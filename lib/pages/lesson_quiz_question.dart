import 'dart:math' as math;

class Question {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;

  Question({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? const <String>[]),
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
    );
  }

  Question shuffled(math.Random random) {
    final indexedOptions = List.generate(
      options.length,
      (index) => MapEntry(index, options[index]),
    );

    for (var index = indexedOptions.length - 1; index > 0; index -= 1) {
      final swapIndex = random.nextInt(index + 1);
      final current = indexedOptions[index];
      indexedOptions[index] = indexedOptions[swapIndex];
      indexedOptions[swapIndex] = current;
    }

    return Question(
      question: question,
      options: indexedOptions.map((entry) => entry.value).toList(),
      correctAnswerIndex: indexedOptions.indexWhere(
        (entry) => entry.key == correctAnswerIndex,
      ),
    );
  }
}
