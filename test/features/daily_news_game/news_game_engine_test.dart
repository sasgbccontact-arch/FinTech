import 'package:fintech/features/daily_news_game/models/news_article.dart';
import 'package:fintech/features/daily_news_game/models/news_game_models.dart';
import 'package:fintech/features/daily_news_game/services/news_game_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NewsGameEngine', () {
    test('nettoie les URLs et métadonnées brutes', () {
      final cleaned = sanitizeNewsGameText(
        'Market Live Updates https://foo.bar/story Reuters.com [LIVE]',
      );

      expect(cleaned, isNot(contains('http')));
      expect(cleaned.toLowerCase(), isNot(contains('reuters.com')));
      expect(cleaned, isNot(contains('[LIVE]')));
    });

    test('nettoie aussi le HTML et les entités résiduelles', () {
      final cleaned = sanitizeNewsGameText(
        '&lt;a href="https://foo.bar" target="_blank"&gt;Fed&lt;/a&gt; &amp; inflation',
      );

      expect(cleaned, isNot(contains('href')));
      expect(cleaned, isNot(contains('target')));
      expect(cleaned, isNot(contains('&lt;')));
      expect(cleaned, contains('Fed'));
      expect(cleaned, contains('inflation'));
    });

    test(
      'nettoie les fragments de metadata HTML visibles dans les sous-titres',
      () {
        final cleaned = sanitizeNewsGameText(
          'Fed outlook href="https://foo.bar" target="_blank" blank" color="#fff" /a /font style="font-size:12px" inflation',
        );

        expect(cleaned.toLowerCase(), isNot(contains('href')));
        expect(cleaned.toLowerCase(), isNot(contains('color=')));
        expect(cleaned.toLowerCase(), isNot(contains('/a')));
        expect(cleaned.toLowerCase(), isNot(contains('/font')));
        expect(cleaned.toLowerCase(), isNot(contains('style=')));
        expect(cleaned.toLowerCase(), isNot(contains('blank"')));
        expect(cleaned.toLowerCase(), isNot(contains('_blank')));
        expect(cleaned, contains('Fed'));
        expect(cleaned, contains('inflation'));
      },
    );

    test('nettoie aussi les decks réhydratés depuis Firestore', () {
      final item = NewsGameDeckItem.fromMap(<String, dynamic>{
        'articleId': 'article_1',
        'article':
            NewsArticle.fromRss(
              title: 'Fed keeps rates steady',
              url: 'https://example.com/fed',
              publishedAt: DateTime.now(),
              source: 'Reuters',
              snippet: 'Inflation and rates remain in focus.',
            ).toFirestore(),
        'displayTitle': 'Fed /a keeps rates steady',
        'displaySnippet':
            'Outlook href="https://foo.bar" target="_blank" blank" color="#fff" /font inflation',
        'region': 'États-Unis',
        'regionKey': 'us',
        'macroCategory': NewsMacroCategory.rates.key,
        'difficulty': NewsDifficulty.medium.key,
        'qualityScore': 80,
        'impactOptions': <Map<String, dynamic>>[
          const NewsImpactOption(
            id: 'rates',
            label: 'Taux',
            kind: NewsImpactKind.theme,
            expectedDirection: PredictionDirection.bearish,
            isExpectedTarget: true,
            explanation: 'Les taux réagissent.',
          ).toMap(),
        ],
        'causalChain': const <String>['Fed', 'Taux'],
        'comprehensionQuestions': <Map<String, dynamic>>[
          const NewsComprehensionQuestion(
            id: 'q1',
            prompt: 'Quel thème href="https://foo.bar" domine ?',
            choices: <String>['Taux', 'font color="#fff"', '/a'],
            correctIndex: 0,
            kind: NewsQuestionKind.theme,
            explanation: 'Les taux dominent.',
          ).toMap(),
        ],
        'debrief': 'Débrief /font cohérent',
        'rewardPotential': 120,
      });

      expect(item.displayTitle.toLowerCase(), isNot(contains('/a')));
      expect(item.displaySnippet.toLowerCase(), isNot(contains('href')));
      expect(item.displaySnippet.toLowerCase(), isNot(contains('color=')));
      expect(
        item.comprehensionQuestions.first.prompt.toLowerCase(),
        isNot(contains('href')),
      );
      expect(item.displaySnippet.toLowerCase(), isNot(contains('blank"')));
      expect(
        item.comprehensionQuestions.first.choices.join(' ').toLowerCase(),
        isNot(contains('/a')),
      );
    });

    test('rejette un article people et conserve un deck max 5', () {
      final bad = NewsArticle.fromRss(
        title: 'Celebrity fashion live updates',
        url: 'https://example.com/bad',
        publishedAt: DateTime.now(),
        source: 'Random',
      );

      final goodArticles = List<NewsArticle>.generate(6, (index) {
        return NewsArticle.fromRss(
          title: 'US inflation cools as bond market prices fewer hikes $index',
          url: 'https://example.com/$index',
          publishedAt: DateTime.now().subtract(Duration(hours: index)),
          source: 'Reuters',
          snippet:
              'The article links inflation, yields, dollar and growth stocks in a clear causal chain.',
        );
      });

      final deck = NewsGameEngine.buildDailyDeck(<NewsArticle>[
        bad,
        ...goodArticles,
      ]);

      expect(deck.length, 5);
      expect(
        deck.every((item) => item.qualityScore >= kNewsGameMinQualityScore),
        isTrue,
      );
      expect(
        deck.any(
          (item) => item.displayTitle.toLowerCase().contains('celebrity'),
        ),
        isFalse,
      );
    });

    test('catégorise correctement une news inflation', () {
      final article = NewsArticle.fromRss(
        title: 'US inflation cools after softer CPI report',
        url: 'https://example.com/inflation',
        publishedAt: DateTime.now(),
        source: 'Bloomberg',
        snippet:
            'Cooling inflation pushed yields lower and improved appetite for growth stocks.',
      );

      final item = NewsGameEngine.buildDeckItem(article);

      expect(item.macroCategory, NewsMacroCategory.inflation);
      expect(item.impactOptions.length, greaterThanOrEqualTo(5));
      expect(item.causalChain, isNotEmpty);
    });

    test('construit une route monde à plusieurs noeuds', () {
      final article = NewsArticle.fromRss(
        title: 'Oil jumps as Middle East tensions escalate',
        url: 'https://example.com/oil',
        publishedAt: DateTime.now(),
        source: 'Financial Times',
        snippet:
            'Markets repriced regional risk, safe havens and cross-border contagion after the escalation.',
      );

      final route = NewsGameEngine.buildWorldRoute(
        sourceCountryIso2: 'SA',
        sourceCountryNameFr: 'Arabie saoudite',
        article: article,
      );

      expect(route.sourceCountryIso2, 'SA');
      expect(route.routeNodes.length, 2);
      expect(<NewsMacroCategory>[
        NewsMacroCategory.geopolitics,
        NewsMacroCategory.commodities,
      ], contains(route.sourceItem.macroCategory));
    });

    test('applique les multiplicateurs de confiance et le bonus combo', () {
      final article = NewsArticle.fromRss(
        title: 'Fed signals more caution as inflation stays sticky',
        url: 'https://example.com/fed',
        publishedAt: DateTime.now(),
        source: 'Reuters',
        snippet:
            'Sticky inflation keeps yields high, supports the dollar and pressures growth stocks.',
      );
      final item = NewsGameEngine.buildDeckItem(article);
      final correctTarget = item.impactOptions.firstWhere(
        (option) => option.isExpectedTarget,
      );

      final round = NewsGameEngine.resolveDeckRound(
        item: item,
        predictions: <NewsImpactPrediction>[
          NewsImpactPrediction(
            targetId: correctTarget.id,
            direction: correctTarget.expectedDirection,
            confidenceLevel: NewsConfidenceLevel.forte,
          ),
        ],
        comprehensionAnswers: const <int?>[0, 0],
        currentCombo: 2,
        questionCount: 2,
      );

      final breakdown = NewsGameEngine.buildSessionBreakdown(<NewsRoundResult>[
        round,
        round,
        round,
      ]);

      expect(round.marketScore, greaterThan(70));
      expect(newsConfidenceGainMultiplier(NewsConfidenceLevel.forte), 1.8);
      expect(
        newsConfidencePenaltyMultiplier(NewsConfidenceLevel.prudente),
        0.25,
      );
      expect(breakdown.comboBonus, greaterThanOrEqualTo(4));
    });
  });
}
