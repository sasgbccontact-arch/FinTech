import '../utils/news_text_sanitizer.dart';

/// Types de questions du quiz QCM.
enum QuizQuestionType {
  // Métadonnées (fallback)
  source,
  date,
  theme,
  country,
  title,
  // Contenu (prioritaires)
  cloze,
  entity,
  number,
  keyword,
  trueSentence,
  association,
}

/// Une question QCM avec 4 choix.
class QuizQuestion {
  final String id;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final QuizQuestionType type;
  final String? sourceArticleUrl;

  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.type,
    this.sourceArticleUrl,
  });

  factory QuizQuestion.fromFirestore(Map<String, dynamic> map) {
    return QuizQuestion(
      id: (map['id'] as String?) ?? '',
      prompt: sanitizeNewsGameText((map['prompt'] as String?) ?? ''),
      choices:
          List<String>.from(
            (map['choices'] as List<dynamic>?) ?? const [],
          ).map(sanitizeNewsGameText).toList(),
      correctIndex: (map['correctIndex'] as int?) ?? 0,
      type: QuizQuestionType.values.firstWhere(
        (t) => t.name == (map['type'] as String?),
        orElse: () => QuizQuestionType.source,
      ),
      sourceArticleUrl: map['sourceArticleUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'prompt': prompt,
    'choices': choices,
    'correctIndex': correctIndex,
    'type': type.name,
    if (sourceArticleUrl != null) 'sourceArticleUrl': sourceArticleUrl,
  };
}
