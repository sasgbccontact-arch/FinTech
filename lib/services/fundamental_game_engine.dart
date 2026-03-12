import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/fundamental_game_models.dart';

class FundamentalGameEngine {
  FundamentalGameEngine._();

  static const _configPath = 'assets/fundamental_game_config.json';

  static FundamentalGameConfig? _cachedConfig;

  static Future<FundamentalGameConfig> loadConfig() async {
    if (_cachedConfig != null) return _cachedConfig!;
    final raw = await rootBundle.loadString(_configPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Configuration fondamentale invalide.');
    }
    _cachedConfig = FundamentalGameConfig.fromJson(decoded);
    return _cachedConfig!;
  }

  static FundamentalAnalysisResult analyze({
    required FundamentalGameData data,
    required FundamentalGameConfig config,
  }) {
    final derived = _DerivedMetrics.fromData(data);
    final missingData = <String>{};

    final subScores = <FundamentalSubScore>[
      _buildCategory(
        categoryId: 'valuation',
        config: config,
        metricInputs: [
          _MetricInput('trailingPe', data.trailingPe),
          _MetricInput('enterpriseToEbitda', data.enterpriseToEbitda),
        ],
        missingData: missingData,
      ),
      _buildCategory(
        categoryId: 'growth',
        config: config,
        metricInputs: [
          _MetricInput('revenueCagr3y', derived.revenueCagr3y),
          _MetricInput('epsCagr3y', derived.epsCagr3y),
        ],
        missingData: missingData,
      ),
      _buildCategory(
        categoryId: 'profitability',
        config: config,
        metricInputs: [
          _MetricInput('returnOnEquity', data.returnOnEquity),
          _MetricInput('ebitMargin', derived.ebitMargin),
          _MetricInput('freeCashflowYield', data.freeCashflowYield),
        ],
        missingData: missingData,
      ),
      _buildCategory(
        categoryId: 'balanceSheet',
        config: config,
        metricInputs: [
          _MetricInput('debtToEbitda', derived.normalizedDebtToEbitda),
          _MetricInput('cashToDebtRatio', derived.cashToDebtRatio),
        ],
        missingData: missingData,
        scoreAdjustment: derived.hasNetCash ? config.netCashBonus : 0,
        note:
            derived.hasNetCash
                ? 'Bonus net cash appliqué : trésorerie supérieure à la dette.'
                : null,
      ),
      _buildDistributionCategory(
        data: data,
        config: config,
        derived: derived,
        missingData: missingData,
      ),
    ];

    double weightedScoreSum = 0;
    double activeWeight = 0;
    var partialCategoryCount = 0;
    var activeCategoryCount = 0;

    for (final subScore in subScores) {
      if (subScore.score == null) continue;
      activeCategoryCount++;
      if (subScore.partial) partialCategoryCount++;
      weightedScoreSum += (subScore.score! / 20) * subScore.weight;
      activeWeight += subScore.weight;
    }

    final finalScore =
        activeWeight > 0
            ? ((weightedScoreSum / activeWeight) * 100).clamp(0, 100).toDouble()
            : null;
    final verdict = _resolveVerdict(finalScore, config);
    final features = derived.toBadgeFeatures(data);
    final badges = _buildBadges(config, features);
    final summaryLines = _buildSummaryLines(
      subScores: subScores,
      finalScore: finalScore,
      verdict: verdict,
      activeCategoryCount: activeCategoryCount,
    );
    final checklist = _buildChecklist(
      subScores: subScores,
      missingData: missingData.toList(),
      badges: badges,
      finalScore: finalScore,
    );

    return FundamentalAnalysisResult(
      finalScore: finalScore,
      verdict: verdict,
      subScores: List.unmodifiable(subScores),
      badges: List.unmodifiable(badges),
      summaryLines: List.unmodifiable(summaryLines),
      checklist: List.unmodifiable(checklist),
      missingData: List.unmodifiable(missingData.toList()..sort()),
      activeCategoryCount: activeCategoryCount,
      partialCategoryCount: partialCategoryCount,
      isInsufficientData: finalScore == null || activeCategoryCount < 2,
    );
  }

  static FundamentalSubScore _buildCategory({
    required String categoryId,
    required FundamentalGameConfig config,
    required List<_MetricInput> metricInputs,
    required Set<String> missingData,
    double scoreAdjustment = 0,
    String? note,
  }) {
    final category = config.categories[categoryId];
    if (category == null) {
      throw StateError('Catégorie fondamentale inconnue: $categoryId');
    }

    final evaluations = <FundamentalMetricEvaluation>[];
    final availableScores = <double>[];
    final missingMetrics = <String>[];

    for (final input in metricInputs) {
      final evaluation = _evaluateMetric(
        metricId: input.metricId,
        rawValue: input.rawValue,
        config: config,
      );
      evaluations.add(evaluation);
      if (evaluation.score != null) {
        availableScores.add(evaluation.score!);
      } else {
        missingMetrics.add(evaluation.label);
        missingData.add(evaluation.label);
      }
    }

    if (availableScores.isEmpty) {
      return FundamentalSubScore(
        id: category.id,
        title: category.title,
        weight: category.weight,
        score: null,
        partial: false,
        metrics: List.unmodifiable(evaluations),
        missingMetrics: List.unmodifiable(missingMetrics),
        note: note ?? 'Aucune métrique exploitable pour cette catégorie.',
      );
    }

    final rawScore =
        availableScores.reduce((left, right) => left + right) /
        availableScores.length;
    final adjustedScore = (rawScore + scoreAdjustment).clamp(0, 20).toDouble();

    return FundamentalSubScore(
      id: category.id,
      title: category.title,
      weight: category.weight,
      score: adjustedScore,
      partial: missingMetrics.isNotEmpty,
      metrics: List.unmodifiable(evaluations),
      missingMetrics: List.unmodifiable(missingMetrics),
      note: note,
    );
  }

  static FundamentalSubScore _buildDistributionCategory({
    required FundamentalGameData data,
    required FundamentalGameConfig config,
    required _DerivedMetrics derived,
    required Set<String> missingData,
  }) {
    final category = config.categories['distribution'];
    if (category == null) {
      throw StateError('Catégorie fondamentale inconnue: distribution');
    }

    if (!derived.hasRecentDividend) {
      return FundamentalSubScore(
        id: category.id,
        title: category.title,
        weight: category.weight,
        score: null,
        partial: false,
        metrics: List.unmodifiable([
          _evaluateMetric(
            metricId: 'payoutRatio',
            rawValue: null,
            config: config,
            overrideLabel: 'Payout ratio',
          ),
          _evaluateMetric(
            metricId: 'dividendStability',
            rawValue: null,
            config: config,
            overrideLabel: 'Stabilité du dividende',
          ),
        ]),
        missingMetrics: const <String>['Historique de dividendes sur 5 ans'],
        note: 'Aucun dividende récent : catégorie retirée du score final.',
      );
    }

    final result = _buildCategory(
      categoryId: 'distribution',
      config: config,
      metricInputs: [
        _MetricInput('payoutRatio', data.payoutRatio),
        _MetricInput('dividendStability', derived.dividendStability),
      ],
      missingData: missingData,
      note:
          derived.hasFiveYearDividendHistory
              ? 'Lecture basée sur les 5 dernières années complètes de dividendes.'
              : 'Historique de dividendes incomplet : lecture partielle.',
    );

    if (!derived.hasFiveYearDividendHistory) {
      missingData.add('Historique complet de dividendes sur 5 ans');
    }
    return result;
  }

  static FundamentalMetricEvaluation _evaluateMetric({
    required String metricId,
    required double? rawValue,
    required FundamentalGameConfig config,
    String? overrideLabel,
  }) {
    final rule = config.metrics[metricId];
    if (rule == null) {
      throw StateError('Règle fondamentale inconnue: $metricId');
    }
    final label = overrideLabel ?? rule.label;
    final score = rule.scoreFor(rawValue);
    return FundamentalMetricEvaluation(
      id: metricId,
      label: label,
      displayValue: _formatMetricValue(metricId, rawValue),
      score: score,
      isMissing: rawValue == null,
      rawValue: rawValue,
      note: rawValue == null ? 'Donnée indisponible.' : _metricNote(metricId),
    );
  }

  static String _resolveVerdict(
    double? finalScore,
    FundamentalGameConfig config,
  ) {
    if (finalScore == null) return 'Données insuffisantes';
    for (final verdict in config.verdicts) {
      if (verdict.matches(finalScore)) return verdict.label;
    }
    return 'Données insuffisantes';
  }

  static List<FundamentalBadge> _buildBadges(
    FundamentalGameConfig config,
    Map<String, double> features,
  ) {
    final badges = <FundamentalBadge>[];
    for (final entry in config.badges.entries) {
      if (!entry.value.matches(features)) continue;
      badges.add(
        FundamentalBadge(
          id: entry.key,
          label: entry.value.label,
          description: entry.value.description,
        ),
      );
    }
    return badges;
  }

  static List<String> _buildSummaryLines({
    required List<FundamentalSubScore> subScores,
    required double? finalScore,
    required String verdict,
    required int activeCategoryCount,
  }) {
    final active =
        subScores.where((score) => score.score != null).toList()
          ..sort((a, b) => b.score!.compareTo(a.score!));
    if (active.isEmpty) {
      return const <String>[
        'Lecture impossible : les données fondamentales sont trop lacunaires.',
        'Complète l’historique financier avant de conclure.',
        'Verdict : données insuffisantes.',
      ];
    }

    final strongest = active.first;
    final weakest = active.last;
    final finalLineScore =
        finalScore == null ? 'N/A' : '${finalScore.toStringAsFixed(0)}/100';

    final weakestLine =
        active.length == 1
            ? 'Seule la catégorie ${strongest.title.toLowerCase()} est réellement exploitable pour l’instant.'
            : 'Point de vigilance principal : ${weakest.title.toLowerCase()} (${weakest.score!.toStringAsFixed(0)}/20).';

    return <String>[
      'Point fort principal : ${strongest.title.toLowerCase()} (${strongest.score!.toStringAsFixed(0)}/20).',
      weakestLine,
      'Verdict : $verdict avec un score fondamental de $finalLineScore sur $activeCategoryCount catégorie(s) active(s).',
    ];
  }

  static List<String> _buildChecklist({
    required List<FundamentalSubScore> subScores,
    required List<String> missingData,
    required List<FundamentalBadge> badges,
    required double? finalScore,
  }) {
    final items = <String>[];
    final active =
        subScores.where((score) => score.score != null).toList()
          ..sort((a, b) => a.score!.compareTo(b.score!));

    for (final subScore in active) {
      if (subScore.score! >= 12 || items.length >= 3) continue;
      items.add(_categoryChecklist(subScore.id));
    }

    if (missingData.isNotEmpty && items.length < 4) {
      items.add(
        'Compléter les données manquantes : ${missingData.take(3).join(', ')}.',
      );
    }

    final badgeIds = badges.map((badge) => badge.id).toSet();
    if (!badgeIds.contains('growth') && items.length < 5) {
      items.add(
        'Relire les publications récentes pour confirmer la trajectoire de croissance du chiffre d’affaires et du BPA.',
      );
    }
    if (!badgeIds.contains('netCash') && items.length < 5) {
      items.add(
        'Vérifier l’échéancier de dette, la liquidité disponible et le risque de refinancement.',
      );
    }
    if ((finalScore ?? 0) < 60 && items.length < 5) {
      items.add(
        'Lire la note de gestion pour identifier les éléments non récurrents et les risques sectoriels.',
      );
    }

    if (items.length < 3) {
      items.add(
        'Comparer systématiquement les multiples et les marges avec deux ou trois concurrents directs.',
      );
    }

    return items.take(5).toList();
  }

  static String _categoryChecklist(String categoryId) {
    switch (categoryId) {
      case 'valuation':
        return 'Comparer le PER et le VE/EBITDA aux pairs du secteur avant de conclure sur la valorisation.';
      case 'growth':
        return 'Valider si le ralentissement du chiffre d’affaires ou du BPA est conjoncturel ou structurel.';
      case 'profitability':
        return 'Contrôler la soutenabilité des marges EBIT et du free cash-flow sur plusieurs exercices.';
      case 'balanceSheet':
        return 'Analyser la structure de dette, les covenants éventuels et la capacité de remboursement.';
      case 'distribution':
        return 'Vérifier que le dividende reste couvert par les bénéfices et la génération de cash.';
      default:
        return 'Compléter l’analyse qualitative avec le rapport annuel et la note de gestion.';
    }
  }

  static String _formatMetricValue(String metricId, double? value) {
    if (value == null) return 'Donnée indisponible';
    switch (metricId) {
      case 'trailingPe':
      case 'enterpriseToEbitda':
      case 'debtToEbitda':
      case 'cashToDebtRatio':
        if (value.isInfinite) return 'Net cash';
        return '${value.toStringAsFixed(1)}x';
      case 'returnOnEquity':
      case 'ebitMargin':
      case 'freeCashflowYield':
      case 'payoutRatio':
      case 'revenueCagr3y':
      case 'epsCagr3y':
        return '${(value * 100).toStringAsFixed(1)} %';
      case 'dividendStability':
        if (value >= 1) return 'Croissant sur 5 ans';
        if (value >= 0.75) return 'Plutôt stable';
        if (value >= 0.5) return 'Stable mais inégal';
        if (value > 0) return 'Historique fragile';
        return 'Instable';
      default:
        return value.toStringAsFixed(2);
    }
  }

  static String? _metricNote(String metricId) {
    switch (metricId) {
      case 'revenueCagr3y':
      case 'epsCagr3y':
        return 'Calculé en CAGR sur 3 ans.';
      case 'dividendStability':
        return 'Basé sur les 5 dernières années civiles complètes.';
      default:
        return null;
    }
  }
}

class _MetricInput {
  const _MetricInput(this.metricId, this.rawValue);

  final String metricId;
  final double? rawValue;
}

class _DerivedMetrics {
  const _DerivedMetrics({
    required this.revenueCagr3y,
    required this.epsCagr3y,
    required this.ebitMargin,
    required this.normalizedDebtToEbitda,
    required this.cashToDebtRatio,
    required this.netDebt,
    required this.dividendStability,
    required this.hasRecentDividend,
    required this.hasFiveYearDividendHistory,
    required this.hasNetCash,
  });

  final double? revenueCagr3y;
  final double? epsCagr3y;
  final double? ebitMargin;
  final double? normalizedDebtToEbitda;
  final double? cashToDebtRatio;
  final double? netDebt;
  final double? dividendStability;
  final bool hasRecentDividend;
  final bool hasFiveYearDividendHistory;
  final bool hasNetCash;

  factory _DerivedMetrics.fromData(FundamentalGameData data) {
    final revenueCagr3y = _computeCagr(data.revenueHistory, years: 3);
    final epsCagr3y = _computeCagr(data.epsHistory, years: 3);
    final ebitMargin =
        data.operatingMargin ??
        _computeMargin(ebit: data.ebit, revenue: data.revenue);
    final normalizedDebtToEbitda = _normalizeDebtToEbitda(
      debtToEbitda: data.debtToEbitda,
      totalDebt: data.totalDebt,
      totalCash: data.totalCash,
      ebitda: data.snapshot.ebitda,
    );
    final dividendMetrics = _computeDividendMetrics(data.dividendPerYear);
    final netDebt = data.netDebt;

    return _DerivedMetrics(
      revenueCagr3y: revenueCagr3y,
      epsCagr3y: epsCagr3y,
      ebitMargin: ebitMargin,
      normalizedDebtToEbitda: normalizedDebtToEbitda,
      cashToDebtRatio: data.cashToDebtRatio,
      netDebt: netDebt,
      dividendStability: dividendMetrics.stabilityScore,
      hasRecentDividend: dividendMetrics.hasRecentDividend,
      hasFiveYearDividendHistory: dividendMetrics.hasFiveYearHistory,
      hasNetCash: netDebt != null && netDebt < 0,
    );
  }

  Map<String, double> toBadgeFeatures(FundamentalGameData data) {
    return <String, double>{
      if (netDebt != null) 'netDebt': netDebt!,
      if (data.freeCashflowYield != null)
        'freeCashflowYield': data.freeCashflowYield!,
      if (data.enterpriseToEbitda != null)
        'enterpriseToEbitda': data.enterpriseToEbitda!,
      if (data.trailingPe != null) 'trailingPe': data.trailingPe!,
      if (epsCagr3y != null) 'epsCagr3y': epsCagr3y!,
      if (dividendStability != null) 'dividendStability': dividendStability!,
      'hasDividendFiveYears': hasFiveYearDividendHistory ? 1 : 0,
    };
  }

  static double? _computeMargin({
    required double? ebit,
    required double? revenue,
  }) {
    if (ebit == null || revenue == null || revenue.abs() < 1e-9) return null;
    return ebit / revenue;
  }

  static double? _normalizeDebtToEbitda({
    required double? debtToEbitda,
    required double? totalDebt,
    required double? totalCash,
    required double? ebitda,
  }) {
    if (totalDebt != null && totalCash != null) {
      final netDebt = totalDebt - totalCash;
      if (netDebt <= 0) return 0;
      if (ebitda == null || ebitda <= 0) return 10;
      return netDebt / ebitda;
    }
    if (debtToEbitda != null) return debtToEbitda;
    if (totalDebt == null) return null;
    if (totalDebt <= 0) return 0;
    if (ebitda == null || ebitda <= 0) return 10;
    return totalDebt / ebitda;
  }

  static double? _computeCagr(
    List<YearlyMetricValue> series, {
    required int years,
  }) {
    if (series.length < years + 1) return null;
    final ordered = [...series]..sort((a, b) => a.year.compareTo(b.year));
    final window = ordered.sublist(ordered.length - (years + 1));
    final start = window.first.value;
    final end = window.last.value;
    if (start <= 0 || end <= 0) return null;
    return math.pow(end / start, 1 / years).toDouble() - 1;
  }

  static _DividendMetrics _computeDividendMetrics(Map<int, double> dividends) {
    final now = DateTime.now();
    final lastCompleteYear = now.year - 1;
    final years = List<int>.generate(
      5,
      (index) => lastCompleteYear - 4 + index,
    );
    final values = years.map((year) => dividends[year] ?? 0).toList();
    final hasRecentDividend = values.any((value) => value > 0);
    final hasFiveYearHistory = values.every((value) => value > 0);

    if (!hasRecentDividend) {
      return const _DividendMetrics(
        stabilityScore: null,
        hasRecentDividend: false,
        hasFiveYearHistory: false,
      );
    }

    var nonDecreasingSteps = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i - 1] > 0 && values[i] >= values[i - 1]) {
        nonDecreasingSteps++;
      }
    }

    double score;
    if (hasFiveYearHistory && nonDecreasingSteps == values.length - 1) {
      score = 1;
    } else if (hasFiveYearHistory && nonDecreasingSteps >= values.length - 2) {
      score = 0.75;
    } else if (values.where((value) => value > 0).length >= 3) {
      score = 0.5;
    } else {
      score = 0.25;
    }

    return _DividendMetrics(
      stabilityScore: score,
      hasRecentDividend: true,
      hasFiveYearHistory: hasFiveYearHistory,
    );
  }
}

class _DividendMetrics {
  const _DividendMetrics({
    required this.stabilityScore,
    required this.hasRecentDividend,
    required this.hasFiveYearHistory,
  });

  final double? stabilityScore;
  final bool hasRecentDividend;
  final bool hasFiveYearHistory;
}
