import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'metals_notif_enabled';
const _kPrefBroadcastKey = 'broadcast_notif_enabled';
const _kTopic = 'daily_metals';
const _kTopicAllUsers = 'all_users';

class MetalsNotificationService {
  MetalsNotificationService._();

  static StreamSubscription<User?>? _authSubscription;
  static bool _initialized = false;

  // ── Init ────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!Platform.isIOS) return;
    if (_initialized) return;
    _initialized = true;

    try {
      final settings = await requestSystemPermission();
      debugPrint('[MetalsNotif] Permission: ${settings.authorizationStatus}');

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Déclenché quand le token FCM est créé/renouvelé (APNS forcément prêt).
      // Couvre les nouveaux appareils et les rotations de token.
      FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
        debugPrint(
          '[MetalsNotif] Token FCM disponible/rafraîchi → souscription',
        );
        await _syncTopicSubscriptions();
        await _syncDeviceToken();
      });

      _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) async {
        if (user == null) return;
        await _syncDeviceToken();
      });

      // Tentative immédiate : peut échouer silencieusement si APNS pas prêt.
      await _syncTopicSubscriptions();
      await _syncDeviceToken();

      // Pour les appareils où le token FCM existe déjà (pas de onTokenRefresh),
      // on attend que l'APNS token soit disponible et on resouscrit.
      _retryWhenApnsReady();
    } catch (e, st) {
      debugPrint('[MetalsNotif] Erreur init: $e\n$st');
    }
  }

  /// Attends que getAPNSToken() retourne une valeur (max ~10s) puis souscrit.
  /// Couvre le cas où les topics échouent au démarrage mais onTokenRefresh
  /// ne se déclenchera pas (token FCM déjà existant).
  static Future<void> _retryWhenApnsReady() async {
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null) {
        debugPrint(
          '[MetalsNotif] APNS token disponible après ${(i + 1) * 2}s → souscription',
        );
        await _syncTopicSubscriptions();
        await _syncDeviceToken();
        return;
      }
    }
    debugPrint('[MetalsNotif] APNS token non disponible après 10s');
  }

  // ── Préférence ──────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefKey) ?? true;
  }

  static Future<bool> isBroadcastEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefBroadcastKey) ?? true;
  }

  static Future<NotificationSettings> requestSystemPermission() {
    return FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<AuthorizationStatus> authorizationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, enabled);
    if (enabled) {
      await requestSystemPermission();
    }
    await _syncTopicSubscriptions();
  }

  static Future<void> setBroadcastEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefBroadcastKey, enabled);
    if (enabled) {
      await requestSystemPermission();
    }
    await _syncTopicSubscriptions();
  }

  static Future<void> _syncTopicSubscriptions() async {
    final enabled = await isEnabled();
    final broadcastEnabled = await isBroadcastEnabled();

    if (enabled) {
      await _subscribeSafe();
    } else {
      await _unsubscribeSafe();
    }

    if (broadcastEnabled) {
      await _subscribeAllUsersSafe();
    } else {
      await _unsubscribeAllUsersSafe();
    }

    await _syncDeviceToken();
  }

  static Future<void> _syncDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[MetalsNotif] FCM token indisponible pour sync device');
        return;
      }

      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc('ios_primary')
          .set({
            'fcmToken': token,
            'platform': 'ios',
            'notificationsEnabled':
                settings.authorizationStatus == AuthorizationStatus.authorized,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('[MetalsNotif] Erreur sync device token: $error\n$stackTrace');
    }
  }

  // ── FCM topics ──────────────────────────────────────────────────────────

  static Future<void> _subscribeSafe() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_kTopic);
      debugPrint('[MetalsNotif] ✓ $_kTopic');
    } on FirebaseException catch (e) {
      debugPrint('[MetalsNotif] $_kTopic → ${e.code}');
    } catch (e) {
      debugPrint('[MetalsNotif] $_kTopic → $e');
    }
  }

  static Future<void> _subscribeAllUsersSafe() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_kTopicAllUsers);
      debugPrint('[MetalsNotif] ✓ $_kTopicAllUsers');
    } on FirebaseException catch (e) {
      debugPrint('[MetalsNotif] $_kTopicAllUsers → ${e.code}');
    } catch (e) {
      debugPrint('[MetalsNotif] $_kTopicAllUsers → $e');
    }
  }

  static Future<void> _unsubscribeSafe() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_kTopic);
      debugPrint('[MetalsNotif] Désabonné: $_kTopic');
    } catch (e) {
      debugPrint('[MetalsNotif] unsubscribe $_kTopic → $e');
    }
  }

  static Future<void> _unsubscribeAllUsersSafe() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_kTopicAllUsers);
      debugPrint('[MetalsNotif] Désabonné: $_kTopicAllUsers');
    } catch (e) {
      debugPrint('[MetalsNotif] unsubscribe $_kTopicAllUsers → $e');
    }
  }
}
