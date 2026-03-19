import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/features/social/social_spotlight_card.dart';
import '../features/notifications/metals_notification_service.dart';
import '../services/ads/ad_config.dart';
import '../services/ads/rewarded_ad_service.dart';
import 'goal_page.dart';
import '../features/daily_news_game/ui/daily_news_game_sheet.dart';
import 'income_statement_game_page.dart';
import 'simulation_game.dart';
import 'shop_page.dart';
import 'compte_terme.dart';
import 'package:fintech/core/constants.dart';
import 'package:fintech/services/activity_tracking_service.dart';
import 'package:fintech/services/daily_reward_service.dart';
import 'package:fintech/services/scenario_game_engine.dart';

const LinearGradient _accentGradient = LinearGradient(
  colors: [detailsColor1, detailsColor2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final List<BoxShadow> _softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 14,
    offset: const Offset(0, 6),
  ),
];

const String _dailyRewardCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="giftGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="18" y="34" width="60" height="40" rx="12" fill="#FFF7DE" stroke="#F5D76E" stroke-width="4"/>
  <rect x="44" y="24" width="8" height="50" rx="4" fill="#2A0F45"/>
  <rect x="18" y="48" width="60" height="8" rx="4" fill="#2A0F45"/>
  <path d="M48 33 C34 19, 24 18, 24 29 C24 39, 36 41, 48 33 Z" fill="url(#giftGold)"/>
  <path d="M48 33 C62 19, 72 18, 72 29 C72 39, 60 41, 48 33 Z" fill="#2A0F45" opacity="0.92"/>
</svg>
''';

const String _dailyRewardLoaderOrbitSvg = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="rewardOrbit" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#2A0F45"/>
    </linearGradient>
  </defs>
  <circle cx="60" cy="60" r="42" fill="none" stroke="#F3E7B9" stroke-width="8"/>
  <path d="M60 18 A42 42 0 0 1 102 60" fill="none" stroke="url(#rewardOrbit)" stroke-width="10" stroke-linecap="round"/>
  <circle cx="60" cy="18" r="6" fill="#2A0F45"/>
  <circle cx="102" cy="60" r="7" fill="#D4AF37"/>
  <circle cx="29" cy="89" r="5" fill="#F5D76E" opacity="0.9"/>
</svg>
''';

const String _questCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="questGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="18" y="16" width="46" height="64" rx="12" fill="#FFF8E6" stroke="#E9D8A0" stroke-width="4"/>
  <rect x="28" y="10" width="26" height="12" rx="6" fill="#2A0F45"/>
  <path d="M29 36 L38 45 L56 28" fill="none" stroke="url(#questGold)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M29 58 L38 67 L56 50" fill="none" stroke="#2A0F45" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="74" cy="68" r="14" fill="url(#questGold)"/>
  <path d="M74 56 L77 64 L86 64 L79 69 L82 78 L74 73 L66 78 L69 69 L62 64 L71 64 Z" fill="#2A0F45"/>
</svg>
''';

const String _shopCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="shopGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <path d="M24 30 H72 L68 76 H28 Z" fill="#FFF8E7" stroke="#E9D8A0" stroke-width="4"/>
  <path d="M34 30 C34 21, 40 15, 48 15 C56 15, 62 21, 62 30" fill="none" stroke="#2A0F45" stroke-width="6" stroke-linecap="round"/>
  <circle cx="40" cy="54" r="9" fill="url(#shopGold)"/>
  <circle cx="58" cy="58" r="9" fill="#2A0F45" opacity="0.92"/>
  <path d="M40 49 V59 M35 54 H45" stroke="#2A0F45" stroke-width="3" stroke-linecap="round"/>
  <path d="M58 53 V63 M53 58 H63" stroke="#F5D76E" stroke-width="3" stroke-linecap="round"/>
</svg>
''';

const String _simulationCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="simGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="14" y="18" width="68" height="60" rx="16" fill="#FFF8E6" stroke="#E9D8A0" stroke-width="4"/>
  <path d="M24 61 L38 48 L48 54 L62 34 L72 40" fill="none" stroke="#2A0F45" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="38" cy="48" r="5" fill="url(#simGold)"/>
  <circle cx="62" cy="34" r="5" fill="url(#simGold)"/>
  <path d="M24 70 H72" stroke="url(#simGold)" stroke-width="5" stroke-linecap="round"/>
</svg>
''';

const String _newsCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="newsGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="18" y="18" width="60" height="60" rx="14" fill="#FFF8E7" stroke="#E9D8A0" stroke-width="4"/>
  <rect x="28" y="30" width="16" height="16" rx="4" fill="#2A0F45"/>
  <path d="M50 33 H68 M50 41 H68 M28 54 H68 M28 62 H60" stroke="url(#newsGold)" stroke-width="5" stroke-linecap="round"/>
  <circle cx="68" cy="68" r="10" fill="#2A0F45"/>
  <path d="M68 58 V78 M58 68 H78" stroke="#F5D76E" stroke-width="2.5" opacity="0.6"/>
</svg>
''';

const String _termDepositCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="termGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="18" y="22" width="42" height="52" rx="12" fill="#FFF8E7" stroke="#E9D8A0" stroke-width="4"/>
  <path d="M30 36 H48 M30 48 H48 M30 60 H42" stroke="#2A0F45" stroke-width="6" stroke-linecap="round"/>
  <circle cx="68" cy="48" r="16" fill="url(#termGold)"/>
  <path d="M68 39 V49 L75 55" fill="none" stroke="#2A0F45" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="68" cy="48" r="3" fill="#2A0F45"/>
</svg>
''';

const String _stockAnalystCardSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="analystGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="12" y="20" width="50" height="44" rx="12" fill="#FFF8E7" stroke="#E9D8A0" stroke-width="4"/>
  <path d="M22 54 L32 44 L42 48 L52 34" fill="none" stroke="#2A0F45" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="58" cy="48" r="18" fill="none" stroke="url(#analystGold)" stroke-width="8"/>
  <line x1="70" y1="60" x2="84" y2="74" stroke="#2A0F45" stroke-width="8" stroke-linecap="round"/>
  <circle cx="58" cy="48" r="5" fill="#2A0F45"/>
</svg>
''';

class _GameSkeletonCard extends StatelessWidget {
  const _GameSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: _softShadow,
      ),
    );
  }
}

class _GameScenarioSkeletonList extends StatelessWidget {
  const _GameScenarioSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          _GameSkeletonCard(height: 120),
          SizedBox(height: 12),
          _GameSkeletonCard(height: 120),
          SizedBox(height: 12),
          _GameSkeletonCard(height: 120),
        ],
      ),
    );
  }
}

class _FloatingSvgBadge extends StatefulWidget {
  const _FloatingSvgBadge({
    required this.svg,
    this.size = 64,
    this.opacity = 1,
  });

  final String svg;
  final double size;
  final double opacity;

  @override
  State<_FloatingSvgBadge> createState() => _FloatingSvgBadgeState();
}

class _FloatingSvgBadgeState extends State<_FloatingSvgBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionCtrl;

  @override
  void initState() {
    super.initState();
    _motionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _motionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motionCtrl,
      builder: (context, child) {
        final dx = math.sin(_motionCtrl.value * math.pi * 2) * 9;
        final dy = math.cos(_motionCtrl.value * math.pi * 2) * 7;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: Opacity(
        opacity: widget.opacity,
        child: SvgPicture.string(
          widget.svg,
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}

class _GameBadgeShell extends StatelessWidget {
  const _GameBadgeShell({
    required this.svg,
    this.active = true,
    this.size = 62,
  });

  final String svg;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: active ? _accentGradient : null,
        color: active ? null : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        boxShadow:
            active
                ? [
                  BoxShadow(
                    color: detailsColor1.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
                : null,
      ),
      child: _FloatingSvgBadge(
        svg: svg,
        size: size,
        opacity: active ? 1 : 0.65,
      ),
    );
  }
}

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
    if (id == '_quintprime') return 'assets/avatars/quint_prime.png';
    if (id == '_beyondbig') return 'assets/avatars/beyond_big.png';
    if (id == '_groseline') return 'assets/avatars/groseline.png';
    if (id == '_gay') return 'assets/avatars/gay.png';
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
    unawaited(_trackGameHubOpen());
  }

  Future<void> _trackGameHubOpen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ActivityTrackingService.trackForUser(
      uid: uid,
      type: 'game_hub_opened',
      label: 'Game hub',
      points: 3,
      counters: const <String, int>{'game_hub_visits': 1},
    );
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

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
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
      stream:
          user != null
              ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots()
              : null,
      builder: (context, userSnapshot) {
        final bool isAdmin =
            (userSnapshot.data?.data() as Map<String, dynamic>?)?['isAdmin'] ??
            false;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
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
                  final userData = snapshot.data?.data() ?? <String, dynamic>{};
                  final avatarId = userData['avatar_id'] as String?;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  return GestureDetector(
                    onLongPress:
                        avatarId == null || currentUser == null
                            ? null
                            : () {
                              HapticFeedback.mediumImpact();
                              showAvatarPreview(
                                context,
                                _getAvatarAsset(avatarId),
                              );
                            },
                    child: IconButton(
                      icon:
                          avatarId != null
                              ? Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: AssetImage(
                                      _getAvatarAsset(avatarId),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                              : const Icon(
                                Icons.account_circle_rounded,
                                color: textColor,
                                size: 28,
                              ),
                      onPressed:
                          currentUser == null
                              ? null
                              : () => _openProfileSheet(
                                userId: currentUser.uid,
                                userData: userData,
                              ),
                    ),
                  );
                },
              ),

              actions: [
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
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _GameHubTabStrip(),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ProgressionHubList(isAdmin: isAdmin),
                      _GamesHubList(
                        isAdmin: isAdmin,
                        scenarioCount: _scenarios.length,
                        completedCount: _completedScenarios.length,
                        loading: _isLoadingScenarios,
                        onOpenSimulationHub: () => _openSimulationHub(isAdmin),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSimulationHub(bool isAdmin) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      builder:
          (_) => _SimulationHubSheet(
            isAdmin: isAdmin,
            scenarios: _scenarios,
            completedScenarios: _completedScenarios,
            isLoadingScenarios: _isLoadingScenarios,
            loadingError: _loadingError,
            onRetry: _loadScenarios,
            onOpenScenario: _openScenario,
          ),
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
        MaterialPageRoute(builder: (_) => SimulationRunner(scenario: scenario)),
      );
      _loadGameProgress();
    }
  }

  Future<void> _openProfileSheet({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    if (!mounted) return;
    await showSocialProfileSheet(
      context: context,
      userId: userId,
      initialUserData: userData,
      metric: SocialProfileMetric.level,
    );
  }
}

class _DailyRewardCard extends StatefulWidget {
  // ignore: unused_element_parameter
  const _DailyRewardCard({this.isAdmin = false});
  final bool isAdmin;

  @override
  State<_DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends State<_DailyRewardCard> {
  bool _loading = true;
  bool _canClaim = false;
  bool _claiming = false;
  bool _canClaimAdBonus = false;
  bool _claimingAdBonus = false;
  bool _adLoading = false;
  bool _adReady = false;

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
      final now = DateTime.now();
      final dailyClaimed = DailyRewardService.hasClaimedToday(
        (data?['last_daily_reward'] as Timestamp?)?.toDate(),
        now: now,
      );
      final adBonusClaimed = DailyRewardService.hasClaimedToday(
        (data?['last_daily_reward_ad'] as Timestamp?)?.toDate(),
        now: now,
      );
      final canClaimAdBonus =
          dailyClaimed &&
          !adBonusClaimed &&
          AdConfig.isRewardedDailyBonusEnabled;

      if (mounted) {
        setState(() {
          _canClaim = !dailyClaimed;
          _canClaimAdBonus = canClaimAdBonus;
          _loading = false;
          _claiming = false;
          _claimingAdBonus = false;
          _adLoading = false;
          _adReady = canClaimAdBonus && RewardedAdService.instance.isReady;
        });
      }
      if (canClaimAdBonus) {
        unawaited(_prepareAdBonus(showError: false));
      }
    } catch (e) {
      debugPrint("Error checking daily reward: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          _claiming = false;
          _claimingAdBonus = false;
          _adLoading = false;
        });
      }
    }
  }

  Future<void> _claimReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_canClaim) {
      return;
    }
    setState(() {
      _loading = true;
      _claiming = true;
    });
    final grant = DailyRewardService.rollDailyReward();

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await ref.set({
        grant.currencyKey: FieldValue.increment(grant.amount),
        'last_daily_reward': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      unawaited(
        ActivityTrackingService.trackForUser(
          uid: user.uid,
          type: 'daily_reward_claimed',
          label: 'Récompense quotidienne',
          points: grant.activityPoints,
          counters: const <String, int>{'daily_rewards_claimed': 1},
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🎁 Récompense récupérée : +${grant.amount} ${grant.label} !",
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _canClaim = false;
          _canClaimAdBonus = AdConfig.isRewardedDailyBonusEnabled;
          _loading = false;
          _claiming = false;
        });
      }
      if (AdConfig.isRewardedDailyBonusEnabled) {
        unawaited(_prepareAdBonus(showError: false));
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
        setState(() {
          _loading = false;
          _claiming = false;
        });
      }
    }
  }

  Future<void> _prepareAdBonus({bool showError = true}) async {
    if (!_canClaimAdBonus || !AdConfig.isRewardedDailyBonusEnabled) {
      if (mounted) {
        setState(() {
          _adLoading = false;
          _adReady = false;
        });
      }
      return;
    }
    if (_adLoading) return;

    setState(() {
      _adLoading = true;
    });

    final loaded = await RewardedAdService.instance.load();
    if (!mounted) return;

    setState(() {
      _adLoading = false;
      _adReady = loaded && RewardedAdService.instance.isReady;
    });

    if (!loaded && showError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La pub de test n'est pas encore prête."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _claimAdBonus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_canClaimAdBonus || _claimingAdBonus) {
      return;
    }

    if (!_adReady) {
      await _prepareAdBonus();
      if (!mounted || !_adReady) {
        return;
      }
    }

    setState(() {
      _claimingAdBonus = true;
    });

    final shown = await RewardedAdService.instance.show(
      onRewardEarned: () {
        unawaited(_grantAdBonusReward(user.uid));
      },
      onClosed: (rewardEarned) {
        if (!mounted || rewardEarned) return;
        setState(() {
          _claimingAdBonus = false;
          _adReady = RewardedAdService.instance.isReady;
        });
        unawaited(_prepareAdBonus(showError: false));
      },
      onFailedToShow: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir la pub de test pour le moment."),
            backgroundColor: Colors.red,
          ),
        );
      },
    );

    if (!shown && mounted) {
      setState(() {
        _claimingAdBonus = false;
        _adReady = RewardedAdService.instance.isReady;
      });
    }
  }

  Future<void> _grantAdBonusReward(String uid) async {
    final grant = DailyRewardService.rollAdBonusReward();

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      await ref.set({
        grant.currencyKey: FieldValue.increment(grant.amount),
        'last_daily_reward_ad': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      unawaited(
        ActivityTrackingService.trackForUser(
          uid: uid,
          type: 'daily_reward_ad_claimed',
          label: 'Bonus pub quotidien',
          points: grant.activityPoints,
          counters: const <String, int>{'daily_reward_ads_claimed': 1},
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🎬 Bonus pub récupéré : +${grant.amount} ${grant.label} !",
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _canClaimAdBonus = false;
        _claimingAdBonus = false;
        _adReady = false;
      });
    } catch (e) {
      debugPrint("Error claiming rewarded ad bonus: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de l'attribution du bonus pub."),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _claimingAdBonus = false;
        _adReady = RewardedAdService.instance.isReady;
      });
      unawaited(_prepareAdBonus(showError: false));
    }
  }

  Future<void> _resetReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'last_daily_reward': FieldValue.delete(),
      'last_daily_reward_ad': FieldValue.delete(),
    });
    _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _DailyRewardLoadingCard(claiming: _claiming);
    }

    final badgeActive = _canClaim || _canClaimAdBonus;
    final statusLabel =
        _canClaim
            ? 'Disponible maintenant'
            : _canClaimAdBonus
            ? (_adReady ? 'Bonus pub prêt' : 'Préparation pub de test')
            : AdConfig.isRewardedDailyBonusEnabled
            ? 'Reviens demain'
            : 'iOS uniquement';
    final statusColor =
        _canClaim || _canClaimAdBonus ? detailsColor2 : Colors.green;
    final subtitle =
        _canClaim
            ? 'Cadeau gratuit : 100-300 coins ou 2-6 gems.'
            : _canClaimAdBonus
            ? 'Second cadeau via une pub de test : 40-80 coins ou 1-2 gems.'
            : AdConfig.isRewardedDailyBonusEnabled
            ? 'Cadeau gratuit et bonus pub déjà récupérés aujourd’hui.'
            : 'Déjà récupérée aujourd’hui. Le bonus pub est activé sur iOS uniquement.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: _softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GameBadgeShell(
            svg: _dailyRewardCardSvg,
            active: badgeActive,
            size: 56,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 12, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Récompense quotidienne",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (_canClaim || _canClaimAdBonus)
                                  ? detailsColor1.withValues(alpha: 0.12)
                                  : Colors.green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (_canClaim)
                        _DailyRewardActionButton(
                          icon: Icons.card_giftcard_rounded,
                          label:
                              _claiming
                                  ? 'Récupération...'
                                  : 'Récupérer le cadeau',
                          onPressed: _claiming ? null : _claimReward,
                        )
                      else if (_canClaimAdBonus)
                        _DailyRewardActionButton(
                          icon:
                              _adReady
                                  ? Icons.ondemand_video_rounded
                                  : Icons.downloading_rounded,
                          label:
                              _claimingAdBonus
                                  ? 'Pub en cours...'
                                  : _adReady
                                  ? 'Voir une pub de test'
                                  : _adLoading
                                  ? 'Chargement...'
                                  : 'Préparer la pub',
                          onPressed:
                              _claimingAdBonus
                                  ? null
                                  : _adReady
                                  ? _claimAdBonus
                                  : () => _prepareAdBonus(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.isAdmin && !_canClaim && !_canClaimAdBonus)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: _resetReward,
              tooltip: "Reset (Admin)",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: badgeActive ? _accentGradient : null,
                color:
                    badgeActive ? null : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                _canClaim
                    ? Icons.card_giftcard_rounded
                    : _canClaimAdBonus
                    ? Icons.ondemand_video_rounded
                    : Icons.check_circle_rounded,
                color: badgeActive ? Colors.white : Colors.green,
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyRewardLoadingCard extends StatefulWidget {
  const _DailyRewardLoadingCard({required this.claiming});

  final bool claiming;

  @override
  State<_DailyRewardLoadingCard> createState() =>
      _DailyRewardLoadingCardState();
}

class _DailyRewardLoadingCardState extends State<_DailyRewardLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loaderCtrl;

  @override
  void initState() {
    super.initState();
    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _loaderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.claiming
            ? 'Distribution du cadeau...'
            : 'Chargement de la récompense';
    final subtitle =
        widget.claiming
            ? 'Préparation de ton lot du jour, ne ferme pas la page.'
            : 'Vérification de la disponibilité du cadeau quotidien.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: _softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: AnimatedBuilder(
              animation: _loaderCtrl,
              builder: (context, child) {
                final angle = _loaderCtrl.value * math.pi * 2;
                final pulse = 0.98 + math.sin(angle).abs() * 0.08;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: angle,
                      child: SvgPicture.string(
                        _dailyRewardLoaderOrbitSvg,
                        width: 72,
                        height: 72,
                      ),
                    ),
                    Transform.scale(scale: pulse, child: child),
                  ],
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: _accentGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: detailsColor1.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SvgPicture.string(
                  _dailyRewardCardSvg,
                  width: 42,
                  height: 42,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 12, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: detailsColor1.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Synchronisation en cours',
                      style: TextStyle(
                        color: detailsColor2,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: detailsColor2.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: detailsColor2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRewardActionButton extends StatelessWidget {
  const _DailyRewardActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: detailsColor2,
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.12),
        disabledForegroundColor: Colors.black45,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _QuestAccessCard extends StatelessWidget {
  const _QuestAccessCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseAuth.instance.currentUser != null
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
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final now = DateTime.now();
          final todayStr = "${now.year}-${now.month}-${now.day}";
          if (data['date'] == todayStr) {
            final qDone =
                (data['quizzes_done'] ?? 0) >= 1 &&
                !(data['claimed_quizzes'] ?? false);
            final lDone =
                (data['lessons_done'] ?? 0) >= 1 &&
                !(data['claimed_lessons'] ?? false);
            final tDone =
                (data['trades_done'] ?? 0) >= 1 &&
                !(data['claimed_trades'] ?? false);
            hasPendingReward = qDone || lDone || tDone;
          }
        }

        return GestureDetector(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoalPage()),
              ),
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: _softShadow,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 190;
                    final badgeSize = compact ? 46.0 : 56.0;
                    final titleStyle = TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: compact ? 1.15 : null,
                    );
                    final subtitleStyle = TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      fontSize: compact ? 11.5 : 13,
                    );

                    final trailingAction = Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: hasPendingReward ? _accentGradient : null,
                        color:
                            hasPendingReward
                                ? null
                                : detailsColor2.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        hasPendingReward
                            ? Icons.redeem_rounded
                            : Icons.arrow_forward_rounded,
                        color: hasPendingReward ? Colors.white : detailsColor2,
                      ),
                    );

                    final textBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Quêtes & Succès",
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          compact
                              ? "Récompenses du jour et succès."
                              : "Récupère tes récompenses journalières et surveille tes succès globaux.",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasPendingReward
                              ? 'Récompense dispo'
                              : 'Progression du jour',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                hasPendingReward ? Colors.red : Colors.black54,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _GameBadgeShell(
                                svg: _questCardSvg,
                                size: badgeSize,
                              ),
                              const Spacer(),
                              trailingAction,
                            ],
                          ),
                          const SizedBox(height: 12),
                          textBlock,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GameBadgeShell(svg: _questCardSvg, size: badgeSize),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 12),
                            child: textBlock,
                          ),
                        ),
                        trailingAction,
                      ],
                    );
                  },
                ),
              ),
              if (hasPendingReward)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GameHubCard extends StatelessWidget {
  const _GameHubCard({
    required this.title,
    required this.subtitle,
    required this.svg,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String svg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            const SizedBox(width: 2),
            _GameBadgeShell(svg: svg, size: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: _accentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: detailsColor1.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameHubTabStrip extends StatelessWidget {
  const _GameHubTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: _softShadow,
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: _accentGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        tabs: const [Tab(text: 'Progression'), Tab(text: 'Jeux')],
      ),
    );
  }
}

class _ProgressionHubList extends StatelessWidget {
  const _ProgressionHubList({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _DailyRewardCard(isAdmin: isAdmin),
        const _ShopAccessCard(),
        const _QuestAccessCard(),
      ],
    );
  }
}

class _GamesHubList extends StatelessWidget {
  const _GamesHubList({
    required this.isAdmin,
    required this.scenarioCount,
    required this.completedCount,
    required this.loading,
    required this.onOpenSimulationHub,
  });

  final bool isAdmin;
  final int scenarioCount;
  final int completedCount;
  final bool loading;
  final VoidCallback onOpenSimulationHub;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SimulationHubAccessCard(
          isAdmin: isAdmin,
          scenarioCount: scenarioCount,
          completedCount: completedCount,
          loading: loading,
          onTap: onOpenSimulationHub,
        ),
        const _NewsGameCard(),
        _TermDepositAccessCard(isAdmin: isAdmin),
        const _IncomeStatementGameCard(),
      ],
    );
  }
}

class _SimulationHubAccessCard extends StatelessWidget {
  const _SimulationHubAccessCard({
    required this.isAdmin,
    required this.scenarioCount,
    required this.completedCount,
    required this.loading,
    required this.onTap,
  });

  final bool isAdmin;
  final int scenarioCount;
  final int completedCount;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        loading
            ? 'Chargement des scénarios en cours...'
            : scenarioCount == 0
            ? 'Ouvre le hub pour lancer tes simulations'
            : '$scenarioCount scénarios • $completedCount terminés';
    return _GameHubCard(
      title: 'Scénarios de marché',
      subtitle: subtitle,
      svg: _simulationCardSvg,
      onTap: onTap,
    );
  }
}

class _TermDepositAccessCard extends StatelessWidget {
  const _TermDepositAccessCard({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return _GameHubCard(
      title: 'Compte à terme',
      subtitle:
          isAdmin
              ? 'Gère les dépôts et les rendements garantis'
              : 'Place tes pièces ou gemmes avec rendement garanti',
      svg: _termDepositCardSvg,
      onTap:
          () => showCupertinoModalBottomSheet(
            context: context,
            expand: true,
            builder: (_) => const _TermDepositHubSheet(),
          ),
    );
  }
}

class _IncomeStatementGameCard extends StatelessWidget {
  const _IncomeStatementGameCard();

  @override
  Widget build(BuildContext context) {
    return _GameHubCard(
      title: 'Stock Analyst',
      subtitle: 'Devine la note fondamentale à partir des métriques brutes',
      svg: _stockAnalystCardSvg,
      onTap:
          () => showCupertinoModalBottomSheet(
            context: context,
            expand: true,
            builder: (_) => const IncomeStatementGamePage(),
          ),
    );
  }
}

class _TermDepositHubSheet extends StatelessWidget {
  const _TermDepositHubSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Compte à terme',
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: const TermDepositSection(),
        ),
      ),
    );
  }
}

class _SimulationHubSheet extends StatelessWidget {
  const _SimulationHubSheet({
    required this.isAdmin,
    required this.scenarios,
    required this.completedScenarios,
    required this.isLoadingScenarios,
    required this.loadingError,
    required this.onRetry,
    required this.onOpenScenario,
  });

  final bool isAdmin;
  final List<PortfolioScenario> scenarios;
  final Set<String> completedScenarios;
  final bool isLoadingScenarios;
  final String? loadingError;
  final VoidCallback onRetry;
  final Future<void> Function(PortfolioScenario scenario) onOpenScenario;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Scénarios de marché',
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: _softShadow,
              ),
              child: const Text(
                "Retrouve ici les scénarios de simulation de marché et progresse au fil des niveaux. Le portefeuille de jeu se pilote désormais depuis l'onglet Dashboard.",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream:
                  user != null
                      ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('games')
                          .doc('progress')
                          .snapshots()
                      : null,
              builder: (context, progressSnapshot) {
                final data =
                    progressSnapshot.data?.data() as Map<String, dynamic>?;
                final xp = data?['xp'] as int? ?? 0;
                final level = ScenarioGameEngine.levelFromXp(xp);
                final completedSet =
                    (data?['completed_scenarios'] as List?)
                        ?.map((e) => e.toString())
                        .toSet() ??
                    completedScenarios;

                if (isLoadingScenarios) {
                  return const _GameScenarioSkeletonList();
                }
                if (loadingError != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          loadingError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }
                if (scenarios.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucun scénario disponible pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream:
                      user != null
                          ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('games')
                              .doc('scenario_campaign')
                              .snapshots()
                          : null,
                  builder: (context, campaignSnapshot) {
                    final campaign = ScenarioCampaignProgress.fromMap(
                      campaignSnapshot.data?.data(),
                    );
                    final totalStars = campaign.chapterStars.values.fold<int>(
                      0,
                      (sum, value) => sum + value,
                    );
                    final bestGlobalScore =
                        campaign.scenarioBestScores.values.isEmpty
                            ? 0
                            : campaign.scenarioBestScores.values.reduce(
                              math.max,
                            );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                            boxShadow: _softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Nouvelle campagne narrative: thèse initiale, décisions sous incertitude, scoring multi-critères et branches rejouables.",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    label: 'Niveau $level',
                                    icon: Icons.flag_rounded,
                                  ),
                                  _InfoChip(
                                    label: '$totalStars étoiles',
                                    icon: Icons.star_rounded,
                                  ),
                                  _InfoChip(
                                    label: 'Best $bestGlobalScore',
                                    icon: Icons.insights_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ...kScenarioChapters.map((chapter) {
                          final chapterScenarios =
                              scenarios
                                  .where(
                                    (scenario) =>
                                        scenario.chapterId == chapter.id,
                                  )
                                  .toList();
                          if (chapterScenarios.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final unlocked =
                              isAdmin ||
                              ScenarioGameEngine.isChapterUnlocked(
                                chapter: chapter,
                                level: level,
                                campaign: campaign,
                              );
                          final chapterStars =
                              campaign.chapterStars[chapter.id] ?? 0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chapter.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            chapter.subtitle,
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            unlocked
                                                ? Colors.white
                                                : Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        unlocked
                                            ? '$chapterStars★'
                                            : 'Niv. ${chapter.requiredLevel} + ${chapter.requiredStarsFromPrevious}★',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color:
                                              unlocked
                                                  ? detailsColor2
                                                  : Colors.black45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...chapterScenarios.map((scenario) {
                                final isCompleted = completedSet.contains(
                                  scenario.id,
                                );
                                final isLocked =
                                    !isAdmin &&
                                    !ScenarioGameEngine.isScenarioUnlocked(
                                      scenario: scenario,
                                      level: level,
                                      campaign: campaign,
                                    );
                                final dailyConsumed =
                                    !ScenarioGameEngine.hasDailySettlementAvailable(
                                      scenarioId: scenario.id,
                                      campaign: campaign,
                                      now: DateTime.now(),
                                    );
                                return Padding(
                                  key: ValueKey(scenario.id),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ScenarioCard(
                                    scenario: scenario,
                                    isCompleted: isCompleted,
                                    isLocked: isLocked,
                                    requiredLevel: scenario.requiredLevel,
                                    chapterLabel: chapter.title,
                                    bestMedal:
                                        campaign.scenarioBestMedals[scenario
                                            .id],
                                    bestScore:
                                        campaign.scenarioBestScores[scenario
                                            .id],
                                    dailySettlementConsumed: dailyConsumed,
                                    onTap:
                                        isLocked
                                            ? () => ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Chapitre verrouillé: niv. ${scenario.requiredLevel} et progression campagne requis.",
                                                ),
                                              ),
                                            )
                                            : () => onOpenScenario(scenario),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: detailsColor2),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuizCard extends StatefulWidget {
  // ignore: unused_element_parameter
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
        final questDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('quests')
                .doc('daily')
                .get();

        if (questDoc.exists && questDoc.data()?['date'] == dateStr) {
          final int done =
              (questDoc.data()?['quizzes_done'] as num?)?.toInt() ?? 0;
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
    if (id == '_quintprime') return 'assets/avatars/quint_prime.png';
    if (id == '_beyondbig') return 'assets/avatars/beyond_big.png';
    if (id == '_groseline') return 'assets/avatars/groseline.png';
    if (id == '_gay') return 'assets/avatars/gay.png';
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
        final achievements = List<String>.from(
          userData?['achievements_claimed'] ?? [],
        );
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

            final level =
                (math.log((xp / 500) + 1) / math.log(1.2)).floor() + 1;
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
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                        'achievements_claimed': FieldValue.arrayUnion([
                          'wealthy_10k',
                        ]),
                        'unlocked_avatars': FieldValue.arrayUnion(['_wealthy']),
                      }, SetOptions(merge: true));

                  final wealthyUserRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid);
                  await wealthyUserRef
                      .collection('games')
                      .doc('progress')
                      .set({
                        'xp': FieldValue.increment(200),
                      }, SetOptions(merge: true));
                  await wealthyUserRef.set({
                    'xp': FieldValue.increment(200),
                  }, SetOptions(merge: true));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Succès débloqué : Économe (10k) ! Avatar Wealthy + 200 XP",
                        ),
                        backgroundColor: Colors.purple,
                      ),
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

                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                        'coins': FieldValue.increment(totalCoins),
                        'gems': FieldValue.increment(totalGems),
                        if (newAvatars.isNotEmpty)
                          'unlocked_avatars': FieldValue.arrayUnion(newAvatars),
                      }, SetOptions(merge: true));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Niveau $level atteint ! +$totalGems Gemmes, +$totalCoins Pièces${newAvatars.isNotEmpty ? ', Avatar débloqué !' : ''}',
                        ),
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
                    margin: const EdgeInsets.only(top: 80, bottom: 16),
                    padding: const EdgeInsets.fromLTRB(16, 90, 16, 16),
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
                        () => _showAvatarPreview(
                          context,
                          avatarId,
                          allUnlocked,
                        ),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child:
                          avatarId != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(36),
                                child: Image.asset(
                                  _getAvatarAsset(avatarId),
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 80,
                                        color: Colors.grey,
                                      ),
                                ),
                              )
                              : const Icon(
                                Icons.person,
                                size: 80,
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

  void _showAvatarPreview(
    BuildContext context,
    String? avatarId,
    List<String> allUnlocked,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image agrandie
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: avatarId != null
                    ? Image.asset(
                        _getAvatarAsset(avatarId),
                        width: 280,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 280,
                          height: 280,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.person, size: 120, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(Icons.person, size: 120, color: Colors.grey),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.close, color: Colors.white70),
                    label: const Text('Fermer', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showAvatarSelector(context, avatarId, allUnlocked);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Changer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      '_quintprime',
      '_beyondbig',
      '_groseline',
      '_gay',
      '_call',
      '_happy',
      '_wealthy',
      '_rich',
    ];

    // Avatars cachés tant qu'ils ne sont pas débloqués (codes secrets)
    final Set<String> secretAvatars = {'_easteregg', '_sydsteregg', '_quintprime', '_beyondbig', '_groseline', '_gay'};

    final List<String> allAvatars =
        specialAvatars.where((id) {
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
    return _GameHubCard(
      title: 'Boutique',
      subtitle: 'Coins, gems, boosts et cosmétiques pour ton profil de jeu.',
      onTap:
          () => showCupertinoModalBottomSheet(
            context: context,
            builder: (context) => const ShopPage(),
          ),
      svg: _shopCardSvg,
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
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, userSnap) {
        final coins =
            (userSnap.data?.data() as Map<String, dynamic>?)?['coins'] ?? 0;
        final gems =
            (userSnap.data?.data() as Map<String, dynamic>?)?['gems'] ?? 0;

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
              const Icon(
                Icons.monetization_on_rounded,
                color: detailsColor1,
                size: 16,
              ),
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
      },
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
    return _GameHubCard(
      title: 'Actu & Quiz',
      subtitle: "Actus du jour, quiz dynamiques et MapMonde interactive",
      svg: _newsCardSvg,
      onTap:
          () => showCupertinoModalBottomSheet(
            context: context,
            builder: (_) => const DailyNewsGameSheet(),
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
    if (mounted) {
      setState(() {
        _enabled = v;
        _loading = false;
      });
    }
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
