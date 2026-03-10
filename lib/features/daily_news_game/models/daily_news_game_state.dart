import 'package:cloud_firestore/cloud_firestore.dart';

import 'news_article.dart';

/// État quotidien du mini-jeu "Actu & Quiz", persisté dans Firestore sous
/// /users/{uid}/dailyNewsGame/{yyyyMMdd}
class DailyNewsGameState {
  final int quota;
  final List<NewsArticle> articles;
  final int currentIndex;
  final int readCount;
  final bool quizAnswered;
  final bool quizCorrect;
  final bool fetchFailed;

  const DailyNewsGameState({
    required this.quota,
    required this.articles,
    required this.currentIndex,
    required this.readCount,
    required this.quizAnswered,
    required this.quizCorrect,
    this.fetchFailed = false,
  });

  /// Tous les articles ont été lus et on peut afficher le quiz.
  bool get showQuiz => currentIndex >= articles.length;

  /// Partie du jour terminée.
  bool get isComplete => quizAnswered;

  factory DailyNewsGameState.fromFirestore(Map<String, dynamic> map) {
    final rawArticles = (map['articles'] as List<dynamic>?) ?? [];
    return DailyNewsGameState(
      quota: (map['quota'] as int?) ?? 3,
      articles: rawArticles
          .whereType<Map<String, dynamic>>()
          .map(NewsArticle.fromFirestore)
          .toList(),
      currentIndex: (map['currentIndex'] as int?) ?? 0,
      readCount: (map['readCount'] as int?) ?? 0,
      quizAnswered: (map['quizAnswered'] as bool?) ?? false,
      quizCorrect: (map['quizCorrect'] as bool?) ?? false,
      fetchFailed: (map['fetchFailed'] as bool?) ?? false,
    );
  }

  /// Sérialisation complète pour la création initiale du document.
  Map<String, dynamic> toFirestore() => {
    'quota': quota,
    'articles': articles.map((a) => a.toFirestore()).toList(),
    'articleIds': articles.map((a) => a.id).toList(),
    'currentIndex': currentIndex,
    'readCount': readCount,
    'quizAnswered': quizAnswered,
    'quizCorrect': quizCorrect,
    'fetchFailed': fetchFailed,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
