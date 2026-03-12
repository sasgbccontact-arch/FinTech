import '../models/fundamental_game_models.dart';

enum FundamentalScoreHeroState { loading, scored, unavailable, error }

class FundamentalScorePresentation {
  const FundamentalScorePresentation({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.verdictLabel,
    required this.confidenceLabel,
    required this.summary,
    required this.strongestSubScore,
    required this.weakestSubScore,
    required this.subScores,
    required this.missingData,
    required this.disclaimer,
    required this.canOpenDetails,
  });

  final FundamentalScoreHeroState state;
  final String title;
  final String subtitle;
  final double? score;
  final String? verdictLabel;
  final String? confidenceLabel;
  final String? summary;
  final FundamentalSubScore? strongestSubScore;
  final FundamentalSubScore? weakestSubScore;
  final List<FundamentalSubScore> subScores;
  final List<String> missingData;
  final String disclaimer;
  final bool canOpenDetails;
}

const String kFundamentalScoreDisclaimer =
    'Repère pédagogique calculé à partir de données publiques. Ceci n\'est pas un conseil en investissement.';

FundamentalScorePresentation buildFundamentalScorePresentation({
  required bool loading,
  required String? error,
  required FundamentalGameData? data,
  required FundamentalAnalysisResult? analysis,
}) {
  if (loading) {
    return const FundamentalScorePresentation(
      state: FundamentalScoreHeroState.loading,
      title: 'Note fondamentale',
      subtitle:
          'Repère informatif en préparation à partir des données actuelles et passées',
      score: null,
      verdictLabel: null,
      confidenceLabel: null,
      summary: null,
      strongestSubScore: null,
      weakestSubScore: null,
      subScores: <FundamentalSubScore>[],
      missingData: <String>[],
      disclaimer: kFundamentalScoreDisclaimer,
      canOpenDetails: false,
    );
  }

  if (error != null && error.trim().isNotEmpty) {
    return FundamentalScorePresentation(
      state: FundamentalScoreHeroState.error,
      title: 'Note fondamentale indisponible',
      subtitle: error.trim(),
      score: null,
      verdictLabel: null,
      confidenceLabel: null,
      summary: null,
      strongestSubScore: null,
      weakestSubScore: null,
      subScores: const <FundamentalSubScore>[],
      missingData: const <String>[],
      disclaimer: kFundamentalScoreDisclaimer,
      canOpenDetails: false,
    );
  }

  final isOperationalEquity =
      (data?.quoteType ?? '').trim().toUpperCase() == 'EQUITY';
  if (!isOperationalEquity) {
    return const FundamentalScorePresentation(
      state: FundamentalScoreHeroState.unavailable,
      title: 'Note fondamentale indisponible',
      subtitle: 'Lecture réservée aux actions opérationnelles',
      score: null,
      verdictLabel: null,
      confidenceLabel: null,
      summary: null,
      strongestSubScore: null,
      weakestSubScore: null,
      subScores: <FundamentalSubScore>[],
      missingData: <String>[],
      disclaimer: kFundamentalScoreDisclaimer,
      canOpenDetails: false,
    );
  }

  if (analysis == null) {
    return const FundamentalScorePresentation(
      state: FundamentalScoreHeroState.unavailable,
      title: 'Note fondamentale indisponible',
      subtitle: 'Données insuffisantes pour calculer une lecture fiable',
      score: null,
      verdictLabel: null,
      confidenceLabel: null,
      summary: null,
      strongestSubScore: null,
      weakestSubScore: null,
      subScores: <FundamentalSubScore>[],
      missingData: <String>[],
      disclaimer: kFundamentalScoreDisclaimer,
      canOpenDetails: false,
    );
  }

  final activeSubScores =
      analysis.subScores.where((entry) => entry.score != null).toList()
        ..sort((a, b) => b.score!.compareTo(a.score!));
  final strongest = activeSubScores.isEmpty ? null : activeSubScores.first;
  final weakest = activeSubScores.length < 2 ? null : activeSubScores.last;

  return FundamentalScorePresentation(
    state: FundamentalScoreHeroState.scored,
    title: 'Note fondamentale',
    subtitle:
        strongest == null
            ? 'Lecture quantitative de la qualité fondamentale'
            : _buildSummary(strongest, weakest),
    score: analysis.finalScore,
    verdictLabel: _neutralVerdictLabel(analysis.verdict),
    confidenceLabel: _confidenceLabel(analysis),
    summary: strongest == null ? null : _buildSummary(strongest, weakest),
    strongestSubScore: strongest,
    weakestSubScore: weakest,
    subScores: List<FundamentalSubScore>.unmodifiable(analysis.subScores),
    missingData: List<String>.unmodifiable(analysis.missingData),
    disclaimer: kFundamentalScoreDisclaimer,
    canOpenDetails: true,
  );
}

String _confidenceLabel(FundamentalAnalysisResult analysis) {
  if (analysis.isInsufficientData) return 'Confiance limitée';
  if (analysis.activeCategoryCount >= 5 &&
      analysis.partialCategoryCount == 0 &&
      analysis.missingData.length <= 2) {
    return 'Confiance élevée';
  }
  return 'Confiance moyenne';
}

String _neutralVerdictLabel(String verdict) {
  switch (verdict) {
    case 'Top pick':
      return 'Lecture élevée';
    case 'Bonne':
      return 'Lecture solide';
    case 'Moyenne':
      return 'Lecture mitigée';
    case 'À risque':
      return 'Lecture fragile';
    default:
      return 'Lecture informative';
  }
}

String _buildSummary(
  FundamentalSubScore strongest,
  FundamentalSubScore? weakest,
) {
  if (weakest == null) {
    return 'Force : ${strongest.title.toLowerCase()}';
  }
  return 'Force : ${strongest.title.toLowerCase()} • Vigilance : ${weakest.title.toLowerCase()}';
}
