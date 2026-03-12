import 'package:fintech/services/yahoo_finance_service.dart';
import 'package:fintech/utils/search_suggestion_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rankSearchSuggestions', () {
    test('fait remonter un ticker exact avant les noms ressemblants', () {
      final candidates = [
        _ticker(
          symbol: 'APLE',
          name: 'Apple Hospitality REIT',
          quoteType: 'EQUITY',
          exchange: 'NYSE',
          region: 'US',
        ),
        _ticker(
          symbol: 'AAPL',
          name: 'Apple Inc.',
          quoteType: 'EQUITY',
          exchange: 'NASDAQ',
          region: 'US',
        ),
      ];

      final ranked = rankSearchSuggestions(
        candidates: candidates,
        query: 'AAPL',
      );

      expect(ranked.first.symbol, 'AAPL');
    });

    test('fait remonter un nom evident meme sans ticker precis', () {
      final candidates = [
        _ticker(
          symbol: 'AI.PA',
          name: 'Air Liquide S.A.',
          quoteType: 'EQUITY',
          exchange: 'Paris',
          region: 'FR',
        ),
        _ticker(
          symbol: 'LQDT',
          name: 'Liquidity Services, Inc.',
          quoteType: 'EQUITY',
          exchange: 'NASDAQ',
          region: 'US',
        ),
      ];

      final ranked = rankSearchSuggestions(
        candidates: candidates,
        query: 'air liquide',
      );

      expect(ranked.first.symbol, 'AI.PA');
      expect(hasStrongSearchMatch(ranked, 'air liquide'), isTrue);
    });

    test('le filtre ETF priorise les ETF sans exclure les autres types', () {
      final candidates = [
        _ticker(
          symbol: 'MSCI',
          name: 'MSCI Inc.',
          quoteType: 'EQUITY',
          exchange: 'NYSE',
          region: 'US',
        ),
        _ticker(
          symbol: 'CW8.PA',
          name: 'Amundi MSCI World UCITS ETF',
          quoteType: 'ETF',
          exchange: 'Paris',
          region: 'FR',
        ),
        _ticker(
          symbol: 'IWDA.AS',
          name: 'iShares Core MSCI World UCITS ETF',
          quoteType: 'ETF',
          exchange: 'Amsterdam',
          region: 'NL',
        ),
        _ticker(
          symbol: 'WRLDX',
          name: 'Global World Opportunities Fund',
          quoteType: 'MUTUALFUND',
          exchange: 'NASDAQ',
          region: 'US',
        ),
      ];

      final ranked = rankSearchSuggestions(
        candidates: candidates,
        query: 'msci world',
        priority: SearchInstrumentPriority.etfs,
      );

      expect(ranked.first.isEtf, isTrue);
      expect(ranked[1].isEtf, isTrue);
      expect(ranked.any((result) => result.isEquity), isTrue);
      expect(ranked.any((result) => result.isMutualFund), isTrue);
    });

    test('le filtre Actions garde les ETF visibles mais apres les actions', () {
      final candidates = [
        _ticker(
          symbol: 'AAPL',
          name: 'Apple Inc.',
          quoteType: 'EQUITY',
          exchange: 'NASDAQ',
          region: 'US',
        ),
        _ticker(
          symbol: 'APLETF',
          name: 'Apple Innovation ETF',
          quoteType: 'ETF',
          exchange: 'NYSEARCA',
          region: 'US',
        ),
        _ticker(
          symbol: '^AAPLX',
          name: 'Apple Composite Index',
          quoteType: 'INDEX',
          exchange: 'SNP',
          region: 'US',
        ),
      ];

      final ranked = rankSearchSuggestions(
        candidates: candidates,
        query: 'apple',
        priority: SearchInstrumentPriority.equities,
      );

      expect(ranked.first.isEquity, isTrue);
      expect(ranked.any((result) => result.isEtf), isTrue);
      expect(ranked.any((result) => result.isIndex), isTrue);
    });

    test('par defaut une action francaise remonte avant les ETF et fonds', () {
      final candidates = [
        _ticker(
          symbol: 'BNP.PA',
          name: 'BNP Paribas SA',
          quoteType: 'EQUITY',
          exchange: 'Paris',
          region: 'FR',
        ),
        _ticker(
          symbol: 'ESE.PA',
          name: 'BNP Paribas Easy S&P 500 UCITS ETF',
          quoteType: 'ETF',
          exchange: 'Paris',
          region: 'FR',
        ),
        _ticker(
          symbol: 'BNPIF',
          name: 'BNP Paribas Growth Fund',
          quoteType: 'MUTUALFUND',
          exchange: 'NASDAQ',
          region: 'US',
        ),
      ];

      final ranked = rankSearchSuggestions(
        candidates: candidates,
        query: 'BNP',
        priority: SearchInstrumentPriority.equities,
      );

      expect(ranked.first.symbol, 'BNP.PA');
      expect(ranked.any((result) => result.isEtf), isTrue);
      expect(ranked.any((result) => result.isMutualFund), isTrue);
    });

    test('le filtre Fonds remonte les fonds sans masquer les actions', () {
      final candidates = [
        _ticker(
          symbol: 'BNP.PA',
          name: 'BNP Paribas SA',
          quoteType: 'EQUITY',
          exchange: 'Paris',
          region: 'FR',
        ),
        _ticker(
          symbol: 'BNPIF',
          name: 'BNP Paribas Growth Fund',
          quoteType: 'MUTUALFUND',
          exchange: 'NASDAQ',
          region: 'US',
        ),
        _ticker(
          symbol: 'ESE.PA',
          name: 'BNP Paribas Easy S&P 500 UCITS ETF',
          quoteType: 'ETF',
          exchange: 'Paris',
          region: 'FR',
        ),
      ];

      final ranked = rankSearchSuggestions(
        candidates: candidates,
        query: 'BNP',
        priority: SearchInstrumentPriority.funds,
      );

      expect(ranked.first.isMutualFund, isTrue);
      expect(ranked.any((result) => result.isEquity), isTrue);
    });
  });
}

TickerSearchResult _ticker({
  required String symbol,
  required String name,
  required String quoteType,
  required String exchange,
  required String region,
}) {
  return TickerSearchResult(
    symbol: symbol,
    displayName: name,
    exchange: exchange,
    quoteType: quoteType,
    region: region,
    currency: 'USD',
    yahooScore: 12,
  );
}
