import 'financial_snapshot.dart';

enum FundamentalMetricDirection { higherIsBetter, lowerIsBetter }

class FundamentalCategoryConfig {
  const FundamentalCategoryConfig({
    required this.id,
    required this.title,
    required this.weight,
  });

  final String id;
  final String title;
  final double weight;

  factory FundamentalCategoryConfig.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return FundamentalCategoryConfig(
      id: id,
      title: (json['title'] ?? id).toString(),
      weight: _readDouble(json['weight']) ?? 20,
    );
  }
}

class FundamentalScoreBand {
  const FundamentalScoreBand({this.min, this.max, required this.score});

  final double? min;
  final double? max;
  final double score;

  factory FundamentalScoreBand.fromJson(Map<String, dynamic> json) {
    return FundamentalScoreBand(
      min: _readDouble(json['min']),
      max: _readDouble(json['max']),
      score: _readDouble(json['score']) ?? 0,
    );
  }

  bool matches(double value) {
    final meetsMin = min == null || value >= min!;
    final meetsMax = max == null || value <= max!;
    return meetsMin && meetsMax;
  }
}

class FundamentalMetricRule {
  const FundamentalMetricRule({
    required this.id,
    required this.label,
    required this.direction,
    required this.bands,
  });

  final String id;
  final String label;
  final FundamentalMetricDirection direction;
  final List<FundamentalScoreBand> bands;

  factory FundamentalMetricRule.fromJson(String id, Map<String, dynamic> json) {
    final directionRaw =
        (json['direction'] ?? 'higher_is_better').toString().trim();
    final rawBands = _asList(json['bands']);

    return FundamentalMetricRule(
      id: id,
      label: (json['label'] ?? id).toString(),
      direction:
          directionRaw == 'lower_is_better'
              ? FundamentalMetricDirection.lowerIsBetter
              : FundamentalMetricDirection.higherIsBetter,
      bands:
          rawBands
              .map((entry) => _asMap(entry))
              .whereType<Map<String, dynamic>>()
              .map(FundamentalScoreBand.fromJson)
              .toList(),
    );
  }

  double? scoreFor(double? value) {
    if (value == null || value.isNaN) return null;
    for (final band in bands) {
      if (band.matches(value)) return band.score.clamp(0, 20).toDouble();
    }
    return null;
  }
}

class FundamentalVerdictRule {
  const FundamentalVerdictRule({required this.label, this.min, this.max});

  final String label;
  final double? min;
  final double? max;

  factory FundamentalVerdictRule.fromJson(Map<String, dynamic> json) {
    return FundamentalVerdictRule(
      label: (json['label'] ?? '').toString(),
      min: _readDouble(json['min']),
      max: _readDouble(json['max']),
    );
  }

  bool matches(double score) {
    final meetsMin = min == null || score >= min!;
    final meetsMax = max == null || score < max!;
    return meetsMin && meetsMax;
  }
}

class FundamentalCondition {
  const FundamentalCondition({
    required this.metric,
    required this.operator,
    required this.value,
  });

  final String metric;
  final String operator;
  final double value;

  factory FundamentalCondition.fromJson(Map<String, dynamic> json) {
    return FundamentalCondition(
      metric: (json['metric'] ?? '').toString(),
      operator: (json['operator'] ?? 'gte').toString(),
      value: _readDouble(json['value']) ?? 0,
    );
  }

  bool matches(Map<String, double> features) {
    final current = features[metric];
    if (current == null) return false;
    switch (operator) {
      case 'lt':
        return current < value;
      case 'lte':
        return current <= value;
      case 'gt':
        return current > value;
      case 'gte':
        return current >= value;
      case 'eq':
        return current == value;
      default:
        return false;
    }
  }
}

class FundamentalBadgeRule {
  const FundamentalBadgeRule({
    required this.id,
    required this.label,
    required this.description,
    required this.conditions,
  });

  final String id;
  final String label;
  final String description;
  final List<FundamentalCondition> conditions;

  factory FundamentalBadgeRule.fromJson(String id, Map<String, dynamic> json) {
    final rawConditions = _asList(json['conditions']);
    return FundamentalBadgeRule(
      id: id,
      label: (json['label'] ?? id).toString(),
      description: (json['description'] ?? '').toString(),
      conditions:
          rawConditions
              .map((entry) => _asMap(entry))
              .whereType<Map<String, dynamic>>()
              .map(FundamentalCondition.fromJson)
              .toList(),
    );
  }

  bool matches(Map<String, double> features) {
    if (conditions.isEmpty) return false;
    return conditions.every((condition) => condition.matches(features));
  }
}

class FundamentalGameConfig {
  const FundamentalGameConfig({
    required this.categories,
    required this.metrics,
    required this.verdicts,
    required this.badges,
    required this.netCashBonus,
  });

  final Map<String, FundamentalCategoryConfig> categories;
  final Map<String, FundamentalMetricRule> metrics;
  final List<FundamentalVerdictRule> verdicts;
  final Map<String, FundamentalBadgeRule> badges;
  final double netCashBonus;

  factory FundamentalGameConfig.fromJson(Map<String, dynamic> json) {
    final rawCategories = _asMap(json['categories']) ?? const {};
    final rawMetrics = _asMap(json['metrics']) ?? const {};
    final rawBadges = _asMap(json['badges']) ?? const {};
    final rawVerdicts = _asList(json['verdicts']);
    final bonuses = _asMap(json['bonuses']) ?? const {};

    return FundamentalGameConfig(
      categories: Map.unmodifiable(
        rawCategories.map((key, value) {
          final item = _asMap(value) ?? const <String, dynamic>{};
          return MapEntry(key, FundamentalCategoryConfig.fromJson(key, item));
        }),
      ),
      metrics: Map.unmodifiable(
        rawMetrics.map((key, value) {
          final item = _asMap(value) ?? const <String, dynamic>{};
          return MapEntry(key, FundamentalMetricRule.fromJson(key, item));
        }),
      ),
      verdicts: List.unmodifiable(
        rawVerdicts
            .map((entry) => _asMap(entry))
            .whereType<Map<String, dynamic>>()
            .map(FundamentalVerdictRule.fromJson),
      ),
      badges: Map.unmodifiable(
        rawBadges.map((key, value) {
          final item = _asMap(value) ?? const <String, dynamic>{};
          return MapEntry(key, FundamentalBadgeRule.fromJson(key, item));
        }),
      ),
      netCashBonus: _readDouble(bonuses['netCashBonus']) ?? 2,
    );
  }
}

class YearlyMetricValue {
  const YearlyMetricValue({required this.year, required this.value});

  final int year;
  final double value;
}

class FundamentalGameData {
  const FundamentalGameData({
    required this.symbol,
    required this.companyName,
    required this.exchange,
    required this.currency,
    required this.quoteType,
    required this.snapshot,
    required this.revenueHistory,
    required this.epsHistory,
    required this.dividendPerYear,
  });

  final String symbol;
  final String? companyName;
  final String? exchange;
  final String? currency;
  final String? quoteType;
  final FinancialSnapshot snapshot;
  final List<YearlyMetricValue> revenueHistory;
  final List<YearlyMetricValue> epsHistory;
  final Map<int, double> dividendPerYear;

  bool get isEquity => (quoteType ?? '').toUpperCase() == 'EQUITY';

  double? get trailingPe => snapshot.trailingPe;
  double? get enterpriseToEbitda => snapshot.enterpriseToEbitda;
  double? get returnOnEquity => snapshot.returnOnEquity;
  double? get ebit => snapshot.ebit;
  double? get operatingMargin => snapshot.operatingMargin;
  double? get freeCashflowYield => snapshot.freeCashflowYield;
  double? get debtToEbitda => snapshot.debtToEbitda;
  double? get payoutRatio => snapshot.payoutRatio;
  double? get totalCash => snapshot.totalCash;
  double? get totalDebt => snapshot.totalDebt;
  double? get revenue => snapshot.revenue;
  double? get netIncome => snapshot.netIncome;
  double? get freeCashflow => snapshot.freeCashflow;

  double? get netDebt {
    if (totalDebt == null || totalCash == null) return null;
    return totalDebt! - totalCash!;
  }

  double? get cashToDebtRatio {
    if (totalDebt == null || totalCash == null) return null;
    if (totalDebt! <= 0) {
      return totalCash! > 0 ? double.infinity : null;
    }
    return totalCash! / totalDebt!;
  }

  factory FundamentalGameData.fromYahoo({
    required String symbol,
    required Map<String, dynamic> summary,
    required Map<int, double> dividendPerYear,
  }) {
    final price = _asMap(summary['price']);
    final incomeStatementHistory = _asMap(summary['incomeStatementHistory']);
    final snapshot = FinancialSnapshot.fromQuoteSummary(summary);

    return FundamentalGameData(
      symbol: symbol,
      companyName:
          _readString(price?['longName']) ??
          _readString(price?['shortName']) ??
          symbol,
      exchange:
          _readString(price?['fullExchangeName']) ??
          _readString(price?['exchangeName']) ??
          _readString(price?['exchange']),
      currency:
          _readString(price?['currency']) ??
          _readString(price?['financialCurrency']),
      quoteType: _readString(price?['quoteType']),
      snapshot: snapshot,
      revenueHistory: _extractAnnualSeries(
        history: incomeStatementHistory,
        key: 'incomeStatementHistory',
        valueExtractor: (statement) => _readDouble(statement['totalRevenue']),
      ),
      epsHistory: _extractAnnualSeries(
        history: incomeStatementHistory,
        key: 'incomeStatementHistory',
        valueExtractor: _extractEpsFromStatement,
      ),
      dividendPerYear: Map.unmodifiable(Map<int, double>.from(dividendPerYear)),
    );
  }

  static List<YearlyMetricValue> _extractAnnualSeries({
    required Map<String, dynamic>? history,
    required String key,
    required double? Function(Map<String, dynamic>) valueExtractor,
  }) {
    if (history == null) return const <YearlyMetricValue>[];
    final statements = _asList(history[key]);
    final byYear = <int, double>{};

    for (final entry in statements) {
      final statement = _asMap(entry);
      if (statement == null) continue;
      final endDate = _readDate(statement['endDate']);
      final year = endDate?.year;
      final value = valueExtractor(statement);
      if (year == null || value == null) continue;
      byYear.putIfAbsent(year, () => value);
    }

    final results =
        byYear.entries
            .map(
              (entry) => YearlyMetricValue(year: entry.key, value: entry.value),
            )
            .toList()
          ..sort((a, b) => a.year.compareTo(b.year));
    return List.unmodifiable(results);
  }

  static double? _extractEpsFromStatement(Map<String, dynamic> statement) {
    final directKeys = [
      'dilutedEPS',
      'basicEPS',
      'reportedEPS',
      'epsActual',
      'normalizedDilutedEPS',
    ];
    for (final key in directKeys) {
      final value = _readDouble(statement[key]);
      if (value != null) return value;
    }

    final netIncome =
        _readDouble(statement['netIncomeApplicableToCommonShares']) ??
        _readDouble(statement['netIncome']);
    final shareCount =
        _readDouble(statement['dilutedAverageShares']) ??
        _readDouble(statement['basicAverageShares']) ??
        _readDouble(statement['weightedAverageShsOutDil']) ??
        _readDouble(statement['weightedAverageShsOut']);

    if (netIncome == null || shareCount == null || shareCount.abs() < 1e-9) {
      return null;
    }
    return netIncome / shareCount;
  }
}

class FundamentalMetricEvaluation {
  const FundamentalMetricEvaluation({
    required this.id,
    required this.label,
    required this.displayValue,
    required this.score,
    required this.isMissing,
    this.note,
    this.rawValue,
  });

  final String id;
  final String label;
  final String displayValue;
  final double? score;
  final bool isMissing;
  final String? note;
  final double? rawValue;
}

class FundamentalSubScore {
  const FundamentalSubScore({
    required this.id,
    required this.title,
    required this.weight,
    required this.score,
    required this.partial,
    required this.metrics,
    required this.missingMetrics,
    this.note,
  });

  final String id;
  final String title;
  final double weight;
  final double? score;
  final bool partial;
  final List<FundamentalMetricEvaluation> metrics;
  final List<String> missingMetrics;
  final String? note;

  bool get isNotAvailable => score == null;
}

class FundamentalBadge {
  const FundamentalBadge({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class FundamentalAnalysisResult {
  const FundamentalAnalysisResult({
    required this.finalScore,
    required this.verdict,
    required this.subScores,
    required this.badges,
    required this.summaryLines,
    required this.checklist,
    required this.missingData,
    required this.activeCategoryCount,
    required this.partialCategoryCount,
    required this.isInsufficientData,
  });

  final double? finalScore;
  final String verdict;
  final List<FundamentalSubScore> subScores;
  final List<FundamentalBadge> badges;
  final List<String> summaryLines;
  final List<String> checklist;
  final List<String> missingData;
  final int activeCategoryCount;
  final int partialCategoryCount;
  final bool isInsufficientData;

  String get qualitySummary {
    final segments = <String>['$activeCategoryCount catégorie(s) exploitables'];
    if (partialCategoryCount > 0) {
      segments.add('$partialCategoryCount partielle(s)');
    }
    if (missingData.isNotEmpty) {
      segments.add('${missingData.length} donnée(s) manquante(s)');
    }
    return segments.join(' • ');
  }
}

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', ''));
  if (value is Map<String, dynamic>) {
    final raw = value['raw'];
    if (raw is num) return raw.toDouble();
    final fmt = value['fmt'];
    if (fmt is String) {
      return double.tryParse(fmt.replaceAll(',', ''));
    }
  }
  return null;
}

String? _readString(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is Map<String, dynamic>) {
    final fmt = value['fmt'];
    if (fmt is String) {
      final trimmed = fmt.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
  }
  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? null : stringValue;
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
  if (value is String) return DateTime.tryParse(value);
  if (value is Map<String, dynamic>) {
    final raw = value['raw'];
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw.toInt() * 1000,
        isUtc: true,
      );
    }
    final fmt = value['fmt'];
    if (fmt is String) return DateTime.tryParse(fmt);
  }
  return null;
}
