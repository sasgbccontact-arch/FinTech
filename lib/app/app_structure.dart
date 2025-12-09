import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/search_page.dart';
import '../services/yahoo_consent_page.dart';
import '../services/yahoo_finance_service.dart';

class AppStructure extends StatefulWidget {
  const AppStructure({Key? key}) : super(key: key);

  @override
  State<AppStructure> createState() => _AppStructureState();
}

class _AppStructureState extends State<AppStructure> with WidgetsBindingObserver {
  Timer? _watchdog;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConsentAtStartup());
    _watchdog = Timer.periodic(const Duration(minutes: 15), (_) => _autoRecoverIfBlocked());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoRecoverIfBlocked();
    }
  }

  Future<void> _ensureConsentAtStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCookie = prefs.getString('yahoo_cookie');

    if (savedCookie == null || savedCookie.isEmpty) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const YahooConsentPage(symbol: 'AAPL')),
      );
      if (ok == true) {
        final cookie = YahooFinanceService.currentCookie();
        if (cookie != null && cookie.isNotEmpty) {
          await prefs.setString('yahoo_cookie', cookie);
          // ignore: avoid_print
          print('[App] Stored yahoo_cookie after consent, length: ${cookie.length}');
        }
      }
      return;
    }

    try {
      await YahooFinanceService.fetchQuote('AAPL');
      // ignore: avoid_print
      print('[App] Probe OK with saved cookie');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final looks401 = msg.contains('401') || msg.contains('unauthorized') || msg.contains('consent');
      if (looks401) {
        // ignore: avoid_print
        print('[App] Probe FAILED with saved cookie -> clearing and opening consent');
        YahooFinanceService.setYahooCookieOverride(null);
        await prefs.remove('yahoo_cookie');
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const YahooConsentPage(symbol: 'AAPL')),
        );
        if (ok == true) {
          final cookie = YahooFinanceService.currentCookie();
          if (cookie != null && cookie.isNotEmpty) {
            await prefs.setString('yahoo_cookie', cookie);
            // ignore: avoid_print
            print('[App] Stored yahoo_cookie after re-consent, length: ${cookie.length}');
          }
        }
      }
    }
  }

  Future<void> _autoRecoverIfBlocked() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      await YahooFinanceService.fetchQuote('AAPL');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final looks401 = msg.contains('401') || msg.contains('unauthorized') || msg.contains('consent');
      if (looks401) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const YahooConsentPage(symbol: 'AAPL')),
        );
        if (ok == true) {
          final prefs = await SharedPreferences.getInstance();
          final cookie = YahooFinanceService.currentCookie();
          if (cookie != null && cookie.isNotEmpty) {
            await prefs.setString('yahoo_cookie', cookie);
          }
        }
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      body: SearchPage(),
    );
  }
}
