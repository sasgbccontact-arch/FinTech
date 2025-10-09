import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/yahoo_finance_service.dart'; // pour setYahooCookieOverride

class YahooConsentPage extends StatefulWidget {
  const YahooConsentPage({super.key, this.symbol = 'AAPL'});
  final String symbol;

  @override
  State<YahooConsentPage> createState() => _YahooConsentPageState();
}

class _YahooConsentPageState extends State<YahooConsentPage> {
  final CookieManager _cookies = CookieManager.instance();
  bool _done = false;
  Timer? _pollTimer;
  Uri? _lastUrl;

  static const bool _debug = true; // set false in prod if needed
  void _log(String m) {
    if (_debug) print('[YahooConsentPage] $m');
  }

  static const _domains = [
    'finance.yahoo.com',
    'yahoo.com',
    'guce.yahoo.com',
    'consent.yahoo.com',
  ];

  @override
  void initState() {
    super.initState();
    // Clear old Yahoo consent cookies to avoid instant redirects/auto-closing
    _clearYahooCookies();
  }

  Future<void> _clearYahooCookies() async {
    for (final d in _domains) {
      try {
        await _cookies.deleteCookies(url: WebUri('https://$d'));
      } catch (_) {}
    }
    _log('Cleared Yahoo cookies for domains: ${_domains.join(', ')}');
  }

  Uri get _startUrl => Uri.parse(
    'https://finance.yahoo.com/quote/${Uri.encodeComponent(widget.symbol)}?guccounter=1',
  );

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // Essaie d’agréger les cookies utiles (A1, A3, GUCS, etc.)
  Future<String?> _collectCookieHeader() async {
    _log('Collecting cookies from WebView store...');
    final buf = <String>[];
    for (final d in _domains) {
      final list = await _cookies.getCookies(url: WebUri('https://$d'));
      _log(
        'Domain ' +
            d +
            ' -> ' +
            list.length.toString() +
            ' cookies: ' +
            (list.isEmpty
                ? '[]'
                : list.map((c) => c.name).take(10).join(', ') +
                    (list.length > 10 ? ' ...' : '')),
      );
      for (final c in list) {
        // on garde les paires NAME=VALUE
        if (c.name.isNotEmpty && c.value.isNotEmpty) {
          buf.add('${c.name}=${c.value}');
        }
      }
    }
    if (buf.isEmpty) return null;

    // Déduplique grossièrement (même nom -> dernière valeur gardée)
    final map = <String, String>{};
    for (final kv in buf) {
      final i = kv.indexOf('=');
      if (i > 0) map[kv.substring(0, i)] = kv.substring(i + 1);
    }
    // optionnel: on ne garde que certains cookies, mais garder large est ok
    final ordered = map.entries.map((e) => '${e.key}=${e.value}').toList();
    final header = ordered.join('; ');
    _log('Aggregated cookie header length: ' + header.length.toString());
    _log(
      'Cookie header preview: ' +
          (header.length > 220 ? header.substring(0, 220) + '...' : header),
    );
    return header;
  }

  // Quand on pense que l’utilisateur a accepté, on tente de lire les cookies
  Future<void> _tryFinish() async {
    if (_done) return;

    final host = _lastUrl?.host.toLowerCase() ?? '';
    const consentHosts = {
      'consent.yahoo.com',
      'guce.yahoo.com',
      'login.yahoo.com',
      'accounts.yahoo.com',
      'account.yahoo.com',
      'guce.yahoo.net',
      'yahoo.mydashboard.oath.com',
    };
    if (host.isNotEmpty && consentHosts.any((value) => host.contains(value))) {
      _log('Still on consent/identity host ($host); waiting for user action.');
      return;
    }

    final header = await _collectCookieHeader();
    if (header == null) return;

    // Heuristique: présence des cookies clés
    final up = header.toUpperCase();
    final hasCore =
        up.contains('A1=') ||
        up.contains('A3=') ||
        up.contains('GUCS=') ||
        up.contains('GUC=');
    if (!hasCore) return;

    _log('Setting override with cookie length: ${header.length}');
    _log(
      'Override cookie preview: ' +
          (header.length > 220 ? header.substring(0, 220) + '...' : header),
    );

    YahooFinanceService.setYahooCookieOverride(header);

    // Persist immediately for reliability
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yahoo_cookie', header);
      _log('Persisted yahoo_cookie (length: ${header.length})');
    } catch (_) {}

    if (mounted) {
      setState(() => _done = true);
      Navigator.of(context).pop(true); // succès
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consentement Yahoo')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_startUrl.toString())),
        initialSettings: InAppWebViewSettings(
          // important pour Android
          thirdPartyCookiesEnabled: true,
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (c) {},
        onLoadStart: (controller, url) {
          _lastUrl = url;
          _log('onLoadStart -> ${url?.toString() ?? '<null>'}');
        },
        onLoadStop: (controller, url) async {
          _lastUrl = url;
          _log('onLoadStop -> ${url?.toString() ?? '<null>'}');
          // Try to finish immediately (in case cookies already set after accept)
          await _tryFinish();

          // Also poll a bit in case consent completes asynchronously
          _pollTimer?.cancel();
          _pollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
            await _tryFinish();
            if (_done || t.tick >= 45) {
              t.cancel();
            }
          });
        },
        onUpdateVisitedHistory: (controller, url, androidIsReload) async {
          _lastUrl = url;
          _log('onUpdateVisitedHistory -> ${url?.toString() ?? '<null>'}');
          await _tryFinish();
        },
      ),
    );
  }
}
