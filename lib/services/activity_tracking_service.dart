import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityTrackingService {
  const ActivityTrackingService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static String dateKey([DateTime? now]) {
    final value = now ?? DateTime.now();
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  static Future<void> trackCurrentUser({
    required String type,
    int points = 0,
    Map<String, int> counters = const <String, int>{},
    String? label,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await trackForUser(
      uid: uid,
      type: type,
      points: points,
      counters: counters,
      label: label,
    );
  }

  static Future<void> trackForUser({
    required String uid,
    required String type,
    int points = 0,
    Map<String, int> counters = const <String, int>{},
    String? label,
  }) async {
    if (uid.isEmpty) return;

    final key = dateKey();
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('activity_daily')
        .doc(key);
    final payload = <String, dynamic>{
      'dateKey': key,
      'eventsCount': FieldValue.increment(1),
      'score': FieldValue.increment(points),
      'lastEventType': type,
      'lastEventLabel': label ?? type,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    counters.forEach((counter, value) {
      if (value != 0) {
        payload['counters.$counter'] = FieldValue.increment(value);
      }
    });

    try {
      await ref.set(payload, SetOptions(merge: true));
      await _db.collection('users').doc(uid).set({
        'last_active_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // L'activité ne doit jamais bloquer le flux principal.
    }
  }
}
