import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/fundamental_game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialSnapshot.fromQuoteSummary', () {
    test(
      'reconstruit les métriques de valorisation et de cashflow manquantes',
      () {
        final summary = <String, dynamic>{
          'price': <String, dynamic>{
            'marketCap': <String, dynamic>{'raw': 800.0},
            'quoteType': 'EQUITY',
          },
          'summaryDetail': <String, dynamic>{
            'trailingPE': <String, dynamic>{'raw': 22.5},
          },
          'defaultKeyStatistics': <String, dynamic>{
            'enterpriseValue': <String, dynamic>{'raw': 1200.0},
            'enterpriseToEbitda': <String, dynamic>{'raw': 8.5},
            'enterpriseToRevenue': <String, dynamic>{'raw': 2.1},
            'sharesOutstanding': <String, dynamic>{'raw': 100.0},
          },
          'incomeStatementHistory': <String, dynamic>{
            'incomeStatementHistory': <Map<String, dynamic>>[
              <String, dynamic>{
                'endDate': <String, dynamic>{'raw': _ts(2025)},
                'totalRevenue': <String, dynamic>{'raw': 1100.0},
                'netIncome': <String, dynamic>{'raw': 140.0},
              },
              <String, dynamic>{
                'endDate': <String, dynamic>{'raw': _ts(2024)},
                'totalRevenue': <String, dynamic>{'raw': 1000.0},
                'netIncome': <String, dynamic>{'raw': 120.0},
              },
            ],
          },
          'cashflowStatementHistory': <String, dynamic>{
            'cashflowStatements': <Map<String, dynamic>>[
              <String, dynamic>{
                'endDate': <String, dynamic>{'raw': _ts(2025)},
                'totalCashFromOperatingActivities': <String, dynamic>{
                  'raw': 200.0,
                },
                'capitalExpenditures': <String, dynamic>{'raw': -50.0},
              },
            ],
          },
        };

        final snapshot = FinancialSnapshot.fromQuoteSummary(summary);

        expect(snapshot.trailingPe, 22.5);
        expect(snapshot.enterpriseValue, 1200.0);
        expect(snapshot.enterpriseToEbitda, 8.5);
        expect(snapshot.enterpriseToRevenue, 2.1);
        expect(snapshot.freeCashflow, 150.0);
        expect(snapshot.freeCashflowYield, closeTo(0.1875, 0.000001));
        expect(snapshot.revenueGrowth, closeTo(0.1, 0.000001));
        expect(snapshot.earningsGrowth, closeTo(0.1666667, 0.000001));
      },
    );
  });

  group('FundamentalGameData.fromYahoo', () {
    test(
      'reconstruit l’historique EPS avec fallback sur sharesOutstanding',
      () {
        final summary = <String, dynamic>{
          'price': <String, dynamic>{
            'longName': 'Test Corp',
            'quoteType': 'EQUITY',
            'currency': 'USD',
          },
          'defaultKeyStatistics': <String, dynamic>{
            'sharesOutstanding': <String, dynamic>{'raw': 100.0},
          },
          'incomeStatementHistory': <String, dynamic>{
            'incomeStatementHistory': <Map<String, dynamic>>[
              <String, dynamic>{
                'endDate': <String, dynamic>{'raw': _ts(2025)},
                'totalRevenue': <String, dynamic>{'raw': 1100.0},
                'netIncome': <String, dynamic>{'raw': 140.0},
              },
              <String, dynamic>{
                'endDate': <String, dynamic>{'raw': _ts(2024)},
                'totalRevenue': <String, dynamic>{'raw': 1000.0},
                'netIncome': <String, dynamic>{'raw': 120.0},
              },
              <String, dynamic>{
                'endDate': <String, dynamic>{'raw': _ts(2023)},
                'totalRevenue': <String, dynamic>{'raw': 920.0},
                'netIncome': <String, dynamic>{'raw': 100.0},
              },
            ],
          },
        };

        final data = FundamentalGameData.fromYahoo(
          symbol: 'TEST',
          summary: summary,
          dividendPerYear: const <int, double>{},
          fallbackTrailingPe: 19.4,
        );

        expect(data.trailingPe, 19.4);
        expect(data.epsHistory, hasLength(3));
        expect(data.epsHistory.last.value, closeTo(1.4, 0.000001));
        expect(data.revenueHistory.last.value, 1100.0);
      },
    );
  });
}

int _ts(int year) => DateTime.utc(year, 12, 31).millisecondsSinceEpoch ~/ 1000;
