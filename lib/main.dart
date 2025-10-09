import 'dart:async';
import 'package:flutter/material.dart';
import 'pages/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/yahoo_finance_service.dart';
import 'services/yahoo_consent_page.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart';
import 'package:flutter_inappwebview_ios/flutter_inappwebview_ios.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure flutter_inappwebview platform implementation is set
  if (defaultTargetPlatform == TargetPlatform.android) {
    InAppWebViewPlatform.instance = AndroidInAppWebViewPlatform();
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    InAppWebViewPlatform.instance = IOSInAppWebViewPlatform();
  }
    // Hook: quand le service détecte consent_required, ouvrir la WebView et persister le cookie
  YahooFinanceService.onConsentRequired = () async {
    // ignore: avoid_print
    print('[App] onConsentRequired: opening YahooConsentPage');
    final ok = await appNavigatorKey.currentState?.push<bool>(
      MaterialPageRoute(builder: (_) => const YahooConsentPage(symbol: 'AAPL')),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      final cookie = YahooFinanceService.currentCookie();
      if (cookie != null && cookie.isNotEmpty) {
        await prefs.setString('yahoo_cookie', cookie);
        // ignore: avoid_print
        print('[App] Stored yahoo_cookie after onConsentRequired, length: ${cookie.length}');
      }
    }
    return ok == true;
  };
  await initPrefs();
  runApp(MaterialApp(
    navigatorKey: appNavigatorKey,
    home: const LogoSplashScreen(),
  ));
}

Future<void> initPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final savedCookie = prefs.getString('yahoo_cookie');
  if (savedCookie != null && savedCookie.isNotEmpty) {
    YahooFinanceService.setYahooCookieOverride(savedCookie);
    // debug
    // ignore: avoid_print
    print('[App] Loaded saved yahoo_cookie, length: ${savedCookie.length}');
  }
}

class LogoSplashScreen extends StatefulWidget {
  const LogoSplashScreen({Key? key}) : super(key: key);

  @override
  State<LogoSplashScreen> createState() => _LogoSplashScreenState();
}

class _LogoSplashScreenState extends State<LogoSplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AppStructure()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey, Colors.white, Colors.grey],
          ),
        ),
        child: Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.white],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  spreadRadius: 10,
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 80,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage('lib/Illustrations/LogoIcon.png'),
            ),
          ),
        ),
      ),
    );
  }
}


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
    // Run consent check when landing on the app container
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConsentAtStartup());
    // Periodic watchdog to refresh consent if cookies expire silently
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

    // If no cookie at all -> open consent directly
    if (savedCookie == null || savedCookie.isEmpty) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const YahooConsentPage(symbol: 'AAPL')),
      );
      if (ok == true) {
        final cookie = YahooFinanceService.currentCookie();
        if (cookie != null && cookie.isNotEmpty) {
          await prefs.setString('yahoo_cookie', cookie);
          // debug
          // ignore: avoid_print
          print('[App] Stored yahoo_cookie after consent, length: ${cookie.length}');
        }
      }
      return;
    }

    // We have a cookie: probe a lightweight fetch; if blocked -> clear & open consent
    try {
      await YahooFinanceService.fetchQuote('AAPL');
      // debug
      // ignore: avoid_print
      print('[App] Probe OK with saved cookie');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final looks401 = msg.contains('401') || msg.contains('unauthorized') || msg.contains('consent');
      if (looks401) {
        // debug
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
            // debug
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
      // Probe with a lightweight popular symbol; any 401/consent wall will surface
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
    // Application mono-page avec SearchPage
    return const Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      body: SearchPage(),
    );
  }
}
