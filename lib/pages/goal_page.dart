import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GoalPage extends StatefulWidget {
  const GoalPage({super.key});

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _claimingQuests = {};

  Future<void> _claimReward(String uid, String questType, int coins, int xp) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Récompense récupérée : ${coins > 0 ? '+$coins pièces ' : ''}${xp > 0 ? '+$xp XP' : ''}"),
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
      return const Scaffold(body: Center(child: Text("Veuillez vous connecter")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final bool isAdmin = userData?['isAdmin'] ?? false;
        final List<dynamic> unlockedAvatars = userData?['unlocked_avatars'] ?? [];
        final List<dynamic> achievementsClaimed = userData?['achievements_claimed'] ?? [];
        // Le chapitre 1 débloque l'avatar '_student'
        final bool chapter1Validated = unlockedAvatars.contains('_student');
        final bool showTradeQuest = isAdmin || chapter1Validated;

        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(user.uid).collection('quests').doc('daily').snapshots(),
          builder: (context, questSnap) {
            final questData = questSnap.data?.data() as Map<String, dynamic>?;
            
            // Vérification de la date pour le reset quotidien
            final now = DateTime.now();
            final todayStr = "${now.year}-${now.month}-${now.day}";
            final dataDate = questData?['date'] as String?;
            final bool isToday = dataDate == todayStr;

            // Si pas la bonne date, on considère tout à 0 (le reset réel se fait à l'écriture)
            final int quizzesDone = isToday ? (questData?['quizzes_done'] ?? 0) : 0;
            final int lessonsDone = isToday ? (questData?['lessons_done'] ?? 0) : 0;
            final int tradesDone = isToday ? (questData?['trades_done'] ?? 0) : 0;

            final bool claimedQuizzes = isToday ? (questData?['claimed_quizzes'] ?? false) : false;
            final bool claimedLessons = isToday ? (questData?['claimed_lessons'] ?? false) : false;
            final bool claimedTrades = isToday ? (questData?['claimed_trades'] ?? false) : false;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F6F7),
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                title: const Text('Quêtes & Succès'),
                elevation: 0.5,
              ),
              body: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    'Quêtes du jour',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildQuestCard(
                    title: "Savoir, c'est pouvoir",
                    description: "Terminer le quiz du jour",
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
                      onClaim: () => _claimReward(user.uid, 'trades', 200, 10),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'Succès',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
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

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(description, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                if (isClaimed)
                  const Icon(Icons.check_circle, color: Colors.green, size: 28)
                else if (isCompleted)
                  ElevatedButton(
                    onPressed: isClaiming ? null : onClaim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isClaiming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                          )
                        : const Text("Récupérer"),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("$progress/$target", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey.shade100,
                color: isCompleted ? Colors.green : Colors.blue,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Récompense : $rewardText",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
            ),
          ],
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
                image: DecorationImage(
                  image: AssetImage(imageAsset),
                  fit: BoxFit.cover,
                  colorFilter: isUnlocked ? null : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                ),
                border: Border.all(color: isUnlocked ? Colors.purple.withOpacity(0.3) : Colors.transparent),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.black : Colors.grey)),
                  Text(reward, style: TextStyle(color: isUnlocked ? Colors.purple : Colors.grey, fontSize: 13, fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal)),
                ],
              ),
            ),
            Icon(isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: isUnlocked ? Colors.green : Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}