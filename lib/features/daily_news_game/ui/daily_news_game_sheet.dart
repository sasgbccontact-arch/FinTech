import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fintech/core/constants.dart';
import '../data/countries_fr.dart';
import '../models/news_article.dart';
import '../repositories/daily_news_game_repository.dart';
import '../repositories/quiz_repository.dart';
import 'daily_news_choice_page.dart';
import 'quiz/quiz_page.dart';
import 'world_map/world_map_widget.dart';

const _accentGradient = LinearGradient(
  colors: [detailsColor1, detailsColor2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 14,
    offset: const Offset(0, 6),
  ),
];

BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: borderColor ?? Colors.black.withValues(alpha: 0.06),
  ),
  boxShadow: _softShadow,
);

class DailyNewsGameSheet extends StatefulWidget {
  final int? initialMode;

  const DailyNewsGameSheet({super.key, this.initialMode});

  @override
  State<DailyNewsGameSheet> createState() => _DailyNewsGameSheetState();
}

class _DailyNewsGameSheetState extends State<DailyNewsGameSheet> {
  final _repo = DailyNewsGameRepository();
  final _quizRepo = QuizRepository();

  int? _selectedMode;
  bool _modeStarting = false;

  String? _sessionId;
  DailyNewsGameMode? _sessionMode;

  bool _loadingActus = false;
  bool _retryingActus = false;
  bool _quizLoading = false;

  List<NewsArticle> _actusArticles = const [];
  int _actusCurrentIndex = 0;
  bool _actusFetchFailed = false;

  Future<void> _goToGameTab() async {
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((route) => route.isFirst);
    nav.pushReplacementNamed('/game');
  }

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _applyOrientationPolicy();

    if (widget.initialMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pickMode(widget.initialMode!);
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _applyOrientationPolicy() async {
    if (_selectedMode != 1) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      return;
    }

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _pickMode(int modeIndex) async {
    if (_modeStarting) return;

    final mode =
        modeIndex == 0 ? DailyNewsGameMode.actus : DailyNewsGameMode.monde;

    setState(() => _modeStarting = true);

    try {
      final startResult = await _repo.startPaidSession(mode);
      if (!mounted) return;

      if (!startResult.success || startResult.sessionId == null) {
        await _showInsufficientGemsModal(
          current: startResult.currentGems,
          required: startResult.requiredGems,
          mode: mode,
        );
        return;
      }

      setState(() {
        _sessionId = startResult.sessionId;
        _sessionMode = mode;
        _selectedMode = modeIndex;

        if (mode == DailyNewsGameMode.actus) {
          _actusArticles = const [];
          _actusCurrentIndex = 0;
          _actusFetchFailed = false;
        }
      });

      if (startResult.usedFreeEntry) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session ${mode == DailyNewsGameMode.actus ? 'Actus du jour' : 'MapMonde'} offerte aujourd’hui.',
            ),
          ),
        );
      }

      await _applyOrientationPolicy();

      if (mode == DailyNewsGameMode.actus) {
        unawaited(_repo.prefetchDailyArticles());
        await _loadActusArticles();
      }
    } finally {
      if (mounted) {
        setState(() => _modeStarting = false);
      }
    }
  }

  Future<void> _showInsufficientGemsModal({
    required int current,
    required int required,
    required DailyNewsGameMode mode,
  }) async {
    final missing = required - current;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Gemmes insuffisantes'),
          content: Text(
            'Il faut $required gemmes pour lancer "${mode == DailyNewsGameMode.actus ? 'Actus du jour' : 'MapMonde'}".\n'
            'Solde actuel: $current\n'
            'Il te manque: $missing\n\n'
            'La première session quotidienne de chaque mode est gratuite.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadActusArticles() async {
    final sid = _sessionId;
    if (sid == null) return;

    setState(() {
      _loadingActus = true;
      _actusFetchFailed = false;
      _actusArticles = const [];
      _actusCurrentIndex = 0;
    });

    try {
      final result = await _repo.fetchDailyArticles();
      if (!mounted) return;

      setState(() {
        _actusArticles = result.articles;
        _actusFetchFailed = result.fetchFailed;
      });

      await _repo.saveSessionArticles(
        mode: DailyNewsGameMode.actus,
        sessionId: sid,
        articles: result.articles,
      );
      debugPrint(
        '[DailyNewsGameSheet] Actus chargées: source=${result.sourceType}, cacheHit=${result.cacheHit}, nb=${result.articles.length}',
      );
    } finally {
      if (mounted) {
        setState(() => _loadingActus = false);
      }
    }
  }

  Future<void> _openActusQuiz() async {
    final sid = _sessionId;
    if (sid == null) return;

    setState(() => _quizLoading = true);
    try {
      final questions = await _quizRepo.getOrCreateSessionQuiz(
        mode: DailyNewsGameMode.actus,
        sessionId: sid,
        articles: _actusArticles,
      );

      debugPrint(
        '[DailyNewsGameSheet] Quiz Actus prêt: ${questions.length} questions',
      );

      if (!mounted) return;

      final result = await Navigator.of(context).push<QuizPageResult>(
        MaterialPageRoute(
          builder:
              (_) =>
                  QuizPage(questions: questions, title: 'Quiz Actus du jour'),
        ),
      );

      if (result != null) {
        await _quizRepo.saveQuizResult(
          mode: DailyNewsGameMode.actus,
          sessionId: sid,
          questions: questions,
          selectedAnswers: result.answers,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Score enregistré: ${result.score}/${result.total}'),
          ),
        );
        await _goToGameTab();
      }
    } finally {
      if (mounted) {
        setState(() => _quizLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: _accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.newspaper_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Actu & Quiz',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_selectedMode == null)
            _buildModeChoice()
          else if (_selectedMode == 0)
            _buildActusBody()
          else
            _buildMondeBody(),
          if (_modeStarting)
            Container(
              color: Colors.black.withValues(alpha: 0.30),
              alignment: Alignment.center,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: detailsColor1,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Préparation de la session…',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeChoice() {
    return DailyNewsChoicePage(
      onPickActus: () => _pickMode(0),
      onPickMonde: () => _pickMode(1),
    );
  }

  Widget _buildActusBody() {
    if (_loadingActus) {
      return const Center(
        child: CircularProgressIndicator(
          color: detailsColor1,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_actusArticles.isEmpty) {
      if (_actusFetchFailed) return _buildFetchFailed();
      return _buildEmptyArticles();
    }

    if (_actusCurrentIndex >= _actusArticles.length) {
      return _buildQuizLaunch(
        title: 'Quiz de session',
        subtitle: 'Ton quiz dynamique est prêt pour cette session.',
        onStart: _openActusQuiz,
      );
    }

    return _buildArticleSection(
      article: _actusArticles[_actusCurrentIndex],
      current: _actusCurrentIndex + 1,
      total: _actusArticles.length,
      onNext: () {
        setState(() {
          _actusCurrentIndex++;
        });
      },
    );
  }

  Widget _buildMondeBody() {
    final sid = _sessionId;
    if (sid == null || _sessionMode != DailyNewsGameMode.monde) {
      return const Center(child: Text('Session invalide'));
    }

    return _MondeView(
      sessionId: sid,
      repo: _repo,
      quizRepo: _quizRepo,
      onQuizCompleted: _goToGameTab,
    );
  }

  Widget _buildArticleSection({
    required NewsArticle article,
    required int current,
    required int total,
    required VoidCallback onNext,
  }) {
    final isLast = current == total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProgressBar(current: current, total: total),
        const SizedBox(height: 16),
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  const Spacer(),
                  Text(
                    _relativeDate(article.publishedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
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
              if (article.snippet != null &&
                  article.snippet!.trim().isNotEmpty) ...[
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
                  onTap: () => _launchUrl(article.url),
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
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              isLast ? 'Passer au quiz →' : 'Article suivant →',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFetchFailed() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(24),
          child: const Column(
            children: [
              Icon(Icons.wifi_off_rounded, size: 52, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'Impossible de charger les actus',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Tu peux réessayer ou passer directement au quiz.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _retryingActus
                    ? null
                    : () async {
                      setState(() => _retryingActus = true);
                      try {
                        await _loadActusArticles();
                      } finally {
                        if (mounted) setState(() => _retryingActus = false);
                      }
                    },
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
                _retryingActus
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Réessayer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _retryingActus ? null : _openActusQuiz,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Passer au quiz →',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyArticles() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(24),
          child: const Column(
            children: [
              Icon(Icons.newspaper_rounded, size: 52, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'Aucun article disponible',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Le quiz se base alors sur les métadonnées de session.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _openActusQuiz,
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
              'Passer au quiz →',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizLaunch({
    required String title,
    required String subtitle,
    required Future<void> Function() onStart,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                gradient: _accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _quizLoading ? null : onStart,
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
                          'Commencer le quiz →',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} j';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Article $current / $total',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            minHeight: 5,
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(detailsColor1),
          ),
        ),
      ],
    );
  }
}

class _MondeView extends StatefulWidget {
  final String sessionId;
  final DailyNewsGameRepository repo;
  final QuizRepository quizRepo;
  final Future<void> Function() onQuizCompleted;

  const _MondeView({
    required this.sessionId,
    required this.repo,
    required this.quizRepo,
    required this.onQuizCompleted,
  });

  @override
  State<_MondeView> createState() => _MondeViewState();
}

class _MondeViewState extends State<_MondeView> {
  CountryInfo? _selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: _selected != null ? 88 : 16,
          ),
          children: [
            WorldMapWidget(
              onCountryTap: (c) => setState(() => _selected = c),
              onCountryPrefetch:
                  (c) => widget.repo.prefetchCountryArticle(
                    countryIso2: c.iso2,
                    countryNameEn: c.nameEn,
                  ),
              onQuizCompleted: widget.onQuizCompleted,
              countryArticleLoader: (c) async {
                final result = await widget.repo.fetchCountryArticle(
                  countryIso2: c.iso2,
                  countryNameEn: c.nameEn,
                );
                final article = result.article;
                if (article != null) {
                  await widget.repo.saveSessionArticles(
                    mode: DailyNewsGameMode.monde,
                    sessionId: widget.sessionId,
                    articles: [article],
                    countryIso2: c.iso2,
                    countryNameFr: c.nameFr,
                  );
                }
                return article;
              },
              selectedIso2: _selected?.iso2,
              sessionId: widget.sessionId,
            ),
          ],
        ),
        if (_selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildConfirmBar(context),
          ),
      ],
    );
  }

  Widget _buildConfirmBar(BuildContext context) {
    final c = _selected!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(c.flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.nameFr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => _CountryArticlePage(
                          country: c,
                          sessionId: widget.sessionId,
                          repo: widget.repo,
                          quizRepo: widget.quizRepo,
                          onQuizCompleted: widget.onQuizCompleted,
                        ),
                  ),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: detailsColor2,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.article_rounded, size: 18),
            label: const Text(
              "Voir l'actualité",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryArticlePage extends StatefulWidget {
  final CountryInfo country;
  final String sessionId;
  final DailyNewsGameRepository repo;
  final QuizRepository quizRepo;
  final Future<void> Function() onQuizCompleted;

  const _CountryArticlePage({
    required this.country,
    required this.sessionId,
    required this.repo,
    required this.quizRepo,
    required this.onQuizCompleted,
  });

  @override
  State<_CountryArticlePage> createState() => _CountryArticlePageState();
}

class _CountryArticlePageState extends State<_CountryArticlePage> {
  late Future<NewsArticle?> _fetchFuture;
  bool _quizLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _fetchFuture = _fetchAndPersist();
  }

  Future<NewsArticle?> _fetchAndPersist() async {
    final fetched = await widget.repo.fetchCountryArticle(
      countryIso2: widget.country.iso2,
      countryNameEn: widget.country.nameEn,
    );
    final article = fetched.article;

    if (article != null) {
      await widget.repo.saveSessionArticles(
        mode: DailyNewsGameMode.monde,
        sessionId: widget.sessionId,
        articles: [article],
        countryIso2: widget.country.iso2,
        countryNameFr: widget.country.nameFr,
      );
    }

    debugPrint(
      '[DailyNewsGameSheet] Monde article: source=${fetched.sourceType}, cacheHit=${fetched.cacheHit}, score=${fetched.bestScore}',
    );

    return article;
  }

  Future<void> _openQuiz(NewsArticle article) async {
    if (_quizLoading) return;

    setState(() => _quizLoading = true);
    try {
      final questions = await widget.quizRepo.getOrCreateSessionQuiz(
        mode: DailyNewsGameMode.monde,
        sessionId: widget.sessionId,
        articles: [article],
        selectedCountryIso2: widget.country.iso2,
        selectedCountryNameFr: widget.country.nameFr,
      );

      debugPrint(
        '[DailyNewsGameSheet] Quiz Monde prêt: ${questions.length} questions',
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
        await widget.quizRepo.saveQuizResult(
          mode: DailyNewsGameMode.monde,
          sessionId: widget.sessionId,
          questions: questions,
          selectedAnswers: result.answers,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Score enregistré: ${result.score}/${result.total}'),
          ),
        );
        await widget.onQuizCompleted();
      }
    } finally {
      if (mounted) {
        setState(() => _quizLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Text(c.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              c.nameFr,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<NewsArticle?>(
        future: _fetchFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: detailsColor1,
                strokeWidth: 2.5,
              ),
            );
          }
          if (snap.hasError) return _buildError();
          final article = snap.data;
          if (article == null) return _buildEmpty();
          return _buildArticle(article);
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.black26),
            const SizedBox(height: 20),
            const Text(
              "Impossible de charger l'article",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vérifie ta connexion et réessaie.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    () => setState(() {
                      _fetchFuture = _fetchAndPersist();
                    }),
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
                  'Réessayer',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Colors.black26,
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun article trouvé pour ${widget.country.nameFr}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Essaie un autre pays.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticle(NewsArticle article) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  const Spacer(),
                  Text(
                    _relativeDate(article.publishedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
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
              if (article.snippet != null &&
                  article.snippet!.trim().isNotEmpty) ...[
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
                  onTap: () => _launchUrl(article.url),
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
            onPressed: _quizLoading ? null : () => _openQuiz(article),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} j';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
