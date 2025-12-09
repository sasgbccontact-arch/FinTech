import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../models/chart_models.dart';
import '../services/portfolio_service.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/portfolio_dialogs.dart';
import 'info_page.dart';

/// Tableau de bord des portefeuilles – liste et fiche analytique animée.
class PortfolioDashboardPage extends StatefulWidget {
  const PortfolioDashboardPage({super.key});

  @override
  State<PortfolioDashboardPage> createState() => _PortfolioDashboardPageState();
}

class _PortfolioDashboardPageState extends State<PortfolioDashboardPage> {
  static const Color _bg = Color(0xFFF5F6F7);
  static const Color _muted = Colors.black54;

  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        color: _bg,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline_rounded, color: _muted, size: 32),
            SizedBox(height: 12),
            Text(
              'Connectez-vous pour gérer vos portefeuilles',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('portfolios')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Container(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tableau de bord',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: .2,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Créez et suivez vos portefeuilles d\'actions.',
                        style: TextStyle(
                          fontSize: 15,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildCreateButton(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.black38, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'Impossible de charger vos portefeuilles pour le moment.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return _EmptyPortfolioState(onCreate: _creating ? null : _createPortfolio);
                }

                final portfolios = docs.map((doc) {
                  final data = doc.data();
                  final name = (data['name'] as String? ?? '').trim();
                  final createdAt = data['createdAt'];
                  final updatedAt = data['updatedAt'];
                  final count = (data['positionsCount'] as num?)?.toInt() ?? 0;
                  return _PortfolioSummary(
                    id: doc.id,
                    ref: doc.reference,
                    name: name.isEmpty ? 'Portefeuille' : name,
                    positionsCount: count,
                    createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
                    updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
                  );
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: portfolios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final portfolio = portfolios[index];
                    return _PortfolioCard(
                      summary: portfolio,
                      onTap: () => _openPortfolioDetail(portfolio),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    final bool disabled = _creating;
    return ElevatedButton.icon(
      onPressed: disabled ? null : _createPortfolio,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: disabled
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add_rounded, size: 18),
      label: Text(disabled ? 'Création…' : 'Nouveau'),
    );
  }

  Future<void> _createPortfolio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour créer un portefeuille.')),
      );
      return;
    }

    final name = await showCreatePortfolioDialog(context);
    if (name == null) {
      return;
    }

    setState(() => _creating = true);
    try {
      await PortfolioService.createPortfolio(uid: user.uid, name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Portefeuille "$name" créé.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de créer le portefeuille (${e.message ?? e.code}).'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la création du portefeuille.')),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _openPortfolioDetail(_PortfolioSummary summary) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PortfolioDetailSheet(summary: summary),
    );
  }
}

class _PortfolioSummary {
  const _PortfolioSummary({
    required this.id,
    required this.ref,
    required this.name,
    required this.positionsCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String name;
  final int positionsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.summary, required this.onTap});

  final _PortfolioSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (summary.positionsCount == 0) {
      subtitle = 'Aucune action pour le moment';
    } else if (summary.positionsCount == 1) {
      subtitle = '1 action suivie';
    } else {
      subtitle = '${summary.positionsCount} actions suivies';
    }

    String? updatedText;
    if (summary.updatedAt != null) {
      final day = summary.updatedAt!.day.toString().padLeft(2, '0');
      final month = summary.updatedAt!.month.toString().padLeft(2, '0');
      updatedText = 'Mis à jour le $day/$month/${summary.updatedAt!.year}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                summary.name.substring(0, summary.name.length >= 3 ? 3 : summary.name.length).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (updatedText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      updatedText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38, size: 26),
          ],
        ),
      ),
    );
  }
}

typedef _OpenPositionCallback = void Function(
  String symbol,
  String? name,
  String? exchange,
  String? currency,
  String? quoteType,
);

class _PortfolioDetailSheet extends StatefulWidget {
  const _PortfolioDetailSheet({required this.summary});

  final _PortfolioSummary summary;

  @override
  State<_PortfolioDetailSheet> createState() => _PortfolioDetailSheetState();
}

class _PortfolioDetailSheetState extends State<_PortfolioDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final stream = widget.summary.ref
        .collection('positions')
        .orderBy('addedAt', descending: true)
        .snapshots();
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: maxHeight,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _PortfolioAnalyticsError(
                message: 'Impossible de charger les positions.',
                onRetry: () => setState(() {}),
              );
            }

            final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final positions = docs
                .map(_PortfolioPositionSnapshot.fromDoc)
                .where((p) => p.symbol.isNotEmpty)
                .toList();

            if (positions.isEmpty) {
              return const _PortfolioPositionsEmpty();
            }

            return _PortfolioPositionsView(
              summary: widget.summary,
              positions: positions,
              onOpenPosition: _openInfo,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openInfo(
    String symbol,
    String? name,
    String? exchange,
    String? currency,
    String? quoteType,
  ) async {
    try {
      await showCupertinoModalBottomSheet(
        context: context,
        expand: true,
        builder: (ctx) => InfoPage(
          ticker: symbol,
          initialName: name,
          initialExchange: exchange,
          initialCurrency: currency,
          initialQuoteType: quoteType,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir la fiche de l'action.")),
      );
    }
  }
}

class _PortfolioPositionsView extends StatefulWidget {
  const _PortfolioPositionsView({
    required this.summary,
    required this.positions,
    required this.onOpenPosition,
  });

  final _PortfolioSummary summary;
  final List<_PortfolioPositionSnapshot> positions;
  final _OpenPositionCallback onOpenPosition;

  @override
  State<_PortfolioPositionsView> createState() => _PortfolioPositionsViewState();
}

class _PortfolioPositionsViewState extends State<_PortfolioPositionsView> {
  Future<_PortfolioAnalytics>? _future;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _scheduleComputation();
  }

  @override
  void didUpdateWidget(covariant _PortfolioPositionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSignature = _signatureFor(widget.positions);
    if (newSignature != _signature) {
      _scheduleComputation();
    }
  }

  void _scheduleComputation() {
    final future = widget.positions.isEmpty
        ? Future<_PortfolioAnalytics>.value(_PortfolioAnalytics.empty(widget.positions))
        : _computeAnalytics(widget.positions);
    setState(() {
      _signature = _signatureFor(widget.positions);
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PortfolioAnalytics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _future == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _PortfolioAnalyticsError(
            message: 'Analyse impossible pour l\'instant.',
            onRetry: _scheduleComputation,
          );
        }

        final analytics = snapshot.data ?? _PortfolioAnalytics.empty(widget.positions);
        if (analytics.positions.isEmpty) {
          return const _PortfolioPositionsEmpty();
        }

        return _PortfolioAnalyticsView(
          summary: widget.summary,
          analytics: analytics,
          onOpenPosition: widget.onOpenPosition,
          onRefreshRequested: _scheduleComputation,
        );
      },
    );
  }
}

class _PortfolioAnalyticsView extends StatelessWidget {
  const _PortfolioAnalyticsView({
    required this.summary,
    required this.analytics,
    required this.onOpenPosition,
    required this.onRefreshRequested,
  });

  final _PortfolioSummary summary;
  final _PortfolioAnalytics analytics;
  final _OpenPositionCallback onOpenPosition;
  final VoidCallback onRefreshRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 72,
            flexibleSpace: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            summary.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                          ),
                          if (summary.updatedAt != null)
                            Text(
                              'Mis à jour ${_relativeDate(summary.updatedAt!)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualiser',
                      onPressed: onRefreshRequested,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _OverviewSection(analytics: analytics)),
          if (analytics.history.points.length > 1)
            SliverToBoxAdapter(child: _PerformanceSection(analytics: analytics)),
          SliverToBoxAdapter(
            child: _InsightsSection(
              analytics: analytics,
              onOpenPosition: onOpenPosition,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Positions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final position = analytics.positions[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == analytics.positions.length - 1 ? 0 : 12),
                    child: _PositionTile(
                      analytics: position,
                      onTap: () {
                        final fallbackName = position.snapshot.displayName.isNotEmpty
                            ? position.snapshot.displayName
                            : position.snapshot.symbol;
                        final rawType = position.snapshot.quoteType;
                        final type =
                            rawType.isEmpty || rawType.toUpperCase() == 'UNKNOWN'
                                ? null
                                : rawType;
                        onOpenPosition(
                          position.snapshot.symbol,
                          fallbackName,
                          position.snapshot.exchange,
                          position.snapshot.currency,
                          type,
                        );
                      },
                    ),
                  );
                },
                childCount: analytics.positions.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final changeColor = analytics.totalChangeValue == null
        ? Colors.black
        : analytics.totalChangeValue! >= 0
            ? Colors.green.shade600
            : Colors.red.shade600;

    final valueText = analytics.totalValue != null
        ? _formatCurrency(analytics.totalValue!, analytics.singleCurrency)
        : 'Multi devises';
    final changeText = analytics.totalChangeValue != null
        ? _formatCurrency(analytics.totalChangeValue!, analytics.singleCurrency, signed: true)
        : '—';
    final changeSubtitle = analytics.totalChangePercent != null
        ? _formatSignedPercent(analytics.totalChangePercent!)
        : 'Variation indisponible';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aperçu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Positions',
                  value: analytics.positions.length.toString(),
                  subtitle: 'Actions suivies',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Valeur',
                  value: valueText,
                  subtitle: analytics.totalValue != null ? 'Cours instantané' : 'Addition brute des devises',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Variation jour',
                  value: changeText,
                  subtitle: changeSubtitle,
                  accent: changeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BestWorstCard(
                  best: analytics.bestPerformer,
                  worst: analytics.worstPerformer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceSection extends StatefulWidget {
  const _PerformanceSection({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  State<_PerformanceSection> createState() => _PerformanceSectionState();
}

class _PerformanceSectionState extends State<_PerformanceSection> {
  double _scenarioPercent = 0;

  @override
  Widget build(BuildContext context) {
    final analytics = widget.analytics;
    final hasValue = analytics.totalValue != null && analytics.singleCurrency != null;
    final simulatedValue = hasValue
        ? analytics.totalValue! * (1 + _scenarioPercent / 100)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Performance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: simulatedValue == null
                    ? const SizedBox.shrink()
                    : Text(
                        _formatCurrency(simulatedValue, analytics.singleCurrency!),
                        key: ValueKey<double>(simulatedValue),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6E8EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _SparklineChart(series: analytics.history),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final percent in const [0.0, 5.0, -5.0, 10.0])
                ChoiceChip(
                  label: Text(percent == 0 ? 'Réel' : (percent > 0 ? '+${percent.toInt()} %' : '${percent.toInt()} %')),
                  selected: _scenarioPercent == percent,
                  onSelected: (_) => setState(() => _scenarioPercent = percent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.analytics, required this.onOpenPosition});

  final _PortfolioAnalytics analytics;
  final _OpenPositionCallback onOpenPosition;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _InsightCard(
        title: 'Répartition devises',
        child: _DistributionChips(slices: analytics.currencyDistribution),
      ),
      _InsightCard(
        title: 'Répartition places de marché',
        child: _DistributionChips(slices: analytics.exchangeDistribution),
      ),
      _ConcentrationCard(analytics: analytics),
      _TimelineCard(entries: analytics.timeline),
    ];

    if (analytics.bestPerformer != null) {
      cards.add(
        _InsightCard(
          title: 'Focus meilleur titre',
          child: _FocusPosition(
            analytics: analytics.bestPerformer!,
            onOpen: onOpenPosition,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards
            .map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                ))
            .toList(),
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
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DistributionChips extends StatelessWidget {
  const _DistributionChips({required this.slices});

  final List<_DistributionSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return Text(
        'Insuffisant pour établir une répartition.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slices
          .map(
            (slice) => Chip(
              label: Text('${slice.label} · ${slice.percentageString}'),
              backgroundColor: Colors.black.withValues(alpha: 0.04),
            ),
          )
          .toList(),
    );
  }
}

class _ConcentrationCard extends StatelessWidget {
  const _ConcentrationCard({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topWeight = analytics.concentrationRatio;
    final alert = topWeight >= 0.25;

    String label;
    if (analytics.bestPerformer != null) {
      label = '${analytics.bestPerformer!.snapshot.displayName.isNotEmpty ? analytics.bestPerformer!.snapshot.displayName : analytics.bestPerformer!.snapshot.symbol} : ${_formatPercent(topWeight * 100)}';
    } else {
      label = _formatPercent(topWeight * 100);
    }

    return _InsightCard(
      title: 'Concentration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert
                ? 'Attention : un titre pèse plus de 25 % du portefeuille.'
                : 'Répartition équilibrée des pondérations.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: alert ? Colors.red.shade600 : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: topWeight.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(alert ? Colors.redAccent : Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entries});

  final List<_TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'Aucun ajout récent.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
      );
    }
    return Column(
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.symbol.substring(0, entry.symbol.length >= 3 ? 3 : entry.symbol.length).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Ajouté ${_relativeDate(entry.date)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FocusPosition extends StatelessWidget {
  const _FocusPosition({required this.analytics, required this.onOpen});

  final _PositionAnalytics analytics;
  final _OpenPositionCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final snapshot = analytics.snapshot;
    final changeText = analytics.changePercent != null
        ? _formatSignedPercent(analytics.changePercent!)
        : analytics.changeValue != null
            ? _formatCurrency(analytics.changeValue!, snapshot.currency, signed: true)
            : 'Variation indisponible';

    final rawType = snapshot.quoteType;
    final quoteType =
        rawType.isEmpty || rawType.toUpperCase() == 'UNKNOWN' ? null : rawType;

    return InkWell(
      onTap: () => onOpen(
        snapshot.symbol,
        snapshot.displayName,
        snapshot.exchange,
        snapshot.currency,
        quoteType,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              child: Text(snapshot.symbol.isEmpty ? '?' : snapshot.symbol[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.displayName.isNotEmpty ? snapshot.displayName : snapshot.symbol,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Poids ${_formatPercent(analytics.weight * 100)} · $changeText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({required this.analytics, required this.onTap});

  final _PositionAnalytics analytics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final snapshot = analytics.snapshot;
    final theme = Theme.of(context);

    final title = snapshot.displayName.isNotEmpty ? snapshot.displayName : snapshot.symbol;
    final subtitleParts = <String>[];
    subtitleParts.add(snapshot.symbol.toUpperCase());
    if (snapshot.exchange.isNotEmpty) subtitleParts.add(snapshot.exchange.toUpperCase());
    if (snapshot.currency.isNotEmpty) subtitleParts.add(snapshot.currency.toUpperCase());

    final valueText = analytics.value != null
        ? _formatCurrency(analytics.value!, snapshot.currency)
        : '—';
    final changeText = analytics.changePercent != null
        ? _formatSignedPercent(analytics.changePercent!)
        : analytics.changeValue != null
            ? _formatCurrency(analytics.changeValue!, snapshot.currency, signed: true)
            : null;
    final changeColor = analytics.changePercent != null
        ? (analytics.changePercent! >= 0 ? Colors.green.shade600 : Colors.red.shade600)
        : (analytics.changeValue != null
            ? (analytics.changeValue! >= 0 ? Colors.green.shade600 : Colors.red.shade600)
            : Colors.black54);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                snapshot.symbol.isNotEmpty ? snapshot.symbol.substring(0, 2).toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(valueText, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (changeText != null)
                  Text(
                    changeText,
                    style: theme.textTheme.labelSmall?.copyWith(color: changeColor, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioAnalyticsError extends StatelessWidget {
  const _PortfolioAnalyticsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioPositionsEmpty extends StatelessWidget {
  const _PortfolioPositionsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.folder_open_rounded, size: 36, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              'Aucune action dans ce portefeuille.\nAjoutez-en depuis la fiche Info.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
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
    final points = series.points;
    if (points.length < 2) {
      return const Center(child: Text('Historique insuffisant.'));
    }
    final color = series.normalized ? Colors.black : Colors.indigo.shade600;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(opacity: value.clamp(0.0, 1.0), child: child);
      },
      child: CustomPaint(
        painter: _SparklinePainter(points: points, color: color),
        child: Stack(
          children: [
            Positioned(
              left: 12,
              bottom: 8,
              child: Text(
                _formatHistoryLabel(points.first.value, series.currency, series.normalized),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54),
              ),
            ),
            Positioned(
              right: 12,
              top: 8,
              child: Text(
                _formatHistoryLabel(points.last.value, series.currency, series.normalized),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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
    double translateY(double value) => size.height - ((value - minValue) / range) * size.height;

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
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => !identical(oldDelegate.points, points) || oldDelegate.color != color;
}

class _PortfolioPositionSnapshot {
  const _PortfolioPositionSnapshot({
    required this.symbol,
    required this.displayName,
    required this.exchange,
    required this.currency,
    required this.quoteType,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.quantity,
    required this.costBasis,
    required this.addedAt,
  });

  final String symbol;
  final String displayName;
  final String exchange;
  final String currency;
  final String quoteType;
  final double? price;
  final double? change;
  final double? changePercent;
  final double quantity;
  final double? costBasis;
  final DateTime? addedAt;

  double? get value => price != null ? price! * quantity : null;
  double? get changeValue => change != null ? change! * quantity : null;

  static _PortfolioPositionSnapshot fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final addedAtRaw = data['addedAt'];
    DateTime? addedAt;
    if (addedAtRaw is Timestamp) addedAt = addedAtRaw.toDate();
    final quantityValue = data['quantity'];
    final quantity = quantityValue is num ? quantityValue.toDouble() : 1.0;
    final priceValue = data['regularMarketPrice'];
    final changeValue = data['regularMarketChange'];
    final changePercentValue = data['regularMarketChangePercent'];
    final costBasisValue = data['costBasis'];
    return _PortfolioPositionSnapshot(
      symbol: (data['symbol'] as String? ?? '').trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      exchange: (data['exchange'] as String? ?? '').trim(),
      currency: (data['currency'] as String? ?? '').trim(),
      quoteType: (data['quoteType'] as String? ?? 'UNKNOWN').trim(),
      price: priceValue is num ? priceValue.toDouble() : null,
      change: changeValue is num ? changeValue.toDouble() : null,
      changePercent: changePercentValue is num ? changePercentValue.toDouble() : null,
      quantity: quantity <= 0 ? 1.0 : quantity,
      costBasis: costBasisValue is num ? costBasisValue.toDouble() : null,
      addedAt: addedAt,
    );
  }
}

class _PositionAnalytics {
  const _PositionAnalytics({
    required this.snapshot,
    required this.value,
    required this.changeValue,
    required this.changePercent,
    required this.weight,
  });

  final _PortfolioPositionSnapshot snapshot;
  final double? value;
  final double? changeValue;
  final double? changePercent;
  final double weight;
}

class _DistributionSlice {
  const _DistributionSlice({required this.label, required this.weight});

  final String label;
  final double weight;

  String get percentageString => _formatPercent(weight * 100);
}

class _TimelineEntry {
  const _TimelineEntry({required this.symbol, required this.name, required this.date});

  final String symbol;
  final String name;
  final DateTime date;
}

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

class _PortfolioAnalytics {
  const _PortfolioAnalytics({
    required this.positions,
    required this.totalValue,
    required this.totalChangeValue,
    required this.totalChangePercent,
    required this.singleCurrency,
    required this.bestPerformer,
    required this.worstPerformer,
    required this.concentrationRatio,
    required this.currencyDistribution,
    required this.exchangeDistribution,
    required this.timeline,
    required this.history,
  });

  final List<_PositionAnalytics> positions;
  final double? totalValue;
  final double? totalChangeValue;
  final double? totalChangePercent;
  final String? singleCurrency;
  final _PositionAnalytics? bestPerformer;
  final _PositionAnalytics? worstPerformer;
  final double concentrationRatio;
  final List<_DistributionSlice> currencyDistribution;
  final List<_DistributionSlice> exchangeDistribution;
  final List<_TimelineEntry> timeline;
  final _HistorySeries history;

  factory _PortfolioAnalytics.empty(List<_PortfolioPositionSnapshot> positions) {
    return _PortfolioAnalytics(
      positions: const [],
      totalValue: null,
      totalChangeValue: null,
      totalChangePercent: null,
      singleCurrency: null,
      bestPerformer: null,
      worstPerformer: null,
      concentrationRatio: 0,
      currencyDistribution: const [],
      exchangeDistribution: const [],
      timeline: positions
          .where((p) => p.addedAt != null)
          .map((p) => _TimelineEntry(
                symbol: p.symbol,
                name: p.displayName.isNotEmpty ? p.displayName : p.symbol,
                date: p.addedAt!,
              ))
          .toList(),
      history: const _HistorySeries(points: <_HistoryPoint>[], currency: null, normalized: true),
    );
  }
}

Future<_PortfolioAnalytics> _computeAnalytics(List<_PortfolioPositionSnapshot> positions) async {
  final currencySet = <String>{};
  for (final position in positions) {
    if (position.currency.isNotEmpty) {
      currencySet.add(position.currency.toUpperCase());
    }
  }
  final singleCurrency = currencySet.length == 1 ? currencySet.first : null;

  // Total value & change calculations
  double totalValue = 0;
  double totalChangeValue = 0;
  var hasValue = false;
  var hasChangeValue = false;
  double weightedPercentSum = 0;
  double totalWeightForPercent = 0;

  for (final position in positions) {
    final value = position.value;
    if (value != null) {
      totalValue += value;
      hasValue = true;
    }
    final changeValue = position.changeValue;
    if (changeValue != null) {
      totalChangeValue += changeValue;
      hasChangeValue = true;
    }
    if (position.changePercent != null && value != null) {
      weightedPercentSum += value * position.changePercent!;
      totalWeightForPercent += value;
    }
  }

  double? totalValueOrNull = hasValue ? totalValue : null;
  double? totalChangeValueOrNull = hasChangeValue ? totalChangeValue : null;
  double? totalChangePercent;
  if (totalWeightForPercent > 0) {
    totalChangePercent = weightedPercentSum / totalWeightForPercent;
  } else if (hasChangeValue && totalValueOrNull != null && (totalValueOrNull - totalChangeValueOrNull!).abs() > 1e-6) {
    final previousValue = totalValueOrNull - totalChangeValueOrNull;
    totalChangePercent = previousValue.abs() < 1e-6 ? null : (totalChangeValueOrNull / previousValue) * 100;
  }

  final positionsAnalytics = positions.map((position) {
    final value = position.value;
    final changeValue = position.changeValue;
    final changePercent = position.changePercent;
    double weight;
    if (value != null && totalValueOrNull != null && totalValueOrNull > 0) {
      weight = value / totalValueOrNull;
    } else {
      weight = 1 / positions.length;
    }
    return _PositionAnalytics(
      snapshot: position,
      value: value,
      changeValue: changeValue,
      changePercent: changePercent,
      weight: weight,
    );
  }).toList();

  _PositionAnalytics? bestPerformer;
  _PositionAnalytics? worstPerformer;
  for (final position in positionsAnalytics) {
    final score = position.changePercent ?? (position.changeValue != null && position.value != null && position.value!.abs() > 1e-6
        ? (position.changeValue! / (position.value! - position.changeValue!)) * 100
        : null);
    if (score == null) continue;
    if (bestPerformer == null || score > (bestPerformer.changePercent ?? double.negativeInfinity)) {
      bestPerformer = position;
    }
    if (worstPerformer == null || score < (worstPerformer.changePercent ?? double.infinity)) {
      worstPerformer = position;
    }
  }

  final concentrationRatio = positionsAnalytics
      .map((p) => p.weight)
      .fold<double>(0, (previousValue, element) => element > previousValue ? element : previousValue);

  final currencyDistribution = _buildDistribution(
    positionsAnalytics,
    (p) => p.snapshot.currency.isNotEmpty ? p.snapshot.currency.toUpperCase() : 'N/A',
    totalValueOrNull,
  );
  final exchangeDistribution = _buildDistribution(
    positionsAnalytics,
    (p) => p.snapshot.exchange.isNotEmpty ? p.snapshot.exchange.toUpperCase() : 'N/A',
    totalValueOrNull,
  );

  final timeline = positions
      .where((p) => p.addedAt != null)
      .map((p) => _TimelineEntry(
            symbol: p.symbol,
            name: p.displayName.isNotEmpty ? p.displayName : p.symbol,
            date: p.addedAt!,
          ))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final history = await _buildAggregatedHistory(positions, singleCurrency: singleCurrency);

  return _PortfolioAnalytics(
    positions: positionsAnalytics,
    totalValue: totalValueOrNull,
    totalChangeValue: totalChangeValueOrNull,
    totalChangePercent: totalChangePercent,
    singleCurrency: singleCurrency,
    bestPerformer: bestPerformer,
    worstPerformer: worstPerformer,
    concentrationRatio: concentrationRatio,
    currencyDistribution: currencyDistribution,
    exchangeDistribution: exchangeDistribution,
    timeline: timeline,
    history: history,
  );
}

List<_DistributionSlice> _buildDistribution(
  List<_PositionAnalytics> analytics,
  String Function(_PositionAnalytics) keySelector,
  double? totalValue,
) {
  if (analytics.isEmpty) return const [];
  final map = <String, double>{};
  final total = totalValue ?? analytics.length.toDouble();
  for (final position in analytics) {
    final key = keySelector(position);
    final weight = totalValue != null && position.value != null
        ? position.value!
        : 1.0;
    map[key] = (map[key] ?? 0) + weight;
  }
  if (total <= 0) return const [];
  return map.entries
      .map((e) => _DistributionSlice(label: e.key, weight: (e.value / total).clamp(0.0, 1.0)))
      .toList()
    ..sort((a, b) => b.weight.compareTo(a.weight));
}

Future<_HistorySeries> _buildAggregatedHistory(
  List<_PortfolioPositionSnapshot> positions, {
  required String? singleCurrency,
}) async {
  if (positions.isEmpty) {
    return const _HistorySeries(points: <_HistoryPoint>[], currency: null, normalized: true);
  }

  DateTime earliest = DateTime.now();
  for (final position in positions) {
    if (position.addedAt != null && position.addedAt!.isBefore(earliest)) {
      earliest = position.addedAt!;
    }
  }

  final interval = _pickInterval(DateTime.now().difference(earliest));
  final futures = positions.map((position) async {
    try {
      final points = await YahooFinanceService.fetchHistoricalSeries(position.symbol, interval);
      return _SymbolHistory(position: position, interval: interval, points: points);
    } catch (_) {
      return _SymbolHistory(position: position, interval: interval, points: const <HistoricalPoint>[]);
    }
  });

  final histories = await Future.wait(futures);
  final normalized = singleCurrency == null;
  final currency = normalized ? null : singleCurrency;
  final map = SplayTreeMap<DateTime, double>();

  for (final history in histories) {
    final filtered = history.points
        .where((point) => history.position.addedAt == null || !point.time.isBefore(history.position.addedAt!))
        .toList();
    if (filtered.isEmpty) {
      if (history.position.price != null) {
        final now = DateTime.now();
        final key = _normalizeHistoryTime(now, history.interval);
        final contribution = normalized
            ? history.position.quantity
            : history.position.price! * history.position.quantity;
        map[key] = (map[key] ?? 0) + contribution;
      }
      continue;
    }

    double baseline = 1.0;
    if (normalized) {
      baseline = filtered.first.close;
      if (baseline.abs() < 1e-6) {
        baseline = history.points.first.close;
      }
    }

    for (final point in filtered) {
      final key = _normalizeHistoryTime(point.time, history.interval);
      final contribution = normalized
          ? (baseline.abs() < 1e-6
              ? history.position.quantity
              : (point.close / baseline) * history.position.quantity)
          : point.close * history.position.quantity;
      map[key] = (map[key] ?? 0) + contribution;
    }

    if (history.position.price != null) {
      final key = _normalizeHistoryTime(DateTime.now(), history.interval);
      final contribution = normalized
          ? (baseline.abs() < 1e-6
              ? history.position.quantity
              : (history.position.price! / baseline) * history.position.quantity)
          : history.position.price! * history.position.quantity;
      map[key] = (map[key] ?? 0) + contribution;
    }
  }

  if (map.isEmpty) {
    return const _HistorySeries(points: <_HistoryPoint>[], currency: null, normalized: true);
  }

  final points = map.entries.map((e) => _HistoryPoint(time: e.key, value: e.value)).toList();
  if (normalized) {
    final firstValue = points.first.value;
    if (firstValue.abs() > 1e-6) {
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        points[i] = _HistoryPoint(time: point.time, value: (point.value / firstValue) * 100);
      }
    }
  }

  return _HistorySeries(points: points, currency: currency, normalized: normalized);
}

class _SymbolHistory {
  const _SymbolHistory({
    required this.position,
    required this.interval,
    required this.points,
  });

  final _PortfolioPositionSnapshot position;
  final ChartInterval interval;
  final List<HistoricalPoint> points;
}

String _signatureFor(List<_PortfolioPositionSnapshot> positions) {
  final buffer = StringBuffer();
  for (final position in positions) {
    buffer
      ..write(position.symbol)
      ..write(position.price ?? 0)
      ..write(position.change ?? 0)
      ..write(position.changePercent ?? 0)
      ..write(position.quantity)
      ..write(position.addedAt?.millisecondsSinceEpoch ?? 0);
  }
  return buffer.toString();
}

ChartInterval _pickInterval(Duration span) {
  final days = span.inDays;
  if (days <= 5) return ChartInterval.sevenDays;
  if (days <= 30) return ChartInterval.oneMonth;
  if (days <= 200) return ChartInterval.sixMonths;
  if (days <= 365) return ChartInterval.yearToDate;
  if (days <= 365 * 5) return ChartInterval.fiveYears;
  return ChartInterval.max;
}

DateTime _normalizeHistoryTime(DateTime time, ChartInterval interval) {
  final granularity = chartIntervalMetas[interval]?.granularity;
  switch (granularity) {
    case '5m':
    case '15m':
    case '30m':
      final step = granularity == '5m'
          ? 5
          : granularity == '15m'
              ? 15
              : 30;
      final minute = (time.minute ~/ step) * step;
      return DateTime(time.year, time.month, time.day, time.hour, minute);
    case '1wk':
      final delta = time.weekday % 7;
      final monday = time.subtract(Duration(days: delta));
      return DateTime(monday.year, monday.month, monday.day);
    case '1mo':
      return DateTime(time.year, time.month, 1);
    default:
      return DateTime(time.year, time.month, time.day);
  }
}

String _formatCurrency(double value, String? currency, {bool signed = false}) {
  final absValue = value.abs();
  String human;
  if (absValue >= 1e9) {
    human = '${(value / 1e9).toStringAsFixed(2)} G';
  } else if (absValue >= 1e6) {
    human = '${(value / 1e6).toStringAsFixed(2)} M';
  } else if (absValue >= 1e3) {
    human = '${(value / 1e3).toStringAsFixed(1)} k';
  } else {
    human = value.toStringAsFixed(2);
  }
  if (signed && value >= 0) human = '+$human';
  return currency != null && currency.isNotEmpty ? '$human $currency' : human;
}

String _formatSignedPercent(double value) {
  final fixed = value.abs() >= 100 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
  return value >= 0 ? '+$fixed %' : '$fixed %';
}

String _formatPercent(double value) => '${value.toStringAsFixed(1)} %';

String _formatHistoryLabel(double value, String? currency, bool normalized) {
  if (normalized) {
    return '${value.toStringAsFixed(1)} pts';
  }
  return _formatCurrency(value, currency);
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inDays >= 7) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'le $day/$month/${date.year}';
  }
  if (difference.inDays >= 1) {
    return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
  }
  if (difference.inHours >= 1) {
    return 'il y a ${difference.inHours} h';
  }
  final minutes = math.max(1, difference.inMinutes);
  return 'il y a $minutes min';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, this.subtitle, this.accent});

  final String title;
  final String value;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? Colors.black87;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class _BestWorstCard extends StatelessWidget {
  const _BestWorstCard({required this.best, required this.worst});

  final _PositionAnalytics? best;
  final _PositionAnalytics? worst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Variations marquantes', style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
          const SizedBox(height: 8),
          if (best != null)
            _bestWorstRow(best!, positive: true, textTheme: theme.textTheme),
          if (worst != null) ...[
            const SizedBox(height: 8),
            _bestWorstRow(worst!, positive: false, textTheme: theme.textTheme),
          ],
          if (best == null && worst == null)
            Text(
              'Aucune donnée de variation disponible.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
            ),
        ],
      ),
    );
  }

  Widget _bestWorstRow(
    _PositionAnalytics analytics, {
    required bool positive,
    required TextTheme textTheme,
  }) {
    final name = analytics.snapshot.displayName.isNotEmpty
        ? analytics.snapshot.displayName
        : analytics.snapshot.symbol;
    final percent = analytics.changePercent != null
        ? _formatSignedPercent(analytics.changePercent!)
        : (analytics.changeValue != null
            ? _formatCurrency(
                analytics.changeValue!,
                analytics.snapshot.currency,
                signed: true,
              )
            : '—');
    return Row(
      children: [
        Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: positive ? Colors.green.shade600 : Colors.red.shade600, size: 20),
        const SizedBox(width: 8),
        Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        ),
        const SizedBox(width: 8),
        Text(
          percent,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: positive ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ),
      ],
    );
  }
}

class _EmptyPortfolioState extends StatelessWidget {
  const _EmptyPortfolioState({this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspaces_outline, color: Colors.black38, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Crée ton premier portefeuille\npour suivre tes actions favorites.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              label: const Text('Créer un portefeuille'),
            ),
          ],
        ),
      ),
    );
  }
}
