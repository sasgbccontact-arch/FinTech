import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../layouts/navigation_footer.dart';
import '../services/yahoo_finance_service.dart';
import 'info_page.dart';

/// Page de recherche – UI modernisée (noir / blanc / gris) + micro-animations
/// - Nouvelle typographie (sans-serif moderne via TextTheme Roboto par défaut)
/// - Couleurs sobres et cohérentes
/// - Animations discrètes: focus du champ, apparition des suggestions, scale sur le titre
class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<TickerSearchResult> _suggestions = [];
  Timer? _debounce;
  String _pseudo = '';
  int _currentIndex = 0; // Footer selected tab
  TickerSearchResult? _selectedSuggestion;
  String? _suggestionMessage;
  bool _isSearching = false;
  int _searchRequestId = 0;

  // Animation pour le titre
  late final AnimationController _titleCtrl;
  late final Animation<double> _titleScale;

  // Palette
  static const Color _bg = Color(0xFFF5F6F7);
  static const Color _card = Colors.white;
  static const Color _ink = Colors.black87;
  static const Color _muted = Colors.black54;
  static const Color _line = Color(0xFFE6E8EB);

  // --- Helpers for search normalization & exchange filtering ---
  // Remove French accents / common diacritics and normalize dashes/spaces
  String _normalizeQuery(String input) {
    const mappings = {
      'à':'a','á':'a','â':'a','ä':'a','ã':'a','å':'a','À':'A','Á':'A','Â':'A','Ä':'A','Ã':'A','Å':'A',
      'æ':'ae','Æ':'AE','œ':'oe','Œ':'OE',
      'ç':'c','Ç':'C',
      'è':'e','é':'e','ê':'e','ë':'e','È':'E','É':'E','Ê':'E','Ë':'E',
      'ì':'i','í':'i','î':'i','ï':'i','Ì':'I','Í':'I','Î':'I','Ï':'I',
      'ñ':'n','Ñ':'N',
      'ò':'o','ó':'o','ô':'o','ö':'o','õ':'o','Ò':'O','Ó':'O','Ô':'O','Ö':'O','Õ':'O',
      'ù':'u','ú':'u','û':'u','ü':'u','Ù':'U','Ú':'U','Û':'U','Ü':'U',
      'ý':'y','ÿ':'y','Ý':'Y'
    };
    final sb = StringBuffer();
    for (final ch in input.runes) {
      final s = String.fromCharCode(ch);
      sb.write(mappings[s] ?? s);
    }
    // Replace various dash characters with spaces and collapse whitespace
    final noDashes = sb.toString().replaceAll(RegExp(r"[\-‐‑–—−]"), ' ');
    return noDashes.replaceAll(RegExp(r"\s+"), ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _titleScale = Tween<double>(begin: .98, end: 1.0).animate(CurvedAnimation(
      parent: _titleCtrl,
      curve: Curves.easeOutBack,
    ));

    _titleCtrl.forward();

    _focusNode.addListener(() => setState(() {}));
    _loadPseudo().then((_) {
      if (_pseudo.isEmpty) _showPseudoDialog();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPseudo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _pseudo = prefs.getString('pseudo') ?? '');
  }

  Future<void> _setPseudo(String pseudo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pseudo', pseudo);
    setState(() => _pseudo = pseudo);
  }

  void _goToInfo(TickerSearchResult suggestion) async {
    try {
      await showCupertinoModalBottomSheet(
        context: context,
        expand: true, // pleine hauteur avec animation iOS
        builder: (ctx) => InfoPage(
          ticker: suggestion.symbol,
          initialName: suggestion.displayName,
          initialExchange: suggestion.exchange,
          initialCurrency: suggestion.currency,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir la fiche de l'action.")),
      );
    }
  }

  Future<void> _showPseudoDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Votre nom d'utilisateur"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Entrez un nom (≥ 3 caractères)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          TextButton(
            onPressed: () async {
              final v = controller.text.trim();
              if (v.length >= 3) {
                await _setPseudo(v);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // --- Search logic (placeholder à remplacer par l'API finance) ---
  Future<void> _fetchSuggestions(String query) async {
    final raw = query.trim();
    if (raw.length < 2) {
      setState(() {
        _suggestions.clear();
        _suggestionMessage = null;
        _isSearching = false;
      });
      return;
    }

    final normalized = _normalizeQuery(raw);
    final queries = <String>{raw};
    if (normalized.isNotEmpty && normalized != raw) {
      queries.add(normalized);
    }

    final requestId = ++_searchRequestId;

    setState(() {
      _isSearching = true;
      _suggestionMessage = null;
    });

    final aggregated = <TickerSearchResult>[];

    try {
      for (final term in queries) {
        final results = await YahooFinanceService.searchEquities(term);
        aggregated.addAll(results);
      }
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _suggestions.clear();
        _isSearching = false;
        _suggestionMessage = 'Erreur réseau — vérifie la connexion';
      });
      return;
    }

    if (!mounted || requestId != _searchRequestId) return;

    final deduped = <String, TickerSearchResult>{};
    for (final item in aggregated) {
      deduped.putIfAbsent(item.symbol, () => item);
    }

    final ordered = deduped.values.take(15).toList();

    setState(() {
      _suggestions
        ..clear()
        ..addAll(ordered);
      _isSearching = false;
      _suggestionMessage = ordered.isEmpty ? "Aucun résultat pour '$raw'" : null;
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
          child: _currentIndex == 0 ? _buildHome(focused, hasText) : _buildPlaceholderTab(),
        ),
      ),
      bottomNavigationBar: NavigationFooter(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  Widget _buildHome(bool focused, bool hasText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pseudo.isEmpty ? 'Bonjour' : 'Bonjour, $_pseudo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
                ),
              ),
              IconButton(
                tooltip: 'Changer de nom',
                onPressed: _showPseudoDialog,
                icon: const Icon(Icons.edit, color: _muted),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),
        Center(
          child: ScaleTransition(
            scale: _titleScale,
            child: const Text(
              'Recherche boursière',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
                color: _ink,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
              boxShadow: [
                if (focused || hasText)
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 250), () => _fetchSuggestions(value));
                      setState(() {
                        _selectedSuggestion = null; // une saisie clavier annule la sélection confirmée
                      });
                    },
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _ink),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un titre / ticker…',
                      hintStyle: TextStyle(color: _muted, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: (_selectedSuggestion != null && hasText)
                      ? Padding(
                          key: const ValueKey('goInfo'),
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _goToInfo(_selectedSuggestion!),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search, color: Colors.white, size: 18),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedOpacity(
                  opacity: hasText ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    onPressed: hasText
                      ? () => setState(() {
                            _searchController.clear();
                            _suggestions.clear();
                            _selectedSuggestion = null;
                            _suggestionMessage = null;
                          })
                      : null,
                    icon: const Icon(Icons.close, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _suggestions.isEmpty
                  ? (_isSearching
                      ? const _LoadingState(key: ValueKey('loading'))
                      : (_suggestionMessage != null
                          ? _MessageState(key: const ValueKey('message'), message: _suggestionMessage!)
                          : const _EmptyState(key: ValueKey('empty'))))
                  : _SuggestionList(
                      key: const ValueKey('list'),
                      suggestions: _suggestions,
                      onTap: (item) => setState(() {
                        _searchController.text = item.symbol;
                        _selectedSuggestion = item; // déclenche l’affichage du bouton rond noir
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

  Widget _buildPlaceholderTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.construction_rounded, color: Colors.black54, size: 32),
          SizedBox(height: 12),
          Text('Section en cours de préparation', style: TextStyle(color: Colors.black54, fontSize: 16)),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({Key? key, required this.suggestions, required this.onTap}) : super(key: key);
  final List<TickerSearchResult> suggestions;
  final ValueChanged<TickerSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE6E8EB)),
        ),
        child: ListView.separated(
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE6E8EB)),
          itemBuilder: (context, i) {
            final item = suggestions[i];
            final bool hasDistinctName = item.displayName.toUpperCase() != item.symbol.toUpperCase();
            final label = hasDistinctName ? '${item.symbol} — ${item.displayName}' : item.symbol;
            final exchange = item.exchange.isNotEmpty ? item.exchange : item.region;
            final suffix = exchange.isNotEmpty ? ' ($exchange)' : '';
            return InkWell(
              onTap: () {
                onTap(item);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.sell_rounded, color: Colors.black54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$label$suffix',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                    const Icon(Icons.north_east_rounded, color: Colors.black45, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.search_rounded, size: 40, color: Colors.black54),
        SizedBox(height: 10),
        Text(
          'Tapez un nom ou un ticker pour commencer',
          style: TextStyle(color: Colors.black54, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({Key? key, required this.message}) : super(key: key);

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
  const _LoadingState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
