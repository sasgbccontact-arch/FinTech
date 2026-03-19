import 'package:fintech/pages/learn_course3_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapter 3 quiz data builds mapped quizzes with valid answers', () {
    final chapters =
        (chapter3QuizData['chapters'] as List).cast<Map<String, dynamic>>();

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

    expect(chapters.length, greaterThan(10));
    expect(totalQuizzes, greaterThan(25));

    final introQuiz = findQuiz('Microéconomie et finance : le même langage');
    expect(introQuiz, isNotNull);
    expect((introQuiz!['questions'] as List).length, greaterThanOrEqualTo(5));

    final capmQuiz = findQuiz('Lire la Security Market Line');
    expect(capmQuiz, isNotNull);

    final anticipationQuiz = findQuiz(
      'Pourquoi le prix réagit avant les résultats',
    );
    expect(anticipationQuiz, isNotNull);

    final prospectQuiz = findQuiz(
      "Modifier la fonction de valeur autour d'un point de référence",
    );
    expect(prospectQuiz, isNotNull);

    for (final quiz in [introQuiz, capmQuiz, anticipationQuiz, prospectQuiz]) {
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
