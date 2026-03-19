import 'dart:convert';
import 'dart:io';

import 'package:fintech/pages/learn_course3_data.dart';
import 'package:fintech/pages/learn_course4_data.dart';
import 'package:fintech/pages/learn_course5_data.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _collectCourseLessons(Map<String, dynamic> courseData) {
  final lessons = <String>[];

  void walk(Map<String, dynamic> node) {
    final nodeLessons =
        (node['lessons'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final lesson in nodeLessons) {
      lessons.add(lesson['lesson_title'] as String);
    }

    final subChapters =
        (node['sub_chapters'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final subChapter in subChapters) {
      walk(subChapter);
    }
  }

  final chapters =
      (courseData['chapters'] as List).cast<Map<String, dynamic>>();
  for (final chapter in chapters) {
    walk(chapter);
  }

  return lessons;
}

List<String> _collectQuizLessons(Map<String, dynamic> quizData) {
  final lessons = <String>[];
  final chapters = (quizData['chapters'] as List).cast<Map<String, dynamic>>();
  for (final chapter in chapters) {
    final quizzes =
        (chapter['quizzes'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final quiz in quizzes) {
      lessons.add(quiz['lesson_title'] as String);
    }
  }
  return lessons;
}

Iterable<String> _allQuizTexts(Map<String, dynamic> quizData) sync* {
  final chapters = (quizData['chapters'] as List).cast<Map<String, dynamic>>();
  for (final chapter in chapters) {
    final quizzes =
        (chapter['quizzes'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final quiz in quizzes) {
      final questions =
          (quiz['questions'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      for (final question in questions) {
        yield question['question'] as String? ?? '';
        final options =
            (question['options'] as List?)?.cast<String>() ?? const <String>[];
        yield* options;
      }
    }
  }
}

Map<String, dynamic> _loadJsonFile(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

bool _hasLatexResidue(String text) {
  const suspiciousSnippets = <String>[
    r'\textbf',
    r'\textit',
    r'\begin',
    r'\end',
    r'\frac',
    r'\mathbb',
    r'\mathrm',
    r'\boxed',
    r'\displaystyle',
    r'\approx',
    r'\sigma',
    r'\beta',
    r'\rho',
    r'\pi',
    r'\Delta',
    r'\leftrightarrow',
  ];

  if (text.contains('{') || text.contains('}') || text.contains(r'\')) {
    return true;
  }

  return suspiciousSnippets.any(text.contains);
}

void _expectFullCoverageAndCleanTexts(
  Map<String, dynamic> courseData,
  Map<String, dynamic> quizData,
) {
  final courseLessons = _collectCourseLessons(courseData);
  final quizLessons = _collectQuizLessons(quizData);
  final missingLessons =
      courseLessons.where((lesson) => !quizLessons.contains(lesson)).toList();

  expect(
    missingLessons,
    isEmpty,
    reason: 'Leçons sans quiz: ${missingLessons.join(', ')}',
  );

  for (final text in _allQuizTexts(quizData)) {
    expect(
      _hasLatexResidue(text),
      isFalse,
      reason: 'Résidu LaTeX détecté: $text',
    );
  }
}

void main() {
  test('all chapter lessons have quizzes and quiz text is clean', () {
    final course1 = _loadJsonFile('assets/chapitre1.json');
    final quiz1 = _loadJsonFile('assets/quizz1.json');
    final course2 = _loadJsonFile('assets/chapitre2.json');
    final quiz2 = _loadJsonFile('assets/quizz2.json');

    _expectFullCoverageAndCleanTexts(course1, quiz1);
    _expectFullCoverageAndCleanTexts(course2, quiz2);
    _expectFullCoverageAndCleanTexts(chapter3CourseData, chapter3QuizData);
    _expectFullCoverageAndCleanTexts(chapter4CourseData, chapter4QuizData);
    _expectFullCoverageAndCleanTexts(chapter5CourseData, chapter5QuizData);
  });
}
