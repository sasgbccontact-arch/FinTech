import 'dart:math' as math;

import 'package:fintech/pages/lesson_quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'question shuffle preserves the correct answer and can vary positions',
    () {
      const correctOption = 'Bonne réponse';
      final question = Question(
        question: 'Question de test',
        options: const <String>[
          'Option A',
          correctOption,
          'Option C',
          'Option D',
        ],
        correctAnswerIndex: 1,
      );

      final seenOrders = <String>{};
      final seenCorrectIndexes = <int>{};

      for (var seed = 0; seed < 20; seed += 1) {
        final shuffled = question.shuffled(math.Random(seed));
        seenOrders.add(shuffled.options.join('|'));
        seenCorrectIndexes.add(shuffled.correctAnswerIndex);
        expect(
          shuffled.options[shuffled.correctAnswerIndex],
          equals(correctOption),
        );
      }

      expect(seenOrders.length, greaterThan(1));
      expect(seenCorrectIndexes.length, greaterThan(1));
    },
  );
}
