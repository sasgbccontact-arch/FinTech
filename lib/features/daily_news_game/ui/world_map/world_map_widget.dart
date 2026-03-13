import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fintech/core/constants.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/countries_fr.dart';
import '../../models/news_article.dart';
import '../../repositories/daily_news_game_repository.dart';
import '../../repositories/quiz_repository.dart';
import '../../services/gdelt_news_service.dart';
import '../quiz/quiz_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorldMapWidget
// - Portrait: suggestion animée de passer en paysage + fallback liste pays
// - Paysage: carte interactive plein écran → sélection pays → confirmation →
//            chargement article → affichage article en portrait
// ─────────────────────────────────────────────────────────────────────────────

class WorldMapWidget extends StatefulWidget {
  /// Appelé lorsque l'utilisateur sélectionne un pays (fallback liste/chips).
  /// (On conserve ce callback pour l'intégration existante.)
  final void Function(CountryInfo country) onCountryTap;

  /// ISO-2 du pays sélectionné (chip en dégradé).
  final String? selectedIso2;
  final String? sessionId;
  final Future<void> Function(CountryInfo country)? onCountryPrefetch;
  final Future<NewsArticle?> Function(CountryInfo country)?
  countryArticleLoader;
  final Future<void> Function()? onQuizCompleted;

  const WorldMapWidget({
    super.key,
    required this.onCountryTap,
    this.selectedIso2,
    this.sessionId,
    this.onCountryPrefetch,
    this.countryArticleLoader,
    this.onQuizCompleted,
  });

  @override
  State<WorldMapWidget> createState() => _WorldMapWidgetState();
}

class _WorldMapWidgetState extends State<WorldMapWidget>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _query = '';

  late final AnimationController _rotateCtl;

  @override
  void initState() {
    super.initState();
    _rotateCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateCtl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<CountryInfo>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kCountriesByRegion;

    final result = <String, List<CountryInfo>>{};
    for (final entry in kCountriesByRegion.entries) {
      final matches =
          entry.value
              .where(
                (c) =>
                    c.nameFr.toLowerCase().contains(q) ||
                    c.nameEn.toLowerCase().contains(q) ||
                    c.iso2.toLowerCase() == q,
              )
              .toList();
      if (matches.isNotEmpty) result[entry.key] = matches;
    }
    return result;
  }

  // Removed _openLandscapeMap (no longer needed).

  Widget _buildRotatePromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Carte',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AnimatedBuilder(
                animation: _rotateCtl,
                builder: (_, __) {
                  final t = (_rotateCtl.value - 0.5) * 2;
                  return Transform.rotate(
                    angle: t * 0.22,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [detailsColor1, detailsColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.screen_rotation_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pour une meilleure expérience, ouvre la carte en mode paysage.\nSinon, utilise la liste des pays ci-dessous.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tourne ton téléphone en paysage sur cette page : la carte s’ouvrira automatiquement.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context);
        final size = mq.size;
        final isLandscapeByConstraints =
            constraints.maxWidth > constraints.maxHeight;
        final isLandscapeBySize = size.width > size.height;
        final isLandscape = isLandscapeByConstraints || isLandscapeBySize;

        debugPrint(
          '[WorldMap] layout: constraints=(${constraints.maxWidth.toStringAsFixed(1)}x${constraints.maxHeight.toStringAsFixed(1)}) '
          'mqSize=(${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}) '
          'landscape(constraints)=$isLandscapeByConstraints landscape(size)=$isLandscapeBySize -> $isLandscape',
        );

        if (isLandscape) {
          return _LandscapeWorldMapPanel(
            sessionId: widget.sessionId,
            onCountryPrefetch: widget.onCountryPrefetch,
            countryArticleLoader: widget.countryArticleLoader,
            onQuizCompleted: widget.onQuizCompleted,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlobeHeader(),
            const SizedBox(height: 16),
            _buildRotatePromptCard(),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Chercher un pays…',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.black38,
                    size: 20,
                  ),
                  suffixIcon:
                      _query.isNotEmpty
                          ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.black38,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              _buildEmpty()
            else
              ...filtered.entries.map(
                (entry) => _buildRegion(entry.key, entry.value),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRegion(String region, List<CountryInfo> countries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            region.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black38,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              countries
                  .map(
                    (c) => _CountryChip(
                      country: c,
                      selected:
                          c.iso2.toUpperCase() ==
                          (widget.selectedIso2?.toUpperCase() ?? ''),
                      onTap: () {
                        widget.onCountryTap(c);
                        if (widget.onCountryPrefetch != null) {
                          widget.onCountryPrefetch!(c);
                        }
                      },
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun pays trouvé pour "$_query"',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: detailsColor1.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🌍', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actualités mondiales',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Sélectionne un pays pour voir ses actus géopolitiques et économiques.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
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

class _CountryChip extends StatelessWidget {
  final CountryInfo country;
  final VoidCallback onTap;
  final bool selected;

  const _CountryChip({
    required this.country,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration:
            selected
                ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: detailsColor2.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
                : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              country.nameFr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountryArticlePage extends StatefulWidget {
  final CountryInfo country;
  final NewsArticle article;
  final String? sessionId;
  final Future<void> Function()? onQuizCompleted;

  const CountryArticlePage({
    super.key,
    required this.country,
    required this.article,
    this.sessionId,
    this.onQuizCompleted,
  });

  @override
  State<CountryArticlePage> createState() => _CountryArticlePageState();
}

class _CountryArticlePageState extends State<CountryArticlePage> {
  final _quizRepo = QuizRepository();
  bool _quizLoading = false;

  Future<void> _launchArticle(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final country = widget.country;
    final article = widget.article;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${country.flag} ${country.nameFr}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.source.isNotEmpty
                            ? article.source
                            : 'Source inconnue',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Text(
                      _relativeDate(article.publishedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.45,
                  ),
                ),
                if (article.snippet != null && article.snippet!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    article.snippet!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (article.url.isNotEmpty)
                  GestureDetector(
                    onTap: () => _launchArticle(article.url),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Lire l'article complet",
                          style: TextStyle(
                            fontSize: 13,
                            color: detailsColor1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: detailsColor1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _quizLoading ? null : _openQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child:
                  _quizLoading
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Passer au quiz →',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuiz() async {
    if (_quizLoading) return;

    final sessionId = widget.sessionId;
    if (sessionId == null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CountryFallbackQuizPage()),
      );
      return;
    }

    setState(() => _quizLoading = true);
    try {
      final questions = await _quizRepo.getOrCreateSessionQuiz(
        mode: DailyNewsGameMode.monde,
        sessionId: sessionId,
        articles: [widget.article],
        selectedCountryIso2: widget.country.iso2,
        selectedCountryNameFr: widget.country.nameFr,
      );

      debugPrint(
        '[WorldMapWidget] Quiz monde généré: session=$sessionId, questions=${questions.length}',
      );

      if (!mounted) return;

      final result = await Navigator.of(context).push<QuizPageResult>(
        MaterialPageRoute(
          builder:
              (_) => QuizPage(
                questions: questions,
                title: 'Quiz ${widget.country.nameFr}',
              ),
        ),
      );

      if (result != null) {
        await _quizRepo.saveQuizResult(
          mode: DailyNewsGameMode.monde,
          sessionId: sessionId,
          questions: questions,
          selectedAnswers: result.answers,
        );
        if (widget.onQuizCompleted != null) {
          await widget.onQuizCompleted!();
        }
      }
    } finally {
      if (mounted) setState(() => _quizLoading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape map panel for in-place landscape mode (not a separate page)
// ─────────────────────────────────────────────────────────────────────────────
class _LandscapeWorldMapPanel extends StatefulWidget {
  final String? sessionId;
  final Future<void> Function(CountryInfo country)? onCountryPrefetch;
  final Future<NewsArticle?> Function(CountryInfo country)?
  countryArticleLoader;
  final Future<void> Function()? onQuizCompleted;

  const _LandscapeWorldMapPanel({
    this.sessionId,
    this.onCountryPrefetch,
    this.countryArticleLoader,
    this.onQuizCompleted,
  });

  @override
  State<_LandscapeWorldMapPanel> createState() =>
      _LandscapeWorldMapPanelState();
}

class _LandscapeWorldMapPanelState extends State<_LandscapeWorldMapPanel>
    with SingleTickerProviderStateMixin {
  String? _selectedIso2;
  String? _selectedMapId;
  CountryInfo? _selectedCountry;
  bool _loading = false;

  late final AnimationController _pulseCtl;
  late final Animation<Color?> _pulseColor;

  @override
  void initState() {
    super.initState();
    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseColor = ColorTween(
      begin: detailsColor1,
      end: detailsColor2,
    ).animate(_pulseCtl);
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    super.dispose();
  }

  CountryInfo? _findCountry(String iso2) {
    final key = iso2.toUpperCase();
    for (final entry in kCountriesByRegion.entries) {
      for (final c in entry.value) {
        if (c.iso2.toUpperCase() == key) return c;
      }
    }
    return null;
  }

  String _normalizeMapIdToIso2(String rawId) {
    final letters = rawId.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    if (letters.length <= 2) return letters;
    return letters.substring(letters.length - 2);
  }

  Map<String, Color> _buildMapColors() {
    if (_selectedMapId == null) return const {};
    return <String, Color>{
      _selectedMapId!: (_pulseColor.value ?? detailsColor2),
    };
  }

  Future<void> _confirmAndLoad() async {
    final country = _selectedCountry;
    if (country == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Voir un article — ${country.nameFr}'),
              content: const Text(
                'On va charger un article géopolitique/économique lié à ce pays.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Charger'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    // Bloque le retour en portrait pendant le chargement (sinon le layout peut buguer)
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    setState(() => _loading = true);

    NewsArticle? article;
    try {
      if (widget.countryArticleLoader != null) {
        article = await widget.countryArticleLoader!(country);
      } else {
        article = await GdeltNewsService().fetchCountryArticle(
          countryIso2: country.iso2,
          countryNameEn: country.nameEn,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;

    // Ré-autorise les orientations du mode Monde après le fetch
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (article == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun article trouvé pour ce pays.')),
      );
      return;
    }

    // On force portrait juste avant d'afficher l'article
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CountryArticlePage(
              country: country,
              article: article!,
              sessionId: widget.sessionId,
              onQuizCompleted: widget.onQuizCompleted,
            ),
      ),
    );

    if (!mounted) return;

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tourne l’écran pour revenir à la carte'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _selectedMapId = null;
      _selectedIso2 = null;
      _selectedCountry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtl,
      builder: (context, _) {
        final colors = _buildMapColors();
        debugPrint(
          '[WorldMap] build landscape panel: selectedMapId=$_selectedMapId selectedIso2=$_selectedIso2 colorsKeys=${colors.keys.toList()}',
        );
        return Stack(
          children: [
            Column(
              children: [
                if (_selectedCountry != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 520;
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedCountry!.flag}  ${_selectedCountry!.nameFr}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _confirmAndLoad,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Charger un article',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_selectedCountry!.flag}  ${_selectedCountry!.nameFr}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _loading ? null : _confirmAndLoad,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Charger un article',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: Colors.black.withValues(alpha: 0.03),
                    child: const Text(
                      'Touche un pays pour le sélectionner.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Builder(
                  builder: (context) {
                    final screenH = MediaQuery.of(context).size.height;
                    // En bottom sheet / ListView, on n'a pas toujours une contrainte de hauteur bornée.
                    // On fixe donc une hauteur raisonnable pour que la carte s'affiche.
                    final mapH = (screenH * 0.70).clamp(220.0, 420.0);
                    return SizedBox(
                      height: mapH,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 12,
                        child: Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.98,
                            child: SimpleMap(
                              instructions: SMapWorld.instructions,
                              defaultColor: Colors.black.withValues(
                                alpha: 0.10,
                              ),
                              colors: colors,
                              callback: (id, name, tapDetails) {
                                if (_loading) return;
                                debugPrint(
                                  '[WorldMap] tap rawId=$id name=$name',
                                );
                                final mapId = id;
                                final iso2 = _normalizeMapIdToIso2(id);
                                final country = _findCountry(iso2);
                                debugPrint(
                                  '[WorldMap] normalized iso2=$iso2 mapId=$mapId foundCountry=${country?.nameEn}',
                                );
                                if (country == null) return;
                                setState(() {
                                  _selectedMapId = mapId;
                                  _selectedIso2 = iso2;
                                  _selectedCountry = country;
                                });
                                if (widget.onCountryPrefetch != null) {
                                  widget.onCountryPrefetch!(country);
                                }
                                debugPrint(
                                  '[WorldMap] setState selectedMapId=$_selectedMapId (will color it)',
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_loading)
              Container(
                color: Colors.black.withValues(alpha: 0.25),
                alignment: Alignment.center,
                child: Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [detailsColor1, detailsColor2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "Chargement de l'article…",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 22),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: detailsColor1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback Quiz Page ("OUI/NON" quiz)
// ─────────────────────────────────────────────────────────────────────────────
class CountryFallbackQuizPage extends StatefulWidget {
  const CountryFallbackQuizPage({super.key});

  @override
  State<CountryFallbackQuizPage> createState() =>
      _CountryFallbackQuizPageState();
}

class _CountryFallbackQuizPageState extends State<CountryFallbackQuizPage> {
  bool? _answer; // null = pas répondu

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Quiz',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [detailsColor1, detailsColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.quiz_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Quiz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Avez-vous compris les enjeux de l'actualité économique ?",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (_answer == null) ...[
                  _QuizChoiceButton(
                    label: 'OUI',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF1FC182),
                    onTap: () => setState(() => _answer = true),
                  ),
                  const SizedBox(height: 12),
                  _QuizChoiceButton(
                    label: 'NON',
                    icon: Icons.cancel_outlined,
                    color: Colors.redAccent,
                    onTap: () => setState(() => _answer = false),
                  ),
                ] else
                  _QuizFeedback(correct: _answer!),
                if (_answer != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terminer',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuizChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(102)), // 0.4*255 ≈ 102
          borderRadius: BorderRadius.circular(12),
          color: color.withAlpha(15), // 0.06*255 ≈ 15
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizFeedback extends StatelessWidget {
  final bool correct;

  const _QuizFeedback({required this.correct});

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF1FC182) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20), // 0.08*255 ≈ 20
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)), // 0.3*255 ≈ 76
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              correct
                  ? "Parfait ! Tu es bien informé(e)."
                  : "Pas de souci, reviens demain pour t'améliorer !",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
