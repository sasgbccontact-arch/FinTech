import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fintech/core/constants.dart';

import '../../models/quiz_question.dart';

class QuizPageResult {
  final int score;
  final int total;
  final List<int?> answers;

  const QuizPageResult({
    required this.score,
    required this.total,
    required this.answers,
  });
}

class QuizPage extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String title;

  const QuizPage({
    super.key,
    required this.questions,
    required this.title,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int? _selectedChoice;
  late final List<int?> _answers;
  bool _showSummary = false;

  late final AnimationController _nextCtl;
  late final Animation<double> _nextAnim;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, null);
    _nextCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _nextAnim = CurvedAnimation(parent: _nextCtl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _nextCtl.dispose();
    super.dispose();
  }

  int get _computedScore {
    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_answers[i] != null && _answers[i] == widget.questions[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  void _selectChoice(int choiceIdx) {
    if (_selectedChoice != null) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedChoice = choiceIdx);
    _nextCtl.forward(from: 0);
  }

  void _goNext() {
    HapticFeedback.lightImpact();
    _answers[_currentIndex] = _selectedChoice;
    _nextCtl.reset();
    if (_currentIndex + 1 >= widget.questions.length) {
      setState(() => _showSummary = true);
    } else {
      setState(() {
        _currentIndex++;
        _selectedChoice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          if (!_showSummary)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.questions.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _showSummary ? _buildSummary() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final q = widget.questions[_currentIndex];
    final total = widget.questions.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: _currentIndex / total,
          backgroundColor: Colors.black.withValues(alpha: 0.06),
          valueColor: const AlwaysStoppedAnimation<Color>(detailsColor1),
          minHeight: 3,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 4),
              _buildQuestionCard(q),
              const SizedBox(height: 16),
              ...List.generate(q.choices.length, (i) => _buildChoiceTile(q, i)),
              if (_selectedChoice != null) ...[
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _nextAnim,
                  child: _buildNextButton(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(QuizQuestion q) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _typeIcon(q.type),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _typeLabel(q.type),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black38,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            q.prompt,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceTile(QuizQuestion q, int choiceIdx) {
    final answered = _selectedChoice != null;
    final isSelected = _selectedChoice == choiceIdx;
    final isCorrect = q.correctIndex == choiceIdx;

    Color borderColor = Colors.black.withValues(alpha: 0.12);
    Color bgColor = Colors.white;
    Color labelColor = textColor;
    Widget? trailing;

    if (answered) {
      if (isCorrect) {
        borderColor = const Color(0xFF1FC182);
        bgColor = const Color(0xFF1FC182).withValues(alpha: 0.08);
        labelColor = const Color(0xFF1FC182);
        trailing = const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF1FC182),
          size: 20,
        );
      } else if (isSelected) {
        borderColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.08);
        labelColor = Colors.redAccent;
        trailing = const Icon(
          Icons.cancel_rounded,
          color: Colors.redAccent,
          size: 20,
        );
      } else {
        bgColor = Colors.black.withValues(alpha: 0.02);
        labelColor = Colors.black38;
        borderColor = Colors.black.withValues(alpha: 0.06);
      }
    }

    Color badgeBg = Colors.black.withValues(alpha: 0.05);
    Color badgeFg = Colors.black54;
    if (answered && isCorrect) {
      badgeBg = const Color(0xFF1FC182).withValues(alpha: 0.15);
      badgeFg = const Color(0xFF1FC182);
    } else if (answered && isSelected) {
      badgeBg = Colors.redAccent.withValues(alpha: 0.15);
      badgeFg = Colors.redAccent;
    } else if (answered) {
      badgeBg = Colors.black.withValues(alpha: 0.04);
      badgeFg = Colors.black26;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: answered ? null : () => _selectChoice(choiceIdx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: answered
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + choiceIdx),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.choices[choiceIdx],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                    height: 1.3,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex + 1 >= widget.questions.length;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _goNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          isLast ? 'Voir le résultat →' : 'Question suivante →',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final score = _computedScore;
    final total = widget.questions.length;
    final ratio = total > 0 ? score / total : 0.0;

    String emoji;
    String headline;
    String subline;
    if (ratio >= 0.8) {
      emoji = '🏆';
      headline = 'Excellent !';
      subline = 'Tu maîtrises bien cette session.';
    } else if (ratio >= 0.5) {
      emoji = '👍';
      headline = 'Bien joué !';
      subline = 'Encore un effort pour viser le sans-faute.';
    } else {
      emoji = '💡';
      headline = 'Pas grave !';
      subline = 'Tu peux rejouer quand tu veux.';
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: detailsColor2.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score/$total',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'correct',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          emoji,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 36),
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subline,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 32),
        ...List.generate(widget.questions.length, (i) {
          final q = widget.questions[i];
          final correct = _answers[i] == q.correctIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: correct
                      ? const Color(0xFF1FC182).withValues(alpha: 0.4)
                      : Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: correct ? const Color(0xFF1FC182) : Colors.redAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.prompt,
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '→ ${q.choices[q.correctIndex]}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(
              QuizPageResult(
                score: score,
                total: total,
                answers: List<int?>.from(_answers),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Terminer',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  IconData _typeIcon(QuizQuestionType type) {
    switch (type) {
      case QuizQuestionType.source:
        return Icons.newspaper_rounded;
      case QuizQuestionType.date:
        return Icons.calendar_today_rounded;
      case QuizQuestionType.theme:
        return Icons.category_rounded;
      case QuizQuestionType.country:
        return Icons.public_rounded;
      case QuizQuestionType.title:
        return Icons.title_rounded;
      case QuizQuestionType.cloze:
        return Icons.edit_note_rounded;
      case QuizQuestionType.entity:
        return Icons.person_search_rounded;
      case QuizQuestionType.number:
        return Icons.bar_chart_rounded;
      case QuizQuestionType.keyword:
        return Icons.key_rounded;
      case QuizQuestionType.trueSentence:
        return Icons.fact_check_rounded;
      case QuizQuestionType.association:
        return Icons.link_rounded;
    }
  }

  String _typeLabel(QuizQuestionType type) {
    switch (type) {
      case QuizQuestionType.source:
        return 'SOURCE';
      case QuizQuestionType.date:
        return 'DATE';
      case QuizQuestionType.theme:
        return 'THÈME';
      case QuizQuestionType.country:
        return 'PAYS';
      case QuizQuestionType.title:
        return 'TITRE';
      case QuizQuestionType.cloze:
        return 'LACUNE';
      case QuizQuestionType.entity:
        return 'ACTEUR';
      case QuizQuestionType.number:
        return 'CHIFFRE';
      case QuizQuestionType.keyword:
        return 'MOT-CLÉ';
      case QuizQuestionType.trueSentence:
        return 'VRAI/FAUX';
      case QuizQuestionType.association:
        return 'PASSAGE';
    }
  }
}
