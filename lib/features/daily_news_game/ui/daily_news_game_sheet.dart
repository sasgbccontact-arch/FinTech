import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fintech/core/constants.dart';

import '../data/countries_fr.dart';
import '../models/news_article.dart';
import '../models/news_game_models.dart';
import '../repositories/daily_news_game_repository.dart';
import '../services/news_game_engine.dart';
import 'daily_news_choice_page.dart';
import 'world_map/world_map_widget.dart';

const _accentGradient = LinearGradient(
  colors: [detailsColor1, detailsColor2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const String _newsHeroSvg = '''
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
    <linearGradient id="violet" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2A0F45"/>
      <stop offset="100%" stop-color="#563078"/>
    </linearGradient>
  </defs>
  <rect x="20" y="28" width="180" height="144" rx="28" fill="#FFFFFF" stroke="#E8E4DA" stroke-width="4"/>
  <rect x="34" y="42" width="120" height="18" rx="9" fill="url(#gold)" opacity="0.92"/>
  <rect x="34" y="70" width="96" height="11" rx="5.5" fill="#EDE7D5"/>
  <rect x="34" y="88" width="118" height="11" rx="5.5" fill="#EDE7D5"/>
  <rect x="34" y="106" width="86" height="11" rx="5.5" fill="#EDE7D5"/>
  <path d="M56 150 C84 122, 106 132, 128 108 S168 86, 186 66" fill="none" stroke="url(#violet)" stroke-width="8" stroke-linecap="round"/>
  <circle cx="186" cy="66" r="8" fill="url(#gold)"/>
  <circle cx="160" cy="88" r="7" fill="#2A0F45"/>
  <circle cx="126" cy="108" r="7" fill="#2A0F45"/>
  <circle cx="90" cy="128" r="7" fill="#2A0F45"/>
  <circle cx="62" cy="144" r="7" fill="#2A0F45"/>
  <circle cx="164" cy="162" r="28" fill="none" stroke="url(#gold)" stroke-width="8"/>
  <path d="M183 181 L200 198" stroke="url(#violet)" stroke-width="10" stroke-linecap="round"/>
</svg>
''';

final _softShadow = <BoxShadow>[
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
];

BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
    color: borderColor ?? Colors.black.withValues(alpha: 0.06),
  ),
  boxShadow: _softShadow,
);

enum _NewsRunStage { forecast, questions, reveal, summary }

@visibleForTesting
class NewsGameUiPreview extends StatefulWidget {
  final bool deckReduced;
  final bool revealed;

  const NewsGameUiPreview({
    super.key,
    this.deckReduced = false,
    this.revealed = false,
  });

  @override
  State<NewsGameUiPreview> createState() => _NewsGameUiPreviewState();
}

class _NewsGameUiPreviewState extends State<NewsGameUiPreview> {
  NewsGameSubMode? _mode;

  @override
  Widget build(BuildContext context) {
    final fakeArticle = NewsArticle.fromRss(
      title: 'US inflation cools as bond traders price fewer hikes',
      url: 'https://example.com/fake',
      publishedAt: DateTime.now(),
      source: 'Reuters',
      snippet:
          'Les chiffres d’inflation se détendent et le marché relit immédiatement les taux, le dollar et les valeurs growth.',
    );
    final item = NewsGameEngine.buildDeckItem(fakeArticle);
    return MaterialApp(
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _NewsGameHeroCard(
                title: 'Deck du jour',
                subtitle:
                    widget.deckReduced
                        ? 'Deck réduit: le mode Sprint est verrouillé'
                        : 'Choisis ton tempo avant de lire le marché',
                qualitySummary:
                    widget.deckReduced
                        ? '2 cartes exploitables'
                        : '5 cartes jouables',
                categories: const <String>['Inflation', 'Taux', 'FX'],
                comboValue: 2,
                progressLabel: '1 / 5',
                motionValue: 0.35,
                showTimer: false,
                timerLabel: null,
              ),
              const SizedBox(height: 16),
              _ModeChoiceCard(
                sprintAvailable: !widget.deckReduced,
                selectedMode: _mode,
                onSelected: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 16),
              if (!widget.revealed)
                _ImpactPredictionCard(
                  item: item,
                  selectedTargets: const <String>{'growth'},
                  selectedDirections: const <String, PredictionDirection>{
                    'growth': PredictionDirection.bullish,
                  },
                  confidenceLevel: NewsConfidenceLevel.assumee,
                  onToggleTarget: (_) {},
                  onDirectionChanged: (_, __) {},
                  onConfidenceChanged: (_) {},
                  showSnippet: false,
                )
              else
                _RoundDebriefCard(
                  title: 'Score révélé',
                  marketScore: 82,
                  comprehensionScore: 100,
                  comboAfterRound: 3,
                  debrief: item.debrief,
                  correctTargets:
                      item.impactOptions
                          .where((option) => option.isExpectedTarget)
                          .map((option) => option)
                          .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyNewsGameSheet extends StatefulWidget {
  final int? initialMode;

  const DailyNewsGameSheet({super.key, this.initialMode});

  @override
  State<DailyNewsGameSheet> createState() => _DailyNewsGameSheetState();
}

class _DailyNewsGameSheetState extends State<DailyNewsGameSheet>
    with TickerProviderStateMixin {
  final _repo = DailyNewsGameRepository();

  late final AnimationController _motionCtl;

  int? _selectedMode;
  bool _modeStarting = false;

  String? _sessionId;
  DailyNewsGameMode? _sessionMode;

  NewsGameDeckResult? _dailyDeckResult;
  NewsGameSubMode? _actusSubMode;
  bool _loadingActus = false;
  bool _retryingActus = false;
  bool _savingCompletion = false;
  bool _completionSaved = false;
  bool _loadingLeaderboard = false;

  int _actusRoundIndex = 0;
  _NewsRunStage _actusStage = _NewsRunStage.forecast;
  final List<NewsRoundResult> _actusRounds = <NewsRoundResult>[];
  NewsRoundResult? _currentActusResult;
  final Set<String> _selectedTargetIds = <String>{};
  final Map<String, PredictionDirection> _selectedDirections =
      <String, PredictionDirection>{};
  NewsConfidenceLevel _selectedConfidence = NewsConfidenceLevel.prudente;
  List<int?> _selectedQuestionAnswers = const <int?>[];
  DateTime? _runStartedAt;
  Timer? _sprintTimer;
  Duration _sprintRemaining = const Duration(seconds: 90);
  List<Map<String, dynamic>> _weeklyLeaderboard =
      const <Map<String, dynamic>>[];
  NewsEntryStatus _entryStatus = const NewsEntryStatus(
    actusFreeToday: true,
    mondeFreeToday: true,
  );
  bool _loadingEntryStatus = false;

  String? _message;

  NewsGameDeckItem? get _currentActusItem {
    final deck = _dailyDeckResult?.deck ?? const <NewsGameDeckItem>[];
    if (_actusRoundIndex < 0 || _actusRoundIndex >= deck.length) return null;
    return deck[_actusRoundIndex];
  }

  int get _questionCountForCurrentMode =>
      _actusSubMode == NewsGameSubMode.sprint ? 1 : 2;

  @override
  void initState() {
    super.initState();
    _motionCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _selectedMode = widget.initialMode;
    _applyOrientationPolicy();
    unawaited(_loadEntryStatus());
    if (widget.initialMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pickMode(widget.initialMode!);
      });
    }
  }

  @override
  void dispose() {
    _sprintTimer?.cancel();
    _motionCtl.dispose();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _loadEntryStatus() async {
    setState(() => _loadingEntryStatus = true);
    try {
      final status = await _repo.loadEntryStatus();
      if (!mounted) return;
      setState(() {
        _entryStatus = status;
        _loadingEntryStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEntryStatus = false);
    }
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

    setState(() {
      _modeStarting = true;
      _message = null;
    });

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
        _dailyDeckResult = null;
        _actusSubMode = null;
        _actusRoundIndex = 0;
        _actusStage = _NewsRunStage.forecast;
        _actusRounds.clear();
        _currentActusResult = null;
        _completionSaved = false;
        _savingCompletion = false;
      });

      setState(() {
        _entryStatus = NewsEntryStatus(
          actusFreeToday:
              mode == DailyNewsGameMode.actus
                  ? false
                  : _entryStatus.actusFreeToday,
          mondeFreeToday:
              mode == DailyNewsGameMode.monde
                  ? false
                  : _entryStatus.mondeFreeToday,
        );
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
        await _loadActusDeck();
        await _loadWeeklyLeaderboard();
      }
    } finally {
      if (mounted) {
        setState(() => _modeStarting = false);
      }
    }
  }

  Future<void> _loadActusDeck() async {
    final sid = _sessionId;
    if (sid == null) return;

    setState(() {
      _loadingActus = true;
      _message = null;
      _dailyDeckResult = null;
      _actusSubMode = null;
      _completionSaved = false;
    });

    try {
      final result = await _repo.buildDailyDeck();
      if (!mounted) return;
      if (result.deck.isNotEmpty) {
        await _repo.saveSessionArticles(
          mode: DailyNewsGameMode.actus,
          sessionId: sid,
          articles: result.deck.map((item) => item.article).toList(),
        );
      }
      setState(() {
        _dailyDeckResult = result;
        _loadingActus = false;
        _message =
            result.fetchFailed
                ? 'Impossible de bâtir un deck propre pour le moment.'
                : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingActus = false;
        _message = 'Chargement des actus impossible: $error';
      });
    }
  }

  Future<void> _loadWeeklyLeaderboard() async {
    setState(() => _loadingLeaderboard = true);
    try {
      final rows = await _repo.fetchWeeklyLeaderboard();
      if (!mounted) return;
      setState(() {
        _weeklyLeaderboard = rows;
        _loadingLeaderboard = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLeaderboard = false);
    }
  }

  Future<void> _startActusMode(NewsGameSubMode subMode) async {
    final sid = _sessionId;
    final result = _dailyDeckResult;
    if (sid == null || result == null || result.deck.isEmpty) return;

    _resetActusSelection();
    setState(() {
      _actusSubMode = subMode;
      _actusRoundIndex = 0;
      _actusStage = _NewsRunStage.forecast;
      _actusRounds.clear();
      _currentActusResult = null;
      _runStartedAt = DateTime.now();
      _completionSaved = false;
      _savingCompletion = false;
      _sprintRemaining = const Duration(seconds: 90);
    });

    await _repo.saveSessionDeck(
      mode: DailyNewsGameMode.actus,
      sessionId: sid,
      subMode: subMode,
      deck: result.deck,
    );

    if (subMode == NewsGameSubMode.sprint) {
      _startSprintTimer();
    } else {
      _sprintTimer?.cancel();
    }
  }

  void _startSprintTimer() {
    _sprintTimer?.cancel();
    _sprintTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _actusSubMode != NewsGameSubMode.sprint) return;
      if (_actusStage == _NewsRunStage.summary) return;
      if (_sprintRemaining <= const Duration(seconds: 1)) {
        timer.cancel();
        setState(() => _sprintRemaining = Duration.zero);
        await _finishActusRunIfNeeded();
        return;
      }
      setState(() => _sprintRemaining -= const Duration(seconds: 1));
    });
  }

  void _resetActusSelection() {
    _selectedTargetIds.clear();
    _selectedDirections.clear();
    _selectedConfidence = NewsConfidenceLevel.prudente;
    _selectedQuestionAnswers = const <int?>[];
  }

  void _toggleTarget(String targetId) {
    setState(() {
      if (_selectedTargetIds.contains(targetId)) {
        _selectedTargetIds.remove(targetId);
        _selectedDirections.remove(targetId);
        return;
      }
      if (_selectedTargetIds.length >= 3) return;
      _selectedTargetIds.add(targetId);
      _selectedDirections[targetId] = PredictionDirection.neutral;
    });
  }

  void _setTargetDirection(String targetId, PredictionDirection direction) {
    if (!_selectedTargetIds.contains(targetId)) return;
    setState(() => _selectedDirections[targetId] = direction);
  }

  void _setQuestionAnswer(int index, int choiceIndex) {
    final nextAnswers = List<int?>.from(_selectedQuestionAnswers);
    if (index >= nextAnswers.length) return;
    nextAnswers[index] = choiceIndex;
    setState(() => _selectedQuestionAnswers = nextAnswers);
  }

  void _openActusAnalysis() {
    if (_selectedTargetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis au moins une cible avant de continuer.'),
        ),
      );
      return;
    }
    final count = math.min(
      _questionCountForCurrentMode,
      _currentActusItem?.comprehensionQuestions.length ?? 0,
    );
    setState(() {
      _actusStage = _NewsRunStage.questions;
      _selectedQuestionAnswers = List<int?>.filled(count, null);
    });
  }

  void _validateActusRound() {
    final item = _currentActusItem;
    if (item == null) return;
    final count = math.min(
      _questionCountForCurrentMode,
      item.comprehensionQuestions.length,
    );
    if (_selectedQuestionAnswers.length < count ||
        _selectedQuestionAnswers.take(count).any((answer) => answer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réponds à toutes les questions de compréhension.'),
        ),
      );
      return;
    }
    final predictions =
        _selectedTargetIds
            .map(
              (targetId) => NewsImpactPrediction(
                targetId: targetId,
                direction:
                    _selectedDirections[targetId] ??
                    PredictionDirection.neutral,
                confidenceLevel: _selectedConfidence,
              ),
            )
            .toList();

    final result = NewsGameEngine.resolveDeckRound(
      item: item,
      predictions: predictions,
      comprehensionAnswers: _selectedQuestionAnswers.take(count).toList(),
      currentCombo:
          _actusRounds.isEmpty ? 0 : _actusRounds.last.comboAfterRound,
      questionCount: count,
    );

    setState(() {
      _currentActusResult = result;
      _actusStage = _NewsRunStage.reveal;
      _actusRounds.add(result);
    });
  }

  Future<void> _goToNextActusRound() async {
    final deck = _dailyDeckResult?.deck ?? const <NewsGameDeckItem>[];
    if (_actusRoundIndex + 1 >= deck.length ||
        (_actusSubMode == NewsGameSubMode.sprint &&
            _sprintRemaining == Duration.zero)) {
      await _finishActusRunIfNeeded();
      return;
    }
    _resetActusSelection();
    setState(() {
      _actusRoundIndex += 1;
      _actusStage = _NewsRunStage.forecast;
      _currentActusResult = null;
    });
  }

  Future<void> _finishActusRunIfNeeded() async {
    final sid = _sessionId;
    final subMode = _actusSubMode;
    final result = _dailyDeckResult;
    if (_completionSaved ||
        _savingCompletion ||
        sid == null ||
        subMode == null ||
        result == null) {
      setState(() => _actusStage = _NewsRunStage.summary);
      return;
    }

    _sprintTimer?.cancel();
    setState(() {
      _savingCompletion = true;
      _actusStage = _NewsRunStage.summary;
    });

    final breakdown = NewsGameEngine.buildSessionBreakdown(_actusRounds);

    try {
      await _repo.completeGameRun(
        mode: DailyNewsGameMode.actus,
        sessionId: sid,
        subMode: subMode,
        deck: result.deck,
        rounds: _actusRounds,
        breakdown: breakdown,
        elapsed:
            _runStartedAt == null
                ? Duration.zero
                : DateTime.now().difference(_runStartedAt!),
      );
      if (!mounted) return;
      setState(() {
        _completionSaved = true;
        _savingCompletion = false;
      });
      await _loadWeeklyLeaderboard();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingCompletion = false;
        _message = 'Impossible d’enregistrer la session: $error';
      });
    }
  }

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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _accentGradient,
                borderRadius: BorderRadius.circular(10),
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
    final actusSubtitle =
        _entryStatus.actusFreeToday
            ? '1–3 actus\n+ quiz\nSession offerte\naujourd’hui'
            : '1–3 actus\n+ quiz\n(50 gemmes)';
    final mondeSubtitle =
        _entryStatus.mondeFreeToday
            ? 'Choisis\nun pays\n→ quiz\nSession offerte\naujourd’hui'
            : 'Choisis\nun pays\n→ quiz\n(100 gemmes)';
    return DailyNewsChoicePage(
      onPickActus: () => _pickMode(0),
      onPickMonde: () => _pickMode(1),
      actusSubtitle:
          _loadingEntryStatus ? 'Chargement\ndu tarif…' : actusSubtitle,
      mondeSubtitle:
          _loadingEntryStatus ? 'Chargement\ndu tarif…' : mondeSubtitle,
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

    final deckResult = _dailyDeckResult;
    if (deckResult == null || deckResult.deck.isEmpty) {
      return _buildActusEmptyState(deckResult);
    }

    final currentItem = _currentActusItem;
    final breakdown = NewsGameEngine.buildSessionBreakdown(_actusRounds);
    return StreamBuilder<NewsSessionProfile>(
      stream: _repo.watchNewsProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? NewsSessionProfile.empty;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _NewsGameHeroCard(
              title:
                  _actusSubMode == null
                      ? 'Deck du jour'
                      : 'Run marché en cours',
              subtitle:
                  _actusSubMode == null
                      ? 'Lis l’impact avant de lire l’article. Le marché bouge avant le quiz.'
                      : 'Double score: lecture de marché + compréhension.',
              qualitySummary: deckResult.qualitySummary,
              categories:
                  deckResult.deck
                      .map((item) => item.macroCategory.label)
                      .toSet()
                      .toList(),
              comboValue: breakdown.maxCombo,
              progressLabel:
                  '${math.min(_actusRoundIndex + 1, deckResult.deck.length)} / ${deckResult.deck.length}',
              motionValue: _motionCtl.value,
              showTimer: _actusSubMode == NewsGameSubMode.sprint,
              timerLabel: _formatDuration(_sprintRemaining),
            ),
            const SizedBox(height: 16),
            _QuestRibbon(
              comboProgress: math.min(3, breakdown.maxCombo),
              countryProgress: math.min(5, profile.countryAccuracy.length),
              ratesProgress:
                  ((profile.themeAccuracy['rates'] ?? 0) / 33.4)
                      .clamp(0, 3)
                      .toInt(),
            ),
            const SizedBox(height: 16),
            if (_message != null) ...[
              _InfoMessageCard(message: _message!),
              const SizedBox(height: 16),
            ],
            if (_actusSubMode == null) ...[
              _ModeChoiceCard(
                sprintAvailable: deckResult.sprintAvailable,
                selectedMode: _actusSubMode,
                onSelected: _startActusMode,
              ),
              const SizedBox(height: 16),
              _DeckPreviewCard(deck: deckResult.deck),
              const SizedBox(height: 16),
              _ProfileInsightsCard(profile: profile),
              const SizedBox(height: 16),
              _LeaderboardCard(
                rows: _weeklyLeaderboard,
                loading: _loadingLeaderboard,
              ),
            ] else if (_actusStage == _NewsRunStage.summary) ...[
              _FinalRunSummaryCard(
                breakdown: breakdown,
                profile: profile,
                loading: _savingCompletion,
                rewardLabel:
                    '+${newsSessionXpReward(breakdown.finalScore)} XP ajoutés à ta progression',
              ),
              const SizedBox(height: 16),
              _LeaderboardCard(
                rows: _weeklyLeaderboard,
                loading: _loadingLeaderboard,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savingCompletion ? null : _goToGameTab,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Retourner à l’onglet Game',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else if (currentItem != null) ...[
              _SessionTimeline(
                current: _actusRoundIndex + 1,
                total: deckResult.deck.length,
                stage: _actusStage,
                comboValue:
                    _actusRounds.isEmpty
                        ? 0
                        : _actusRounds.last.comboAfterRound,
              ),
              const SizedBox(height: 16),
              if (_actusStage == _NewsRunStage.forecast)
                _ImpactPredictionCard(
                  item: currentItem,
                  selectedTargets: _selectedTargetIds,
                  selectedDirections: _selectedDirections,
                  confidenceLevel: _selectedConfidence,
                  onToggleTarget: _toggleTarget,
                  onDirectionChanged: _setTargetDirection,
                  onConfidenceChanged:
                      (value) => setState(() => _selectedConfidence = value),
                  showSnippet: _actusSubMode == NewsGameSubMode.analyse,
                )
              else if (_actusStage == _NewsRunStage.questions)
                _RoundQuestionCard(
                  item: currentItem,
                  questionCount: _questionCountForCurrentMode,
                  selectedAnswers: _selectedQuestionAnswers,
                  onAnswerSelected: _setQuestionAnswer,
                )
              else if (_currentActusResult != null)
                _RoundDebriefCard(
                  title: 'Score révélé',
                  marketScore: _currentActusResult!.marketScore,
                  comprehensionScore: _currentActusResult!.comprehensionScore,
                  comboAfterRound: _currentActusResult!.comboAfterRound,
                  debrief: _currentActusResult!.debrief,
                  correctTargets:
                      currentItem.impactOptions
                          .where((option) => option.isExpectedTarget)
                          .toList(),
                ),
              const SizedBox(height: 16),
              _RoundActionBar(
                stage: _actusStage,
                isLast: _actusRoundIndex + 1 >= deckResult.deck.length,
                onOpenAnalysis: _openActusAnalysis,
                onValidateRound: _validateActusRound,
                onNextRound: _goToNextActusRound,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActusEmptyState(NewsGameDeckResult? deckResult) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoMessageCard(
          message:
              _message ??
              deckResult?.qualitySummary ??
              'Aucun deck n’a pu être construit.',
          icon: Icons.newspaper_rounded,
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
                        await _loadActusDeck();
                        await _loadWeeklyLeaderboard();
                      } finally {
                        if (mounted) setState(() => _retryingActus = false);
                      }
                    },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child:
                _retryingActus
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text('Réessayer'),
          ),
        ),
      ],
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
      motionValue: _motionCtl.value,
      onCompleted: _goToGameTab,
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _MondeView extends StatefulWidget {
  final String sessionId;
  final DailyNewsGameRepository repo;
  final double motionValue;
  final Future<void> Function() onCompleted;

  const _MondeView({
    required this.sessionId,
    required this.repo,
    required this.motionValue,
    required this.onCompleted,
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
            bottom: _selected != null ? 110 : 16,
          ),
          children: [
            _NewsGameHeroCard(
              title: 'Route macro monde',
              subtitle:
                  'Sélectionne un pays source, garde la carte en paysage, puis pars en lecture transfrontalière.',
              qualitySummary:
                  'La carte s’active en paysage. Le run détaillé revient ensuite en portrait.',
              categories: const <String>[
                'Géopolitique',
                'Commodities',
                'Taux',
                'FX',
              ],
              comboValue: 0,
              progressLabel: 'Carte paysage',
              motionValue: widget.motionValue,
              showTimer: false,
              timerLabel: null,
            ),
            const SizedBox(height: 16),
            WorldMapWidget(
              onCountryTap: (country) => setState(() => _selected = country),
              selectedIso2: _selected?.iso2,
              sessionId: widget.sessionId,
              onCountryPrefetch:
                  (country) => widget.repo.prefetchCountryArticle(
                    countryIso2: country.iso2,
                    countryNameEn: country.nameEn,
                  ),
            ),
          ],
        ),
        if (_selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WorldConfirmBar(
              country: _selected!,
              onOpen: () async {
                final country = _selected!;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => _WorldRoutePage(
                          sessionId: widget.sessionId,
                          repo: widget.repo,
                          country: country,
                          onCompleted: widget.onCompleted,
                        ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _WorldRoutePage extends StatefulWidget {
  final String sessionId;
  final DailyNewsGameRepository repo;
  final CountryInfo country;
  final Future<void> Function() onCompleted;

  const _WorldRoutePage({
    required this.sessionId,
    required this.repo,
    required this.country,
    required this.onCompleted,
  });

  @override
  State<_WorldRoutePage> createState() => _WorldRoutePageState();
}

class _WorldRoutePageState extends State<_WorldRoutePage> {
  NewsWorldRoute? _route;
  bool _loading = true;
  bool _saving = false;
  bool _completed = false;
  String? _message;

  int _stepIndex = 0;
  _NewsRunStage _stage = _NewsRunStage.forecast;
  final List<NewsRoundResult> _rounds = <NewsRoundResult>[];
  NewsRoundResult? _currentResult;
  final Set<String> _selectedTargetIds = <String>{};
  final Map<String, PredictionDirection> _selectedDirections =
      <String, PredictionDirection>{};
  NewsConfidenceLevel _confidence = NewsConfidenceLevel.prudente;
  List<int?> _selectedAnswers = const <int?>[];
  DateTime? _startedAt;

  bool get _canExitRoute => _stage == _NewsRunStage.summary && !_saving;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _loadRoute();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final route = await widget.repo.buildWorldRoute(
        countryIso2: widget.country.iso2,
        countryNameEn: widget.country.nameEn,
        countryNameFr: widget.country.nameFr,
      );
      if (!mounted) return;
      if (route == null) {
        setState(() {
          _loading = false;
          _message = 'Aucune route macro exploitable pour ce pays aujourd’hui.';
        });
        return;
      }
      await widget.repo.saveSessionArticles(
        mode: DailyNewsGameMode.monde,
        sessionId: widget.sessionId,
        articles: <NewsArticle>[route.sourceItem.article],
        countryIso2: widget.country.iso2,
        countryNameFr: widget.country.nameFr,
      );
      await widget.repo.saveSessionDeck(
        mode: DailyNewsGameMode.monde,
        sessionId: widget.sessionId,
        subMode: NewsGameSubMode.worldRoute,
        deck: <NewsGameDeckItem>[route.sourceItem],
        routeNodes: route.routeNodes,
        sourceCountryIso2: widget.country.iso2,
        sourceCountryNameFr: widget.country.nameFr,
      );
      setState(() {
        _route = route;
        _loading = false;
        _startedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Chargement de la route impossible: $error';
      });
    }
  }

  bool get _isSourceStep => _stepIndex == 0;

  int get _stepCount => _route == null ? 0 : 1 + _route!.routeNodes.length;

  NewsGameDeckItem? get _sourceItem => _route?.sourceItem;

  NewsWorldRouteNode? get _currentNode {
    final route = _route;
    if (route == null || _isSourceStep) return null;
    final index = _stepIndex - 1;
    if (index < 0 || index >= route.routeNodes.length) return null;
    return route.routeNodes[index];
  }

  void _resetSelection() {
    _selectedTargetIds.clear();
    _selectedDirections.clear();
    _confidence = NewsConfidenceLevel.prudente;
    _selectedAnswers = const <int?>[];
  }

  void _toggleTarget(String targetId) {
    setState(() {
      if (_selectedTargetIds.contains(targetId)) {
        _selectedTargetIds.remove(targetId);
        _selectedDirections.remove(targetId);
      } else {
        if (_selectedTargetIds.length >= 3) return;
        _selectedTargetIds.add(targetId);
        _selectedDirections[targetId] = PredictionDirection.neutral;
      }
    });
  }

  void _setDirection(String targetId, PredictionDirection direction) {
    setState(() => _selectedDirections[targetId] = direction);
  }

  void _setAnswer(int index, int answer) {
    final next = List<int?>.from(_selectedAnswers);
    if (index >= next.length) return;
    next[index] = answer;
    setState(() => _selectedAnswers = next);
  }

  void _openWorldQuestions() {
    if (_selectedTargetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis au moins une cible.')),
      );
      return;
    }
    if (!_isSourceStep) {
      _validateWorldStep();
      return;
    }
    setState(() {
      _stage = _NewsRunStage.questions;
      _selectedAnswers = List<int?>.filled(1, null);
    });
  }

  void _validateWorldStep() {
    final predictions =
        _selectedTargetIds
            .map(
              (id) => NewsImpactPrediction(
                targetId: id,
                direction:
                    _selectedDirections[id] ?? PredictionDirection.neutral,
                confidenceLevel: _confidence,
              ),
            )
            .toList();
    if (_isSourceStep) {
      final source = _sourceItem;
      if (source == null) return;
      if (_selectedAnswers.any((value) => value == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponds à la question source.')),
        );
        return;
      }
      final result = NewsGameEngine.resolveDeckRound(
        item: source,
        predictions: predictions,
        comprehensionAnswers: _selectedAnswers,
        currentCombo: _rounds.isEmpty ? 0 : _rounds.last.comboAfterRound,
        questionCount: 1,
      );
      setState(() {
        _currentResult = result;
        _rounds.add(result);
        _stage = _NewsRunStage.reveal;
      });
      return;
    }

    final node = _currentNode;
    final route = _route;
    if (node == null || route == null) return;
    final result = NewsGameEngine.resolveRouteNode(
      node: node,
      category: route.sourceItem.macroCategory,
      predictions: predictions,
      currentCombo: _rounds.isEmpty ? 0 : _rounds.last.comboAfterRound,
    );
    setState(() {
      _currentResult = result;
      _rounds.add(result);
      _stage = _NewsRunStage.reveal;
    });
  }

  Future<void> _nextWorldStep() async {
    if (_stepIndex + 1 >= _stepCount) {
      await _finishWorldRun();
      return;
    }
    _resetSelection();
    setState(() {
      _stepIndex += 1;
      _stage = _NewsRunStage.forecast;
      _currentResult = null;
    });
  }

  Future<void> _finishWorldRun() async {
    final route = _route;
    if (route == null || _completed || _saving) {
      setState(() => _stage = _NewsRunStage.summary);
      return;
    }
    setState(() {
      _saving = true;
      _stage = _NewsRunStage.summary;
    });
    final breakdown = NewsGameEngine.buildSessionBreakdown(_rounds);
    try {
      await widget.repo.completeGameRun(
        mode: DailyNewsGameMode.monde,
        sessionId: widget.sessionId,
        subMode: NewsGameSubMode.worldRoute,
        deck: <NewsGameDeckItem>[route.sourceItem],
        routeNodes: route.routeNodes,
        rounds: _rounds,
        breakdown: breakdown,
        sourceCountryIso2: route.sourceCountryIso2,
        sourceCountryNameFr: route.sourceCountryNameFr,
        elapsed:
            _startedAt == null
                ? Duration.zero
                : DateTime.now().difference(_startedAt!),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _completed = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Enregistrement impossible: $error';
      });
    }
  }

  void _showRouteLockedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Termine la route pour récupérer la récompense avant de quitter.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final breakdown = NewsGameEngine.buildSessionBreakdown(_rounds);
    return PopScope(
      canPop: _canExitRoute,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showRouteLockedMessage();
        }
      },
      child: Scaffold(
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
            onPressed: () {
              if (_canExitRoute) {
                Navigator.of(context).pop();
              } else {
                _showRouteLockedMessage();
              }
            },
          ),
          title: Text(
            '${widget.country.flag} ${widget.country.nameFr}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: textColor,
            ),
          ),
        ),
        body:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: detailsColor1,
                    strokeWidth: 2.5,
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _NewsGameHeroCard(
                      title: 'Route macro ${widget.country.nameFr}',
                      subtitle:
                          'Étape source, propagation régionale, puis deuxième onde globale.',
                      qualitySummary:
                          route == null
                              ? 'Aucune route chargée'
                              : '3 nœuds de décision · ${route.sourceItem.macroCategory.label}',
                      categories:
                          route == null
                              ? const <String>[]
                              : <String>[
                                route.sourceItem.macroCategory.label,
                                'Propagation',
                                'Cross-border',
                              ],
                      comboValue: breakdown.maxCombo,
                      progressLabel:
                          '${math.min(_stepIndex + 1, _stepCount)} / $_stepCount',
                      motionValue: 0.2,
                      showTimer: false,
                      timerLabel: null,
                    ),
                    const SizedBox(height: 16),
                    if (_message != null) ...[
                      _InfoMessageCard(message: _message!),
                      const SizedBox(height: 16),
                    ],
                    if (route == null)
                      _InfoMessageCard(
                        message:
                            'Aucune route macro exploitable pour ${widget.country.nameFr}.',
                      )
                    else if (_stage == _NewsRunStage.summary) ...[
                      _FinalRunSummaryCard(
                        breakdown: breakdown,
                        profile: NewsSessionProfile.empty,
                        loading: _saving,
                        rewardLabel:
                            '+${newsSessionXpReward(breakdown.finalScore)} XP pour cette route monde',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : widget.onCompleted,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Récupérer la récompense et revenir',
                          ),
                        ),
                      ),
                    ] else ...[
                      _SessionTimeline(
                        current: _stepIndex + 1,
                        total: _stepCount,
                        stage: _stage,
                        comboValue:
                            _rounds.isEmpty ? 0 : _rounds.last.comboAfterRound,
                      ),
                      const SizedBox(height: 16),
                      if (_stage == _NewsRunStage.forecast)
                        _isSourceStep
                            ? _ImpactPredictionCard(
                              item: route.sourceItem,
                              selectedTargets: _selectedTargetIds,
                              selectedDirections: _selectedDirections,
                              confidenceLevel: _confidence,
                              onToggleTarget: _toggleTarget,
                              onDirectionChanged: _setDirection,
                              onConfidenceChanged:
                                  (value) =>
                                      setState(() => _confidence = value),
                              showSnippet: true,
                            )
                            : _RouteNodeCard(
                              node: _currentNode!,
                              selectedTargets: _selectedTargetIds,
                              selectedDirections: _selectedDirections,
                              confidenceLevel: _confidence,
                              onToggleTarget: _toggleTarget,
                              onDirectionChanged: _setDirection,
                              onConfidenceChanged:
                                  (value) =>
                                      setState(() => _confidence = value),
                            )
                      else if (_stage == _NewsRunStage.questions)
                        _RoundQuestionCard(
                          item: route.sourceItem,
                          questionCount: 1,
                          selectedAnswers: _selectedAnswers,
                          onAnswerSelected: _setAnswer,
                        )
                      else if (_currentResult != null)
                        _RoundDebriefCard(
                          title: 'Nœud validé',
                          marketScore: _currentResult!.marketScore,
                          comprehensionScore:
                              _currentResult!.comprehensionScore,
                          comboAfterRound: _currentResult!.comboAfterRound,
                          debrief: _currentResult!.debrief,
                          correctTargets:
                              _isSourceStep
                                  ? route.sourceItem.impactOptions
                                      .where(
                                        (option) => option.isExpectedTarget,
                                      )
                                      .toList()
                                  : _currentNode!.impactOptions
                                      .where(
                                        (option) => option.isExpectedTarget,
                                      )
                                      .toList(),
                        ),
                      const SizedBox(height: 16),
                      _RoundActionBar(
                        stage: _stage,
                        isLast: _stepIndex + 1 >= _stepCount,
                        onOpenAnalysis: _openWorldQuestions,
                        onValidateRound: _validateWorldStep,
                        onNextRound: _nextWorldStep,
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}

class _NewsGameHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String qualitySummary;
  final List<String> categories;
  final int comboValue;
  final String progressLabel;
  final double motionValue;
  final bool showTimer;
  final String? timerLabel;

  const _NewsGameHeroCard({
    required this.title,
    required this.subtitle,
    required this.qualitySummary,
    required this.categories,
    required this.comboValue,
    required this.progressLabel,
    required this.motionValue,
    required this.showTimer,
    required this.timerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final dx = math.sin(motionValue * math.pi * 2) * 9;
    final dy = math.cos(motionValue * math.pi * 2) * 7;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            detailsColor1.withValues(alpha: 0.12),
            detailsColor2.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: detailsColor1.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(20),
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontFamily: 'Geo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      qualitySummary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(dx, dy),
                child: SvgPicture.string(_newsHeroSvg, width: 84),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                categories
                    .take(5)
                    .map((label) => _ChipBadge(label: label))
                    .toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                icon: Icons.local_fire_department_rounded,
                label: 'Combo',
                value: comboValue.toString(),
              ),
              _MetricPill(
                icon: Icons.timeline_rounded,
                label: 'Progression',
                value: progressLabel,
              ),
              if (showTimer)
                _MetricPill(
                  icon: Icons.timer_outlined,
                  label: 'Sprint',
                  value: timerLabel ?? '--:--',
                  accent: Colors.redAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? detailsColor2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label · $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;

  const _ChipBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _QuestRibbon extends StatelessWidget {
  final int comboProgress;
  final int countryProgress;
  final int ratesProgress;

  const _QuestRibbon({
    required this.comboProgress,
    required this.countryProgress,
    required this.ratesProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuestTile(
            title: '3 lectures de suite',
            progressLabel: '$comboProgress/3',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuestTile(
            title: '5 pays couverts',
            progressLabel: '$countryProgress/5',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuestTile(
            title: 'Sans erreur sur les taux',
            progressLabel: '$ratesProgress/3',
          ),
        ),
      ],
    );
  }
}

class _QuestTile extends StatelessWidget {
  final String title;
  final String progressLabel;

  const _QuestTile({required this.title, required this.progressLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_rounded, color: detailsColor1, size: 18),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progressLabel,
            style: const TextStyle(
              fontSize: 12,
              color: detailsColor2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  final bool sprintAvailable;
  final NewsGameSubMode? selectedMode;
  final ValueChanged<NewsGameSubMode> onSelected;

  const _ModeChoiceCard({
    required this.sprintAvailable,
    required this.selectedMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choisis ton run',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sprint pour une lecture réflexe en 90 secondes, Analyse pour détailler causalité et compréhension.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  title: 'Mode Sprint',
                  subtitle:
                      sprintAvailable
                          ? '5 headlines max · 90 sec'
                          : 'Verrouillé: deck réduit',
                  enabled: sprintAvailable,
                  selected: selectedMode == NewsGameSubMode.sprint,
                  onTap:
                      sprintAvailable
                          ? () => onSelected(NewsGameSubMode.sprint)
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeButton(
                  title: 'Mode Analyse',
                  subtitle: 'Deck complet · 2 questions par carte',
                  enabled: true,
                  selected: selectedMode == NewsGameSubMode.analyse,
                  onTap: () => onSelected(NewsGameSubMode.analyse),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        selected
            ? _accentGradient
            : LinearGradient(
              colors: [
                Colors.white,
                enabled ? Colors.white : Colors.grey.shade100,
              ],
            );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: enabled ? 0.08 : 0.04),
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: detailsColor1.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white70 : Colors.black54,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckPreviewCard extends StatelessWidget {
  final List<NewsGameDeckItem> deck;

  const _DeckPreviewCard({required this.deck});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deck du jour',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...deck.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: _accentGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.macroCategory.label.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.region} · ${item.macroCategory.label} · ${item.difficulty.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInsightsCard extends StatelessWidget {
  final NewsSessionProfile profile;

  const _ProfileInsightsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final bestTheme = _topEntry(profile.themeAccuracy);
    final bestCountry = _topEntry(profile.countryAccuracy);
    final bestAsset = _topEntry(profile.assetAccuracy);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique perso',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          _InsightRow(
            label: 'Meilleur thème',
            value: bestTheme?.$1 ?? 'Aucun run',
            trailing:
                bestTheme == null
                    ? '--'
                    : '${bestTheme.$2.toStringAsFixed(0)}%',
          ),
          _InsightRow(
            label: 'Zone la plus juste',
            value: bestCountry?.$1 ?? 'Aucune',
            trailing:
                bestCountry == null
                    ? '--'
                    : '${bestCountry.$2.toStringAsFixed(0)}%',
          ),
          _InsightRow(
            label: 'Actif le mieux lu',
            value: bestAsset?.$1 ?? 'Aucun',
            trailing:
                bestAsset == null
                    ? '--'
                    : '${bestAsset.$2.toStringAsFixed(0)}%',
          ),
          _InsightRow(
            label: 'Combo record',
            value: 'Chaîne max',
            trailing: profile.bestCombo.toString(),
          ),
        ],
      ),
    );
  }

  (String, double)? _topEntry(Map<String, double> values) {
    if (values.isEmpty) return null;
    final sorted =
        values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return (sorted.first.key, sorted.first.value);
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final String trailing;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: detailsColor2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool loading;

  const _LeaderboardCard({required this.rows, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ligue hebdo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Classement par précision moyenne, pas par volume de sessions.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  color: detailsColor1,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (rows.isEmpty)
            const Text(
              'Aucune donnée hebdo pour le moment.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            ...rows.take(5).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final name = (row['displayName'] as String?) ?? 'Joueur';
              final accuracy =
                  (row['averageAccuracy'] as num?)?.toDouble() ?? 0;
              final sessions = (row['sessionCount'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: detailsColor1.withValues(alpha: 0.18),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: detailsColor2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${accuracy.toStringAsFixed(0)}% · $sessions run(s)',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SessionTimeline extends StatelessWidget {
  final int current;
  final int total;
  final _NewsRunStage stage;
  final int comboValue;

  const _SessionTimeline({
    required this.current,
    required this.total,
    required this.stage,
    required this.comboValue,
  });

  @override
  Widget build(BuildContext context) {
    final stageLabel = switch (stage) {
      _NewsRunStage.forecast => 'Prédiction',
      _NewsRunStage.questions => 'Compréhension',
      _NewsRunStage.reveal => 'Débrief',
      _NewsRunStage.summary => 'Résumé',
    };
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carte $current / $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$stageLabel · combo $comboValue',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : current / total,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(detailsColor1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactPredictionCard extends StatelessWidget {
  final NewsGameDeckItem item;
  final Set<String> selectedTargets;
  final Map<String, PredictionDirection> selectedDirections;
  final NewsConfidenceLevel confidenceLevel;
  final ValueChanged<String> onToggleTarget;
  final void Function(String targetId, PredictionDirection direction)
  onDirectionChanged;
  final ValueChanged<NewsConfidenceLevel> onConfidenceChanged;
  final bool showSnippet;

  const _ImpactPredictionCard({
    required this.item,
    required this.selectedTargets,
    required this.selectedDirections,
    required this.confidenceLevel,
    required this.onToggleTarget,
    required this.onDirectionChanged,
    required this.onConfidenceChanged,
    required this.showSnippet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ArticleMetaHeader(item: item),
          const SizedBox(height: 16),
          Text(
            item.displayTitle,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.35,
            ),
          ),
          if (showSnippet && item.displaySnippet.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.displaySnippet,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Lis le titre, prends position, puis ouvre l’analyse pour vérifier ton intuition.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Sur quoi le marché réagit-il vraiment ? Choisis 1 à 3 cibles.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...item.impactOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ImpactTargetTile(
                option: option,
                selected: selectedTargets.contains(option.id),
                direction: selectedDirections[option.id],
                onToggle: () => onToggleTarget(option.id),
                onDirectionChanged:
                    (direction) => onDirectionChanged(option.id, direction),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const _DirectionHelpHint(),
          const SizedBox(height: 10),
          _ConfidenceSelector(
            value: confidenceLevel,
            onChanged: onConfidenceChanged,
          ),
          if (item.article.url.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ArticleLink(url: item.article.url),
          ],
        ],
      ),
    );
  }
}

class _RouteNodeCard extends StatelessWidget {
  final NewsWorldRouteNode node;
  final Set<String> selectedTargets;
  final Map<String, PredictionDirection> selectedDirections;
  final NewsConfidenceLevel confidenceLevel;
  final ValueChanged<String> onToggleTarget;
  final void Function(String targetId, PredictionDirection direction)
  onDirectionChanged;
  final ValueChanged<NewsConfidenceLevel> onConfidenceChanged;

  const _RouteNodeCard({
    required this.node,
    required this.selectedTargets,
    required this.selectedDirections,
    required this.confidenceLevel,
    required this.onToggleTarget,
    required this.onDirectionChanged,
    required this.onConfidenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            node.prompt,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                node.causalChain
                    .map((label) => _ChipBadge(label: label))
                    .toList(),
          ),
          const SizedBox(height: 16),
          ...node.impactOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ImpactTargetTile(
                option: option,
                selected: selectedTargets.contains(option.id),
                direction: selectedDirections[option.id],
                onToggle: () => onToggleTarget(option.id),
                onDirectionChanged:
                    (direction) => onDirectionChanged(option.id, direction),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _DirectionHelpHint(),
          const SizedBox(height: 10),
          _ConfidenceSelector(
            value: confidenceLevel,
            onChanged: onConfidenceChanged,
          ),
        ],
      ),
    );
  }
}

class _ArticleMetaHeader extends StatelessWidget {
  final NewsGameDeckItem item;

  const _ArticleMetaHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MiniTag(
          label:
              item.article.source.isEmpty
                  ? 'Source inconnue'
                  : item.article.source,
        ),
        _MiniTag(label: item.region),
        _MiniTag(label: item.macroCategory.label),
        _MiniTag(label: item.difficulty.label),
        _MiniTag(label: '+${item.rewardPotential} pts'),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;

  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImpactTargetTile extends StatelessWidget {
  final NewsImpactOption option;
  final bool selected;
  final PredictionDirection? direction;
  final VoidCallback onToggle;
  final ValueChanged<PredictionDirection> onDirectionChanged;

  const _ImpactTargetTile({
    required this.option,
    required this.selected,
    required this.direction,
    required this.onToggle,
    required this.onDirectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? detailsColor1.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              selected
                  ? detailsColor1.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.kind.key,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? detailsColor2 : Colors.black26,
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 12),
            Row(
              children:
                  PredictionDirection.values.map((value) {
                    final isActive = direction == value;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => onDirectionChanged(value),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: isActive ? _accentGradient : null,
                              color:
                                  isActive
                                      ? null
                                      : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              value.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive ? Colors.white : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfidenceSelector extends StatelessWidget {
  final NewsConfidenceLevel value;
  final ValueChanged<NewsConfidenceLevel> onChanged;

  const _ConfidenceSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Niveau de confiance',
          style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 340;
            final items =
                NewsConfidenceLevel.values.map((level) {
                  final active = level == value;
                  final card = InkWell(
                    onTap: () => onChanged(level),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: compact ? null : (constraints.maxWidth - 16) / 3,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: active ? _accentGradient : null,
                        color:
                            active
                                ? null
                                : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            level.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'x${level.gainMultiplier.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: active ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  return compact
                      ? SizedBox(width: constraints.maxWidth, child: card)
                      : card;
                }).toList();
            return compact
                ? Column(
                  children:
                      items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: item,
                            ),
                          )
                          .toList(),
                )
                : Wrap(spacing: 8, runSpacing: 8, children: items);
          },
        ),
      ],
    );
  }
}

class _DirectionHelpHint extends StatelessWidget {
  const _DirectionHelpHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Bullish : impact plutot favorable • Bearish : impact plutot defavorable • Neutre : effet limite ou mitige',
        style: TextStyle(
          fontSize: 11.5,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _RoundQuestionCard extends StatelessWidget {
  final NewsGameDeckItem item;
  final int questionCount;
  final List<int?> selectedAnswers;
  final void Function(int index, int choiceIndex) onAnswerSelected;

  const _RoundQuestionCard({
    required this.item,
    required this.questionCount,
    required this.selectedAnswers,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final questions = item.comprehensionQuestions.take(questionCount).toList();
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ArticleMetaHeader(item: item),
          const SizedBox(height: 16),
          Text(
            item.displayTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.35,
            ),
          ),
          if (item.displaySnippet.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.displaySnippet,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _QuestionBlock(
                question: question,
                selectedAnswer:
                    index < selectedAnswers.length
                        ? selectedAnswers[index]
                        : null,
                onAnswerSelected: (choice) => onAnswerSelected(index, choice),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final NewsComprehensionQuestion question;
  final int? selectedAnswer;
  final ValueChanged<int> onAnswerSelected;

  const _QuestionBlock({
    required this.question,
    required this.selectedAnswer,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.prompt,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        ...question.choices.asMap().entries.map((entry) {
          final choiceIndex = entry.key;
          final choice = entry.value;
          final selected = selectedAnswer == choiceIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onAnswerSelected(choiceIndex),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: selected ? _accentGradient : null,
                  color: selected ? null : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        choice,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.white : textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? Colors.white : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RoundDebriefCard extends StatelessWidget {
  final String title;
  final int marketScore;
  final int comprehensionScore;
  final int comboAfterRound;
  final String debrief;
  final List<NewsImpactOption> correctTargets;

  const _RoundDebriefCard({
    required this.title,
    required this.marketScore,
    required this.comprehensionScore,
    required this.comboAfterRound,
    required this.debrief,
    required this.correctTargets,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        decoration: _cardDecoration(
          borderColor: detailsColor1.withValues(alpha: 0.22),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ScoreBox(
                    label: 'Marché',
                    score: marketScore,
                    accent: detailsColor2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScoreBox(
                    label: 'Compréhension',
                    score: comprehensionScore,
                    accent: detailsColor1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScoreBox(
                    label: 'Combo',
                    score: comboAfterRound * 10,
                    accent: const Color(0xFF1FC182),
                    displayValue: comboAfterRound.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              debrief,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  correctTargets
                      .map(
                        (option) => _ChipBadge(
                          label:
                              '${option.label} ${option.expectedDirection.label.toLowerCase()}',
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int score;
  final Color accent;
  final String? displayValue;

  const _ScoreBox({
    required this.label,
    required this.score,
    required this.accent,
    this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayValue ?? '$score',
            style: TextStyle(
              fontSize: 20,
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionBar extends StatelessWidget {
  final _NewsRunStage stage;
  final bool isLast;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onValidateRound;
  final Future<void> Function() onNextRound;

  const _RoundActionBar({
    required this.stage,
    required this.isLast,
    required this.onOpenAnalysis,
    required this.onValidateRound,
    required this.onNextRound,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      _NewsRunStage.forecast => 'Ouvrir l’analyse',
      _NewsRunStage.questions => 'Valider ce round',
      _NewsRunStage.reveal =>
        isLast ? 'Voir le résumé final' : 'Carte suivante',
      _NewsRunStage.summary => 'Terminé',
    };
    final action = switch (stage) {
      _NewsRunStage.forecast => () => onOpenAnalysis(),
      _NewsRunStage.questions => () => onValidateRound(),
      _NewsRunStage.reveal => () => onNextRound(),
      _NewsRunStage.summary => null,
    };

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: action == null ? null : () => action(),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _FinalRunSummaryCard extends StatelessWidget {
  final NewsSessionScoreBreakdown breakdown;
  final NewsSessionProfile profile;
  final bool loading;
  final String rewardLabel;

  const _FinalRunSummaryCard({
    required this.breakdown,
    required this.profile,
    required this.loading,
    required this.rewardLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé final',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ScoreBox(
                  label: 'Final',
                  score: breakdown.finalScore,
                  accent: detailsColor2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreBox(
                  label: 'Marché',
                  score: breakdown.marketScore,
                  accent: detailsColor1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreBox(
                  label: 'Combo',
                  score: breakdown.comboBonus,
                  accent: const Color(0xFF1FC182),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: _FinalRadarCard(
              finalScore: breakdown.finalScore.toDouble(),
              marketScore: breakdown.marketScore.toDouble(),
              comprehensionScore: breakdown.comprehensionScore.toDouble(),
              comboValue: (breakdown.comboBonus * 10).toDouble(),
              consistency: (profile.weeklyAverageAccuracy).clamp(0, 100),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rewardLabel,
            style: const TextStyle(
              fontSize: 13,
              color: detailsColor2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loading
                ? 'Enregistrement de la session, de la ligue et des quêtes…'
                : 'Ta progression perso et la ligue hebdo ont été mises à jour.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FinalRadarCard extends StatelessWidget {
  final double finalScore;
  final double marketScore;
  final double comprehensionScore;
  final double comboValue;
  final double consistency;

  const _FinalRadarCard({
    required this.finalScore,
    required this.marketScore,
    required this.comprehensionScore,
    required this.comboValue,
    required this.consistency,
  });

  @override
  Widget build(BuildContext context) {
    const axisLabels = <String>[
      'Final',
      'Marché',
      'Compréhension',
      'Combo',
      'Régularité',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Radar de performance',
          style: TextStyle(fontWeight: FontWeight.w800, color: detailsColor2),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: CustomPaint(
              painter: _RadarPainter(
                values: <double>[
                  finalScore,
                  marketScore,
                  comprehensionScore,
                  comboValue,
                  consistency,
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              axisLabels.map((label) => _RadarAxisChip(label: label)).toList(),
        ),
      ],
    );
  }
}

class _RadarAxisChip extends StatelessWidget {
  final String label;

  const _RadarAxisChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values;

  const _RadarPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;
    final gridPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.08);
    final fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = detailsColor1.withValues(alpha: 0.18);
    final strokePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = detailsColor2;

    for (var ring = 1; ring <= 4; ring++) {
      final scaled = radius * (ring / 4);
      final path = Path();
      for (var index = 0; index < 5; index++) {
        final angle = (-math.pi / 2) + ((math.pi * 2) / 5) * index;
        final point = Offset(
          center.dx + math.cos(angle) * scaled,
          center.dy + math.sin(angle) * scaled,
        );
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var index = 0; index < 5; index++) {
      final angle = (-math.pi / 2) + ((math.pi * 2) / 5) * index;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(center, point, gridPaint);
    }

    final polygon = Path();
    for (var index = 0; index < values.length; index++) {
      final ratio = (values[index].clamp(0, 100)) / 100;
      final angle = (-math.pi / 2) + ((math.pi * 2) / values.length) * index;
      final point = Offset(
        center.dx + math.cos(angle) * radius * ratio,
        center.dy + math.sin(angle) * radius * ratio,
      );
      if (index == 0) {
        polygon.moveTo(point.dx, point.dy);
      } else {
        polygon.lineTo(point.dx, point.dy);
      }
    }
    polygon.close();
    canvas.drawPath(polygon, fillPaint);
    canvas.drawPath(polygon, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _WorldConfirmBar extends StatelessWidget {
  final CountryInfo country;
  final VoidCallback onOpen;

  const _WorldConfirmBar({required this.country, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child:
              compact
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  country.nameFr,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Source du choc macro',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onOpen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: detailsColor2,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.alt_route_rounded, size: 18),
                          label: const Text(
                            'Démarrer la route',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      Text(country.flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              country.nameFr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Source du choc macro',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: onOpen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: detailsColor2,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.alt_route_rounded, size: 18),
                          label: const Text(
                            'Démarrer la route',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
        );
      },
    );
  }
}

class _InfoMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;

  const _InfoMessageCard({
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: detailsColor1),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleLink extends StatelessWidget {
  final String url;

  const _ArticleLink({required this.url});

  Future<void> _launch() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _launch,
      borderRadius: BorderRadius.circular(10),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_new_rounded, size: 16, color: detailsColor1),
          SizedBox(width: 6),
          Text(
            'Lire l’article complet',
            style: TextStyle(
              fontSize: 13,
              color: detailsColor1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
