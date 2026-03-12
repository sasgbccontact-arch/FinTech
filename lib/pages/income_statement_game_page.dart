import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';

import '../models/fundamental_game_models.dart';
import '../services/fundamental_game_engine.dart';
import '../services/yahoo_finance_service.dart';

class IncomeStatementGamePage extends StatefulWidget {
  const IncomeStatementGamePage({super.key});

  @override
  State<IncomeStatementGamePage> createState() =>
      _IncomeStatementGamePageState();
}

class _IncomeStatementGamePageState extends State<IncomeStatementGamePage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<TickerSearchResult> _suggestions = [];
  TickerSearchResult? _selectedTicker;
  FundamentalGameConfig? _config;
  FundamentalGameData? _gameData;
  FundamentalAnalysisResult? _analysis;

  bool _loadingConfig = true;
  bool _loadingSearch = false;
  bool _loadingAnalysis = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await FundamentalGameEngine.loadConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _message = 'Configuration du jeu indisponible.';
      });
    }
  }

  Future<void> _searchTickers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _loadingSearch = false;
      });
      return;
    }

    setState(() {
      _loadingSearch = true;
      _message = null;
    });

    try {
      final results = await YahooFinanceService.searchEquities(trimmed);
      if (!mounted) return;
      setState(() {
        _suggestions = results.take(8).toList();
        _loadingSearch = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSearch = false;
        _message = 'Recherche indisponible pour le moment.';
      });
    }
  }

  Future<void> _selectTicker(TickerSearchResult ticker) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedTicker = ticker;
      _searchController.text = ticker.symbol;
      _suggestions = [];
      _gameData = null;
      _analysis = null;
      _loadingAnalysis = true;
      _message = null;
    });

    if (!ticker.isEquity) {
      setState(() {
        _loadingAnalysis = false;
        _message = 'Choisis une action réelle, pas un ETF ou un fonds.';
      });
      return;
    }

    try {
      final config = _config ?? await FundamentalGameEngine.loadConfig();
      final data = await YahooFinanceService.fetchFundamentalGameData(
        ticker.symbol,
      );
      if (!mounted) return;

      if (!data.isEquity) {
        setState(() {
          _loadingAnalysis = false;
          _message = 'Choisis une action réelle, pas un ETF ou un fonds.';
        });
        return;
      }

      final analysis = FundamentalGameEngine.analyze(
        data: data,
        config: config,
      );
      setState(() {
        _config = config;
        _gameData = data;
        _analysis = analysis;
        _loadingAnalysis = false;
        _message =
            analysis.isInsufficientData
                ? 'Données insuffisantes pour une lecture fiable : certaines catégories restent N/A.'
                : null;
      });
    } on FinanceRequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAnalysis = false;
        _message = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAnalysis = false;
        _message =
            'Impossible de charger les fondamentaux de cette action pour le moment.';
      });
    }
  }

  String _qualityLabel(FundamentalAnalysisResult analysis) {
    if (analysis.isInsufficientData) {
      return 'Qualité limitée • ${analysis.qualitySummary}';
    }
    return 'Qualité des données • ${analysis.qualitySummary}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedTicker = _selectedTicker;
    final analysis = _analysis;
    final gameData = _gameData;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Stock Analyst — Défi fondamental',
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _IntroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Score automatiquement une entreprise sur 100',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le module charge les fondamentaux réels d’une action, calcule 5 sous-scores, attribue des badges puis génère un résumé pédagogique et une checklist.',
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6E8EB)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => _searchTickers(value),
                        );
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Rechercher un ticker ou une entreprise',
                        icon: Icon(Icons.manage_search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingConfig) const LinearProgressIndicator(),
                  if (_loadingSearch) const LinearProgressIndicator(),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._suggestions.map(
                      (ticker) => _TickerSuggestionTile(
                        ticker: ticker,
                        onTap: () => _selectTicker(ticker),
                      ),
                    ),
                  ],
                  if (FirebaseAuth.instance.currentUser != null) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Raccourcis favoris',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _FavoriteTickerChips(onTap: _selectTicker),
                  ],
                ],
              ),
            ),
            if (selectedTicker != null) ...[
              const SizedBox(height: 16),
              _IntroCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [detailsColor1, detailsColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selectedTicker.symbol.substring(
                          0,
                          selectedTicker.symbol.length >= 4
                              ? 4
                              : selectedTicker.symbol.length,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gameData?.companyName ?? selectedTicker.displayName,
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${selectedTicker.symbol} • ${selectedTicker.exchange}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (analysis != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _qualityLabel(analysis),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_loadingAnalysis) const CircularProgressIndicator(),
                  ],
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              _StatusCard(message: _message!),
            ],
            if (analysis != null) ...[
              const SizedBox(height: 16),
              _ScoreOverviewCard(
                score: analysis.finalScore,
                verdict: analysis.verdict,
                qualitySummary: analysis.qualitySummary,
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.analytics_rounded,
                title: 'Sous-scores',
              ),
              const SizedBox(height: 10),
              ...analysis.subScores.map(_SubScoreCard.new),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.workspace_premium_rounded,
                title: 'Badges',
              ),
              const SizedBox(height: 10),
              _BadgesCard(badges: analysis.badges),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.short_text_rounded,
                title: 'Résumé 3 lignes',
              ),
              const SizedBox(height: 10),
              _BulletCard(lines: analysis.summaryLines),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.fact_check_rounded,
                title: 'Actions à vérifier',
              ),
              const SizedBox(height: 10),
              _BulletCard(lines: analysis.checklist),
              if (analysis.missingData.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionTitle(
                  icon: Icons.warning_amber_rounded,
                  title: 'Données manquantes',
                ),
                const SizedBox(height: 10),
                _BulletCard(lines: analysis.missingData),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: textColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScoreOverviewCard extends StatelessWidget {
  const _ScoreOverviewCard({
    required this.score,
    required this.verdict,
    required this.qualitySummary,
  });

  final double? score;
  final String verdict;
  final String qualitySummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score final',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score == null ? 'N/A' : score!.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  '/100',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScoreBadge(
                label: verdict,
                backgroundColor: Colors.white,
                foregroundColor: _verdictColor(verdict),
              ),
              _ScoreBadge(
                label: qualitySummary,
                backgroundColor: Colors.white.withValues(alpha: .16),
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _verdictColor(String value) {
    switch (value) {
      case 'Top pick':
        return Colors.green.shade700;
      case 'Bonne':
        return Colors.teal.shade700;
      case 'Moyenne':
        return Colors.orange.shade700;
      default:
        return Colors.red.shade700;
    }
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SubScoreCard extends StatelessWidget {
  const _SubScoreCard(this.subScore);

  final FundamentalSubScore subScore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _IntroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subScore.title,
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                _MetricScorePill(
                  label:
                      subScore.score == null
                          ? 'N/A'
                          : '${subScore.score!.toStringAsFixed(0)}/20',
                ),
                if (subScore.partial) ...[
                  const SizedBox(width: 8),
                  const _MetricScorePill(label: 'Partiel'),
                ],
              ],
            ),
            if (subScore.note != null) ...[
              const SizedBox(height: 8),
              Text(
                subScore.note!,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...subScore.metrics.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MetricRow(metric: metric),
              ),
            ),
            if (subScore.missingMetrics.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Manque : ${subScore.missingMetrics.join(', ')}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final FundamentalMetricEvaluation metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _MetricScorePill(
                label:
                    metric.score == null
                        ? 'N/A'
                        : '${metric.score!.toStringAsFixed(0)}/20',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            metric.displayValue,
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (metric.note != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.note!,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricScorePill extends StatelessWidget {
  const _MetricScorePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.badges});

  final List<FundamentalBadge> badges;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child:
          badges.isEmpty
              ? const Text(
                'Aucun badge instantané déclenché sur les données disponibles.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              )
              : Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    badges
                        .map(
                          (badge) => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE6E8EB),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  badge.label,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    badge.description,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            lines
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: detailsColor2,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line,
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
                )
                .toList(),
      ),
    );
  }
}

class _FavoriteTickerChips extends StatelessWidget {
  const _FavoriteTickerChips({required this.onTap});

  final ValueChanged<TickerSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('favoris')
              .orderBy('addedAt', descending: true)
              .limit(5)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              docs.map((doc) {
                final data = doc.data();
                final symbol = (data['symbol'] as String? ?? doc.id).trim();
                if (symbol.isEmpty) return const SizedBox.shrink();
                final name = (data['name'] as String? ?? symbol).trim();
                final exchange = (data['exchange'] as String? ?? '').trim();
                final currency = (data['currency'] as String? ?? '').trim();
                final quoteType =
                    (data['quoteType'] as String? ?? 'EQUITY').trim();

                return ActionChip(
                  label: Text(symbol),
                  onPressed:
                      () => onTap(
                        TickerSearchResult(
                          symbol: symbol,
                          displayName: name,
                          exchange: exchange,
                          quoteType: quoteType,
                          region: '',
                          currency: currency,
                        ),
                      ),
                );
              }).toList(),
        );
      },
    );
  }
}

class _TickerSuggestionTile extends StatelessWidget {
  const _TickerSuggestionTile({required this.ticker, required this.onTap});

  final TickerSearchResult ticker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker.displayName,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ticker.symbol} • ${ticker.exchange}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: detailsColor2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
