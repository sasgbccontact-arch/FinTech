import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fintech/services/activity_tracking_service.dart';

import '../models/news_article.dart';
import '../models/quiz_question.dart';
import '../services/quiz_generator.dart';
import 'daily_news_game_repository.dart';

class QuizRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _sessionRef({
    required DailyNewsGameMode mode,
    required String sessionId,
  }) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection(mode.sessionCollection)
        .doc(sessionId);
  }

  Future<List<QuizQuestion>> getOrCreateSessionQuiz({
    required DailyNewsGameMode mode,
    required String sessionId,
    required List<NewsArticle> articles,
    String? selectedCountryIso2,
    String? selectedCountryNameFr,
  }) async {
    final seed = computeQuizSeed(
      uid: _uid,
      sessionId: sessionId,
      articles: articles,
    );
    final ref = _sessionRef(mode: mode, sessionId: sessionId);
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};

    final existingSeed = (data['quizSeed'] as num?)?.toInt();
    final existingQuiz = _parseQuestions(data['quiz']);

    if (existingQuiz.isNotEmpty && existingSeed == seed) {
      debugPrint(
        '[QuizRepo] Quiz existant réutilisé: session=$sessionId, mode=${mode.modeKey}, questions=${existingQuiz.length}',
      );
      return existingQuiz;
    }

    final questions = await generateQuizAsync(
      articles: articles,
      seed: seed,
      context:
          mode == DailyNewsGameMode.actus
              ? QuizContext.actus
              : QuizContext.monde,
      selectedCountryIso2: selectedCountryIso2,
      selectedCountryNameFr: selectedCountryNameFr,
    );

    await ref.set({
      'quizSeed': seed,
      'quiz': questions.map((q) => q.toFirestore()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      '[QuizRepo] Quiz généré/enregistré: session=$sessionId, mode=${mode.modeKey}, nbQuestions=${questions.length}',
    );

    return questions;
  }

  Future<void> saveQuizResult({
    required DailyNewsGameMode mode,
    required String sessionId,
    required List<QuizQuestion> questions,
    required List<int?> selectedAnswers,
  }) async {
    final ref = _sessionRef(mode: mode, sessionId: sessionId);
    final answers = <Map<String, dynamic>>[];
    var score = 0;

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final selected = i < selectedAnswers.length ? selectedAnswers[i] : null;
      final isCorrect = selected != null && selected == q.correctIndex;
      if (isCorrect) score++;

      answers.add({
        'questionId': q.id,
        'selectedIndex': selected,
        'correctIndex': q.correctIndex,
        'isCorrect': isCorrect,
      });
    }

    await ref.set({
      'answers': answers,
      'score': {'correct': score, 'total': questions.length},
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    unawaited(
      ActivityTrackingService.trackForUser(
        uid: _uid,
        type: 'daily_news_quiz_completed',
        label: mode.modeKey,
        points: 20 + (score * 12),
        counters: <String, int>{
          'daily_news_quizzes': 1,
          'daily_news_correct_answers': score,
        },
      ),
    );

    debugPrint(
      '[QuizRepo] Résultat enregistré: session=$sessionId, mode=${mode.modeKey}, score=$score/${questions.length}',
    );
  }

  List<QuizQuestion> _parseQuestions(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestion.fromFirestore)
        .where((q) => q.prompt.trim().isNotEmpty && q.choices.length >= 3)
        .toList();
  }
}
