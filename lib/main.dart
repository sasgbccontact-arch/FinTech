import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/yahoo_finance_service.dart';
import 'services/yahoo_consent_page.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart';
import 'package:flutter_inappwebview_ios/flutter_inappwebview_ios.dart';
import 'pages/login_page.dart';
import 'firebase_options.dart';
import 'app/app_structure.dart';

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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
    _redirectAfterSplash();
  }

  Future<void> _redirectAfterSplash() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    final nextPage = user == null ? const LoginPage() : const AppStructure();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextPage),
    );
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
                  color: Colors.white.withValues(alpha: 0.9),
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
