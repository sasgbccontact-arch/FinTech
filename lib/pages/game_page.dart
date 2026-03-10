import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../features/notifications/metals_notification_service.dart';
import '../models/chart_models.dart';
import '../widgets/help_fab.dart';
import '../services/yahoo_finance_service.dart';
import 'info_page.dart';
import 'community_page.dart';
import 'goal_page.dart';
import '../features/daily_news_game/ui/daily_news_game_sheet.dart';
import 'simulation_game.dart';
import 'shop_page.dart';
import 'compte_terme.dart';
import 'package:fintech/core/constants.dart';



const LinearGradient _accentGradient = LinearGradient(
  colors: [detailsColor1, detailsColor2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final List<BoxShadow> _softShadow = [
  BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 14,
    offset: const Offset(0, 6),
  ),
];

/// Page de simulation pour l'onglet "Game".
class MarketSimulationPage extends StatefulWidget {
  const MarketSimulationPage({super.key});

  @override
  State<MarketSimulationPage> createState() => _MarketSimulationPageState();
}

class _MarketSimulationPageState extends State<MarketSimulationPage> {
  Set<String> _completedScenarios = {};
  List<PortfolioScenario> _scenarios = [];
  bool _isLoadingScenarios = true;
  String? _loadingError;

  List<PortfolioScenario> _buildGeneratedScenarios() => [];

  String _getAvatarAsset(String id) {
    if (id == '_easteregg') return 'assets/avatars/easteregg.png';
    if (id == '_sydsteregg') return 'assets/avatars/sydsteregg.png';
    if (id == '_call') return 'assets/avatars/avatar_call.png';
    if (id == '_happy') return 'assets/avatars/avatar_happy.png';
    if (id == '_wealthy') return 'assets/avatars/avatar_wealthy.png';
    if (id == '_rich') return 'assets/avatars/avatar_rich.png';
    return 'assets/avatars/avatar$id.png';
  }

  @override
  void initState() {
    super.initState();
    _migrateLearningToGames();
    _loadGameProgress();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    setState(() {
      _isLoadingScenarios = true;
      _loadingError = null;
    });
    try {
      final loaded = await PortfolioScenario.loadScenarios();
      if (mounted) {
        setState(() {
          _scenarios = [...loaded, ..._buildGeneratedScenarios()];
          _isLoadingScenarios = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading scenarios: $e');
      if (mounted) {
        setState(() {
          _isLoadingScenarios = false;
          _loadingError =
              "Erreur de chargement des scénarios.\nVérifiez 'assets/scenario.json'.";
        });
      }
    }
  }

  Future<void> _migrateLearningToGames() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final oldRef = userRef.collection('learning').doc('progress');
    final newRef = userRef.collection('games').doc('progress');

    try {
      final newDoc = await newRef.get();
      if (!newDoc.exists) {
        final oldDoc = await oldRef.get();
        if (oldDoc.exists && oldDoc.data() != null) {
          await newRef.set(oldDoc.data()!);
          debugPrint("Migration learning -> games terminée.");
        }
      }
    } catch (e) {
      debugPrint("Erreur migration: $e");
    }
  }

  Future<void> _loadGameProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('games')
              .doc('progress')
              .get();
      if (doc.exists && mounted) {
        final completed =
            (doc.data()?['completed_scenarios'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        setState(() {
          _completedScenarios = completed.toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading game progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MarketSimulationPage');
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() : null,
      builder: (context, userSnapshot) {
        final bool isAdmin = (userSnapshot.data?.data() as Map<String, dynamic>?)?['isAdmin'] ?? false;

        return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseAuth.instance.currentUser != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots()
                  : null,
          builder: (context, snapshot) {
            final avatarId = snapshot.data?.data()?['avatar_id'] as String?;
            return IconButton(
              icon:
                  avatarId != null
                      ? Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: AssetImage(_getAvatarAsset(avatarId)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      : const Icon(
                        Icons.account_circle_rounded,
                        color: textColor,
                        size: 28,
                      ),
              onPressed: () => _showUserProfile(context, isAdmin),
            );
          },
        ),
        
        actions: [
          IconButton(
            icon: Icon(Icons.groups_rounded, color: textColor.withOpacity(0.75), size: 24),
            tooltip: 'Jeux communautaires',
            onPressed: () => showCupertinoModalBottomSheet(
              context: context,
              builder: (_) => const CommunityPage(),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('quests')
                    .doc('daily')
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              bool hasPendingReward = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final now = DateTime.now();
                final todayStr = "${now.year}-${now.month}-${now.day}";
                
                if (data['date'] == todayStr) {
                  final qDone = (data['quizzes_done'] ?? 0) >= 1 && !(data['claimed_quizzes'] ?? false);
                  final lDone = (data['lessons_done'] ?? 0) >= 1 && !(data['claimed_lessons'] ?? false);
                  final tDone = (data['trades_done'] ?? 0) >= 1 && !(data['claimed_trades'] ?? false);
                  hasPendingReward = qDone || lDone || tDone;
                }
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.checklist_rounded, color: textColor, size: 28),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalPage())),
                  ),
                  if (hasPendingReward)
                    Positioned(
                      top: 12,
                      right: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: const _HeaderBalance(),
            ),
          ),
        ],
        backgroundColor: backgroundColor,
surfaceTintColor: backgroundColor,
elevation: 0,
        centerTitle: false,
      ),
      floatingActionButton: const HelpFab(
        helpText:
            "Ici, vous pouvez participer à des simulations de marché. Choisissez un scénario, gérez votre portefeuille face à des événements et gagnez des récompenses.",
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _ShopAccessCard()),
              const SizedBox(width: 12),
              Expanded(child: _DailyRewardCard(isAdmin: isAdmin)),
            ],
          ),
          _GamePortfolio(isAdmin: isAdmin),
          _DailyQuizCard(isAdmin: isAdmin),
          const _NewsGameCard(),
          const TermDepositSection(),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: const Text(
                'Simulation Games',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              leading: const Icon(
                Icons.sports_esports_rounded,
                color: Colors.black,
              ),
              initiallyExpanded: false,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children:
                  // On enveloppe la liste dans un StreamBuilder pour écouter l'XP et calculer le niveau
                  [StreamBuilder<DocumentSnapshot>(
                    stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).collection('games').doc('progress').snapshots() : null,
                    builder: (context, progressSnapshot) {
                      final data = progressSnapshot.data?.data() as Map<String, dynamic>?;
                      final xp = data?['xp'] as int? ?? 0;
                      final level = (math.log((xp / 500) + 1) / math.log(1.2)).floor() + 1;
                      
                      // Récupération des scénarios complétés depuis le stream pour la réactivité
                      final completedSet = (data?['completed_scenarios'] as List?)?.map((e) => e.toString()).toSet() ?? _completedScenarios;
                      
                      return Column(
                        children: 
                  _isLoadingScenarios
                      ? const [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ]
                      : _loadingError != null
                      ? [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                _loadingError!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: _loadScenarios,
                                child: const Text("Réessayer"),
                              ),
                            ],
                          ),
                        ),
                      ]
                      : () {
                        // On prépare une liste avec l'index d'origine pour le calcul du niveau
                        final entries = _scenarios.asMap().entries.toList();

                        // Tri : Non complétés en premier, Complétés en dernier.
                        // En cas d'égalité, on garde l'ordre d'origine (index).
                        entries.sort((a, b) {
                          final aCompleted = completedSet.contains(a.value.id);
                          final bCompleted = completedSet.contains(b.value.id);
                          
                          if (aCompleted != bCompleted) {
                            return aCompleted ? 1 : -1;
                          }
                          return a.key.compareTo(b.key);
                        });

                        return entries.map<Widget>((entry) {
                          final index = entry.key; // Index d'origine
                          final scenario = entry.value;
                          final isCompleted = completedSet.contains(scenario.id);
                          
                          // Logique : 3 scénarios par niveau.
                          // Niveau 1 : indices 0, 1, 2 débloqués.
                          // Niveau 2 : indices 3, 4, 5 débloqués, etc.
                          final requiredLevel = (index / 3).floor() + 1;
                          final isLocked = !isAdmin && (level < requiredLevel);

                          return Padding(
                            key: ValueKey(scenario.id),
                            padding: const EdgeInsets.only(top: 12),
                            child: ScenarioCard(
                              scenario: scenario,
                              isCompleted: isCompleted,
                              isLocked: isLocked,
                              requiredLevel: requiredLevel,
                              onTap:
                                  isLocked
                                      ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Niveau $requiredLevel requis !")))
                                      : (isCompleted && !isAdmin)
                                          ? null
                                          : () => _openScenario(scenario),
                            ),
                          );
                        }).toList();
                      }(),
                      );
                    }
                  )],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Future<void> _openScenario(PortfolioScenario scenario) async {
    final result = await showCupertinoModalBottomSheet<bool>(
      context: context,
      builder: (context) => ScenarioBriefing(scenario: scenario),
    );

    if (result == true && mounted) {
      await Navigator.push(
        context,
          MaterialPageRoute(
            builder: (_) => SimulationRunner(scenario: scenario),
          ),


      );
      _loadGameProgress();
    }
  }

  void _showUserProfile(BuildContext context, bool isAdmin) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: UserProfileHeader(isAdmin: isAdmin),
            ),
          ),
    );
  }
}

class _DailyRewardCard extends StatefulWidget {
  const _DailyRewardCard({this.isAdmin = false});
  final bool isAdmin;

  @override
  State<_DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends State<_DailyRewardCard> {
  bool _loading = true;
  bool _canClaim = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void didUpdateWidget(_DailyRewardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdmin != oldWidget.isAdmin) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      final lastRewardTs = data?['last_daily_reward'] as Timestamp?;

      bool claimedToday = false;
      if (lastRewardTs != null) {
        final now = DateTime.now();
        final last = lastRewardTs.toDate();
        if (now.year == last.year &&
            now.month == last.month &&
            now.day == last.day) {
          claimedToday = true;
        }
      }

      if (mounted) {
        setState(() {
          _canClaim = !claimedToday;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking daily reward: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_canClaim) {
      return;
    }
    setState(() => _loading = true);

    final random = math.Random();
    final isCoins = random.nextBool();

    int amount;
    String type;
    String label;

    if (isCoins) {
      type = 'coins';
      final options = [100, 200, 300];
      amount = options[random.nextInt(options.length)];
      label = 'Pièces';
    } else {
      type = 'gems';
      final options = [2, 4, 6];
      amount = options[random.nextInt(options.length)];
      label = 'Gemmes';
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await ref.set({
        type: FieldValue.increment(amount),
        'last_daily_reward': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎁 Récompense récupérée : +$amount $label !"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _canClaim = false;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error claiming reward: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de la récupération."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'last_daily_reward': FieldValue.delete()});
    _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    //if (_loading) return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()));
    if (_loading)
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );

    return GestureDetector(
      onTap: _canClaim ? _claimReward : null,

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: _softShadow,
        ),
        height: 140,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: _canClaim ? _accentGradient : null,
                color: _canClaim ? null : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: _canClaim ? Colors.white : textColor.withOpacity(0.6),
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: const Text(
                  "Cadeau",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (_canClaim)
              /*ElevatedButton(
              onPressed: _claimReward,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                minimumSize: const Size(0, 36),
              ),
              child: const Text("Récupérer"),
            )*/
              const SizedBox.shrink()
            else if (widget.isAdmin)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                onPressed: _resetReward,
                tooltip: "Reset (Admin)",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

class _GamePortfolio extends StatefulWidget {
  const _GamePortfolio({this.isAdmin = false});
  final bool isAdmin;

  @override
  State<_GamePortfolio> createState() => _GamePortfolioState();
}

class _GamePortfolioState extends State<_GamePortfolio> {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<QueryDocumentSnapshot> _positions = [];
  Map<String, double> _prices = {};
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  _HistorySeries? _historySeries;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _subscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('games')
          .doc('portofolio')
          .collection('positions')
          .snapshots()
          .listen(_onPositionsUpdate);
      _userSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen(_checkInvestmentAchievement);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _onPositionsUpdate(QuerySnapshot snapshot) {
    if (mounted) {
      setState(() {
        _positions = snapshot.docs;
      });
      _refreshPrices();
      _refreshHistory();
    }
  }

  Future<void> _checkInvestmentAchievement(DocumentSnapshot snapshot) async {
    if (_positions.isEmpty) return;
    
    double totalInvested = 0;
    for (var doc in _positions) {
      final data = doc.data() as Map<String, dynamic>;
      final qty = (data['quantity'] as num?)?.toInt() ?? 0;
      final pru = (data['averagePrice'] as num?)?.toDouble() ?? 0.0;
      totalInvested += qty * pru;
    }

    final userData = snapshot.data() as Map<String, dynamic>?;
    final achievements = List<String>.from(userData?['achievements_claimed'] ?? []);

    if (totalInvested >= 50000 && !achievements.contains('investor_50k')) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'achievements_claimed': FieldValue.arrayUnion(['investor_50k']),
          'unlocked_avatars': FieldValue.arrayUnion(['_rich']),
          'gems': FieldValue.increment(100),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('games').doc('progress').set({
          'xp': FieldValue.increment(400),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Succès débloqué : Investisseur (50k) ! Avatar Rich + 400 XP + 100 Gemmes"), backgroundColor: Colors.purple));
        }
      } catch (e) {
        debugPrint("Error unlocking investor achievement: $e");
      }
    }
  }

  Future<void> _refreshPrices() async {
    final symbols = _positions.map((d) => d['symbol'] as String).toSet();
    if (symbols.isEmpty) {
      return;
    }

    final newPrices = <String, double>{};
    // Récupération des prix en parallèle
    await Future.wait(
      symbols.map((s) async {
        try {
          final quote = await YahooFinanceService.fetchQuote(s);
          if (quote.regularMarketPrice != null) {
            newPrices[s] = quote.regularMarketPrice!;
          }
        } catch (e) {
          debugPrint('Error fetching price for $s: $e');
        }
      }),
    );

    if (mounted) {
      setState(() {
        _prices = newPrices;
      });
    }
  }

  Future<void> _refreshHistory() async {
    if (_positions.isEmpty) {
      if (mounted) setState(() => _historySeries = null);
      return;
    }

    // On utilise un intervalle d'un mois pour le jeu
    const interval = ChartInterval.oneMonth;
    final symbols = _positions.map((d) => d['symbol'] as String).toSet();
    final quantities = {
      for (var d in _positions)
        d['symbol'] as String: (d.data() as Map<String, dynamic>)['quantity'] as num
    };

    try {
      final futures = symbols.map((s) => YahooFinanceService.fetchHistoricalSeries(s, interval));
      final results = await Future.wait(futures);

      final historyMap = <String, List<HistoricalPoint>>{};
      int i = 0;
      for (var s in symbols) {
        historyMap[s] = results[i];
        i++;
      }

      final aggregated = SplayTreeMap<DateTime, double>();

      for (var s in symbols) {
        final points = historyMap[s] ?? [];
        final qty = quantities[s]?.toDouble() ?? 0.0;
        
        for (var p in points) {
           // Normalisation à la journée pour aligner les points
           final dateKey = DateTime(p.time.year, p.time.month, p.time.day);
           aggregated.update(dateKey, (val) => val + (p.close * qty), ifAbsent: () => p.close * qty);
        }
      }
      
      final points = aggregated.entries.map((e) => _HistoryPoint(time: e.key, value: e.value)).toList();
      
      if (mounted) {
        setState(() {
          _historySeries = _HistorySeries(points: points, currency: 'coins', normalized: false);
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final unlockedAvatars = List<String>.from(userData?['unlocked_avatars'] ?? []);
        // '_student' est débloqué à la fin du Chapitre 1 (voir learn_page.dart)
        final bool isUnlocked = widget.isAdmin || unlockedAvatars.contains('_student');

        if (!isUnlocked) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_rounded, color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text(
                  "Débloqué après le chapitre 1",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildPortfolioContent();
      },
    );
  }

  Widget _buildPortfolioContent() {
    if (_positions.isEmpty) return const SizedBox.shrink();

    double totalVal = 0;
    double totalInvested = 0;

    for (var doc in _positions) {
      final data = doc.data() as Map<String, dynamic>;
      final qty = (data['quantity'] as num?)?.toInt() ?? 0;
      final pru = (data['averagePrice'] as num?)?.toDouble() ?? 0.0;
      final symbol = data['symbol'] as String;

      totalInvested += qty * pru;
      // Si le prix est chargé on l'utilise, sinon on utilise le PRU comme estimation temporaire
      final price = _prices[symbol] ?? pru;
      totalVal += qty * price;
    }

    final pnl = totalVal - totalInvested;
    final pnlPercent = totalInvested > 0 ? (pnl / totalInvested) * 100 : 0.0;
    final isPositive = pnl >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: _softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: const Text(
            "Portefeuille de Jeu",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                "${totalVal.toStringAsFixed(2)} coins",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${isPositive ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%",
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          initiallyExpanded: false,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (_historySeries != null && _historySeries!.points.length > 1)
              Container(
                height: 140,
                padding: const EdgeInsets.only(bottom: 16),
                child: _SparklineChart(series: _historySeries!),
              ),
            ..._positions.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final symbol = data['symbol'] ?? '';
              final qty = (data['quantity'] as num?)?.toInt() ?? 0;
              final pru = (data['averagePrice'] as num?)?.toDouble() ?? 0.0;

              return _PortfolioItem(
                symbol: symbol,
                qty: qty,
                pru: pru,
                currentPrice: _prices[symbol],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- Classes pour le graphique (copiées/adaptées de portfolio_dashboard_page.dart) ---

class _HistorySeries {
  const _HistorySeries({
    required this.points,
    required this.currency,
    required this.normalized,
  });

  final List<_HistoryPoint> points;
  final String? currency;
  final bool normalized;
}

class _HistoryPoint {
  const _HistoryPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.series});

  final _HistorySeries series;

  @override
  Widget build(BuildContext context) {
    final points = series.points;
    if (points.length < 2) {
      return Center(child: Text('Historique insuffisant.', style: TextStyle(color: textColor.withOpacity(0.65))));
    }
    // Utilisation de la palette harmonisée
    const color = detailsColor2;

    return CustomPaint(
      painter: _SparklinePainter(points: points, color: color),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Text(
              "${points.first.value.toStringAsFixed(0)} coins",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.55)),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Text(
              "${points.last.value.toStringAsFixed(0)} coins",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.points, required this.color});

  final List<_HistoryPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    final fillPath = Path();
    final minValue = points.map((p) => p.value).reduce(math.min);
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final range = (maxValue - minValue).abs() < 1e-6 ? 1.0 : maxValue - minValue;
    final first = points.first;

    double translateX(int index) => (index / (points.length - 1)) * size.width;
    double translateY(double value) =>
        size.height - ((value - minValue) / range) * size.height;

    path.moveTo(translateX(0), translateY(first.value));
    fillPath.moveTo(translateX(0), size.height);
    fillPath.lineTo(translateX(0), translateY(first.value));

    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      final x = translateX(i);
      final y = translateY(point.value);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(translateX(points.length - 1), size.height);
    fillPath.close();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          detailsColor1.withOpacity(0.22),
          detailsColor2.withOpacity(0.08),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      !identical(oldDelegate.points, points) || oldDelegate.color != color;
}

class _PortfolioItem extends StatelessWidget {
  final String symbol;
  final int qty;
  final double pru;
  final double? currentPrice;

  const _PortfolioItem({
    required this.symbol,
    required this.qty,
    required this.pru,
    this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    double? variation;
    double? pnl;

    if (currentPrice != null && pru > 0) {
      variation = ((currentPrice! - pru) / pru) * 100;
      pnl = (currentPrice! - pru) * qty;
    }

    final isPositive = (variation ?? 0) >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final prefix = isPositive ? '+' : '';

    return GestureDetector(
      onTap: () {
        showCupertinoModalBottomSheet(
          context: context,
          expand: true,
          builder: (context) => InfoPage(ticker: symbol),
        );
      },
      child: Container(
        color: Colors.transparent, // Pour capturer le tap sur toute la zone
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  "$qty actions • PRU ${pru.toStringAsFixed(2)}",
                  style: TextStyle(color: textColor.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
            if (currentPrice == null)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (pnl != null && variation != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$prefix${pnl.toStringAsFixed(2)} ($prefix${variation.toStringAsFixed(2)}%)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Cours: ${currentPrice!.toStringAsFixed(2)}",
                    style: TextStyle(color: textColor.withOpacity(0.55), fontSize: 12),
                  ),
                ],
              )
            else
              Text("-", style: TextStyle(color: textColor.withOpacity(0.55))),
          ],
        ),
      ),
    );
  }
}

class _DailyQuizCard extends StatefulWidget {
  const _DailyQuizCard({this.isAdmin = false});
  final bool isAdmin;

  @override
  State<_DailyQuizCard> createState() => _DailyQuizCardState();
}

class _DailyQuizCardState extends State<_DailyQuizCard> {
  List<_DailyQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  int? _selectedOption;
  bool _answered = false;
  bool _isCorrect = false;
  bool _noLessons = false;
  bool _completed = false;
  int _score = 0;
  bool _isRefreshed = false;
  bool _restoredFromHistory = false;

  @override
  void initState() {
    super.initState();
    _loadDailyQuiz();
  }

  @override
  void didUpdateWidget(_DailyQuizCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdmin != oldWidget.isAdmin && widget.isAdmin) {
      _loadDailyQuiz();
    }
  }

  Future<void> _loadDailyQuiz({bool refresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // 1. Récupérer les leçons terminées
      final progDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('games')
              .doc('progress')
              .get();
      final completedLessons =
          (progDoc.data()?['completed_lessons'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (completedLessons.isEmpty && !widget.isAdmin) {
        if (mounted) {
          setState(() {
            _noLessons = true;
            _loading = false;
          });
        }
        return;
      }

      final jsonString = await rootBundle.loadString('assets/quizz1.json');
      final json = jsonDecode(jsonString);
      final allQuestions = <_DailyQuestion>[];

      for (var chapter in json['chapters']) {
        for (var quiz in chapter['quizzes']) {
          for (var q in quiz['questions']) {
            // Filtrer uniquement les questions des leçons terminées
            if (widget.isAdmin ||
                completedLessons.contains(quiz['lesson_title'])) {
              allQuestions.add(_DailyQuestion.fromJson(q));
            }
          }
        }
      }

      if (allQuestions.isNotEmpty) {
        math.Random random;
        if (refresh || _isRefreshed) {
          random = math.Random();
          _isRefreshed = true;
        } else {
          final now = DateTime.now();
          // Seed unique par jour pour avoir les mêmes questions toute la journée
          final seed = now.year * 10000 + now.month * 100 + now.day;
          random = math.Random(seed);
        }

        // Mélanger et prendre 3 questions (ou moins si pas assez dispo)
        allQuestions.shuffle(random);
        _questions = allQuestions.take(3).toList();
      }

      if (!refresh && _questions.isNotEmpty) {
        final today = DateTime.now();
        final dateStr = "${today.year}-${today.month}-${today.day}";
        final questDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('quests')
            .doc('daily')
            .get();

        if (questDoc.exists && questDoc.data()?['date'] == dateStr) {
          final int done = (questDoc.data()?['quizzes_done'] as num?)?.toInt() ?? 0;
          if (done > 0) {
            _completed = true;
            _restoredFromHistory = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading daily quiz: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateDailyQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month}-${today.day}";
      final questRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quests')
          .doc('daily');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(questRef);
        if (!snapshot.exists || snapshot.data()?['date'] != dateStr) {
          transaction.set(questRef, {
            'date': dateStr,
            'quizzes_done': 1,
            'lessons_done': 0,
            'trades_done': 0,
          });
        } else {
          transaction.update(questRef, {
            'quizzes_done': FieldValue.increment(1),
          });
        }
      });
    } catch (e) {
      debugPrint("Error updating daily quest: $e");
    }
  }

  void _submitAnswer() {
    if (_selectedOption == null || _answered || _questions.isEmpty) return;

    final correct =
        _selectedOption == _questions[_currentIndex].correctAnswerIndex;
    setState(() {
      _answered = true;
      _isCorrect = correct;
      if (correct) _score++;
    });

    if (correct) {
      _rewardUser();
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      setState(() => _completed = true);
      _updateDailyQuest();
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _selectedOption = null;
      _answered = false;
      _completed = false;
      _score = 0;
    });
  }

  Future<void> _buyNewQuestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) throw Exception("Erreur profil");

        final int currentGems =
            (snapshot.data()?['gems'] as num?)?.toInt() ?? 0;
        if (currentGems < 5) {
          throw Exception("Pas assez de gemmes (5 requises)");
        }

        transaction.update(userRef, {'gems': currentGems - 5});
      });

      await _loadDailyQuiz(refresh: true);

      if (mounted) {
        setState(() {
          _currentIndex = 0;
          _selectedOption = null;
          _answered = false;
          _completed = false;
          _score = 0;
          _loading = false;
          _restoredFromHistory = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nouveau quiz généré ! -5 💎"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rewardUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      await userRef.set({
        'coins': FieldValue.increment(10),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error rewarding daily quiz: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    if (_noLessons && !widget.isAdmin) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.black.withOpacity(0.06)),
  boxShadow: _softShadow,
),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Terminez une leçon pour débloquer le quiz du jour !',
                style: TextStyle(
                  color: textColor.withOpacity(0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_completed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.green.withOpacity(0.30)),
  boxShadow: _softShadow,
),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                _restoredFromHistory
                    ? 'Quiz du jour terminé !'
                    : 'Quiz terminé ! Score : $_score/${_questions.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Container(
  decoration: BoxDecoration(
    gradient: _accentGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: _softShadow,
  ),
  child: ElevatedButton.icon(
    onPressed: _buyNewQuestions,
    icon: const Icon(Icons.refresh_rounded, size: 18),
    label: const Text('Nouveau quiz (5 💎)'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
),
            if (widget.isAdmin)
              TextButton.icon(
                onPressed: _resetQuiz,
                icon: const Icon(Icons.refresh),
                label: const Text('Recommencer (Admin)'),
              ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) return const SizedBox.shrink();

    final question = _questions[_currentIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.black.withOpacity(0.06)),
  boxShadow: _softShadow,
),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: detailsColor1,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Quiz du jour (${_currentIndex + 1}/${_questions.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (_answered)
                Text(
                  _isCorrect ? '+10 coins' : 'Raté !',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isCorrect ? detailsColor1 : Colors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(question.options.length, (index) {
            final isSelected = _selectedOption == index;
            final isCorrectAnswer = index == question.correctAnswerIndex;

            Color? bgColor;
            Color borderColor = Colors.black12;

            if (_answered) {
              if (isCorrectAnswer) {
                bgColor = Colors.green.withOpacity(0.1);
                borderColor = Colors.green;
              } else if (isSelected && !isCorrectAnswer) {
                bgColor = Colors.red.withOpacity(0.1);
                borderColor = Colors.red;
              }
            } else if (isSelected) {
              bgColor = Colors.black.withOpacity(0.05);
              borderColor = Colors.black;
            }

            return Padding(
              key: ValueKey(index),
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap:
                    _answered
                        ? null
                        : () => setState(() => _selectedOption = index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(question.options[index])),
                      if (_answered && isCorrectAnswer)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                      if (_answered && isSelected && !isCorrectAnswer)
                        const Icon(Icons.cancel, color: Colors.red, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  !_answered
                      ? (_selectedOption != null ? _submitAnswer : null)
                      : _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                !_answered
                    ? 'Valider'
                    : (_currentIndex < _questions.length - 1
                        ? 'Question suivante'
                        : 'Terminer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;

  _DailyQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory _DailyQuestion.fromJson(Map<String, dynamic> json) {
    return _DailyQuestion(
      question: json['question'] ?? '',
      options:
          (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
    );
  }
}

class UserProfileHeader extends StatefulWidget {
  const UserProfileHeader({super.key, this.isAdmin = false, this.onLogout});
  final bool isAdmin;
  final VoidCallback? onLogout;

  @override
  State<UserProfileHeader> createState() => _UserProfileHeaderState();
}

class _UserProfileHeaderState extends State<UserProfileHeader> {
  String _getAvatarAsset(String id) {
    if (id == '_easteregg') return 'assets/avatars/easteregg.png';
    if (id == '_sydsteregg') return 'assets/avatars/sydsteregg.png';
    if (id == '_call') return 'assets/avatars/avatar_call.png';
    if (id == '_happy') return 'assets/avatars/avatar_happy.png';
    if (id == '_wealthy') return 'assets/avatars/avatar_wealthy.png';
    if (id == '_rich') return 'assets/avatars/avatar_rich.png';
    return 'assets/avatars/avatar$id.png';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data();
        final pseudo =
            userData?['Name'] as String? ?? user.displayName ?? 'Joueur';
        final avatarId = userData?['avatar_id'] as String?;
        final coins = (userData?['coins'] as num?)?.toInt() ?? 0;
        final achievements = List<String>.from(userData?['achievements_claimed'] ?? []);
        final unlockedAvatars =
            (userData?['unlocked_avatars'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('games')
                  .doc('progress')
                  .snapshots(),
          builder: (context, progressSnapshot) {
            final data = progressSnapshot.data?.data();
            final xp = (data?['xp'] as num?)?.toInt() ?? 0;

            // Calcul du streak (logique identique à learn_page.dart)
            int streak = (data?['current_streak'] as num?)?.toInt() ?? 0;
            int maxStreak = (data?['max_streak'] as num?)?.toInt() ?? 0;
            final Timestamp? lastDateTs = data?['last_streak_date'];

            if (lastDateTs != null) {
              final lastDate = lastDateTs.toDate();
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final lastDay = DateTime(
                lastDate.year,
                lastDate.month,
                lastDate.day,
              );

              final diff = today.difference(lastDay).inDays;

              if (diff > 1) streak = 0;
            } else {
              streak = 0;
            }

            if (streak > maxStreak) maxStreak = streak;

            final level = (math.log((xp / 500) + 1) / math.log(1.2)).floor() + 1;
            final startXp = 500 * (math.pow(1.2, level - 1) - 1);
            final nextLevelXp = 500 * (math.pow(1.2, level) - 1);
            final range = nextLevelXp - startXp;
            final progress = range > 0 ? (xp - startXp) / range : 0.0;
            final inventory =
                (data?['inventory'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final allUnlocked = {...unlockedAvatars, ...inventory}.toList();

            // --- Gestion Succès : 10 000 pièces ---
            if (coins >= 10000 && !achievements.contains('wealthy_10k')) {
               WidgetsBinding.instance.addPostFrameCallback((_) async {
                 try {
                   await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                     'achievements_claimed': FieldValue.arrayUnion(['wealthy_10k']),
                     'unlocked_avatars': FieldValue.arrayUnion(['_wealthy']),
                   }, SetOptions(merge: true));
                   
                   await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('games').doc('progress').set({
                     'xp': FieldValue.increment(200),
                   }, SetOptions(merge: true));

                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Succès débloqué : Économe (10k) ! Avatar Wealthy + 200 XP"), backgroundColor: Colors.purple),
                     );
                   }
                 } catch (e) {
                   debugPrint("Error unlocking wealthy achievement: $e");
                 }
               });
            }

            // Gestion des récompenses de niveau
            if (progressSnapshot.hasData && data != null) {
              final lastRewardedLevel =
                  (data['last_rewarded_level'] as num?)?.toInt();

              if (lastRewardedLevel == null) {
                // Initialisation si le champ n'existe pas (évite de récompenser rétroactivement au premier lancement)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  progressSnapshot.data!.reference.set({
                    'last_rewarded_level': level,
                  }, SetOptions(merge: true));
                });
              } else if (level > lastRewardedLevel) {
                // Niveau supérieur atteint
                int totalGems = 0;
                int totalCoins = 0;
                List<String> newAvatars = [];

                for (int i = lastRewardedLevel + 1; i <= level; i++) {
                  // Récompense standard par niveau
                  totalGems += 10;
                  totalCoins += 1000;

                  // Récompenses spécifiques
                  if (i == 5) newAvatars.add('_call');
                  if (i == 10) {
                    newAvatars.add('_geek');
                    totalGems += 100;
                  }
                  if (i == 20) {
                    newAvatars.add('_happy');
                    totalGems += 100;
                  }
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  progressSnapshot.data!.reference.set({
                    'last_rewarded_level': level,
                  }, SetOptions(merge: true));

                  FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                    'coins': FieldValue.increment(totalCoins),
                    'gems': FieldValue.increment(totalGems),
                    if (newAvatars.isNotEmpty) 'unlocked_avatars': FieldValue.arrayUnion(newAvatars),
                  }, SetOptions(merge: true));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Niveau $level atteint ! +$totalGems Gemmes, +$totalCoins Pièces${newAvatars.isNotEmpty ? ', Avatar débloqué !' : ''}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                });
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  // Carte d'infos (en bas)
                  Container(
                    margin: const EdgeInsets.only(top: 60, bottom: 16),
                    padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
                    // width: double.infinity, // REMOVED: Caused layout issues in some contexts
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Pseudo
                        Text(
                          pseudo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Info Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Niveau $level',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 20,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: 20,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$maxStreak',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // XP Progress
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'XP',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.shade100,
                                  color: Colors.blue.shade600,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        const _MetalsNotifToggle(),

                        if (widget.onLogout != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: widget.onLogout,
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text(
                              "Se déconnecter",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Avatar (au dessus)
                  GestureDetector(
                    onTap:
                        () =>
                            _showAvatarSelector(context, avatarId, allUnlocked),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child:
                          avatarId != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Image.asset(
                                  _getAvatarAsset(avatarId),
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                ),
                              )
                              : const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAvatarSelector(
    BuildContext context,
    String? currentAvatarId,
    List<String> unlockedAvatars,
  ) {
    final List<String> specialAvatars = [
      '1',
      '_student',
      '_expert',
      '_bling',
      '_strong',
      '_geek',
      '_skelet',
      '_easteregg',
      '_sydsteregg',
      '_call',
      '_happy',
      '_wealthy',
      '_rich',
    ];

    // Avatars cachés tant qu'ils ne sont pas débloqués (codes secrets)
    final Set<String> secretAvatars = {'_easteregg', '_sydsteregg'};

    final List<String> allAvatars = specialAvatars.where((id) {
      if (secretAvatars.contains(id)) {
        return widget.isAdmin || unlockedAvatars.contains(id);
      }
      return true;
    }).toList();

    // Tri : Les avatars débloqués s'affichent en premier
    allAvatars.sort((a, b) {
      final isUnlockedA = widget.isAdmin || unlockedAvatars.contains(a);
      final isUnlockedB = widget.isAdmin || unlockedAvatars.contains(b);
      if (isUnlockedA == isUnlockedB) return 0;
      return isUnlockedA ? -1 : 1;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Choisir un avatar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 200,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: allAvatars.length,
                  itemBuilder: (context, index) {
                    final id = allAvatars[index];
                    final isSelected = id == currentAvatarId;
                    final isUnlocked =
                        widget.isAdmin ||
                        id == '1' ||
                        unlockedAvatars.contains(id);

                    return GestureDetector(
                      key: ValueKey(id),
                      onTap:
                          isUnlocked
                              ? () {
                                _updateAvatar(context, id);
                                Navigator.pop(context);
                              }
                              : null,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              isSelected
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : Border.all(color: Colors.grey.shade200),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.asset(
                                _getAvatarAsset(id),
                                fit: BoxFit.cover,
                                color: isUnlocked ? null : Colors.grey,
                                colorBlendMode:
                                    isUnlocked ? null : BlendMode.saturation,
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                    ),
                              ),
                            ),
                            if (!isUnlocked)
                              const Center(
                                child: Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateAvatar(BuildContext context, String newAvatarId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'avatar_id': newAvatarId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating avatar: $e');
    }
  }
}

class _ShopAccessCard extends StatelessWidget {
  const _ShopAccessCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => showCupertinoModalBottomSheet(
            context: context,
            builder: (context) => const ShopPage(),
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: _softShadow,
        ),
        height: 140,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: _accentGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Boutique",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBalance extends StatelessWidget {
  const _HeaderBalance();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final coins = (userSnap.data?.data() as Map<String, dynamic>?)?['coins'] ?? 0;
        final gems = (userSnap.data?.data() as Map<String, dynamic>?)?['gems'] ?? 0;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: _softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 22,
                decoration: BoxDecoration(
                  gradient: _accentGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.diamond_rounded, color: detailsColor2, size: 16),
              const SizedBox(width: 4),
              Text(
                "$gems",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.monetization_on_rounded, color: detailsColor1, size: 16),
              const SizedBox(width: 4),
              Text(
                "$coins",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte d'accès au mini-jeu "Actu & Quiz"
// ─────────────────────────────────────────────────────────────────────────────

class _NewsGameCard extends StatelessWidget {
  const _NewsGameCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showCupertinoModalBottomSheet(
        context: context,
        builder: (_) => const DailyNewsGameSheet(),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: _accentGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.newspaper_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actu & Quiz',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Lis l'actu et teste tes connaissances",
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle notifications métaux précieux
// ─────────────────────────────────────────────────────────────────────────────

class _MetalsNotifToggle extends StatefulWidget {
  const _MetalsNotifToggle();

  @override
  State<_MetalsNotifToggle> createState() => _MetalsNotifToggleState();
}

class _MetalsNotifToggleState extends State<_MetalsNotifToggle> {
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await MetalsNotificationService.isEnabled();
    if (mounted) setState(() { _enabled = v; _loading = false; });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await MetalsNotificationService.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 48);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🥇', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cours des métaux',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Notification quotidienne à 9h30',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _enabled,
            onChanged: _toggle,
            activeThumbColor: const Color(0xFFD4AF37),
            activeTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
