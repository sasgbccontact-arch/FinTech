import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'metals_notif_enabled';
const _kTopic   = 'daily_metals';

/// Gère les notifications push quotidiennes des cours de l'or et de l'argent.
///
/// Appeler [MetalsNotificationService.init] au démarrage de l'app (après
/// Firebase.initializeApp). L'abonnement / désabonnement FCM est piloté par
/// [setEnabled].
class MetalsNotificationService {
  MetalsNotificationService._();

  // ── Init ────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    // iOS : demande de permission push
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[MetalsNotif] Statut permission : ${settings.authorizationStatus}',
    );

    // Afficher les notifications FCM lorsque l'app est au premier plan
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Souscrire ou désouscrire selon la préférence stockée
    final enabled = await isEnabled();
    if (enabled) {
      await _subscribe();
    }
  }

  // ── Préférence ──────────────────────────────────────────────────────────

  /// Retourne `true` si les notifications métaux sont activées (défaut : true).
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefKey) ?? true;
  }

  /// Active ou désactive les notifications et met à jour l'abonnement FCM.
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, enabled);
    if (enabled) {
      await _subscribe();
    } else {
      await _unsubscribe();
    }
  }

  // ── FCM topic ───────────────────────────────────────────────────────────

  static Future<void> _subscribe() async {
    await FirebaseMessaging.instance.subscribeToTopic(_kTopic);
    debugPrint('[MetalsNotif] Abonné au topic $_kTopic');
  }

  static Future<void> _unsubscribe() async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(_kTopic);
    debugPrint('[MetalsNotif] Désabonné du topic $_kTopic');
  }
}
