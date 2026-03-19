import 'dart:ui' as ui;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/features/duel/duel_models.dart';
import 'package:fintech/features/duel/duel_service.dart';
import 'package:fintech/features/notifications/notification_center_page.dart';
import 'package:fintech/features/onboarding/onboarding_page.dart';
import 'package:fintech/features/settings/app_settings_sheet.dart';
import 'package:fintech/features/social/social_spotlight_card.dart';
import 'package:fintech/features/daily_news_game/ui/daily_news_game_sheet.dart';
import 'package:fintech/pages/community_page.dart';
import 'package:fintech/pages/dividend_calendar_sheet.dart';
import 'package:fintech/pages/goal_page.dart';
import 'package:fintech/pages/info_page.dart';
import 'package:fintech/services/yahoo_finance_service.dart';
import 'package:fintech/utils/search_suggestion_ranker.dart';
import 'package:fintech/widgets/sponsored_native_ad_card.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;

  bool _onboardingHandled = false;

  String _avatarAsset(String id) {
    if (id == '_easteregg') return 'assets/avatars/easteregg.png';
    if (id == '_sydsteregg') return 'assets/avatars/sydsteregg.png';
    if (id == '_quintprime') return 'assets/avatars/quint_prime.png';
    if (id == '_beyondbig') return 'assets/avatars/beyond_big.png';
    if (id == '_groseline') return 'assets/avatars/groseline.png';
    if (id == '_gay') return 'assets/avatars/gay.png';
    if (id == '_call') return 'assets/avatars/avatar_call.png';
    if (id == '_happy') return 'assets/avatars/avatar_happy.png';
    if (id == '_wealthy') return 'assets/avatars/avatar_wealthy.png';
    if (id == '_rich') return 'assets/avatars/avatar_rich.png';
    if (id == '_geek') return 'assets/avatars/avatar_geek.png';
    return 'assets/avatars/avatar$id.png';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureOnboardingIfNeeded();
    });
  }

  Future<void> _ensureOnboardingIfNeeded() async {
    if (_onboardingHandled || !mounted) return;
    _onboardingHandled = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data == null || data['onboarding_completed_at'] == null) {
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const FinHubOnboardingPage(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TodayPage] Erreur onboarding: $e');
    }
  }

  Future<void> _openOnboarding({bool allowClose = true}) async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FinHubOnboardingPage(allowClose: allowClose),
      ),
    );
  }

  Future<void> _openNotificationCenter() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationCenterPage()));
  }

  Future<void> _openSettings(String? currentName) async {
    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: false,
      builder:
          (_) => AppSettingsSheet(
            currentName: currentName,
            onOpenNotificationCenter: _openNotificationCenter,
            onRelaunchOnboarding: () => _openOnboarding(allowClose: true),
          ),
    );
  }

  Future<void> _openProfileSheet({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    if (!mounted) return;
    await showSocialProfileSheet(
      context: context,
      userId: userId,
      initialUserData: userData,
      metric: SocialProfileMetric.level,
    );
  }

  Future<void> _openQuiz() async {
    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder: (_) => const DailyNewsGameSheet(),
    );
  }

  Future<void> _openDividendCalendar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder: (_) => DividendCalendarSheet(userId: user.uid),
    );
  }

  Future<void> _openCommunity() async {
    if (!mounted) return;
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder: (_) => const CommunityPage(),
    );
  }

  Future<void> _openGoalsPage() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GoalPage()));
  }

  void _openPrimaryPath(String starterPath) {
    switch (starterPath) {
      case 'portfolio':
        widget.onNavigateToTab(1);
        break;
      case 'news':
        _openQuiz();
        break;
      case 'learn':
      default:
        widget.onNavigateToTab(2);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bottomScrollInset = MediaQuery.of(context).padding.bottom + 108;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'Connectez-vous pour accéder à votre espace.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const _TodayLoadingSkeleton();
            }
            final userData = snapshot.data?.data() ?? <String, dynamic>{};
            final name = (userData['Name'] as String?)?.trim();
            final avatarId = userData['avatar_id'] as String?;
            final greeting =
                name == null || name.isEmpty ? 'Bonjour' : 'Bonjour, $name';
            final starterPath =
                (userData['starter_path'] as String?) ?? 'learn';
            final experience =
                (userData['experience_level'] as String?) ?? 'debutant';
            final interests =
                (userData['interests'] as List<dynamic>? ?? const <dynamic>[])
                    .map((value) => value.toString())
                    .where((value) => value.isNotEmpty)
                    .take(3)
                    .toList();
            final coins = (userData['coins'] as num?)?.toInt() ?? 0;
            final gems = (userData['gems'] as num?)?.toInt() ?? 0;

            return ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomScrollInset),
              children: [
                Row(
                  children: [
                    _AvatarButton(
                      avatarAsset:
                          avatarId == null ? null : _avatarAsset(avatarId),
                      onTap:
                          () => _openProfileSheet(
                            userId: user.uid,
                            userData: userData,
                          ),
                      onLongPress:
                          avatarId == null
                              ? null
                              : () {
                                HapticFeedback.mediumImpact();
                                showAvatarPreview(
                                  context,
                                  _avatarAsset(avatarId),
                                );
                              },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitleForExperience(experience),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(
                      icon: Icons.notifications_rounded,
                      tooltip: 'Centre de notifications',
                      onTap: _openNotificationCenter,
                    ),
                    const SizedBox(width: 8),
                    _HeaderIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Réglages',
                      onTap: () => _openSettings(name),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _HeroTodayCard(
                  starterPath: starterPath,
                  interests: interests,
                  coins: coins,
                  gems: gems,
                  onPrimaryTap: () => _openPrimaryPath(starterPath),
                ),
                _TodayDuelHighlight(
                  userId: user.uid,
                  onOpenCommunity: _openCommunity,
                ),
                const SizedBox(height: 16),
                _TodayHomeHubCard(
                  userId: user.uid,
                  onOpenLearn: () => widget.onNavigateToTab(2),
                  onOpenGoals: _openGoalsPage,
                  onOpenNews: _openQuiz,
                  onOpenNotifications: _openNotificationCenter,
                  onOpenDividendCalendar: _openDividendCalendar,
                  onOpenCommunity: _openCommunity,
                ),
                const SizedBox(height: 16),
                const SponsoredNativeAdCard.today(),
              ],
            );
          },
        ),
      ),
    );
  }

  String _subtitleForExperience(String experience) {
    switch (experience) {
      case 'intermediaire':
        return 'Ton hub est prêt pour reprendre rapidement.';
      case 'avance':
        return 'Vue condensée, actions utiles et signaux du jour.';
      case 'debutant':
      default:
        return 'Voici les prochaines actions utiles pour aujourd’hui.';
    }
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.avatarAsset,
    required this.onTap,
    this.onLongPress,
  });

  final String? avatarAsset;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir les réglages du profil',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.2),
            child:
                avatarAsset == null
                    ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(avatarAsset!, fit: BoxFit.cover),
                    ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Icon(icon, color: textColor),
        ),
      ),
    );
  }
}

class _HeroTodayCard extends StatefulWidget {
  const _HeroTodayCard({
    required this.starterPath,
    required this.interests,
    required this.coins,
    required this.gems,
    required this.onPrimaryTap,
  });

  final String starterPath;
  final List<String> interests;
  final int coins;
  final int gems;
  final VoidCallback onPrimaryTap;

  @override
  State<_HeroTodayCard> createState() => _HeroTodayCardState();
}

class _HeroTodayCardState extends State<_HeroTodayCard> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<TickerSearchResult> _suggestions = <TickerSearchResult>[];
  final List<TickerSearchResult> _searchCandidates = <TickerSearchResult>[];
  Timer? _debounce;

  bool _searchExpanded = false;
  bool _isSearching = false;
  String? _suggestionMessage;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _primaryLabel {
    switch (widget.starterPath) {
      case 'portfolio':
        return 'Continuer mon portefeuille';
      case 'news':
        return 'Lancer Actu & Quiz';
      case 'learn':
      default:
        return 'Reprendre mon parcours';
    }
  }

  void _expandSearch() {
    if (_searchExpanded) {
      _requestSearchFocus();
      return;
    }
    setState(() {
      _searchExpanded = true;
    });
    _requestSearchFocus();
  }

  void _requestSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _dismissSearchKeyboard() {
    _searchFocusNode.unfocus();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchRequestId += 1;
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _suggestionMessage = null;
      _searchCandidates.clear();
      _suggestions.clear();
    });
    _requestSearchFocus();
  }

  void _collapseSearch() {
    _debounce?.cancel();
    _searchRequestId += 1;
    _dismissSearchKeyboard();
    setState(() {
      _searchExpanded = false;
      _isSearching = false;
      _suggestionMessage = null;
      _searchController.clear();
      _searchCandidates.clear();
      _suggestions.clear();
    });
  }

  Future<void> _openInfoPage(TickerSearchResult suggestion) async {
    try {
      await showCupertinoModalBottomSheet<void>(
        context: context,
        expand: true,
        builder:
            (_) => InfoPage(
              ticker: suggestion.symbol,
              initialName: suggestion.displayName,
              initialExchange: suggestion.exchange,
              initialCurrency: suggestion.currency,
              initialQuoteType: suggestion.quoteType,
            ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir la fiche de l'actif."),
        ),
      );
    }
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      _expandSearch();
      return;
    }

    await _fetchSuggestions(query);
    if (!mounted || _suggestions.isEmpty) return;
    _searchFocusNode.unfocus();
    await _openInfoPage(_suggestions.first);
  }

  void _onSearchChanged(String value) {
    if (!_searchExpanded) {
      _searchExpanded = true;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _fetchSuggestions(value),
    );
    setState(() {});
  }

  Future<void> _fetchSuggestions(String query) async {
    final raw = query.trim();
    if (raw.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions.clear();
        _searchCandidates.clear();
        _suggestionMessage = null;
        _isSearching = false;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    final searchTerms = _buildSearchTerms(raw);

    setState(() {
      _isSearching = true;
      _suggestionMessage = null;
    });

    try {
      final initialResults = await _collectSearchResults(
        searchTerms,
        enableFuzzyQuery: false,
      );
      final exactCandidates = await _collectExactFrenchCandidates(raw);
      var deduped = _dedupeResults([...initialResults, ...exactCandidates]);
      var ordered = rankSearchSuggestions(
        candidates: deduped,
        query: raw,
        priority: SearchInstrumentPriority.equities,
      );

      final shouldUseFuzzyFallback =
          ordered.length < 8 ||
          !hasStrongSearchMatch(
            ordered,
            raw,
            priority: SearchInstrumentPriority.equities,
          );

      if (shouldUseFuzzyFallback) {
        final fuzzyResults = await _collectSearchResults(
          searchTerms,
          enableFuzzyQuery: true,
        );
        deduped = _dedupeResults([...deduped, ...fuzzyResults]);
        ordered = rankSearchSuggestions(
          candidates: deduped,
          query: raw,
          priority: SearchInstrumentPriority.equities,
        );
      }

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchCandidates
          ..clear()
          ..addAll(deduped);
        _suggestions
          ..clear()
          ..addAll(ordered);
        _isSearching = false;
        _suggestionMessage =
            ordered.isEmpty ? "Aucun résultat pour '$raw'" : null;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchCandidates.clear();
        _suggestions.clear();
        _isSearching = false;
        _suggestionMessage = 'Erreur réseau. Vérifie la connexion.';
      });
    }
  }

  List<String> _buildSearchTerms(String rawQuery) {
    final trimmed = rawQuery.trim();
    final normalized = normalizeSearchText(trimmed);
    final variants = <String>{trimmed};
    if (normalized.isNotEmpty && normalized != trimmed.toLowerCase()) {
      variants.add(normalized);
    }
    return variants.where((term) => term.trim().length >= 2).toList();
  }

  Future<List<TickerSearchResult>> _collectSearchResults(
    List<String> searchTerms, {
    required bool enableFuzzyQuery,
  }) async {
    final responses = await Future.wait(
      searchTerms.map(
        (term) => YahooFinanceService.searchSecurities(
          term,
          quotesCount: 50,
          enableFuzzyQuery: enableFuzzyQuery,
        ),
      ),
    );
    return responses.expand((items) => items).toList();
  }

  Future<List<TickerSearchResult>> _collectExactFrenchCandidates(
    String rawQuery,
  ) async {
    final trimmed = rawQuery.trim().toUpperCase();
    final looksLikeTicker = RegExp(r'^[A-Z0-9.-]{2,6}$').hasMatch(trimmed);
    if (!looksLikeTicker || trimmed.contains(' ')) {
      return const <TickerSearchResult>[];
    }

    final symbols =
        <String>{trimmed, if (!trimmed.contains('.')) '$trimmed.PA'}.toList();

    try {
      final exactMatches = await YahooFinanceService.lookupSecuritiesBySymbols(
        symbols,
      );
      return exactMatches
          .where((result) => result.isSearchDisplayableInstrument)
          .toList();
    } catch (_) {
      return const <TickerSearchResult>[];
    }
  }

  List<TickerSearchResult> _dedupeResults(List<TickerSearchResult> items) {
    final deduped = <String, TickerSearchResult>{};
    for (final item in items) {
      deduped.putIfAbsent(item.searchIdentity, () => item);
    }
    return deduped.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _searchController.text.trim().isNotEmpty;
    final showSearchContent =
        _isSearching ||
        _suggestions.isNotEmpty ||
        _suggestionMessage != null ||
        hasText;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _searchExpanded ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, premiumValue, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -34 + (premiumValue * 16),
              right: -18 - (premiumValue * 12),
              child: _TodayHeroOrb(
                size: 118,
                opacity: 0.16 + (premiumValue * 0.08),
              ),
            ),
            Positioned(
              bottom: -44 + (premiumValue * 10),
              left: -28 + (premiumValue * 10),
              child: _TodayHeroOrb(
                size: 146,
                opacity: 0.10 + (premiumValue * 0.06),
              ),
            ),
            child!,
          ],
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                right: 14,
                child: IgnorePointer(
                  child: _TodayHeroIllustration(expanded: _searchExpanded),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accueil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TodayHeroWalletChip(
                          icon: Icons.monetization_on_rounded,
                          label: 'Coins',
                          value: widget.coins.toString(),
                        ),
                        _TodayHeroWalletChip(
                          icon: Icons.diamond_rounded,
                          label: 'Gemmes',
                          value: widget.gems.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder:
                            (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1,
                                child: child,
                              ),
                            ),
                        child:
                            _searchExpanded
                                ? Column(
                                  key: const ValueKey('hero-search-open'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child: Row(
                                        key: const ValueKey(
                                          'hero-search-toolbar',
                                        ),
                                        children: [
                                          const _TodayHeroPremiumPill(
                                            label: 'Recherche instantanée',
                                          ),
                                          const Spacer(),
                                          TextButton.icon(
                                            onPressed: _collapseSearch,
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Fermer'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _TodayHeroSearchField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: _onSearchChanged,
                                      onClearQuery: _clearSearch,
                                      onCollapse: _collapseSearch,
                                      onSubmitted: (_) => _submitSearch(),
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child:
                                          showSearchContent
                                              ? Padding(
                                                key: ValueKey(
                                                  _isSearching
                                                      ? 'search-loading'
                                                      : _suggestions.isNotEmpty
                                                      ? 'search-results'
                                                      : _suggestionMessage ??
                                                          'search-hint',
                                                ),
                                                padding: const EdgeInsets.only(
                                                  top: 12,
                                                ),
                                                child: _buildSearchContent(),
                                              )
                                              : const Padding(
                                                key: ValueKey(
                                                  'search-default-hint',
                                                ),
                                                padding: EdgeInsets.only(
                                                  top: 12,
                                                ),
                                                child: _TodayHeroSearchHint(),
                                              ),
                                    ),
                                  ],
                                )
                                : Row(
                                  key: const ValueKey('hero-search-closed'),
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: widget.onPrimaryTap,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(_primaryLabel),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: _expandSearch,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.38,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Rechercher'),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const _TodayHeroSearchLoading();
    }
    if (_suggestions.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 292),
        child: _TodayHeroSuggestionList(
          suggestions: _suggestions,
          onTap: _openInfoPage,
        ),
      );
    }
    if (_suggestionMessage != null) {
      return _TodayHeroSearchMessage(message: _suggestionMessage!);
    }
    return const _TodayHeroSearchHint();
  }
}

class _TodayHeroSearchField extends StatelessWidget {
  const _TodayHeroSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClearQuery,
    required this.onCollapse,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onCollapse;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final isFocused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isFocused ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.manage_search_rounded,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Recherche instantanée d’action, ETF ou fonds',
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onTapOutside: (_) => focusNode.unfocus(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Nom, ticker, ETF ou fonds...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                hasText
                    ? Row(
                      key: const ValueKey('hero-search-actions-filled'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: onClearQuery,
                          tooltip: 'Effacer la recherche',
                          icon: const Icon(
                            Icons.backspace_outlined,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: onCollapse,
                          tooltip: 'Fermer la recherche',
                          icon: const Icon(
                            Icons.keyboard_hide_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                    : Row(
                      key: const ValueKey('hero-search-actions-empty'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => onSubmitted(controller.text),
                          tooltip: 'Lancer la recherche',
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: onCollapse,
                          tooltip: 'Revenir à Accueil',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

class _TodayHeroSearchHint extends StatelessWidget {
  const _TodayHeroSearchHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recherche instantanee',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ouvre directement la fiche d’un actif avec les meme suggestions que ta recherche complete.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TodayHeroHintPill(label: 'Actions'),
              _TodayHeroHintPill(label: 'ETF'),
              _TodayHeroHintPill(label: 'Fonds'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayHeroHintPill extends StatelessWidget {
  const _TodayHeroHintPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
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

class _TodayHeroWalletChip extends StatelessWidget {
  const _TodayHeroWalletChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayHeroIllustration extends StatelessWidget {
  const _TodayHeroIllustration({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      offset: expanded ? const Offset(0.02, -0.02) : Offset.zero,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutBack,
        scale: expanded ? 1.04 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: expanded ? 0.9 : 0.78,
          child: SizedBox(
            width: 80,
            height: 80,
            child: SvgPicture.string(_todayHeroSvg),
          ),
        ),
      ),
    );
  }
}

class _TodayHeroSuggestionList extends StatelessWidget {
  const _TodayHeroSuggestionList({
    required this.suggestions,
    required this.onTap,
  });

  final List<TickerSearchResult> suggestions;
  final ValueChanged<TickerSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder:
              (_, __) => const Divider(height: 1, color: Color(0xFFF0F1F3)),
          itemBuilder: (context, index) {
            final item = suggestions[index];
            final exchange =
                item.exchange.isNotEmpty ? item.exchange : item.region;
            final marketLine = <String>[
              if (exchange.isNotEmpty) exchange,
              if (item.currency.isNotEmpty) item.currency,
            ].join(' • ');
            final hasDistinctName =
                item.displayName.toUpperCase() != item.symbol.toUpperCase();

            return Semantics(
              button: true,
              label: 'Ouvrir ${item.displayName}',
              child: InkWell(
                onTap: () => onTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForItem(item),
                        color: detailsColor2.withValues(alpha: 0.92),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.symbol,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _TodayHeroTypeBadge(
                                  label: item.instrumentLabel,
                                ),
                              ],
                            ),
                            if (hasDistinctName) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                            if (marketLine.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                marketLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForItem(TickerSearchResult item) {
    if (item.isEtf) return Icons.stacked_line_chart_rounded;
    if (item.isMutualFund) return Icons.account_balance_wallet_rounded;
    if (item.isIndex) return Icons.query_stats_rounded;
    return Icons.trending_up_rounded;
  }
}

class _TodayHeroPremiumPill extends StatelessWidget {
  const _TodayHeroPremiumPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayHeroOrb extends StatelessWidget {
  const _TodayHeroOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _TodayHeroTypeBadge extends StatelessWidget {
  const _TodayHeroTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: detailsColor1.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: detailsColor2.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: detailsColor2,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _TodayHeroSearchMessage extends StatelessWidget {
  const _TodayHeroSearchMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _TodayHeroSearchLoading extends StatelessWidget {
  const _TodayHeroSearchLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.96),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Recherche des meilleurs resultats...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHomeHubCard extends StatefulWidget {
  const _TodayHomeHubCard({
    required this.userId,
    required this.onOpenLearn,
    required this.onOpenGoals,
    required this.onOpenNews,
    required this.onOpenNotifications,
    required this.onOpenDividendCalendar,
    required this.onOpenCommunity,
  });

  final String userId;
  final VoidCallback onOpenLearn;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenNews;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenDividendCalendar;
  final VoidCallback onOpenCommunity;

  @override
  State<_TodayHomeHubCard> createState() => _TodayHomeHubCardState();
}

class _TodayHomeHubCardState extends State<_TodayHomeHubCard> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  num? _readNum(Map<String, dynamic>? data, String key) {
    final raw = data?[key];
    return raw is num ? raw : null;
  }

  Map<String, dynamic>? _latestBroadcast(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    String? type,
    bool requireMetalsPayload = false,
  }) {
    if (docs.isEmpty) return null;
    final sorted = [...docs]..sort((left, right) {
      final leftDate = left.data()['createdAt'];
      final rightDate = right.data()['createdAt'];
      final leftTime =
          leftDate is Timestamp
              ? leftDate.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          rightDate is Timestamp
              ? rightDate.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
      return rightTime.compareTo(leftTime);
    });
    for (final doc in sorted) {
      final data = doc.data();
      if (type != null && data['type'] != type) continue;
      if (requireMetalsPayload &&
          _readNum(data, 'gold') == null &&
          _readNum(data, 'oil') == null) {
        continue;
      }
      return data;
    }
    return null;
  }

  Map<String, dynamic>? _latestMetalsHistory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;
    final sorted = [...docs]
      ..sort((left, right) => right.id.compareTo(left.id));
    for (final doc in sorted) {
      final data = doc.data();
      if (_readNum(data, 'gold') != null || _readNum(data, 'oil') != null) {
        return data;
      }
    }
    return null;
  }

  String _formatPrice(num? value, {int decimals = 2}) {
    if (value == null) return '--';
    return value.toStringAsFixed(decimals);
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('games')
            .doc('progress')
            .snapshots();
    final questStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('quests')
            .doc('daily')
            .snapshots();
    final freeStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('dailyBenefits')
            .doc('news_${_todayKey()}')
            .snapshots();
    final metalsTodayStream =
        FirebaseFirestore.instance
            .collection('metalsPrices')
            .doc(_todayKey())
            .snapshots();
    final metalsHistoryStream =
        FirebaseFirestore.instance.collection('metalsPrices').snapshots();
    final broadcastStream =
        FirebaseFirestore.instance.collection('broadcasts').snapshots();

    return SizedBox(
      height: 560,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: progressStream,
          builder: (context, progressSnapshot) {
            final progressData =
                progressSnapshot.data?.data() ?? const <String, dynamic>{};
            final streak =
                (progressData['current_streak'] as num?)?.toInt() ?? 0;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: questStream,
              builder: (context, questSnapshot) {
                final questData =
                    questSnapshot.data?.data() ?? const <String, dynamic>{};
                final now = DateTime.now();
                final todayLabel = '${now.year}-${now.month}-${now.day}';
                final isToday = questData['date'] == todayLabel;
                final quizzesDone =
                    isToday
                        ? (questData['quizzes_done'] as num?)?.toInt() ?? 0
                        : 0;
                final lessonsDone =
                    isToday
                        ? (questData['lessons_done'] as num?)?.toInt() ?? 0
                        : 0;
                final tradesDone =
                    isToday
                        ? (questData['trades_done'] as num?)?.toInt() ?? 0
                        : 0;
                final pendingRewards =
                    ((quizzesDone >= 1 &&
                            (questData['claimed_quizzes'] as bool?) != true)
                        ? 1
                        : 0) +
                    ((lessonsDone >= 1 &&
                            (questData['claimed_lessons'] as bool?) != true)
                        ? 1
                        : 0) +
                    ((tradesDone >= 1 &&
                            (questData['claimed_trades'] as bool?) != true)
                        ? 1
                        : 0);

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: freeStream,
                  builder: (context, freeSnapshot) {
                    final freeData =
                        freeSnapshot.data?.data() ?? const <String, dynamic>{};
                    final actusFreeAvailable =
                        (freeData['free_actus_used'] as bool?) != true;
                    final mondeFreeAvailable =
                        (freeData['free_monde_used'] as bool?) != true;

                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: metalsTodayStream,
                      builder: (context, metalsTodaySnapshot) {
                        final metalsToday = metalsTodaySnapshot.data?.data();

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: metalsHistoryStream,
                          builder: (context, metalsHistorySnapshot) {
                            final latestMetalsDoc = _latestMetalsHistory(
                              metalsHistorySnapshot.data?.docs ?? const [],
                            );

                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: broadcastStream,
                              builder: (context, broadcastSnapshot) {
                                final latestBroadcast = _latestBroadcast(
                                  broadcastSnapshot.data?.docs ?? const [],
                                );
                                final latestMetalsBroadcast = _latestBroadcast(
                                  broadcastSnapshot.data?.docs ?? const [],
                                  type: 'daily_metals',
                                  requireMetalsPayload: true,
                                );
                                final gold =
                                    _readNum(metalsToday, 'gold') ??
                                    _readNum(latestMetalsDoc, 'gold') ??
                                    _readNum(latestMetalsBroadcast, 'gold');
                                final oil =
                                    _readNum(metalsToday, 'oil') ??
                                    _readNum(latestMetalsDoc, 'oil') ??
                                    _readNum(latestMetalsBroadcast, 'oil');
                                final latestTitle =
                                    (latestBroadcast?['title'] as String?) ??
                                    'Aucune annonce récente';
                                const hubSubtitle =
                                    'Priorités, signaux et accès rapides dans un seul bloc.';

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Hub du jour',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 19,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                height: 36,
                                                child: Text(
                                                  hubSubtitle,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: detailsColor1.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: detailsColor2.withValues(
                                                alpha: 0.10,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            '${_pageIndex + 1}/3',
                                            style: const TextStyle(
                                              color: detailsColor2,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child: PageView(
                                        controller: _pageController,
                                        onPageChanged:
                                            (value) => setState(
                                              () => _pageIndex = value,
                                            ),
                                        children: [
                                          _TodayHubSlideFrame(
                                            title: 'Cap du jour',
                                            subtitle:
                                                'Ton rythme, tes quêtes et les accès gratuits.',
                                            svg: _todayOverviewSvg,
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _TodayHubMetricTile(
                                                        label: 'Streak',
                                                        value: '$streak jours',
                                                        icon:
                                                            Icons
                                                                .local_fire_department_rounded,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: _TodayHubMetricTile(
                                                        label: 'Récompenses',
                                                        value:
                                                            pendingRewards > 0
                                                                ? '$pendingRewards à récupérer'
                                                                : 'Rien en attente',
                                                        icon:
                                                            Icons
                                                                .task_alt_rounded,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _TodayHubMetricTile(
                                                        label: 'Actu & Quiz',
                                                        value:
                                                            actusFreeAvailable
                                                                ? 'Session gratuite'
                                                                : 'Déjà utilisée',
                                                        icon:
                                                            Icons
                                                                .newspaper_rounded,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: _TodayHubMetricTile(
                                                        label: 'MapMonde',
                                                        value:
                                                            mondeFreeAvailable
                                                                ? 'Session gratuite'
                                                                : 'Déjà utilisée',
                                                        icon:
                                                            Icons
                                                                .public_rounded,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _MiniActionButton(
                                                        label: 'Leçons',
                                                        icon:
                                                            Icons
                                                                .school_rounded,
                                                        onTap:
                                                            widget.onOpenLearn,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: _MiniActionButton(
                                                        label: 'Quêtes',
                                                        icon:
                                                            Icons.flag_rounded,
                                                        onTap:
                                                            widget.onOpenGoals,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: _MiniActionButton(
                                                        label: 'Quiz',
                                                        icon:
                                                            Icons.quiz_rounded,
                                                        onTap:
                                                            widget.onOpenNews,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          _TodayHubSlideFrame(
                                            title: 'Agenda marché',
                                            subtitle:
                                                'Un aperçu compact des signaux à surveiller.',
                                            svg: _todaySignalsSvg,
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _TodayHubMetricTile(
                                                        label: 'Or',
                                                        value:
                                                            '${_formatPrice(gold)} \$/oz',
                                                        icon:
                                                            Icons
                                                                .brightness_high_rounded,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: _TodayHubMetricTile(
                                                        label: 'Pétrole',
                                                        value:
                                                            '${_formatPrice(oil)} \$/baril',
                                                        icon:
                                                            Icons
                                                                .oil_barrel_rounded,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    14,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF7F8FA,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFE6E8EB,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: detailsColor2
                                                              .withValues(
                                                                alpha: 0.10,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .campaign_rounded,
                                                          color: detailsColor2,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              'Dernière annonce',
                                                              style: TextStyle(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              latestTitle,
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .black54,
                                                                height: 1.35,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: [
                                                    _StatPill(
                                                      icon:
                                                          Icons
                                                              .workspace_premium_rounded,
                                                      label:
                                                          pendingRewards > 0
                                                              ? '$pendingRewards récompense(s)'
                                                              : 'Aucune récompense en attente',
                                                    ),
                                                    _StatPill(
                                                      icon:
                                                          Icons
                                                              .newspaper_rounded,
                                                      label:
                                                          actusFreeAvailable
                                                              ? 'Quiz gratuit disponible'
                                                              : 'Quiz déjà utilisé',
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          _TodayHubSlideFrame(
                                            title: 'Actions utiles',
                                            subtitle: 'Raccourcis',
                                            svg: _todayActionsSvg,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: _TodayHubActionCard(
                                                          icon:
                                                              Icons
                                                                  .event_available_rounded,
                                                          title: 'Dividendes',
                                                          subtitle:
                                                              'Dates clés',
                                                          onTap:
                                                              widget
                                                                  .onOpenDividendCalendar,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: _TodayHubActionCard(
                                                          icon:
                                                              Icons
                                                                  .notifications_rounded,
                                                          title: 'Alertes',
                                                          subtitle: 'Voir tout',
                                                          onTap:
                                                              widget
                                                                  .onOpenNotifications,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: _TodayHubActionCard(
                                                          icon:
                                                              Icons
                                                                  .groups_rounded,
                                                          title: 'Communauté',
                                                          subtitle:
                                                              'Spotlight & duel',
                                                          onTap:
                                                              widget
                                                                  .onOpenCommunity,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: _TodayHubActionCard(
                                                          icon:
                                                              Icons
                                                                  .flag_rounded,
                                                          title: 'Objectifs',
                                                          subtitle:
                                                              'Rester régulier',
                                                          onTap:
                                                              widget
                                                                  .onOpenGoals,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(
                                            3,
                                            (index) => GestureDetector(
                                              onTap: () => _jumpToPage(index),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 220,
                                                ),
                                                margin: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                width:
                                                    _pageIndex == index
                                                        ? 22
                                                        : 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color:
                                                      _pageIndex == index
                                                          ? detailsColor2
                                                          : detailsColor1
                                                              .withValues(
                                                                alpha: 0.28,
                                                              ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Glisse pour naviguer',
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: 0.46,
                                            ),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TodayDuelHighlight extends StatelessWidget {
  const _TodayDuelHighlight({
    required this.userId,
    required this.onOpenCommunity,
  });

  final String userId;
  final VoidCallback onOpenCommunity;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DuelService.watchProfile(userId),
      builder: (context, profileSnapshot) {
        final profile = DuelProfile.fromDoc(
          profileSnapshot.data,
          fallbackUid: userId,
        );
        final duelId = profile.currentDuelId;
        if (!profile.isActiveDuel || duelId == null || duelId.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: DuelService.watchDuel(duelId),
            builder: (context, duelSnapshot) {
              if (!duelSnapshot.hasData || duelSnapshot.data?.exists != true) {
                return const SizedBox.shrink();
              }
              final duel = DuelData.fromDoc(duelSnapshot.data);
              if (!duel.isActive) {
                return const SizedBox.shrink();
              }

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('duels')
                        .doc(duelId)
                        .collection('participants')
                        .doc(userId)
                        .snapshots(),
                builder: (context, participantSnapshot) {
                  final participant = DuelParticipant.fromDoc(
                    participantSnapshot.data,
                    uid: userId,
                  );
                  final remaining = duel.endsAt?.difference(DateTime.now());
                  final progress = _todayDuelProgress(
                    duel.acceptedAt,
                    duel.endsAt,
                  );
                  final startCapital =
                      participant.startingTotalCapital > 0
                          ? participant.startingTotalCapital
                          : ((participant.currentTotalCapitalCache ??
                                  (profile.holdingsValueEstimate +
                                      profile.reserveCoins)) >
                              0)
                          ? (participant.currentTotalCapitalCache ??
                              (profile.holdingsValueEstimate +
                                  profile.reserveCoins))
                          : 0.0;
                  final currentCapital =
                      participant.currentTotalCapitalCache ?? startCapital;
                  final capitalDelta = currentCapital - startCapital;
                  final capitalDeltaPct =
                      startCapital <= 0
                          ? 0.0
                          : (capitalDelta / startCapital) * 100;
                  final lastSync = participant.currentUpdatedAt;

                  return InkWell(
                    onTap: onOpenCommunity,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [detailsColor2, detailsColor1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Duel en cours',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  remaining == null
                                      ? 'En cours'
                                      : _formatCompactRemaining(remaining),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _TodayDuelStat(
                                  label: 'Score',
                                  value: _formatSigned(
                                    participant.currentScoreCache ?? 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TodayDuelStat(
                                  label: 'Capital',
                                  value:
                                      '${capitalDelta >= 0 ? '+' : ''}${_formatShortCoins(capitalDelta)}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TodayDuelStat(
                                  label: 'Perf défi',
                                  value: '${_formatSigned(capitalDeltaPct)}%',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.16,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            lastSync == null
                                ? 'Le duel est actif. Ouvre le dashboard pour suivre l’écart et le radar adverse.'
                                : 'Synchro ${_formatCompactDateTime(lastSync)} · ouvre le dashboard duel pour suivre les variations clés.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.pie_chart_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Ouvrir le dashboard duel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
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
            },
          ),
        );
      },
    );
  }
}

class _TodayHubSlideFrame extends StatelessWidget {
  const _TodayHubSlideFrame({
    required this.title,
    required this.subtitle,
    required this.svg,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String svg;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            detailsColor1.withValues(alpha: 0.16),
            Colors.white,
            detailsColor2.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFE8E2D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TodayHubSvgBadge(svg: svg),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TodayHubSvgBadge extends StatelessWidget {
  const _TodayHubSvgBadge({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.84),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: detailsColor2.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SvgPicture.string(svg),
      ),
    );
  }
}

class _TodayHubMetricTile extends StatelessWidget {
  const _TodayHubMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: detailsColor1.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: detailsColor2, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              height: 1.25,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHubActionCard extends StatelessWidget {
  const _TodayHubActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: detailsColor1.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: detailsColor2, size: 16),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: detailsColor2,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayDuelStat extends StatelessWidget {
  const _TodayDuelStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCompactRemaining(Duration remaining) {
  if (remaining.isNegative) {
    return 'Terminé';
  }
  final days = remaining.inDays;
  final hours = remaining.inHours.remainder(24);
  if (days > 0) {
    return '${days}j ${hours}h';
  }
  final minutes = remaining.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
}

String _formatSigned(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}';
}

double _todayDuelProgress(DateTime? acceptedAt, DateTime? endsAt) {
  if (acceptedAt == null || endsAt == null || !endsAt.isAfter(acceptedAt)) {
    return 0;
  }
  final totalMs = endsAt.difference(acceptedAt).inMilliseconds;
  if (totalMs <= 0) return 0;
  final elapsedMs = DateTime.now()
      .difference(acceptedAt)
      .inMilliseconds
      .clamp(0, totalMs);
  return elapsedMs / totalMs;
}

String _formatShortCoins(double value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toStringAsFixed(0);
}

String _formatCompactDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} · $hour:$minute';
}

const String _todayHeroSvg = '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="heroWarm" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFF4CC"/>
      <stop offset="100%" stop-color="#D88A4A"/>
    </linearGradient>
  </defs>
  <circle cx="62" cy="58" r="34" fill="url(#heroWarm)" opacity="0.95"/>
  <rect x="24" y="68" width="72" height="18" rx="9" fill="#FFFFFF" opacity="0.22"/>
  <path d="M28 73 C38 66, 48 70, 58 60 S79 54, 92 44" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>
  <circle cx="92" cy="44" r="6" fill="#FFFFFF"/>
  <path d="M38 32 L44 22 L50 32" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M70 29 L76 19 L82 29" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" opacity="0.72"/>
</svg>
''';

const String _todayOverviewSvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="14" width="52" height="44" rx="16" fill="#FFF2D9"/>
  <path d="M22 40 C28 32, 35 37, 42 27 S52 23, 57 18" fill="none" stroke="#8D3E20" stroke-width="4" stroke-linecap="round"/>
  <circle cx="57" cy="18" r="4" fill="#8D3E20"/>
  <circle cx="26" cy="25" r="5" fill="#D9A441"/>
  <path d="M24 50 H48" stroke="#D9A441" stroke-width="4" stroke-linecap="round"/>
</svg>
''';

const String _todaySignalsSvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <rect x="11" y="12" width="50" height="48" rx="16" fill="#F9E7D4"/>
  <path d="M20 46 H52" stroke="#8D3E20" stroke-width="4" stroke-linecap="round"/>
  <path d="M24 38 L31 28 L39 34 L48 21" fill="none" stroke="#D88A4A" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="48" cy="21" r="4" fill="#D88A4A"/>
  <circle cx="24" cy="24" r="5" fill="#E0B84B" opacity="0.9"/>
</svg>
''';

const String _todayActionsSvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <rect x="12" y="12" width="20" height="20" rx="8" fill="#FFF1D0"/>
  <rect x="40" y="12" width="20" height="20" rx="8" fill="#F6E0D5"/>
  <rect x="12" y="40" width="20" height="20" rx="8" fill="#F6E0D5"/>
  <rect x="40" y="40" width="20" height="20" rx="8" fill="#FFF1D0"/>
  <path d="M24 22 h-4 v-4" fill="none" stroke="#8D3E20" stroke-width="3" stroke-linecap="round"/>
  <path d="M48 18 l4 4 l-4 4" fill="none" stroke="#D88A4A" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="22" cy="50" r="4" fill="#8D3E20"/>
  <path d="M45 50 h10" stroke="#D88A4A" stroke-width="4" stroke-linecap="round"/>
</svg>
''';

class _TodayLoadingSkeleton extends StatelessWidget {
  const _TodayLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 180,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final height in const [236.0, 142.0, 560.0])
          Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6E8EB)),
            ),
          ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: detailsColor1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: detailsColor2.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: detailsColor2),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: detailsColor1.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: detailsColor2.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: detailsColor2, size: 17),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
