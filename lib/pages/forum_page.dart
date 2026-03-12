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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Forum',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snapshot) {
            final user = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
              children: [
                if (user == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _GradientInfoCard(
                      text:
                          'Tu peux explorer le hub social, mais il faut être connecté pour envoyer des demandes d’amis et participer au forum boursier.',
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _ForumSectionHeader(
                    title: 'Espace social',
                    subtitle:
                        'Profils publics, badges, demandes d’amis et classements globaux ou entre amis.',
                  ),
                ),
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: SocialSpotlightCard(
                      currentUserId: user.uid,
                      onOpenCommunity: _openCommunitySheet,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _GradientInfoCard(
                      text:
                          'Connecte-toi pour activer le social, les amis et les classements personnalisés.',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _ForumPulseEntryCard(
                    canCompose: user != null,
                    onTap: _openForumSheet,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _ForumSectionHeader(
                    title: 'Communauté',
                    subtitle:
                        'Passe du classement social au duel hebdo sans garder l’ancien système de mini-jeux.',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _ForumCommunityCard(),
                ),
              ],
            );
          },
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

class _ForumSectionHeader extends StatelessWidget {
  const _ForumSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12.8,
            height: 1.4,
          ),
        ),
      ],
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

class _ForumCommunityCard extends StatelessWidget {
  const _ForumCommunityCard();

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

            return InkWell(
              onTap:
                  () => showCupertinoModalBottomSheet(
                    context: context,
                    expand: true,
                    builder: (_) => const CommunityPage(),
                  ),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6E8EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [detailsColor1, detailsColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.sports_kabaddi_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duel hebdo',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
