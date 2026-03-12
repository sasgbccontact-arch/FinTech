import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:fintech/core/constants.dart';

import '../services/yahoo_finance_service.dart';
import 'info_page.dart';
import 'dividend_calendar_sheet.dart';
import 'game_page.dart' show UserProfileHeader;
import 'login_page.dart';
import '../utils/search_suggestion_ranker.dart';
import '../widgets/wallet_balances.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<TickerSearchResult> _suggestions = [];
  final List<TickerSearchResult> _searchCandidates = [];
  Timer? _debounce;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocSubscription;
  String? _displayName;
  String? _avatarId;
  bool _loadingName = true;
  TickerSearchResult? _selectedSuggestion;
  String? _suggestionMessage;
  bool _isSearching = false;
  int _searchRequestId = 0;
  SearchInstrumentPriority _searchPriority = SearchInstrumentPriority.equities;

  // Animation pour le titre
  late final AnimationController _titleCtrl;
  late final Animation<double> _titleScale;

  // Palette (from core/constants.dart)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _muted = Colors.black54;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;
  static const Color _chipBg = Color(0xFFF0F1F3);

  String _getAvatarAsset(String id) {
    if (id == '_easteregg') return 'assets/avatars/easteregg.png';
    if (id == '_sydsteregg') return 'assets/avatars/sydsteregg.png';
    return 'assets/avatars/avatar$id.png';
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _titleScale = Tween<double>(
      begin: .98,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutBack));

    _titleCtrl.forward();

    _focusNode.addListener(() => setState(() {}));
    _listenToUserProfile();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userDocSubscription?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _listenToUserProfile() {
    _userDocSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _displayName = null;
        _loadingName = false;
      });
      return;
    }

    setState(() {
      _loadingName = true;
    });

    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            final name = data?['Name'] as String?;
            final avatarId = data?['avatar_id'] as String?;
            if (!mounted) {
              return;
            }
            setState(() {
              _displayName =
                  (name != null && name.trim().isNotEmpty) ? name.trim() : null;
              _avatarId = avatarId;
              _loadingName = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _loadingName = false;
            });
          },
        );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déconnexion impossible. Réessayez.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _goToInfo(TickerSearchResult suggestion) async {
    try {
      await showCupertinoModalBottomSheet(
        context: context,
        expand: true, // pleine hauteur avec animation iOS
        builder:
            (ctx) => InfoPage(
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
          content: Text("Impossible d'ouvrir la fiche de l'action."),
        ),
      );
    }
  }

  Future<void> _openDividendCalendar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connectez-vous pour consulter le calendrier des dividendes.',
          ),
        ),
      );
      return;
    }

    try {
      await showCupertinoModalBottomSheet(
        context: context,
        expand: true,
        builder: (ctx) => DividendCalendarSheet(userId: user.uid),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'afficher le calendrier des dividendes.'),
        ),
      );
    }
  }

  void _showUserProfile(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: UserProfileHeader(onLogout: _logout),
            ),
          ),
    );
  }

  Future<void> _showNameDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    // 1. Vérifier les gemmes
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      final snapshot = await userRef.get();
      final int gems = (snapshot.data()?['gems'] as num?)?.toInt() ?? 0;

      if (gems < 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Il vous faut 200 gemmes pour changer de nom.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint("Erreur lecture gemmes: $e");
      return;
    }

    final controller = TextEditingController(text: _displayName ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier votre nom (200 💎)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Changer de pseudo coûte 200 gemmes. Voulez-vous continuer ?",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau nom',
                    hintText: 'Entrez votre nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Indiquez votre nom.';
                    }
                    if (value.trim().length < 2) {
                      return 'Nom trop court.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text(
                'Payer 200 💎',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == null || result == _displayName) {
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentGems = (userDoc.data()?['gems'] as num?)?.toInt() ?? 0;

        if (currentGems < 200) {
          throw Exception("Pas assez de gemmes");
        }

        transaction.update(userRef, {'gems': currentGems - 200});
        transaction.set(userRef, {
          'Name': result,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nom modifié avec succès ! (-200 💎)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains("Pas assez")
                ? "Pas assez de gemmes !"
                : 'Erreur lors de la modification.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    final raw = query.trim();
    if (raw.length < 2) {
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
        priority: _searchPriority,
      );

      final shouldUseFuzzyFallback =
          ordered.length < 8 ||
          !hasStrongSearchMatch(ordered, raw, priority: _searchPriority);

      if (shouldUseFuzzyFallback) {
        final fuzzyResults = await _collectSearchResults(
          searchTerms,
          enableFuzzyQuery: true,
        );
        deduped = _dedupeResults([...deduped, ...fuzzyResults]);
        ordered = rankSearchSuggestions(
          candidates: deduped,
          query: raw,
          priority: _searchPriority,
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
        _suggestions.clear();
        _searchCandidates.clear();
        _isSearching = false;
        _suggestionMessage = 'Erreur réseau — vérifie la connexion';
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

  void _applySuggestionPriority(SearchInstrumentPriority priority) {
    if (_searchPriority == priority) return;
    final query = _searchController.text.trim();
    final ranked =
        _searchCandidates.isEmpty || query.length < 2
            ? const <TickerSearchResult>[]
            : rankSearchSuggestions(
              candidates: _searchCandidates,
              query: query,
              priority: priority,
            );

    setState(() {
      _searchPriority = priority;
      _suggestions
        ..clear()
        ..addAll(ranked);
      if (_searchCandidates.isNotEmpty) {
        _suggestionMessage =
            ranked.isEmpty ? "Aucun résultat pour '$query'" : null;
      }
    });
  }

  // ————— UI —————
  @override
  Widget build(BuildContext context) {
    final bool focused = _focusNode.hasFocus;
    final bool hasText = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: const ValueKey('home-tab'),
            child: _buildHome(focused, hasText),
          ),
        ),
      ),
    );
  }

  Widget _buildHome(bool focused, bool hasText) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _displayName;
    final greetingText =
        _loadingName
            ? 'Bonjour'
            : (displayName == null || displayName.isEmpty
                ? 'Bonjour'
                : 'Bonjour, $displayName');
    final canEditName = user != null && !_loadingName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showUserProfile(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [_gold, _wine],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.2),
                    child:
                        _avatarId != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                _getAvatarAsset(_avatarId!),
                                fit: BoxFit.cover,
                              ),
                            )
                            : const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greetingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Changer de nom',
                child: InkWell(
                  onTap: canEditName ? _showNameDialog : null,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: canEditName ? 1 : .5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _chipBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.edit_rounded, size: 16, color: _ink),
                          SizedBox(width: 8),
                          Text(
                            'Nom',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: WalletBalances(auth: FirebaseAuth.instance, compact: true),
        ),

        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ScaleTransition(
            scale: _titleScale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recherche boursière',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  width: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [_gold, _wine],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  focused || hasText
                      ? _gold.withValues(alpha: .06)
                      : _bg.withValues(alpha: .5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    focused || hasText ? _wine.withValues(alpha: .35) : _line,
              ),
              boxShadow: [
                if (focused || hasText)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.manage_search_rounded,
                  color: focused || hasText ? _wine : _muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: 'Rechercher une action, un ETF ou un fonds',
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => _fetchSuggestions(value),
                        );
                        setState(() {
                          _selectedSuggestion =
                              null; // une saisie clavier annule la sélection confirmée
                        });
                      },
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un titre / ticker…',
                        hintStyle: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder:
                      (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                  child:
                      (_selectedSuggestion != null && hasText)
                          ? Padding(
                            key: const ValueKey('goInfo'),
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => _goToInfo(_selectedSuggestion!),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    colors: [_gold, _wine],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .12,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
                AnimatedOpacity(
                  opacity: hasText ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    onPressed:
                        hasText
                            ? () => setState(() {
                              _searchController.clear();
                              _suggestions.clear();
                              _searchCandidates.clear();
                              _selectedSuggestion = null;
                              _suggestionMessage = null;
                              _isSearching = false;
                            })
                            : null,
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchPrioritySelector(
            priority: _searchPriority,
            onChanged: _applySuggestionPriority,
          ),
        ),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DividendCalendarButton(onTap: _openDividendCalendar),
        ),

        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  _suggestions.isEmpty
                      ? (_isSearching
                          ? const _LoadingState(key: ValueKey('loading'))
                          : (_suggestionMessage != null
                              ? _MessageState(
                                key: const ValueKey('message'),
                                message: _suggestionMessage!,
                              )
                              : const _EmptyState(key: ValueKey('empty'))))
                      : _SuggestionList(
                        key: const ValueKey('list'),
                        suggestions: _suggestions,
                        selectedPriority: _searchPriority,
                        onTap:
                            (item) => setState(() {
                              _searchController.text = item.symbol;
                              _selectedSuggestion =
                                  item; // déclenche l’affichage du bouton rond noir
                              _suggestions.clear();
                              _suggestionMessage = null;
                              FocusScope.of(context).unfocus();
                            }),
                      ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SearchPrioritySelector extends StatelessWidget {
  const _SearchPrioritySelector({
    required this.priority,
    required this.onChanged,
  });

  final SearchInstrumentPriority priority;
  final ValueChanged<SearchInstrumentPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SearchPriorityChip(
          label: 'Actions',
          selected: priority == SearchInstrumentPriority.equities,
          onTap: () => onChanged(SearchInstrumentPriority.equities),
        ),
        _SearchPriorityChip(
          label: 'Tout',
          selected: priority == SearchInstrumentPriority.all,
          onTap: () => onChanged(SearchInstrumentPriority.all),
        ),
        _SearchPriorityChip(
          label: 'ETF',
          selected: priority == SearchInstrumentPriority.etfs,
          onTap: () => onChanged(SearchInstrumentPriority.etfs),
        ),
        _SearchPriorityChip(
          label: 'Fonds',
          selected: priority == SearchInstrumentPriority.funds,
          onTap: () => onChanged(SearchInstrumentPriority.funds),
        ),
      ],
    );
  }
}

class _SearchPriorityChip extends StatelessWidget {
  const _SearchPriorityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected
                    ? detailsColor2.withValues(alpha: .32)
                    : const Color(0xFFE6E8EB),
          ),
          gradient:
              selected
                  ? LinearGradient(
                    colors: [
                      detailsColor1.withValues(alpha: .16),
                      detailsColor2.withValues(alpha: .12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: selected ? null : Colors.white,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? detailsColor2 : textColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    super.key,
    required this.suggestions,
    required this.selectedPriority,
    required this.onTap,
  });
  final List<TickerSearchResult> suggestions;
  final SearchInstrumentPriority selectedPriority;
  final ValueChanged<TickerSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          itemCount: suggestions.length,
          separatorBuilder:
              (_, __) => const Divider(height: 1, color: Color(0xFFF0F1F3)),
          itemBuilder: (context, i) {
            final item = suggestions[i];
            final bool hasDistinctName =
                item.displayName.toUpperCase() != item.symbol.toUpperCase();
            final exchange =
                item.exchange.isNotEmpty ? item.exchange : item.region;
            final marketLine = <String>[
              if (exchange.isNotEmpty) exchange,
              if (item.currency.isNotEmpty) item.currency,
            ].join(' • ');
            final isPrioritized =
                (selectedPriority == SearchInstrumentPriority.all &&
                    item.isEquity &&
                    item.isFrenchListed) ||
                (selectedPriority == SearchInstrumentPriority.equities &&
                    item.isEquity) ||
                (selectedPriority == SearchInstrumentPriority.etfs &&
                    item.isEtf) ||
                (selectedPriority == SearchInstrumentPriority.funds &&
                    item.isMutualFund);
            return InkWell(
              onTap: () {
                onTap(item);
              },
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
                      color:
                          isPrioritized
                              ? detailsColor2.withValues(alpha: .92)
                              : Colors.black54,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _SuggestionTypeBadge(
                                label: item.instrumentLabel,
                                highlighted: isPrioritized,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black45,
                      size: 18,
                    ),
                  ],
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

class _SuggestionTypeBadge extends StatelessWidget {
  const _SuggestionTypeBadge({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            highlighted
                ? detailsColor1.withValues(alpha: .16)
                : const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              highlighted
                  ? detailsColor2.withValues(alpha: .18)
                  : const Color(0xFFE6E8EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? detailsColor2 : textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.manage_search_rounded, size: 40, color: Colors.black54),
            SizedBox(height: 10),
            Text(
              'Tapez un nom ou un ticker pour commencer',
              style: TextStyle(color: Colors.black54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DividendCalendarButton extends StatelessWidget {
  const _DividendCalendarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available_rounded, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Calendrier des dividendes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: .85),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          style: const TextStyle(color: Colors.black54, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder:
          (_, __) => Container(
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E8EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
    );
  }
}
