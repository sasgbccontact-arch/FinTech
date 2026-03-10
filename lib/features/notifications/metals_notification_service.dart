import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey      = 'metals_notif_enabled';
const _kTopic        = 'daily_metals';
const _kTopicAllUsers = 'all_users'; // notifications manuelles broadcast

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

    // Sur iOS, le token APNS peut ne pas être disponible immédiatement au
    // démarrage. Le listener onTokenRefresh garantit que l'abonnement sera
    // rejoué dès que le token sera prêt (y compris au premier lancement).
    FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      final enabled = await isEnabled();
      if (enabled) await _subscribeSafe();
    });

    // Tentative immédiate — silencieuse si APNS pas encore prêt
    final enabled = await isEnabled();
    if (enabled) await _subscribeSafe();
    // Topic broadcast toujours souscrit (notifications manuelles admin)
    await _subscribeAllUsersSafe();
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

  /// Abonnement tolérant : catch silencieux si le token APNS n'est pas encore prêt.
  /// Le listener onTokenRefresh dans [init] retentera automatiquement.
  static Future<void> _subscribeSafe() async {
    try {
      // Topic métaux (toggle utilisateur)
      await FirebaseMessaging.instance.subscribeToTopic(_kTopic);
      debugPrint('[MetalsNotif] Abonné au topic $_kTopic');
      // Topic broadcast (toujours actif)
      await FirebaseMessaging.instance.subscribeToTopic(_kTopicAllUsers);
      debugPrint('[MetalsNotif] Abonné au topic $_kTopicAllUsers');
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        debugPrint('[MetalsNotif] APNS token pas encore prêt — sera souscrit à la prochaine actualisation du token');
      } else {
        rethrow;
      }
    }
  }

  static Future<void> _subscribe() async {
    await FirebaseMessaging.instance.subscribeToTopic(_kTopic);
    debugPrint('[MetalsNotif] Abonné au topic $_kTopic');
  }

  static Future<void> _unsubscribe() async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(_kTopic);
    debugPrint('[MetalsNotif] Désabonné du topic $_kTopic');
    // Note: _kTopicAllUsers n'est jamais désabonné (notifications broadcast permanentes)
  }

  /// Abonnement inconditionnel au topic broadcast (appelé même si métaux désactivés).
  static Future<void> _subscribeAllUsersSafe() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_kTopicAllUsers);
      debugPrint('[MetalsNotif] Abonné au topic $_kTopicAllUsers');
    } on FirebaseException catch (e) {
      if (e.code != 'apns-token-not-set') rethrow;
    }
  }
}
