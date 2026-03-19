import 'package:fintech/pages/learn_course4_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapter 4 quiz data builds mapped quizzes with valid answers', () {
    final chapters =
        (chapter4QuizData['chapters'] as List).cast<Map<String, dynamic>>();

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
    expect(totalQuizzes, greaterThan(30));

    final introQuiz = findQuiz('Pourquoi la macro encadre tous les marchés');
    expect(introQuiz, isNotNull);
    expect((introQuiz!['questions'] as List).length, greaterThanOrEqualTo(5));

    final taylorQuiz = findQuiz(
      'Une lecture stylisée des réactions de la banque centrale',
    );
    expect(taylorQuiz, isNotNull);

    final changeQuiz = findQuiz('Le change comme prix d’équilibre');
    expect(changeQuiz, isNotNull);

    final ratesQuiz = findQuiz(
      'Pourquoi les flux lointains sont les plus vulnérables',
    );
    expect(ratesQuiz, isNotNull);

    for (final quiz in [introQuiz, taylorQuiz, changeQuiz, ratesQuiz]) {
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
