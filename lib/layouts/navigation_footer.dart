
import 'package:flutter/material.dart';

/// Modern animated bottom footer with 5 items:
/// Home, Dashboard, Favorites, Stats, Calculator.
///
/// Colors: white background, black active accents, grey inactive icons.
/// Use [NavigationFooter] in your Scaffold bottomNavigationBar and
/// control the selected index from your parent widget.
class NavigationFooter extends StatefulWidget {
  const NavigationFooter({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

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
    final Color bg = Colors.white;
    final Color border = Colors.black.withOpacity(0.10);
    final Color active = Colors.black;
    final Color inactive = Colors.grey.shade600;

    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            // Subtle elevation
            BoxShadow(
              color: Colors.black.withOpacity(brightness == Brightness.dark ? 0.15 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _AnimatedBar(
          currentIndex: widget.currentIndex,
          onTap: widget.onTap,
          active: active,
          inactive: inactive,
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
        const count = 5;
        final itemWidth = width / count;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Sliding indicator (pill) behind the active icon
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: currentIndex * itemWidth,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: itemWidth,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  icon: _iconFor(i),
                  label: _labelFor(i),
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

  IconData _iconFor(int i) => const [
        Icons.home_rounded,
        Icons.dashboard_rounded,
        Icons.favorite_rounded,
        Icons.bar_chart_rounded,
        Icons.calculate_rounded,
      ][i];
  String _labelFor(int i) => const ['Home', 'Dashboard', 'Favoris', 'Stats', 'Calculs'][i];
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
        onTap: () => onTap(index),
        splashColor: Colors.black12,
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
                scale: selected ? 1.1 : 1.0,
                curve: Curves.easeOut,
                child: Icon(icon, color: iconColor, size: selected ? 26 : 24),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: selected ? 1.0 : 0.85,
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optional helper: simple demo scaffold showing how to use the footer.
/// Delete this if you already integrate it in your own pages.
class NavigationFooterDemo extends StatefulWidget {
  const NavigationFooterDemo({Key? key}) : super(key: key);

  @override
  State<NavigationFooterDemo> createState() => _NavigationFooterDemoState();
}

class _NavigationFooterDemoState extends State<NavigationFooterDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: Center(
        child: Text(
          'Onglet sélectionné: ${['Home', 'Dashboard', 'Favoris', 'Stats', 'Calculs'][_index]}',
          style: const TextStyle(fontFamily: 'Geo', fontSize: 18),
        ),
      ),
      bottomNavigationBar: NavigationFooter(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}