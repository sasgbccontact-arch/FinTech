import 'package:fintech/pages/learn_course3_data.dart';
import 'package:fintech/pages/learn_course4_data.dart';
import 'package:fintech/pages/learn_course5_data.dart';
import 'package:fintech/pages/learn_page.dart';
import 'package:flutter_test/flutter_test.dart';

List<LessonContent> _collectLessons(CourseContent course) {
  final lessons = <LessonContent>[];

  void walk(ChapterContent chapter) {
    lessons.addAll(chapter.lessons);
    for (final subChapter in chapter.subChapters) {
      walk(subChapter);
    }
  }

  for (final chapter in course.chapters) {
    walk(chapter);
  }

  return lessons;
}

void _expectAllLessonsHaveQuiz(CourseContent course, String label) {
  final lessons = _collectLessons(course);
  final missing =
      lessons
          .where((lesson) => lesson.quizQuestions.isEmpty)
          .map((lesson) => lesson.title)
          .toList();

  expect(
    missing,
    isEmpty,
    reason: '$label: leçons sans quiz après parsing: ${missing.join(', ')}',
  );
}

void main() {
  test('chapter 3, 4 and 5 quiz bindings survive multiple parses', () {
    final course3First = parseLearnCourseContent(
      chapter3CourseData,
      chapter3QuizData,
    );
    final course3Second = parseLearnCourseContent(
      chapter3CourseData,
      chapter3QuizData,
    );

    final course4First = parseLearnCourseContent(
      chapter4CourseData,
      chapter4QuizData,
    );
    final course4Second = parseLearnCourseContent(
      chapter4CourseData,
      chapter4QuizData,
    );

    final course5First = parseLearnCourseContent(
      chapter5CourseData,
      chapter5QuizData,
    );
    final course5Second = parseLearnCourseContent(
      chapter5CourseData,
      chapter5QuizData,
    );

    _expectAllLessonsHaveQuiz(course3First, 'Chapitre 3 premier parse');
    _expectAllLessonsHaveQuiz(course3Second, 'Chapitre 3 second parse');
    _expectAllLessonsHaveQuiz(course4First, 'Chapitre 4 premier parse');
    _expectAllLessonsHaveQuiz(course4Second, 'Chapitre 4 second parse');
    _expectAllLessonsHaveQuiz(course5First, 'Chapitre 5 premier parse');
    _expectAllLessonsHaveQuiz(course5Second, 'Chapitre 5 second parse');
  });
}
