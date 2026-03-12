import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/fundamental_game_models.dart';
import 'package:fintech/utils/fundamental_score_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildFundamentalScorePresentation', () {
    test('retourne un état scored pour une action avec analyse', () {
      final analysis = _buildAnalysis(
        finalScore: 82,
        verdict: 'Top pick',
        isInsufficientData: false,
        activeCategoryCount: 5,
        partialCategoryCount: 0,
        missingData: const <String>[],
      );
      final data = _buildData('EQUITY');

      final presentation = buildFundamentalScorePresentation(
        loading: false,
        error: null,
        data: data,
        analysis: analysis,
      );

      expect(presentation.state, FundamentalScoreHeroState.scored);
      expect(presentation.score, 82);
      expect(presentation.verdictLabel, 'Lecture élevée');
      expect(presentation.confidenceLabel, 'Confiance élevée');
      expect(presentation.summary, contains('Force'));
      expect(
        presentation.disclaimer,
        contains('Ceci n\'est pas un conseil en investissement'),
      );
      expect(presentation.canOpenDetails, isTrue);
    });

    test(
      'retourne une confiance limitée si les données sont insuffisantes',
      () {
        final analysis = _buildAnalysis(
          finalScore: 54,
          verdict: 'Moyenne',
          isInsufficientData: true,
          activeCategoryCount: 2,
          partialCategoryCount: 1,
          missingData: const <String>['Croissance du BPA (3 ans)'],
        );
        final data = _buildData('EQUITY');

        final presentation = buildFundamentalScorePresentation(
          loading: false,
          error: null,
          data: data,
          analysis: analysis,
        );

        expect(presentation.state, FundamentalScoreHeroState.scored);
        expect(presentation.confidenceLabel, 'Confiance limitée');
      },
    );

    test('retourne unavailable pour un ETF', () {
      final presentation = buildFundamentalScorePresentation(
        loading: false,
        error: null,
        data: _buildData('ETF'),
        analysis: null,
      );

      expect(presentation.state, FundamentalScoreHeroState.unavailable);
      expect(
        presentation.subtitle,
        'Lecture réservée aux actions opérationnelles',
      );
      expect(presentation.canOpenDetails, isFalse);
    });

    test('retourne error si le chargement fondamental échoue', () {
      final presentation = buildFundamentalScorePresentation(
        loading: false,
        error: 'Erreur de chargement',
        data: null,
        analysis: null,
      );

      expect(presentation.state, FundamentalScoreHeroState.error);
      expect(presentation.subtitle, 'Erreur de chargement');
    });
  });
}

FundamentalGameData _buildData(String quoteType) {
  return FundamentalGameData(
    symbol: 'TEST',
    companyName: 'Test Corp',
    exchange: 'NASDAQ',
    currency: 'USD',
    quoteType: quoteType,
    snapshot: const FinancialSnapshot(),
    revenueHistory: const <YearlyMetricValue>[],
    epsHistory: const <YearlyMetricValue>[],
    dividendPerYear: const <int, double>{},
  );
}

FundamentalAnalysisResult _buildAnalysis({
  required double finalScore,
  required String verdict,
  required bool isInsufficientData,
  required int activeCategoryCount,
  required int partialCategoryCount,
  required List<String> missingData,
}) {
  final subScores = <FundamentalSubScore>[
    const FundamentalSubScore(
      id: 'profitability',
      title: 'Rentabilité',
      weight: 20,
      score: 18,
      partial: false,
      metrics: <FundamentalMetricEvaluation>[],
      missingMetrics: <String>[],
    ),
    const FundamentalSubScore(
      id: 'valuation',
      title: 'Valorisation',
      weight: 20,
      score: 11,
      partial: false,
      metrics: <FundamentalMetricEvaluation>[],
      missingMetrics: <String>[],
    ),
  ];

  return FundamentalAnalysisResult(
    finalScore: finalScore,
    verdict: verdict,
    subScores: subScores,
    badges: const <FundamentalBadge>[],
    summaryLines: const <String>[],
    checklist: const <String>[],
    missingData: missingData,
    activeCategoryCount: activeCategoryCount,
    partialCategoryCount: partialCategoryCount,
    isInsufficientData: isInsufficientData,
  );
}
