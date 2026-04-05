import 'package:fintech/features/daily_news_game/models/news_article.dart';
import 'package:fintech/features/daily_news_game/models/quiz_question.dart';
import 'package:fintech/features/daily_news_game/services/quiz_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Daily news dynamic quiz sanitization', () {
    test('génère des questions sans résidu HTML / query parasite', () {
      final articles = <NewsArticle>[
        NewsArticle.fromRss(
          title: 'Fed href="https://foo.bar" signals softer inflation',
          url: 'https://example.com/fed',
          publishedAt: DateTime.now(),
          source: 'Reuters',
          snippet:
              'Fed h="https://foo.bar?hl=en&output=1" target="_blank" blank" color="#fff" said inflation eased after CPI, supporting bonds, helping Treasuries and weakening the dollar while equities rebounded on hopes of fewer hikes.',
        ),
        NewsArticle.fromRss(
          title: 'ECB keeps rates high as growth slows',
          url: 'https://example.com/ecb',
          publishedAt: DateTime.now(),
          source: 'Bloomberg',
          snippet:
              'The ECB maintained restrictive policy while recession fears mounted, pressuring cyclicals and forcing investors to reassess euro area growth expectations after weaker surveys.',
        ),
        NewsArticle.fromRss(
          title: 'Oil jumps after supply disruption in the Middle East',
          url: 'https://example.com/oil',
          publishedAt: DateTime.now(),
          source: 'Financial Times',
          snippet:
              'Oil prices surged after a supply disruption, lifting inflation expectations, pushing yields higher and reviving demand for defensive sectors across global markets.',
        ),
      ];

      final questions = QuizGenerator().generateQuizForArticles(
        articles,
        seed: 42,
      );

      expect(questions, isNotEmpty);

      for (final question in questions) {
        final lower =
            '${question.prompt} ${question.choices.join(' ')}'.toLowerCase();

        expect(lower, isNot(contains('href')));
        expect(lower, isNot(contains('target')));
        expect(lower, isNot(contains('blank')));
        expect(lower, isNot(contains('h=')));
        expect(lower, isNot(contains('hl=')));
        expect(lower, isNot(contains('output=')));
        expect(lower, isNot(contains('color=')));
        expect(lower, isNot(contains('http://')));
        expect(lower, isNot(contains('https://')));
        expect(lower, isNot(contains('/a')));
      }
    });

    test('nettoie aussi les quiz dynamiques déjà persistés dans Firestore', () {
      final question = QuizQuestion.fromFirestore(<String, dynamic>{
        'id': 'legacy_q1',
        'prompt':
            'Quel thème h="https://foo.bar?hl=en&output=1" target="_blank" domine ?',
        'choices': <String>[
          'Taux',
          'h="https://foo.bar"',
          'blank" color="#fff"',
          '/a',
        ],
        'correctIndex': 0,
        'type': 'theme',
      });

      final lower =
          '${question.prompt} ${question.choices.join(' ')}'.toLowerCase();

      expect(lower, isNot(contains('href')));
      expect(lower, isNot(contains('target')));
      expect(lower, isNot(contains('blank')));
      expect(lower, isNot(contains('h=')));
      expect(lower, isNot(contains('hl=')));
      expect(lower, isNot(contains('output=')));
      expect(lower, isNot(contains('color=')));
      expect(lower, isNot(contains('/a')));
    });
  });
}
