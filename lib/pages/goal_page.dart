import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/services/activity_tracking_service.dart';

import 'learn_course3_data.dart';
import 'learn_course4_data.dart';
import 'learn_course5_data.dart';

final Set<String> _microLessonTitles = _collectCourseLessonTitles(
  chapter3CourseData,
);
final Set<String> _macroLessonTitles = _collectCourseLessonTitles(
  chapter4CourseData,
);
final Set<String> _assetLessonTitles = _collectCourseLessonTitles(
  chapter5CourseData,
);

final Set<String> _microQuizLessonTitles = _collectQuizLessonTitles(
  chapter3QuizData,
);
final Set<String> _macroQuizLessonTitles = _collectQuizLessonTitles(
  chapter4QuizData,
);
final Set<String> _assetQuizLessonTitles = _collectQuizLessonTitles(
  chapter5QuizData,
);

Set<String> _collectCourseLessonTitles(Map<String, dynamic> courseData) {
  final results = <String>{};

  void walk(Map<String, dynamic> node) {
    final lessons =
        (node['lessons'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final lesson in lessons) {
      final title = (lesson['lesson_title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) {
        results.add(title);
      }
    }

    final subChapters =
        (node['sub_chapters'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final subChapter in subChapters) {
      walk(subChapter);
    }
  }

  final chapters =
      (courseData['chapters'] as List?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  for (final chapter in chapters) {
    walk(chapter);
  }
  return results;
}

Set<String> _collectQuizLessonTitles(Map<String, dynamic> quizData) {
  final results = <String>{};
  final chapters =
      (quizData['chapters'] as List?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  for (final chapter in chapters) {
    final quizzes =
        (chapter['quizzes'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final quiz in quizzes) {
      final lessonTitle = (quiz['lesson_title'] as String?)?.trim();
      if (lessonTitle != null && lessonTitle.isNotEmpty) {
        results.add(lessonTitle);
      }
    }
  }
  return results;
}

enum _GoalFilter { all, claimable, inProgress, completed, locked }

enum _GoalStatus { claimable, inProgress, completed, locked }

enum _CollectionKind { avatar, socialBadge, title, frame, theme, cosmeticBadge }

class _RewardBundle {
  const _RewardBundle({
    this.coins = 0,
    this.gems = 0,
    this.xp = 0,
    this.avatars = const <String>[],
    this.cosmetics = const <String>[],
    this.titles = const <String>[],
    this.consumables = const <String, int>{},
  });

  final int coins;
  final int gems;
  final int xp;
  final List<String> avatars;
  final List<String> cosmetics;
  final List<String> titles;
  final Map<String, int> consumables;

  bool get isEmpty =>
      coins <= 0 &&
      gems <= 0 &&
      xp <= 0 &&
      avatars.isEmpty &&
      cosmetics.isEmpty &&
      titles.isEmpty &&
      consumables.isEmpty;

  List<_RewardChipData> toChipData() {
    final chips = <_RewardChipData>[];
    if (coins > 0) {
      chips.add(
        _RewardChipData(
          icon: Icons.monetization_on_rounded,
          label: '+$coins coins',
          tint: const Color(0xFFFFE8AF),
          foreground: const Color(0xFF7A5600),
        ),
      );
    }
    if (gems > 0) {
      chips.add(
        _RewardChipData(
          icon: Icons.diamond_rounded,
          label: '+$gems gemmes',
          tint: const Color(0xFFE7DEFF),
          foreground: detailsColor2,
        ),
      );
    }
    if (xp > 0) {
      chips.add(
        _RewardChipData(
          icon: Icons.bolt_rounded,
          label: '+$xp XP',
          tint: const Color(0xFFFFE3DA),
          foreground: const Color(0xFFAB4C1A),
        ),
      );
    }
    for (final avatar in avatars) {
      chips.add(
        _RewardChipData(
          icon: Icons.face_rounded,
          label: 'Avatar ${_prettyAvatarName(avatar)}',
          tint: const Color(0xFFE7F4FF),
          foreground: const Color(0xFF175D94),
        ),
      );
    }
    for (final cosmetic in cosmetics) {
      final kind = _collectionKindFromId(cosmetic);
      chips.add(
        _RewardChipData(
          icon: switch (kind) {
            _CollectionKind.frame => Icons.crop_square_rounded,
            _CollectionKind.theme => Icons.palette_rounded,
            _CollectionKind.cosmeticBadge => Icons.auto_awesome_rounded,
            _ => Icons.style_rounded,
          },
          label: _prettyCosmeticName(cosmetic),
          tint: const Color(0xFFE7FFF6),
          foreground: const Color(0xFF166C53),
        ),
      );
    }
    for (final title in titles) {
      chips.add(
        _RewardChipData(
          icon: Icons.workspace_premium_rounded,
          label: title,
          tint: const Color(0xFFF2EEFF),
          foreground: const Color(0xFF5230A3),
        ),
      );
    }
    consumables.forEach((id, amount) {
      chips.add(
        _RewardChipData(
          icon: Icons.shield_moon_rounded,
          label:
              id == 'stock_streak_guard'
                  ? '+$amount protection de streak'
                  : '+$amount ${_prettyCosmeticName(id)}',
          tint: const Color(0xFFEFF6FF),
          foreground: const Color(0xFF245B9D),
        ),
      );
    });
    return chips;
  }

  String summaryLabel() {
    final parts = <String>[];
    if (coins > 0) parts.add('+$coins coins');
    if (gems > 0) parts.add('+$gems gemmes');
    if (xp > 0) parts.add('+$xp XP');
    for (final avatar in avatars) {
      parts.add('avatar ${_prettyAvatarName(avatar)}');
    }
    for (final cosmetic in cosmetics) {
      parts.add(_prettyCosmeticName(cosmetic));
    }
    for (final title in titles) {
      parts.add('titre "$title"');
    }
    consumables.forEach((id, amount) {
      parts.add(
        id == 'stock_streak_guard'
            ? '+$amount protection de streak'
            : '+$amount ${_prettyCosmeticName(id)}',
      );
    });
    return parts.join(' · ');
  }
}

class _RewardChipData {
  const _RewardChipData({
    required this.icon,
    required this.label,
    required this.tint,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color foreground;
}

class _QuestItemData {
  const _QuestItemData({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.reward,
    required this.status,
    this.lockReason,
    this.claimMode = _QuestClaimMode.none,
    this.periodKey,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;
  final _RewardBundle reward;
  final _GoalStatus status;
  final String? lockReason;
  final _QuestClaimMode claimMode;
  final String? periodKey;

  bool get isClaimable => status == _GoalStatus.claimable;
  double get progressRatio {
    if (target <= 0) return 0;
    return (progress / target).clamp(0.0, 1.0);
  }

  String get progressLabel => '$progress/$target';
}

enum _QuestClaimMode { none, daily, weekly, special }

class _AchievementItemData {
  const _AchievementItemData({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.progress,
    required this.target,
    required this.reward,
    required this.status,
    required this.progressLabel,
    this.icon = Icons.emoji_events_rounded,
    this.claimable = false,
    this.lockReason,
    this.highlightValue,
    this.footnote,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int progress;
  final int target;
  final _RewardBundle reward;
  final _GoalStatus status;
  final String progressLabel;
  final IconData icon;
  final bool claimable;
  final String? lockReason;
  final String? highlightValue;
  final String? footnote;

  double get progressRatio {
    if (target <= 0) return 0;
    return (progress / target).clamp(0.0, 1.0);
  }
}

class _CollectionItemData {
  const _CollectionItemData({
    required this.id,
    required this.label,
    required this.kind,
    this.assetPath,
    this.equipped = false,
  });

  final String id;
  final String label;
  final _CollectionKind kind;
  final String? assetPath;
  final bool equipped;
}

class _GoalViewData {
  const _GoalViewData({
    required this.dailyQuests,
    required this.weeklyQuests,
    required this.specialQuests,
    required this.achievements,
    required this.avatars,
    required this.socialBadges,
    required this.profileTitles,
    required this.framesAndThemes,
    required this.cosmeticBadges,
    required this.activeQuestCount,
    required this.pendingRewardsCount,
    required this.unlockedAchievementsCount,
    required this.totalAchievementsCount,
  });

  final List<_QuestItemData> dailyQuests;
  final List<_QuestItemData> weeklyQuests;
  final List<_QuestItemData> specialQuests;
  final List<_AchievementItemData> achievements;
  final List<_CollectionItemData> avatars;
  final List<_CollectionItemData> socialBadges;
  final List<_CollectionItemData> profileTitles;
  final List<_CollectionItemData> framesAndThemes;
  final List<_CollectionItemData> cosmeticBadges;
  final int activeQuestCount;
  final int pendingRewardsCount;
  final int unlockedAchievementsCount;
  final int totalAchievementsCount;
}

class GoalPage extends StatefulWidget {
  const GoalPage({super.key});

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _claimingIds = <String>{};

  _GoalFilter _questFilter = _GoalFilter.all;
  _GoalFilter _achievementFilter = _GoalFilter.all;
  int _refreshSeed = 0;

  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _line = Color(0xFFE6E8EB);

  Future<void> _claimDailyQuest({
    required String uid,
    required String questType,
    required _RewardBundle reward,
    required String questTitle,
  }) async {
    final claimKey = 'daily_$questType';
    if (_claimingIds.contains(claimKey)) return;
    setState(() => _claimingIds.add(claimKey));

    final userRef = _firestore.collection('users').doc(uid);
    final questRef = userRef.collection('quests').doc('daily');
    final progressRef = userRef.collection('games').doc('progress');
    final shopRef = userRef.collection('games').doc('shop');

    try {
      final success = await _firestore.runTransaction((transaction) async {
        final questDoc = await transaction.get(questRef);
        if (!questDoc.exists) return false;
        if (questDoc.data()?['claimed_$questType'] == true) return false;

        transaction.set(questRef, {
          'claimed_$questType': true,
        }, SetOptions(merge: true));
        _applyRewardBundle(
          transaction,
          userRef: userRef,
          progressRef: progressRef,
          shopRef: shopRef,
          reward: reward,
        );
        return true;
      });

      if (!mounted) return;
      if (success) {
        unawaited(
          ActivityTrackingService.trackForUser(
            uid: uid,
            type: 'quest_claim',
            label: questTitle,
            points: 20 + reward.xp + reward.gems * 8 + (reward.coins ~/ 25),
            counters: const <String, int>{'quest_claims': 1},
          ),
        );
        _showClaimSnackBar('Récompense récupérée : ${reward.summaryLabel()}');
        setState(() => _refreshSeed += 1);
      }
    } catch (error) {
      debugPrint('Erreur récupération quête quotidienne: $error');
    } finally {
      if (mounted) {
        setState(() => _claimingIds.remove(claimKey));
      }
    }
  }

  Future<void> _claimPeriodicQuest({
    required String uid,
    required String docId,
    required String questId,
    required String questTitle,
    required _RewardBundle reward,
    String? periodKey,
  }) async {
    final claimKey = '$docId:$questId';
    if (_claimingIds.contains(claimKey)) return;
    setState(() => _claimingIds.add(claimKey));

    final userRef = _firestore.collection('users').doc(uid);
    final questRef = userRef.collection('quests').doc(docId);
    final progressRef = userRef.collection('games').doc('progress');
    final shopRef = userRef.collection('games').doc('shop');

    try {
      final success = await _firestore.runTransaction((transaction) async {
        final questSnap = await transaction.get(questRef);
        final data = questSnap.data() ?? const <String, dynamic>{};
        final storedPeriodKey = data['periodKey'] as String?;
        final claimed =
            periodKey != null && storedPeriodKey != periodKey
                ? <String, dynamic>{}
                : Map<String, dynamic>.from(
                  (data['claimed'] as Map?)?.cast<String, dynamic>() ??
                      const <String, dynamic>{},
                );
        if (claimed[questId] == true) return false;

        claimed[questId] = true;
        final payload = <String, dynamic>{
          'claimed': claimed,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (periodKey != null) {
          payload['periodKey'] = periodKey;
        }
        transaction.set(questRef, payload, SetOptions(merge: true));
        _applyRewardBundle(
          transaction,
          userRef: userRef,
          progressRef: progressRef,
          shopRef: shopRef,
          reward: reward,
        );
        return true;
      });

      if (!mounted) return;
      if (success) {
        unawaited(
          ActivityTrackingService.trackForUser(
            uid: uid,
            type: 'quest_claim',
            label: questTitle,
            points: 24 + reward.xp + reward.gems * 8 + (reward.coins ~/ 25),
            counters: const <String, int>{'quest_claims': 1},
          ),
        );
        _showClaimSnackBar('Récompense récupérée : ${reward.summaryLabel()}');
        setState(() => _refreshSeed += 1);
      }
    } catch (error) {
      debugPrint('Erreur récupération quête périodique: $error');
    } finally {
      if (mounted) {
        setState(() => _claimingIds.remove(claimKey));
      }
    }
  }

  Future<void> _claimAchievement({
    required String uid,
    required _AchievementItemData achievement,
  }) async {
    final claimKey = 'achievement:${achievement.id}';
    if (_claimingIds.contains(claimKey)) return;
    setState(() => _claimingIds.add(claimKey));

    final userRef = _firestore.collection('users').doc(uid);
    final progressRef = userRef.collection('games').doc('progress');
    final shopRef = userRef.collection('games').doc('shop');

    try {
      final success = await _firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final claimed =
            (userSnap.data()?['achievements_claimed'] as List?)
                ?.map((entry) => entry.toString())
                .toSet() ??
            <String>{};
        if (claimed.contains(achievement.id)) return false;

        transaction.set(userRef, {
          'achievements_claimed': FieldValue.arrayUnion([achievement.id]),
        }, SetOptions(merge: true));
        _applyRewardBundle(
          transaction,
          userRef: userRef,
          progressRef: progressRef,
          shopRef: shopRef,
          reward: achievement.reward,
        );
        return true;
      });

      if (!mounted) return;
      if (success) {
        unawaited(
          ActivityTrackingService.trackForUser(
            uid: uid,
            type: 'achievement_claim',
            label: achievement.title,
            points:
                30 +
                achievement.reward.xp +
                achievement.reward.gems * 10 +
                (achievement.reward.coins ~/ 20),
            counters: const <String, int>{'achievement_claims': 1},
          ),
        );
        _showClaimSnackBar(
          'Succès débloqué : ${achievement.title} · ${achievement.reward.summaryLabel()}',
        );
        setState(() => _refreshSeed += 1);
      }
    } catch (error) {
      debugPrint('Erreur récupération succès: $error');
    } finally {
      if (mounted) {
        setState(() => _claimingIds.remove(claimKey));
      }
    }
  }

  void _applyRewardBundle(
    Transaction transaction, {
    required DocumentReference<Map<String, dynamic>> userRef,
    required DocumentReference<Map<String, dynamic>> progressRef,
    required DocumentReference<Map<String, dynamic>> shopRef,
    required _RewardBundle reward,
  }) {
    if (reward.coins > 0) {
      transaction.set(userRef, {
        'coins': FieldValue.increment(reward.coins),
      }, SetOptions(merge: true));
    }
    if (reward.gems > 0) {
      transaction.set(userRef, {
        'gems': FieldValue.increment(reward.gems),
      }, SetOptions(merge: true));
    }
    if (reward.xp > 0) {
      transaction.set(progressRef, {
        'xp': FieldValue.increment(reward.xp),
      }, SetOptions(merge: true));
      transaction.set(userRef, {
        'xp': FieldValue.increment(reward.xp),
      }, SetOptions(merge: true));
    }
    if (reward.avatars.isNotEmpty) {
      transaction.set(userRef, {
        'unlocked_avatars': FieldValue.arrayUnion(reward.avatars),
      }, SetOptions(merge: true));
    }
    if (reward.titles.isNotEmpty) {
      transaction.set(userRef, {
        'profile_titles': FieldValue.arrayUnion(reward.titles),
      }, SetOptions(merge: true));
    }
    if (reward.cosmetics.isNotEmpty) {
      transaction.set(shopRef, {
        'ownedCosmetics': FieldValue.arrayUnion(reward.cosmetics),
      }, SetOptions(merge: true));
    }
    reward.consumables.forEach((id, amount) {
      if (amount <= 0) return;
      transaction.set(shopRef, {
        'consumables.$id': FieldValue.increment(amount),
      }, SetOptions(merge: true));
    });
  }

  void _showClaimSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<_GoalViewData> _buildGoalViewData({
    required String uid,
    required Map<String, dynamic>? userData,
    required Map<String, dynamic>? dailyQuestData,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final results = await Future.wait<dynamic>([
      userRef.collection('games').doc('progress').get(),
      userRef.collection('games').doc('shop').get(),
      userRef.collection('activity_daily').get(),
      userRef.collection('quiz_results').get(),
      userRef.collection('stockAnalystGuesses').get(),
      userRef
          .collection('games')
          .doc('portofolio')
          .collection('positions')
          .get(),
      userRef.collection('quests').doc('weekly').get(),
      userRef.collection('quests').doc('special').get(),
    ]);

    final gamesProgress =
        (results[0] as DocumentSnapshot<Map<String, dynamic>>).data();
    final shopData =
        (results[1] as DocumentSnapshot<Map<String, dynamic>>).data();
    final activityDocs =
        (results[2] as QuerySnapshot<Map<String, dynamic>>).docs;
    final quizResultDocs =
        (results[3] as QuerySnapshot<Map<String, dynamic>>).docs;
    final stockGuessDocs =
        (results[4] as QuerySnapshot<Map<String, dynamic>>).docs;
    final positionDocs =
        (results[5] as QuerySnapshot<Map<String, dynamic>>).docs;
    final weeklyQuestData =
        (results[6] as DocumentSnapshot<Map<String, dynamic>>).data();
    final specialQuestData =
        (results[7] as DocumentSnapshot<Map<String, dynamic>>).data();

    final achievementsClaimed =
        (userData?['achievements_claimed'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final unlockedAvatars =
        (userData?['unlocked_avatars'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final storedTitles =
        (userData?['profile_titles'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final avatarInventory =
        (gamesProgress?['inventory'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final ownedCosmetics =
        (shopData?['ownedCosmetics'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final equippedCosmetics =
        (shopData?['equippedCosmetics'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        const <String, String>{};

    final coins = (userData?['coins'] as num?)?.toInt() ?? 0;
    final xp = (gamesProgress?['xp'] as num?)?.toInt() ?? 0;
    final level = _gameLevelFromXp(xp);
    final completedLessons =
        (gamesProgress?['completed_lessons'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final completedScenarios =
        (gamesProgress?['completed_scenarios'] as List?)
            ?.map((entry) => entry.toString())
            .toSet() ??
        <String>{};
    final streak = (gamesProgress?['current_streak'] as num?)?.toInt() ?? 0;
    final oracleHits =
        (userData?['stock_analyst_oracle_hits'] as num?)?.toInt() ?? 0;
    final profitableSellStreak =
        (userData?['game_profitable_sell_streak'] as num?)?.toInt() ?? 0;
    final isTermDepositUnlocked =
        (userData?['is_term_deposit_unlocked'] as bool?) ?? false;
    final firstTradeAt = _readDate(userData?['game_first_trade_at']);
    final lastGameSellAt = _readDate(userData?['last_game_sell_at']);

    final completedQuizTitles = <String>{};
    var perfectQuizCount = 0;
    for (final doc in quizResultDocs) {
      completedQuizTitles.add(doc.id);
      final rawResults = doc.data()['results'];
      if (rawResults is List && rawResults.isNotEmpty) {
        final results = rawResults.map((entry) => entry == true).toList();
        if (results.every((value) => value)) {
          perfectQuizCount += 1;
        }
      }
    }

    var investedCapital = 0.0;
    for (final doc in positionDocs) {
      final data = doc.data();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final averagePrice = (data['averagePrice'] as num?)?.toDouble() ?? 0;
      investedCapital += quantity * averagePrice;
    }
    final investedCapitalRounded = investedCapital.round();
    final positionsCount = positionDocs.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _startOfWeek(today);
    final currentWeekKey = _periodKey(weekStart);

    var weeklyQuizCount = 0;
    var weeklyLessonCount = 0;
    var weeklyTradeCount = 0;
    var treasuryRunsTotal = 0;
    var weeklyStockAnalystSuccesses = 0;

    final activeDays = <String>{};
    final gameOpenDays = <String>{};
    final dailyNewsSuccessDays = <String>{};

    for (final doc in activityDocs) {
      final data = doc.data();
      final dateKey = (data['dateKey'] as String?) ?? doc.id;
      final date = _dateFromKey(dateKey);
      if (date == null) continue;

      final eventsCount = (data['eventsCount'] as num?)?.toInt() ?? 0;
      if (eventsCount > 0) {
        activeDays.add(dateKey);
      }

      final counters =
          (data['counters'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
          ) ??
          const <String, int>{};

      treasuryRunsTotal += counters['treasury_runs_completed'] ?? 0;

      if (!date.isBefore(weekStart)) {
        weeklyQuizCount +=
            (counters['lesson_quizzes_completed'] ?? 0) +
            (counters['daily_news_quizzes'] ?? 0);
        weeklyLessonCount += counters['lessons_completed'] ?? 0;
        weeklyTradeCount += counters['portfolio_trades'] ?? 0;
      }

      if ((counters['game_hub_visits'] ?? 0) > 0) {
        gameOpenDays.add(dateKey);
      }
      if ((counters['daily_news_correct_predictions'] ?? 0) > 0) {
        dailyNewsSuccessDays.add(dateKey);
      }
    }

    for (final doc in stockGuessDocs) {
      final data = doc.data();
      final dayKey =
          (data['dayKey'] as String?) ??
          _dateKeyFromDate(_readDate(data['createdAt']) ?? now);
      final date = _dateFromKey(dayKey);
      final diff = (data['diff'] as num?)?.toInt() ?? 100;
      if (date != null && !date.isBefore(weekStart) && diff <= 10) {
        weeklyStockAnalystSuccesses += 1;
      }
    }

    final gameOpenStreak = _consecutiveDayStreak(
      reference: today,
      matchingDays: gameOpenDays,
    );
    final dailyNewsSuccessStreak = _consecutiveDayStreak(
      reference: today,
      matchingDays: dailyNewsSuccessDays,
    );
    final activeDayStreak = _consecutiveDayStreak(
      reference: today,
      matchingDays: activeDays,
    );

    final noSellProgress =
        positionsCount == 0
            ? 0
            : _noSellDaysProgress(
              today: today,
              lastSellAt: lastGameSellAt,
              firstTradeAt: firstTradeAt,
              activeDayStreak: activeDayStreak,
            );

    final microQuizCompleted = _intersectionCount(
      completedQuizTitles,
      _microQuizLessonTitles,
    );
    final macroQuizCompleted = _intersectionCount(
      completedQuizTitles,
      _macroQuizLessonTitles,
    );
    final assetQuizCompleted = _intersectionCount(
      completedQuizTitles,
      _assetQuizLessonTitles,
    );

    final microLessonsCompleted = _intersectionCount(
      completedLessons,
      _microLessonTitles,
    );
    final macroLessonsCompleted = _intersectionCount(
      completedLessons,
      _macroLessonTitles,
    );
    final assetLessonsCompleted = _intersectionCount(
      completedLessons,
      _assetLessonTitles,
    );

    final completedCoreCourses =
        <String>{
          if (microLessonsCompleted >= _microLessonTitles.length) 'micro',
          if (macroLessonsCompleted >= _macroLessonTitles.length) 'macro',
          if (assetLessonsCompleted >= _assetLessonTitles.length) 'assets',
        }.length;

    final stockGuessCount = stockGuessDocs.length;
    final stockAverageAccuracy =
        stockGuessCount == 0
            ? 0
            : stockGuessDocs.fold<int>(0, (total, doc) {
                  final diff = (doc.data()['diff'] as num?)?.toInt() ?? 100;
                  return total + math.max(0, 100 - diff);
                }) ~/
                stockGuessCount;

    final dailyQuestClaimedQuizzes =
        _isTodayDailyQuest(dailyQuestData, now)
            ? (dailyQuestData?['claimed_quizzes'] as bool? ?? false)
            : false;
    final dailyQuestClaimedLessons =
        _isTodayDailyQuest(dailyQuestData, now)
            ? (dailyQuestData?['claimed_lessons'] as bool? ?? false)
            : false;
    final dailyQuestClaimedTrades =
        _isTodayDailyQuest(dailyQuestData, now)
            ? (dailyQuestData?['claimed_trades'] as bool? ?? false)
            : false;
    final dailyQuizzesDone =
        _isTodayDailyQuest(dailyQuestData, now)
            ? (dailyQuestData?['quizzes_done'] as num?)?.toInt() ?? 0
            : 0;
    final dailyLessonsDone =
        _isTodayDailyQuest(dailyQuestData, now)
            ? (dailyQuestData?['lessons_done'] as num?)?.toInt() ?? 0
            : 0;
    final dailyTradesDone =
        _isTodayDailyQuest(dailyQuestData, now)
            ? (dailyQuestData?['trades_done'] as num?)?.toInt() ?? 0
            : 0;
    final showTradeQuest =
        (userData?['isAdmin'] as bool?) == true ||
        unlockedAvatars.contains('_student');

    final weeklyClaimed = _readClaimedMap(
      weeklyQuestData,
      currentPeriodKey: currentWeekKey,
    );
    final specialClaimed = _readClaimedMap(specialQuestData);

    final dailyQuests = <_QuestItemData>[
      _QuestItemData(
        id: 'quizzes',
        title: "Savoir, c'est pouvoir",
        description: 'Terminer un quiz de leçon.',
        progress: dailyQuizzesDone,
        target: 1,
        reward: const _RewardBundle(xp: 30),
        status: _questStatus(
          progress: dailyQuizzesDone,
          target: 1,
          claimed: dailyQuestClaimedQuizzes,
        ),
        claimMode: _QuestClaimMode.daily,
      ),
      _QuestItemData(
        id: 'lessons',
        title: 'Élève modèle',
        description: 'Terminer 1 leçon.',
        progress: dailyLessonsDone,
        target: 1,
        reward: const _RewardBundle(coins: 200),
        status: _questStatus(
          progress: dailyLessonsDone,
          target: 1,
          claimed: dailyQuestClaimedLessons,
        ),
        claimMode: _QuestClaimMode.daily,
      ),
      _QuestItemData(
        id: 'trades',
        title: 'Loup de Wall Street',
        description: 'Acheter ou vendre une action.',
        progress: dailyTradesDone,
        target: 1,
        reward: const _RewardBundle(coins: 200, xp: 10),
        status: _questStatus(
          progress: dailyTradesDone,
          target: 1,
          claimed: dailyQuestClaimedTrades,
          locked: !showTradeQuest,
        ),
        lockReason:
            showTradeQuest
                ? null
                : 'Valide le début du parcours Learn pour débloquer les trades.',
        claimMode: _QuestClaimMode.daily,
      ),
    ];

    final weeklyQuests = <_QuestItemData>[
      _QuestItemData(
        id: 'weekly_quizzes',
        title: 'Rythme hebdo',
        description: 'Finir 5 quiz sur la semaine.',
        progress: weeklyQuizCount,
        target: 5,
        reward: const _RewardBundle(xp: 120),
        status: _questStatus(
          progress: weeklyQuizCount,
          target: 5,
          claimed: weeklyClaimed['weekly_quizzes'] == true,
        ),
        claimMode: _QuestClaimMode.weekly,
        periodKey: currentWeekKey,
      ),
      _QuestItemData(
        id: 'weekly_lessons',
        title: 'Semaine studieuse',
        description: 'Terminer 3 leçons cette semaine.',
        progress: weeklyLessonCount,
        target: 3,
        reward: const _RewardBundle(coins: 350),
        status: _questStatus(
          progress: weeklyLessonCount,
          target: 3,
          claimed: weeklyClaimed['weekly_lessons'] == true,
        ),
        claimMode: _QuestClaimMode.weekly,
        periodKey: currentWeekKey,
      ),
      _QuestItemData(
        id: 'weekly_trades',
        title: 'Carnet actif',
        description: 'Effectuer 3 trades sur le portefeuille de jeu.',
        progress: weeklyTradeCount,
        target: 3,
        reward: const _RewardBundle(coins: 250, xp: 20),
        status: _questStatus(
          progress: weeklyTradeCount,
          target: 3,
          claimed: weeklyClaimed['weekly_trades'] == true,
          locked: !showTradeQuest,
        ),
        lockReason:
            showTradeQuest
                ? null
                : 'Débloque les trades pour faire progresser cette quête.',
        claimMode: _QuestClaimMode.weekly,
        periodKey: currentWeekKey,
      ),
      _QuestItemData(
        id: 'weekly_game_streak',
        title: 'Présence régulière',
        description: 'Ouvrir l’onglet Game 3 jours de suite.',
        progress: gameOpenStreak,
        target: 3,
        reward: const _RewardBundle(gems: 2),
        status: _questStatus(
          progress: gameOpenStreak,
          target: 3,
          claimed: weeklyClaimed['weekly_game_streak'] == true,
        ),
        claimMode: _QuestClaimMode.weekly,
        periodKey: currentWeekKey,
      ),
      _QuestItemData(
        id: 'weekly_stock_analyst',
        title: 'Desk analyste',
        description: 'Réussir 3 Stock Analyst sur la semaine.',
        progress: weeklyStockAnalystSuccesses,
        target: 3,
        reward: const _RewardBundle(
          xp: 90,
          consumables: <String, int>{'stock_streak_guard': 1},
        ),
        status: _questStatus(
          progress: weeklyStockAnalystSuccesses,
          target: 3,
          claimed: weeklyClaimed['weekly_stock_analyst'] == true,
        ),
        claimMode: _QuestClaimMode.weekly,
        periodKey: currentWeekKey,
      ),
    ];

    final specialQuests = <_QuestItemData>[
      _QuestItemData(
        id: 'special_first_portfolio',
        title: 'Premier portefeuille',
        description:
            'Créer ta première exposition dans le portefeuille de jeu.',
        progress: positionsCount > 0 ? 1 : 0,
        target: 1,
        reward: const _RewardBundle(
          coins: 250,
          titles: <String>['Premier ordre'],
        ),
        status: _questStatus(
          progress: positionsCount > 0 ? 1 : 0,
          target: 1,
          claimed: specialClaimed['special_first_portfolio'] == true,
        ),
        claimMode: _QuestClaimMode.special,
      ),
      _QuestItemData(
        id: 'special_first_scenario',
        title: 'Premier scénario',
        description: 'Terminer un scénario de marché.',
        progress: completedScenarios.isNotEmpty ? 1 : 0,
        target: 1,
        reward: const _RewardBundle(xp: 120, gems: 1),
        status: _questStatus(
          progress: completedScenarios.isNotEmpty ? 1 : 0,
          target: 1,
          claimed: specialClaimed['special_first_scenario'] == true,
        ),
        claimMode: _QuestClaimMode.special,
      ),
      _QuestItemData(
        id: 'special_treasury_operator',
        title: 'Opérateur trésorerie',
        description: 'Résoudre 2 boards du compte à terme.',
        progress: treasuryRunsTotal,
        target: 2,
        reward: const _RewardBundle(
          coins: 150,
          consumables: <String, int>{'stock_streak_guard': 1},
        ),
        status: _questStatus(
          progress: treasuryRunsTotal,
          target: 2,
          claimed: specialClaimed['special_treasury_operator'] == true,
          locked: !isTermDepositUnlocked && treasuryRunsTotal == 0,
        ),
        lockReason:
            isTermDepositUnlocked || treasuryRunsTotal > 0
                ? null
                : 'Débloque le compte à terme depuis l’onglet Jeux.',
        claimMode: _QuestClaimMode.special,
      ),
      _QuestItemData(
        id: 'special_news_reader',
        title: 'Radar macro',
        description: 'Réussir une session Daily News.',
        progress: dailyNewsSuccessDays.isNotEmpty ? 1 : 0,
        target: 1,
        reward: const _RewardBundle(
          cosmetics: <String>['badge_market_pulse'],
          titles: <String>['Radar macro'],
        ),
        status: _questStatus(
          progress: dailyNewsSuccessDays.isNotEmpty ? 1 : 0,
          target: 1,
          claimed: specialClaimed['special_news_reader'] == true,
        ),
        claimMode: _QuestClaimMode.special,
      ),
    ];

    final achievements = <_AchievementItemData>[
      _AchievementItemData(
        id: 'level_5',
        title: 'Niveau 5 atteint',
        description: 'Passer le premier vrai palier de progression.',
        category: 'Progression',
        progress: math.min(level, 5),
        target: 5,
        reward: const _RewardBundle(avatars: <String>['_call']),
        status: _legacyAchievementStatus(
          storedUnlocked: unlockedAvatars.contains('_call'),
          progress: level,
          target: 5,
        ),
        progressLabel: '${math.min(level, 5)}/5',
        icon: Icons.signal_cellular_alt_rounded,
      ),
      _AchievementItemData(
        id: 'level_10',
        title: 'Niveau 10 atteint',
        description: 'Installer une vraie routine de progression.',
        category: 'Progression',
        progress: math.min(level, 10),
        target: 10,
        reward: const _RewardBundle(avatars: <String>['_geek'], gems: 100),
        status: _legacyAchievementStatus(
          storedUnlocked: unlockedAvatars.contains('_geek'),
          progress: level,
          target: 10,
        ),
        progressLabel: '${math.min(level, 10)}/10',
        icon: Icons.rocket_launch_rounded,
      ),
      _AchievementItemData(
        id: 'level_20',
        title: 'Niveau 20 atteint',
        description: 'Atteindre un palier avancé sur l’app.',
        category: 'Progression',
        progress: math.min(level, 20),
        target: 20,
        reward: const _RewardBundle(avatars: <String>['_happy'], gems: 100),
        status: _legacyAchievementStatus(
          storedUnlocked: unlockedAvatars.contains('_happy'),
          progress: level,
          target: 20,
        ),
        progressLabel: '${math.min(level, 20)}/20',
        icon: Icons.local_fire_department_rounded,
      ),
      _AchievementItemData(
        id: 'streak_7',
        title: 'Streak 7 jours',
        description: 'Rester actif 7 jours d’affilée.',
        category: 'Progression',
        progress: math.min(streak, 7),
        target: 7,
        reward: const _RewardBundle(gems: 2, titles: <String>['Régulier']),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('streak_7'),
          progress: streak,
          target: 7,
        ),
        progressLabel: '${math.min(streak, 7)}/7',
        icon: Icons.bolt_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'wealthy_10k',
        title: 'Économe (10k coins)',
        description: 'Accumuler une vraie réserve de coins.',
        category: 'Économie',
        progress: math.min(coins, 10000),
        target: 10000,
        reward: const _RewardBundle(xp: 200, avatars: <String>['_wealthy']),
        status: _legacyAchievementStatus(
          storedUnlocked: achievementsClaimed.contains('wealthy_10k'),
          progress: coins,
          target: 10000,
        ),
        progressLabel: '${math.min(coins, 10000)}/10000',
        highlightValue: '$coins coins',
        icon: Icons.savings_rounded,
      ),
      _AchievementItemData(
        id: 'investor_10k',
        title: 'Investi 10k',
        description:
            'Atteindre 10k de capital investi sur le portefeuille jeu.',
        category: 'Portefeuille',
        progress: math.min(investedCapitalRounded, 10000),
        target: 10000,
        reward: const _RewardBundle(xp: 80, titles: <String>['Capital 10k']),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('investor_10k'),
          progress: investedCapitalRounded,
          target: 10000,
        ),
        progressLabel: '${math.min(investedCapitalRounded, 10000)}/10000',
        highlightValue: '$investedCapitalRounded investis',
        icon: Icons.account_balance_wallet_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'investor_25k',
        title: 'Investi 25k',
        description: 'Monter en puissance sur le portefeuille de jeu.',
        category: 'Portefeuille',
        progress: math.min(investedCapitalRounded, 25000),
        target: 25000,
        reward: const _RewardBundle(gems: 2, titles: <String>['Capital 25k']),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('investor_25k'),
          progress: investedCapitalRounded,
          target: 25000,
        ),
        progressLabel: '${math.min(investedCapitalRounded, 25000)}/25000',
        highlightValue: '$investedCapitalRounded investis',
        icon: Icons.trending_up_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'investor_50k',
        title: 'Investisseur (50k investis)',
        description: 'Déployer un capital déjà conséquent.',
        category: 'Portefeuille',
        progress: math.min(investedCapitalRounded, 50000),
        target: 50000,
        reward: const _RewardBundle(
          avatars: <String>['_rich'],
          xp: 400,
          gems: 100,
        ),
        status: _legacyAchievementStatus(
          storedUnlocked: achievementsClaimed.contains('investor_50k'),
          progress: investedCapitalRounded,
          target: 50000,
        ),
        progressLabel: '${math.min(investedCapitalRounded, 50000)}/50000',
        highlightValue: '$investedCapitalRounded investis',
        icon: Icons.stacked_line_chart_rounded,
      ),
      _AchievementItemData(
        id: 'investor_100k',
        title: 'Investi 100k',
        description: 'Atteindre le cap symbolique des 100k.',
        category: 'Portefeuille',
        progress: math.min(investedCapitalRounded, 100000),
        target: 100000,
        reward: const _RewardBundle(
          xp: 250,
          gems: 5,
          titles: <String>['Capital 100k'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('investor_100k'),
          progress: investedCapitalRounded,
          target: 100000,
        ),
        progressLabel: '${math.min(investedCapitalRounded, 100000)}/100000',
        highlightValue: '$investedCapitalRounded investis',
        icon: Icons.workspace_premium_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'stock_analyst_oracle',
        title: 'Oracle fondamental',
        description: 'Cumuler 20 guesses parfaits au Stock Analyst.',
        category: 'Mini-jeux',
        progress: math.min(oracleHits, 20),
        target: 20,
        reward: const _RewardBundle(titles: <String>['Oracle fondamental']),
        status: _legacyAchievementStatus(
          storedUnlocked: achievementsClaimed.contains('stock_analyst_oracle'),
          progress: oracleHits,
          target: 20,
        ),
        progressLabel: '${math.min(oracleHits, 20)}/20',
        highlightValue: '$oracleHits hits parfaits',
        icon: Icons.insights_rounded,
      ),
      _AchievementItemData(
        id: 'mastery_micro_quizzes',
        title: 'Tous les quiz micro validés',
        description: 'Boucler tous les quiz du chapitre micro.',
        category: 'Maîtrise',
        progress: microQuizCompleted,
        target: _microQuizLessonTitles.length,
        reward: const _RewardBundle(
          xp: 120,
          titles: <String>['Micro stratège'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('mastery_micro_quizzes'),
          progress: microQuizCompleted,
          target: _microQuizLessonTitles.length,
        ),
        progressLabel: '$microQuizCompleted/${_microQuizLessonTitles.length}',
        icon: Icons.account_tree_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'mastery_macro_quizzes',
        title: 'Tous les quiz macro validés',
        description: 'Boucler tous les quiz du chapitre macro.',
        category: 'Maîtrise',
        progress: macroQuizCompleted,
        target: _macroQuizLessonTitles.length,
        reward: const _RewardBundle(xp: 120, titles: <String>['Macro watcher']),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('mastery_macro_quizzes'),
          progress: macroQuizCompleted,
          target: _macroQuizLessonTitles.length,
        ),
        progressLabel: '$macroQuizCompleted/${_macroQuizLessonTitles.length}',
        icon: Icons.language_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'mastery_asset_quizzes',
        title: 'Tous les quiz actifs validés',
        description: 'Boucler tous les quiz du chapitre actifs financiers.',
        category: 'Maîtrise',
        progress: assetQuizCompleted,
        target: _assetQuizLessonTitles.length,
        reward: const _RewardBundle(
          xp: 150,
          cosmetics: <String>['badge_market_pulse'],
          titles: <String>['Architecte d’actifs'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('mastery_asset_quizzes'),
          progress: assetQuizCompleted,
          target: _assetQuizLessonTitles.length,
        ),
        progressLabel: '$assetQuizCompleted/${_assetQuizLessonTitles.length}',
        icon: Icons.pie_chart_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'curriculum_complete_3',
        title: 'Micro + macro + actifs terminés',
        description: 'Finir l’ensemble des trois grands parcours.',
        category: 'Maîtrise',
        progress: completedCoreCourses,
        target: 3,
        reward: const _RewardBundle(
          xp: 300,
          gems: 5,
          cosmetics: <String>['frame_oracle'],
          titles: <String>['Cycle complet'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('curriculum_complete_3'),
          progress: completedCoreCourses,
          target: 3,
        ),
        progressLabel: '$completedCoreCourses/3',
        icon: Icons.menu_book_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'quiz_perfect_10',
        title: '10 quiz parfaits',
        description: 'Réussir 10 quiz sans aucune erreur.',
        category: 'Apprentissage',
        progress: math.min(perfectQuizCount, 10),
        target: 10,
        reward: const _RewardBundle(xp: 100, gems: 2),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('quiz_perfect_10'),
          progress: perfectQuizCount,
          target: 10,
        ),
        progressLabel: '${math.min(perfectQuizCount, 10)}/10',
        icon: Icons.checklist_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'quiz_perfect_25',
        title: '25 quiz sans erreur',
        description: 'Confirmer la régularité sur la durée.',
        category: 'Apprentissage',
        progress: math.min(perfectQuizCount, 25),
        target: 25,
        reward: const _RewardBundle(
          xp: 200,
          gems: 4,
          consumables: <String, int>{'stock_streak_guard': 1},
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('quiz_perfect_25'),
          progress: perfectQuizCount,
          target: 25,
        ),
        progressLabel: '${math.min(perfectQuizCount, 25)}/25',
        icon: Icons.fact_check_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'game_portfolio_first',
        title: 'Premier portefeuille créé',
        description: 'Détenir au moins une ligne sur le portefeuille de jeu.',
        category: 'Portefeuille',
        progress: positionsCount > 0 ? 1 : 0,
        target: 1,
        reward: const _RewardBundle(
          coins: 250,
          titles: <String>['Premier ordre'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('game_portfolio_first'),
          progress: positionsCount > 0 ? 1 : 0,
          target: 1,
        ),
        progressLabel: positionsCount > 0 ? '1/1' : '0/1',
        icon: Icons.candlestick_chart_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'no_sell_7d',
        title: '7 jours sans vendre',
        description: 'Garder une discipline de détention sur la durée.',
        category: 'Portefeuille',
        progress: math.min(noSellProgress, 7),
        target: 7,
        reward: const _RewardBundle(
          consumables: <String, int>{'stock_streak_guard': 1},
          titles: <String>['Discipline de fer'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('no_sell_7d'),
          progress: noSellProgress,
          target: 7,
        ),
        progressLabel: '${math.min(noSellProgress, 7)}/7',
        icon: Icons.lock_clock_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'sell_profit_streak_5',
        title: '5 ventes profitables d’affilée',
        description: 'Enchaîner cinq sorties gagnantes.',
        category: 'Portefeuille',
        progress: math.min(profitableSellStreak, 5),
        target: 5,
        reward: const _RewardBundle(
          coins: 200,
          gems: 3,
          titles: <String>['Main chaude'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('sell_profit_streak_5'),
          progress: profitableSellStreak,
          target: 5,
        ),
        progressLabel: '${math.min(profitableSellStreak, 5)}/5',
        icon: Icons.show_chart_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'daily_news_streak_3',
        title: 'Daily News : série de 3',
        description: 'Réussir Daily News trois jours de suite.',
        category: 'Mini-jeux',
        progress: math.min(dailyNewsSuccessStreak, 3),
        target: 3,
        reward: const _RewardBundle(xp: 120, titles: <String>['Radar macro']),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('daily_news_streak_3'),
          progress: dailyNewsSuccessStreak,
          target: 3,
        ),
        progressLabel: '${math.min(dailyNewsSuccessStreak, 3)}/3',
        icon: Icons.newspaper_rounded,
        claimable: true,
      ),
      _AchievementItemData(
        id: 'stock_analyst_precision_80',
        title: 'Précision Stock Analyst',
        description: 'Maintenir une moyenne ≥ 80 sur au moins 5 analyses.',
        category: 'Mini-jeux',
        progress: math.min(stockGuessCount, 5),
        target: 5,
        reward: const _RewardBundle(
          xp: 150,
          gems: 2,
          titles: <String>['Analyste discipliné'],
        ),
        status:
            achievementsClaimed.contains('stock_analyst_precision_80')
                ? _GoalStatus.completed
                : stockGuessCount >= 5 && stockAverageAccuracy >= 80
                ? _GoalStatus.claimable
                : stockGuessCount > 0
                ? _GoalStatus.inProgress
                : _GoalStatus.locked,
        progressLabel: '${math.min(stockGuessCount, 5)}/5',
        highlightValue: 'moyenne $stockAverageAccuracy/100',
        icon: Icons.analytics_rounded,
        claimable: true,
        footnote:
            stockGuessCount >= 5
                ? 'Moyenne actuelle : $stockAverageAccuracy/100'
                : 'Fais encore ${math.max(0, 5 - stockGuessCount)} analyse(s) pour activer la moyenne.',
      ),
      _AchievementItemData(
        id: 'treasury_runs_5',
        title: 'Compte à terme : 5 boards',
        description: 'Résoudre cinq boards de trésorerie.',
        category: 'Mini-jeux',
        progress: math.min(treasuryRunsTotal, 5),
        target: 5,
        reward: const _RewardBundle(
          coins: 300,
          xp: 100,
          titles: <String>['Trésorier'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('treasury_runs_5'),
          progress: treasuryRunsTotal,
          target: 5,
          locked: !isTermDepositUnlocked && treasuryRunsTotal == 0,
        ),
        progressLabel: '${math.min(treasuryRunsTotal, 5)}/5',
        icon: Icons.account_balance_rounded,
        claimable: true,
        lockReason:
            isTermDepositUnlocked || treasuryRunsTotal > 0
                ? null
                : 'Débloque le compte à terme pour lancer cette série.',
      ),
      _AchievementItemData(
        id: 'scenarios_completed_5',
        title: 'Scénarios : 5 complétés',
        description: 'Valider cinq scénarios de marché différents.',
        category: 'Mini-jeux',
        progress: math.min(completedScenarios.length, 5),
        target: 5,
        reward: const _RewardBundle(
          xp: 200,
          gems: 2,
          titles: <String>['Stratège de marché'],
        ),
        status: _derivedAchievementStatus(
          claimed: achievementsClaimed.contains('scenarios_completed_5'),
          progress: completedScenarios.length,
          target: 5,
        ),
        progressLabel: '${math.min(completedScenarios.length, 5)}/5',
        icon: Icons.vrpano_rounded,
        claimable: true,
      ),
    ];

    final mergedTitles = <String>{
      ...storedTitles,
      ...achievementsClaimed.map(_achievementTitleReward).whereType<String>(),
    };

    final avatarIds = <String>{...unlockedAvatars, ...avatarInventory}
      ..removeWhere((id) => id.trim().isEmpty);
    final avatars =
        avatarIds
            .map(
              (id) => _CollectionItemData(
                id: id,
                label: _prettyAvatarName(id),
                kind: _CollectionKind.avatar,
                assetPath: _avatarAsset(id),
              ),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    final socialBadges =
        achievementsClaimed
            .map(
              (id) => _CollectionItemData(
                id: id,
                label: _prettyAchievementBadge(id),
                kind: _CollectionKind.socialBadge,
              ),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    final titles =
        mergedTitles
            .map(
              (title) => _CollectionItemData(
                id: title,
                label: title,
                kind: _CollectionKind.title,
              ),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

    final framesAndThemes = <_CollectionItemData>[];
    final cosmeticBadges = <_CollectionItemData>[];
    for (final id in ownedCosmetics) {
      final kind = _collectionKindFromId(id);
      final isEquipped = equippedCosmetics.containsValue(id);
      final item = _CollectionItemData(
        id: id,
        label: _prettyCosmeticName(id),
        kind: kind,
        equipped: isEquipped,
      );
      if (kind == _CollectionKind.frame || kind == _CollectionKind.theme) {
        framesAndThemes.add(item);
      } else if (kind == _CollectionKind.cosmeticBadge) {
        cosmeticBadges.add(item);
      }
    }
    framesAndThemes.sort((a, b) => a.label.compareTo(b.label));
    cosmeticBadges.sort((a, b) => a.label.compareTo(b.label));

    final allQuests = <_QuestItemData>[
      ...dailyQuests,
      ...weeklyQuests,
      ...specialQuests,
    ];
    final pendingRewardsCount =
        allQuests
            .where((quest) => quest.status == _GoalStatus.claimable)
            .length +
        achievements
            .where(
              (achievement) =>
                  achievement.status == _GoalStatus.claimable &&
                  achievement.claimable,
            )
            .length;
    final activeQuestCount =
        allQuests
            .where(
              (quest) =>
                  quest.status == _GoalStatus.claimable ||
                  quest.status == _GoalStatus.inProgress,
            )
            .length;
    final unlockedAchievementsCount =
        achievements
            .where(
              (achievement) =>
                  achievement.status == _GoalStatus.completed ||
                  achievement.status == _GoalStatus.claimable,
            )
            .length;

    return _GoalViewData(
      dailyQuests: dailyQuests,
      weeklyQuests: weeklyQuests,
      specialQuests: specialQuests,
      achievements: achievements,
      avatars: avatars,
      socialBadges: socialBadges,
      profileTitles: titles,
      framesAndThemes: framesAndThemes,
      cosmeticBadges: cosmeticBadges,
      activeQuestCount: activeQuestCount,
      pendingRewardsCount: pendingRewardsCount,
      unlockedAchievementsCount: unlockedAchievementsCount,
      totalAchievementsCount: achievements.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const _GoalLockedScaffold();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData &&
            userSnap.connectionState == ConnectionState.waiting) {
          return const _GoalsLoadingView();
        }
        final userData = userSnap.data?.data();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('quests')
                  .doc('daily')
                  .snapshots(),
          builder: (context, dailyQuestSnap) {
            if (!dailyQuestSnap.hasData &&
                dailyQuestSnap.connectionState == ConnectionState.waiting) {
              return const _GoalsLoadingView();
            }
            final dailyQuestData = dailyQuestSnap.data?.data();

            return FutureBuilder<_GoalViewData>(
              key: ValueKey(
                '${user.uid}|$_refreshSeed|${(userData?['achievements_claimed'] as List?)?.length ?? 0}|${dailyQuestData?['date'] ?? 'none'}|${dailyQuestData?['quizzes_done'] ?? 0}|${dailyQuestData?['lessons_done'] ?? 0}|${dailyQuestData?['trades_done'] ?? 0}',
              ),
              future: _buildGoalViewData(
                uid: user.uid,
                userData: userData,
                dailyQuestData: dailyQuestData,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const _GoalsLoadingView();
                }
                if (!snapshot.hasData) {
                  return const _GoalsLoadingView();
                }

                final data = snapshot.data!;
                return DefaultTabController(
                  length: 3,
                  child: Scaffold(
                    backgroundColor: _bg,
                    appBar: AppBar(
                      title: const Text(
                        'Quêtes & Succès',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: .2,
                        ),
                      ),
                      backgroundColor: _bg,
                      foregroundColor: _ink,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                    ),
                    body: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: _GoalSummaryCard(
                              activeQuestCount: data.activeQuestCount,
                              pendingRewardsCount: data.pendingRewardsCount,
                              unlockedAchievementsCount:
                                  data.unlockedAchievementsCount,
                              totalAchievementsCount:
                                  data.totalAchievementsCount,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _GoalTabStrip(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildQuestsTab(uid: user.uid, quests: data),
                                _buildAchievementsTab(
                                  uid: user.uid,
                                  achievements: data.achievements,
                                ),
                                _buildCollectionTab(data),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuestsTab({required String uid, required _GoalViewData quests}) {
    final daily = _filterQuests(quests.dailyQuests, _questFilter);
    final weekly = _filterQuests(quests.weeklyQuests, _questFilter);
    final special = _filterQuests(quests.specialQuests, _questFilter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const _GoalIntroCard(
          title: 'Quêtes pilotées par période',
          subtitle:
              'Retrouve ici les objectifs quotidiens, les défis hebdo et les missions spéciales avec récompenses visibles.',
          icon: Icons.flag_rounded,
        ),
        const SizedBox(height: 12),
        _GoalFilterStrip(
          filter: _questFilter,
          onChanged: (next) => setState(() => _questFilter = next),
        ),
        const SizedBox(height: 14),
        _QuestSection(
          title: 'Quotidiennes',
          subtitle: 'Courtes, rapides et claimables chaque jour.',
          items: daily,
          emptyLabel: 'Aucune quête quotidienne pour ce filtre.',
          builder:
              (quest) => _QuestCard(
                quest: quest,
                loading: _claimingIds.contains(switch (quest.claimMode) {
                  _QuestClaimMode.daily => 'daily_${quest.id}',
                  _QuestClaimMode.weekly => 'weekly:${quest.id}',
                  _QuestClaimMode.special => 'special:${quest.id}',
                  _QuestClaimMode.none => quest.id,
                }),
                onClaim:
                    quest.isClaimable
                        ? () => _claimDailyQuest(
                          uid: uid,
                          questType: quest.id,
                          reward: quest.reward,
                          questTitle: quest.title,
                        )
                        : null,
              ),
        ),
        const SizedBox(height: 16),
        _QuestSection(
          title: 'Hebdo',
          subtitle: 'Des objectifs plus profonds, remis à zéro chaque semaine.',
          items: weekly,
          emptyLabel: 'Aucune quête hebdo pour ce filtre.',
          builder:
              (quest) => _QuestCard(
                quest: quest,
                loading: _claimingIds.contains('weekly:${quest.id}'),
                onClaim:
                    quest.isClaimable
                        ? () => _claimPeriodicQuest(
                          uid: uid,
                          docId: 'weekly',
                          questId: quest.id,
                          questTitle: quest.title,
                          reward: quest.reward,
                          periodKey: quest.periodKey,
                        )
                        : null,
              ),
        ),
        const SizedBox(height: 16),
        _QuestSection(
          title: 'Spéciales',
          subtitle: 'Des jalons one-shot pour enrichir ton profil Game.',
          items: special,
          emptyLabel: 'Aucune quête spéciale pour ce filtre.',
          builder:
              (quest) => _QuestCard(
                quest: quest,
                loading: _claimingIds.contains('special:${quest.id}'),
                onClaim:
                    quest.isClaimable
                        ? () => _claimPeriodicQuest(
                          uid: uid,
                          docId: 'special',
                          questId: quest.id,
                          questTitle: quest.title,
                          reward: quest.reward,
                        )
                        : null,
              ),
        ),
      ],
    );
  }

  Widget _buildAchievementsTab({
    required String uid,
    required List<_AchievementItemData> achievements,
  }) {
    final filtered = _filterAchievements(achievements, _achievementFilter);
    final groups = <String, List<_AchievementItemData>>{};
    for (final achievement in filtered) {
      groups.putIfAbsent(achievement.category, () => <_AchievementItemData>[]);
      groups[achievement.category]!.add(achievement);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const _GoalIntroCard(
          title: 'Succès avec vraie progression',
          subtitle:
              'Chaque succès expose désormais son avancement réel, ses paliers et ses récompenses.',
          icon: Icons.emoji_events_rounded,
        ),
        const SizedBox(height: 12),
        _GoalFilterStrip(
          filter: _achievementFilter,
          onChanged: (next) => setState(() => _achievementFilter = next),
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          const _GoalEmptyCard(
            title: 'Aucun succès pour ce filtre',
            message:
                'Essaie un autre filtre pour retrouver les succès en cours, récupérables ou verrouillés.',
          )
        else
          ...groups.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _QuestSection(
                title: entry.key,
                subtitle: _categorySubtitle(entry.key),
                items: entry.value,
                emptyLabel: 'Aucun succès dans cette catégorie.',
                builder:
                    (achievement) => _AchievementCard(
                      achievement: achievement,
                      loading: _claimingIds.contains(
                        'achievement:${achievement.id}',
                      ),
                      onClaim:
                          achievement.claimable &&
                                  achievement.status == _GoalStatus.claimable
                              ? () => _claimAchievement(
                                uid: uid,
                                achievement: achievement,
                              )
                              : null,
                    ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCollectionTab(_GoalViewData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        const _GoalIntroCard(
          title: 'Collection & profil',
          subtitle:
              'Visualise tout ce que tu as débloqué: avatars, badges sociaux, titres et cosmétiques de profil.',
          icon: Icons.inventory_2_rounded,
        ),
        const SizedBox(height: 14),
        _CollectionSectionCard(
          title: 'Avatars',
          subtitle: 'Ceux que tu peux équiper dans le hub.',
          items: data.avatars,
          emptyLabel: 'Aucun avatar débloqué pour le moment.',
          asGrid: true,
        ),
        const SizedBox(height: 16),
        _CollectionSectionCard(
          title: 'Badges visibles sur le profil social',
          subtitle: 'Issus de tes succès claimés.',
          items: data.socialBadges,
          emptyLabel: 'Aucun badge social visible pour le moment.',
        ),
        const SizedBox(height: 16),
        _CollectionSectionCard(
          title: 'Titres de profil',
          subtitle: 'Récompenses textuelles liées aux paliers et succès rares.',
          items: data.profileTitles,
          emptyLabel: 'Aucun titre de profil débloqué.',
        ),
        const SizedBox(height: 16),
        _CollectionSectionCard(
          title: 'Cadres & profils spéciaux',
          subtitle: 'Cadres, thèmes et habillages du hub.',
          items: data.framesAndThemes,
          emptyLabel: 'Aucun cadre ou thème spécial pour l’instant.',
        ),
        const SizedBox(height: 16),
        _CollectionSectionCard(
          title: 'Badges cosmétiques',
          subtitle:
              'Badges de personnalisation issus de la boutique ou des quêtes spéciales.',
          items: data.cosmeticBadges,
          emptyLabel: 'Aucun badge cosmétique débloqué.',
        ),
      ],
    );
  }
}

int _intersectionCount(Set<String> values, Set<String> targets) {
  var total = 0;
  for (final target in targets) {
    if (values.contains(target)) total += 1;
  }
  return total;
}

_GoalStatus _questStatus({
  required int progress,
  required int target,
  required bool claimed,
  bool locked = false,
}) {
  if (claimed) return _GoalStatus.completed;
  if (locked) return _GoalStatus.locked;
  if (progress >= target) return _GoalStatus.claimable;
  if (progress > 0) return _GoalStatus.inProgress;
  return _GoalStatus.locked;
}

_GoalStatus _derivedAchievementStatus({
  required bool claimed,
  required int progress,
  required int target,
  bool locked = false,
}) {
  if (claimed) return _GoalStatus.completed;
  if (locked) return _GoalStatus.locked;
  if (progress >= target) return _GoalStatus.claimable;
  if (progress > 0) return _GoalStatus.inProgress;
  return _GoalStatus.locked;
}

_GoalStatus _legacyAchievementStatus({
  required bool storedUnlocked,
  required int progress,
  required int target,
}) {
  if (storedUnlocked || progress >= target) {
    return _GoalStatus.completed;
  }
  if (progress > 0) return _GoalStatus.inProgress;
  return _GoalStatus.locked;
}

List<_QuestItemData> _filterQuests(
  List<_QuestItemData> items,
  _GoalFilter filter,
) {
  return items.where((item) => _matchesFilter(item.status, filter)).toList();
}

List<_AchievementItemData> _filterAchievements(
  List<_AchievementItemData> items,
  _GoalFilter filter,
) {
  return items.where((item) => _matchesFilter(item.status, filter)).toList();
}

bool _matchesFilter(_GoalStatus status, _GoalFilter filter) {
  return switch (filter) {
    _GoalFilter.all => true,
    _GoalFilter.claimable => status == _GoalStatus.claimable,
    _GoalFilter.inProgress => status == _GoalStatus.inProgress,
    _GoalFilter.completed => status == _GoalStatus.completed,
    _GoalFilter.locked => status == _GoalStatus.locked,
  };
}

DateTime _startOfWeek(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

bool _isTodayDailyQuest(Map<String, dynamic>? data, DateTime now) {
  if (data == null) return false;
  final todayLabel = '${now.year}-${now.month}-${now.day}';
  return data['date'] == todayLabel;
}

String _periodKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

DateTime? _dateFromKey(String key) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(key);
  if (match == null) return null;
  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String _dateKeyFromDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
}

int _consecutiveDayStreak({
  required DateTime reference,
  required Set<String> matchingDays,
}) {
  var streak = 0;
  var cursor = DateTime(reference.year, reference.month, reference.day);
  while (matchingDays.contains(_dateKeyFromDate(cursor))) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

int _noSellDaysProgress({
  required DateTime today,
  required DateTime? lastSellAt,
  required DateTime? firstTradeAt,
  required int activeDayStreak,
}) {
  if (lastSellAt != null) {
    final lastSellDay = DateTime(
      lastSellAt.year,
      lastSellAt.month,
      lastSellAt.day,
    );
    return math.max(0, today.difference(lastSellDay).inDays);
  }
  if (firstTradeAt != null) {
    final firstTradeDay = DateTime(
      firstTradeAt.year,
      firstTradeAt.month,
      firstTradeAt.day,
    );
    return today.difference(firstTradeDay).inDays + 1;
  }
  return math.max(activeDayStreak, 1);
}

Map<String, dynamic> _readClaimedMap(
  Map<String, dynamic>? data, {
  String? currentPeriodKey,
}) {
  if (data == null) return const <String, dynamic>{};
  if (currentPeriodKey != null &&
      data['periodKey'] != null &&
      data['periodKey'] != currentPeriodKey) {
    return const <String, dynamic>{};
  }
  return Map<String, dynamic>.from(
    (data['claimed'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{},
  );
}

int _gameLevelFromXp(int xp) {
  final safeXp = math.max(0, xp);
  return (math.log((safeXp / 500) + 1) / math.log(1.2)).floor() + 1;
}

String _categorySubtitle(String category) {
  switch (category) {
    case 'Progression':
      return 'Niveau, streak et paliers généraux.';
    case 'Économie':
      return 'Gestion des ressources et discipline de réserve.';
    case 'Portefeuille':
      return 'Investissement, tenue des positions et rythme de trade.';
    case 'Mini-jeux':
      return 'Daily News, Stock Analyst, scénarios et trésorerie.';
    case 'Maîtrise':
      return 'Validation profonde des parcours Learn.';
    case 'Apprentissage':
      return 'Qualité d’exécution sur les quiz.';
    default:
      return 'Progression catégorisée.';
  }
}

_CollectionKind _collectionKindFromId(String id) {
  if (id.startsWith('frame_')) return _CollectionKind.frame;
  if (id.startsWith('theme_')) return _CollectionKind.theme;
  if (id.startsWith('badge_')) return _CollectionKind.cosmeticBadge;
  return _CollectionKind.cosmeticBadge;
}

String? _achievementTitleReward(String achievementId) {
  switch (achievementId) {
    case 'wealthy_10k':
      return 'Économe';
    case 'investor_50k':
      return 'Investisseur';
    case 'stock_analyst_oracle':
      return 'Oracle fondamental';
    case 'streak_7':
      return 'Régulier';
    case 'investor_10k':
      return 'Capital 10k';
    case 'investor_25k':
      return 'Capital 25k';
    case 'investor_100k':
      return 'Capital 100k';
    case 'mastery_micro_quizzes':
      return 'Micro stratège';
    case 'mastery_macro_quizzes':
      return 'Macro watcher';
    case 'mastery_asset_quizzes':
      return 'Architecte d’actifs';
    case 'curriculum_complete_3':
      return 'Cycle complet';
    case 'game_portfolio_first':
      return 'Premier ordre';
    case 'no_sell_7d':
      return 'Discipline de fer';
    case 'sell_profit_streak_5':
      return 'Main chaude';
    case 'daily_news_streak_3':
      return 'Radar macro';
    case 'stock_analyst_precision_80':
      return 'Analyste discipliné';
    case 'treasury_runs_5':
      return 'Trésorier';
    case 'scenarios_completed_5':
      return 'Stratège de marché';
    default:
      return null;
  }
}

String _prettyAchievementBadge(String id) {
  switch (id) {
    case 'wealthy_10k':
      return 'Capital 10k';
    case 'investor_50k':
      return 'Investisseur 50k';
    case 'stock_analyst_oracle':
      return 'Oracle fondamental';
    default:
      return id
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

String _prettyAvatarName(String id) {
  switch (id) {
    case '_call':
      return 'Call';
    case '_geek':
      return 'Geek';
    case '_happy':
      return 'Happy';
    case '_wealthy':
      return 'Wealthy';
    case '_rich':
      return 'Rich';
    case '_student':
      return 'Student';
    default:
      final cleaned = id.replaceFirst('_', '');
      return cleaned.isEmpty
          ? 'Avatar'
          : cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

String _prettyCosmeticName(String id) {
  switch (id) {
    case 'frame_oracle':
      return 'Cadre Oracle';
    case 'badge_market_pulse':
      return 'Badge Market Pulse';
    case 'stock_streak_guard':
      return 'Protection de streak';
    default:
      return id
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

String? _avatarAsset(String id) {
  switch (id) {
    case '_easteregg':
      return 'assets/avatars/easteregg.png';
    case '_sydsteregg':
      return 'assets/avatars/sydsteregg.png';
    case '_quintprime':
      return 'assets/avatars/quint_prime.png';
    case '_beyondbig':
      return 'assets/avatars/beyond_big.png';
    case '_groseline':
      return 'assets/avatars/groseline.png';
    case '_gay':
      return 'assets/avatars/gay.png';
    case '_call':
      return 'assets/avatars/avatar_call.png';
    case '_happy':
      return 'assets/avatars/avatar_happy.png';
    case '_wealthy':
      return 'assets/avatars/avatar_wealthy.png';
    case '_rich':
      return 'assets/avatars/avatar_rich.png';
    case '_geek':
      return 'assets/avatars/avatar_geek.png';
    default:
      if (id.trim().isEmpty) return null;
      return 'assets/avatars/avatar$id.png';
  }
}

class _GoalLockedScaffold extends StatelessWidget {
  const _GoalLockedScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _GoalPageState._bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _GoalPageState._line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.black54,
                    size: 34,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Veuillez vous connecter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTabStrip extends StatelessWidget {
  const _GoalTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        tabs: [
          Tab(text: 'Quêtes'),
          Tab(text: 'Succès'),
          Tab(text: 'Collection'),
        ],
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.activeQuestCount,
    required this.pendingRewardsCount,
    required this.unlockedAchievementsCount,
    required this.totalAchievementsCount,
  });

  final int activeQuestCount;
  final int pendingRewardsCount;
  final int unlockedAchievementsCount;
  final int totalAchievementsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vue d’ensemble Game',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quêtes actives, récompenses à récupérer et progression globale des succès.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.flag_rounded,
                  value: '$activeQuestCount',
                  label: 'quêtes à faire',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.redeem_rounded,
                  value: '$pendingRewardsCount',
                  label: 'récompenses',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.emoji_events_rounded,
                  value: '$unlockedAchievementsCount/$totalAchievementsCount',
                  label: 'succès',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: detailsColor2),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalIntroCard extends StatelessWidget {
  const _GoalIntroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalFilterStrip extends StatelessWidget {
  const _GoalFilterStrip({required this.filter, required this.onChanged});

  final _GoalFilter filter;
  final ValueChanged<_GoalFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <(_GoalFilter, String)>[
      (_GoalFilter.all, 'Tout'),
      (_GoalFilter.claimable, 'À récupérer'),
      (_GoalFilter.inProgress, 'En cours'),
      (_GoalFilter.completed, 'Terminés'),
      (_GoalFilter.locked, 'Verrouillés'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            entries.map((entry) {
              final selected = filter == entry.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onChanged(entry.$1),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          selected
                              ? const LinearGradient(
                                colors: [detailsColor1, detailsColor2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color: selected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            selected
                                ? Colors.transparent
                                : const Color(0xFFE6E8EB),
                      ),
                    ),
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        color: selected ? Colors.white : textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.8,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _QuestSection<T> extends StatelessWidget {
  const _QuestSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.builder,
    required this.emptyLabel,
  });

  final String title;
  final String subtitle;
  final List<T> items;
  final Widget Function(T item) builder;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _GoalEmptyCard(title: 'Rien à afficher', message: emptyLabel)
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: builder(item),
            ),
          ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.loading,
    required this.onClaim,
  });

  final _QuestItemData quest;
  final bool loading;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(quest.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [detailsColor1, detailsColor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    switch (quest.status) {
                      _GoalStatus.completed => Icons.check_circle_rounded,
                      _GoalStatus.claimable => Icons.redeem_rounded,
                      _GoalStatus.inProgress => Icons.bolt_rounded,
                      _GoalStatus.locked => Icons.lock_outline_rounded,
                    },
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quest.description,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(style: style),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: quest.progressRatio,
                minHeight: 9,
                backgroundColor: const Color(0xFFF0F1F3),
                valueColor: AlwaysStoppedAnimation<Color>(style.accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  quest.progressLabel,
                  style: TextStyle(
                    color: style.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (quest.lockReason != null)
                  Flexible(
                    child: Text(
                      quest.lockReason!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  quest.reward
                      .toChipData()
                      .map((chip) => _RewardChip(chip: chip))
                      .toList(),
            ),
            const SizedBox(height: 14),
            if (quest.status == _GoalStatus.claimable)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: loading ? null : onClaim,
                  style: FilledButton.styleFrom(
                    backgroundColor: detailsColor2,
                    disabledBackgroundColor: Colors.black.withValues(
                      alpha: 0.12,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon:
                      loading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(Icons.redeem_rounded, size: 18),
                  label: const Text(
                    'Récupérer',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.loading,
    required this.onClaim,
  });

  final _AchievementItemData achievement;
  final bool loading;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(achievement.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [detailsColor1, detailsColor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(achievement.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(style: style),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: achievement.progressRatio,
                      minHeight: 9,
                      backgroundColor: const Color(0xFFF0F1F3),
                      valueColor: AlwaysStoppedAnimation<Color>(style.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: style.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    achievement.progressLabel,
                    style: TextStyle(
                      color: style.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (achievement.highlightValue != null ||
                achievement.footnote != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (achievement.highlightValue != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8EAEE)),
                      ),
                      child: Text(
                        achievement.highlightValue!,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  if (achievement.footnote != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8EAEE)),
                      ),
                      child: Text(
                        achievement.footnote!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  achievement.reward
                      .toChipData()
                      .map((chip) => _RewardChip(chip: chip))
                      .toList(),
            ),
            const SizedBox(height: 14),
            if (achievement.status == _GoalStatus.claimable &&
                achievement.claimable)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: loading ? null : onClaim,
                  style: FilledButton.styleFrom(
                    backgroundColor: detailsColor2,
                    disabledBackgroundColor: Colors.black.withValues(
                      alpha: 0.12,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon:
                      loading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(
                            Icons.workspace_premium_rounded,
                            size: 18,
                          ),
                  label: const Text(
                    'Débloquer',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
            else if (achievement.lockReason != null)
              Text(
                achievement.lockReason!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionSectionCard extends StatelessWidget {
  const _CollectionSectionCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyLabel,
    this.asGrid = false,
  });

  final String title;
  final String subtitle;
  final List<_CollectionItemData> items;
  final String emptyLabel;
  final bool asGrid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _GoalEmptyCard(title: 'Aucun élément', message: emptyLabel)
          else if (asGrid)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  items
                      .map((item) => _AvatarCollectionTile(item: item))
                      .toList(),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  items.map((item) => _CollectionChip(item: item)).toList(),
            ),
        ],
      ),
    );
  }
}

class _AvatarCollectionTile extends StatelessWidget {
  const _AvatarCollectionTile({required this.item});

  final _CollectionItemData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E9EE)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image:
                  item.assetPath == null
                      ? null
                      : DecorationImage(
                        image: AssetImage(item.assetPath!),
                        fit: BoxFit.cover,
                      ),
            ),
            child:
                item.assetPath == null
                    ? const Icon(Icons.face_rounded, color: Colors.white)
                    : null,
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({required this.item});

  final _CollectionItemData item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      _CollectionKind.socialBadge => Icons.verified_rounded,
      _CollectionKind.title => Icons.workspace_premium_rounded,
      _CollectionKind.frame => Icons.crop_square_rounded,
      _CollectionKind.theme => Icons.palette_rounded,
      _CollectionKind.cosmeticBadge => Icons.auto_awesome_rounded,
      _CollectionKind.avatar => Icons.face_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            item.equipped ? const Color(0xFFF2EEFF) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              item.equipped
                  ? detailsColor2.withValues(alpha: 0.22)
                  : const Color(0xFFE7E9EE),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: detailsColor2),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          if (item.equipped) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.chip});

  final _RewardChipData chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chip.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 14, color: chip.foreground),
          const SizedBox(width: 6),
          Text(
            chip.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.2,
              color: chip.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});

  final _GoalStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.accent,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GoalStatusStyle {
  const _GoalStatusStyle({
    required this.label,
    required this.accent,
    required this.soft,
  });

  final String label;
  final Color accent;
  final Color soft;
}

_GoalStatusStyle _statusStyle(_GoalStatus status) {
  return switch (status) {
    _GoalStatus.claimable => const _GoalStatusStyle(
      label: 'À récupérer',
      accent: Color(0xFF1D5AA6),
      soft: Color(0xFFEAF2FF),
    ),
    _GoalStatus.inProgress => const _GoalStatusStyle(
      label: 'En cours',
      accent: Color(0xFF8A5400),
      soft: Color(0xFFFFF2D7),
    ),
    _GoalStatus.completed => const _GoalStatusStyle(
      label: 'Terminé',
      accent: Color(0xFF1B8B61),
      soft: Color(0xFFE8FAF2),
    ),
    _GoalStatus.locked => const _GoalStatusStyle(
      label: 'Verrouillé',
      accent: Color(0xFF6E737B),
      soft: Color(0xFFF1F3F6),
    ),
  };
}

class _GoalEmptyCard extends StatelessWidget {
  const _GoalEmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E9EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsLoadingView extends StatelessWidget {
  const _GoalsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _GoalPageState._bg,
      appBar: AppBar(
        title: const Text(
          'Quêtes & Succès',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _GoalPageState._ink,
          ),
        ),
        backgroundColor: _GoalPageState._bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: List.generate(
          6,
          (index) => Container(
            height: index == 0 ? 140 : 128,
            margin: EdgeInsets.only(bottom: index == 5 ? 0 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _GoalPageState._line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
