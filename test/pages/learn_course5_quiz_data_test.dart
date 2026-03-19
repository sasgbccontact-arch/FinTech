import 'package:fintech/pages/learn_course5_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapter 5 quiz data builds mapped quizzes with valid answers', () {
    final chapters =
        (chapter5QuizData['chapters'] as List).cast<Map<String, dynamic>>();

    Map<String, dynamic>? findQuiz(String lessonTitle) {
      for (final chapter in chapters) {
        final quizzes =
            (chapter['quizzes'] as List).cast<Map<String, dynamic>>();
        for (final quiz in quizzes) {
          if (quiz['lesson_title'] == lessonTitle) {
            return quiz;
          }
        }
      }
      return null;
    }

    final totalQuizzes = chapters.fold<int>(
      0,
      (sum, chapter) => sum + (chapter['quizzes'] as List).length,
    );

    expect(chapters.length, equals(2));
    expect(totalQuizzes, equals(21));

    final introQuiz = findQuiz('Qu’est-ce qu’un actif ou produit financier ?');
    expect(introQuiz, isNotNull);
    expect((introQuiz!['questions'] as List).length, greaterThanOrEqualTo(4));

    final livretQuiz = findQuiz('Livret A, LDDS, LEP et pouvoir d’achat');
    expect(livretQuiz, isNotNull);

    final turboQuiz = findQuiz('Le levier avec barrière désactivante');
    expect(turboQuiz, isNotNull);

    final commodityQuiz = findQuiz('Un rendement qui vient uniquement du prix');
    expect(commodityQuiz, isNotNull);

    final cryptoQuiz = findQuiz('Une exposition technologique et spéculative');
    expect(cryptoQuiz, isNotNull);

    for (final quiz in [
      introQuiz,
      livretQuiz,
      turboQuiz,
      commodityQuiz,
      cryptoQuiz,
    ]) {
      final questions =
          (quiz!['questions'] as List).cast<Map<String, dynamic>>();
      for (final question in questions) {
        final options = (question['options'] as List).cast<String>();
        final correctAnswerIndex = question['correct_answer_index'] as int;
        expect(options.length, greaterThanOrEqualTo(4));
        expect(correctAnswerIndex, inInclusiveRange(0, options.length - 1));
      }
    }
  });
}
