import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/features/duel/duel_models.dart';
import 'package:fintech/features/forum/forum_boursier_sheet.dart';
import 'package:fintech/features/social/social_spotlight_card.dart';

import 'community_page.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  Future<void> _openCommunitySheet() async {
    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder: (_) => const CommunityPage(),
    );
  }

  Future<void> _openForumSheet() async {
    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder: (_) => const ForumBoursierSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _SocialPageHeader(),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SocialTabStrip(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _SocialTabView(
                          child:
                              user != null
                                  ? SocialSpotlightCard(
                                    currentUserId: user.uid,
                                    onOpenCommunity: _openCommunitySheet,
                                  )
                                  : const _GradientInfoCard(
                                    text:
                                        'Connecte-toi pour activer le classement social, les amis et les badges personnalisés.',
                                  ),
                        ),
                        _SocialTabView(
                          child: _ForumPulseEntryCard(
                            canCompose: user != null,
                            onTap: _openForumSheet,
                          ),
                        ),
                        _SocialTabView(
                          child: _DuelPulseEntryCard(
                            onTap: _openCommunitySheet,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GradientInfoCard extends StatelessWidget {
  const _GradientInfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _SocialPageHeader extends StatelessWidget {
  const _SocialPageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Social',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Classement, forum et duel réunis dans le même hub.',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.35),
        ),
      ],
    );
  }
}

class _SocialTabStrip extends StatelessWidget {
  const _SocialTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        tabs: [Tab(text: 'Classement'), Tab(text: 'Forum'), Tab(text: 'Duel')],
      ),
    );
  }
}

class _SocialTabView extends StatelessWidget {
  const _SocialTabView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomScrollInset = MediaQuery.of(context).padding.bottom + 118;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12, 14, 12, bottomScrollInset),
      children: [child],
    );
  }
}

class _ForumPulseEntryCard extends StatefulWidget {
  const _ForumPulseEntryCard({required this.canCompose, required this.onTap});

  final bool canCompose;
  final VoidCallback onTap;

  @override
  State<_ForumPulseEntryCard> createState() => _ForumPulseEntryCardState();
}

class _ForumPulseEntryCardState extends State<_ForumPulseEntryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir le flux du forum boursier',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final phase = _controller.value;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [detailsColor1, detailsColor2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ForumPulsePainter(progress: phase),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10 + (math.sin(phase * math.pi * 2) * 4),
                    right: 8,
                    child: const _ForumFloatingPill(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Débats live',
                    ),
                  ),
                  Positioned(
                    bottom: 10 + (math.cos(phase * math.pi * 2) * 5),
                    right: 56,
                    child: const _ForumFloatingPill(
                      icon: Icons.show_chart_rounded,
                      label: 'Courbes & idées',
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.forum_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Forum boursier',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.canCompose
                            ? 'Passe du social au forum riche pour publier, réagir, signaler un message ou mettre en avant un post important.'
                            : 'Explore les échanges, les courbes partagées et les idées de marché avant de participer.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const _ForumPulseTag(label: 'Messages'),
                          const _ForumPulseTag(label: 'Votes & réactions'),
                          const _ForumPulseTag(label: 'Pins & signalements'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.canCompose
                                    ? 'Touchez pour ouvrir directement le forum riche.'
                                    : 'Touchez pour lire les conversations actives.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ForumPulsePainter extends CustomPainter {
  const _ForumPulsePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 1;
    final curvePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);

    final baseY = size.height * 0.68;
    final amplitude = size.height * 0.07;
    final phase = progress * math.pi * 2;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (0.22 + (i * 0.18));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i <= 32; i++) {
      final t = i / 32;
      final x = size.width * t;
      final y =
          baseY -
          amplitude * math.sin((t * math.pi * 2.2) + phase) -
          (t * size.height * 0.08);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, curvePaint);
    for (final t in <double>[0.24, 0.58, 0.86]) {
      final x = size.width * t;
      final y =
          baseY -
          amplitude * math.sin((t * math.pi * 2.2) + phase) -
          (t * size.height * 0.08);
      canvas.drawCircle(Offset(x, y), 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForumPulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ForumFloatingPill extends StatelessWidget {
  const _ForumFloatingPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumPulseTag extends StatelessWidget {
  const _ForumPulseTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _DuelPulseEntryCard extends StatefulWidget {
  const _DuelPulseEntryCard({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_DuelPulseEntryCard> createState() => _DuelPulseEntryCardState();
}

class _DuelPulseEntryCardState extends State<_DuelPulseEntryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDuelsStream =
        FirebaseFirestore.instance
            .collection('duels')
            .where('status', isEqualTo: 'active')
            .limit(20)
            .snapshots();
    final currentUser = FirebaseAuth.instance.currentUser;
    final ownProfileStream =
        currentUser == null
            ? null
            : FirebaseFirestore.instance
                .collection('duel_profiles')
                .doc(currentUser.uid)
                .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: activeDuelsStream,
      builder: (context, duelSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ownProfileStream,
          builder: (context, ownSnapshot) {
            final openCount = duelSnapshot.data?.docs.length ?? 0;
            final ownProfile =
                currentUser == null
                    ? null
                    : DuelProfile.fromDoc(
                      ownSnapshot.data,
                      fallbackUid: currentUser.uid,
                    );
            final subtitle = switch (ownProfile?.state) {
              'pending_received' =>
                'Une invitation duel t’attend. Ouvre le hub pour répondre.',
              'pending_sent' =>
                'Ton dernier matchmaking attend une réponse adverse.',
              'active_duel' => 'Tu as un duel actif. Le dashboard est prêt.',
              _ =>
                openCount > 0
                    ? '$openCount duel(s) actif(s) dans la communauté.'
                    : 'Lance le duel hebdo pour affronter un joueur proche de ton niveau.',
            };
            final statusLabel = switch (ownProfile?.state) {
              'pending_received' => 'À répondre',
              'pending_sent' => 'En attente',
              'active_duel' => 'En cours',
              _ => openCount > 0 ? '$openCount actif(s)' : 'Matchmaking',
            };

            return Semantics(
              button: true,
              label: 'Ouvrir le hub duel hebdomadaire',
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(28),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final phase = _controller.value;
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [detailsColor1, detailsColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: detailsColor1.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _DuelArenaPainter(progress: phase),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4 + (math.sin(phase * math.pi * 2) * 5),
                            right: 4,
                            child: _ForumFloatingPill(
                              icon: Icons.local_fire_department_rounded,
                              label: statusLabel,
                            ),
                          ),
                          Positioned(
                            bottom: 54 + (math.cos(phase * math.pi * 2) * 4),
                            right: 18,
                            child: const _ForumFloatingPill(
                              icon: Icons.query_stats_rounded,
                              label: 'Dashboard live',
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.20,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.sports_kabaddi_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Duel hebdo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Un face-à-face de portefeuille, une semaine pour creuser l’écart.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  _ForumPulseTag(label: 'Radar adverse'),
                                  _ForumPulseTag(label: 'Révélations'),
                                  _ForumPulseTag(label: 'Score live'),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Ouvrir le hub duel',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DuelArenaPainter extends CustomPainter {
  const _DuelArenaPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final orbitPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.13);
    final glowPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.28);
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);

    final center = Offset(size.width * 0.82, size.height * 0.28);
    final outerRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.40,
      height: size.height * 0.42,
    );
    final innerRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.24,
      height: size.height * 0.24,
    );

    canvas.drawOval(outerRect, orbitPaint);
    canvas.drawOval(innerRect, orbitPaint);
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.78),
      size.width * 0.12,
      orbitPaint,
    );

    final orbitStart = progress * math.pi * 2;
    canvas.drawArc(outerRect, orbitStart, math.pi * 0.95, false, glowPaint);
    canvas.drawArc(
      innerRect,
      -orbitStart * 1.2,
      math.pi * 0.78,
      false,
      glowPaint,
    );

    final movingOuter = Offset(
      center.dx + (outerRect.width / 2) * math.cos(orbitStart),
      center.dy + (outerRect.height / 2) * math.sin(orbitStart),
    );
    final movingInner = Offset(
      center.dx + (innerRect.width / 2) * math.cos(-orbitStart * 1.2),
      center.dy + (innerRect.height / 2) * math.sin(-orbitStart * 1.2),
    );

    canvas.drawCircle(movingOuter, 4.5, dotPaint);
    canvas.drawCircle(movingInner, 3.5, dotPaint);

    final bottomPulse = Offset(
      size.width * 0.20 + size.width * 0.12 * math.cos(orbitStart * 0.7),
      size.height * 0.78 + size.width * 0.12 * math.sin(orbitStart * 0.7),
    );
    canvas.drawCircle(bottomPulse, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DuelArenaPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
