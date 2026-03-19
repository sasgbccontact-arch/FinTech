import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:sensors_plus/sensors_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:fintech/core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyNewsChoicePage — écran de choix "bluffant"
//
// - Split screen en forme d'éclair, légèrement incliné.
// - Drag horizontal (et micro-oscillation idle) fait bouger la frontière.
// - 1er tap: arme la sélection + décale la frontière (10–20%).
// - 2e tap sur le même côté: confirme + animation + callback.
// - Glass + glows animés, palette cohérente.
// ─────────────────────────────────────────────────────────────────────────────

const _accentGradient = LinearGradient(
  colors: [detailsColor1, detailsColor2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class DailyNewsChoicePage extends StatefulWidget {
  final VoidCallback onPickActus;
  final VoidCallback onPickMonde;
  final String actusSubtitle;
  final String mondeSubtitle;

  const DailyNewsChoicePage({
    super.key,
    required this.onPickActus,
    required this.onPickMonde,
    required this.actusSubtitle,
    required this.mondeSubtitle,
  });

  @override
  State<DailyNewsChoicePage> createState() => _DailyNewsChoicePageState();
}

class _DailyNewsChoicePageState extends State<DailyNewsChoicePage>
    with TickerProviderStateMixin {
  // 0..1 position de la séparation (0 = tout gauche, 1 = tout droite)
  double _split = 0.5;
  int? _armedSide; // 0 = gauche, 1 = droite
  bool _confirming = false;
  static const double _armDeadZone = 0.05; // 5% autour du centre

  // Tilt control
  StreamSubscription<AccelerometerEvent>? _accSub;
  bool _isDragging = false;
  static const double _tiltStrength = 0.040; // sensibilité
  double _tiltTargetSplit = 0.5;
  Ticker? _tiltTicker;

  // Spring smoothing (réactif mais fluide)
  double _tiltVel = 0.0;
  static const double _springK = 32.0; // raideur
  static const double _springC = 12.0; // amortissement
  static const double _maxVel = 1.4; // limite de vitesse
  static const double _tiltEpsilon = 0.00025;
  Duration? _lastTick;

  late final AnimationController _glowCtl;
  late final AnimationController _splitCtl;
  Animation<double>? _splitAnim;

  late final AnimationController _confirmCtl;
  late final Animation<double> _confirmScale;
  late final Animation<double> _confirmFade;

  @override
  void initState() {
    super.initState();

    _glowCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    _splitCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _confirmCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _confirmScale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _confirmCtl, curve: Curves.easeOutBack));
    _confirmFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _confirmCtl, curve: Curves.easeInCubic));
    _accSub = accelerometerEvents.listen((e) {
      if (!mounted) return;
      if (_confirming) return;
      if (_isDragging) return;

      // En portrait: axe X (gauche/droite). On limite pour éviter les pics.
      final tiltX = (-e.x).clamp(-5.0, 5.0);
      _tiltTargetSplit = (0.5 + (tiltX * _tiltStrength)).clamp(0.18, 0.82);
    });

    _tiltTicker = createTicker((elapsed) {
      if (!mounted) return;
      if (_confirming) return;

      if (_isDragging) {
        _lastTick = elapsed;
        return;
      }

      final last = _lastTick;
      _lastTick = elapsed;
      if (last == null) return;

      // dt en secondes (capé pour éviter les sauts)
      var dt = (elapsed - last).inMicroseconds / 1e6;
      if (dt <= 0) return;
      dt = dt.clamp(0.0, 1 / 30); // max ~33ms

      final x = _split;
      final v = _tiltVel;
      final target = _tiltTargetSplit;

      // Force ressort + amortissement (critically-ish damped)
      final a = _springK * (target - x) - _springC * v;

      var vNext = v + a * dt;
      vNext = vNext.clamp(-_maxVel, _maxVel);

      final xNext = (x + vNext * dt).clamp(0.18, 0.82);

      // évite setState microscopique
      if ((xNext - _split).abs() < _tiltEpsilon && vNext.abs() < 0.002) {
        _tiltVel = vNext;
        return;
      }

      setState(() {
        _split = xNext;
        _tiltVel = vNext;

        final diff = _split - 0.5;
        if (diff.abs() < _armDeadZone) {
          _armedSide = null;
        } else {
          _armedSide = diff < 0 ? 0 : 1;
        }
      });
    })..start();
  }

  @override
  void dispose() {
    _tiltTicker?.dispose();
    _tiltTicker = null;
    _accSub?.cancel();
    _accSub = null;
    _glowCtl.dispose();
    _splitCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  void _animateSplitTo(double target) {
    _tiltVel = 0.0;
    _splitCtl.stop();
    _splitAnim = Tween<double>(begin: _split, end: target).animate(
      CurvedAnimation(parent: _splitCtl, curve: Curves.easeOutCubic),
    )..addListener(() {
      setState(() => _split = _splitAnim!.value);
    });
    _splitCtl
      ..reset()
      ..forward();
  }

  void _armOrConfirm(int side) async {
    if (_confirming) return;

    // Si l'autre côté est armé et qu'on tape de l'autre côté,
    // on revient au centre et on désarme (au lieu de basculer directement).
    if (_armedSide != null && _armedSide != side) {
      setState(() => _armedSide = null);
      _animateSplitTo(0.5);
      return;
    }

    // 1er tap : on arme et on décale la séparation
    if (_armedSide == null || _armedSide != side) {
      HapticFeedback.lightImpact();
      setState(() => _armedSide = side);
      final nudge = 0.16; // 10–20%
      final target =
          (side == 0 ? _split - nudge : _split + nudge)
              .clamp(0.25, 0.75)
              .toDouble();
      _animateSplitTo(target);
      return;
    }

    // 2e tap : confirmation
    HapticFeedback.mediumImpact();
    setState(() => _confirming = true);
    await _confirmCtl.forward();
    if (!mounted) return;

    if (side == 0) {
      widget.onPickActus();
    } else {
      widget.onPickMonde();
    }
  }

  void _onPanUpdate(DragUpdateDetails d, double width) {
    if (_confirming) return;
    final delta = d.delta.dx / width;

    setState(() {
      _split = (_split + delta).clamp(0.18, 0.82);

      // Armer automatiquement en fonction de la position de la frontière.
      // Si on est proche du centre, on désarme.
      final diff = _split - 0.5;
      if (diff.abs() < _armDeadZone) {
        _armedSide = null;
      } else {
        _armedSide = diff < 0 ? 0 : 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          // Marge pour rendre les coins bas visibles dans la bottom sheet
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(
              color: backgroundColor,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  // micro-oscillation pour donner un feeling "réagit à l'inclinaison"
                  final idle = math.sin(_glowCtl.value * math.pi * 2) * 0.006;
                  final split = (_split + idle).clamp(0.18, 0.82);

                  final splitX = w * split;

                  return AnimatedBuilder(
                    animation: Listenable.merge([_glowCtl, _confirmCtl]),
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _confirmScale.value,
                        child: Opacity(
                          opacity: _confirmFade.value,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (_) {
                              _isDragging = true;
                              _tiltVel = 0.0;
                            },
                            onPanUpdate: (d) => _onPanUpdate(d, w),
                            onPanEnd: (_) {
                              _isDragging = false;
                              _tiltVel = 0.0;
                              if (_confirming) return;
                              // Si l'utilisateur relâche proche du centre, on recentre.
                              if ((_split - 0.5).abs() < _armDeadZone) {
                                setState(() => _armedSide = null);
                                _animateSplitTo(0.5);
                              }
                            },
                            onPanCancel: () {
                              _isDragging = false;
                            },
                            onTapUp: (d) {
                              final side = d.localPosition.dx < splitX ? 0 : 1;
                              _armOrConfirm(side);
                            },
                            child: Stack(
                              children: [
                                // ── Background glows (mouvants) ───────────────────
                                _MovingGlows(progress: _glowCtl.value),

                                // ── Left side (Actus) ─────────────────────────────
                                Positioned.fill(
                                  child: ClipPath(
                                    clipper: _LightningSplitClipper(
                                      split: split,
                                      side: _LightningSide.left,
                                    ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black,
                                            Color(0xFF1F1F1F),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: _GlassLayer(
                                        child: _SideContent(
                                          side: 0,
                                          armedSide: _armedSide,
                                          title: 'Actus\ndu jour',
                                          subtitle: widget.actusSubtitle,
                                          icon: Icons.newspaper_rounded,
                                          primaryColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Right side (Monde) ────────────────────────────
                                Positioned.fill(
                                  child: ClipPath(
                                    clipper: _LightningSplitClipper(
                                      split: split,
                                      side: _LightningSide.right,
                                    ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: _accentGradient,
                                      ),
                                      child: _GlassLayer(
                                        child: _SideContent(
                                          side: 1,
                                          armedSide: _armedSide,
                                          title: 'Map\nMonde',
                                          subtitle: widget.mondeSubtitle,
                                          icon: Icons.public_rounded,
                                          primaryColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Divider glow + stroke ─────────────────────────
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _LightningDividerPainter(
                                        split: split,
                                        glowT: _glowCtl.value,
                                      ),
                                    ),
                                  ),
                                ),

                                // ── Overlay pills ABOVE divider ────────────────────
                                Positioned(
                                  left: 16,
                                  bottom: 26,
                                  child: _OverlayPill(
                                    active: _armedSide == 0,
                                    label:
                                        _armedSide == 0
                                            ? 'Tap pour confirmer'
                                            : 'Tap pour sélectionner',
                                  ),
                                ),
                                Positioned(
                                  right: 16,
                                  bottom: 26,
                                  child: _OverlayPill(
                                    active: _armedSide == 1,
                                    label:
                                        _armedSide == 1
                                            ? 'Tap pour confirmer'
                                            : 'Tap pour sélectionner',
                                  ),
                                ),

                                // ── Top badge ─────────────────────────────────────
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  top: 14,
                                  child: _TopBadge(armedSide: _armedSide),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI pieces
// ─────────────────────────────────────────────────────────────────────────────

class _TopBadge extends StatelessWidget {
  final int? armedSide;

  const _TopBadge({required this.armedSide});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: _accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  armedSide == null
                      ? 'Choisis ton mode'
                      : (armedSide == 0
                          ? 'Actus du jour — encore un tap pour confirmer'
                          : 'Monde — encore un tap pour confirmer'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideContent extends StatelessWidget {
  final int side;
  final int? armedSide;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;

  const _SideContent({
    required this.side,
    required this.armedSide,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final armed = armedSide == side;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 78, 18, 66),
      child: Column(
        crossAxisAlignment:
            side == 0 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: armed ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                if (armed)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Icon(icon, color: primaryColor, size: 26),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: side == 0 ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: primaryColor,
              height: 1.05,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            maxLines: 6,
            textAlign: side == 0 ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.1,
              color: primaryColor.withValues(alpha: 0.86),
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Pills moved to overlay, nothing here.
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final bool active;
  final String label;

  const _OverlayPill({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? _accentGradient : null,
            color: active ? null : Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: detailsColor2.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassLayer extends StatelessWidget {
  final Widget child;

  const _GlassLayer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.06),
          child: child,
        ),
      ),
    );
  }
}

class _MovingGlows extends StatelessWidget {
  final double progress;

  const _MovingGlows({required this.progress});

  @override
  Widget build(BuildContext context) {
    // 3 blobs qui se déplacent légèrement
    final t = progress * math.pi * 2;

    Offset blob(double a, double rX, double rY) {
      return Offset(math.cos(t + a) * rX, math.sin(t * 0.8 + a) * rY);
    }

    final b1 = blob(0.0, 120, 80);
    final b2 = blob(2.1, 140, 90);
    final b3 = blob(4.2, 110, 70);

    Widget glow(Offset o, Color c, double size, double alpha) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Transform.translate(
            offset: o,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.withValues(alpha: alpha),
                      c.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        glow(b1 + const Offset(-120, -180), detailsColor2, 520, 0.16),
        glow(b2 + const Offset(140, 80), detailsColor1, 560, 0.14),
        glow(b3 + const Offset(0, 220), Colors.white, 520, 0.06),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightning split clipper & painter
// ─────────────────────────────────────────────────────────────────────────────

enum _LightningSide { left, right }

class _LightningSplitClipper extends CustomClipper<Path> {
  final double split;
  final _LightningSide side;

  _LightningSplitClipper({required this.split, required this.side});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final x = w * split;

    // bolt points (slightly tilted)
    final tilt = -w * 0.08;
    final topX = x + tilt * 0.25;
    final botX = x - tilt * 0.25;

    final pts = <Offset>[
      Offset(topX, 0),
      Offset(x - 22, h * 0.18),
      Offset(x + 16, h * 0.34),
      Offset(x - 26, h * 0.52),
      Offset(x + 14, h * 0.70),
      Offset(botX, h),
    ];

    final p = Path();

    if (side == _LightningSide.left) {
      p.moveTo(0, 0);
      p.lineTo(pts.first.dx, 0);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      p.lineTo(0, h);
      p.close();
      return p;
    }

    // right
    p.moveTo(w, 0);
    p.lineTo(pts.first.dx, 0);
    for (int i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    p.lineTo(w, h);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant _LightningSplitClipper oldClipper) {
    return oldClipper.split != split || oldClipper.side != side;
  }
}

class _LightningDividerPainter extends CustomPainter {
  final double split;
  final double glowT;

  _LightningDividerPainter({required this.split, required this.glowT});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final x = w * split;

    final tilt = -w * 0.08;
    final topX = x + tilt * 0.25;
    final botX = x - tilt * 0.25;

    final pts = <Offset>[
      Offset(topX, 0),
      Offset(x - 22, h * 0.18),
      Offset(x + 16, h * 0.34),
      Offset(x - 26, h * 0.52),
      Offset(x + 14, h * 0.70),
      Offset(botX, h),
    ];

    final path = Path()..moveTo(pts.first.dx, 0);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    // Glow (animated)
    final pulse = 0.55 + 0.45 * math.sin(glowT * math.pi * 2);
    final glowPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = detailsColor2.withValues(alpha: 0.16 + 0.08 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.drawPath(path, glowPaint);

    // Core stroke (white)
    final corePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.78);

    canvas.drawPath(path, corePaint);

    // Small sparkles along the line
    final sparklePaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.50);

    for (int i = 1; i < pts.length - 1; i++) {
      final o = pts[i];
      final r = 2.0 + (i % 2) * 1.2;
      canvas.drawCircle(
        o.translate(math.sin(glowT * 10 + i) * 3, math.cos(glowT * 9 + i) * 3),
        r,
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightningDividerPainter oldDelegate) {
    return oldDelegate.split != split || oldDelegate.glowT != glowT;
  }
}
