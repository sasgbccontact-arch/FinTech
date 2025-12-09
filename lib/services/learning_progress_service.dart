import 'package:cloud_firestore/cloud_firestore.dart';

/// Model + service pour persister la progression Learn dans Firestore.
class LearningProgress {
  const LearningProgress({
    required this.streak,
    required this.hearts,
    required this.dailyXp,
    required this.totalXp,
    required this.coins,
    required this.lessonsDoneToday,
    required this.quizDoneToday,
    required this.scenariosDoneToday,
    required this.lessonTickets,
    required this.quizTickets,
    required this.scenarioTickets,
    required this.gems,
    required this.lastGemStreak,
    required this.completedQuizIds,
    required this.completedLessonIds,
    required this.completedScenarioIds,
    required this.completedChallengeIds,
    required this.stageProgress,
    this.lastActivityDate,
    this.heartsLastReset,
    this.lastGoalCompletedDate,
  });

  final int streak;
  final int hearts;
  final int dailyXp;
  final int totalXp;
  final int coins;
  final int lessonsDoneToday;
  final int quizDoneToday;
  final int scenariosDoneToday;
  final int lessonTickets;
  final int quizTickets;
  final int scenarioTickets;
  final int gems;
  final int lastGemStreak;
  final Set<String> completedQuizIds;
  final Set<String> completedLessonIds;
  final Set<String> completedScenarioIds;
  final Set<String> completedChallengeIds;
  final Map<String, double> stageProgress;
  final DateTime? lastActivityDate;
  final DateTime? heartsLastReset;
  final DateTime? lastGoalCompletedDate;

  static const int defaultHearts = 4;
  static const int defaultCoins = 5000;
  static const int defaultGems = 0;

  factory LearningProgress.initial() {
    final today = _today();
    return LearningProgress(
      streak: 0,
      hearts: defaultHearts,
      dailyXp: 0,
      totalXp: 0,
      coins: defaultCoins,
      lessonsDoneToday: 0,
      quizDoneToday: 0,
      scenariosDoneToday: 0,
      lessonTickets: 0,
      quizTickets: 0,
      scenarioTickets: 0,
      gems: defaultGems,
      lastGemStreak: 0,
      completedQuizIds: <String>{},
      completedLessonIds: <String>{},
      completedScenarioIds: <String>{},
      completedChallengeIds: <String>{},
      stageProgress: const <String, double>{},
      lastActivityDate: today,
      heartsLastReset: today,
      lastGoalCompletedDate: null,
    );
  }

  factory LearningProgress.fromMap(Map<String, dynamic> data) {
    DateTime? readDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    Map<String, double> _readStage(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value.map((key, raw) => MapEntry(key, (raw as num?)?.toDouble() ?? 0));
      }
      return const <String, double>{};
    }

    Set<String> _readSet(dynamic value) {
      if (value is Iterable) {
        return value.map((e) => e.toString()).toSet();
      }
      return <String>{};
    }

    return LearningProgress(
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      hearts: (data['hearts'] as num?)?.toInt() ?? defaultHearts,
      dailyXp: (data['dailyXp'] as num?)?.toInt() ?? 0,
      totalXp: (data['totalXp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? defaultCoins,
      lessonsDoneToday: (data['lessonsDoneToday'] as num?)?.toInt() ?? 0,
      quizDoneToday: (data['quizDoneToday'] as num?)?.toInt() ?? 0,
      scenariosDoneToday: (data['scenariosDoneToday'] as num?)?.toInt() ?? 0,
      lessonTickets: (data['lessonTickets'] as num?)?.toInt() ?? 0,
      quizTickets: (data['quizTickets'] as num?)?.toInt() ?? 0,
      scenarioTickets: (data['scenarioTickets'] as num?)?.toInt() ?? 0,
      gems: (data['gems'] as num?)?.toInt() ?? defaultGems,
      lastGemStreak: (data['lastGemStreak'] as num?)?.toInt() ?? 0,
      completedQuizIds: _readSet(data['completedQuizIds']),
      completedLessonIds: _readSet(data['completedLessonIds']),
      completedScenarioIds: _readSet(data['completedScenarioIds']),
      completedChallengeIds: _readSet(data['completedChallengeIds']),
      stageProgress: _readStage(data['stageProgress']),
      lastActivityDate: readDate(data['lastActivityDate']),
      heartsLastReset: readDate(data['heartsLastReset']),
      lastGoalCompletedDate: readDate(data['lastGoalCompletedDate']),
    );
  }

  Map<String, dynamic> toMap() {
    Timestamp? _ts(DateTime? date) => date == null ? null : Timestamp.fromDate(date);
    return {
      'streak': streak,
      'hearts': hearts,
      'dailyXp': dailyXp,
      'totalXp': totalXp,
      'coins': coins,
      'lessonsDoneToday': lessonsDoneToday,
      'quizDoneToday': quizDoneToday,
      'scenariosDoneToday': scenariosDoneToday,
      'lessonTickets': lessonTickets,
      'quizTickets': quizTickets,
      'scenarioTickets': scenarioTickets,
      'gems': gems,
      'lastGemStreak': lastGemStreak,
      'completedQuizIds': completedQuizIds.toList(),
      'completedLessonIds': completedLessonIds.toList(),
      'completedScenarioIds': completedScenarioIds.toList(),
      'completedChallengeIds': completedChallengeIds.toList(),
      'stageProgress': stageProgress,
      'lastActivityDate': _ts(lastActivityDate),
      'heartsLastReset': _ts(heartsLastReset),
      'lastGoalCompletedDate': _ts(lastGoalCompletedDate),
    }..removeWhere((key, value) => value == null);
  }

  LearningProgress copyWith({
    int? streak,
    int? hearts,
    int? dailyXp,
    int? totalXp,
    int? coins,
    int? lessonsDoneToday,
    int? quizDoneToday,
    int? scenariosDoneToday,
    int? lessonTickets,
    int? quizTickets,
    int? scenarioTickets,
    int? gems,
    int? lastGemStreak,
    Set<String>? completedQuizIds,
    Set<String>? completedLessonIds,
    Set<String>? completedScenarioIds,
    Set<String>? completedChallengeIds,
    Map<String, double>? stageProgress,
    DateTime? lastActivityDate,
    DateTime? heartsLastReset,
    DateTime? lastGoalCompletedDate,
  }) {
    return LearningProgress(
      streak: streak ?? this.streak,
      hearts: hearts ?? this.hearts,
      dailyXp: dailyXp ?? this.dailyXp,
      totalXp: totalXp ?? this.totalXp,
      coins: coins ?? this.coins,
      lessonsDoneToday: lessonsDoneToday ?? this.lessonsDoneToday,
      quizDoneToday: quizDoneToday ?? this.quizDoneToday,
      scenariosDoneToday: scenariosDoneToday ?? this.scenariosDoneToday,
      lessonTickets: lessonTickets ?? this.lessonTickets,
      quizTickets: quizTickets ?? this.quizTickets,
      scenarioTickets: scenarioTickets ?? this.scenarioTickets,
      gems: gems ?? this.gems,
      lastGemStreak: lastGemStreak ?? this.lastGemStreak,
      completedQuizIds: completedQuizIds ?? this.completedQuizIds,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      completedScenarioIds: completedScenarioIds ?? this.completedScenarioIds,
      completedChallengeIds: completedChallengeIds ?? this.completedChallengeIds,
      stageProgress: stageProgress ?? this.stageProgress,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      heartsLastReset: heartsLastReset ?? this.heartsLastReset,
      lastGoalCompletedDate: lastGoalCompletedDate ?? this.lastGoalCompletedDate,
    );
  }

  LearningProgress updateStage(String stageId, double delta) {
    final mutable = Map<String, double>.from(stageProgress);
    final current = mutable[stageId] ?? 0;
    mutable[stageId] = (current + delta).clamp(0.0, 1.0);
    return copyWith(stageProgress: mutable);
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class LearningProgressService {
  LearningProgressService._();

  static DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('learning').doc('progress');
  }

  /// Charge la progression et applique les resets quotidiens (XP journalier, coeurs).
  static Future<LearningProgress> loadProgress(String uid) async {
    final snap = await _doc(uid).get();
    var progress = snap.exists
        ? LearningProgress.fromMap(snap.data()!)
        : LearningProgress.initial();

    final today = LearningProgress._today();
    if (!LearningProgress.isSameDay(progress.heartsLastReset, today)) {
      progress = progress.copyWith(
        hearts: LearningProgress.defaultHearts,
        heartsLastReset: today,
      );
    }
    final last = progress.lastActivityDate;
    final bool wasYesterday = last != null && _isYesterday(last, today);
    final bool gap = last != null && !LearningProgress.isSameDay(last, today) && !wasYesterday;
    if (gap) {
      progress = progress.copyWith(streak: 0);
    }
    if (!LearningProgress.isSameDay(progress.lastActivityDate, today)) {
      progress = progress.copyWith(
        dailyXp: 0,
        lessonsDoneToday: 0,
        quizDoneToday: 0,
        scenariosDoneToday: 0,
        lessonTickets: 0,
        quizTickets: 0,
        scenarioTickets: 0,
        lastActivityDate: today,
      );
    }

    await _doc(uid).set(progress.toMap(), SetOptions(merge: true));
    return progress;
  }

  static Future<void> saveProgress(String uid, LearningProgress progress) {
    return _doc(uid).set(progress.toMap(), SetOptions(merge: true));
  }

  static bool _isYesterday(DateTime date, DateTime today) {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
}
