import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintech/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../models/chart_models.dart';
import '../services/yahoo_finance_service.dart';
import 'info_page.dart';
import 'simulation_game.dart';

class GamePortfolioDashboardSheet extends StatefulWidget {
  const GamePortfolioDashboardSheet({super.key, required this.uid});

  final String uid;

  @override
  State<GamePortfolioDashboardSheet> createState() =>
      _GamePortfolioDashboardSheetState();
}

class _GamePortfolioDashboardSheetState
    extends State<GamePortfolioDashboardSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  Future<_GamePortfolioAnalytics>? _analyticsFuture;
  String? _analyticsSignature;
  int _refreshTick = 0;
  int? _scenarioCount;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    unawaited(_loadScenarioCount());
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _loadScenarioCount() async {
    try {
      final count = await PortfolioScenario.loadScenarios().then(
        (v) => v.length,
      );
      if (!mounted) return;
      setState(() {
        _scenarioCount = count;
        _analyticsSignature = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scenarioCount = 0;
      });
    }
  }

  void _forceRefresh() {
    setState(() {
      _refreshTick += 1;
      _analyticsSignature = null;
      _analyticsFuture = null;
    });
  }

  Future<_GamePortfolioAnalytics> _futureFor(_GamePortfolioSource source) {
    final signature = '${source.signature}|refresh=$_refreshTick';
    if (_analyticsFuture != null && _analyticsSignature == signature) {
      return _analyticsFuture!;
    }
    _analyticsSignature = signature;
    _analyticsFuture = _computeAnalytics(source).then((analytics) async {
      await _syncMilestones(analytics);
      return analytics;
    });
    return _analyticsFuture!;
  }

  Future<void> _syncMilestones(_GamePortfolioAnalytics analytics) async {
    if (analytics.investedCapital < 50000) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);
    final userSnapshot = await userRef.get();
    final claimed =
        (userSnapshot.data()?['achievements_claimed'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    if (claimed.contains('investor_50k')) return;

    await userRef.set({
      'achievements_claimed': FieldValue.arrayUnion(['investor_50k']),
      'unlocked_avatars': FieldValue.arrayUnion(['_rich']),
      'gems': FieldValue.increment(100),
    }, SetOptions(merge: true));
    await userRef.collection('games').doc('progress').set({
      'xp': FieldValue.increment(400),
    }, SetOptions(merge: true));
  }

  Future<void> _openInfo(_GamePositionAnalytics position) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      builder:
          (_) => InfoPage(
            ticker: position.symbol,
            initialName: position.displayName,
            initialExchange: position.exchange,
            initialCurrency: position.currency,
            initialQuoteType: position.quoteType,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);

    return DefaultTabController(
      length: 4,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnapshot) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userRef.collection('games').doc('progress').snapshots(),
            builder: (context, progressSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    userRef
                        .collection('games')
                        .doc('portofolio')
                        .collection('positions')
                        .snapshots(),
                builder: (context, positionsSnapshot) {
                  if (userSnapshot.hasError ||
                      progressSnapshot.hasError ||
                      positionsSnapshot.hasError) {
                    return _SheetScaffold(
                      onRefresh: _forceRefresh,
                      child: _SheetErrorState(
                        message:
                            'Impossible de charger le portefeuille de jeu pour le moment.',
                        onRetry: _forceRefresh,
                      ),
                    );
                  }

                  final waitingForStreams =
                      !userSnapshot.hasData ||
                      !progressSnapshot.hasData ||
                      !positionsSnapshot.hasData;
                  if (waitingForStreams) {
                    return _SheetScaffold(
                      onRefresh: _forceRefresh,
                      child: const _SheetLoadingState(),
                    );
                  }

                  final source = _GamePortfolioSource.fromSnapshots(
                    userData: userSnapshot.data?.data(),
                    progressData: progressSnapshot.data?.data(),
                    positions: positionsSnapshot.data?.docs ?? const [],
                    scenarioCount: _scenarioCount,
                  );

                  return _SheetScaffold(
                    onRefresh: _forceRefresh,
                    child: FutureBuilder<_GamePortfolioAnalytics>(
                      future: _futureFor(source),
                      builder: (context, analyticsSnapshot) {
                        if (analyticsSnapshot.hasError) {
                          return _SheetErrorState(
                            message:
                                'Les indicateurs du portefeuille ne sont pas disponibles.',
                            onRetry: _forceRefresh,
                          );
                        }

                        if (analyticsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !analyticsSnapshot.hasData) {
                          return const _SheetLoadingState();
                        }

                        final analytics =
                            analyticsSnapshot.data ??
                            _GamePortfolioAnalytics.placeholder(source);
                        return _DashboardBody(
                          analytics: analytics,
                          motion: _motionController,
                          onOpenInfo: _openInfo,
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.child, required this.onRefresh});

  final Widget child;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portefeuille de jeu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Vue live, allocation, performance et pilotage.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleButton(icon: Icons.refresh_rounded, onTap: onRefresh),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.analytics,
    required this.motion,
    required this.onOpenInfo,
  });

  final _GamePortfolioAnalytics analytics;
  final Animation<double> motion;
  final Future<void> Function(_GamePositionAnalytics position) onOpenInfo;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HeroCard(analytics: analytics, motion: motion),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabStripHeaderDelegate(
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: _GameTabStrip(),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        children: [
          _OverviewTab(analytics: analytics),
          _PerformanceTab(analytics: analytics),
          _AllocationTab(analytics: analytics),
          _PilotageTab(analytics: analytics, onOpenInfo: onOpenInfo),
        ],
      ),
    );
  }
}

class _TabStripHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabStripHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 82;

  @override
  double get maxExtent => 82;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: backgroundColor, child: child);
  }

  @override
  bool shouldRebuild(covariant _TabStripHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _GameTabStrip extends StatelessWidget {
  const _GameTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
        tabs: const [
          Tab(text: 'Vue'),
          Tab(text: 'Performance'),
          Tab(text: 'Répartition'),
          Tab(text: 'Pilotage'),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.analytics, required this.motion});

  final _GamePortfolioAnalytics analytics;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final pnlPositive = analytics.latentPnlValue >= 0;
    final tabController = DefaultTabController.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9D8A0)),
        boxShadow: [
          BoxShadow(
            color: detailsColor1.withOpacity(0.11),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -14,
              child: AnimatedBuilder(
                animation: motion,
                builder: (context, child) {
                  final dx = math.sin(motion.value * math.pi * 2) * 9;
                  final dy = math.cos(motion.value * math.pi * 2) * 7;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: child,
                  );
                },
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: SvgPicture.string(_gamePortfolioSvg),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.35),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.68),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: detailsColor1.withOpacity(0.28),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_graph_rounded,
                              size: 15,
                              color: detailsColor2,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Table de pilotage',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              pnlPositive
                                  ? const Color(0xFFE8F5EC)
                                  : const Color(0xFFFFEFEA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          pnlPositive
                              ? _formatSignedGameAmount(
                                analytics.latentPnlValue,
                              )
                              : _formatSignedGameAmount(
                                analytics.latentPnlValue,
                              ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color:
                                pnlPositive
                                    ? const Color(0xFF13804A)
                                    : const Color(0xFFB4533B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Capital total de jeu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatGameAmount(analytics.totalCapital),
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analytics.positions.isEmpty
                        ? 'Commence une première ligne pour transformer ta réserve en portefeuille.'
                        : 'Réserve ${_formatGameAmount(analytics.reserveCoins)} • ${analytics.positions.length} lignes actives • niveau ${analytics.level}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroStatChip(
                        label: 'Réserve',
                        value: _formatGameAmount(analytics.reserveCoins),
                      ),
                      _HeroStatChip(
                        label: 'Investi',
                        value: _formatGameAmount(analytics.investedCapital),
                      ),
                      _HeroStatChip(
                        label: 'Niveau',
                        value: '${analytics.level} • ${analytics.xp} XP',
                      ),
                      _HeroStatChip(
                        label: 'Scénarios',
                        value:
                            analytics.scenarioCount != null
                                ? '${analytics.completedScenarioCount}/${analytics.scenarioCount}'
                                : '${analytics.completedScenarioCount}',
                      ),
                      _HeroStatChip(
                        label: 'Gemmes',
                        value: '${analytics.gems}',
                      ),
                      _HeroStatChip(
                        label: 'Avatars',
                        value: '${analytics.unlockedAvatarCount}',
                      ),
                    ],
                  ),
                  if (analytics.fallbackCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${analytics.fallbackCount} ligne(s) utilisent le PRU en secours faute de quote live.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (analytics.positions.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => tabController.animateTo(3),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: detailsColor2.withOpacity(0.18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.72),
                      ),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text(
                        'Piloter mes lignes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.analytics});

  final _GamePortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final best = analytics.bestPerformer;
    final worst = analytics.worstPerformer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _ResponsiveMetricGrid(
          children: [
            _MetricCard(
              title: 'Capital total',
              value: _formatGameAmount(analytics.totalCapital),
              subtitle: 'Réserve + valeur des positions',
            ),
            _MetricCard(
              title: 'Réserve coins',
              value: _formatGameAmount(analytics.reserveCoins),
              subtitle:
                  analytics.totalCapital <= 0
                      ? 'Disponible'
                      : '${_formatPercent((analytics.cashWeight * 100).clamp(0, 100))} du capital',
            ),
            _MetricCard(
              title: 'Capital investi',
              value: _formatGameAmount(analytics.investedCapital),
              subtitle: 'Coût de revient cumulé',
            ),
            _MetricCard(
              title: 'P&L latent',
              value: _formatSignedGameAmount(analytics.latentPnlValue),
              subtitle: _formatSignedPercent(analytics.latentPnlPercent),
              accent:
                  analytics.latentPnlValue >= 0
                      ? const Color(0xFF13804A)
                      : const Color(0xFFB4533B),
            ),
            _MetricCard(
              title: 'Niveau de jeu',
              value: 'Niv. ${analytics.level}',
              subtitle: '${analytics.xp} XP cumulés',
            ),
            _MetricCard(
              title: 'Scénarios terminés',
              value:
                  analytics.scenarioCount != null
                      ? '${analytics.completedScenarioCount}/${analytics.scenarioCount}'
                      : '${analytics.completedScenarioCount}',
              subtitle: 'Progression du mode simulation',
            ),
            _MetricCard(
              title: 'Meilleure ligne',
              value:
                  best == null
                      ? 'Aucune'
                      : '${best.symbol} ${_formatSignedPercent(best.pnlPercent)}',
              subtitle:
                  best == null
                      ? 'Ajoute une ligne pour démarrer.'
                      : _formatSignedGameAmount(best.pnlValue),
              accent: const Color(0xFF13804A),
            ),
            _MetricCard(
              title: 'Ligne à surveiller',
              value:
                  worst == null
                      ? 'Aucune'
                      : '${worst.symbol} ${_formatSignedPercent(worst.pnlPercent)}',
              subtitle:
                  worst == null
                      ? 'Pas de baisse significative.'
                      : _formatSignedGameAmount(worst.pnlValue),
              accent: const Color(0xFFB4533B),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InsightCard(
          title: 'Lecture rapide',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analytics.positions.isEmpty
                    ? 'Ton portefeuille de jeu est vide. Utilise la recherche pour acheter une première ligne et déclencher un vrai suivi.'
                    : 'Le portefeuille est actuellement ${analytics.investedWeight >= 0.7
                        ? 'fortement investi'
                        : analytics.cashWeight >= 0.5
                        ? 'très liquide'
                        : 'équilibré'} avec ${analytics.positions.length} ligne(s) et un niveau de concentration de ${_formatPercent(analytics.concentrationRatio * 100)} sur la première position.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SoftChip(
                    label: 'Gemmes ${analytics.gems}',
                    icon: Icons.diamond_outlined,
                  ),
                  _SoftChip(
                    label: 'Avatars ${analytics.unlockedAvatarCount}',
                    icon: Icons.face_retouching_natural_rounded,
                  ),
                  _SoftChip(
                    label: 'Succès ${analytics.achievementsCount}',
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({required this.analytics});

  final _GamePortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics.positions.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.insights_rounded,
        title: 'Pas encore de trajectoire',
        message:
            'Ajoute une ligne pour démarrer la courbe 1 mois de tes positions.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _InsightCard(
          title: 'Valeur des positions sur 1 mois',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatGameAmount(analytics.holdingsValue),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatSignedGameAmount(analytics.historyChangeValue)} sur 1 mois • ${_formatSignedPercent(analytics.historyChangePercent)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                analytics.historyChangeValue >= 0
                                    ? const Color(0xFF13804A)
                                    : const Color(0xFFB4533B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1E6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      analytics.history.points.length > 1
                          ? '${analytics.history.points.length} points'
                          : 'Historique partiel',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 194,
                child: _SparklineChart(series: analytics.history),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Plus haut',
                      value: _formatGameAmount(analytics.historyHigh),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Plus bas',
                      value: _formatGameAmount(analytics.historyLow),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Drawdown',
                      value: _formatPercent(analytics.maxDrawdown * 100),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ResponsiveMetricGrid(
          children: [
            _MetricCard(
              title: 'Valeur actuelle',
              value: _formatGameAmount(analytics.holdingsValue),
              subtitle: 'Sur base quotes live ou PRU',
            ),
            _MetricCard(
              title: 'Coût de revient',
              value: _formatGameAmount(analytics.investedCapital),
              subtitle: 'Capital engagé',
            ),
            _MetricCard(
              title: 'Latent absolu',
              value: _formatSignedGameAmount(analytics.latentPnlValue),
              subtitle: 'Ecart vs coût de revient',
              accent:
                  analytics.latentPnlValue >= 0
                      ? const Color(0xFF13804A)
                      : const Color(0xFFB4533B),
            ),
            _MetricCard(
              title: 'Latent relatif',
              value: _formatSignedPercent(analytics.latentPnlPercent),
              subtitle: 'Pondéré sur les lignes',
              accent:
                  analytics.latentPnlPercent >= 0
                      ? const Color(0xFF13804A)
                      : const Color(0xFFB4533B),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InsightCard(
          title: 'Notes de lecture',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La courbe retrace uniquement la valeur des positions en portefeuille. La réserve de coins reste affichée comme KPI courant et n’est pas injectée dans la série historique.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.45,
                ),
              ),
              if (analytics.fallbackCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${analytics.fallbackCount} ligne(s) n’ont pas retourné de quote exploitable. La valorisation de secours repose sur leur PRU.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AllocationTab extends StatelessWidget {
  const _AllocationTab({required this.analytics});

  final _GamePortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics.positions.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Aucune répartition à afficher',
        message:
            'La répartition cash/investi et les pondérations apparaîtront après ta première position.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _InsightCard(
          title: 'Cash vs capital investi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StackedShareBar(
                leadingWeight: analytics.cashWeight,
                trailingWeight: analytics.investedWeight,
                leadingColor: const Color(0xFFE3C56C),
                trailingColor: detailsColor2,
                leadingLabel:
                    'Réserve ${_formatPercent(analytics.cashWeight * 100)}',
                trailingLabel:
                    'Investi ${_formatPercent(analytics.investedWeight * 100)}',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Cash',
                      value: _formatGameAmount(analytics.reserveCoins),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Positions',
                      value: _formatGameAmount(analytics.holdingsValue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InsightCard(
          title: 'Concentration',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analytics.concentrationRatio >= 0.35
                    ? 'Le portefeuille dépend fortement de sa première ligne.'
                    : 'La concentration reste contenue sur la première ligne.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color:
                      analytics.concentrationRatio >= 0.35
                          ? const Color(0xFFB4533B)
                          : textColor,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: analytics.concentrationRatio.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: const Color(0xFFF4EFE2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    detailsColor2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Poids max ${_formatPercent(analytics.concentrationRatio * 100)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InsightCard(
          title: 'Top positions',
          child: Column(
            children:
                analytics.positions.take(5).map((position) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WeightRow(position: position),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _InsightCard(
          title: 'Devises',
          child: _DistributionWrap(slices: analytics.currencyDistribution),
        ),
        const SizedBox(height: 14),
        _InsightCard(
          title: 'Places de cotation',
          child: _DistributionWrap(slices: analytics.exchangeDistribution),
        ),
      ],
    );
  }
}

class _PilotageTab extends StatelessWidget {
  const _PilotageTab({required this.analytics, required this.onOpenInfo});

  final _GamePortfolioAnalytics analytics;
  final Future<void> Function(_GamePositionAnalytics position) onOpenInfo;

  @override
  Widget build(BuildContext context) {
    if (analytics.positions.isEmpty) {
      return _TabEmptyState(
        icon: Icons.wallet_outlined,
        title: 'Portefeuille prêt à être lancé',
        message:
            'Ajoute une première ligne pour débloquer le pilotage détaillé du portefeuille de jeu.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                title: 'Commandes rapides',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ouvre une ligne pour acheter, vendre ou consulter sa fiche complète dans le flux de trading existant.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...analytics.positions.map(
          (position) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PositionCard(
              position: position,
              onTap: () => onOpenInfo(position),
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position, required this.onTap});

  final _GamePositionAnalytics position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = position.pnlValue >= 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEAE7DE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position.displayName.isEmpty
                              ? position.symbol
                              : position.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          position.symbol,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          positive
                              ? const Color(0xFFE8F5EC)
                              : const Color(0xFFFFEFEA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatSignedPercent(position.pnlPercent),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color:
                            positive
                                ? const Color(0xFF13804A)
                                : const Color(0xFFB4533B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (position.exchange != null &&
                      position.exchange!.isNotEmpty)
                    _SoftChip(
                      label: position.exchange!,
                      icon: Icons.public_rounded,
                    ),
                  if (position.currency != null &&
                      position.currency!.isNotEmpty)
                    _SoftChip(
                      label: position.currency!,
                      icon: Icons.payments_outlined,
                    ),
                  _SoftChip(
                    label: 'Poids ${_formatPercent(position.weight * 100)}',
                    icon: Icons.pie_chart_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Quantité',
                      value: '${position.quantity}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'PRU',
                      value: _formatPrice(
                        position.averagePrice,
                        position.currency,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Cours',
                      value:
                          position.currentPrice == null
                              ? 'N/A'
                              : _formatPrice(
                                position.currentPrice!,
                                position.currency,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Valeur',
                      value: _formatGameAmount(position.currentValue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'P&L',
                      value: _formatSignedGameAmount(position.pnlValue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black38,
                    size: 28,
                  ),
                ],
              ),
              if (position.usesFallbackPrice) ...[
                const SizedBox(height: 10),
                const Text(
                  'Quote live indisponible, valorisation basée sur le PRU.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  const _ResponsiveMetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 1 : 2;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: columns == 1 ? 2.7 : 1.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.accent,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E3D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: accent ?? textColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E3D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DistributionWrap extends StatelessWidget {
  const _DistributionWrap({required this.slices});

  final List<_DistributionSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Text(
        'Données insuffisantes pour établir une répartition fiable.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          slices
              .map(
                (slice) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3E8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${slice.label} · ${_formatPercent(slice.weight * 100)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.position});

  final _GamePositionAnalytics position;

  @override
  Widget build(BuildContext context) {
    final positive = position.pnlValue >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                position.displayName.isEmpty
                    ? position.symbol
                    : position.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatPercent(position.weight * 100),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: position.weight.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0xFFF4EFE2),
            valueColor: AlwaysStoppedAnimation<Color>(
              positive ? const Color(0xFFE3C56C) : detailsColor2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_formatGameAmount(position.currentValue)} • ${_formatSignedPercent(position.pnlPercent)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: positive ? const Color(0xFF13804A) : const Color(0xFFB4533B),
          ),
        ),
      ],
    );
  }
}

class _StackedShareBar extends StatelessWidget {
  const _StackedShareBar({
    required this.leadingWeight,
    required this.trailingWeight,
    required this.leadingColor,
    required this.trailingColor,
    required this.leadingLabel,
    required this.trailingLabel,
  });

  final double leadingWeight;
  final double trailingWeight;
  final Color leadingColor;
  final Color trailingColor;
  final String leadingLabel;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    final total = leadingWeight + trailingWeight;
    final lead = total <= 0 ? 0.0 : leadingWeight / total;
    final trail = total <= 0 ? 0.0 : trailingWeight / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  flex: math.max(1, (lead * 1000).round()),
                  child: Container(color: leadingColor),
                ),
                Expanded(
                  flex: math.max(1, (trail * 1000).round()),
                  child: Container(color: trailingColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendChip(color: leadingColor, label: leadingLabel),
            _LegendChip(color: trailingColor, label: trailingLabel),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: detailsColor2),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: detailsColor1.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Icon(icon, color: textColor, size: 22),
        ),
      ),
    );
  }
}

class _SheetLoadingState extends StatelessWidget {
  const _SheetLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        _SkeletonBox(height: 268, radius: 28),
        SizedBox(height: 14),
        _SkeletonBox(height: 58, radius: 22),
        SizedBox(height: 14),
        _SkeletonBox(height: 140, radius: 24),
        SizedBox(height: 14),
        _SkeletonBox(height: 140, radius: 24),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
    );
  }
}

class _SheetErrorState extends StatelessWidget {
  const _SheetErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: Colors.black38,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: detailsColor2,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: detailsColor2),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.series});

  final _HistorySeries series;

  @override
  Widget build(BuildContext context) {
    if (series.points.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5EC),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Historique insuffisant',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      );
    }

    final points =
        series.points.length == 1
            ? <_HistoryPoint>[
              _HistoryPoint(
                time: series.points.first.time.subtract(
                  const Duration(days: 1),
                ),
                value: series.points.first.value,
              ),
              series.points.first,
            ]
            : series.points;

    final rising = points.last.value >= points.first.value;
    final color = rising ? const Color(0xFF13804A) : const Color(0xFFB4533B);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E1CE)),
      ),
      child: CustomPaint(
        painter: _SparklinePainter(points: points, color: color),
        child: Container(),
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
    if (points.isEmpty) return;

    final values = points.map((point) => point.value).toList();
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < 1e-6) {
      maxValue += 1;
      minValue -= 1;
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final dx =
          points.length == 1
              ? size.width / 2
              : i * size.width / (points.length - 1);
      final normalized = (points[i].value - minValue) / (maxValue - minValue);
      final dy = size.height - (normalized * (size.height - 12)) - 6;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final fillPath =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    final fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            colors: [color.withOpacity(0.22), color.withOpacity(0.02)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);

    final last = points.last;
    final lastNormalized = (last.value - minValue) / (maxValue - minValue);
    final lastDx = size.width;
    final lastDy = size.height - (lastNormalized * (size.height - 12)) - 6;
    canvas.drawCircle(
      Offset(lastDx, lastDy),
      5.5,
      Paint()..color = color.withOpacity(0.16),
    );
    canvas.drawCircle(Offset(lastDx, lastDy), 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _GamePortfolioSource {
  const _GamePortfolioSource({
    required this.coins,
    required this.gems,
    required this.xp,
    required this.unlockedAvatarCount,
    required this.achievementsCount,
    required this.completedScenarioCount,
    required this.scenarioCount,
    required this.positions,
  });

  final int coins;
  final int gems;
  final int xp;
  final int unlockedAvatarCount;
  final int achievementsCount;
  final int completedScenarioCount;
  final int? scenarioCount;
  final List<_GamePositionSnapshot> positions;

  factory _GamePortfolioSource.fromSnapshots({
    required Map<String, dynamic>? userData,
    required Map<String, dynamic>? progressData,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> positions,
    required int? scenarioCount,
  }) {
    final unlocked =
        (userData?['unlocked_avatars'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final achievements =
        (userData?['achievements_claimed'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final completed =
        (progressData?['completed_scenarios'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return _GamePortfolioSource(
      coins: (userData?['coins'] as num?)?.toInt() ?? 0,
      gems: (userData?['gems'] as num?)?.toInt() ?? 0,
      xp: (progressData?['xp'] as num?)?.toInt() ?? 0,
      unlockedAvatarCount: unlocked.length,
      achievementsCount: achievements.length,
      completedScenarioCount: completed.length,
      scenarioCount: scenarioCount,
      positions:
          positions
              .map(_GamePositionSnapshot.fromDoc)
              .where((position) => position.symbol.isNotEmpty)
              .toList(),
    );
  }

  String get signature {
    final buffer =
        StringBuffer()
          ..write(
            'coins=$coins|gems=$gems|xp=$xp|avatars=$unlockedAvatarCount|',
          )
          ..write(
            'achievements=$achievementsCount|completed=$completedScenarioCount|',
          )
          ..write('scenarioCount=${scenarioCount ?? -1}|');
    for (final position in positions) {
      buffer
        ..write(position.symbol)
        ..write(':')
        ..write(position.quantity)
        ..write(':')
        ..write(position.averagePrice.toStringAsFixed(6))
        ..write('|');
    }
    return buffer.toString();
  }
}

class _GamePositionSnapshot {
  const _GamePositionSnapshot({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });

  final String symbol;
  final int quantity;
  final double averagePrice;

  factory _GamePositionSnapshot.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _GamePositionSnapshot(
      symbol: (data['symbol'] as String? ?? doc.id).trim().toUpperCase(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: (data['averagePrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _GamePositionAnalytics {
  const _GamePositionAnalytics({
    required this.symbol,
    required this.displayName,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.currentValue,
    required this.costBasis,
    required this.pnlValue,
    required this.pnlPercent,
    required this.weight,
    required this.exchange,
    required this.currency,
    required this.quoteType,
    required this.usesFallbackPrice,
  });

  final String symbol;
  final String displayName;
  final int quantity;
  final double averagePrice;
  final double? currentPrice;
  final double currentValue;
  final double costBasis;
  final double pnlValue;
  final double pnlPercent;
  final double weight;
  final String? exchange;
  final String? currency;
  final String? quoteType;
  final bool usesFallbackPrice;
}

class _GamePortfolioAnalytics {
  const _GamePortfolioAnalytics({
    required this.positions,
    required this.history,
    required this.reserveCoins,
    required this.investedCapital,
    required this.holdingsValue,
    required this.totalCapital,
    required this.latentPnlValue,
    required this.latentPnlPercent,
    required this.historyChangeValue,
    required this.historyChangePercent,
    required this.historyHigh,
    required this.historyLow,
    required this.maxDrawdown,
    required this.concentrationRatio,
    required this.cashWeight,
    required this.investedWeight,
    required this.currencyDistribution,
    required this.exchangeDistribution,
    required this.bestPerformer,
    required this.worstPerformer,
    required this.fallbackCount,
    required this.level,
    required this.xp,
    required this.gems,
    required this.unlockedAvatarCount,
    required this.achievementsCount,
    required this.completedScenarioCount,
    required this.scenarioCount,
  });

  final List<_GamePositionAnalytics> positions;
  final _HistorySeries history;
  final double reserveCoins;
  final double investedCapital;
  final double holdingsValue;
  final double totalCapital;
  final double latentPnlValue;
  final double latentPnlPercent;
  final double historyChangeValue;
  final double historyChangePercent;
  final double historyHigh;
  final double historyLow;
  final double maxDrawdown;
  final double concentrationRatio;
  final double cashWeight;
  final double investedWeight;
  final List<_DistributionSlice> currencyDistribution;
  final List<_DistributionSlice> exchangeDistribution;
  final _GamePositionAnalytics? bestPerformer;
  final _GamePositionAnalytics? worstPerformer;
  final int fallbackCount;
  final int level;
  final int xp;
  final int gems;
  final int unlockedAvatarCount;
  final int achievementsCount;
  final int completedScenarioCount;
  final int? scenarioCount;

  factory _GamePortfolioAnalytics.placeholder(_GamePortfolioSource source) {
    final reserve = source.coins.toDouble();
    return _GamePortfolioAnalytics(
      positions: const [],
      history: const _HistorySeries(points: <_HistoryPoint>[]),
      reserveCoins: reserve,
      investedCapital: 0,
      holdingsValue: 0,
      totalCapital: reserve,
      latentPnlValue: 0,
      latentPnlPercent: 0,
      historyChangeValue: 0,
      historyChangePercent: 0,
      historyHigh: 0,
      historyLow: 0,
      maxDrawdown: 0,
      concentrationRatio: 0,
      cashWeight: 1,
      investedWeight: 0,
      currencyDistribution: const [],
      exchangeDistribution: const [],
      bestPerformer: null,
      worstPerformer: null,
      fallbackCount: 0,
      level: _levelFromXp(source.xp),
      xp: source.xp,
      gems: source.gems,
      unlockedAvatarCount: source.unlockedAvatarCount,
      achievementsCount: source.achievementsCount,
      completedScenarioCount: source.completedScenarioCount,
      scenarioCount: source.scenarioCount,
    );
  }
}

class _DistributionSlice {
  const _DistributionSlice({required this.label, required this.weight});

  final String label;
  final double weight;
}

class _HistorySeries {
  const _HistorySeries({required this.points});

  final List<_HistoryPoint> points;
}

class _HistoryPoint {
  const _HistoryPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

Future<_GamePortfolioAnalytics> _computeAnalytics(
  _GamePortfolioSource source,
) async {
  final quotes = <String, QuoteDetail?>{};
  final quoteTasks = source.positions.map((position) async {
    try {
      quotes[position.symbol] = await YahooFinanceService.fetchQuote(
        position.symbol,
      );
    } catch (_) {
      quotes[position.symbol] = null;
    }
  });
  await Future.wait(quoteTasks);

  final provisional = <_GamePositionAnalytics>[];
  var fallbackCount = 0;
  var holdingsValue = 0.0;
  var investedCapital = 0.0;

  for (final position in source.positions) {
    final quote = quotes[position.symbol];
    final marketPrice = quote?.regularMarketPrice;
    final fallbackPrice =
        position.averagePrice > 0 ? position.averagePrice : null;
    final currentPrice = marketPrice ?? fallbackPrice;
    final usesFallback = marketPrice == null && fallbackPrice != null;
    if (usesFallback) fallbackCount += 1;

    final currentValue = (currentPrice ?? 0) * position.quantity;
    final costBasis = position.averagePrice * position.quantity;
    final pnlValue = currentValue - costBasis;
    final pnlPercent =
        position.averagePrice > 0 && currentPrice != null
            ? ((currentPrice - position.averagePrice) / position.averagePrice) *
                100
            : 0.0;

    investedCapital += costBasis;
    holdingsValue += currentValue;

    provisional.add(
      _GamePositionAnalytics(
        symbol: position.symbol,
        displayName:
            (quote?.longName?.trim().isNotEmpty ?? false)
                ? quote!.longName!.trim()
                : (quote?.shortName?.trim().isNotEmpty ?? false)
                ? quote!.shortName!.trim()
                : position.symbol,
        quantity: position.quantity,
        averagePrice: position.averagePrice,
        currentPrice: currentPrice,
        currentValue: currentValue,
        costBasis: costBasis,
        pnlValue: pnlValue,
        pnlPercent: pnlPercent,
        weight: 0,
        exchange: quote?.fullExchangeName ?? quote?.exchange,
        currency: quote?.currency,
        quoteType: quote?.quoteType,
        usesFallbackPrice: usesFallback,
      ),
    );
  }

  final reserveCoins = source.coins.toDouble();
  final totalCapital = holdingsValue + reserveCoins;
  final totalWeightBase = holdingsValue > 0 ? holdingsValue : investedCapital;
  final positions =
      provisional
          .map(
            (position) => _GamePositionAnalytics(
              symbol: position.symbol,
              displayName: position.displayName,
              quantity: position.quantity,
              averagePrice: position.averagePrice,
              currentPrice: position.currentPrice,
              currentValue: position.currentValue,
              costBasis: position.costBasis,
              pnlValue: position.pnlValue,
              pnlPercent: position.pnlPercent,
              weight:
                  totalWeightBase <= 0
                      ? 0
                      : (position.currentValue > 0
                          ? position.currentValue / totalWeightBase
                          : position.costBasis / totalWeightBase),
              exchange: position.exchange,
              currency: position.currency,
              quoteType: position.quoteType,
              usesFallbackPrice: position.usesFallbackPrice,
            ),
          )
          .toList()
        ..sort((a, b) => b.currentValue.compareTo(a.currentValue));

  _GamePositionAnalytics? bestPerformer;
  _GamePositionAnalytics? worstPerformer;
  for (final position in positions) {
    if (bestPerformer == null ||
        position.pnlPercent > bestPerformer.pnlPercent) {
      bestPerformer = position;
    }
    if (worstPerformer == null ||
        position.pnlPercent < worstPerformer.pnlPercent) {
      worstPerformer = position;
    }
  }

  final latentPnlValue = holdingsValue - investedCapital;
  final latentPnlPercent =
      investedCapital <= 0 ? 0.0 : (latentPnlValue / investedCapital) * 100;
  final concentrationRatio =
      positions.isEmpty
          ? 0.0
          : positions
              .map((position) => position.weight)
              .reduce((a, b) => a > b ? a : b);
  final cashWeight = totalCapital <= 0 ? 1.0 : reserveCoins / totalCapital;
  final investedWeight = totalCapital <= 0 ? 0.0 : holdingsValue / totalCapital;

  final history = await _buildHistorySeries(source.positions, positions);
  final historyHigh =
      history.points.isEmpty
          ? holdingsValue
          : history.points.map((point) => point.value).reduce(math.max);
  final historyLow =
      history.points.isEmpty
          ? holdingsValue
          : history.points.map((point) => point.value).reduce(math.min);
  final historyChangeValue =
      history.points.length < 2
          ? 0.0
          : history.points.last.value - history.points.first.value;
  final historyChangePercent =
      history.points.length < 2 || history.points.first.value.abs() < 1e-6
          ? 0.0
          : (historyChangeValue / history.points.first.value) * 100;

  var peak = 0.0;
  var maxDrawdown = 0.0;
  for (final point in history.points) {
    if (point.value > peak) peak = point.value;
    if (peak > 0) {
      final drawdown = (peak - point.value) / peak;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }
  }

  return _GamePortfolioAnalytics(
    positions: positions,
    history: history,
    reserveCoins: reserveCoins,
    investedCapital: investedCapital,
    holdingsValue: holdingsValue,
    totalCapital: totalCapital,
    latentPnlValue: latentPnlValue,
    latentPnlPercent: latentPnlPercent,
    historyChangeValue: historyChangeValue,
    historyChangePercent: historyChangePercent,
    historyHigh: historyHigh,
    historyLow: historyLow,
    maxDrawdown: maxDrawdown,
    concentrationRatio: concentrationRatio,
    cashWeight: cashWeight,
    investedWeight: investedWeight,
    currencyDistribution: _buildDistribution(
      positions,
      (position) =>
          (position.currency == null || position.currency!.trim().isEmpty)
              ? 'N/A'
              : position.currency!.trim().toUpperCase(),
    ),
    exchangeDistribution: _buildDistribution(
      positions,
      (position) =>
          (position.exchange == null || position.exchange!.trim().isEmpty)
              ? 'N/A'
              : position.exchange!.trim(),
    ),
    bestPerformer: bestPerformer,
    worstPerformer: worstPerformer,
    fallbackCount: fallbackCount,
    level: _levelFromXp(source.xp),
    xp: source.xp,
    gems: source.gems,
    unlockedAvatarCount: source.unlockedAvatarCount,
    achievementsCount: source.achievementsCount,
    completedScenarioCount: source.completedScenarioCount,
    scenarioCount: source.scenarioCount,
  );
}

List<_DistributionSlice> _buildDistribution(
  List<_GamePositionAnalytics> positions,
  String Function(_GamePositionAnalytics position) selector,
) {
  if (positions.isEmpty) return const [];
  final total = positions.fold<double>(
    0,
    (runningTotal, position) => runningTotal + position.currentValue,
  );
  if (total <= 0) return const [];

  final buckets = <String, double>{};
  for (final position in positions) {
    final label = selector(position);
    buckets[label] = (buckets[label] ?? 0) + position.currentValue;
  }

  return buckets.entries
      .map(
        (entry) => _DistributionSlice(
          label: entry.key,
          weight: (entry.value / total).clamp(0.0, 1.0),
        ),
      )
      .toList()
    ..sort((a, b) => b.weight.compareTo(a.weight));
}

Future<_HistorySeries> _buildHistorySeries(
  List<_GamePositionSnapshot> positions,
  List<_GamePositionAnalytics> analytics,
) async {
  if (positions.isEmpty) {
    return const _HistorySeries(points: <_HistoryPoint>[]);
  }

  final histories = await Future.wait(
    positions.map((position) async {
      try {
        return await YahooFinanceService.fetchHistoricalSeries(
          position.symbol,
          ChartInterval.oneMonth,
        );
      } catch (_) {
        return const <HistoricalPoint>[];
      }
    }),
  );

  final map = SplayTreeMap<DateTime, double>();
  for (var i = 0; i < positions.length; i++) {
    final position = positions[i];
    final history = histories[i];
    for (final point in history) {
      final key = DateTime(point.time.year, point.time.month, point.time.day);
      map[key] = (map[key] ?? 0) + (point.close * position.quantity);
    }
  }

  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);
  final currentTotal = analytics.fold<double>(
    0,
    (runningTotal, position) => runningTotal + position.currentValue,
  );
  if (currentTotal > 0) {
    map[todayKey] = currentTotal;
  }

  if (map.isEmpty && currentTotal > 0) {
    return _HistorySeries(
      points: [
        _HistoryPoint(
          time: today.subtract(const Duration(days: 30)),
          value: currentTotal,
        ),
        _HistoryPoint(time: today, value: currentTotal),
      ],
    );
  }

  final points =
      map.entries
          .map((entry) => _HistoryPoint(time: entry.key, value: entry.value))
          .toList();
  return _HistorySeries(points: points);
}

int _levelFromXp(int xp) {
  return (math.log((xp / 500) + 1) / math.log(1.2)).floor() + 1;
}

String _formatGameAmount(double value) {
  final absolute = value.abs();
  final prefix = value < 0 ? '-' : '';
  if (absolute >= 1000000) {
    return '$prefix${(absolute / 1000000).toStringAsFixed(2)} M';
  }
  if (absolute >= 1000) {
    return '$prefix${(absolute / 1000).toStringAsFixed(1)} k';
  }
  return '$prefix${absolute.toStringAsFixed(0)}';
}

String _formatSignedGameAmount(double value) {
  final sign = value >= 0 ? '+' : '-';
  return '$sign${_formatGameAmount(value.abs())}';
}

String _formatSignedPercent(double value) {
  final fixed =
      value.abs() >= 100 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
  return value >= 0 ? '+$fixed %' : '$fixed %';
}

String _formatPercent(double value) => '${value.toStringAsFixed(1)} %';

String _formatPrice(double value, String? currency) {
  final amount =
      value.abs() >= 1000 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  if (currency == null || currency.isEmpty) return amount;
  return '$amount $currency';
}

const String _gamePortfolioSvg = '''
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F6D97B"/>
      <stop offset="100%" stop-color="#A26242"/>
    </linearGradient>
    <linearGradient id="soft" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFF5D6" stop-opacity="0.95"/>
      <stop offset="100%" stop-color="#F7E6B8" stop-opacity="0.55"/>
    </linearGradient>
  </defs>
  <circle cx="120" cy="96" r="70" fill="url(#soft)"/>
  <path d="M36 144 C56 118, 86 106, 110 114 C136 122, 156 154, 186 150" fill="none" stroke="url(#gold)" stroke-width="8" stroke-linecap="round"/>
  <path d="M50 160 H182" stroke="#8B5E3C" stroke-opacity="0.28" stroke-width="6" stroke-linecap="round"/>
  <rect x="58" y="92" width="20" height="54" rx="10" fill="#E9B84A"/>
  <rect x="94" y="72" width="20" height="74" rx="10" fill="#C98D42"/>
  <rect x="130" y="52" width="20" height="94" rx="10" fill="#8B4F3A"/>
  <circle cx="162" cy="72" r="18" fill="#FFF9EA" stroke="#D7A85A" stroke-width="5"/>
  <path d="M154 72 L160 78 L171 63" fill="none" stroke="#8B4F3A" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';
