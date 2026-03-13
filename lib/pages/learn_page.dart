import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'shop_page.dart';
import 'package:fintech/core/constants.dart';
import 'package:fintech/services/activity_tracking_service.dart';
import 'learn_course3_data.dart';
import 'learn_course4_data.dart';
import 'learn_course5_data.dart';

// --- Models ---

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
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
    );
  }
}

class LessonContent {
  final String title;
  final String content;
  final List<Question> quizQuestions;

  LessonContent({
    required this.title,
    required this.content,
    this.quizQuestions = const [],
  });
}

class ChapterContent {
  final String title;
  final List<LessonContent> lessons;
  final List<ChapterContent> subChapters;
  final bool subChaptersFirst;

  ChapterContent({
    required this.title,
    required this.lessons,
    this.subChapters = const [],
    this.subChaptersFirst = false,
  });
}

class CourseContent {
  final String title;
  final String author;
  final List<ChapterContent> chapters;

  CourseContent({
    required this.title,
    required this.author,
    required this.chapters,
  });
}

// --- Pages ---

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> with TickerProviderStateMixin {
  CourseContent? _course1;
  CourseContent? _course2;
  CourseContent? _course3;
  CourseContent? _course4;
  CourseContent? _course5;
  bool _loading = true;
  String? _error;
  final Set<String> _completedLessons = {};
  int _xp = 0;
  int _streak = 0;
  int _maxStreak = 0;
  bool _isStreakActiveToday = false;
  late AnimationController _streakController;
  late Animation<double> _streakAnimation;
  late AnimationController _ambientController;
  late Animation<double> _ambientAnimation;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _ambientAnimation = CurvedAnimation(
      parent: _ambientController,
      curve: Curves.easeInOutSine,
    );
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _streakAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _streakController, curve: Curves.easeInOut),
    );

    _loadCourses();
    _loadProgress();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _streakController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      // Load Chapter 1
      final c1Json = jsonDecode(
        await rootBundle.loadString('assets/chapitre1.json'),
      );
      final q1Json = jsonDecode(
        await rootBundle.loadString('assets/quizz1.json'),
      );
      _course1 = _parseCourseContent(c1Json, q1Json);
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement du Chapitre 1: $e';
        _loading = false;
      });
      return;
    }

    try {
      // Load Chapter 2
      final c2Json = jsonDecode(
        await rootBundle.loadString('assets/chapitre2.json'),
      );
      final q2Json = jsonDecode(
        await rootBundle.loadString('assets/quizz2.json'),
      );
      _course2 = _parseCourseContent(c2Json, q2Json);
    } catch (e) {
      debugPrint('Erreur chargement Chapitre 2 (ignorée): $e');
    }

    try {
      _course3 = _parseCourseContentSafely(
        chapter3CourseData,
        chapter3QuizData,
        'Chapitre 3',
      );
    } catch (e) {
      debugPrint('Erreur chargement Chapitre 3 (ignorée): $e');
    }

    try {
      _course4 = _parseCourseContentSafely(
        chapter4CourseData,
        chapter4QuizData,
        'Chapitre 4',
      );
    } catch (e) {
      debugPrint('Erreur chargement Chapitre 4 (ignorée): $e');
    }

    try {
      _course5 = _parseCourseContentSafely(
        chapter5CourseData,
        chapter5QuizData,
        'Chapitre 5',
      );
    } catch (e) {
      debugPrint('Erreur chargement Chapitre 5 (ignorée): $e');
    }

    // Filter duplicates in course 2 (remove chapters already in course 1)
    if (_course1 != null && _course2 != null) {
      final titles1 = _course1!.chapters.map((c) => c.title).toSet();
      _course2!.chapters.removeWhere((c) => titles1.contains(c.title));
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  CourseContent _parseCourseContent(dynamic courseJson, dynamic quizJson) {
    final chapters = <ChapterContent>[];
    final courseChapters = courseJson['chapters'] as List;
    final quizChapters = quizJson['chapters'] as List;

    for (var cData in courseChapters) {
      chapters.add(_parseChapter(cData, quizChapters));
    }

    return CourseContent(
      title: courseJson['course_title'] ?? 'Cours',
      author: courseJson['author'] ?? '',
      chapters: chapters,
    );
  }

  CourseContent? _parseCourseContentSafely(
    dynamic courseJson,
    dynamic quizJson,
    String label,
  ) {
    try {
      return _parseCourseContent(courseJson, quizJson);
    } catch (e) {
      debugPrint('$label: échec du parsing avec quiz, fallback sans quiz: $e');
      try {
        return _parseCourseContent(courseJson, {'chapters': <dynamic>[]});
      } catch (fallbackError) {
        debugPrint('$label: échec du fallback sans quiz: $fallbackError');
        return null;
      }
    }
  }

  ChapterContent _parseChapter(
    dynamic cData,
    List quizChapters, {
    List<dynamic>? inheritedQuizzes,
  }) {
    final cTitle = cData['chapter_title'];

    bool subChaptersFirst = false;
    if (cData is Map) {
      final keys = cData.keys.toList();
      final lIndex = keys.indexOf('lessons');
      final sIndex = keys.indexOf('sub_chapters');
      if (sIndex != -1 && lIndex != -1 && sIndex < lIndex) {
        subChaptersFirst = true;
      }
    }

    final cLessons = cData['lessons'] as List? ?? [];
    final cSubChapters = cData['sub_chapters'] as List? ?? [];

    // Find matching quiz chapter
    final qChapter = quizChapters.firstWhere(
      (q) => q['chapter_title'] == cTitle,
      orElse: () => null,
    );

    // Use found quizzes or inherited ones
    final List<dynamic> qQuizzes =
        qChapter != null
            ? (qChapter['quizzes'] as List)
            : (inheritedQuizzes ?? []);

    final lessons = <LessonContent>[];
    for (var lData in cLessons) {
      final lTitle = lData['lesson_title'];
      final lContent = lData['content'];

      // Find matching quiz
      final qIndex = qQuizzes.indexWhere((q) => q['lesson_title'] == lTitle);
      Map<String, dynamic>? qData;
      if (qIndex != -1) {
        qData = qQuizzes[qIndex];
        // Remove to handle duplicate titles in order and avoid reusing the same quiz
        qQuizzes.removeAt(qIndex);
      }

      final questions = <Question>[];
      if (qData != null && qData['questions'] != null) {
        for (var q in qData['questions']) {
          questions.add(Question.fromJson(q));
        }
      }

      lessons.add(
        LessonContent(
          title: lTitle,
          content: lContent,
          quizQuestions: questions,
        ),
      );
    }

    final subChapters = <ChapterContent>[];
    for (var subData in cSubChapters) {
      subChapters.add(
        _parseChapter(subData, quizChapters, inheritedQuizzes: qQuizzes),
      );
    }

    return ChapterContent(
      title: cTitle,
      lessons: lessons,
      subChapters: subChapters,
      subChaptersFirst: subChaptersFirst,
    );
  }

  Future<void> _loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('games')
              .doc('progress')
              .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final completed = List<String>.from(data?['completed_lessons'] ?? []);
        final xp = (data?['xp'] as num?)?.toInt() ?? 0;

        // Gestion du Streak
        int streak = (data?['current_streak'] as num?)?.toInt() ?? 0;
        int maxStreak = (data?['max_streak'] as num?)?.toInt() ?? 0;
        final Timestamp? lastDateTs = data?['last_streak_date'];
        bool isActiveToday = false;

        if (lastDateTs != null) {
          final lastDate = lastDateTs.toDate();
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

          final diff = today.difference(lastDay).inDays;

          if (diff == 0) {
            isActiveToday = true;
          } else if (diff > 1) {
            // Si plus d'un jour d'écart, le streak est perdu
            streak = 0;
          }
          // Si diff == 1 (hier), on garde le streak tel quel, en attente de validation aujourd'hui
        } else {
          streak = 0;
        }

        if (streak > maxStreak) maxStreak = streak;

        setState(() {
          _completedLessons.addAll(completed);
          _xp = xp;
          _streak = streak;
          _maxStreak = maxStreak;
          _isStreakActiveToday = isActiveToday;
        });
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  Future<void> _updateStreak() async {
    if (_isStreakActiveToday) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Si le streak était à 0 ou maintenu depuis hier, on l'incrémente
    // (La logique de reset si > 1 jour est gérée au chargement, donc ici _streak est soit 0 soit valide)
    int newStreak = _streak + 1;
    int newMaxStreak = _maxStreak;
    if (newStreak > newMaxStreak) {
      newMaxStreak = newStreak;
    }

    setState(() {
      _streak = newStreak;
      _maxStreak = newMaxStreak;
      _isStreakActiveToday = true;
    });
    _streakController.forward(from: 0.0);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('games')
          .doc('progress')
          .set({
            'current_streak': newStreak,
            'max_streak': newMaxStreak,
            'last_streak_date': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating streak: $e');
    }
  }

  Future<void> _onLessonCompleted(
    String lessonTitle,
    int score,
    List<bool> newResults,
  ) async {
    // Met à jour le streak (activité) et marque la leçon comme terminée si c'est la première fois.
    _updateStreak();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_completedLessons.contains(lessonTitle)) {
      setState(() {
        _completedLessons.add(lessonTitle);
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('games')
          .doc('progress')
          .set({
            'completed_lessons': FieldValue.arrayUnion([lessonTitle]),
          }, SetOptions(merge: true));
    }

    // Calcule et attribue l'XP en fonction des nouvelles bonnes réponses.
    final quizResultRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('quiz_results')
        .doc(lessonTitle);
    int xpGained = 0;
    const int xpPerCorrectAnswer = 10;

    try {
      final doc = await quizResultRef.get();
      if (doc.exists) {
        // Quiz refait
        final oldResultsData = doc.data()?['results'];
        if (oldResultsData is List) {
          final oldResults = List<bool>.from(oldResultsData);
          int newlyCorrect = 0;
          for (int i = 0; i < newResults.length && i < oldResults.length; i++) {
            if (newResults[i] && !oldResults[i]) {
              newlyCorrect++;
            }
          }
          xpGained = newlyCorrect * xpPerCorrectAnswer;
        } else {
          xpGained = score * xpPerCorrectAnswer; // Fallback
        }
      } else {
        // Première fois
        xpGained = score * xpPerCorrectAnswer;
      }

      await quizResultRef.set({'results': newResults});

      if (xpGained > 0) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        // XP reste dans learning/progress, mais si on gagne des coins, c'est sur userRef
        // Ici c'est de l'XP. On le met maintenant dans games/progress.
        final progressRef = userRef.collection('games').doc('progress');
        await progressRef.set({
          'xp': FieldValue.increment(xpGained),
        }, SetOptions(merge: true));
        if (mounted) {
          setState(() {
            _xp += xpGained;
          });
        }
      }

      unawaited(
        ActivityTrackingService.trackForUser(
          uid: user.uid,
          type: 'lesson_completed',
          label: lessonTitle,
          points: 35 + xpGained + (score * 5),
          counters: <String, int>{
            'lessons_completed': 1,
            'lesson_quizzes_completed': 1,
            'correct_answers': score,
          },
        ),
      );
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de l\'XP : $e');
    }

    await _checkUnlockables();

    // --- Mise à jour des quêtes quotidiennes ---
    try {
      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month}-${today.day}";
      final questRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quests')
          .doc('daily');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(questRef);
        if (!snapshot.exists || snapshot.data()?['date'] != dateStr) {
          // Reset si nouveau jour ou inexistant
          transaction.set(questRef, {
            'date': dateStr,
            'quizzes_done': 1,
            'lessons_done': 1,
            'trades_done': 0,
          });
        } else {
          transaction.update(questRef, {
            'quizzes_done': FieldValue.increment(1),
            'lessons_done': FieldValue.increment(1),
          });
        }
      });
    } catch (e) {
      debugPrint("Erreur mise à jour quête : $e");
    }
  }

  bool _isCourseCompleted(CourseContent? course) {
    if (course == null) return false;
    for (var chapter in course.chapters) {
      if (!_isChapterCompleted(chapter)) return false;
    }
    return true;
  }

  bool _isChapterCompleted(ChapterContent chapter) {
    for (var lesson in chapter.lessons) {
      if (!_completedLessons.contains(lesson.title)) return false;
    }
    for (var sub in chapter.subChapters) {
      if (!_isChapterCompleted(sub)) return false;
    }
    return true;
  }

  int _requiredLevelForCourse(int courseIndex) {
    switch (courseIndex) {
      case 2:
        return 2;
      case 3:
        return 4;
      case 4:
        return 6;
      case 5:
        return 8;
      default:
        return 1;
    }
  }

  int get _currentLevel => (_xp / 100).floor() + 1;

  bool _isCourseUnlocked({
    required int courseIndex,
    required bool isAdmin,
    CourseContent? previousCourse,
  }) {
    if (courseIndex <= 1 || isAdmin) return true;
    if (_isCourseCompleted(previousCourse)) return true;
    return _currentLevel >= _requiredLevelForCourse(courseIndex);
  }

  Future<void> _checkUnlockables() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final List<String> newUnlocks = [];

    // Check Chapter 1 (Course 1)
    if (_course1 != null && _isCourseCompleted(_course1)) {
      newUnlocks.add('_student');
    }

    // Check Chapter 2 (Course 2)
    if (_course2 != null && _isCourseCompleted(_course2)) {
      newUnlocks.add('_expert');
    }

    if (newUnlocks.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'unlocked_avatars': FieldValue.arrayUnion(newUnlocks),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _retryLoading() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadCourses();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LearnLoadingView();
    }

    if (_error != null) {
      return _LearnErrorView(message: _error!, onRetry: _retryLoading);
    }

    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          user != null
              ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots()
              : null,
      builder: (context, snapshot) {
        final bool isAdmin = snapshot.data?.data()?['isAdmin'] == true;
        final isCourse2Unlocked = _isCourseUnlocked(
          courseIndex: 2,
          isAdmin: isAdmin,
          previousCourse: _course1,
        );
        final isCourse3Unlocked = _isCourseUnlocked(
          courseIndex: 3,
          isAdmin: isAdmin,
          previousCourse: _course2,
        );
        final isCourse4Unlocked = _isCourseUnlocked(
          courseIndex: 4,
          isAdmin: isAdmin,
          previousCourse: _course3,
        );
        final isCourse5Unlocked = _isCourseUnlocked(
          courseIndex: 5,
          isAdmin: isAdmin,
          previousCourse: _course4,
        );

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Apprentissage',
              style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'Boutique',
                  child: InkWell(
                    onTap: () {
                      showCupertinoModalBottomSheet(
                        context: context,
                        builder: (context) => const ShopPage(),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE6E8EB)),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: detailsColor2,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: _LevelIndicator(),
              ),
            ],
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 6,
                    width: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildLearningHero(),
              _buildStreakWidget(),
              if (_course1 != null)
                _buildCourseCard(
                  title: 'Chapitre 1 : Investir en bourse',
                  subtitle:
                      'Fondations, habitudes, vocabulaire et premiers réflexes.',
                  badge: 'Base',
                  icon: Icons.school_rounded,
                  accentColors: const [detailsColor1, detailsColor2],
                  course: _course1!,
                  isAdmin: isAdmin,
                ),
              if (_course2 != null && _course2!.chapters.isNotEmpty)
                if (isCourse2Unlocked)
                  _buildCourseCard(
                    title: 'Chapitre 2 : Analyse fondamentale et graphique',
                    subtitle:
                        'Ratios, graphiques et lecture du marché en profondeur.',
                    badge: 'Analyse',
                    icon: Icons.trending_up_rounded,
                    accentColors: const [Color(0xFFE7C874), Color(0xFF4A1D5E)],
                    course: _course2!,
                    isAdmin: isAdmin,
                  )
                else
                  _buildLockedChapterCard(
                    'Chapitre 2 : Analyse fondamentale et graphique',
                    subtitle:
                        'Débloqué en validant le chapitre 1 ou au niveau ${_requiredLevelForCourse(2)}.',
                  ),
              if (_course3 != null && _course3!.chapters.isNotEmpty)
                if (isCourse3Unlocked)
                  _buildCourseCard(
                    title: 'Chapitre 3 : Microéconomie et marchés financiers',
                    subtitle:
                        'Prix, arbitrage, CAPM, contrats et finance moderne.',
                    badge: 'Avancé',
                    icon: Icons.auto_graph_rounded,
                    accentColors: const [Color(0xFFF0B36D), Color(0xFF562243)],
                    course: _course3!,
                    isAdmin: isAdmin,
                  )
                else
                  _buildLockedChapterCard(
                    'Chapitre 3 : Microéconomie et marchés financiers',
                    subtitle:
                        'Débloqué en validant le chapitre 2 ou au niveau ${_requiredLevelForCourse(3)}.',
                  )
              else
                _buildLockedChapterCard(
                  'Chapitre 3 : Microéconomie et marchés financiers',
                  subtitle: 'Contenu en cours de chargement.',
                ),
              if (_course4 != null && _course4!.chapters.isNotEmpty)
                if (isCourse4Unlocked)
                  _buildCourseCard(
                    title: 'Chapitre 4 : Macroéconomie et marchés financiers',
                    subtitle:
                        'Croissance, inflation, banques centrales et régimes macro-financiers.',
                    badge: 'Macro',
                    icon: Icons.public_rounded,
                    accentColors: const [Color(0xFFDAB98A), Color(0xFF4C2A5E)],
                    course: _course4!,
                    isAdmin: isAdmin,
                  )
                else
                  _buildLockedChapterCard(
                    'Chapitre 4 : Macroéconomie et marchés financiers',
                    subtitle:
                        'Débloqué en validant le chapitre 3 ou au niveau ${_requiredLevelForCourse(4)}.',
                  )
              else
                _buildLockedChapterCard(
                  'Chapitre 4 : Macroéconomie et marchés financiers',
                  subtitle: 'Contenu en cours de chargement.',
                ),
              if (_course5 != null && _course5!.chapters.isNotEmpty)
                if (isCourse5Unlocked)
                  _buildCourseCard(
                    title: 'Chapitre 5 : Les actifs financiers',
                    subtitle:
                        'Livrets, OPCVM, dérivés, structurés, matières premières et crypto-actifs.',
                    badge: 'Actifs',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColors: const [Color(0xFFC9B06D), Color(0xFF453055)],
                    course: _course5!,
                    isAdmin: isAdmin,
                  )
                else
                  _buildLockedChapterCard(
                    'Chapitre 5 : Les actifs financiers',
                    subtitle:
                        'Débloqué en validant le chapitre 4 ou au niveau ${_requiredLevelForCourse(5)}.',
                  )
              else
                _buildLockedChapterCard(
                  'Chapitre 5 : Les actifs financiers',
                  subtitle: 'Contenu en cours de chargement.',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLearningHero() {
    return AnimatedBuilder(
      animation: _ambientAnimation,
      builder: (context, child) {
        final drift = math.sin(_ambientAnimation.value * math.pi * 2);
        final oppositeDrift = math.cos(_ambientAnimation.value * math.pi * 2);

        return Container(
          constraints: const BoxConstraints(minHeight: 244),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF33154E), Color(0xFF140A1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: detailsColor1.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: detailsColor2.withValues(alpha: 0.20),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: detailsColor1.withValues(alpha: 0.12),
                blurRadius: 48,
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Positioned(
                  left: -20 + drift * 10,
                  top: -26,
                  child: _GlowOrb(
                    size: 130,
                    color: detailsColor1.withValues(alpha: 0.24),
                  ),
                ),
                Positioned(
                  right: -16 + oppositeDrift * 12,
                  bottom: -30,
                  child: _GlowOrb(
                    size: 150,
                    color: const Color(0xFFB88AD8).withValues(alpha: 0.16),
                  ),
                ),
                Positioned(
                  right: -4 + drift * 10,
                  top: 4 + oppositeDrift * 8,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.38,
                      child: Transform.rotate(
                        angle: 0.03 * drift,
                        child: SizedBox(
                          width: 196,
                          height: 188,
                          child: SvgPicture.string(_learningHeroSvg),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.01),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              detailsColor1.withValues(alpha: 0.18),
                              detailsColor2.withValues(alpha: 0.20),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: detailsColor1,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Parcours FinHub',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 220,
                        child: Text(
                          'Apprendre la finance avec plus de relief.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cours hiérarchisés, schémas, formules et progression visuelle dans une surface plus premium.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _HeroMetricChip(
                            icon: Icons.layers_rounded,
                            label: '5 chapitres',
                          ),
                          _HeroMetricChip(
                            icon: Icons.functions_rounded,
                            label: 'Formules',
                          ),
                          _HeroMetricChip(
                            icon: Icons.quiz_rounded,
                            label: 'Quiz',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakWidget() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF7F4EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              _isStreakActiveToday
                  ? detailsColor1.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _isStreakActiveToday
                    ? detailsColor1.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors:
                    _isStreakActiveToday || _streak > 0
                        ? [
                          detailsColor1.withValues(alpha: 0.95),
                          const Color(0xFFFF8A3D),
                        ]
                        : [Colors.grey.shade300, Colors.grey.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _isStreakActiveToday || _streak > 0
                          ? detailsColor1.withValues(alpha: 0.22)
                          : Colors.transparent,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ScaleTransition(
              scale: _streakAnimation,
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_streak jours de série',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        _isStreakActiveToday || _streak > 0
                            ? detailsColor2
                            : Colors.black87,
                  ),
                ),
                Text(
                  _isStreakActiveToday
                      ? 'Activité validée aujourd’hui'
                      : 'Termine une leçon pour garder le rythme',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: detailsColor1.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: detailsColor2.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Record $_maxStreak',
              style: TextStyle(
                fontSize: 12,
                color: detailsColor2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required List<Color> accentColors,
    required CourseContent course,
    required bool isAdmin,
  }) {
    final totalLessons = _countCourseLessons(course);
    final completedLessons = _countCompletedCourseLessons(course);
    final progress = totalLessons == 0 ? 0.0 : completedLessons / totalLessons;

    return AnimatedBuilder(
      animation: _ambientAnimation,
      builder: (context, child) {
        final floatOffset =
            math.sin(
              (_ambientAnimation.value * math.pi * 2) + title.length / 6,
            ) *
            8;
        final topTone =
            Color.lerp(const Color(0xFFFFFCF4), accentColors.first, 0.16)!;
        final bottomTone =
            Color.lerp(const Color(0xFFF9EBC5), accentColors.first, 0.28)!;
        final panelTone = Color.lerp(Colors.white, accentColors.first, 0.08)!;
        final titleColor = detailsColor2;
        final bodyColor = Colors.black.withValues(alpha: 0.68);
        final mutedColor = Colors.black.withValues(alpha: 0.54);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [topTone, bottomTone],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: detailsColor1.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: detailsColor1.withValues(alpha: 0.14),
                blurRadius: 20,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned(
                  right: -18 + floatOffset,
                  top: -14,
                  child: _GlowOrb(
                    size: 110,
                    color: accentColors.first.withValues(alpha: 0.22),
                  ),
                ),
                Positioned(
                  left: -24,
                  bottom: -34 + floatOffset / 2,
                  child: _GlowOrb(
                    size: 124,
                    color: accentColors.last.withValues(alpha: 0.20),
                  ),
                ),
                Positioned(
                  right: 4 + floatOffset,
                  top: 10,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.24,
                      child: SizedBox(
                        width: 170,
                        height: 160,
                        child: SvgPicture.string(_courseBackdropSvg),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            accentColors.first.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.white.withValues(alpha: 0.06),
                    highlightColor: Colors.white.withValues(alpha: 0.04),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    collapsedIconColor: detailsColor2,
                    iconColor: detailsColor2,
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            accentColors.first,
                            detailsColor1.withValues(alpha: 0.86),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColors.first.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: detailsColor2, size: 24),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: detailsColor2,
                                  height: 1.08,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: detailsColor2.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: detailsColor2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              '$completedLessons/$totalLessons leçons',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${course.chapters.length} modules',
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.06,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              detailsColor2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        decoration: BoxDecoration(
                          color: panelTone.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: detailsColor1.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          children: _buildChapterContent(course, isAdmin),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _countCourseLessons(CourseContent course) {
    return course.chapters.fold(
      0,
      (total, chapter) => total + _countChapterLessons(chapter),
    );
  }

  int _countCompletedCourseLessons(CourseContent course) {
    return course.chapters.fold(
      0,
      (total, chapter) => total + _countCompletedChapterLessons(chapter),
    );
  }

  int _countChapterLessons(ChapterContent chapter) {
    return chapter.lessons.length +
        chapter.subChapters.fold(
          0,
          (total, subChapter) => total + _countChapterLessons(subChapter),
        );
  }

  int _countCompletedChapterLessons(ChapterContent chapter) {
    final localCompleted =
        chapter.lessons
            .where((lesson) => _completedLessons.contains(lesson.title))
            .length;
    return localCompleted +
        chapter.subChapters.fold(
          0,
          (total, subChapter) =>
              total + _countCompletedChapterLessons(subChapter),
        );
  }

  List<Widget> _buildChapterContent(CourseContent course, bool isAdmin) {
    List<Widget> widgets = [];
    bool previousCompleted = true;

    for (int i = 0; i < course.chapters.length; i++) {
      final chapter = course.chapters[i];
      final isChapterUnlocked = previousCompleted;

      widgets.add(
        _buildRecursiveChapterTile(
          chapter,
          i + 1,
          isChapterUnlocked,
          isAdmin,
          isTopLevel: true,
        ),
      );

      if (previousCompleted) {
        previousCompleted = _isChapterCompleted(chapter);
      }
    }
    return widgets;
  }

  Widget _buildRecursiveChapterTile(
    ChapterContent chapter,
    int index,
    bool unlocked,
    bool isAdmin, {
    bool isTopLevel = false,
  }) {
    List<Widget> children = [];
    bool currentUnlocked = unlocked;
    final isCompleted = _isChapterCompleted(chapter);
    final chapterLessons = _countChapterLessons(chapter);
    final chapterCompletedLessons = _countCompletedChapterLessons(chapter);
    final titleColor = detailsColor2;
    final bodyColor = Colors.black.withValues(alpha: 0.66);
    final mutedColor = Colors.black.withValues(alpha: 0.52);

    void buildLessons() {
      for (var lesson in chapter.lessons) {
        final isCompleted = _completedLessons.contains(lesson.title);
        final isLocked = !isAdmin && !currentUnlocked;

        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color:
                  isLocked
                      ? Colors.white.withValues(alpha: 0.42)
                      : Colors.white.withValues(alpha: 0.78),
              border: Border.all(
                color:
                    isCompleted
                        ? detailsColor1.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              title: Text(
                lesson.title,
                style: TextStyle(
                  color:
                      isLocked ? bodyColor.withValues(alpha: 0.52) : titleColor,
                  fontWeight: isLocked ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              subtitle:
                  isCompleted
                      ? Text(
                        'Validée',
                        style: TextStyle(
                          color: detailsColor2,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                      : null,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isLocked
                          ? Colors.white.withValues(alpha: 0.44)
                          : (isCompleted
                              ? detailsColor1.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.62)),
                ),
                child: Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : (isCompleted
                          ? Icons.check_rounded
                          : Icons.article_outlined),
                  size: 18,
                  color:
                      isLocked
                          ? bodyColor.withValues(alpha: 0.5)
                          : (isCompleted ? detailsColor2 : detailsColor2),
                ),
              ),
              trailing:
                  isLocked
                      ? null
                      : Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: detailsColor2.withValues(alpha: 0.58),
                      ),
              onTap:
                  isLocked
                      ? null
                      : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => LessonPage(
                                  lesson: lesson,
                                  onCompleted:
                                      (score, results) => _onLessonCompleted(
                                        lesson.title,
                                        score,
                                        results,
                                      ),
                                ),
                          ),
                        );
                      },
            ),
          ),
        );

        if (!isCompleted) {
          currentUnlocked = false;
        }
      }
    }

    void buildSubChapters() {
      for (int i = 0; i < chapter.subChapters.length; i++) {
        final sub = chapter.subChapters[i];
        children.add(
          _buildRecursiveChapterTile(
            sub,
            i + 1,
            currentUnlocked,
            isAdmin,
            isTopLevel: false,
          ),
        );
        if (!_isChapterCompleted(sub)) {
          currentUnlocked = false;
        }
      }
    }

    if (chapter.subChaptersFirst) {
      buildSubChapters();
      buildLessons();
    } else {
      buildLessons();
      buildSubChapters();
    }

    if (isTopLevel) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: unlocked ? 0.78 : 0.62),
              detailsColor1.withValues(alpha: 0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color:
                isCompleted
                    ? detailsColor1.withValues(alpha: 0.32)
                    : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            collapsedIconColor: detailsColor2,
            iconColor: detailsColor2,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color:
                        unlocked
                            ? titleColor
                            : bodyColor.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$chapterCompletedLessons/$chapterLessons leçons validées',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors:
                      isCompleted
                          ? [detailsColor1, const Color(0xFFFFA94D)]
                          : [
                            detailsColor1.withValues(alpha: 0.55),
                            Colors.white,
                          ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow:
                    isCompleted
                        ? [
                          BoxShadow(
                            color: detailsColor1.withValues(alpha: 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                        : null,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isCompleted ? Colors.black : Colors.black87,
                  ),
                ),
              ),
            ),
            children: children,
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.56),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            collapsedIconColor: detailsColor2,
            iconColor: detailsColor2,
            title: Text(
              chapter.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: titleColor,
              ),
            ),
            leading: Icon(
              Icons.account_tree_rounded,
              size: 19,
              color: detailsColor2.withValues(alpha: 0.72),
            ),
            children: children,
          ),
        ),
      );
    }
  }

  Widget _buildLockedChapterCard(String title, {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF5), Color(0xFFF4E2AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: detailsColor1.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: detailsColor1.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -12,
              child: Opacity(
                opacity: 0.10,
                child: SizedBox(
                  width: 150,
                  height: 140,
                  child: SvgPicture.string(_courseBackdropSvg),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: detailsColor2,
                ),
              ),
              subtitle:
                  subtitle == null
                      ? null
                      : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.62),
                            height: 1.35,
                          ),
                        ),
                      ),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.70),
                  border: Border.all(
                    color: detailsColor2.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: detailsColor2,
                  size: 22,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.72),
                  border: Border.all(
                    color: detailsColor2.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  'Verrouillé',
                  style: TextStyle(
                    color: detailsColor2.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelIndicator extends StatelessWidget {
  const _LevelIndicator();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('games')
              .doc('progress')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 78,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE6E8EB)),
            ),
          );
        }
        final data = snapshot.data?.data();
        final xp = (data?['xp'] as num?)?.toInt() ?? 0;
        final level = (xp / 100).floor() + 1;
        final progress = (xp % 100) / 100.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: RepaintBoundary(
                    child: CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      color: detailsColor2,
                      strokeWidth: 3,
                    ),
                  ),
                ),
                Text(
                  '$level',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: detailsColor2,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Niveau',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$xp XP',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.6,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            detailsColor1.withValues(alpha: 0.18),
            detailsColor2.withValues(alpha: 0.24),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: detailsColor1, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

const String _learningHeroSvg = '''
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="line" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F4D06F" stop-opacity="0.95"/>
      <stop offset="100%" stop-color="#B88AD8" stop-opacity="0.9"/>
    </linearGradient>
  </defs>
  <path d="M22 165 C40 124, 63 135, 86 96 S134 60, 157 93 194 84, 201 46" fill="none" stroke="url(#line)" stroke-width="7" stroke-linecap="round"/>
  <path d="M22 164 L22 190 L198 190" fill="none" stroke="#ffffff" stroke-opacity="0.28" stroke-width="3"/>
  <circle cx="86" cy="96" r="9" fill="#F4D06F" fill-opacity="0.94"/>
  <circle cx="157" cy="93" r="9" fill="#B88AD8" fill-opacity="0.94"/>
  <rect x="46" y="132" width="16" height="36" rx="8" fill="#ffffff" fill-opacity="0.12" stroke="#ffffff" stroke-opacity="0.22"/>
  <rect x="78" y="110" width="16" height="58" rx="8" fill="#ffffff" fill-opacity="0.12" stroke="#ffffff" stroke-opacity="0.22"/>
  <rect x="110" y="118" width="16" height="50" rx="8" fill="#ffffff" fill-opacity="0.12" stroke="#ffffff" stroke-opacity="0.22"/>
  <rect x="142" y="92" width="16" height="76" rx="8" fill="#ffffff" fill-opacity="0.12" stroke="#ffffff" stroke-opacity="0.22"/>
  <rect x="174" y="70" width="16" height="98" rx="8" fill="#ffffff" fill-opacity="0.12" stroke="#ffffff" stroke-opacity="0.22"/>
</svg>
''';

const String _courseBackdropSvg = '''
<svg viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <g fill="none" stroke="#ffffff" stroke-opacity="0.28" stroke-width="2.5">
    <path d="M18 126 C42 102, 58 112, 84 84 S128 54, 162 34"/>
    <path d="M26 144 L154 144"/>
    <path d="M38 144 L38 122"/>
    <path d="M70 144 L70 108"/>
    <path d="M102 144 L102 92"/>
    <path d="M134 144 L134 74"/>
  </g>
  <circle cx="84" cy="84" r="7" fill="#F4D06F" fill-opacity="0.85"/>
  <circle cx="134" cy="74" r="7" fill="#B88AD8" fill-opacity="0.85"/>
</svg>
''';

class _LearnLoadingView extends StatelessWidget {
  const _LearnLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _LearnSkeletonBlock(height: 92, radius: 22),
            SizedBox(height: 14),
            _LearnSkeletonBlock(height: 74, radius: 22),
            SizedBox(height: 16),
            _LearnSkeletonBlock(height: 150, radius: 18),
            SizedBox(height: 12),
            _LearnSkeletonBlock(height: 150, radius: 18),
            SizedBox(height: 12),
            _LearnSkeletonBlock(height: 120, radius: 18),
          ],
        ),
      ),
    );
  }
}

class _LearnErrorView extends StatelessWidget {
  const _LearnErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE6E8EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Contenu indisponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnSkeletonBlock extends StatelessWidget {
  const _LearnSkeletonBlock({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
  }
}

class _LessonHeaderCard extends StatelessWidget {
  const _LessonHeaderCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF33154E), Color(0xFF140A1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: detailsColor1.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: detailsColor2.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: detailsColor1.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -6,
            child: Opacity(
              opacity: 0.26,
              child: SizedBox(
                width: 132,
                height: 120,
                child: SvgPicture.string(_courseBackdropSvg),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      detailsColor1.withValues(alpha: 0.18),
                      detailsColor2.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: detailsColor1,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Leçon',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Lis, comprends, puis valide la leçon pour faire progresser ton parcours.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LessonPage extends StatelessWidget {
  final LessonContent lesson;
  final Function(int score, List<bool> results)? onCompleted;

  const LessonPage({super.key, required this.lesson, this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Cours'),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LessonHeaderCard(title: lesson.title),
            const SizedBox(height: 20),
            _FormattedLessonText(lesson.content),
            const SizedBox(height: 40),
            if (lesson.quizQuestions.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => QuizPage(
                              title: lesson.title,
                              questions: lesson.quizQuestions,
                              onCompleted: onCompleted,
                            ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.quiz_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Passer le Quizz',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: .2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FormattedLessonText extends StatelessWidget {
  final String text;

  const _FormattedLessonText(this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildBlocks(text),
    );
  }

  List<Widget> _buildBlocks(String text) {
    // 1. Extract figures to protect them from splitting
    final List<String> figures = [];
    final figureRegex = RegExp(
      r'\\begin\{figure\}.*?\\end\{figure\}',
      dotAll: true,
    );

    String processedText = text.replaceAllMapped(figureRegex, (match) {
      figures.add(match.group(0)!);
      return '@@FIGURE_${figures.length - 1}@@';
    });

    // 2. Split by double newlines
    final List<String> rawBlocks = processedText.split(RegExp(r'\n\s*\n'));
    final List<Widget> widgets = [];

    for (String block in rawBlocks) {
      if (block.trim().isEmpty) continue;

      // Restore figures
      if (block.contains('@@FIGURE_')) {
        final parts = block.split(RegExp(r'@@FIGURE_(\d+)@@'));
        final matches = RegExp(r'@@FIGURE_(\d+)@@').allMatches(block).toList();

        for (int i = 0; i < parts.length; i++) {
          if (parts[i].trim().isNotEmpty) {
            widgets.add(_buildParagraphOrSection(parts[i]));
          }
          if (i < matches.length) {
            final figIndex = int.parse(matches[i].group(1)!);
            widgets.add(_TikzFigureRenderer(figures[figIndex]));
          }
        }
        continue;
      }

      widgets.add(_buildParagraphOrSection(block));
    }

    return widgets;
  }

  Widget _buildParagraphOrSection(String text) {
    // Check for Section Title pattern: **Title**\nBody
    final sectionRegex = RegExp(r'^\s*\*\*(.*?)\*\*\s*\n(.*)', dotAll: true);
    final match = sectionRegex.firstMatch(text);

    if (match != null) {
      final title = match.group(1)!.trim();
      final body = match.group(2)!.trim();

      return Container(
        margin: const EdgeInsets.only(bottom: 24, top: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFCFBF7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: detailsColor1.withValues(alpha: 0.42),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: detailsColor2.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: detailsColor1.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [detailsColor2, Color(0xFF442164)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: detailsColor1,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF2D3436),
                  ),
                  children: _parseContent(body),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Regular paragraph
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
          bottomLeft: Radius.circular(10),
        ),
        border: Border.all(color: const Color(0xFFE9E2D2), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 30,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
                children: _parseContent(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseContent(String text) {
    final spans = <InlineSpan>[];
    int i = 0;
    while (i < text.length) {
      // 1. Block Math \[ ... \]
      if (i + 1 < text.length && text.substring(i, i + 2) == '\\[') {
        int end = text.indexOf('\\]', i + 2);
        if (end != -1) {
          spans.add(_formatMath(text.substring(i + 2, end), isBlock: true));
          i = end + 2;
          continue;
        }
      }

      // 2. Inline Math $ ... $
      if (text[i] == '\$') {
        int end = text.indexOf('\$', i + 1);
        if (end != -1) {
          spans.add(_formatMath(text.substring(i + 1, end), isBlock: false));
          i = end + 1;
          continue;
        }
      }

      // 3. Superscript \textsuperscript{...}
      if (i + 16 < text.length &&
          text.substring(i, i + 16) == '\\textsuperscript{') {
        int end = text.indexOf('}', i + 16);
        if (end != -1) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Transform.translate(
                offset: const Offset(0, -4),
                child: Text(
                  text.substring(i + 16, end),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
          i = end + 1;
          continue;
        }
      }

      // 4. Bold ** ... **
      if (i + 1 < text.length && text.substring(i, i + 2) == '**') {
        int end = text.indexOf('**', i + 2);
        if (end != -1) {
          spans.add(
            TextSpan(
              text: text.substring(i + 2, end),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          i = end + 2;
          continue;
        }
      }

      // 5. Bullet point * (followed by space)
      if (text[i] == '*' && i + 1 < text.length && text[i + 1] == ' ') {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
        i += 2;
        continue;
      }

      // 6. Figure Environment (TikZ)
      if (i + 14 < text.length &&
          text.substring(i, i + 14) == '\\begin{figure}') {
        int end = text.indexOf('\\end{figure}', i);
        if (end != -1) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _TikzFigureRenderer(text.substring(i, end + 12)),
            ),
          );
          i = end + 12;
          continue;
        }
      }

      // Regular text
      int nextSpecial = -1;
      List<int> candidates = [];
      if (text.contains('\\[', i)) {
        candidates.add(text.indexOf('\\[', i));
      }
      if (text.contains('\$', i)) {
        candidates.add(text.indexOf('\$', i));
      }
      if (text.contains('\\textsuperscript{', i)) {
        candidates.add(text.indexOf('\\textsuperscript{', i));
      }
      if (text.contains('**', i)) {
        candidates.add(text.indexOf('**', i));
      }
      if (text.contains('* ', i)) {
        candidates.add(text.indexOf('* ', i));
      }
      if (text.contains('\\begin{figure}', i)) {
        candidates.add(text.indexOf('\\begin{figure}', i));
      }

      if (candidates.isNotEmpty) {
        nextSpecial = candidates.reduce((min, val) => val < min ? val : min);
      }

      if (nextSpecial != -1) {
        if (nextSpecial > i) {
          spans.add(TextSpan(text: text.substring(i, nextSpecial)));
          i = nextSpecial;
        } else {
          // Prevent infinite loop if a special character is found but not handled
          spans.add(TextSpan(text: text.substring(i, i + 1)));
          i++;
        }
      } else {
        spans.add(TextSpan(text: text.substring(i)));
        i = text.length;
      }
    }
    return spans;
  }

  InlineSpan _formatMath(String latex, {bool isBlock = false}) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child:
          isBlock
              ? Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _LatexRenderer(latex),
                ),
              )
              : _LatexRenderer(latex),
    );
  }
}

class _LatexRenderer extends StatelessWidget {
  final String latex;
  const _LatexRenderer(this.latex);

  @override
  Widget build(BuildContext context) {
    String content = latex.trim();
    bool isBoxed = false;

    // Check for \boxed{...}
    if (content.startsWith(r'\boxed')) {
      final arg = _parseArg(content, r'\boxed'.length);
      if (arg.content.isNotEmpty && arg.endIndex == content.length) {
        isBoxed = true;
        content = arg.content;
      }
    }

    Widget child = _parseExpression(_normalizeLatex(content));

    if (isBoxed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1), // Amber 50
          border: Border.all(
            color: const Color(0xFFFFB300),
            width: 2,
          ), // Amber 600
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }
    return child;
  }

  String _normalizeLatex(String text) {
    return text
        .replaceAll(r'\_', '_')
        .replaceAll(r'\,', r'\ ')
        .replaceAll(r'\qquad', r'\quad\quad')
        .replaceAll('<->', '↔')
        .replaceAll('->', '→');
  }

  Widget _parseExpression(String text) {
    List<Widget> children = [];
    int i = 0;
    while (i < text.length) {
      if (text[i] == '\\') {
        int cmdEnd = i + 1;
        if (cmdEnd < text.length) {
          if (RegExp(r'[a-zA-Z]').hasMatch(text[cmdEnd])) {
            while (cmdEnd < text.length &&
                RegExp(r'[a-zA-Z]').hasMatch(text[cmdEnd])) {
              cmdEnd++;
            }
          } else {
            cmdEnd++;
          }
        }
        String cmd = text.substring(i, cmdEnd);

        if (cmd == r'\frac' || cmd == r'\dfrac') {
          _ArgResult arg1 = _parseArg(text, cmdEnd);
          _ArgResult arg2 = _parseArg(text, arg1.endIndex);
          children.add(_buildFraction(arg1.content, arg2.content));
          i = arg2.endIndex;
        } else if (cmd == r'\text' || cmd == r'\mathrm') {
          _ArgResult arg = _parseArg(text, cmdEnd);
          children.add(_parseExpression(arg.content));
          i = arg.endIndex;
        } else if (cmd == r'\left' || cmd == r'\right') {
          i = cmdEnd; // Skip, let next char be parsed
        } else if (cmd == r'\ln') {
          children.add(_buildMathText('ln'));
          i = cmdEnd;
        } else if (cmd == r'\times') {
          children.add(_buildSymbolText(' × '));
          i = cmdEnd;
        } else if (cmd == r'\approx') {
          children.add(_buildSymbolText(' ≈ '));
          i = cmdEnd;
        } else if (cmd == r'\pi') {
          children.add(_buildMathText('π'));
          i = cmdEnd;
        } else if (cmd == r'\alpha') {
          children.add(_buildMathText('α'));
          i = cmdEnd;
        } else if (cmd == r'\beta') {
          children.add(_buildMathText('β'));
          i = cmdEnd;
        } else if (cmd == r'\varepsilon') {
          children.add(_buildMathText('ε'));
          i = cmdEnd;
        } else if (cmd == r'\quad') {
          children.add(const SizedBox(width: 20));
          i = cmdEnd;
        } else if (cmd == r'\Rightarrow') {
          children.add(_buildSymbolText(' ⇒ '));
          i = cmdEnd;
        } else if (cmd == r'\dots') {
          children.add(_buildSymbolText('...'));
          i = cmdEnd;
        } else if (cmd == r'\;' || cmd == r'\ ') {
          children.add(const SizedBox(width: 6));
          i = cmdEnd;
        } else {
          i = cmdEnd;
        }
      } else if (text[i] == '^') {
        String supContent = "";
        int nextIdx = i + 1;
        if (nextIdx < text.length && text[nextIdx] == '{') {
          _ArgResult arg = _parseArg(text, i + 1);
          supContent = arg.content;
          i = arg.endIndex;
        } else if (nextIdx < text.length) {
          supContent = text[nextIdx];
          i = nextIdx + 1;
        } else {
          i++;
        }
        children.add(
          Transform.translate(
            offset: const Offset(0, -6),
            child: Text(
              supContent,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (text[i] == '_') {
        String subContent = "";
        int nextIdx = i + 1;
        if (nextIdx < text.length && text[nextIdx] == '{') {
          _ArgResult arg = _parseArg(text, i + 1);
          subContent = arg.content;
          i = arg.endIndex;
        } else if (nextIdx < text.length) {
          subContent = text[nextIdx];
          i = nextIdx + 1;
        } else {
          i++;
        }
        children.add(
          Transform.translate(
            offset: const Offset(0, 5),
            child: Text(
              subContent,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (text[i] == '{' || text[i] == '}') {
        i++;
      } else {
        int start = i;
        while (i < text.length &&
            text[i] != '\\' &&
            text[i] != '^' &&
            text[i] != '_' &&
            text[i] != '{' &&
            text[i] != '}') {
          i++;
        }
        children.add(Text(text.substring(start, i), style: _mathTextStyle));
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  Widget _buildMathText(String value) {
    return Text(value, style: _mathTextStyle);
  }

  Widget _buildSymbolText(String value) {
    return Text(
      value,
      style: _mathTextStyle.copyWith(fontStyle: FontStyle.normal),
    );
  }

  static const TextStyle _mathTextStyle = TextStyle(
    fontSize: 18,
    fontFamily: 'Serif',
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  Widget _buildFraction(String num, String den) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _parseExpression(num),
            Container(height: 1.5, color: Colors.black87),
            _parseExpression(den),
          ],
        ),
      ),
    );
  }

  _ArgResult _parseArg(String text, int startIndex) {
    int i = startIndex;
    while (i < text.length && text[i] == ' ') {
      i++;
    }
    if (i >= text.length || text[i] != '{') {
      return _ArgResult("", startIndex);
    }

    i++;
    int startContent = i;
    int balance = 1;
    while (i < text.length && balance > 0) {
      if (text[i] == '{') {
        balance++;
      }
      if (text[i] == '}') {
        balance--;
      }
      if (balance > 0) {
        i++;
      }
    }
    return _ArgResult(text.substring(startContent, i), i + 1);
  }
}

class _TikzFigureRenderer extends StatelessWidget {
  final String latex;
  const _TikzFigureRenderer(this.latex);

  @override
  Widget build(BuildContext context) {
    final caption = _extractCaption(latex);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6C5CE7), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (caption.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF6C5CE7),
              child: Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxWidth / 2.2),
                  painter: _TikzPainter(latex),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _extractCaption(String latex) {
    final start = latex.indexOf('\\caption{');
    if (start == -1) return '';
    final end = latex.indexOf('}', start);
    if (end == -1) return '';
    return latex.substring(start + 9, end);
  }
}

class _TikzPainter extends CustomPainter {
  final String latex;
  _TikzPainter(this.latex);

  @override
  void paint(Canvas canvas, Size size) {
    // Parsing simplifié pour le cas spécifique du canal haussier
    // Coordonnées approximatives du graphique TikZ fourni : X[-0.5, 13], Y[-0.5, 5.5]
    const double minX = -0.5;
    const double maxX = 13.0;
    const double minY = -2.0;
    const double maxY = 6.0;

    final double scaleX = size.width / (maxX - minX);
    final double scaleY = size.height / (maxY - minY);

    Offset map(double x, double y) {
      return Offset(
        (x - minX) * scaleX,
        size.height - (y - minY) * scaleY, // Inversion de l'axe Y
      );
    }

    // 0. Parse colors
    final Map<String, Color> definedColors = {
      'black': Colors.black,
      'white': Colors.white,
      'red': Colors.red,
      'green': Colors.green,
      'blue': Colors.blue,
    };
    final colorDefRegex = RegExp(
      r'\\definecolor\{(\w+)\}\{RGB\}\{(\d+),\s*(\d+),\s*(\d+)\}',
    );
    for (final match in colorDefRegex.allMatches(latex)) {
      definedColors[match.group(1)!] = Color.fromARGB(
        255,
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
      );
    }

    // 1. Parse coordinates definitions
    final Map<String, Offset> definedCoords = {};
    final coordDefRegex = RegExp(
      r'\\coordinate\s*\((.*?)\)\s*at\s*\((-?[\d\.]+)\s*,\s*(-?[\d\.]+)\s*\);',
    );
    for (final match in coordDefRegex.allMatches(latex)) {
      final name = match.group(1) ?? '';
      final x = double.tryParse(match.group(2) ?? '0') ?? 0;
      final y = double.tryParse(match.group(3) ?? '0') ?? 0;
      definedCoords[name] = map(x, y);
    }

    // Regex pour extraire les commandes \draw et \path
    final drawRegex = RegExp(
      r'\\(draw|path)\s*\[(.*?)\]\s*(.*?);',
      dotAll: true,
    );
    // Updated regex to handle (x,y) and (Name)
    final coordRegex = RegExp(
      r'\(\s*(-?[\d\.]+)\s*,\s*(-?[\d\.]+)\s*\)|\(\s*([a-zA-Z0-9_]+)\s*\)',
    );

    for (final match in drawRegex.allMatches(latex)) {
      final type = match.group(1) ?? 'draw';
      final style = match.group(2) ?? '';
      final content = match.group(3) ?? '';
      final points = <Offset>[];

      // Parse colors and style
      Color? strokeColor;
      Color? fillColor;
      double strokeWidth = 1.5;
      bool hasArrow = false;

      if (style.contains('draw=')) {
        final colorMatch = RegExp(r'draw=([a-zA-Z0-9_]+)').firstMatch(style);
        if (colorMatch != null) {
          strokeColor = definedColors[colorMatch.group(1)];
        }
      } else if (type == 'draw') {
        strokeColor = Colors.black;
      }

      if (style.contains('fill=')) {
        final colorMatch = RegExp(r'fill=([a-zA-Z0-9_]+)').firstMatch(style);
        if (colorMatch != null) {
          fillColor = definedColors[colorMatch.group(1)];
        }
      }

      if (style.contains('arrow')) {
        hasArrow = true;
      }

      if (style.contains('price')) {
        strokeColor = Colors.blue.shade700;
        strokeWidth = 1.5;
      }
      if (style.contains('wick') ||
          style.contains('arrow') ||
          style.contains('line width=3pt')) {
        strokeWidth = 3.0;
      }

      for (final cm in coordRegex.allMatches(content)) {
        if (cm.group(1) != null && cm.group(2) != null) {
          // Explicit coordinate (x,y)
          final x = double.tryParse(cm.group(1) ?? '0') ?? 0;
          final y = double.tryParse(cm.group(2) ?? '0') ?? 0;
          points.add(map(x, y));
        } else if (cm.group(3) != null) {
          // Named coordinate (Name)
          final name = cm.group(3)!;
          if (definedCoords.containsKey(name)) {
            points.add(definedCoords[name]!);
          }
        }
      }

      if (points.length > 1) {
        final path = Path();

        if (content.contains('rectangle') && points.length >= 2) {
          path.addRect(Rect.fromPoints(points[0], points[1]));
        } else {
          path.moveTo(points[0].dx, points[0].dy);
          for (int i = 1; i < points.length; i++) {
            path.lineTo(points[i].dx, points[i].dy);
          }
        }

        // Draw Fill
        if (fillColor != null) {
          canvas.drawPath(
            path,
            Paint()
              ..color = fillColor
              ..style = PaintingStyle.fill,
          );
        }

        // Draw Stroke
        if (strokeColor != null) {
          final strokePaint =
              Paint()
                ..color = strokeColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth;
          if (style.contains('dashed') ||
              style.contains('leader') ||
              style.contains('inner') ||
              style.contains('proj')) {
            canvas.drawPath(_dashPath(path, 5, 5), strokePaint);
          } else {
            canvas.drawPath(path, strokePaint);
          }
          // Draw arrowhead if needed
          if (hasArrow && points.length >= 2) {
            _drawArrowhead(
              canvas,
              points[points.length - 2],
              points.last,
              Paint()
                ..color = strokeColor
                ..style = PaintingStyle.fill,
            );
          }
        }
      }
    }

    // Regex pour extraire les commandes \node
    final nodeRegex = RegExp(
      r'\\node\[(.*?)\]\s*at\s*\((-?[\d\.]+),(-?[\d\.]+)\)\s*\{(.*?)\};',
      dotAll: true,
    );
    for (final match in nodeRegex.allMatches(latex)) {
      final style = match.group(1) ?? '';
      final x = double.tryParse(match.group(2) ?? '0') ?? 0;
      final y = double.tryParse(match.group(3) ?? '0') ?? 0;
      String text = match.group(4) ?? '';
      text = text.replaceAll(r'\n', '\n').replaceAll(r'\\', '\n');

      double rotation = 0;
      if (style.contains('rotate=')) {
        final rotMatch = RegExp(r'rotate=(-?[\d\.]+)').firstMatch(style);
        if (rotMatch != null) {
          // TikZ rotation (degres anti-horaire) -> Flutter rotation (radians horaire)
          // Comme l'axe Y est inversé visuellement, une pente montante reste montante,
          // mais la rotation doit suivre le repère visuel.
          // Une rotation positive TikZ (montante) correspond à une rotation négative en radians Flutter.
          rotation =
              -(double.tryParse(rotMatch.group(1)!) ?? 0) * (math.pi / 180);
        }
      }

      TextAlign textAlign = TextAlign.left;
      if (style.contains('anchor=east')) {
        textAlign = TextAlign.right;
      } else if (style.contains('anchor=center')) {
        textAlign = TextAlign.center;
      }

      final textSpan = TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: textAlign,
      );
      textPainter.layout();

      final pos = map(x, y);

      double offsetX = -textPainter.width / 2;
      final double offsetY = -textPainter.height / 2;

      if (style.contains('anchor=east')) {
        offsetX = -textPainter.width;
      } else if (style.contains('anchor=west')) {
        offsetX = 0;
      }

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      // Centrer le texte sur le point
      textPainter.paint(canvas, Offset(offsetX, offsetY));
      canvas.restore();
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const double arrowSize = 10.0;
    const double arrowAngle = math.pi / 6; // 30 degrees

    final double angle = math.atan2(to.dy - from.dy, to.dx - from.dx);

    final Path path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * math.cos(angle - arrowAngle),
      to.dy - arrowSize * math.sin(angle - arrowAngle),
    );
    path.lineTo(
      to.dx - arrowSize * math.cos(angle + arrowAngle),
      to.dy - arrowSize * math.sin(angle + arrowAngle),
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  Path _dashPath(Path source, double dashArray, double dashSpace) {
    final Path dest = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashArray : dashSpace;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArgResult {
  final String content;
  final int endIndex;
  _ArgResult(this.content, this.endIndex);
}

class QuizPage extends StatefulWidget {
  final String title;
  final List<Question> questions;
  final Function(int score, List<bool> results)? onCompleted;

  const QuizPage({
    super.key,
    required this.title,
    required this.questions,
    this.onCompleted,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentIndex = 0;
  int _score = 0;
  bool _finished = false;
  int? _selectedAnswerIndex;
  bool _isValidated = false;
  final List<bool> _results = [];

  void _onOptionSelected(int index) {
    if (_isValidated) return;

    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  void _validateAnswer() {
    setState(() {
      _isValidated = true;
      final isCorrect =
          _selectedAnswerIndex ==
          widget.questions[_currentIndex].correctAnswerIndex;
      if (isCorrect) {
        _score++;
      }
      _results.add(isCorrect);
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _isValidated = false;
      });
    } else {
      setState(() {
        _finished = true;
      });
      widget.onCompleted?.call(_score, _results);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 20),
              Text(
                'Score: $_score / ${widget.questions.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour à la leçon'),
              ),
            ],
          ),
        ),
      );
    }

    final question = widget.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Quizz (${_currentIndex + 1}/${widget.questions.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.question,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ...List.generate(question.options.length, (index) {
              final isCorrect = index == question.correctAnswerIndex;
              final isSelected = index == _selectedAnswerIndex;

              Color? backgroundColor;
              Color borderColor = Colors.black12;
              Color textColor = Colors.black87;
              FontWeight fontWeight = FontWeight.normal;

              if (_isValidated) {
                if (isCorrect) {
                  backgroundColor = Colors.green.withValues(alpha: 0.1);
                  borderColor = Colors.green;
                  textColor = Colors.green.shade800;
                  fontWeight = FontWeight.bold;
                } else if (isSelected) {
                  backgroundColor = Colors.red.withValues(alpha: 0.1);
                  borderColor = Colors.red;
                  textColor = Colors.red.shade800;
                  fontWeight = FontWeight.bold;
                }
              } else if (isSelected) {
                backgroundColor = Colors.black.withValues(alpha: 0.05);
                borderColor = Colors.black87;
                fontWeight = FontWeight.w600;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: () => _onOptionSelected(index),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: backgroundColor,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    question.options[index],
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
              );
            }),
            if (_selectedAnswerIndex != null) ...[
              const SizedBox(height: 24),
              InkWell(
                onTap: _isValidated ? _nextQuestion : _validateAnswer,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [detailsColor1, detailsColor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _isValidated
                          ? (_currentIndex < widget.questions.length - 1
                              ? 'Question suivante'
                              : 'Voir les résultats')
                          : 'Valider',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
