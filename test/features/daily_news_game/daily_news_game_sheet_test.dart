import 'package:fintech/features/daily_news_game/ui/daily_news_game_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NewsGameUiPreview', () {
    testWidgets('affiche les choix Sprint et Analyse', (tester) async {
      await tester.pumpWidget(const NewsGameUiPreview());

      expect(find.text('Mode Sprint'), findsOneWidget);
      expect(find.text('Mode Analyse'), findsOneWidget);
      expect(find.text('Deck du jour'), findsOneWidget);
    });

    testWidgets('affiche le rappel bullish bearish neutre', (tester) async {
      await tester.pumpWidget(const NewsGameUiPreview());

      expect(
        find.textContaining('Bullish : impact plutot favorable'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Neutre : effet limite ou mitige'),
        findsOneWidget,
      );
    });

    testWidgets('verrouille Sprint quand le deck est réduit', (tester) async {
      await tester.pumpWidget(const NewsGameUiPreview(deckReduced: true));

      expect(find.text('Verrouillé: deck réduit'), findsOneWidget);
      expect(find.text('2 cartes exploitables'), findsOneWidget);
    });

    testWidgets('bascule sur la carte de reveal', (tester) async {
      await tester.pumpWidget(const NewsGameUiPreview(revealed: true));
      await tester.pumpAndSettle();

      expect(find.text('Score révélé'), findsOneWidget);
      expect(find.text('Marché'), findsOneWidget);
      expect(find.text('Compréhension'), findsOneWidget);
    });
  });
}
