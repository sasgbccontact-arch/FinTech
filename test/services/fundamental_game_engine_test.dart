import 'dart:convert';
import 'dart:io';

import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/fundamental_game_models.dart';
import 'package:fintech/services/fundamental_game_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FundamentalGameConfig config;

  setUpAll(() {
    final raw = File('assets/fundamental_game_config.json').readAsStringSync();
    config = FundamentalGameConfig.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  });

  group('FundamentalGameEngine.analyze', () {
    test('attribue un verdict Top pick et les badges attendus', () {
      final data = _buildData(
        trailingPe: 8,
        enterpriseToEbitda: 5,
        returnOnEquity: 0.24,
        operatingMargin: 0.22,
        freeCashflowYield: 0.06,
        totalCash: 600,
        totalDebt: 100,
        debtToEbitda: 0.5,
        payoutRatio: 0.45,
        revenueHistory: _history([100, 120, 145, 180]),
        epsHistory: _history([1.0, 1.25, 1.55, 1.95]),
        dividendPerYear: _dividendHistory([0.8, 0.9, 1.0, 1.1, 1.2]),
      );

      final result = FundamentalGameEngine.analyze(data: data, config: config);

      expect(result.verdict, 'Top pick');
      expect(result.finalScore, isNotNull);
      expect(result.finalScore!, greaterThanOrEqualTo(80));
      expect(
        result.badges.map((badge) => badge.id),
        containsAll(<String>[
          'netCash',
          'highYield',
          'deepValue',
          'growth',
          'dividendKing',
        ]),
      );
    });

    test('renormalise le score quand la distribution est N/A', () {
      final data = _buildData(
        trailingPe: 14,
        enterpriseToEbitda: 9,
        returnOnEquity: 0.16,
        operatingMargin: 0.14,
        freeCashflowYield: 0.03,
        totalCash: 180,
        totalDebt: 220,
        debtToEbitda: 2.2,
        payoutRatio: null,
        revenueHistory: _history([100, 108, 118, 128]),
        epsHistory: _history([1.0, 1.05, 1.12, 1.2]),
        dividendPerYear: const <int, double>{},
      );

      final result = FundamentalGameEngine.analyze(data: data, config: config);
      final distribution = result.subScores.firstWhere(
        (subScore) => subScore.id == 'distribution',
      );

      expect(distribution.score, isNull);
      expect(result.activeCategoryCount, 4);
      expect(result.finalScore, isNotNull);
      expect(result.finalScore!, inInclusiveRange(0, 100));
    });

    test('marque la croissance comme partielle quand le BPA manque', () {
      final data = _buildData(
        trailingPe: 16,
        enterpriseToEbitda: 11,
        returnOnEquity: 0.15,
        operatingMargin: 0.13,
        freeCashflowYield: 0.025,
        totalCash: 120,
        totalDebt: 180,
        debtToEbitda: 2.8,
        payoutRatio: 0.5,
        revenueHistory: _history([100, 112, 123, 136]),
        epsHistory: const <YearlyMetricValue>[],
        dividendPerYear: _dividendHistory([0.5, 0.5, 0.55, 0.55, 0.6]),
      );

      final result = FundamentalGameEngine.analyze(data: data, config: config);
      final growth = result.subScores.firstWhere(
        (subScore) => subScore.id == 'growth',
      );

      expect(growth.score, isNotNull);
      expect(growth.partial, isTrue);
      expect(result.missingData, contains('Croissance du BPA (3 ans)'));
      expect(result.badges.map((badge) => badge.id), isNot(contains('growth')));
    });

    test('retourne un verdict À risque sur un profil faible', () {
      final data = _buildData(
        trailingPe: 38,
        enterpriseToEbitda: 18,
        returnOnEquity: 0.01,
        operatingMargin: 0.02,
        freeCashflowYield: -0.01,
        totalCash: 40,
        totalDebt: 400,
        debtToEbitda: 5.5,
        payoutRatio: 1.3,
        revenueHistory: _history([150, 140, 130, 115]),
        epsHistory: _history([2.0, 1.8, 1.4, 1.1]),
        dividendPerYear: _dividendHistory([0.8, 0.7, 0.5, 0.3, 0.2]),
      );

      final result = FundamentalGameEngine.analyze(data: data, config: config);

      expect(result.verdict, 'À risque');
      expect(result.finalScore, isNotNull);
      expect(result.finalScore!, lessThan(40));
    });
  });
}

FundamentalGameData _buildData({
  required double trailingPe,
  required double enterpriseToEbitda,
  required double returnOnEquity,
  required double operatingMargin,
  required double freeCashflowYield,
  required double totalCash,
  required double totalDebt,
  required double debtToEbitda,
  required double? payoutRatio,
  required List<YearlyMetricValue> revenueHistory,
  required List<YearlyMetricValue> epsHistory,
  required Map<int, double> dividendPerYear,
}) {
  final latestRevenue =
      revenueHistory.isEmpty ? 100.0 : revenueHistory.last.value;
  final ebit = latestRevenue * operatingMargin;

  return FundamentalGameData(
    symbol: 'TEST',
    companyName: 'Test Corp',
    exchange: 'NASDAQ',
    currency: 'USD',
    quoteType: 'EQUITY',
    snapshot: FinancialSnapshot(
      revenue: latestRevenue,
      ebit: ebit,
      ebitda: debtToEbitda > 0 ? totalDebt / debtToEbitda : null,
      operatingMargin: operatingMargin,
      freeCashflowYield: freeCashflowYield,
      returnOnEquity: returnOnEquity,
      trailingPe: trailingPe,
      enterpriseToEbitda: enterpriseToEbitda,
      payoutRatio: payoutRatio,
      totalCash: totalCash,
      totalDebt: totalDebt,
      debtToEbitda: debtToEbitda,
      freeCashflow: latestRevenue * freeCashflowYield,
    ),
    revenueHistory: revenueHistory,
    epsHistory: epsHistory,
    dividendPerYear: dividendPerYear,
  );
}

List<YearlyMetricValue> _history(List<double> values) {
  final lastYear = DateTime.now().year - 1;
  final startYear = lastYear - values.length + 1;
  return List<YearlyMetricValue>.generate(
    values.length,
    (index) => YearlyMetricValue(year: startYear + index, value: values[index]),
  );
}

Map<int, double> _dividendHistory(List<double> values) {
  final lastYear = DateTime.now().year - 1;
  final startYear = lastYear - values.length + 1;
  return <int, double>{
    for (var index = 0; index < values.length; index++)
      startYear + index: values[index],
  };
}
