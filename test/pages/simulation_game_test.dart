import 'package:fintech/pages/simulation_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScenarioGameUiPreview', () {
    Future<void> scrollToText(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('affiche l’état plan initial seedé', (tester) async {
      await tester.pumpWidget(const ScenarioGameUiPreview(previewStage: 1));
      await tester.pumpAndSettle();

      expect(find.text('Plan initial'), findsAtLeastNWidgets(1));
      expect(find.text('Agressif'), findsOneWidget);
      expect(find.text('Équilibré'), findsOneWidget);
      await scrollToText(tester, 'Défensif');
      expect(find.text('Défensif'), findsOneWidget);
    });

    testWidgets('affiche le glossaire débutant dans le briefing', (
      tester,
    ) async {
      await tester.pumpWidget(const ScenarioGameUiPreview());
      await tester.pumpAndSettle();

      await scrollToText(tester, 'Glossaire rapide');
      expect(find.text('Glossaire rapide'), findsOneWidget);
      expect(find.textContaining('Pourquoi'), findsWidgets);
    });

    testWidgets('affiche l’état acte seedé', (tester) async {
      await tester.pumpWidget(const ScenarioGameUiPreview(previewStage: 2));
      await tester.pumpAndSettle();

      await scrollToText(tester, 'Info de marché');
      expect(find.text('Info de marché'), findsOneWidget);
      expect(find.text('Décision'), findsOneWidget);
      await scrollToText(tester, 'Justification');
      expect(find.text('Justification'), findsOneWidget);
    });

    testWidgets('affiche le debrief final seedé', (tester) async {
      await tester.pumpWidget(const ScenarioGameUiPreview(previewStage: 3));
      await tester.pumpAndSettle();

      expect(find.text('Run terminé'), findsOneWidget);
      expect(find.text('Score multidimensionnel'), findsOneWidget);
      await scrollToText(tester, 'Journal de décision');
      expect(find.text('Journal de décision'), findsOneWidget);
    });

    testWidgets(
      'montre le mode entraînement quand le PnL réel du jour est consommé',
      (tester) async {
        await tester.pumpWidget(
          const ScenarioGameUiPreview(dailySettlementAvailable: false),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Mode entraînement'), findsWidgets);
        expect(
          find.textContaining('PnL réel du jour est déjà consommé'),
          findsOneWidget,
        );
      },
    );

    testWidgets('débloque les mutateurs après un premier clear', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ScenarioGameUiPreview(mutatorsUnlocked: true),
      );
      await tester.pumpAndSettle();

      await scrollToText(tester, 'Mode Expert');
      expect(find.text('Mode Expert'), findsOneWidget);
      expect(find.text('Volatilité renforcée'), findsOneWidget);
      expect(find.text('News contradictoires'), findsOneWidget);
    });
  });
}
