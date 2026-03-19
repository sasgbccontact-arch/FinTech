import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:fintech/core/constants.dart';
import '../models/chart_models.dart';
import '../services/activity_tracking_service.dart';
import '../services/portfolio_service.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/portfolio_dialogs.dart';
import 'info_page.dart';
import 'favorites_page.dart';
import 'game_portfolio_dashboard_sheet.dart';

/// Tableau de bord des portefeuilles – liste et fiche analytique animée.
class PortfolioDashboardPage extends StatefulWidget {
  const PortfolioDashboardPage({super.key});

  @override
  State<PortfolioDashboardPage> createState() => _PortfolioDashboardPageState();
}

enum _DashboardSection { portfolios, favorites }

const List<_StarterWatchIdea> _starterWatchIdeas = <_StarterWatchIdea>[
  _StarterWatchIdea(
    symbol: 'SPY',
    name: 'S&P 500 ETF',
    description: 'Un ETF large pour comprendre la diversification.',
  ),
  _StarterWatchIdea(
    symbol: 'AAPL',
    name: 'Apple',
    description: 'Une Big Tech simple a suivre et a comparer.',
  ),
  _StarterWatchIdea(
    symbol: 'MC.PA',
    name: 'LVMH',
    description: 'Une valeur europeenne pour sortir du biais US.',
  ),
];

class _PortfolioDashboardPageState extends State<PortfolioDashboardPage> {
  // Palette (same style as SearchPage)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _muted = Colors.black54;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;
  static const Color _chipBg = Color(0xFFF0F1F3);

  bool _creating = false;
  _DashboardSection _section = _DashboardSection.portfolios;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
                    Icon(Icons.lock_outline_rounded, color: _muted, size: 34),
                    SizedBox(height: 12),
                    Text(
                      'Connectez-vous pour gérer vos portefeuilles',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
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

    final stream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('portfolios')
            .orderBy('createdAt', descending: false)
            .snapshots();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tableau de bord',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
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
                        const SizedBox(height: 8),
                        Text(
                          _section == _DashboardSection.portfolios
                              ? "Créez et suivez vos portefeuilles d'actions."
                              : "Retrouvez ici vos actions suivies en raccourci.",
                          style: const TextStyle(
                            fontSize: 14,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_section == _DashboardSection.portfolios) ...[
                    const SizedBox(width: 12),
                    _buildCreateButton(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DashboardSectionSwitch(
                section: _section,
                onChanged: (section) => setState(() => _section = section),
              ),
            ),
            const SizedBox(height: 16),
            if (_section == _DashboardSection.portfolios)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GamePortfolioShortcut(uid: user.uid),
              ),
            Expanded(
              child:
                  _section == _DashboardSection.portfolios
                      ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: stream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _PortfolioListSkeleton();
                          }
                          if (!snapshot.hasData) {
                            return const _PortfolioListSkeleton();
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.black38,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Impossible de charger vos portefeuilles pour le moment.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: _muted),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final docs =
                              snapshot.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                          if (docs.isEmpty) {
                            return _EmptyPortfolioState(
                              onCreate: _creating ? null : _createPortfolio,
                              onCreateStarter:
                                  _creating ? null : _createStarterPortfolio,
                              ideas: _starterWatchIdeas,
                            );
                          }

                          final portfolios =
                              docs.map((doc) {
                                final data = doc.data();
                                final name =
                                    (data['name'] as String? ?? '').trim();
                                final createdAt = data['createdAt'];
                                final updatedAt = data['updatedAt'];
                                final count =
                                    (data['positionsCount'] as num?)?.toInt() ??
                                    0;
                                return _PortfolioSummary(
                                  id: doc.id,
                                  ref: doc.reference,
                                  name: name.isEmpty ? 'Portefeuille' : name,
                                  positionsCount: count,
                                  createdAt:
                                      createdAt is Timestamp
                                          ? createdAt.toDate()
                                          : null,
                                  updatedAt:
                                      updatedAt is Timestamp
                                          ? updatedAt.toDate()
                                          : null,
                                );
                              }).toList();

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            physics: const BouncingScrollPhysics(),
                            itemCount: portfolios.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final portfolio = portfolios[index];
                              return _PortfolioCard(
                                summary: portfolio,
                                onTap: () => _openPortfolioDetail(portfolio),
                                onDelete:
                                    () => _deletePortfolio(
                                      portfolio.id,
                                      portfolio.name,
                                    ),
                              );
                            },
                          );
                        },
                      )
                      : const FavoritesListSection(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final bool disabled = _creating;

    return Semantics(
      button: true,
      label:
          disabled
              ? 'Création du portefeuille en cours'
              : 'Créer un portefeuille',
      child: InkWell(
        onTap: disabled ? null : _createPortfolio,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: disabled ? 0.7 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                disabled
                    ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: _wine,
                        backgroundColor: _gold.withValues(alpha: .20),
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                const SizedBox(width: 10),
                Text(
                  disabled ? 'Création…' : 'Nouveau',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPortfolio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour créer un portefeuille.'),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Portefeuille "$name" créé.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de créer le portefeuille (${e.message ?? e.code}).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la création du portefeuille.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _createStarterPortfolio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour créer un portefeuille guide.'),
        ),
      );
      return;
    }

    setState(() => _creating = true);

    const portfolioName = 'Starter FinHub';
    var addedCount = 0;

    try {
      final createdPortfolioId = await PortfolioService.createPortfolio(
        uid: user.uid,
        name: portfolioName,
      );

      Map<String, TickerSearchResult> lookupBySymbol = const {};
      try {
        final lookups = await YahooFinanceService.lookupSecuritiesBySymbols(
          _starterWatchIdeas.map((idea) => idea.symbol).toList(),
        );
        lookupBySymbol = {
          for (final item in lookups) item.symbol.toUpperCase(): item,
        };
      } catch (_) {}

      for (final idea in _starterWatchIdeas) {
        final symbol = idea.symbol.toUpperCase();
        final lookup = lookupBySymbol[symbol];
        QuoteDetail? quote;
        try {
          quote = await YahooFinanceService.fetchQuote(symbol);
        } catch (_) {}

        final displayName =
            lookup?.displayName ??
            quote?.longName ??
            quote?.shortName ??
            idea.name;
        final price = quote?.regularMarketPrice;

        await PortfolioService.addPosition(
          uid: user.uid,
          portfolioId: createdPortfolioId,
          data: <String, dynamic>{
            'symbol': symbol,
            'displayName': displayName,
            'exchange':
                lookup?.exchange ??
                quote?.fullExchangeName ??
                quote?.exchange ??
                '',
            'currency': lookup?.currency ?? quote?.currency ?? '',
            'quoteType': lookup?.quoteType ?? quote?.quoteType ?? 'UNKNOWN',
            'regularMarketPrice': price,
            'regularMarketChange': quote?.regularMarketChange,
            'regularMarketChangePercent': quote?.regularMarketChangePercent,
            'quantity': 1.0,
            if (price != null) 'costBasis': price,
            'starterDescription': idea.description,
          },
        );
        addedCount += 1;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Portefeuille guide cree avec $addedCount titre(s). Lis ensuite la carte pedagogique du dashboard.',
          ),
        ),
      );

      await _openPortfolioDetail(
        _PortfolioSummary(
          id: createdPortfolioId,
          ref: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('portfolios')
              .doc(createdPortfolioId),
          name: portfolioName,
          positionsCount: addedCount,
          createdAt: null,
          updatedAt: null,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de creer le portefeuille guide (${e.message ?? e.code}).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la creation du portefeuille guide.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _deletePortfolio(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Supprimer le portefeuille ?'),
            content: Text(
              'Voulez-vous vraiment supprimer "$name" ?\nCette action est irréversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('portfolios')
          .doc(id);
      // Suppression des positions (sous-collection)
      final positions = await ref.collection('positions').get();
      for (final doc in positions.docs) {
        await doc.reference.delete();
      }
      await ref.delete();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portefeuille "$name" supprimé.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression.')),
        );
    }
  }

  Future<void> _openPortfolioDetail(_PortfolioSummary summary) async {
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder: (context) => _PortfolioDetailSheet(summary: summary),
    );
  }
}

class _DashboardSectionSwitch extends StatelessWidget {
  const _DashboardSectionSwitch({
    required this.section,
    required this.onChanged,
  });

  final _DashboardSection section;
  final ValueChanged<_DashboardSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _PortfolioDashboardPageState._chipBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PortfolioDashboardPageState._line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SectionButton(
              label: 'Portefeuilles',
              selected: section == _DashboardSection.portfolios,
              onTap: () => onChanged(_DashboardSection.portfolios),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SectionButton(
              label: 'Favoris',
              selected: section == _DashboardSection.favorites,
              onTap: () => onChanged(_DashboardSection.favorites),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient:
              selected
                  ? const LinearGradient(
                    colors: [
                      _PortfolioDashboardPageState._gold,
                      _PortfolioDashboardPageState._wine,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: selected ? null : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _PortfolioDashboardPageState._ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
  const _PortfolioCard({
    required this.summary,
    required this.onTap,
    this.onDelete,
  });

  final _PortfolioSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (summary.positionsCount == 0) {
      subtitle = 'Aucune ligne pour le moment';
    } else if (summary.positionsCount == 1) {
      subtitle = '1 ligne de simulation';
    } else {
      subtitle = '${summary.positionsCount} lignes de simulation';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFCFBF7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: detailsColor1.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: detailsColor2.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [detailsColor1, detailsColor2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                summary.name
                    .substring(
                      0,
                      summary.name.length >= 2 ? 2 : summary.name.length,
                    )
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.black38),
                tooltip: 'Supprimer',
              )
            else
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: detailsColor1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chevron_right_rounded, color: detailsColor1, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _OpenPositionCallback =
    void Function(
      String symbol,
      String? name,
      String? exchange,
      String? currency,
      String? quoteType,
    );

typedef _DeletePositionCallback =
    Future<bool> Function(String positionId, String symbol);

typedef _EditPositionCallback =
    Future<bool> Function(
      String positionId,
      String symbol,
      double currentQty,
      double? currentPru,
    );

class _GamePortfolioShortcut extends StatefulWidget {
  const _GamePortfolioShortcut({required this.uid});

  final String uid;

  @override
  State<_GamePortfolioShortcut> createState() => _GamePortfolioShortcutState();
}

class _GamePortfolioShortcutState extends State<_GamePortfolioShortcut>
    with SingleTickerProviderStateMixin {
  Future<_GamePortfolioShortcutMetrics>? _metricsFuture;
  String? _metricsSignature;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<_GamePortfolioShortcutMetrics> _futureFor(
    int coins,
    List<_GamePortfolioShortcutPosition> positions,
  ) {
    final signature = StringBuffer()..write('coins=$coins|');
    for (final position in positions) {
      signature
        ..write(position.symbol)
        ..write(':')
        ..write(position.quantity)
        ..write(':')
        ..write(position.averagePrice.toStringAsFixed(6))
        ..write('|');
    }
    final key = signature.toString();
    if (_metricsFuture != null && _metricsSignature == key) {
      return _metricsFuture!;
    }
    _metricsSignature = key;
    _metricsFuture = _loadMetrics(coins, positions);
    return _metricsFuture!;
  }

  Future<_GamePortfolioShortcutMetrics> _loadMetrics(
    int coins,
    List<_GamePortfolioShortcutPosition> positions,
  ) async {
    if (positions.isEmpty) {
      return _GamePortfolioShortcutMetrics(
        reserveCoins: coins.toDouble(),
        linesCount: 0,
        investedCapital: 0,
        latentPnlValue: 0,
        latentPnlPercent: 0,
        fallbackCount: 0,
      );
    }

    final quotes = <String, QuoteDetail?>{};
    final quoteTasks = positions.map((position) async {
      try {
        quotes[position.symbol] = await YahooFinanceService.fetchQuote(
          position.symbol,
        );
      } catch (_) {
        quotes[position.symbol] = null;
      }
    });
    await Future.wait(quoteTasks);

    var investedCapital = 0.0;
    var currentValue = 0.0;
    var fallbackCount = 0;
    for (final position in positions) {
      final quote = quotes[position.symbol];
      final marketPrice = quote?.regularMarketPrice;
      final fallbackPrice =
          position.averagePrice > 0 ? position.averagePrice : 0;
      final currentPrice = marketPrice ?? fallbackPrice;
      if (marketPrice == null && fallbackPrice > 0) fallbackCount += 1;
      investedCapital += position.averagePrice * position.quantity;
      currentValue += currentPrice * position.quantity;
    }

    final latentPnlValue = currentValue - investedCapital;
    final latentPnlPercent =
        investedCapital <= 0 ? 0.0 : (latentPnlValue / investedCapital) * 100;

    return _GamePortfolioShortcutMetrics(
      reserveCoins: coins.toDouble(),
      linesCount: positions.length,
      investedCapital: investedCapital,
      latentPnlValue: latentPnlValue,
      latentPnlPercent: latentPnlPercent,
      fallbackCount: fallbackCount,
    );
  }

  Future<void> _openSheet() async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      builder: (_) => GamePortfolioDashboardSheet(uid: widget.uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);
    final positionsStream =
        userRef
            .collection('games')
            .doc('portofolio')
            .collection('positions')
            .snapshots();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: positionsStream,
            builder: (context, positionsSnapshot) {
              if (userSnapshot.hasError || positionsSnapshot.hasError) {
                return _buildCard(
                  subtitle:
                      'Le tableau de pilotage est momentanément indisponible.',
                  badge: 'Erreur',
                  kpis: const [
                    _ShortcutChipData(label: 'Etat', value: 'Indisponible'),
                    _ShortcutChipData(label: 'Accès', value: 'Réessaye'),
                  ],
                );
              }

              final waiting =
                  !userSnapshot.hasData || !positionsSnapshot.hasData;
              if (waiting) {
                return _buildCard(
                  subtitle: 'Chargement du portefeuille de jeu...',
                  badge: 'Live',
                  kpis: const [
                    _ShortcutChipData(label: 'Réserve', value: '...'),
                    _ShortcutChipData(label: 'Lignes', value: '...'),
                    _ShortcutChipData(label: 'Perf', value: '...'),
                  ],
                );
              }

              final coins =
                  (userSnapshot.data?.data()?['coins'] as num?)?.toInt() ?? 0;
              final positions =
                  (positionsSnapshot.data?.docs ?? const [])
                      .map(_GamePortfolioShortcutPosition.fromDoc)
                      .where((position) => position.symbol.isNotEmpty)
                      .toList();

              return FutureBuilder<_GamePortfolioShortcutMetrics>(
                future: _futureFor(coins, positions),
                builder: (context, metricsSnapshot) {
                  final metrics =
                      metricsSnapshot.data ??
                      _GamePortfolioShortcutMetrics(
                        reserveCoins: coins.toDouble(),
                        linesCount: positions.length,
                        investedCapital: 0,
                        latentPnlValue: 0,
                        latentPnlPercent: 0,
                        fallbackCount: 0,
                      );

                  final hasLines = metrics.linesCount > 0;
                  final perfLabel =
                      hasLines
                          ? _formatSignedPercent(metrics.latentPnlPercent)
                          : 'Prêt';
                  final fallbackText =
                      metrics.fallbackCount > 0
                          ? ' • ${metrics.fallbackCount} ligne(s) en secours PRU'
                          : '';

                  return _buildCard(
                    subtitle:
                        hasLines
                            ? 'Pilote ta réserve, ta performance et tes lignes sans quitter le dashboard$fallbackText.'
                            : 'Lance ton portefeuille de jeu, ajoute des lignes et suis-le dans un vrai tableau de bord.',
                    badge: hasLines ? 'Actif' : 'Sandbox',
                    kpis: [
                      _ShortcutChipData(
                        label: 'Réserve',
                        value: _formatGameAmount(metrics.reserveCoins),
                      ),
                      _ShortcutChipData(
                        label: 'Lignes',
                        value: '${metrics.linesCount}',
                      ),
                      _ShortcutChipData(label: 'Perf', value: perfLabel),
                    ],
                    footer:
                        hasLines
                            ? 'Capital investi ${_formatGameAmount(metrics.investedCapital)}'
                            : 'Ajoute une première ligne pour démarrer',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required String subtitle,
    required String badge,
    required List<_ShortcutChipData> kpis,
    String? footer,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _openSheet,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF4CE), Color(0xFFFFFBF3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE9D49B)),
            boxShadow: [
              BoxShadow(
                color: detailsColor1.withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -6,
                top: -8,
                child: AnimatedBuilder(
                  animation: _motionController,
                  builder: (context, child) {
                    final dx =
                        math.sin(_motionController.value * math.pi * 2) * 8;
                    final dy =
                        math.cos(_motionController.value * math.pi * 2) * 6;
                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 126,
                    height: 126,
                    child: SvgPicture.string(_gamePortfolioShortcutSvg),
                  ),
                ),
              ),
              Column(
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
                          color: Colors.white.withOpacity(0.76),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.stacked_line_chart_rounded,
                              size: 15,
                              color: detailsColor2,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Portefeuille de jeu',
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
                          color: detailsColor2.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: detailsColor2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Portefeuille de jeu',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 245,
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        kpis
                            .map(
                              (chip) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.82),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: detailsColor1.withOpacity(0.14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      chip.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      chip.value,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          footer ?? 'Ouvrir le tableau de pilotage',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: detailsColor2,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ouvrir',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GamePortfolioShortcutMetrics {
  const _GamePortfolioShortcutMetrics({
    required this.reserveCoins,
    required this.linesCount,
    required this.investedCapital,
    required this.latentPnlValue,
    required this.latentPnlPercent,
    required this.fallbackCount,
  });

  final double reserveCoins;
  final int linesCount;
  final double investedCapital;
  final double latentPnlValue;
  final double latentPnlPercent;
  final int fallbackCount;
}

class _GamePortfolioShortcutPosition {
  const _GamePortfolioShortcutPosition({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });

  final String symbol;
  final int quantity;
  final double averagePrice;

  factory _GamePortfolioShortcutPosition.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _GamePortfolioShortcutPosition(
      symbol: (data['symbol'] as String? ?? doc.id).trim().toUpperCase(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: (data['averagePrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _ShortcutChipData {
  const _ShortcutChipData({required this.label, required this.value});

  final String label;
  final String value;
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

const String _gamePortfolioShortcutSvg = '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="shortcutGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F3D06C"/>
      <stop offset="100%" stop-color="#9A5D44"/>
    </linearGradient>
  </defs>
  <circle cx="88" cy="68" r="48" fill="#FFF5D6"/>
  <path d="M30 104 C48 88, 64 80, 84 84 C104 88, 118 108, 136 100" fill="none" stroke="url(#shortcutGold)" stroke-width="7" stroke-linecap="round"/>
  <rect x="42" y="76" width="16" height="34" rx="8" fill="#E4B84F"/>
  <rect x="70" y="62" width="16" height="48" rx="8" fill="#C98746"/>
  <rect x="98" y="48" width="16" height="62" rx="8" fill="#8D4F39"/>
</svg>
''';

class _PortfolioDetailSheet extends StatefulWidget {
  const _PortfolioDetailSheet({required this.summary});

  final _PortfolioSummary summary;

  @override
  State<_PortfolioDetailSheet> createState() => _PortfolioDetailSheetState();
}

class _PortfolioDetailSheetState extends State<_PortfolioDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final stream =
        widget.summary.ref
            .collection('positions')
            .orderBy('addedAt', descending: true)
            .snapshots();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    _VirtualCircleButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.summary.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Portefeuille de simulation',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _VirtualCircleButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _PortfolioDetailSkeleton();
                    }
                    if (snapshot.hasError) {
                      return _PortfolioAnalyticsError(
                        message: 'Impossible de charger les positions.',
                        onRetry: () => setState(() {}),
                      );
                    }

                    final docs =
                        snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final positions =
                        docs
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
                      onDeletePosition: _deletePosition,
                      onEditPosition: _editPosition,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _editPosition(
    String positionId,
    String symbol,
    double currentQty,
    double? currentPru,
  ) async {
    final qtyController = TextEditingController(
      text: currentQty.toString().replaceAll(RegExp(r'\.?0+$'), ''),
    );
    final pruController = TextEditingController(
      text: currentPru != null
          ? currentPru.toStringAsFixed(2)
          : '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Modifier $symbol',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantité',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pruController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'PRU (Prix de Revient Unitaire)',
                hintText: 'Optionnel',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.euro_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: detailsColor2,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != true) return false;

    final newQty = double.tryParse(qtyController.text.replaceAll(',', '.'));
    final newPru = pruController.text.trim().isEmpty
        ? null
        : double.tryParse(pruController.text.trim().replaceAll(',', '.'));

    if (newQty == null || newQty <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantité invalide.')),
        );
      }
      return false;
    }

    try {
      final updates = <String, dynamic>{
        'quantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newPru != null) updates['costBasis'] = newPru;

      await widget.summary.ref.collection('positions').doc(positionId).update(updates);
      await widget.summary.ref.update({'updatedAt': FieldValue.serverTimestamp()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Position $symbol mise à jour.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la modification.')),
        );
      }
      return false;
    }
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
        builder:
            (ctx) => InfoPage(
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
        const SnackBar(
          content: Text("Impossible d'ouvrir la fiche de l'action."),
        ),
      );
    }
  }

  Future<bool> _deletePosition(String positionId, String symbol) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Vendre $symbol ?'),
            content: const Text(
              'Voulez-vous retirer cette position du portefeuille ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Vendre',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return false;

    try {
      await widget.summary.ref.collection('positions').doc(positionId).delete();
      await widget.summary.ref.update({
        'positionsCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(
          ActivityTrackingService.trackForUser(
            uid: uid,
            type: 'portfolio_position_sold',
            label: symbol,
            points: 24,
            counters: const <String, int>{
              'portfolio_trades': 1,
              'portfolio_positions_sold': 1,
            },
          ),
        );
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Position $symbol vendue. Compare maintenant la concentration et la diversification du portefeuille.',
            ),
          ),
        );
      return true;
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la vente.')),
        );
      return false;
    }
  }
}

class _PortfolioPositionsView extends StatefulWidget {
  const _PortfolioPositionsView({
    required this.summary,
    required this.positions,
    required this.onOpenPosition,
    required this.onDeletePosition,
    required this.onEditPosition,
  });

  final _PortfolioSummary summary;
  final List<_PortfolioPositionSnapshot> positions;
  final _OpenPositionCallback onOpenPosition;
  final _DeletePositionCallback onDeletePosition;
  final _EditPositionCallback onEditPosition;

  @override
  State<_PortfolioPositionsView> createState() =>
      _PortfolioPositionsViewState();
}

class _PortfolioPositionsViewState extends State<_PortfolioPositionsView> {
  Future<_PortfolioAnalytics>? _future;
  String _signature = '';
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;

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
    final future =
        widget.positions.isEmpty
            ? Future<_PortfolioAnalytics>.value(
              _PortfolioAnalytics.empty(widget.positions),
            )
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
        if (snapshot.connectionState == ConnectionState.waiting ||
            _future == null) {
          return Center(
            child: CircularProgressIndicator(
              color: _wine,
              backgroundColor: _gold.withValues(alpha: .20),
              strokeWidth: 3,
            ),
          );
        }
        if (snapshot.hasError) {
          return _PortfolioAnalyticsError(
            message: 'Analyse impossible pour l\'instant.',
            onRetry: _scheduleComputation,
          );
        }

        final analytics =
            snapshot.data ?? _PortfolioAnalytics.empty(widget.positions);
        if (analytics.positions.isEmpty) {
          return const _PortfolioPositionsEmpty();
        }

        return _PortfolioAnalyticsView(
          summary: widget.summary,
          analytics: analytics,
          onOpenPosition: widget.onOpenPosition,
          onDeletePosition: widget.onDeletePosition,
          onEditPosition: widget.onEditPosition,
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
    required this.onDeletePosition,
    required this.onEditPosition,
    required this.onRefreshRequested,
  });

  final _PortfolioSummary summary;
  final _PortfolioAnalytics analytics;
  final _OpenPositionCallback onOpenPosition;
  final _DeletePositionCallback onDeletePosition;
  final _EditPositionCallback onEditPosition;
  final VoidCallback onRefreshRequested;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _VirtualHeroCard(analytics: analytics),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _VirtualTabHeaderDelegate(
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: _VirtualTabStrip(),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        children: [
          // Tab 0: Vue
          _buildVueTab(context),
          // Tab 1: Analyse
          _buildAnalyseTab(context),
          // Tab 2: Positions
          _buildPositionsTab(context),
        ],
      ),
    );
  }

  Widget _buildVueTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _OverviewSection(analytics: analytics),
        _PortfolioCoachCard(analytics: analytics),
      ],
    );
  }

  Widget _buildAnalyseTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _PnLTableSection(analytics: analytics),
        if (analytics.history.points.length > 1)
          _PerformanceSection(analytics: analytics),
        _InsightsSection(
          analytics: analytics,
          onOpenPosition: onOpenPosition,
        ),
      ],
    );
  }

  Widget _buildPositionsTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: analytics.positions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final position = analytics.positions[index];
        return Dismissible(
          key: Key(position.snapshot.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
          ),
          confirmDismiss: (_) => onDeletePosition(
            position.snapshot.id,
            position.snapshot.symbol,
          ),
          child: _PositionTile(
            analytics: position,
            onTap: () {
              final fallbackName =
                  position.snapshot.displayName.isNotEmpty
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
            onEdit: () => onEditPosition(
              position.snapshot.id,
              position.snapshot.symbol,
              position.snapshot.quantity,
              position.snapshot.costBasis,
            ),
          ),
        );
      },
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final changeColor =
        analytics.totalChangeValue == null
            ? Colors.black
            : analytics.totalChangeValue! >= 0
            ? Colors.green.shade600
            : Colors.red.shade600;

    final valueText =
        analytics.totalValue != null
            ? _formatCurrency(analytics.totalValue!, analytics.singleCurrency)
            : 'Multi devises';
    final changeText =
        analytics.totalChangeValue != null
            ? _formatCurrency(
              analytics.totalChangeValue!,
              analytics.singleCurrency,
              signed: true,
            )
            : '—';
    final changeSubtitle =
        analytics.totalChangePercent != null
            ? _formatSignedPercent(analytics.totalChangePercent!)
            : 'Variation indisponible';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aperçu',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  subtitle:
                      analytics.totalValue != null
                          ? 'Cours instantané'
                          : 'Addition brute des devises',
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
    final hasValue =
        analytics.totalValue != null && analytics.singleCurrency != null;
    final simulatedValue =
        hasValue ? analytics.totalValue! * (1 + _scenarioPercent / 100) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Performance',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child:
                    simulatedValue == null
                        ? const SizedBox.shrink()
                        : Text(
                          _formatCurrency(
                            simulatedValue,
                            analytics.singleCurrency!,
                          ),
                          key: ValueKey<double>(simulatedValue),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
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
                  label: Text(
                    percent == 0
                        ? 'Réel'
                        : (percent > 0
                            ? '+${percent.toInt()} %'
                            : '${percent.toInt()} %'),
                  ),
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

class _PnLTableSection extends StatelessWidget {
  const _PnLTableSection({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final positions = analytics.positions;
    if (positions.isEmpty) return const SizedBox.shrink();

    double totalInvested = 0;
    double totalCurrent = 0;
    bool hasAnyPru = false;

    for (final p in positions) {
      final pru = p.snapshot.costBasis;
      final price = p.snapshot.price;
      final qty = p.snapshot.quantity;
      if (pru != null) {
        totalInvested += pru * qty;
        hasAnyPru = true;
      }
      if (price != null) totalCurrent += price * qty;
    }

    final totalLatent = hasAnyPru ? totalCurrent - totalInvested : null;
    final totalLatentPct =
        hasAnyPru && totalInvested > 0
            ? (totalLatent! / totalInvested) * 100
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plus-values latentes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6E8EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Titre',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'PRU → Cours',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Latent',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // Position rows
                ...positions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final pru = p.snapshot.costBasis;
                  final price = p.snapshot.price;
                  final qty = p.snapshot.quantity;
                  final currency = p.snapshot.currency;

                  double? latentVal;
                  double? latentPct;
                  if (pru != null && price != null) {
                    latentVal = (price - pru) * qty;
                    latentPct = ((price - pru) / pru) * 100;
                  }

                  final isLast = i == positions.length - 1;
                  final color =
                      latentVal == null
                          ? Colors.black54
                          : latentVal >= 0
                          ? Colors.green.shade600
                          : Colors.red.shade600;

                  final symbol =
                      p.snapshot.symbol.isNotEmpty
                          ? p.snapshot.symbol.toUpperCase()
                          : '?';

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    symbol,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    '${qty % 1 == 0 ? qty.toInt() : qty} titre${qty > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black38,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (pru != null)
                                    Text(
                                      _formatCurrency(pru, currency),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (price != null)
                                    Text(
                                      _formatCurrency(price, currency),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  if (pru == null && price == null)
                                    const Text(
                                      '—',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.black38),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (latentVal != null)
                                    Text(
                                      _formatCurrency(
                                        latentVal,
                                        currency,
                                        signed: true,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  if (latentPct != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _formatSignedPercent(latentPct),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  if (latentVal == null)
                                    const Text(
                                      '—',
                                      style: TextStyle(color: Colors.black38),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  );
                }),
                // Total row
                if (totalLatent != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 5,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _formatCurrency(
                              totalCurrent,
                              analytics.singleCurrency ?? '',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatCurrency(
                                  totalLatent,
                                  analytics.singleCurrency ?? '',
                                  signed: true,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      totalLatent >= 0
                                          ? Colors.green.shade600
                                          : Colors.red.shade600,
                                ),
                              ),
                              if (totalLatentPct != null)
                                Text(
                                  _formatSignedPercent(totalLatentPct),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        totalLatentPct >= 0
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({
    required this.analytics,
    required this.onOpenPosition,
  });

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
        children:
            cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ),
                )
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
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          slices
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
      label =
          '${analytics.bestPerformer!.snapshot.displayName.isNotEmpty ? analytics.bestPerformer!.snapshot.displayName : analytics.bestPerformer!.snapshot.symbol} : ${_formatPercent(topWeight * 100)}';
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
              valueColor: AlwaysStoppedAnimation<Color>(
                alert ? Colors.redAccent : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
      );
    }
    return Column(
      children:
          entries
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
                          entry.symbol
                              .substring(
                                0,
                                entry.symbol.length >= 3
                                    ? 3
                                    : entry.symbol.length,
                              )
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Ajouté ${_relativeDate(entry.date)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
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
    final changeText =
        analytics.changePercent != null
            ? _formatSignedPercent(analytics.changePercent!)
            : analytics.changeValue != null
            ? _formatCurrency(
              analytics.changeValue!,
              snapshot.currency,
              signed: true,
            )
            : 'Variation indisponible';

    final rawType = snapshot.quoteType;
    final quoteType =
        rawType.isEmpty || rawType.toUpperCase() == 'UNKNOWN' ? null : rawType;

    return InkWell(
      onTap:
          () => onOpen(
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
              child: Text(
                snapshot.symbol.isEmpty
                    ? '?'
                    : snapshot.symbol[0].toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.displayName.isNotEmpty
                        ? snapshot.displayName
                        : snapshot.symbol,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Poids ${_formatPercent(analytics.weight * 100)} · $changeText',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
  const _PositionTile({
    required this.analytics,
    required this.onTap,
    this.onEdit,
  });

  final _PositionAnalytics analytics;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final snapshot = analytics.snapshot;
    final theme = Theme.of(context);

    final title =
        snapshot.displayName.isNotEmpty
            ? snapshot.displayName
            : snapshot.symbol;
    final subtitleParts = <String>[];
    subtitleParts.add(snapshot.symbol.toUpperCase());
    if (snapshot.exchange.isNotEmpty)
      subtitleParts.add(snapshot.exchange.toUpperCase());
    if (snapshot.currency.isNotEmpty)
      subtitleParts.add(snapshot.currency.toUpperCase());

    final valueText =
        analytics.value != null
            ? _formatCurrency(analytics.value!, snapshot.currency)
            : '—';
    final changeText =
        analytics.changePercent != null
            ? _formatSignedPercent(analytics.changePercent!)
            : analytics.changeValue != null
            ? _formatCurrency(
              analytics.changeValue!,
              snapshot.currency,
              signed: true,
            )
            : null;
    final changeColor =
        analytics.changePercent != null
            ? (analytics.changePercent! >= 0
                ? Colors.green.shade600
                : Colors.red.shade600)
            : (analytics.changeValue != null
                ? (analytics.changeValue! >= 0
                    ? Colors.green.shade600
                    : Colors.red.shade600)
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
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
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
                snapshot.symbol.isNotEmpty
                    ? snapshot.symbol.substring(0, 2).toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (changeText != null)
                  Text(
                    changeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (analytics.snapshot.costBasis != null)
                  Text(
                    'PRU ${_formatCurrency(analytics.snapshot.costBasis!, analytics.snapshot.currency)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.black38,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: detailsColor1.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: detailsColor1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Virtual portfolio helpers (design matching game portfolio) ─────────────

class _VirtualCircleButton extends StatelessWidget {
  const _VirtualCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: textColor),
      ),
    );
  }
}

class _VirtualTabStrip extends StatelessWidget {
  const _VirtualTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Vue'),
          Tab(text: 'Analyse'),
          Tab(text: 'Positions'),
        ],
      ),
    );
  }
}

class _VirtualTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _VirtualTabHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 76;

  @override
  double get maxExtent => 76;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: backgroundColor, child: child);
  }

  @override
  bool shouldRebuild(covariant _VirtualTabHeaderDelegate old) =>
      old.child != child;
}

class _VirtualHeroCard extends StatelessWidget {
  const _VirtualHeroCard({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final totalValue = analytics.totalValue;
    final totalChange = analytics.totalChangeValue;
    final totalChangePct = analytics.totalChangePercent;
    final positive = totalChange == null || totalChange >= 0;

    final valueText = totalValue != null
        ? _formatCurrency(totalValue, analytics.singleCurrency)
        : 'Multi-devises';
    final changeText = totalChange != null
        ? _formatCurrency(totalChange, analytics.singleCurrency, signed: true)
        : null;
    final pctText = totalChangePct != null
        ? _formatSignedPercent(totalChangePct)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9D8A0)),
        boxShadow: [
          BoxShadow(
            color: detailsColor1.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Valeur simulée',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  valueText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                if (changeText != null || pctText != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (changeText != null)
                        Text(
                          changeText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: positive
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                          ),
                        ),
                      if (changeText != null && pctText != null)
                        const SizedBox(width: 8),
                      if (pctText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: positive
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pctText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: positive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${analytics.positions.length} ligne${analytics.positions.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Simulation',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortfolioAnalyticsError extends StatelessWidget {
  const _PortfolioAnalyticsError({
    required this.message,
    required this.onRetry,
  });

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
              style: TextStyle(
                color: Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
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
                _formatHistoryLabel(
                  points.first.value,
                  series.currency,
                  series.normalized,
                ),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.black54),
              ),
            ),
            Positioned(
              right: 12,
              top: 8,
              child: Text(
                _formatHistoryLabel(
                  points.last.value,
                  series.currency,
                  series.normalized,
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
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
    final range =
        (maxValue - minValue).abs() < 1e-6 ? 1.0 : maxValue - minValue;
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

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color;
    final fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      !identical(oldDelegate.points, points) || oldDelegate.color != color;
}

class _PortfolioPositionSnapshot {
  const _PortfolioPositionSnapshot({
    required this.id,
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

  final String id;
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

  static _PortfolioPositionSnapshot fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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
      id: doc.id,
      symbol: (data['symbol'] as String? ?? '').trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      exchange: (data['exchange'] as String? ?? '').trim(),
      currency: (data['currency'] as String? ?? '').trim(),
      quoteType: (data['quoteType'] as String? ?? 'UNKNOWN').trim(),
      price: priceValue is num ? priceValue.toDouble() : null,
      change: changeValue is num ? changeValue.toDouble() : null,
      changePercent:
          changePercentValue is num ? changePercentValue.toDouble() : null,
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
  const _TimelineEntry({
    required this.symbol,
    required this.name,
    required this.date,
  });

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

  factory _PortfolioAnalytics.empty(
    List<_PortfolioPositionSnapshot> positions,
  ) {
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
      timeline:
          positions
              .where((p) => p.addedAt != null)
              .map(
                (p) => _TimelineEntry(
                  symbol: p.symbol,
                  name: p.displayName.isNotEmpty ? p.displayName : p.symbol,
                  date: p.addedAt!,
                ),
              )
              .toList(),
      history: const _HistorySeries(
        points: <_HistoryPoint>[],
        currency: null,
        normalized: true,
      ),
    );
  }
}

Future<_PortfolioAnalytics> _computeAnalytics(
  List<_PortfolioPositionSnapshot> positions,
) async {
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
  } else if (hasChangeValue &&
      totalValueOrNull != null &&
      (totalValueOrNull - totalChangeValueOrNull!).abs() > 1e-6) {
    final previousValue = totalValueOrNull - totalChangeValueOrNull;
    totalChangePercent =
        previousValue.abs() < 1e-6
            ? null
            : (totalChangeValueOrNull / previousValue) * 100;
  }

  final positionsAnalytics =
      positions.map((position) {
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
    final score =
        position.changePercent ??
        (position.changeValue != null &&
                position.value != null &&
                position.value!.abs() > 1e-6
            ? (position.changeValue! /
                    (position.value! - position.changeValue!)) *
                100
            : null);
    if (score == null) continue;
    if (bestPerformer == null ||
        score > (bestPerformer.changePercent ?? double.negativeInfinity)) {
      bestPerformer = position;
    }
    if (worstPerformer == null ||
        score < (worstPerformer.changePercent ?? double.infinity)) {
      worstPerformer = position;
    }
  }

  final concentrationRatio = positionsAnalytics
      .map((p) => p.weight)
      .fold<double>(
        0,
        (previousValue, element) =>
            element > previousValue ? element : previousValue,
      );

  final currencyDistribution = _buildDistribution(
    positionsAnalytics,
    (p) =>
        p.snapshot.currency.isNotEmpty
            ? p.snapshot.currency.toUpperCase()
            : 'N/A',
    totalValueOrNull,
  );
  final exchangeDistribution = _buildDistribution(
    positionsAnalytics,
    (p) =>
        p.snapshot.exchange.isNotEmpty
            ? p.snapshot.exchange.toUpperCase()
            : 'N/A',
    totalValueOrNull,
  );

  final timeline =
      positions
          .where((p) => p.addedAt != null)
          .map(
            (p) => _TimelineEntry(
              symbol: p.symbol,
              name: p.displayName.isNotEmpty ? p.displayName : p.symbol,
              date: p.addedAt!,
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final history = await _buildAggregatedHistory(
    positions,
    singleCurrency: singleCurrency,
  );

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
    final weight =
        totalValue != null && position.value != null ? position.value! : 1.0;
    map[key] = (map[key] ?? 0) + weight;
  }
  if (total <= 0) return const [];
  return map.entries
      .map(
        (e) => _DistributionSlice(
          label: e.key,
          weight: (e.value / total).clamp(0.0, 1.0),
        ),
      )
      .toList()
    ..sort((a, b) => b.weight.compareTo(a.weight));
}

Future<_HistorySeries> _buildAggregatedHistory(
  List<_PortfolioPositionSnapshot> positions, {
  required String? singleCurrency,
}) async {
  if (positions.isEmpty) {
    return const _HistorySeries(
      points: <_HistoryPoint>[],
      currency: null,
      normalized: true,
    );
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
      final points = await YahooFinanceService.fetchHistoricalSeries(
        position.symbol,
        interval,
      );
      return _SymbolHistory(
        position: position,
        interval: interval,
        points: points,
      );
    } catch (_) {
      return _SymbolHistory(
        position: position,
        interval: interval,
        points: const <HistoricalPoint>[],
      );
    }
  });

  final histories = await Future.wait(futures);
  final normalized = singleCurrency == null;
  final currency = normalized ? null : singleCurrency;
  final map = SplayTreeMap<DateTime, double>();

  for (final history in histories) {
    final filtered =
        history.points
            .where(
              (point) =>
                  history.position.addedAt == null ||
                  !point.time.isBefore(history.position.addedAt!),
            )
            .toList();
    if (filtered.isEmpty) {
      if (history.position.price != null) {
        final now = DateTime.now();
        final key = _normalizeHistoryTime(now, history.interval);
        final contribution =
            normalized
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
      final contribution =
          normalized
              ? (baseline.abs() < 1e-6
                  ? history.position.quantity
                  : (point.close / baseline) * history.position.quantity)
              : point.close * history.position.quantity;
      map[key] = (map[key] ?? 0) + contribution;
    }

    if (history.position.price != null) {
      final key = _normalizeHistoryTime(DateTime.now(), history.interval);
      final contribution =
          normalized
              ? (baseline.abs() < 1e-6
                  ? history.position.quantity
                  : (history.position.price! / baseline) *
                      history.position.quantity)
              : history.position.price! * history.position.quantity;
      map[key] = (map[key] ?? 0) + contribution;
    }
  }

  if (map.isEmpty) {
    return const _HistorySeries(
      points: <_HistoryPoint>[],
      currency: null,
      normalized: true,
    );
  }

  final points =
      map.entries
          .map((e) => _HistoryPoint(time: e.key, value: e.value))
          .toList();
  if (normalized) {
    final firstValue = points.first.value;
    if (firstValue.abs() > 1e-6) {
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        points[i] = _HistoryPoint(
          time: point.time,
          value: (point.value / firstValue) * 100,
        );
      }
    }
  }

  return _HistorySeries(
    points: points,
    currency: currency,
    normalized: normalized,
  );
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
      final step =
          granularity == '5m'
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
  final fixed =
      value.abs() >= 100 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
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
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
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
          Text(
            'Variations marquantes',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
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
    final name =
        analytics.snapshot.displayName.isNotEmpty
            ? analytics.snapshot.displayName
            : analytics.snapshot.symbol;
    final percent =
        analytics.changePercent != null
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
        Icon(
          positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: positive ? Colors.green.shade600 : Colors.red.shade600,
          size: 20,
        ),
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
  const _EmptyPortfolioState({
    this.onCreate,
    this.onCreateStarter,
    this.ideas = const <_StarterWatchIdea>[],
  });

  final VoidCallback? onCreate;
  final VoidCallback? onCreateStarter;
  final List<_StarterWatchIdea> ideas;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE6E8EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Portefeuille pedagogique',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Installe une watchlist de depart pour apprendre a comparer un ETF, une Big Tech et une valeur europeenne.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        ideas
                            .map(
                              (idea) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFE6E8EB),
                                  ),
                                ),
                                child: Text(
                                  '${idea.symbol} · ${idea.name}',
                                  style: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCreateStarter,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      label: const Text('Installer la watchlist de depart'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Crée ton premier portefeuille\npour suivre tes actions favorites.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: const Text('Créer un portefeuille'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarterWatchIdea {
  const _StarterWatchIdea({
    required this.symbol,
    required this.name,
    required this.description,
  });

  final String symbol;
  final String name;
  final String description;
}

class _PortfolioListSkeleton extends StatelessWidget {
  const _PortfolioListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: 3,
      itemBuilder:
          (context, index) => Container(
            height: 108,
            margin: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6E8EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 180,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _PortfolioDetailSkeleton extends StatelessWidget {
  const _PortfolioDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: List.generate(
        4,
        (index) => Container(
          height: index == 0 ? 120 : 88,
          margin: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
        ),
      ),
    );
  }
}

class _PortfolioCoachCard extends StatelessWidget {
  const _PortfolioCoachCard({required this.analytics});

  final _PortfolioAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final recommendations = <String>[
      if (analytics.positions.length < 3)
        'Ajoute encore 1 a 2 titres pour comparer plusieurs styles de marche.',
      if (analytics.concentrationRatio >= 0.35)
        'Un seul titre pese beaucoup dans le portefeuille. Diversifie pour mieux comparer les risques.',
      if (analytics.bestPerformer != null)
        'Ouvre le meilleur titre pour relire ses fondamentaux et comprendre ce qui tire la performance.',
      'Apres chaque achat ou vente, relis la repartition devises et la concentration.',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6E8EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lecture pedagogique',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le but est de comprendre ce que tu deplaces dans ton portefeuille, pas seulement d’ajouter des lignes.',
              style: TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < recommendations.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == recommendations.length - 1 ? 0 : 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [detailsColor1, detailsColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recommendations[index],
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
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
