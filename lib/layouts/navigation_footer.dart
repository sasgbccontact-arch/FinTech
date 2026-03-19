import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fintech/core/constants.dart';

/// Modern animated bottom footer with 5 items:
/// Aujourd'hui, Dashboard, Apprendre, Game, Social.
///
/// Notes:
/// - The parent widget (AppStructure) controls ALL tabs (0..4) via [onTap].
/// - NavigationFooter does NOT push routes; it only emits the tapped index.
class NavigationFooter extends StatefulWidget {
  const NavigationFooter({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// The selected tab index (0..4)
  final int currentIndex;

  /// Callback when a tab is tapped
  final ValueChanged<int> onTap;

  @override
  State<NavigationFooter> createState() => _NavigationFooterState();
}

class _NavigationFooterState extends State<NavigationFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant NavigationFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color border = Colors.black.withValues(
      alpha: brightness == Brightness.dark ? 0.18 : 0.10,
    );
    final Color active = textColor;
    final Color inactive = Colors.grey.shade600;

    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: brightness == Brightness.dark ? 0.18 : 0.08,
              ),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // iOS-style frosted glass blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.white.withValues(
                    alpha: brightness == Brightness.dark ? 0.03 : 0.10,
                  ),
                ),
              ),
            ),

            // Inner highlight to mimic glass edge
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: brightness == Brightness.dark ? 0.08 : 0.35,
                    ),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(
                        alpha: brightness == Brightness.dark ? 0.03 : 0.10,
                      ),
                      Colors.white.withValues(alpha: 0.00),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Subtle global glow
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      detailsColor1.withValues(alpha: 0.05),
                      detailsColor2.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            _AnimatedBar(
              currentIndex: widget.currentIndex,
              onTap: widget.onTap,
              active: active,
              inactive: inactive,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.currentIndex,
    required this.onTap,
    required this.active,
    required this.inactive,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color active;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final icons = _icons;
        final labels = _labels;
        assert(icons.length == labels.length);
        final count = icons.length;

        final itemWidth = width / count;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Sliding gradient glow behind the active item
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: currentIndex * itemWidth,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: itemWidth,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow
                      Container(
                        width: 64,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [detailsColor1, detailsColor2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Blur/soften via opacity layers
                      Container(
                        width: 64,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      // Inner pill
                      Container(
                        width: 46,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              detailsColor1.withValues(alpha: 0.18),
                              detailsColor2.withValues(alpha: 0.18),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: detailsColor2.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Items row
            Row(
              children: List.generate(count, (i) {
                final bool selected = i == currentIndex;
                return _FooterItem(
                  width: itemWidth,
                  index: i,
                  icon: icons[i],
                  label: labels[i],
                  selected: selected,
                  active: active,
                  inactive: inactive,
                  onTap: onTap,
                );
              }),
            ),
          ],
        );
      },
    );
  }

  static const List<IconData> _icons = [
    Icons.home_rounded,
    Icons.dashboard_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.groups_rounded,
  ];

  static const List<String> _labels = [
    'Home',
    'Dashboard',
    'Apprendre',
    'Game',
    'Social',
  ];
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.width,
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
    required this.active,
    required this.inactive,
    required this.onTap,
  });

  final double width;
  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final Color active;
  final Color inactive;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? active : inactive;
    final textStyle = TextStyle(
      fontFamily: 'Geo',
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      fontSize: selected ? 12.0 : 11.0,
      color: iconColor,
    );

    return SizedBox(
      width: width,
      height: double.infinity,
      child: InkWell(
        onTap: () {
          if (selected) return;
          HapticFeedback.selectionClick();
          onTap(index);
        },
        splashColor: Colors.black.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: textStyle,
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: selected ? 1.12 : 1.0,
                curve: Curves.easeOut,
                child: Icon(
                  icon,
                  color: selected ? detailsColor2 : iconColor,
                  size: selected ? 26 : 24,
                ),
              ),
              const SizedBox(height: 4),
              Opacity(opacity: selected ? 1.0 : 0.78, child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}
