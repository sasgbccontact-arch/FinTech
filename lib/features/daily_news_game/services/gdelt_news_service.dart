import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/news_article.dart';
import '../utils/news_text_sanitizer.dart';

class DailyNewsFetchResult {
  final List<NewsArticle> articles;
  final String sourceType;
  final String lang;
  final List<String> queriesTried;
  final int bestScore;

  const DailyNewsFetchResult({
    required this.articles,
    required this.sourceType,
    required this.lang,
    required this.queriesTried,
    required this.bestScore,
  });
}

class CountryNewsFetchResult {
  final NewsArticle? article;
  final String sourceType;
  final String lang;
  final String? queryUsed;
  final List<String> queriesTried;
  final int bestScore;

  const CountryNewsFetchResult({
    required this.article,
    required this.sourceType,
    required this.lang,
    required this.queryUsed,
    required this.queriesTried,
    required this.bestScore,
  });
}

class _GdeltRequestResult {
  final List<NewsArticle> articles;
  final bool rateLimited;
  final bool timedOut;
  final bool nonJson;
  final bool queryTooLong;

  const _GdeltRequestResult({
    required this.articles,
    this.rateLimited = false,
    this.timedOut = false,
    this.nonJson = false,
    this.queryTooLong = false,
  });
}

class _ScoredArticle {
  final NewsArticle article;
  final int score;

  const _ScoredArticle(this.article, this.score);
}

class GdeltNewsService {
  static const _baseUrl = 'https://api.gdeltproject.org/api/v2/doc/doc';

  static const _primaryQuery =
      '(economy OR inflation OR "central bank" OR recession OR geopolitics OR oil OR sanctions OR war) sourcelang:english';

  static const _fallbackQuery =
      '(economy OR inflation OR rates OR oil OR sanctions OR war)';

  static const _financeKeywordsShortEn =
      '(stocks OR equity OR market OR investing OR inflation OR rates OR "central bank" OR earnings OR GDP OR oil)';

  static const _financeKeywordsShortFr =
      '(bourse OR actions OR marchés OR investissement OR inflation OR taux OR "banque centrale" OR résultats OR PIB OR pétrole)';

  static const _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'fintech-app/1.0 (Flutter)',
    'Connection': 'close',
  };

  static const _reliableSources = <String>[
    'reuters',
    'bloomberg',
    'financial times',
    'ft.com',
    'wsj',
    'wall street journal',
    'associated press',
    'ap news',
    'les echos',
    'le monde',
    'bbc',
    'cnbc',
    'marketwatch',
  ];

  static const _financeSignals = <String>[
    'stock',
    'stocks',
    'equity',
    'market',
    'markets',
    'invest',
    'investment',
    'investing',
    'inflation',
    'rate',
    'rates',
    'central bank',
    'earnings',
    'revenue',
    'profit',
    'gdp',
    'recession',
    'bond',
    'yield',
    'oil',
    'commodities',
    'forex',
    'bourse',
    'actions',
    'marché',
    'marchés',
    'investissement',
    'banque centrale',
    'résultats',
    'bénéfices',
    'pib',
    'pétrole',
    'matières premières',
  ];

  static const _badSignals = <String>[
    'celebrity',
    'movie',
    'music',
    'sport',
    'sports',
    'fashion',
    'recipe',
    'gaming',
    'viral',
  ];

  static const _vagueSignals = <String>[
    'what to know',
    'live updates',
    'morning news',
    'top stories',
    'must watch',
    'breaking news',
  ];

  Future<List<NewsArticle>> fetchRecentArticles({int limit = 3}) async {
    final result = await fetchRecentArticlesFast(limit: limit);
    return result.articles;
  }

  Future<DailyNewsFetchResult> fetchRecentArticlesFast({int limit = 3}) async {
    final sw = Stopwatch()..start();
    final clampedLimit = limit.clamp(1, 5);
    final queriesTried = <String>[];

    final gdeltPrimary = await _requestGdelt(
      query: _primaryQuery,
      maxrecords: 8,
      timeout: const Duration(seconds: 8),
      perfLabel: '[NewsPerf][Actus][GDELT][primary]',
    );
    queriesTried.add('gdelt_primary_8s');

    var selected = _selectTopScored(
      gdeltPrimary.articles,
      expectedLang: 'en',
      limit: clampedLimit,
    );

    if (selected.isNotEmpty) {
      sw.stop();
      final bestScore = _scoreGeneral(selected.first, expectedLang: 'en');
      debugPrint(
        '[NewsPerf][Actus][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=gdelt bestScore=$bestScore',
      );
      return DailyNewsFetchResult(
        articles: selected,
        sourceType: 'gdelt',
        lang: 'en',
        queriesTried: queriesTried,
        bestScore: bestScore,
      );
    }

    final shouldSkipSecondGdelt =
        gdeltPrimary.rateLimited ||
        gdeltPrimary.timedOut ||
        gdeltPrimary.queryTooLong;

    if (!shouldSkipSecondGdelt) {
      final gdeltRetry = await _requestGdelt(
        query: _fallbackQuery,
        maxrecords: 8,
        timeout: const Duration(seconds: 12),
        perfLabel: '[NewsPerf][Actus][GDELT][retry]',
      );
      queriesTried.add('gdelt_fallback_12s');

      selected = _selectTopScored(
        gdeltRetry.articles,
        expectedLang: 'en',
        limit: clampedLimit,
      );

      if (selected.isNotEmpty) {
        sw.stop();
        final bestScore = _scoreGeneral(selected.first, expectedLang: 'en');
        debugPrint(
          '[NewsPerf][Actus][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=gdelt_retry bestScore=$bestScore',
        );
        return DailyNewsFetchResult(
          articles: selected,
          sourceType: 'gdelt_retry',
          lang: 'en',
          queriesTried: queriesTried,
          bestScore: bestScore,
        );
      }
    }

    final rss = await _fetchFromGoogleNewsRss(
      limit: 10,
      timeout: const Duration(seconds: 8),
      perfLabel: '[NewsPerf][Actus][RSS]',
    );
    queriesTried.add('rss_en_8s');

    selected = _selectTopScored(rss, expectedLang: 'en', limit: clampedLimit);

    sw.stop();

    if (selected.isNotEmpty) {
      final bestScore = _scoreGeneral(selected.first, expectedLang: 'en');
      debugPrint(
        '[NewsPerf][Actus][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=rss bestScore=$bestScore',
      );
      return DailyNewsFetchResult(
        articles: selected,
        sourceType: 'rss',
        lang: 'en',
        queriesTried: queriesTried,
        bestScore: bestScore,
      );
    }

    debugPrint(
      '[NewsPerf][Actus][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=none bestScore=0',
    );

    return DailyNewsFetchResult(
      articles: const [],
      sourceType: 'none',
      lang: 'en',
      queriesTried: queriesTried,
      bestScore: 0,
    );
  }

  Future<NewsArticle?> fetchCountryArticle({
    required String countryIso2,
    required String countryNameEn,
  }) async {
    final result = await fetchCountryArticleFast(
      countryIso2: countryIso2,
      countryNameEn: countryNameEn,
    );
    return result.article;
  }

  Future<List<NewsArticle>> fetchCountryCandidates({
    required String countryIso2,
    required String countryNameEn,
    required String lang,
    int limit = 3,
  }) async {
    final iso2 = countryIso2.trim().toUpperCase();
    final nameEn = countryNameEn.trim();
    final baseCountry = '($nameEn OR $iso2)';
    final q =
        lang == 'fr'
            ? '$baseCountry $_financeKeywordsShortFr sourcelang:french'
            : '$baseCountry $_financeKeywordsShortEn sourcelang:english';

    final result = await _requestGdelt(
      query: q,
      maxrecords: 5,
      timeout: const Duration(seconds: 7),
      perfLabel: '[NewsPerf][Monde][$iso2][GDELT][$lang][candidates]',
    );

    final deduped = _dedupeByUrl(result.articles);
    if (deduped.length <= limit) return deduped;
    return deduped.take(limit).toList();
  }

  Future<CountryNewsFetchResult> fetchCountryArticleFast({
    required String countryIso2,
    required String countryNameEn,
  }) async {
    final sw = Stopwatch()..start();
    final iso2 = countryIso2.trim().toUpperCase();
    final nameEn = countryNameEn.trim();
    final queriesTried = <String>[];

    if (iso2.isEmpty || nameEn.isEmpty) {
      return const CountryNewsFetchResult(
        article: null,
        sourceType: 'none',
        lang: 'en',
        queryUsed: null,
        queriesTried: <String>[],
        bestScore: 0,
      );
    }

    final baseCountry = '($nameEn OR $iso2)';
    final queryEn = '$baseCountry $_financeKeywordsShortEn sourcelang:english';

    final enResult = await _requestGdelt(
      query: queryEn,
      maxrecords: 3,
      timeout: const Duration(seconds: 7),
      perfLabel: '[NewsPerf][Monde][$iso2][GDELT][en]',
    );
    queriesTried.add('gdelt_en_7s');

    final bestEn = _bestCountryCandidate(
      enResult.articles,
      countryNameEn: nameEn,
      countryIso2: iso2,
      expectedLang: 'en',
    );

    if (bestEn != null && bestEn.score >= 55) {
      sw.stop();
      debugPrint(
        '[NewsPerf][Monde][$iso2][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=gdelt score=${bestEn.score}',
      );
      return CountryNewsFetchResult(
        article: bestEn.article,
        sourceType: 'gdelt',
        lang: 'en',
        queryUsed: queryEn,
        queriesTried: queriesTried,
        bestScore: bestEn.score,
      );
    }

    final fastFallbackNeeded =
        enResult.rateLimited ||
        enResult.timedOut ||
        enResult.queryTooLong ||
        enResult.nonJson;

    if (!fastFallbackNeeded) {
      final queryFr = '$baseCountry $_financeKeywordsShortFr sourcelang:french';
      final frResult = await _requestGdelt(
        query: queryFr,
        maxrecords: 3,
        timeout: const Duration(seconds: 7),
        perfLabel: '[NewsPerf][Monde][$iso2][GDELT][fr]',
      );
      queriesTried.add('gdelt_fr_7s');

      final bestFr = _bestCountryCandidate(
        frResult.articles,
        countryNameEn: nameEn,
        countryIso2: iso2,
        expectedLang: 'fr',
      );

      if (bestFr != null && bestFr.score >= 55) {
        sw.stop();
        debugPrint(
          '[NewsPerf][Monde][$iso2][FR] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=gdelt score=${bestFr.score}',
        );
        return CountryNewsFetchResult(
          article: bestFr.article,
          sourceType: 'gdelt',
          lang: 'fr',
          queryUsed: queryFr,
          queriesTried: queriesTried,
          bestScore: bestFr.score,
        );
      }
    }

    final rssEnUrl = _buildGoogleNewsRssUrlForCountry(
      countryName: nameEn,
      countryIso2: iso2,
      lang: 'en-US',
      gl: 'US',
      ceid: 'US:en',
      keywords: 'market OR stocks OR investing OR inflation OR central bank',
    );
    final rssEn = await _fetchFromGoogleNewsRss(
      limit: 5,
      customRssUrl: rssEnUrl,
      timeout: const Duration(seconds: 8),
      perfLabel: '[NewsPerf][Monde][$iso2][RSS][en]',
    );
    queriesTried.add('rss_en_8s');

    final bestRssEn = _bestCountryCandidate(
      rssEn,
      countryNameEn: nameEn,
      countryIso2: iso2,
      expectedLang: 'en',
    );

    if (bestRssEn != null && bestRssEn.score >= 55) {
      sw.stop();
      debugPrint(
        '[NewsPerf][Monde][$iso2][EN] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=rss score=${bestRssEn.score}',
      );
      return CountryNewsFetchResult(
        article: bestRssEn.article,
        sourceType: 'rss',
        lang: 'en',
        queryUsed: 'rss_en',
        queriesTried: queriesTried,
        bestScore: bestRssEn.score,
      );
    }

    final rssFrUrl = _buildGoogleNewsRssUrlForCountry(
      countryName: nameEn,
      countryIso2: iso2,
      lang: 'fr-FR',
      gl: 'FR',
      ceid: 'FR:fr',
      keywords:
          'bourse OR marchés OR investissement OR inflation OR banque centrale',
    );
    final rssFr = await _fetchFromGoogleNewsRss(
      limit: 5,
      customRssUrl: rssFrUrl,
      timeout: const Duration(seconds: 8),
      perfLabel: '[NewsPerf][Monde][$iso2][RSS][fr]',
    );
    queriesTried.add('rss_fr_8s');

    final bestRssFr = _bestCountryCandidate(
      rssFr,
      countryNameEn: nameEn,
      countryIso2: iso2,
      expectedLang: 'fr',
    );

    sw.stop();

    if (bestRssFr != null && bestRssFr.score >= 55) {
      debugPrint(
        '[NewsPerf][Monde][$iso2][FR] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=rss score=${bestRssFr.score}',
      );
      return CountryNewsFetchResult(
        article: bestRssFr.article,
        sourceType: 'rss',
        lang: 'fr',
        queryUsed: 'rss_fr',
        queriesTried: queriesTried,
        bestScore: bestRssFr.score,
      );
    }

    debugPrint(
      '[NewsPerf][Monde][$iso2] cacheHit=false totalMs=${sw.elapsedMilliseconds} source=none score=0',
    );

    return CountryNewsFetchResult(
      article: null,
      sourceType: 'none',
      lang: 'en',
      queryUsed: null,
      queriesTried: queriesTried,
      bestScore: 0,
    );
  }

  _ScoredArticle? _bestCountryCandidate(
    List<NewsArticle> candidates, {
    required String countryNameEn,
    required String countryIso2,
    required String expectedLang,
  }) {
    final deduped = _dedupeByUrl(candidates);
    if (deduped.isEmpty) return null;

    final scored =
        deduped
            .map(
              (a) => _ScoredArticle(
                a,
                _scoreCountry(
                  a,
                  countryNameEn: countryNameEn,
                  countryIso2: countryIso2,
                  expectedLang: expectedLang,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.first;
  }

  List<NewsArticle> _selectTopScored(
    List<NewsArticle> candidates, {
    required String expectedLang,
    required int limit,
  }) {
    final deduped = _dedupeByUrl(candidates);
    final scored =
        deduped
            .map(
              (a) => _ScoredArticle(
                a,
                _scoreGeneral(a, expectedLang: expectedLang),
              ),
            )
            .where((s) => s.score >= 55)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(limit).map((s) => s.article).toList();
  }

  int _scoreCountry(
    NewsArticle article, {
    required String countryNameEn,
    required String countryIso2,
    required String expectedLang,
  }) {
    final text = _normalizedText(article);
    final hasFinance = _hasFinanceSignal(text);
    if (!hasFinance) return -100;
    if (_hasBadSignal(text)) return -100;

    var score = 0;

    final name = countryNameEn.toLowerCase();
    final iso = countryIso2.toLowerCase();
    if (text.contains(name) || RegExp('\\b$iso\\b').hasMatch(text)) {
      score += 40;
    }

    score += 25;

    if (_matchesExpectedLang(text, expectedLang: expectedLang)) {
      score += 15;
    }

    if (_isReliableSource(article.source)) {
      score += 10;
    }

    if (_hasCausalAngle(text)) {
      score += 10;
    }

    if (_hasVagueSignal(text)) {
      score -= 16;
    }

    return score;
  }

  int _scoreGeneral(NewsArticle article, {required String expectedLang}) {
    final text = _normalizedText(article);
    final hasFinance = _hasFinanceSignal(text);
    if (!hasFinance) return -100;
    if (_hasBadSignal(text)) return -100;

    var score = 25;

    if (_matchesExpectedLang(text, expectedLang: expectedLang)) {
      score += 15;
    }

    if (_isReliableSource(article.source)) {
      score += 10;
    }

    final ageHours =
        DateTime.now().difference(article.publishedAt.toLocal()).inHours;
    if (ageHours <= 48) {
      score += 20;
    } else if (ageHours <= 72) {
      score += 8;
    } else {
      score -= 8;
    }

    if ((article.snippet ?? '').trim().isNotEmpty) {
      score += 8;
    }

    if (_hasCausalAngle(text)) {
      score += 10;
    }

    if (_hasVagueSignal(text)) {
      score -= 16;
    }

    return score;
  }

  bool _hasFinanceSignal(String text) {
    return _financeSignals.any(text.contains);
  }

  bool _hasBadSignal(String text) {
    return _badSignals.any(text.contains);
  }

  bool _hasVagueSignal(String text) {
    return _vagueSignals.any(text.contains);
  }

  bool _hasCausalAngle(String text) {
    return <String>[
      'because',
      'after',
      'amid',
      'following',
      'due to',
      'on fears',
      'on hopes',
      'après',
      'en raison',
      'face à',
    ].any(text.contains);
  }

  bool _isReliableSource(String source) {
    final s = source.toLowerCase();
    return _reliableSources.any(s.contains);
  }

  bool _matchesExpectedLang(String text, {required String expectedLang}) {
    if (expectedLang == 'fr') {
      return RegExp(
        r'\b(le|la|les|des|une|avec|pour|sur|banque|marché|économie)\b',
      ).hasMatch(text);
    }
    return RegExp(
      r'\b(the|and|for|with|market|economy|bank|inflation)\b',
    ).hasMatch(text);
  }

  String _normalizedText(NewsArticle article) {
    return '${_sanitizeText(article.title)} ${_sanitizeText(article.snippet ?? '')}'
        .toLowerCase();
  }

  List<NewsArticle> _dedupeByUrl(List<NewsArticle> articles) {
    final map = <String, NewsArticle>{};
    for (final article in articles) {
      final cleanTitle = _sanitizeText(article.title).toLowerCase();
      final key =
          '${article.url.trim().toLowerCase()}|$cleanTitle|${article.source.toLowerCase()}';
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => article);
    }
    return map.values.toList();
  }

  Future<_GdeltRequestResult> _requestGdelt({
    required String query,
    required int maxrecords,
    required Duration timeout,
    required String perfLabel,
  }) async {
    final sw = Stopwatch()..start();

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'query': query,
          'mode': 'artlist',
          'maxrecords': maxrecords.toString(),
          'format': 'json',
          'timespan': '1w',
          'sort': 'DateDesc',
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(timeout);

      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        if (retryAfter != null && retryAfter > 0) {
          final waitSec = retryAfter.clamp(1, 6);
          await Future<void>.delayed(Duration(seconds: waitSec));
        }

        sw.stop();
        debugPrint('$perfLabel status=429 ms=${sw.elapsedMilliseconds}');
        return const _GdeltRequestResult(
          articles: <NewsArticle>[],
          rateLimited: true,
        );
      }

      if (response.statusCode != 200) {
        final body = response.body.toLowerCase();
        final queryTooLong = body.contains('query') && body.contains('long');

        sw.stop();
        debugPrint(
          '$perfLabel status=${response.statusCode} ms=${sw.elapsedMilliseconds} queryTooLong=$queryTooLong',
        );

        return _GdeltRequestResult(
          articles: const <NewsArticle>[],
          queryTooLong: queryTooLong,
        );
      }

      final parsed = _parseArticles(response.body);
      sw.stop();

      debugPrint(
        '$perfLabel status=200 ms=${sw.elapsedMilliseconds} count=${parsed.length}',
      );

      return _GdeltRequestResult(
        articles: parsed,
        nonJson: parsed.isEmpty && !_looksLikeJson(response.body),
      );
    } on Exception catch (e) {
      sw.stop();
      final timedOut = e.toString().toLowerCase().contains('timeout');
      debugPrint(
        '$perfLabel error="$e" ms=${sw.elapsedMilliseconds} timedOut=$timedOut',
      );
      return _GdeltRequestResult(
        articles: const <NewsArticle>[],
        timedOut: timedOut,
      );
    }
  }

  bool _looksLikeJson(String body) {
    final trimmed = body.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  List<NewsArticle> _parseArticles(String rawBody) {
    final body = rawBody.trim();
    if (body.isEmpty || body == 'null') {
      return [];
    }

    if (!_looksLikeJson(body)) {
      return [];
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return [];
      }
      data = decoded;
    } catch (_) {
      return [];
    }

    final rawList = data['articles'];
    if (rawList is! List) {
      return [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((m) {
          try {
            return NewsArticle.fromGdelt(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<NewsArticle>()
        .map(
          (article) => NewsArticle(
            id: article.id,
            title: _sanitizeText(article.title),
            url: article.url,
            source: article.source,
            publishedAt: article.publishedAt,
            snippet:
                article.snippet == null
                    ? null
                    : _sanitizeText(article.snippet!),
          ),
        )
        .where((a) => a.title.isNotEmpty && a.url.isNotEmpty)
        .toList();
  }

  static const _googleNewsRssUrl =
      'https://news.google.com/rss/search?q=(economy%20OR%20inflation%20OR%20rates%20OR%20oil%20OR%20sanctions%20OR%20war)%20when:7d&hl=en-US&gl=US&ceid=US:en';

  String _buildGoogleNewsRssUrlForCountry({
    required String countryName,
    required String countryIso2,
    required String lang,
    required String gl,
    required String ceid,
    required String keywords,
  }) {
    final q = '($countryName OR $countryIso2) $keywords when:7d';
    final encoded = Uri.encodeComponent(q);
    return 'https://news.google.com/rss/search?q=$encoded&hl=$lang&gl=$gl&ceid=$ceid';
  }

  Future<List<NewsArticle>> _fetchFromGoogleNewsRss({
    required int limit,
    String? customRssUrl,
    required Duration timeout,
    required String perfLabel,
  }) async {
    final sw = Stopwatch()..start();

    try {
      final uri = Uri.parse(customRssUrl ?? _googleNewsRssUrl);
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/rss+xml, application/xml, text/xml, */*',
              'User-Agent': _headers['User-Agent']!,
              'Connection': 'close',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        sw.stop();
        debugPrint(
          '$perfLabel status=${response.statusCode} ms=${sw.elapsedMilliseconds}',
        );
        return const [];
      }

      final parsed = _parseGoogleNewsRss(response.body);
      sw.stop();
      debugPrint(
        '$perfLabel status=200 ms=${sw.elapsedMilliseconds} count=${parsed.length}',
      );

      if (parsed.length <= limit) return parsed;
      return parsed.take(limit).toList();
    } catch (e) {
      sw.stop();
      debugPrint('$perfLabel error="$e" ms=${sw.elapsedMilliseconds}');
      return const [];
    }
  }

  List<NewsArticle> _parseGoogleNewsRss(String rawXml) {
    final xml = rawXml.trim();
    if (xml.isEmpty) return [];

    final items = <NewsArticle>[];

    final itemRegex = RegExp(r'<item>([\s\S]*?)</item>', multiLine: true);
    final titleRegex = RegExp(
      r'<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</title>',
    );
    final linkRegex = RegExp(r'<link>([\s\S]*?)</link>');
    final pubDateRegex = RegExp(r'<pubDate>([\s\S]*?)</pubDate>');
    final sourceRegex = RegExp(
      r'<source[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</source>',
    );
    final descRegex = RegExp(
      r'<description>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</description>',
    );

    for (final m in itemRegex.allMatches(xml)) {
      final chunk = m.group(1) ?? '';

      final title = (titleRegex.firstMatch(chunk)?.group(1) ?? '').trim();
      final link = (linkRegex.firstMatch(chunk)?.group(1) ?? '').trim();
      if (title.isEmpty || link.isEmpty) continue;

      final pubRaw = (pubDateRegex.firstMatch(chunk)?.group(1) ?? '').trim();
      DateTime publishedAt;
      try {
        publishedAt =
            pubRaw.isNotEmpty ? HttpDate.parse(pubRaw) : DateTime.now();
      } catch (_) {
        publishedAt = DateTime.now();
      }

      String source = (sourceRegex.firstMatch(chunk)?.group(1) ?? '').trim();
      if (source.isEmpty) {
        final parts = title.split(' - ');
        if (parts.length >= 2) source = parts.last.trim();
      }
      if (source.isEmpty) source = 'Google News';

      String? snippet = (descRegex.firstMatch(chunk)?.group(1) ?? '').trim();
      if (snippet.isNotEmpty) {
        snippet = snippet.replaceAll(RegExp(r'<[^>]+>'), ' ');
        snippet = _sanitizeText(snippet);
        if (snippet.isEmpty) snippet = null;
      } else {
        snippet = null;
      }

      items.add(
        NewsArticle.fromRss(
          title: _sanitizeText(title),
          url: link,
          publishedAt: publishedAt,
          source: source,
          snippet: snippet,
        ),
      );

      if (items.length >= 10) break;
    }

    return items.where((a) => a.title.isNotEmpty && a.url.isNotEmpty).toList();
  }

  String _sanitizeText(String raw) {
    return sanitizeNewsGameText(raw);
  }
}
