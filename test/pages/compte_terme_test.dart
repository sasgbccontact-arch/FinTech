import 'package:fintech/pages/compte_terme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TermDepositUiPreview', () {
    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text(label)),
      );
      await tester.pumpAndSettle();
    }

    Finder verticalScrollable(String storageKey) {
      return find
          .descendant(
            of: find.byKey(PageStorageKey<String>(storageKey)),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;
    }

    testWidgets('rend le cockpit et la courbe des taux', (tester) async {
      await tester.pumpWidget(const TermDepositUiPreview());
      await tester.pumpAndSettle();

      expect(find.text('Cockpit de trésorerie'), findsOneWidget);
      expect(find.text('Vue'), findsOneWidget);
      expect(find.text('Offres'), findsOneWidget);
      await openTab(tester, 'Offres');
      expect(find.text('Mini yield curve'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Board du jour'),
        220,
        scrollable: verticalScrollable('treasury-tab-offers'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Board du jour'), findsOneWidget);
    });

    testWidgets('affiche une alerte quand la liquidité est tendue', (
      tester,
    ) async {
      await tester.pumpWidget(const TermDepositUiPreview(lowLiquidity: true));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Trésorerie tendue'),
        220,
        scrollable: verticalScrollable('treasury-tab-overview'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Trésorerie tendue'), findsOneWidget);
    });

    testWidgets('affiche les coûts premium et le CTA de slot', (tester) async {
      await tester.pumpWidget(const TermDepositUiPreview(premiumLocked: true));
      await tester.pumpAndSettle();

      await openTab(tester, 'Pilotage');

      expect(find.text('Débloquer slot 3'), findsWidgets);
      expect(find.text('60 gems'), findsOneWidget);
      expect(find.text('130 pts saison'), findsOneWidget);
    });

    testWidgets('affiche le debrief précédent quand il est fourni', (
      tester,
    ) async {
      await tester.pumpWidget(const TermDepositUiPreview(showDebrief: true));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Debrief précédent board'),
        220,
        scrollable: verticalScrollable('treasury-tab-overview'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Debrief précédent board'), findsOneWidget);
    });
  });
}
