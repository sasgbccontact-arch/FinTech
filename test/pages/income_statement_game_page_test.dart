import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintech/pages/income_statement_game_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stock Analyst helpers', () {
    test('génère un dayKey local sur 8 chiffres', () {
      expect(stockAnalystDayKey(DateTime(2026, 3, 9)), '20260309');
      expect(stockAnalystDayKey(DateTime(2026, 11, 13)), '20261113');
    });

    test('formate le cooldown local en JJ/MM/AA', () {
      expect(stockAnalystLocalCooldownLabel('20260313'), '13/03/26');
    });

    test('attribue le jackpot oracle pour un écart <= 5', () {
      final preview = stockAnalystRewardPreview(diff: 4, currentCoins: 120);

      expect(preview.rewardBand, 'jackpot');
      expect(preview.rewardCoins, 250);
      expect(preview.rewardGems, 8);
      expect(preview.penaltyCoins, 0);
      expect(preview.badgeKey, 'oracle');
      expect(preview.unlocksAchievement, isFalse);
      expect(preview.oracleHitCountAfterGuess, 1);
    });

    test('débloque Oracle fondamental au 20e jackpot parfait', () {
      final preview = stockAnalystRewardPreview(
        diff: 3,
        currentCoins: 120,
        oracleHitCount: 19,
      );

      expect(preview.rewardBand, 'jackpot');
      expect(preview.unlocksAchievement, isTrue);
      expect(preview.oracleHitCountAfterGuess, 20);
    });

    test('applique un malus plafonné au solde courant', () {
      final preview = stockAnalystRewardPreview(diff: 31, currentCoins: 12);

      expect(preview.rewardBand, 'miss');
      expect(preview.rewardCoins, 0);
      expect(preview.rewardGems, 0);
      expect(preview.penaltyCoins, 12);
      expect(preview.badgeKey, isNull);
    });

    test('rehydrate correctement une tentative Firestore', () {
      final debug = stockAnalystGuessDebugMap(<String, dynamic>{
        'symbol': 'aapl',
        'companyName': 'Apple',
        'guess': 61,
        'actual': 66,
        'diff': 5,
        'rewardBand': 'jackpot',
        'rewardCoins': 250,
        'rewardGems': 8,
        'penaltyCoins': 0,
        'badgeKey': 'oracle',
        'qualitySummary': '5 catégorie(s) exploitables',
        'verdict': 'Bonne',
        'dayKey': '20260313',
        'oracleHitCount': 12,
        'achievementUnlocked': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 13, 9, 30)),
      });

      expect(debug['symbol'], 'AAPL');
      expect(debug['companyName'], 'Apple');
      expect(debug['guess'], 61);
      expect(debug['actual'], 66);
      expect(debug['diff'], 5);
      expect(debug['badgeKey'], 'oracle');
      expect(debug['dayKey'], '20260313');
      expect(debug['oracleHitCount'], 12);
      expect(debug['achievementUnlocked'], isFalse);
    });

    test('choisit un ticker jouable et riche parmi les meilleurs profils', () {
      final picked =
          stockAnalystPickCandidateSymbol(const <StockAnalystCandidateProbe>[
            StockAnalystCandidateProbe(
              symbol: 'AAA',
              playable: false,
              missingDataCount: 0,
              activeCategoryCount: 5,
              metricCount: 20,
            ),
            StockAnalystCandidateProbe(
              symbol: 'BBB',
              playable: true,
              missingDataCount: 3,
              activeCategoryCount: 4,
              metricCount: 14,
            ),
            StockAnalystCandidateProbe(
              symbol: 'CCC',
              playable: true,
              missingDataCount: 1,
              activeCategoryCount: 5,
              metricCount: 18,
            ),
          ], seed: 7);

      expect(picked, 'CCC');
    });
  });

  group('StockAnalystUiPreview', () {
    Future<void> openResultsTab(WidgetTester tester) async {
      await tester.tap(find.text('Résultat'));
      await tester.pumpAndSettle();
    }

    testWidgets('affiche la carte slider avec le CTA de reveal', (
      tester,
    ) async {
      await tester.pumpWidget(const StockAnalystUiPreview());
      await openResultsTab(tester);

      expect(find.text('Ton estimation'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Révéler mon score (48)'),
        findsOneWidget,
      );
    });

    testWidgets('bascule entre état masqué et état révélé', (tester) async {
      await tester.pumpWidget(const StockAnalystUiPreview());
      await openResultsTab(tester);
      expect(find.text('Score verrouillé'), findsOneWidget);
      expect(find.text('Score révélé'), findsNothing);

      await tester.pumpWidget(
        const StockAnalystUiPreview(
          revealed: true,
          initialGuess: 62,
          actualScore: 67,
        ),
      );
      await tester.pumpAndSettle();
      await openResultsTab(tester);

      expect(find.text('Score révélé'), findsOneWidget);
      expect(find.textContaining('Écart 5 pts'), findsOneWidget);
    });

    testWidgets('montre le blocage déjà joué aujourd’hui', (tester) async {
      await tester.pumpWidget(
        const StockAnalystUiPreview(playedToday: true, revealed: true),
      );
      await tester.pumpAndSettle();
      await openResultsTab(tester);

      expect(find.textContaining('Déjà joué aujourd’hui'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Score révélé'), findsOneWidget);
    });

    testWidgets('affiche le tirage et les onglets du nouveau flow', (
      tester,
    ) async {
      await tester.pumpWidget(const StockAnalystUiPreview());

      expect(find.text('Métriques'), findsOneWidget);
      expect(find.text('Résultat'), findsOneWidget);
      expect(find.text('Méthode'), findsOneWidget);
      expect(find.text('Relancer un tirage'), findsOneWidget);
    });
  });
}
