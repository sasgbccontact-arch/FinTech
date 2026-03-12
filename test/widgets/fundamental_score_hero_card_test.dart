import 'package:fintech/models/fundamental_game_models.dart';
import 'package:fintech/utils/fundamental_score_presenter.dart';
import 'package:fintech/widgets/fundamental_score_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche et anime un score fondamental', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FundamentalScoreHeroCard(
            presentation: _scoredPresentation(),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Note fondamentale'), findsOneWidget);
    expect(find.text('Lecture élevée'), findsOneWidget);
    expect(
      find.textContaining('Ceci n\'est pas un conseil en investissement'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('82/100'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(FundamentalScoreHeroCard));
    expect(tapped, isTrue);
  });

  testWidgets('affiche un état indisponible pour un instrument non éligible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FundamentalScoreHeroCard(
            presentation: FundamentalScorePresentation(
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
            ),
          ),
        ),
      ),
    );

    expect(find.text('Note fondamentale indisponible'), findsOneWidget);
    expect(
      find.text('Lecture réservée aux actions opérationnelles'),
      findsOneWidget,
    );
  });
}

FundamentalScorePresentation _scoredPresentation() {
  return const FundamentalScorePresentation(
    state: FundamentalScoreHeroState.scored,
    title: 'Note fondamentale',
    subtitle: 'Force : rentabilité • Vigilance : valorisation',
    score: 82,
    verdictLabel: 'Lecture élevée',
    confidenceLabel: 'Confiance élevée',
    summary: 'Force : rentabilité • Vigilance : valorisation',
    strongestSubScore: FundamentalSubScore(
      id: 'profitability',
      title: 'Rentabilité',
      weight: 20,
      score: 18,
      partial: false,
      metrics: <FundamentalMetricEvaluation>[],
      missingMetrics: <String>[],
    ),
    weakestSubScore: FundamentalSubScore(
      id: 'valuation',
      title: 'Valorisation',
      weight: 20,
      score: 11,
      partial: false,
      metrics: <FundamentalMetricEvaluation>[],
      missingMetrics: <String>[],
    ),
    subScores: <FundamentalSubScore>[],
    missingData: <String>[],
    disclaimer: kFundamentalScoreDisclaimer,
    canOpenDetails: true,
  );
}
