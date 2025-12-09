import 'dart:async';
import 'dart:convert';

import 'package:fintech/models/chart_models.dart';
import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/dividend_event.dart';
import 'package:fintech/models/news_models.dart';
import 'package:http/http.dart' as http;

/// Lightweight client around Yahoo Finance public endpoints.
class YahooFinanceService {
  YahooFinanceService._();

  static const _searchEndpoint =
      'https://query2.finance.yahoo.com/v1/finance/search';
  static const _quoteEndpoint =
      'https://query1.finance.yahoo.com/v7/finance/quote';
  static const _crumbEndpoint =
      'https://query1.finance.yahoo.com/v1/test/getcrumb';
  static const _chartEndpoint =
      'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _quoteSummaryEndpoint =
      'https://query1.finance.yahoo.com/v10/finance/quoteSummary';
  static const _newsEndpoint =
      'https://query1.finance.yahoo.com/v2/finance/news';

  static const Map<String, String> _baseHeaders = {
    'Accept': 'application/json',
    // Yahoo normally expects a browser UA, otherwise returns 403 intermittently.
    'User-Agent':
        'Mozilla/5.0 (compatible; CodexFinanceApp/1.0; +https://openai.com)',
  };

  // Local fallback metas to guarantee enough data points from Yahoo v8 chart.
  // We fetch a broader range and window on-device to the exact interval.
  static const Map<ChartInterval, ChartIntervalMeta> _defaultChartMetas = {
    ChartInterval.oneDay: ChartIntervalMeta(
      range: '5d',       // ensure multiple intraday points for the last day
      granularity: '1m', // minute bars when available
      intraday: true,
    ),
    ChartInterval.sevenDays: ChartIntervalMeta(
      range: '1mo',      // fetch a month, then window to the last 7 days
      granularity: '1d', // daily bars are reliable across regions
      intraday: false,
    ),
    ChartInterval.oneMonth: ChartIntervalMeta(
      range: '3mo',
      granularity: '1d',
      intraday: false,
    ),
    ChartInterval.sixMonths: ChartIntervalMeta(
      range: '6mo',
      granularity: '1d',
      intraday: false,
    ),
    ChartInterval.yearToDate: ChartIntervalMeta(
      range: 'ytd',
      granularity: '1d',
      intraday: false,
    ),
    ChartInterval.fiveYears: ChartIntervalMeta(
      range: '5y',
      granularity: '1wk',
      intraday: false,
    ),
    ChartInterval.max: ChartIntervalMeta(
      range: 'max',
      granularity: '1mo',
      intraday: false,
    ),
  };

  // ----- Debug helpers -----
  static bool _debug = true; // passe à false en prod si besoin
  static Future<bool> Function()? onConsentRequired;
  static void _log(String msg) {
    if (_debug) {
      // ignore: avoid_print
      print('[YahooFinance] $msg');
    }
  }

  // ----- Optional cookie override (e.g., paste from browser after consent) -----
  static String? _cookieOverride;
  static void setYahooCookieOverride(String? cookieHeader) {
    String? cleaned = cookieHeader?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      final up = cleaned.toUpperCase();
      final hasCore =
          up.contains('A1=') ||
          up.contains('A3=') ||
          up.contains('GUCS=') ||
          up.contains('GUC=');
      if (cleaned.length < 80 || !hasCore) {
        _log(
          'Ignoring manual Yahoo cookie override (length ${cleaned.length}) -> missing core cookies.',
        );
        cleaned = null;
      }
    }

    _cookieOverride = (cleaned != null && cleaned.isNotEmpty) ? cleaned : null;
    if (_cookieOverride != null) {
      _log(
        'Using manual Yahoo cookie override (' +
            _cookieOverride!.length.toString() +
            ' chars).',
      );
      _yahooCookie = null; // rely solely on manual override when present
      _yahooCrumb = null;
      _yahooCookieExpiry = DateTime.now().add(const Duration(minutes: 30));
    } else {
      _log('Cleared manual Yahoo cookie override.');
    }
  }

  static String? currentCookie() {
    return _buildCookieHeader();
  }

  // ===== Yahoo cookie/crumb cache =====
  static String? _yahooCookie;
  static String? _yahooCrumb;
  static DateTime? _yahooCookieExpiry;

  static final RegExp _crumbRegex = RegExp(
    r'\"CrumbStore\":\\\{\"crumb\":\"(?<c>[^\"\\\\]+)',
  );
  static final RegExp _cookiePairRegex = RegExp(r'(^|;)\s*([^=;\s]+)=([^;]+)');

  static String? _buildCookieHeader() {
    final pairs = <String, String>{};

    void absorb(String? source) {
      if (source == null || source.trim().isEmpty) return;
      for (final match in _cookiePairRegex.allMatches(source)) {
        final name = match.group(2)?.trim();
        final value = match.group(3)?.trim();
        if (name == null || name.isEmpty || value == null || value.isEmpty) {
          continue;
        }
        pairs[name] = value;
      }
    }

    absorb(_yahooCookie);
    absorb(_cookieOverride);

    if (pairs.isEmpty) return null;
    return pairs.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  // Helper: Update cookies from a Set-Cookie header string
  static void _updateCookiesFromSetCookie(String? sc) {
    if (sc == null || sc.isEmpty) return;
    final reg = RegExp(r'(^|,)\s*([^=;\s,]+)=([^;\s,]+)');
    final pairs = <String, String>{};

    void absorbExisting(String? existing) {
      if (existing == null || existing.isEmpty) return;
      for (final match in _cookiePairRegex.allMatches(existing)) {
        final name = match.group(2)?.trim();
        final value = match.group(3)?.trim();
        if (name == null || name.isEmpty || value == null || value.isEmpty) {
          continue;
        }
        pairs[name] = value;
      }
    }

    absorbExisting(_yahooCookie);

    for (final m in reg.allMatches(sc)) {
      final name = m.group(2);
      final value = m.group(3);
      if (name != null && value != null) {
        final up = name.toLowerCase();
        if (up == 'expires' ||
            up == 'path' ||
            up == 'domain' ||
            up == 'max-age' ||
            up == 'secure' ||
            up == 'httponly' ||
            up.startsWith('samesite')) {
          continue;
        }
        pairs[name] = value;
      }
    }

    if (pairs.isNotEmpty) {
      _yahooCookie = pairs.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
      _yahooCookieExpiry = DateTime.now().add(const Duration(minutes: 10));
      _yahooCrumb = null;
      _log('Updated cookies (' + pairs.length.toString() + ' pairs).');
    }
  }

  /// Try to obtain Yahoo cookies by hitting endpoints known to set A1/A3 etc.
  static Future<void> _bootstrapCookies() async {
    if (_cookieOverride != null) {
      _log('Bootstrap skipped because manual cookie override is active.');
      return;
    }
    final common = <String, String>{
      'Accept-Encoding': 'gzip, deflate',
      'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
      'User-Agent': _baseHeaders['User-Agent']!,
      'Connection': 'keep-alive',
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
    };

    Future<void> _hit(Uri uri, {Map<String, String>? extra}) async {
      final headers = Map<String, String>.from(common);
      if (extra != null) headers.addAll(extra);
      final cookieHeader = _buildCookieHeader();
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
      }
      _log('Bootstrapping cookies via: ' + uri.toString());
      http.Response r;
      try {
        r = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        _log('Bootstrap request timed out for ' + uri.toString());
        return;
      } catch (e) {
        _log('Bootstrap request error: ' + e.toString());
        return;
      }
      _log('Bootstrap status: ' + r.statusCode.toString());
      final sc = r.headers['set-cookie'];
      if (sc != null && sc.isNotEmpty) {
        _log('Bootstrap Set-Cookie length: ' + sc.length.toString());
        _updateCookiesFromSetCookie(sc);
      }
    }

    // 1) fc.yahoo.com is known to set cookies
    await _hit(Uri.parse('https://fc.yahoo.com'));
    if (_yahooCookie == null) {
      // 2) finance.yahoo.com homepage sometimes sets cookies before quote pages
      await _hit(
        Uri.parse('https://finance.yahoo.com'),
        extra: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );
    }
  }

  static Future<void> _refreshCrumb({bool force = false}) async {
    final crumbValid =
        !force &&
        _yahooCrumb != null &&
        _yahooCrumb!.isNotEmpty &&
        _yahooCookieExpiry != null &&
        DateTime.now().isBefore(_yahooCookieExpiry!);
    if (crumbValid) {
      return;
    }

    final cookieHeader = _buildCookieHeader();
    if (cookieHeader == null || cookieHeader.isEmpty) {
      _log('Cannot refresh crumb: no cookies available.');
      throw FinanceRequestException('consent_required');
    }

    final headers = <String, String>{
      'Accept': 'text/plain',
      'User-Agent': _baseHeaders['User-Agent']!,
      'Cookie': cookieHeader,
      'Connection': 'keep-alive',
    };

    http.Response res;
    try {
      res = await http
          .get(Uri.parse(_crumbEndpoint), headers: headers)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      _log('Crumb endpoint request timed out.');
      throw FinanceRequestException('consent_required');
    } catch (e) {
      _log('Crumb endpoint request error: ' + e.toString());
      throw FinanceRequestException('crumb_unavailable');
    }
    _log('Crumb endpoint status: ' + res.statusCode.toString());

    if (res.statusCode == 200) {
      final crumb = res.body.trim();
      if (crumb.isEmpty) {
        _log('Crumb endpoint returned empty payload.');
        throw FinanceRequestException('crumb_unavailable');
      }
      _yahooCrumb = crumb;
      _log('Crumb refreshed: ' + _yahooCrumb!);
      return;
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      _log('Crumb endpoint denied with status ' + res.statusCode.toString());
      throw FinanceRequestException(
        'consent_required',
        statusCode: res.statusCode,
      );
    }

    _log('Crumb endpoint unexpected status: ' + res.statusCode.toString());
    throw FinanceRequestException(
      'crumb_unavailable',
      statusCode: res.statusCode,
    );
  }

  static Future<void> _collectCrumbFromHtml(String symbol) async {
    try {
      final html = await _getQuoteHtml(symbol);
      final match = _crumbRegex.firstMatch(html);
      if (match != null) {
        final raw = match.namedGroup('c');
        if (raw != null && raw.isNotEmpty) {
          _yahooCrumb = raw.replaceAll(r'\\u002F', '/');
          _log('Crumb extracted from HTML: ' + (_yahooCrumb ?? '<none>'));
          return;
        }
      }
      _log('Crumb not found in HTML payload.');
      throw FinanceRequestException('crumb_unavailable');
    } on FinanceRequestException {
      rethrow;
    } catch (e) {
      _log('collectCrumbFromHtml error: ' + e.toString());
      throw FinanceRequestException('crumb_unavailable');
    }
  }

  /// Fetch a Yahoo quote page to obtain cookies + crumb (cached ~10 minutes)
  static Future<void> _ensureYahooAuth(String symbol) async {
    _log('Ensuring Yahoo auth for symbol: ' + symbol);
    final now = DateTime.now();
    final cookieHeader = _buildCookieHeader();
    final cookieValid =
        cookieHeader != null &&
        cookieHeader.isNotEmpty &&
        _yahooCookieExpiry != null &&
        now.isBefore(_yahooCookieExpiry!);

    if (!cookieValid) {
      await _bootstrapCookies();
    }

    final refreshedCookieHeader = _buildCookieHeader();
    if (refreshedCookieHeader == null || refreshedCookieHeader.isEmpty) {
      _log('No Yahoo cookies available after bootstrap.');
      throw FinanceRequestException('consent_required');
    }

    try {
      await _refreshCrumb();
      return;
    } on FinanceRequestException catch (e) {
      if (e.message == 'crumb_unavailable') {
        _log('Crumb endpoint failed, falling back to HTML extraction...');
        await _collectCrumbFromHtml(symbol);
        return;
      }
      rethrow;
    }
  }

  /// Returns the top search results for equities matching [query].
  static Future<List<TickerSearchResult>> searchEquities(String query) async {
    final uri = Uri.parse(
      '$_searchEndpoint?q=${Uri.encodeComponent(query)}&lang=fr-FR&region=FR&quotesCount=20&newsCount=0&enableFuzzyQuery=false',
    );

    final res = await http
        .get(uri, headers: _baseHeaders)
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw FinanceRequestException(
        'Recherche indisponible (${res.statusCode}).',
      );
    }

    final decoded = jsonDecode(res.body);
    final quotes = decoded is Map<String, dynamic> ? decoded['quotes'] : null;
    if (quotes is! List) return const [];

    final seen = <String>{};
    final results = <TickerSearchResult>[];

    for (final item in quotes) {
      if (item is! Map<String, dynamic>) continue;
      final result = TickerSearchResult.tryFromJson(item);
      if (result == null) continue;
      if (seen.contains(result.symbol)) continue;
      seen.add(result.symbol);
      results.add(result);
    }

    return results;
  }

  /// Fetches the latest quote snapshot and meta information for [symbol].
  static Future<QuoteDetail> fetchQuote(String symbol) async {
    try {
      return await _fetchQuoteFromYahoo(symbol);
    } on FinanceRequestException catch (e) {
      // Si le service a détecté le mur RGPD, on appelle le hook UI pour ouvrir la WebView
      if (e.message == 'consent_required' && onConsentRequired != null) {
        _log('Consent required: invoking onConsentRequired hook...');
        try {
          final ok = await onConsentRequired!.call();
          _log('onConsentRequired returned: ${ok == true ? 'true' : 'false'}');
          if (ok == true) {
            // On retente une fois après consentement
            return await _fetchQuoteFromYahoo(symbol);
          }
        } catch (hookError) {
          _log('onConsentRequired hook error: $hookError');
        }
      }
      rethrow;
    } catch (e) {
      // Autres erreurs : on propage
      rethrow;
    }
  }

  /// Returns historical closing prices for [symbol] at the selected [interval].
  static Future<List<HistoricalPoint>> fetchHistoricalSeries(
    String symbol,
    ChartInterval interval,
  ) async {
    Future<List<HistoricalPoint>> run() =>
        _fetchHistoricalSeries(symbol, interval);

    try {
      return await run();
    } on FinanceRequestException catch (e) {
      if (e.message == 'consent_required' && onConsentRequired != null) {
        _log('Consent required for chart on $symbol — invoking hook...');
        try {
          final ok = await onConsentRequired!.call();
          _log('onConsentRequired returned: ${ok == true ? 'true' : 'false'}');
          if (ok == true) {
            return await run();
          }
        } catch (hookError) {
          _log('onConsentRequired hook error: $hookError');
        }
      }
      rethrow;
    }
  }

  static Future<List<FinanceNewsItem>> fetchCompanyNews(
    String symbol, {
    int count = 12,
    List<String>? aliases,
  }) async {
    final trimmed = symbol.trim();
    if (trimmed.isEmpty) return const <FinanceNewsItem>[];

    try {
      await _ensureYahooAuth(trimmed);
    } on FinanceRequestException catch (e) {
      if (e.message == 'consent_required') rethrow;
    } catch (e) {
      _log('ensureYahooAuth (news) error: ' + e.toString());
    }

    final aggregated = <FinanceNewsItem>[];
    final seen = <String>{};
    final tickerAliases = _buildTickerAliases(trimmed, aliases);
    final textAliases = _buildTextAliases(trimmed, aliases);
    FinanceRequestException? lastError;

    Future<void> _tryCollect(List<FinanceNewsItem> source, String label) async {
      _log('News attempt "$label" returned ' + source.length.toString() + ' items.');
      for (final item in source) {
        if (seen.add(item.id)) {
          aggregated.add(item);
        }
      }
    }

    Future<List<FinanceNewsItem>> _newsApiAttempt({
      required String region,
      required String lang,
      required int fetchCount,
    }) async {
      final params = <String, String>{
        'symbols': trimmed,
        'count': fetchCount.toString(),
        'region': region,
        'lang': lang,
      };
      if (_yahooCrumb != null && _yahooCrumb!.isNotEmpty) {
        params['crumb'] = _yahooCrumb!;
      }
      final uri = Uri.parse(_newsEndpoint).replace(queryParameters: params);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
        'User-Agent': _baseHeaders['User-Agent']!,
        'Connection': 'keep-alive',
      };
      final cookie = _buildCookieHeader();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      _log('Requesting news: ' + uri.toString());

      http.Response res;
      try {
        res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        throw FinanceRequestException('Actualités indisponibles (timeout).');
      } catch (e) {
        throw FinanceRequestException('Actualités indisponibles. ${e.toString()}');
      }

      if (res.statusCode == 401 || res.statusCode == 403) {
        _yahooCookie = null;
        _yahooCrumb = null;
        _yahooCookieExpiry = null;
        await _bootstrapCookies();
        try {
          await _refreshCrumb(force: true);
        } catch (e) {
          _log('refreshCrumb (news retry) error: ' + e.toString());
        }
        final retryParams = Map<String, String>.from(params);
        if (_yahooCrumb != null && _yahooCrumb!.isNotEmpty) {
          retryParams['crumb'] = _yahooCrumb!;
        }
        final retryUri = Uri.parse(_newsEndpoint).replace(queryParameters: retryParams);
        _log('Retrying news request: ' + retryUri.toString());
        res = await http
            .get(retryUri, headers: headers)
            .timeout(const Duration(seconds: 8));
      }

      if (res.statusCode != 200) {
        final preview =
            res.body.isNotEmpty
                ? res.body.substring(
                  0,
                  res.body.length > 160 ? 160 : res.body.length,
                )
                : '';
        _log(
          'News non-200 for ' +
              trimmed +
              ' -> ' +
              res.statusCode.toString() +
              ' preview=' +
              preview,
        );
        throw FinanceRequestException(
          'Actualités indisponibles (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (e) {
        throw FinanceRequestException('Réponse Yahoo actualités invalide.');
      }

      return _extractNewsItemsFromPayload(decoded);
    }

    Future<List<FinanceNewsItem>> _searchFallbackAttempt({
      required String region,
      required String lang,
      required int newsCount,
    }) async {
      final uri = Uri.parse(
        '$_searchEndpoint?q=${Uri.encodeComponent(trimmed)}&lang=${Uri.encodeComponent(lang)}&region=${Uri.encodeComponent(region)}&quotesCount=0&newsCount=$newsCount&enableFuzzyQuery=false',
      );
      _log('Fallback search news: ' + uri.toString());
      http.Response res;
      try {
        res = await http
            .get(uri, headers: _baseHeaders)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        throw FinanceRequestException('Recherche actualités indisponible (timeout).');
      } catch (e) {
        throw FinanceRequestException('Recherche actualités indisponible. ${e.toString()}');
      }

      if (res.statusCode != 200) {
        _log(
          'Search news non-200 -> ' +
              res.statusCode.toString() +
              ' body=' +
              (res.body.length > 120 ? res.body.substring(0, 120) : res.body),
        );
        throw FinanceRequestException(
          'Recherche actualités indisponible (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (e) {
        throw FinanceRequestException('Réponse recherche Yahoo invalide.');
      }

      final news = decoded is Map<String, dynamic> ? decoded['news'] : null;
      if (news is! List) return const <FinanceNewsItem>[];
      final results = <FinanceNewsItem>[];
      final localSeen = <String>{};
      for (final item in news) {
        if (item is Map<String, dynamic>) {
          final parsed = FinanceNewsItem.fromJson(item);
          if (parsed != null && localSeen.add(parsed.id)) {
            results.add(parsed);
          }
        }
      }
      return results;
    }

    final apiAttempts = <Map<String, dynamic>>[
      {'region': 'FR', 'lang': 'fr-FR', 'count': count},
      {'region': 'FR', 'lang': 'en-US', 'count': count * 2},
      {'region': 'US', 'lang': 'en-US', 'count': count * 2},
    ];

    for (final attempt in apiAttempts) {
      try {
        final items = await _newsApiAttempt(
          region: attempt['region'] as String,
          lang: attempt['lang'] as String,
          fetchCount: attempt['count'] as int,
        );
        await _tryCollect(items, '${attempt['region']}/${attempt['lang']}');
        if (aggregated.length >= count) break;
      } on FinanceRequestException catch (e) {
        lastError = e;
        _log('News API attempt failed (${attempt['region']}/${attempt['lang']}): ' + e.message);
      }
    }

    if (aggregated.length < count) {
      final fallbackAttempts = <Map<String, String>>[
        {'region': 'FR', 'lang': 'fr-FR'},
        {'region': 'US', 'lang': 'en-US'},
      ];
      for (final attempt in fallbackAttempts) {
        try {
          final items = await _searchFallbackAttempt(
            region: attempt['region']!,
            lang: attempt['lang']!,
            newsCount: count * 3,
          );
          await _tryCollect(items, 'search ${attempt['region']}/${attempt['lang']}');
          if (aggregated.length >= count) break;
        } on FinanceRequestException catch (e) {
          lastError = e;
          _log('Search fallback failed (${attempt['region']}/${attempt['lang']}): ' + e.message);
        }
      }
    }

    if (aggregated.isEmpty && lastError != null) {
      throw lastError;
    }

    aggregated.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    final filtered = aggregated.where((item) {
      final ok = _isNewsRelevant(
        item,
        tickerAliases: tickerAliases,
        textAliases: textAliases,
      );
      if (!ok) {
        _log('Filtered out news item ${item.id} (title="${item.title}").');
      }
      return ok;
    }).toList();

    _log(
      'News filtered count=' +
          filtered.length.toString() +
          ' / total=' +
          aggregated.length.toString() +
          ', tickerAliases=' +
          tickerAliases.join(',') +
          ', textAliases=' +
          textAliases.join(','),
    );

    final chosen = filtered.isNotEmpty ? filtered : aggregated;
    if (chosen.length > count) {
      return chosen.sublist(0, count);
    }
    return chosen;
  }

  static Future<FinancialSnapshot> fetchFinancialSnapshot(String symbol) async {
    Future<FinancialSnapshot> run() => _fetchFinancialSnapshot(symbol);

    try {
      return await run();
    } on FinanceRequestException catch (e) {
      if (e.message == 'consent_required' && onConsentRequired != null) {
        _log('Consent required for financial snapshot on $symbol — invoking hook...');
        try {
          final ok = await onConsentRequired!.call();
          _log('onConsentRequired returned: ${ok == true ? 'true' : 'false'}');
          if (ok == true) {
            return await run();
          }
        } catch (hookError) {
          _log('onConsentRequired hook error: $hookError');
        }
      }
      rethrow;
    }
  }

  static List<FinanceNewsItem> _extractNewsItemsFromPayload(dynamic decoded) {
    final items = <FinanceNewsItem>[];
    final localSeen = <String>{};

    void collect(dynamic node) {
      if (node is Map<String, dynamic>) {
        final item = FinanceNewsItem.fromJson(node);
        if (item != null && localSeen.add(item.id)) {
          items.add(item);
        } else {
          for (final value in node.values) {
            collect(value);
          }
        }
      } else if (node is List) {
        for (final value in node) {
          collect(value);
        }
      }
    }

    collect(decoded);
    return items;
  }

  static Future<FinancialSnapshot> _fetchFinancialSnapshot(String symbol) async {
    try {
      await _ensureYahooAuth(symbol);
    } on FinanceRequestException {
      rethrow;
    } catch (e) {
      _log('ensureYahooAuth (snapshot) error: ' + e.toString());
    }

    try {
      await _refreshCrumb();
    } catch (e) {
      _log('refreshCrumb (snapshot) error: ' + e.toString());
    }

    if ((_buildCookieHeader() ?? '').isEmpty) {
      throw FinanceRequestException('consent_required');
    }

    Uri _buildUri() {
      final symbolPath = Uri.encodeComponent(symbol);
      final modules = [
        'financialData',
        'defaultKeyStatistics',
        'summaryDetail',
        'balanceSheetHistory',
        'balanceSheetHistoryQuarterly',
        'incomeStatementHistory',
        'incomeStatementHistoryQuarterly',
        'cashflowStatementHistory',
        'summaryProfile',
        'fundProfile',
        'fundPerformance',
      ].join(',');
      final params = <String, String>{'modules': modules};
      if (_yahooCrumb != null && _yahooCrumb!.isNotEmpty) {
        params['crumb'] = _yahooCrumb!;
      }
      return Uri.parse('$_quoteSummaryEndpoint/$symbolPath').replace(
        queryParameters: params,
      );
    }

    Future<http.Response> _doRequest(Uri uri) {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
        'User-Agent': _baseHeaders['User-Agent']!,
        'Referer': 'https://finance.yahoo.com/quote/$symbol',
        'Connection': 'keep-alive',
      };
      final cookie = _buildCookieHeader();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      final uriString = uri.toString();
      _log('Requesting financial snapshot: ' + uriString);
      return http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
    }

    Uri uri = _buildUri();
    http.Response res;
    try {
      res = await _doRequest(uri);
    } on TimeoutException {
      throw FinanceRequestException('Données financières indisponibles (timeout).');
    } catch (e) {
      throw FinanceRequestException('Données financières indisponibles. ${e.toString()}');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      _yahooCookie = null;
      _yahooCrumb = null;
      _yahooCookieExpiry = null;
      await _bootstrapCookies();
      try {
        await _refreshCrumb(force: true);
      } catch (e) {
        _log('refreshCrumb (snapshot retry) error: ' + e.toString());
      }
      uri = _buildUri();
      res = await _doRequest(uri);
    }

    if (res.statusCode != 200) {
      final preview =
          res.body.isNotEmpty
              ? res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)
              : '';
      _log(
        'Financial snapshot non-200 for ' +
            symbol +
            ': ' +
            res.statusCode.toString() +
            ' -> ' +
            preview,
      );
      throw FinanceRequestException(
        'Données financières indisponibles (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      throw FinanceRequestException('Réponse Yahoo financière invalide.');
    }

    Map<String, dynamic>? _asMap(dynamic value) =>
        value is Map<String, dynamic> ? value : null;

    final summary = _asMap(decoded)?['quoteSummary'];
    final resultList = summary is Map<String, dynamic> ? summary['result'] : null;
    if (resultList is! List || resultList.isEmpty) {
      throw FinanceRequestException('Données financières indisponibles.');
    }

    final first = _asMap(resultList.first);
    if (first == null) {
      throw FinanceRequestException('Données financières indisponibles.');
    }

    return FinancialSnapshot.fromQuoteSummary(first);
  }

  static Future<DividendEvent?> fetchDividendEvent(String symbol) async {
    try {
      await _ensureYahooAuth(symbol);
    } on FinanceRequestException {
      rethrow;
    } catch (e) {
      _log('ensureYahooAuth (dividend) error: ' + e.toString());
    }

    try {
      await _refreshCrumb();
    } catch (e) {
      _log('refreshCrumb (dividend) error: ' + e.toString());
    }

    if ((_buildCookieHeader() ?? '').isEmpty) {
      throw FinanceRequestException('consent_required');
    }

    Uri _buildUri() {
      final symbolPath = Uri.encodeComponent(symbol);
      const modules = 'calendarEvents,summaryDetail,price';
      final params = <String, String>{'modules': modules};
      if (_yahooCrumb != null && _yahooCrumb!.isNotEmpty) {
        params['crumb'] = _yahooCrumb!;
      }
      return Uri.parse('$_quoteSummaryEndpoint/$symbolPath').replace(
        queryParameters: params,
      );
    }

    Future<http.Response> _doRequest(Uri uri) {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
        'User-Agent': _baseHeaders['User-Agent']!,
        'Referer': 'https://finance.yahoo.com/quote/$symbol',
        'Connection': 'keep-alive',
      };
      final cookie = _buildCookieHeader();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      return http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
    }

    Uri uri = _buildUri();
    http.Response res;
    try {
      res = await _doRequest(uri);
    } on TimeoutException {
      throw FinanceRequestException('Calendrier de dividendes indisponible (timeout).');
    } catch (e) {
      throw FinanceRequestException('Calendrier de dividendes indisponible. ${e.toString()}');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      _yahooCookie = null;
      _yahooCrumb = null;
      _yahooCookieExpiry = null;
      await _bootstrapCookies();
      try {
        await _refreshCrumb(force: true);
      } catch (e) {
        _log('refreshCrumb (dividend retry) error: ' + e.toString());
      }
      uri = _buildUri();
      res = await _doRequest(uri);
    }

    if (res.statusCode != 200) {
      throw FinanceRequestException(
        'Calendrier de dividendes indisponible (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      throw FinanceRequestException('Réponse Yahoo invalide pour le calendrier de dividendes.');
    }

    Map<String, dynamic>? _asMap(dynamic value) =>
        value is Map<String, dynamic> ? value : null;

    DateTime? _readDate(dynamic value) {
      if (value == null) return null;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000, isUtc: true).toLocal();
      }
      if (value is Map<String, dynamic>) {
        final raw = value['raw'];
        if (raw is num) {
          return DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000, isUtc: true).toLocal();
        }
        final fmt = value['fmt'];
        if (fmt is String) {
          return DateTime.tryParse(fmt)?.toLocal();
        }
      }
      if (value is String) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    double? _readNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.replaceAll(',', ''));
      if (value is Map<String, dynamic>) {
        final raw = value['raw'];
        if (raw is num) return raw.toDouble();
        final fmt = value['fmt'];
        if (fmt is String) {
          return double.tryParse(fmt.replaceAll(',', ''));
        }
      }
      return null;
    }

    final summary = _asMap(decoded)?['quoteSummary'];
    final resultList = summary is Map<String, dynamic> ? summary['result'] : null;
    if (resultList is! List || resultList.isEmpty) {
      return null;
    }

    final first = _asMap(resultList.first);
    if (first == null) {
      return null;
    }

    final calendarEvents = _asMap(first['calendarEvents']);
    final summaryDetail = _asMap(first['summaryDetail']);
    final priceMap = _asMap(first['price']);

    final cashDividend = _asMap(calendarEvents?['cashDividend']);
    DateTime? exDate = _readDate(calendarEvents?['exDividendDate'] ?? summaryDetail?['exDividendDate']);
    DateTime? paymentDate = _readDate(calendarEvents?['dividendDate'] ?? summaryDetail?['dividendDate']);
    final declarationDate = _readDate(calendarEvents?['dividendDeclDate'] ?? calendarEvents?['declarationDate']);
    double? amount = _readNum(cashDividend?['raw'] ?? cashDividend);
    amount ??= _readNum(summaryDetail?['dividendRate'] ?? summaryDetail?['trailingAnnualDividendRate']);
    final currency = (summaryDetail?['currency'] ?? priceMap?['currency'])?.toString();
    final frequency = summaryDetail?['dividendFrequency']?.toString();
    final name =
        (priceMap?['shortName'] ?? priceMap?['longName'] ?? priceMap?['displayName'] ?? symbol).toString();

    if (exDate == null && paymentDate != null) {
      exDate = paymentDate.subtract(const Duration(days: 3));
    } else if (paymentDate == null && exDate != null) {
      paymentDate = exDate.add(const Duration(days: 3));
    }
    if (exDate != null && paymentDate != null && paymentDate.isBefore(exDate)) {
      paymentDate = exDate.add(const Duration(days: 3));
    }

    if (exDate == null && paymentDate == null && amount == null) {
      return null;
    }

    return DividendEvent(
      symbol: symbol,
      name: name,
      exDate: exDate,
      paymentDate: paymentDate,
      declarationDate: declarationDate,
      amount: amount,
      currency: currency,
      frequency: frequency?.isEmpty ?? true ? null : frequency,
    );
  }

  static Set<String> _buildTickerAliases(String symbol, List<String>? aliases) {
    final results = <String>{};
    void add(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      results.add(trimmed.toUpperCase());
      results.add(trimmed.replaceAll('.', '').toUpperCase());
    }

    add(symbol);
    if (symbol.contains('.')) {
      add(symbol.split('.').first);
    }
    if (aliases != null) {
      for (final alias in aliases) {
        add(alias);
      }
    }
    results.removeWhere((value) => value.isEmpty);
    return results;
  }

  static Set<String> _buildTextAliases(String symbol, List<String>? aliases) {
    final results = <String>{};
    void add(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      results.add(trimmed.toLowerCase());
    }

    add(symbol);
    if (symbol.contains('.')) {
      add(symbol.split('.').first);
    }
    if (aliases != null) {
      for (final alias in aliases) {
        add(alias);
      }
    }
    results.removeWhere((value) => value.isEmpty);
    return results;
  }

  static bool _isNewsRelevant(
    FinanceNewsItem item, {
    required Set<String> tickerAliases,
    required Set<String> textAliases,
  }) {
    for (final ticker in item.relatedTickers) {
      final normalized = ticker.replaceAll('.', '').toUpperCase();
      if (tickerAliases.contains(ticker.toUpperCase()) ||
          tickerAliases.contains(normalized)) {
        return true;
      }
    }

    final lowerTitle = item.title.toLowerCase();
    final lowerSummary = item.summary?.toLowerCase();
    for (final alias in textAliases) {
      if (lowerTitle.contains(alias)) return true;
      if (lowerSummary != null && lowerSummary.contains(alias)) return true;
    }

    return false;
  }

  // Helper: Try to bypass Yahoo EU consent wall if detected in HTML.
  static Future<bool> _maybeBypassConsent(String html) async {
    // Detect EU consent wall
    final isConsent =
        html.contains('famille de marques Yahoo') ||
        html.contains('guce.yahoo.com') ||
        html.contains('consent.yahoo.com');
    if (!isConsent) return false;

    _log('Consent wall detected. Trying to collect consent...');

    // Find a collectConsent URL in the HTML
    final re = RegExp(r'''https://consent\.yahoo\.com[^"']+''');
    final m = re.firstMatch(html);
    if (m == null) {
      // Some pages link to guce.yahoo.com which then redirects to consent
      final re2 = RegExp(r'''https://guce\.yahoo\.com[^"']+''');
      final m2 = re2.firstMatch(html);
      if (m2 == null) {
        _log('No consent URL found in page.');
        return false;
      }
      final url2 = m2.group(0)!;
      _log('Hitting GUCE URL: ' + url2);
      final headers2 = <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'User-Agent': _baseHeaders['User-Agent']!,
      };
      final cookieForGuce = _buildCookieHeader();
      if (cookieForGuce != null && cookieForGuce.isNotEmpty) {
        headers2['Cookie'] = cookieForGuce;
      }
      http.Response r2;
      try {
        r2 = await http
            .get(Uri.parse(url2), headers: headers2)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        _log('Consent GUCE request failed: ' + e.toString());
        throw FinanceRequestException('consent_required');
      }
      _updateCookiesFromSetCookie(r2.headers['set-cookie']);
      // Try to find a consent link in this response, too
      final html2 = r2.body;
      final m3 = re.firstMatch(html2);
      if (m3 == null) {
        _log('No collectConsent link on GUCE page.');
        return false;
      }
      final url = m3.group(0)!;
      _log('Calling collectConsent: ' + url);
      final headers3 = <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'User-Agent': _baseHeaders['User-Agent']!,
      };
      final cookieForConsent = _buildCookieHeader();
      if (cookieForConsent != null && cookieForConsent.isNotEmpty) {
        headers3['Cookie'] = cookieForConsent;
      }
      http.Response r3;
      try {
        r3 = await http
            .get(Uri.parse(url), headers: headers3)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        _log('Consent collect request failed: ' + e.toString());
        throw FinanceRequestException('consent_required');
      }
      _updateCookiesFromSetCookie(r3.headers['set-cookie']);
      return _yahooCookie != null;
    } else {
      final url = m.group(0)!;
      _log('Calling collectConsent: ' + url);
      final headers = <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'User-Agent': _baseHeaders['User-Agent']!,
      };
      final cookieForConsent = _buildCookieHeader();
      if (cookieForConsent != null && cookieForConsent.isNotEmpty) {
        headers['Cookie'] = cookieForConsent;
      }
      http.Response r;
      try {
        r = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        _log('Consent collect request failed: ' + e.toString());
        throw FinanceRequestException('consent_required');
      }
      _updateCookiesFromSetCookie(r.headers['set-cookie']);
      return _yahooCookie != null;
    }
  }

  /// Helper to fetch Yahoo quote HTML, trying multiple variants.
  static Future<String> _getQuoteHtml(String symbol) async {
    final variants = [
      'https://finance.yahoo.com/quote/${Uri.encodeComponent(symbol)}',
      'https://finance.yahoo.com/quote/${Uri.encodeComponent(symbol)}?p=${Uri.encodeComponent(symbol)}&.tsrc=fin-srch',
      // Variants that sometimes avoid consent interstitials
      'https://finance.yahoo.com/quote/${Uri.encodeComponent(symbol)}?guccounter=1',
      'https://finance.yahoo.com/quote/${Uri.encodeComponent(symbol)}?.intl=us',
    ];

    final baseHeaders = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
      'User-Agent': _baseHeaders['User-Agent']!,
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    };

    for (final url in variants) {
      final headers = Map<String, String>.from(baseHeaders);
      final cookieHeader = _buildCookieHeader();
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
      }
      _log('Fetching quote HTML variant: ' + url);
      http.Response res;
      try {
        res = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        _log('Variant request error: ' + e.toString());
        continue;
      }
      _log('Variant status: ' + res.statusCode.toString());
      final ce = res.headers['content-encoding'] ?? '<none>';
      _log('Variant content-encoding: ' + ce);
      final setCookie = res.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        _log('Variant Set-Cookie length: ' + setCookie.length.toString());
        _updateCookiesFromSetCookie(setCookie);
      }
      if (res.statusCode == 200) {
        var body = res.body;
        // If consent wall detected, try to bypass and then refetch this URL once
        final bypassed = await _maybeBypassConsent(body);
        if (bypassed) {
          _log('Consent collected. Refetching: ' + url);
          final headers2 = Map<String, String>.from(baseHeaders);
          final refreshedCookie = _buildCookieHeader();
          if (refreshedCookie != null && refreshedCookie.isNotEmpty) {
            headers2['Cookie'] = refreshedCookie;
          }
          final res2 = await http
              .get(Uri.parse(url), headers: headers2)
              .timeout(const Duration(seconds: 8));
          _log('Refetch status: ' + res2.statusCode.toString());
          if (res2.statusCode == 200) {
            final setCookieRetry = res2.headers['set-cookie'];
            if (setCookieRetry != null && setCookieRetry.isNotEmpty) {
              _log(
                'Set-Cookie header length (variant refetch): ' +
                    setCookieRetry.length.toString(),
              );
              _updateCookiesFromSetCookie(setCookieRetry);
            }
            body = res2.body;
          }
        } else {
          // Still looks like consent wall -> bubble up for UI to trigger WebView
          if (body.contains('famille de marques Yahoo') ||
              body.contains('guce.yahoo.com') ||
              body.contains('consent.yahoo.com')) {
            _log('Consent wall detected and not bypassed.');
            throw FinanceRequestException('consent_required');
          }
        }
        return body;
      }
    }
    throw FinanceRequestException('Pages Yahoo indisponibles.');
  }

  /// Final Yahoo-only fallback: parse the quote page HTML and extract data from embedded JSON.
  /// This avoids the v7 API (which may deny 401) while still using Yahoo as the sole source.
  static Future<QuoteDetail> _fetchQuoteFromHtml(String symbol) async {
    final html = await _getQuoteHtml(symbol);

    // Try to extract JSON from __NEXT_DATA__ first
    String? jsonText;
    final nextStart = html.indexOf('<script id="__NEXT_DATA__"');
    if (nextStart != -1) {
      final openTagEnd = html.indexOf('>', nextStart);
      final closeTag = html.indexOf('</script>', openTagEnd + 1);
      if (openTagEnd != -1 && closeTag != -1) {
        jsonText = html.substring(openTagEnd + 1, closeTag).trim();
      }
    }

    // Fallback: extract from root.App.main = {...};
    if (jsonText == null || jsonText.isEmpty) {
      final reg = RegExp(
        r'root\.App\.main\s*=\s*(\{.*?\});\s*\n',
        dotAll: true,
      );
      final m = reg.firstMatch(html);
      if (m != null) {
        jsonText = m.group(1);
      }
    }

    // Third fallback: extract from window.__APOLLO_STATE__=
    if (jsonText == null || jsonText.isEmpty) {
      final idx = html.indexOf('window.__APOLLO_STATE__=');
      if (idx != -1) {
        final start = idx + 'window.__APOLLO_STATE__='.length;
        // Capture until the next closing script or semicolon followed by </script>
        int end = html.indexOf('</script>', start);
        if (end != -1) {
          var snippet = html.substring(start, end);
          // Remove trailing semicolon if present
          if (snippet.endsWith(';'))
            snippet = snippet.substring(0, snippet.length - 1);
          jsonText = snippet.trim();
        }
      }
    }

    // Regex-based minimal extractor as last resort
    if (jsonText == null || jsonText.isEmpty) {
      _log(
        'Unable to locate embedded JSON in HTML. Trying regex-based lightweight extraction...',
      );
      // Minimal fields directly from HTML text
      double? numOf(RegExp re) {
        final m = re.firstMatch(html);
        if (m != null) {
          return double.tryParse(m.group(1)!.replaceAll(',', ''));
        }
        return null;
      }

      String? strOf(RegExp re) {
        final m = re.firstMatch(html);
        if (m != null) {
          return m.group(1)!.replaceAll('\\"', '"');
        }
        return null;
      }

      final price = numOf(
        RegExp(r'"regularMarketPrice"\s*:\s*\{\s*"raw"\s*:\s*([-0-9.eE]+)'),
      );
      final change = numOf(
        RegExp(r'"regularMarketChange"\s*:\s*\{\s*"raw"\s*:\s*([-0-9.eE]+)'),
      );
      final changePct = numOf(
        RegExp(
          r'"regularMarketChangePercent"\s*:\s*\{\s*"raw"\s*:\s*([-0-9.eE]+)',
        ),
      );
      final currency = strOf(RegExp(r'"currency"\s*:\s*"([A-Z]{3})"'));
      final shortName = strOf(RegExp(r'"shortName"\s*:\s*"([^"]{1,200})"'));
      final longName = strOf(RegExp(r'"longName"\s*:\s*"([^"]{1,200})"'));
      final exchangeName = strOf(
        RegExp(r'"exchangeName"\s*:\s*"([^"]{1,100})"'),
      );

      if (price != null) {
        final normalized = <String, dynamic>{
          'symbol': symbol,
          'shortName': shortName ?? longName ?? symbol,
          'longName': longName ?? shortName ?? symbol,
          'exchange': exchangeName,
          'fullExchangeName': exchangeName,
          'currency': currency,
          'regularMarketPrice': price,
          'regularMarketChange': change,
          'regularMarketChangePercent': changePct,
        };
        final quote = QuoteDetail.fromJson(normalized);
        if (quote.hasCoreData) {
          _log(
            'Regex fallback OK for ' +
                symbol +
                ' @ ' +
                (quote.regularMarketPrice?.toString() ?? 'n/a'),
          );
          return quote;
        }
      }

      // Dump a tiny preview to help debug
      final preview = html.substring(0, html.length > 800 ? 800 : html.length);
      _log('Regex fallback failed. HTML preview: ' + preview);
      throw FinanceRequestException(
        'Structure Yahoo inattendue (pas de JSON embarqué).',
      );
    }

    dynamic root;
    try {
      root = jsonDecode(jsonText);
    } catch (e) {
      _log('Embedded JSON decode error: ' + e.toString());
      throw FinanceRequestException('JSON embarqué Yahoo illisible.');
    }

    Map<String, dynamic>? _asMap(dynamic v) =>
        v is Map<String, dynamic> ? v : null;

    // Attempt multiple known structures
    Map<String, dynamic>? stores;
    final m1 = _asMap(root);
    if (m1 != null) {
      // __NEXT_DATA__ path
      final props = _asMap(m1['props']);
      final pageProps = props != null ? _asMap(props['pageProps']) : null;
      final fin =
          pageProps != null ? _asMap(pageProps['dehydratedState']) : null;
      if (fin != null) {
        // Some variants place queries here; we would need to traverse, but try QuoteSummaryStore below too
      }

      // root.App.main path
      final ctx = _asMap(m1['context']);
      final dispatcher = ctx != null ? _asMap(ctx['dispatcher']) : null;
      stores = dispatcher != null ? _asMap(dispatcher['stores']) : null;
    }

    Map<String, dynamic>? qss;
    if (stores != null) {
      qss = _asMap(stores['QuoteSummaryStore']);
    }

    Map<String, dynamic>? price = qss != null ? _asMap(qss['price']) : null;
    if (price == null && stores != null) {
      // Sometimes price info is under StreamDataStore or QuotePageStore
      final qps = _asMap(stores['QuotePageStore']);
      price = qps != null ? _asMap(qps['price']) : null;
    }

    if (price == null) {
      _log('No price section found in embedded JSON.');
      throw FinanceRequestException(
        'Données de prix introuvables dans la page.',
      );
    }

    double? _toNum(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is Map && v['raw'] is num) return (v['raw'] as num).toDouble();
      return null;
    }

    String? _toStr(dynamic v) => v?.toString();

    final data = <String, dynamic>{
      'symbol': _toStr(price['symbol']) ?? symbol,
      'shortName':
          _toStr(price['shortName']) ?? _toStr(price['longName']) ?? symbol,
      'longName':
          _toStr(price['longName']) ?? _toStr(price['shortName']) ?? symbol,
      'exchange':
          _toStr(price['exchange']) ??
          _toStr(price['market']) ??
          _toStr(price['exchangeName']),
      'fullExchangeName':
          _toStr(price['exchangeName']) ?? _toStr(price['fullExchangeName']),
      'currency': _toStr(price['currency']) ?? _toStr(price['quoteCurrency']),
      'regularMarketPrice':
          _toNum(price['regularMarketPrice']) ??
          _toNum(price['postMarketPrice']) ??
          _toNum(price['preMarketPrice']),
      'regularMarketChange': _toNum(price['regularMarketChange']),
      'regularMarketChangePercent': _toNum(price['regularMarketChangePercent']),
      'regularMarketDayHigh': _toNum(price['regularMarketDayHigh']),
      'regularMarketDayLow': _toNum(price['regularMarketDayLow']),
      'fiftyTwoWeekHigh': _toNum(price['fiftyTwoWeekHigh']),
      'fiftyTwoWeekLow': _toNum(price['fiftyTwoWeekLow']),
      'marketCap': _toNum(price['marketCap']),
      'regularMarketVolume': _toNum(price['regularMarketVolume']),
      'averageDailyVolume3Month': _toNum(price['averageDailyVolume3Month']),
      'regularMarketTime':
          (price['regularMarketTime'] is num)
              ? (price['regularMarketTime'] as num)
              : (price['regularMarketTime'] is Map &&
                      (price['regularMarketTime']['raw'] is num)
                  ? price['regularMarketTime']['raw'] as num
                  : null),
      'trailingPE': _toNum(price['trailingPE']),
      'forwardPE': _toNum(price['forwardPE']),
      'epsTrailingTwelveMonths': _toNum(price['epsTrailingTwelveMonths']),
      'dividendYield': _toNum(price['dividendYield']),
      'previousClose': _toNum(
        price['regularMarketPreviousClose'] ?? price['previousClose'],
      ),
      'open': _toNum(price['regularMarketOpen'] ?? price['open']),
    };

    // Adapt to QuoteDetail factory input
    final normalized = <String, dynamic>{
      'symbol': data['symbol'],
      'shortName': data['shortName'],
      'longName': data['longName'],
      'exchange': data['exchange'],
      'fullExchangeName': data['fullExchangeName'],
      'currency': data['currency'],
      'regularMarketPrice': data['regularMarketPrice'],
      'regularMarketChange': data['regularMarketChange'],
      'regularMarketChangePercent': data['regularMarketChangePercent'],
      'regularMarketDayHigh': data['regularMarketDayHigh'],
      'regularMarketDayLow': data['regularMarketDayLow'],
      'fiftyTwoWeekHigh': data['fiftyTwoWeekHigh'],
      'fiftyTwoWeekLow': data['fiftyTwoWeekLow'],
      'marketCap': data['marketCap'],
      'regularMarketVolume': data['regularMarketVolume'],
      'averageDailyVolume3Month': data['averageDailyVolume3Month'],
      'regularMarketTime': data['regularMarketTime'],
      'trailingPE': data['trailingPE'],
      'forwardPE': data['forwardPE'],
      'epsTrailingTwelveMonths': data['epsTrailingTwelveMonths'],
      'dividendYield': data['dividendYield'],
      'regularMarketPreviousClose': data['previousClose'],
      'regularMarketOpen': data['open'],
    };

    final quote = QuoteDetail.fromJson(normalized);
    if (!quote.hasCoreData) {
      _log('HTML fallback produced no core data.');
      throw QuoteNotFoundException(symbol);
    }
    _log(
      'HTML fallback OK for ' +
          symbol +
          ' @ ' +
          (quote.regularMarketPrice?.toString() ?? 'n/a'),
    );
    return quote;
  }

  static DateTime _intervalStartForNow(ChartInterval interval) {
    final now = DateTime.now();
    switch (interval) {
      case ChartInterval.oneDay:
        return now.subtract(const Duration(days: 1));
      case ChartInterval.sevenDays:
        return now.subtract(const Duration(days: 7));
      case ChartInterval.oneMonth:
        return now.subtract(const Duration(days: 31));
      case ChartInterval.sixMonths:
        return now.subtract(const Duration(days: 186));
      case ChartInterval.yearToDate:
        return DateTime(now.year, 1, 1, 0, 0, 0);
      case ChartInterval.fiveYears:
        return DateTime(now.year - 5, now.month, now.day);
      case ChartInterval.max:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static List<HistoricalPoint> _applyIntervalWindowAndExtend(
    List<HistoricalPoint> pts,
    ChartInterval interval,
  ) {
    if (pts.isEmpty) return pts;
    // Ensure chronological order
    pts.sort((a, b) => a.time.compareTo(b.time));

    // Compute start bound for the chosen interval
    final bound = _intervalStartForNow(interval);

    // Keep one point before the bound (if any) to preserve visual continuity
    int startIdx = 0;
    for (var i = 0; i < pts.length; i++) {
      if (pts[i].time.isAfter(bound) || pts[i].time.isAtSameMomentAs(bound)) {
        startIdx = (i > 0) ? i - 1 : 0;
        break;
      }
      // if never passes the bound, keep moving; if all are before, startIdx remains last idx
      if (i == pts.length - 1) startIdx = i;
    }

    final windowed = pts.sublist(startIdx).where((p) => !p.time.isBefore(bound)).toList(growable: true);
    if (windowed.isEmpty) {
      // If everything was before, keep last few points for context
      final take = pts.length >= 2 ? 2 : 1;
      return pts.sublist(pts.length - take);
    }

    // If last point is earlier than "now", extend with a synthetic point at now using last close
    final last = windowed.last;
    final lastClose = last.close;
    final now = last.time.isUtc ? DateTime.now().toUtc() : DateTime.now();
    // only append if we moved forward by >= 1 minute to avoid duplicates
    if (now.difference(last.time).inMinutes >= 1) {
      windowed.add(HistoricalPoint(time: now, close: lastClose));
    }
  
    return windowed;
  }

  static Future<List<HistoricalPoint>> _fetchHistoricalSeries(
    String symbol,
    ChartInterval interval,
  ) async {
    try {
      await _ensureYahooAuth(symbol);
    } on FinanceRequestException {
      rethrow;
    } catch (e) {
      _log('ensureYahooAuth (chart) error: ' + e.toString());
    }

    try {
      await _refreshCrumb();
    } catch (e) {
      _log('refreshCrumb (chart) error: ' + e.toString());
    }

    if ((_buildCookieHeader() ?? '').isEmpty) {
      throw FinanceRequestException('consent_required');
    }

    final effectiveMeta = chartIntervalMetas[interval] ?? _defaultChartMetas[interval];
    if (effectiveMeta == null) {
      _log('No meta found for interval: ' + interval.toString());
      throw FinanceRequestException('interval_unsupported');
    }
    _log('Chart meta for ' + symbol + ' @ ' + interval.toString() +
        ' -> range=' + effectiveMeta.range + ', granularity=' + effectiveMeta.granularity +
        ', intraday=' + (effectiveMeta.intraday ? 'true' : 'false'));

    Uri _buildUri() {
      final symbolPath = Uri.encodeComponent(symbol);
      final params = <String, String>{
        'range': effectiveMeta.range,
        'interval': effectiveMeta.granularity,
        'includePrePost': 'false',
        'events': 'div,splits',
        'lang': 'fr-FR',
        'region': 'FR',
      };
      if (_yahooCrumb != null && _yahooCrumb!.isNotEmpty) {
        params['crumb'] = _yahooCrumb!;
      }
      return Uri.parse(
        _chartEndpoint + '/$symbolPath',
      ).replace(queryParameters: params);
    }

    Future<http.Response> _doRequest() {
      final freshCookie = _buildCookieHeader();
      if (freshCookie == null || freshCookie.isEmpty) {
        return Future.error(FinanceRequestException('consent_required'));
      }
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
        'User-Agent': _baseHeaders['User-Agent']!,
        'Referer': 'https://finance.yahoo.com/quote/$symbol',
        'Connection': 'keep-alive',
        'Cookie': freshCookie,
      };
      final uri = _buildUri();
      _log('Chart request URI: ' + uri.toString());
      return http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
    }

    http.Response res;
    try {
      res = await _doRequest();
    } on FinanceRequestException {
      rethrow;
    } on TimeoutException {
      _log('Chart request timeout for ' + symbol);
      throw FinanceRequestException(
        'Données graphiques indisponibles (timeout).',
      );
    } catch (e) {
      _log('Chart request error: ' + e.toString());
      throw FinanceRequestException('Données graphiques indisponibles.');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      final preview =
          res.body.isNotEmpty
              ? res.body.substring(
                0,
                res.body.length > 300 ? 300 : res.body.length,
              )
              : '';
      _log(
        'Received ' +
            res.statusCode.toString() +
            ' from chart. Body: ' +
            preview,
      );
      _yahooCookie = null;
      _yahooCrumb = null;
      _yahooCookieExpiry = null;
      await _bootstrapCookies();
      try {
        await _refreshCrumb(force: true);
      } catch (e) {
        _log('refreshCrumb (chart, retry) error: ' + e.toString());
      }
      try {
        res = await _doRequest();
      } on FinanceRequestException {
        rethrow;
      } on TimeoutException {
        _log('Chart request timeout (retry) for ' + symbol);
        throw FinanceRequestException(
          'Données graphiques indisponibles (timeout).',
        );
      }
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw FinanceRequestException(
        'consent_required',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode != 200) {
      final preview =
          res.body.isNotEmpty
              ? res.body.substring(
                0,
                res.body.length > 200 ? 200 : res.body.length,
              )
              : '';
      _log(
        'Chart non-200 for ' +
            symbol +
            ': ' +
            res.statusCode.toString() +
            ' -> ' +
            preview,
      );
      throw FinanceRequestException(
        'Données graphiques indisponibles (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      _log('Chart JSON decode error: ' + e.toString());
      throw FinanceRequestException('Réponse graphique Yahoo invalide.');
    }

    final chart = decoded is Map<String, dynamic> ? decoded['chart'] : null;
    final results = chart is Map<String, dynamic> ? chart['result'] : null;
    if (results is! List || results.isEmpty) {
      _log('Chart result empty for ' + symbol);
      return const <HistoricalPoint>[];
    }

    final first = results.first;
    if (first is! Map<String, dynamic>) {
      _log('Unexpected chart payload for ' + symbol);
      return const <HistoricalPoint>[];
    }

    final timestamps = first['timestamp'];
    if (timestamps is! List) {
      _log('No timestamps in chart payload for ' + symbol);
      return const <HistoricalPoint>[];
    }
    _log('Chart payload lengths -> timestamps=' + timestamps.length.toString());

    Map<String, dynamic>? _asMap(dynamic value) =>
        value is Map<String, dynamic> ? value : null;

    List<dynamic>? quoteCloses;
    List<dynamic>? adjCloses;
    final indicators = _asMap(first['indicators']);
    if (indicators != null) {
      final quoteList = indicators['quote'];
      if (quoteList is List && quoteList.isNotEmpty) {
        final quote = _asMap(quoteList.first);
        if (quote != null && quote['close'] is List) {
          quoteCloses = (quote['close'] as List).toList();
        }
      }
      if (indicators['adjclose'] is List) {
        final adj = indicators['adjclose'] as List;
        if (adj.isNotEmpty) {
          final firstAdj = _asMap(adj.first);
          if (firstAdj != null && firstAdj['adjclose'] is List) {
            adjCloses = (firstAdj['adjclose'] as List).toList();
          }
        }
      }
    }

    bool _hasUsableValues(List<dynamic>? source) {
      if (source == null || source.isEmpty) return false;
      for (final value in source) {
        if (value is num && value.isFinite) return true;
        if (value is String && double.tryParse(value) != null) {
          return true;
        }
      }
      return false;
    }

    if (!_hasUsableValues(quoteCloses) && !_hasUsableValues(adjCloses)) {
      _log('No close series in chart payload for ' + symbol);
      return const <HistoricalPoint>[];
    }
    _log('Series availability -> hasQuoteCloses=' + _hasUsableValues(quoteCloses).toString() +
        ', hasAdjCloses=' + _hasUsableValues(adjCloses).toString());

    final metaSection = _asMap(first['meta']);
    final gmtoffset =
        metaSection != null && metaSection['gmtoffset'] is num
            ? (metaSection['gmtoffset'] as num).toInt()
            : null;

    double? _valueAt(List<dynamic>? source, int index) {
      if (source == null || index >= source.length) return null;
      final raw = source[index];
      if (raw == null) return null;
      if (raw is num) {
        return raw.isFinite ? raw.toDouble() : null;
      }
      if (raw is String) {
        return double.tryParse(raw);
      }
      return null;
    }

    final points = <HistoricalPoint>[];
    final seenEpochMillis = <int>{};
    double? lastClose;
    for (var i = 0; i < timestamps.length; i++) {
      final rawTs = timestamps[i];
      if (rawTs == null) continue;
      final ts = rawTs is num ? rawTs.toInt() : int.tryParse(rawTs.toString());
      if (ts == null) continue;
      final close =
          _valueAt(quoteCloses, i) ??
          _valueAt(adjCloses, i) ??
          lastClose; // carry forward last known value when gaps exist
      if (close == null) continue;
      lastClose = close;
      var time = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
      if (gmtoffset != null) {
        time = time.add(Duration(seconds: gmtoffset));
      } else {
        time = time.toLocal();
      }
      // Deduplicate potential duplicate timestamps that can appear in payload.
      final epochMillis = time.millisecondsSinceEpoch;
      if (seenEpochMillis.add(epochMillis)) {
        points.add(HistoricalPoint(time: time, close: close));
      }
    }

    _log('Built raw points: ' + points.length.toString() +
        (points.isNotEmpty ? (' first=' + points.first.time.toIso8601String() + ' last=' + points.last.time.toIso8601String()) : ''));

    points.sort((a, b) => a.time.compareTo(b.time));

    // Window to the selected interval and extend to current time for a complete chart
    final windowed = _applyIntervalWindowAndExtend(points, interval);

    // Continue with optional downsampling on the windowed data
    var series = windowed;

    _log('Windowed series for ' + interval.toString() + ': ' + series.length.toString() +
        (series.isNotEmpty ? (' first=' + series.first.time.toIso8601String() + ' last=' + series.last.time.toIso8601String()) : ''));
    if (series.length <= 1) {
      _log('WARNING: Only ' + series.length.toString() + ' point(s) after windowing. ' +
          'This usually means Yahoo returned very sparse data for the selected interval.');
    }

    if (series.length > 600) {
      final step = (series.length / 600).ceil();
      final reduced = <HistoricalPoint>[];
      for (var i = 0; i < series.length; i += step) {
        reduced.add(series[i]);
      }
      if (reduced.isNotEmpty && reduced.last.time != series.last.time) {
        reduced.add(series.last);
      }
      return reduced;
    }

    return series;
  }

  /// Tip: if you are behind EU consent, call once at app startup with a cookie captured
  /// from a real browser session after accepting consent, e.g.:
  /// YahooFinanceService.setYahooCookieOverride('A1=...; A3=...; GUCS=...');
  static Future<QuoteDetail> _fetchQuoteFromYahoo(String symbol) async {
    // Ensure cookie + crumb from Yahoo (best-effort)
    try {
      await _ensureYahooAuth(symbol);
    } on FinanceRequestException {
      rethrow;
    } catch (e) {
      _log('ensureYahooAuth error: ' + e.toString());
    }

    Future<http.Response> _doRequest({int host = 1}) {
      final endpoint =
          host == 1
              ? _quoteEndpoint
              : _quoteEndpoint.replaceFirst('query1', 'query2');
      final baseUrl = '$endpoint?symbols=${Uri.encodeComponent(symbol)}';
      final uri =
          (_yahooCrumb != null && _yahooCrumb!.isNotEmpty)
              ? Uri.parse('$baseUrl&crumb=${Uri.encodeComponent(_yahooCrumb!)}')
              : Uri.parse(baseUrl);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
        'User-Agent': _baseHeaders['User-Agent']!,
        'Referer': 'https://finance.yahoo.com/quote/$symbol',
        'Connection': 'keep-alive',
      };
      final cookieToUse = _buildCookieHeader();
      if (cookieToUse != null && cookieToUse.isNotEmpty) {
        headers['Cookie'] = cookieToUse;
      }
      _log(
        'Requesting quote (query' + host.toString() + '): ' + uri.toString(),
      );
      _log(
        'Cookie present: ' +
            ((headers['Cookie']?.isNotEmpty ?? false) ? 'yes' : 'no'),
      );
      return http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
    }

    http.Response res = await _doRequest(host: 1);
    _log('Quote response status: ' + res.statusCode.toString());

    if (res.statusCode == 401 || res.statusCode == 403) {
      final preview =
          res.body.isNotEmpty
              ? res.body.substring(
                0,
                res.body.length > 300 ? 300 : res.body.length,
              )
              : '';
      _log(
        'Received ' +
            res.statusCode.toString() +
            ' from query1. Body (preview): ' +
            preview,
      );
      _log('Refreshing cookies via bootstrap and switching to query2...');
      _yahooCookie = null;
      _yahooCrumb = null;
      _yahooCookieExpiry = null;
      await _bootstrapCookies();
      try {
        await _refreshCrumb(force: true);
      } on FinanceRequestException catch (e) {
        if (e.message == 'crumb_unavailable') {
          _log(
            'Crumb still unavailable after bootstrap, using HTML fallback...',
          );
          await _collectCrumbFromHtml(symbol);
        } else {
          rethrow;
        }
      }
      // Try again on query2
      res = await _doRequest(host: 2);
      _log('Query2 response status: ' + res.statusCode.toString());
    }

    if (res.statusCode != 200) {
      final preview =
          res.body.isNotEmpty
              ? res.body.substring(
                0,
                res.body.length > 300 ? 300 : res.body.length,
              )
              : '';
      _log(
        'Non-200 after retry. Status: ' +
            res.statusCode.toString() +
            ' Body (preview): ' +
            preview,
      );

      // Try HTML parsing fallback from the quote page (still Yahoo) before failing
      try {
        return await _fetchQuoteFromHtml(symbol);
      } catch (e) {
        _log('HTML fallback failed: ' + e.toString());
      }

      throw FinanceRequestException(
        'Impossible de récupérer le cours (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      _log('JSON decode error: ' + e.toString());
      throw FinanceRequestException('Réponse Yahoo invalide.');
    }

    final quoteResponse =
        decoded is Map<String, dynamic> ? decoded['quoteResponse'] : null;
    final results =
        quoteResponse is Map<String, dynamic> ? quoteResponse['result'] : null;

    if (results is! List || results.isEmpty) {
      _log('Quote not found for ' + symbol);
      throw QuoteNotFoundException(symbol);
    }

    final map = results.first;
    if (map is! Map<String, dynamic>) {
      _log('Unexpected payload for ' + symbol);
      throw QuoteNotFoundException(symbol);
    }

    final quote = QuoteDetail.fromJson(map);
    if (!quote.hasCoreData) {
      _log('No core data in quote for ' + symbol);
      throw QuoteNotFoundException(symbol);
    }

    _log(
      'Quote OK for ' +
          symbol +
          ' @ ' +
          (quote.regularMarketPrice?.toString() ?? 'n/a'),
    );
    return quote;
  }


// ====== REMOVED DUPLICATE METHODS BELOW ======

// (Removed duplicate fetchChartSeries(String symbol, {String range, String interval}) and
// duplicate fetchHistoricalSeries(String symbol, {String range, String interval}) methods.)
}

class QuoteNotFoundException implements Exception {
  QuoteNotFoundException(this.symbol);
  final String symbol;

  @override
  String toString() => "Aucune donnée trouvée pour '$symbol'.";
}

class FinanceRequestException implements Exception {
  FinanceRequestException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TickerSearchResult {
  TickerSearchResult({
    required this.symbol,
    required this.displayName,
    required this.exchange,
    required this.quoteType,
    required this.region,
    required this.currency,
  });

  final String symbol;
  final String displayName;
  final String exchange;
  final String quoteType;
  final String region;
  final String currency;

  bool get isEquity => quoteType.toUpperCase() == 'EQUITY';
  bool get isEtf => quoteType.toUpperCase() == 'ETF';
  bool get isSupportedInstrument => isEquity || isEtf;

  bool get isSupportedExchange {
    final up = exchange.toUpperCase();
    const euronext = {
      'EURONEXT',
      'PARIS',
      'AMSTERDAM',
      'BRUSSELS',
      'LISBON',
      'DUBLIN',
      'OSLO',
      'MILAN',
    };
    if (up.contains('NASDAQ')) return true;
    if (up.contains('NYSE')) return true;
    if (up.contains('SNP')) return true;
    if (euronext.any((name) => up.contains(name))) return true;

    final symbolUp = symbol.toUpperCase();
    const suffixes = ['.PA', '.AS', '.BR', '.LS', '.IR', '.OL', '.MI'];
    if (suffixes.any(symbolUp.endsWith)) return true;
    return false;
  }

  static TickerSearchResult? tryFromJson(Map<String, dynamic> json) {
    final rawSymbol = (json['symbol'] ?? '').toString().trim();
    if (rawSymbol.isEmpty) return null;
    final type = (json['quoteType'] ?? json['type'] ?? '').toString();
    final name =
        (json['longname'] ??
                json['longName'] ??
                json['shortname'] ??
                json['shortName'] ??
                json['name'] ??
                '')
            .toString();
    final exchange =
        (json['exchDisp'] ??
                json['exchangeDisplay'] ??
                json['fullExchangeName'] ??
                json['exchange'] ??
                '')
            .toString();
    final region = (json['region'] ?? '').toString();
    final currency = (json['currency'] ?? '').toString();

  final result = TickerSearchResult(
    symbol: rawSymbol,
    displayName: name.isEmpty ? rawSymbol : name,
    exchange: exchange,
    quoteType: type.isEmpty ? 'UNKNOWN' : type,
      region: region,
      currency: currency,
  );

    if (!result.isSupportedInstrument || !result.isSupportedExchange) return null;
    return result;
  }
}

class QuoteDetail {
  QuoteDetail({
    required this.symbol,
    required this.shortName,
    required this.longName,
    required this.exchange,
    required this.fullExchangeName,
    required this.currency,
    required this.regularMarketPrice,
    required this.regularMarketChange,
    required this.regularMarketChangePercent,
    required this.regularMarketDayHigh,
    required this.regularMarketDayLow,
    required this.fiftyTwoWeekHigh,
    required this.fiftyTwoWeekLow,
    required this.marketCap,
    required this.regularMarketVolume,
    required this.averageDailyVolume3Month,
    required this.regularMarketTime,
    required this.trailingPE,
    required this.forwardPE,
    required this.epsTrailingTwelveMonths,
    required this.dividendYield,
    required this.previousClose,
    required this.open,
    this.quoteType,
  });

  final String symbol;
  final String? shortName;
  final String? longName;
  final String? exchange;
  final String? fullExchangeName;
  final String? currency;
  final String? quoteType;
  final double? regularMarketPrice;
  final double? regularMarketChange;
  final double? regularMarketChangePercent;
  final double? regularMarketDayHigh;
  final double? regularMarketDayLow;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final double? marketCap;
  final double? regularMarketVolume;
  final double? averageDailyVolume3Month;
  final DateTime? regularMarketTime;
  final double? trailingPE;
  final double? forwardPE;
  final double? epsTrailingTwelveMonths;
  final double? dividendYield;
  final double? previousClose;
  final double? open;

  bool get hasCoreData =>
      (regularMarketPrice != null) ||
      (longName != null && longName!.isNotEmpty) ||
      (shortName != null && shortName!.isNotEmpty);

  factory QuoteDetail.fromJson(Map<String, dynamic> json) {
    DateTime? marketTime;
    final rawTime = json['regularMarketTime'];
    if (rawTime is num) {
      marketTime = DateTime.fromMillisecondsSinceEpoch(
        rawTime.toInt() * 1000,
        isUtc: true,
      );
    }

    double? _toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    }

    return QuoteDetail(
      symbol: (json['symbol'] ?? '').toString(),
      shortName: (json['shortName'] ?? json['displayName'])?.toString(),
      longName: (json['longName'] ?? json['displayName'])?.toString(),
      exchange: (json['exchange'] ?? json['market'])?.toString(),
      fullExchangeName:
          (json['fullExchangeName'] ?? json['exchDisp'])?.toString(),
      currency: (json['currency'] ?? json['financialCurrency'])?.toString(),
      quoteType: (json['quoteType'] ?? json['type'])?.toString(),
      regularMarketPrice: _toDouble(json['regularMarketPrice']),
      regularMarketChange: _toDouble(json['regularMarketChange']),
      regularMarketChangePercent: _toDouble(json['regularMarketChangePercent']),
      regularMarketDayHigh: _toDouble(json['regularMarketDayHigh']),
      regularMarketDayLow: _toDouble(json['regularMarketDayLow']),
      fiftyTwoWeekHigh: _toDouble(json['fiftyTwoWeekHigh']),
      fiftyTwoWeekLow: _toDouble(json['fiftyTwoWeekLow']),
      marketCap: _toDouble(json['marketCap']),
      regularMarketVolume: _toDouble(json['regularMarketVolume']),
      averageDailyVolume3Month: _toDouble(json['averageDailyVolume3Month']),
      regularMarketTime: marketTime,
      trailingPE: _toDouble(json['trailingPE']),
      forwardPE: _toDouble(json['forwardPE']),
      epsTrailingTwelveMonths: _toDouble(json['epsTrailingTwelveMonths']),
      dividendYield: _toDouble(json['dividendYield']),
      previousClose: _toDouble(
        json['regularMarketPreviousClose'] ?? json['previousClose'],
      ),
      open: _toDouble(json['regularMarketOpen'] ?? json['open']),
    );
  }
}
