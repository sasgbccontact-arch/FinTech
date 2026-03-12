import 'package:fintech/core/constants.dart';
import 'package:flutter/material.dart';
import '../layouts/navigation_footer.dart';
import '../pages/portfolio_dashboard_page.dart';
import '../pages/learn_page.dart';
import '../pages/game_page.dart';
import '../pages/forum_page.dart';
import '../pages/today_page.dart';

/// Modern animated bottom footer with 5 items:
/// Aujourd'hui, Dashboard, Apprendre, Game, Forum.
///
/// IMPORTANT:
/// - This footer does NOT navigate by itself.
/// - The parent (AppStructure) controls the current page and provides `onTap`.
/// App shell that hosts the 6 bottom tabs and provides a slide transition between them.
///
/// Indices:
/// 0 Aujourd'hui (TodayPage)
/// 1 Dashboard (PortfolioDashboardPage)
/// 2 Apprendre (LearnPage)
/// 3 Game (MarketSimulationPage)
/// 4 Forum (ForumPage)
class AppStructure extends StatefulWidget {
  const AppStructure({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppStructure> createState() => _AppStructureState();
}

class _AppStructureState extends State<AppStructure> {
  int _selectedIndex = 0;
  PageController? _pageController;

  List<Widget> get _pages => <Widget>[
    TodayPage(onNavigateToTab: _onTabTap),
    const PortfolioDashboardPage(),
    const LearnPage(),
    const MarketSimulationPage(),
    const ForumPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant AppStructure oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialIndex.clamp(0, 4);
    if (oldWidget.initialIndex != widget.initialIndex &&
        next != _selectedIndex) {
      _selectedIndex = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        (_pageController ??= PageController(initialPage: _selectedIndex))
            .jumpToPage(_selectedIndex);
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _selectedIndex) return;
    setState(() => _selectedIndex = i);
    _pageController?.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: PageView(
        controller:
            (_pageController ??= PageController(initialPage: _selectedIndex)),
        onPageChanged: (i) {
          if (i == _selectedIndex) return;
          setState(() => _selectedIndex = i);
        },
        children: _pages,
      ),
      bottomNavigationBar: NavigationFooter(
        currentIndex: _selectedIndex,
        onTap: _onTabTap,
      ),
    );
  }
}
