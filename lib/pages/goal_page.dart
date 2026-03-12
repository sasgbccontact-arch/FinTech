import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fintech/core/constants.dart';
import 'package:fintech/services/activity_tracking_service.dart';

class GoalPage extends StatefulWidget {
  const GoalPage({super.key});

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _claimingQuests = {};

  // Palette (same style as SearchPage)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _muted = Colors.black54;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _chipBg = Color(0xFFF0F1F3);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;

  Future<void> _claimReward(
    String uid,
    String questType,
    int coins,
    int xp,
  ) async {
    if (_claimingQuests.contains(questType)) return;

    setState(() {
      _claimingQuests.add(questType);
    });

    final userRef = _firestore.collection('users').doc(uid);
    final questRef = userRef.collection('quests').doc('daily');
    final progressRef = userRef.collection('games').doc('progress');

    try {
      final bool success = await _firestore.runTransaction((transaction) async {
        final questDoc = await transaction.get(questRef);
        if (!questDoc.exists) return false;

        // Vérifier si déjà réclamé pour éviter la triche
        if (questDoc.data()?['claimed_$questType'] == true) return false;

        // Marquer comme réclamé
        transaction.update(questRef, {'claimed_$questType': true});

        // Donner les récompenses
        if (coins > 0) {
          transaction.update(userRef, {'coins': FieldValue.increment(coins)});
        }
        if (xp > 0) {
          transaction.update(progressRef, {'xp': FieldValue.increment(xp)});
        }
        return true;
      });

      if (mounted && success) {
        unawaited(
          ActivityTrackingService.trackForUser(
            uid: uid,
            type: 'quest_claim',
            label: 'Quête quotidienne',
            points: 20 + xp + (coins ~/ 20),
            counters: const <String, int>{'quest_claims': 1},
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Récompense récupérée : ${coins > 0 ? '+$coins pièces ' : ''}${xp > 0 ? '+$xp XP' : ''}",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération : $e");
    } finally {
      if (mounted) {
        setState(() {
          _claimingQuests.remove(questType);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _line),
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

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData &&
            userSnap.connectionState == ConnectionState.waiting) {
          return const _GoalsLoadingView();
        }
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final bool isAdmin = userData?['isAdmin'] ?? false;
        final List<dynamic> unlockedAvatars =
            userData?['unlocked_avatars'] ?? [];
        final List<dynamic> achievementsClaimed =
            userData?['achievements_claimed'] ?? [];
        // Le chapitre 1 débloque l'avatar '_student'
        final bool chapter1Validated = unlockedAvatars.contains('_student');
        final bool showTradeQuest = isAdmin || chapter1Validated;

        return StreamBuilder<DocumentSnapshot>(
          stream:
              _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('quests')
                  .doc('daily')
                  .snapshots(),
          builder: (context, questSnap) {
            if (!questSnap.hasData &&
                questSnap.connectionState == ConnectionState.waiting) {
              return const _GoalsLoadingView();
            }
            final questData = questSnap.data?.data() as Map<String, dynamic>?;

            // Vérification de la date pour le reset quotidien
            final now = DateTime.now();
            final todayStr = "${now.year}-${now.month}-${now.day}";
            final dataDate = questData?['date'] as String?;
            final bool isToday = dataDate == todayStr;

            // Si pas la bonne date, on considère tout à 0 (le reset réel se fait à l'écriture)
            final int quizzesDone =
                isToday ? (questData?['quizzes_done'] ?? 0) : 0;
            final int lessonsDone =
                isToday ? (questData?['lessons_done'] ?? 0) : 0;
            final int tradesDone =
                isToday ? (questData?['trades_done'] ?? 0) : 0;

            final bool claimedQuizzes =
                isToday ? (questData?['claimed_quizzes'] ?? false) : false;
            final bool claimedLessons =
                isToday ? (questData?['claimed_lessons'] ?? false) : false;
            final bool claimedTrades =
                isToday ? (questData?['claimed_trades'] ?? false) : false;

            return Scaffold(
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 6,
                        width: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: const LinearGradient(
                            colors: [_gold, _wine],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  children: [
                    const _SectionHeader(
                      title: 'Quêtes du jour',
                      subtitle:
                          'Complète tes objectifs quotidiens pour gagner XP et pièces.',
                      icon: Icons.flag_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildQuestCard(
                      title: "Savoir, c'est pouvoir",
                      description: "Terminer un quiz de leçon",
                      progress: quizzesDone,
                      target: 1,
                      rewardText: "+30 XP",
                      isClaimed: claimedQuizzes,
                      isClaiming: _claimingQuests.contains('quizzes'),
                      onClaim: () => _claimReward(user.uid, 'quizzes', 0, 30),
                    ),
                    _buildQuestCard(
                      title: "Élève modèle",
                      description: "Terminer 1 leçon",
                      progress: lessonsDone,
                      target: 1,
                      rewardText: "+200 Pièces",
                      isClaimed: claimedLessons,
                      isClaiming: _claimingQuests.contains('lessons'),
                      onClaim: () => _claimReward(user.uid, 'lessons', 200, 0),
                    ),
                    if (showTradeQuest)
                      _buildQuestCard(
                        title: "Loup de Wall Street",
                        description: "Acheter ou vendre une action",
                        progress: tradesDone,
                        target: 1,
                        rewardText: "+200 Pièces, +10 XP",
                        isClaimed: claimedTrades,
                        isClaiming: _claimingQuests.contains('trades'),
                        onClaim:
                            () => _claimReward(user.uid, 'trades', 200, 10),
                      ),
                    const SizedBox(height: 18),
                    const _SectionHeader(
                      title: 'Succès',
                      subtitle:
                          'Débloque des avatars et des récompenses en progressant.',
                      icon: Icons.emoji_events_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildAchievementItem(
                      title: 'Niveau 5 atteint',
                      reward: 'Avatar Call',
                      isUnlocked: unlockedAvatars.contains('_call'),
                      imageAsset: 'assets/avatars/avatar_call.png',
                    ),
                    _buildAchievementItem(
                      title: 'Niveau 10 atteint',
                      reward: 'Avatar Geek + 100 Gemmes',
                      isUnlocked: unlockedAvatars.contains('_geek'),
                      imageAsset: 'assets/avatars/avatar_geek.png',
                    ),
                    _buildAchievementItem(
                      title: 'Niveau 20 atteint',
                      reward: 'Avatar Happy + 100 Gemmes',
                      isUnlocked: unlockedAvatars.contains('_happy'),
                      imageAsset: 'assets/avatars/avatar_happy.png',
                    ),
                    _buildAchievementItem(
                      title: 'Économe (10k pièces)',
                      reward: 'Avatar Wealthy + 200 XP',
                      isUnlocked: achievementsClaimed.contains('wealthy_10k'),
                      imageAsset: 'assets/avatars/avatar_wealthy.png',
                    ),
                    _buildAchievementItem(
                      title: 'Investisseur (50k investis)',
                      reward: 'Avatar Rich + 400 XP + 100 Gemmes',
                      isUnlocked: achievementsClaimed.contains('investor_50k'),
                      imageAsset: 'assets/avatars/avatar_rich.png',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuestCard({
    required String title,
    required String description,
    required int progress,
    required int target,
    required String rewardText,
    required bool isClaimed,
    required bool isClaiming,
    required VoidCallback onClaim,
  }) {
    final bool isCompleted = progress >= target;
    final double progressValue = (progress / target).clamp(0.0, 1.0);

    return Semantics(
      label:
          '$title. Progression $progress sur $target. Récompense $rewardText.',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
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
                        colors: [_gold, _wine],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .10),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : Icons.bolt_rounded,
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
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isClaimed)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 26,
                    )
                  else if (!isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        "$progress/$target",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: isClaiming ? null : onClaim,
                      borderRadius: BorderRadius.circular(14),
                      child: Opacity(
                        opacity: isClaiming ? .7 : 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [_gold, _wine],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child:
                              isClaiming
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text(
                                    'Récupérer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: _chipBg,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : _wine,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _wine.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _wine.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        'Récompense : $rewardText',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _wine,
                        ),
                      ),
                    ),
                  ),
                  if (isClaimed) ...[
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Déjà récupérée',
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementItem({
    required String title,
    required String reward,
    required bool isUnlocked,
    required String imageAsset,
  }) {
    final Color accent = isUnlocked ? _wine : Colors.black54;

    return Semantics(
      label:
          '$title. Récompense $reward. ${isUnlocked ? 'Débloqué' : 'Verrouillé'}.',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: _chipBg,
                  border: Border.all(
                    color: isUnlocked ? _wine.withValues(alpha: 0.25) : _line,
                  ),
                  image: DecorationImage(
                    image: AssetImage(imageAsset),
                    fit: BoxFit.cover,
                    colorFilter:
                        isUnlocked
                            ? null
                            : const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: isUnlocked ? _ink : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reward,
                      style: TextStyle(
                        color: isUnlocked ? accent : Colors.black45,
                        fontSize: 13,
                        fontWeight:
                            isUnlocked ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isUnlocked ? _wine.withValues(alpha: 0.10) : _chipBg,
                  border: Border.all(
                    color: isUnlocked ? _wine.withValues(alpha: 0.18) : _line,
                  ),
                ),
                child: Icon(
                  isUnlocked
                      ? Icons.check_circle_rounded
                      : Icons.lock_outline_rounded,
                  color: isUnlocked ? Colors.green : Colors.black38,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
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
          5,
          (index) => Container(
            height: index < 3 ? 148 : 92,
            margin: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
            color: Colors.black.withValues(alpha: .05),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .10),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
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
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
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
