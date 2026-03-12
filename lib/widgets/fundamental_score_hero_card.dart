import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/utils/fundamental_score_presenter.dart';

class FundamentalScoreHeroCard extends StatelessWidget {
  const FundamentalScoreHeroCard({
    super.key,
    required this.presentation,
    this.onTap,
  });

  final FundamentalScorePresentation presentation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final verdictColor = _verdictToneColor(presentation.verdictLabel);
    final score = presentation.score?.clamp(0, 100).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: presentation.canOpenDetails ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: detailsColor1.withValues(alpha: .28)),
            boxShadow: [
              BoxShadow(
                color: detailsColor2.withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: switch (presentation.state) {
                  FundamentalScoreHeroState.loading => _LoadingContent(
                    key: const ValueKey<String>('loading'),
                    title: presentation.title,
                    subtitle: presentation.subtitle,
                  ),
                  FundamentalScoreHeroState.scored => _ScoredContent(
                    key: const ValueKey<String>('scored'),
                    presentation: presentation,
                    score: score ?? 0,
                    verdictColor: verdictColor,
                  ),
                  FundamentalScoreHeroState.unavailable => _UnavailableContent(
                    key: const ValueKey<String>('unavailable'),
                    title: presentation.title,
                    subtitle: presentation.subtitle,
                    icon: Icons.layers_clear_rounded,
                  ),
                  FundamentalScoreHeroState.error => _UnavailableContent(
                    key: const ValueKey<String>('error'),
                    title: presentation.title,
                    subtitle: presentation.subtitle,
                    icon: Icons.error_outline_rounded,
                  ),
                },
              ),
              if (presentation.disclaimer.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  width: double.infinity,
                  color: detailsColor1.withValues(alpha: .14),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: detailsColor2.withValues(alpha: .72),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        presentation.disclaimer,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.35,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _verdictToneColor(String? verdict) {
    switch (verdict) {
      case 'Lecture élevée':
        return const Color(0xFF8C6A12);
      case 'Lecture solide':
        return detailsColor2;
      case 'Lecture mitigée':
        return const Color(0xFF6F657D);
      case 'Lecture fragile':
        return const Color(0xFF4E3A66);
      default:
        return detailsColor2;
    }
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: CircularProgressIndicator(
                strokeWidth: 7,
                valueColor: AlwaysStoppedAnimation<Color>(
                  detailsColor2.withValues(alpha: .88),
                ),
                backgroundColor: detailsColor1.withValues(alpha: .18),
              ),
            ),
            const Icon(Icons.auto_graph_rounded, color: textColor),
          ],
        ),
      ],
    );
  }
}

class _ScoredContent extends StatelessWidget {
  const _ScoredContent({
    super.key,
    required this.presentation,
    required this.score,
    required this.verdictColor,
  });

  final FundamentalScorePresentation presentation;
  final double score;
  final Color verdictColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Note fondamentale',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: score),
                duration: const Duration(milliseconds: 780),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return RichText(
                    text: TextSpan(
                      style: const TextStyle(color: textColor),
                      children: [
                        TextSpan(
                          text: value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const TextSpan(
                          text: '/100',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    label: presentation.verdictLabel ?? 'Lecture informative',
                    background: verdictColor.withValues(alpha: .12),
                    foreground: verdictColor,
                  ),
                  if (presentation.confidenceLabel != null)
                    _HeroChip(
                      label: presentation.confidenceLabel!,
                      background: detailsColor1.withValues(alpha: .14),
                      foreground: textColor,
                    ),
                ],
              ),
              if (presentation.summary != null) ...[
                const SizedBox(height: 10),
                Text(
                  presentation.summary!,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            _AnimatedScoreRing(score: score, color: verdictColor),
            if (presentation.canOpenDetails) ...[
              const SizedBox(height: 8),
              const Text(
                'Détails',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _UnavailableContent extends StatelessWidget {
  const _UnavailableContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: detailsColor1.withValues(alpha: .32)),
            color: detailsColor1.withValues(alpha: .08),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: detailsColor2, size: 30),
        ),
      ],
    );
  }
}

class _AnimatedScoreRing extends StatelessWidget {
  const _AnimatedScoreRing({required this.score, required this.color});

  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: detailsColor1.withValues(alpha: .20),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'lecture',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      ),
    );
  }
}
