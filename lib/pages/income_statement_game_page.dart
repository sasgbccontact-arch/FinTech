import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/services/activity_tracking_service.dart';

import '../models/fundamental_game_models.dart';
import '../services/fundamental_game_engine.dart';
import '../services/yahoo_finance_service.dart';

const Duration _stockAnalystRevealDuration = Duration(milliseconds: 820);
const String _stockAnalystOracleAchievementKey = 'stock_analyst_oracle';
const int _stockAnalystOracleAchievementTarget = 20;
const String _stockAnalystDrawSvg = '''
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="goldDraw" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
    <linearGradient id="violetDraw" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2A0F45"/>
      <stop offset="100%" stop-color="#5D317F"/>
    </linearGradient>
  </defs>
  <rect x="26" y="44" width="126" height="104" rx="24" fill="#FFFFFF" stroke="#E6D9A8" stroke-width="4"/>
  <rect x="42" y="60" width="74" height="14" rx="7" fill="url(#goldDraw)" opacity="0.92"/>
  <rect x="42" y="84" width="92" height="10" rx="5" fill="#EFE7D3"/>
  <rect x="42" y="101" width="66" height="10" rx="5" fill="#EFE7D3"/>
  <path d="M50 132 C74 108, 96 118, 114 96 S146 72, 160 62" fill="none" stroke="url(#violetDraw)" stroke-width="8" stroke-linecap="round"/>
  <circle cx="160" cy="62" r="8" fill="url(#goldDraw)"/>
  <circle cx="178" cy="154" r="26" fill="none" stroke="url(#goldDraw)" stroke-width="8"/>
  <path d="M195 172 L208 186" stroke="url(#violetDraw)" stroke-width="10" stroke-linecap="round"/>
  <path d="M160 172 C148 184, 128 188, 112 182" fill="none" stroke="url(#violetDraw)" stroke-width="7" stroke-linecap="round"/>
  <path d="M104 176 L106 190 L118 184" fill="none" stroke="url(#goldDraw)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

class _StockAnalystCandidateSeed {
  const _StockAnalystCandidateSeed({
    required this.symbol,
    required this.displayName,
    required this.exchange,
    required this.region,
    required this.currency,
  });

  final String symbol;
  final String displayName;
  final String exchange;
  final String region;
  final String currency;

  TickerSearchResult toTicker() {
    return TickerSearchResult(
      symbol: symbol,
      displayName: displayName,
      exchange: exchange,
      quoteType: 'EQUITY',
      region: region,
      currency: currency,
    );
  }
}

const List<_StockAnalystCandidateSeed> _stockAnalystCandidateUniverse =
    <_StockAnalystCandidateSeed>[
      _StockAnalystCandidateSeed(
        symbol: 'AAPL',
        displayName: 'Apple',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'MSFT',
        displayName: 'Microsoft',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'NVDA',
        displayName: 'NVIDIA',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'GOOGL',
        displayName: 'Alphabet',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'AMZN',
        displayName: 'Amazon',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'META',
        displayName: 'Meta',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'BRK-B',
        displayName: 'Berkshire Hathaway',
        exchange: 'NYSE',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'JPM',
        displayName: 'JPMorgan',
        exchange: 'NYSE',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'V',
        displayName: 'Visa',
        exchange: 'NYSE',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'MA',
        displayName: 'Mastercard',
        exchange: 'NYSE',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'UNH',
        displayName: 'UnitedHealth',
        exchange: 'NYSE',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'XOM',
        displayName: 'ExxonMobil',
        exchange: 'NYSE',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'COST',
        displayName: 'Costco',
        exchange: 'NASDAQ',
        region: 'US',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'ASML',
        displayName: 'ASML',
        exchange: 'NASDAQ',
        region: 'EU',
        currency: 'USD',
      ),
      _StockAnalystCandidateSeed(
        symbol: 'LVMUY',
        displayName: 'LVMH',
        exchange: 'OTC',
        region: 'EU',
        currency: 'USD',
      ),
    ];

@visibleForTesting
class StockAnalystCandidateProbe {
  const StockAnalystCandidateProbe({
    required this.symbol,
    required this.playable,
    required this.missingDataCount,
    required this.activeCategoryCount,
    required this.metricCount,
  });

  final String symbol;
  final bool playable;
  final int missingDataCount;
  final int activeCategoryCount;
  final int metricCount;
}

@visibleForTesting
String? stockAnalystPickCandidateSymbol(
  List<StockAnalystCandidateProbe> probes, {
  required int seed,
}) {
  final playable = probes.where((probe) => probe.playable).toList();
  if (playable.isEmpty) return null;
  int scoreFor(StockAnalystCandidateProbe probe) =>
      (probe.activeCategoryCount * 20) +
      probe.metricCount -
      (probe.missingDataCount * 4);

  playable.sort((a, b) {
    final scoreCompare = scoreFor(b).compareTo(scoreFor(a));
    if (scoreCompare != 0) return scoreCompare;
    return a.symbol.compareTo(b.symbol);
  });
  final topScore = scoreFor(playable.first);
  final pool =
      playable.where((probe) => scoreFor(probe) >= topScore - 4).toList();
  final random = math.Random(seed);
  return pool[random.nextInt(pool.length)].symbol;
}

@visibleForTesting
String stockAnalystDayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? _stockAnalystDateFromDayKey(String dayKey) {
  if (!RegExp(r'^\d{8}$').hasMatch(dayKey)) return null;
  final year = int.tryParse(dayKey.substring(0, 4));
  final month = int.tryParse(dayKey.substring(4, 6));
  final day = int.tryParse(dayKey.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

@visibleForTesting
String stockAnalystLocalCooldownLabel(String dayKey, {DateTime? fallbackDate}) {
  final value =
      _stockAnalystDateFromDayKey(dayKey) ?? fallbackDate ?? DateTime.now();
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = (value.year % 100).toString().padLeft(2, '0');
  return '$day/$month/$year';
}

@visibleForTesting
({
  String rewardBand,
  int rewardCoins,
  int rewardGems,
  int penaltyCoins,
  String? badgeKey,
  bool unlocksAchievement,
  int oracleHitCountAfterGuess,
})
stockAnalystRewardPreview({
  required int diff,
  required int currentCoins,
  int oracleHitCount = 0,
  bool achievementAlreadyUnlocked = false,
}) {
  final outcome = _StockAnalystRewardOutcome.fromDiff(
    diff: diff,
    currentCoins: currentCoins,
    oracleHitCount: oracleHitCount,
    achievementAlreadyUnlocked: achievementAlreadyUnlocked,
  );
  return (
    rewardBand: outcome.rewardBand,
    rewardCoins: outcome.rewardCoins,
    rewardGems: outcome.rewardGems,
    penaltyCoins: outcome.penaltyCoins,
    badgeKey: outcome.badgeKey,
    unlocksAchievement: outcome.unlocksAchievement,
    oracleHitCountAfterGuess: outcome.oracleHitCountAfterGuess,
  );
}

@visibleForTesting
Map<String, Object?> stockAnalystGuessDebugMap(Map<String, dynamic> raw) {
  final record = _StockAnalystGuessRecord.fromMap(raw);
  return <String, Object?>{
    'symbol': record.symbol,
    'companyName': record.companyName,
    'guess': record.guess,
    'actual': record.actual,
    'diff': record.diff,
    'rewardBand': record.rewardBand,
    'rewardCoins': record.rewardCoins,
    'rewardGems': record.rewardGems,
    'penaltyCoins': record.penaltyCoins,
    'badgeKey': record.badgeKey,
    'qualitySummary': record.qualitySummary,
    'verdict': record.verdict,
    'dayKey': record.dayKey,
    'oracleHitCount': record.oracleHitCount,
    'achievementUnlocked': record.achievementUnlocked,
  };
}

class IncomeStatementGamePage extends StatefulWidget {
  const IncomeStatementGamePage({super.key});

  @override
  State<IncomeStatementGamePage> createState() =>
      _IncomeStatementGamePageState();
}

class _IncomeStatementGamePageState extends State<IncomeStatementGamePage>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();

  late final AnimationController _motionController;
  late final AnimationController _revealController;

  TickerSearchResult? _selectedTicker;
  FundamentalGameConfig? _config;
  FundamentalGameData? _gameData;
  FundamentalAnalysisResult? _analysis;
  _StockAnalystGuessRecord? _guessRecord;

  double _guessValue = 50;
  bool _loadingConfig = true;
  bool _loadingAnalysis = false;
  bool _loadingGuessRecord = false;
  bool _submittingGuess = false;
  bool _drawingTicker = false;
  bool _closingReward = false;
  String? _message;

  bool get _hasRevealedGuess => _guessRecord != null;

  bool get _hasPlayableRound {
    final analysis = _analysis;
    return analysis != null &&
        analysis.finalScore != null &&
        !analysis.isInsufficientData;
  }

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _revealController = AnimationController(
      vsync: this,
      duration: _stockAnalystRevealDuration,
    );
    _loadConfig();
  }

  @override
  void dispose() {
    _motionController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await FundamentalGameEngine.loadConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _message = 'Configuration du jeu indisponible.';
      });
    }
  }

  Future<void> _drawRandomTicker() async {
    if (_drawingTicker || _loadingConfig) {
      return;
    }

    FocusScope.of(context).unfocus();
    _resetRoundState();
    setState(() {
      _drawingTicker = true;
      _loadingAnalysis = true;
      _selectedTicker = null;
      _message = null;
    });

    try {
      final config = _config ?? await FundamentalGameEngine.loadConfig();
      final shuffled = List<_StockAnalystCandidateSeed>.from(
        _stockAnalystCandidateUniverse,
      )..shuffle(_random);

      final probes = <StockAnalystCandidateProbe>[];
      final tickerBySymbol = <String, TickerSearchResult>{};
      final dataBySymbol = <String, FundamentalGameData>{};
      final analysisBySymbol = <String, FundamentalAnalysisResult>{};

      for (final candidate in shuffled) {
        try {
          final ticker = candidate.toTicker();
          final data = await YahooFinanceService.fetchFundamentalGameData(
            candidate.symbol,
          );
          if (!data.isEquity) {
            continue;
          }
          final analysis = FundamentalGameEngine.analyze(
            data: data,
            config: config,
          );
          final metricCount = analysis.subScores.fold<int>(
            0,
            (total, subScore) =>
                total +
                subScore.metrics.where((metric) => !metric.isMissing).length,
          );
          final probe = StockAnalystCandidateProbe(
            symbol: candidate.symbol,
            playable:
                analysis.finalScore != null && !analysis.isInsufficientData,
            missingDataCount: analysis.missingData.length,
            activeCategoryCount: analysis.activeCategoryCount,
            metricCount: metricCount,
          );
          probes.add(probe);
          tickerBySymbol[candidate.symbol] = ticker;
          dataBySymbol[candidate.symbol] = data;
          analysisBySymbol[candidate.symbol] = analysis;
          if (probes.where((item) => item.playable).length >= 5) {
            break;
          }
        } catch (_) {
          continue;
        }
      }

      final pickedSymbol = stockAnalystPickCandidateSymbol(
        probes,
        seed: _random.nextInt(1 << 31),
      );

      if (!mounted) return;

      if (pickedSymbol == null ||
          !tickerBySymbol.containsKey(pickedSymbol) ||
          !dataBySymbol.containsKey(pickedSymbol) ||
          !analysisBySymbol.containsKey(pickedSymbol)) {
        setState(() {
          _loadingAnalysis = false;
          _drawingTicker = false;
          _message =
              'Aucun titre suffisamment exploitable pour un vrai round n’a été trouvé. Réessaie dans un instant.';
        });
        return;
      }

      final ticker = tickerBySymbol[pickedSymbol]!;
      final data = dataBySymbol[pickedSymbol]!;
      final analysis = analysisBySymbol[pickedSymbol]!;
      setState(() {
        _config = config;
        _selectedTicker = ticker;
        _gameData = data;
        _analysis = analysis;
        _loadingAnalysis = false;
        _drawingTicker = false;
        _message = null;
      });
      await _loadExistingGuess(
        symbol: data.symbol,
        companyName: data.companyName ?? ticker.displayName,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _drawingTicker = false;
        _loadingAnalysis = false;
        _message =
            'Le tirage intelligent est indisponible pour le moment. Réessaie dans un instant.';
      });
    }
  }

  void _resetRoundState() {
    _revealController.reset();
    _guessRecord = null;
    _analysis = null;
    _gameData = null;
    _guessValue = 50;
    _loadingGuessRecord = false;
    _submittingGuess = false;
    _closingReward = false;
  }

  Future<void> _loadExistingGuess({
    required String symbol,
    required String companyName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _guessRecord = null;
        _loadingGuessRecord = false;
      });
      return;
    }

    setState(() {
      _loadingGuessRecord = true;
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('stockAnalystGuesses')
              .doc(_stockAnalystGuessDocId(symbol, DateTime.now()))
              .get();

      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final record = _StockAnalystGuessRecord.fromMap(
          doc.data()!,
          fallbackSymbol: symbol,
          fallbackCompanyName: companyName,
        );
        _applyGuessRecord(record);
      } else {
        setState(() {
          _guessRecord = null;
          _guessValue = 50;
          _loadingGuessRecord = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGuessRecord = false;
      });
    }
  }

  void _applyGuessRecord(_StockAnalystGuessRecord record) {
    _revealController.forward(from: 0);
    setState(() {
      _guessRecord = record;
      _guessValue = record.guess.toDouble();
      _loadingGuessRecord = false;
      _closingReward = false;
    });
  }

  Future<void> _closeAndCollectReward() async {
    if (_closingReward) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    setState(() {
      _closingReward = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigator.pop(_guessRecord);
    });
  }

  Future<void> _submitGuess() async {
    final user = FirebaseAuth.instance.currentUser;
    final selectedTicker = _selectedTicker;
    final analysis = _analysis;
    final gameData = _gameData;
    if (user == null ||
        selectedTicker == null ||
        analysis == null ||
        gameData == null ||
        analysis.finalScore == null ||
        analysis.isInsufficientData ||
        _submittingGuess ||
        _hasRevealedGuess) {
      return;
    }

    setState(() {
      _submittingGuess = true;
      _message = null;
    });

    final guess = _guessValue.round().clamp(0, 100);
    final actual = analysis.finalScore!.round().clamp(0, 100);
    final diff = (guess - actual).abs();
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final guessRef = userRef
        .collection('stockAnalystGuesses')
        .doc(_stockAnalystGuessDocId(selectedTicker.symbol, DateTime.now()));

    try {
      final record = await FirebaseFirestore.instance
          .runTransaction<_StockAnalystGuessRecord>((transaction) async {
            final existingGuess = await transaction.get(guessRef);
            if (existingGuess.exists && existingGuess.data() != null) {
              return _StockAnalystGuessRecord.fromMap(
                existingGuess.data()!,
                fallbackSymbol: selectedTicker.symbol,
                fallbackCompanyName:
                    gameData.companyName ?? selectedTicker.displayName,
              );
            }

            final userSnap = await transaction.get(userRef);
            final userData = userSnap.data() ?? const <String, dynamic>{};
            final currentCoins = (userData['coins'] as num?)?.toInt() ?? 0;
            final currentGems = (userData['gems'] as num?)?.toInt() ?? 0;
            final currentOracleHits =
                (userData['stock_analyst_oracle_hits'] as num?)?.toInt() ?? 0;
            final achievements =
                (userData['achievements_claimed'] as List?)
                    ?.map((entry) => entry.toString())
                    .toSet() ??
                <String>{};

            final rewardOutcome = _StockAnalystRewardOutcome.fromDiff(
              diff: diff,
              currentCoins: currentCoins,
              oracleHitCount: currentOracleHits,
              achievementAlreadyUnlocked: achievements.contains(
                _stockAnalystOracleAchievementKey,
              ),
            );
            final nextCoins = math.max(
              0,
              currentCoins +
                  rewardOutcome.rewardCoins -
                  rewardOutcome.penaltyCoins,
            );
            final updates = <String, Object?>{
              'coins': nextCoins,
              'gems': currentGems + rewardOutcome.rewardGems,
            };
            if (rewardOutcome.badgeKey == 'oracle') {
              updates['stock_analyst_oracle_hits'] =
                  rewardOutcome.oracleHitCountAfterGuess;
            }
            if (rewardOutcome.unlocksAchievement &&
                !achievements.contains(_stockAnalystOracleAchievementKey)) {
              updates['achievements_claimed'] = FieldValue.arrayUnion([
                _stockAnalystOracleAchievementKey,
              ]);
            }
            transaction.set(userRef, updates, SetOptions(merge: true));

            final now = DateTime.now();
            final record = _StockAnalystGuessRecord(
              symbol: selectedTicker.symbol.toUpperCase(),
              companyName: gameData.companyName ?? selectedTicker.displayName,
              guess: guess,
              actual: actual,
              diff: diff,
              rewardBand: rewardOutcome.rewardBand,
              rewardCoins: rewardOutcome.rewardCoins,
              rewardGems: rewardOutcome.rewardGems,
              penaltyCoins: rewardOutcome.penaltyCoins,
              badgeKey: rewardOutcome.badgeKey,
              qualitySummary: analysis.qualitySummary,
              verdict: analysis.verdict,
              dayKey: stockAnalystDayKey(now),
              createdAt: now,
              oracleHitCount: rewardOutcome.oracleHitCountAfterGuess,
              achievementUnlocked: rewardOutcome.unlocksAchievement,
            );

            transaction.set(guessRef, {
              'symbol': record.symbol,
              'companyName': record.companyName,
              'guess': record.guess,
              'actual': record.actual,
              'diff': record.diff,
              'rewardBand': record.rewardBand,
              'rewardCoins': record.rewardCoins,
              'rewardGems': record.rewardGems,
              'penaltyCoins': record.penaltyCoins,
              'badgeKey': record.badgeKey,
              'qualitySummary': record.qualitySummary,
              'verdict': record.verdict,
              'dayKey': record.dayKey,
              'oracleHitCount': record.oracleHitCount,
              'achievementUnlocked': record.achievementUnlocked,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            return record;
          });

      if (!mounted) return;
      _applyGuessRecord(record);

      unawaited(
        ActivityTrackingService.trackForUser(
          uid: user.uid,
          type:
              record.badgeKey == 'oracle'
                  ? 'stock_analyst_jackpot'
                  : 'stock_analyst_guess',
          label: selectedTicker.symbol.toUpperCase(),
          points: switch (record.rewardBand) {
            'jackpot' => 34,
            'strong' => 24,
            'close' => 16,
            _ => 8,
          },
          counters: <String, int>{
            'stock_analyst_guesses': 1,
            if (record.badgeKey == 'oracle') 'stock_analyst_jackpots': 1,
          },
        ),
      );

      if (record.achievementUnlocked) {
        unawaited(
          ActivityTrackingService.trackForUser(
            uid: user.uid,
            type: 'stock_analyst_oracle_unlocked',
            label: record.symbol,
            points: 20,
            counters: const <String, int>{'stock_analyst_oracle_unlocks': 1},
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Impossible d’enregistrer ta prédiction pour le moment. Réessaie dans un instant.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submittingGuess = false;
        });
      }
    }
  }

  Widget _buildMetricsTab({
    required TickerSearchResult? selectedTicker,
    required FundamentalAnalysisResult? analysis,
    required FundamentalGameData? gameData,
    required User? user,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RandomTickerDrawCard(
          motion: _motionController,
          loading: _drawingTicker || _loadingAnalysis,
          selectedTicker: selectedTicker,
          onDraw: _drawRandomTicker,
        ),
        const SizedBox(height: 16),
        _StockAnalystHeroCard(
          motion: _motionController,
          selectedTicker: selectedTicker,
          gameData: gameData,
          analysis: analysis,
          guessRecord: _guessRecord,
          loadingAnalysis: _loadingAnalysis || _drawingTicker,
          loadingGuessRecord: _loadingGuessRecord,
          hasAuthenticatedUser: user != null,
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          _StatusCard(message: _message!),
        ],
        if (analysis != null && gameData != null) ...[
          const SizedBox(height: 16),
          _MetricKpiStrip(
            gameData: gameData,
            qualitySummary: analysis.qualitySummary,
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.tune_rounded,
            title: 'Métriques brutes',
          ),
          const SizedBox(height: 10),
          ...analysis.subScores.map(
            (subScore) => _PlayableCategoryCard(subScore: subScore),
          ),
        ] else ...[
          const SizedBox(height: 16),
          const _StatusCard(
            message:
                'Tire un titre pour lancer une vraie session jouable. Le système privilégie les actions avec des fondamentaux riches et exploitables.',
          ),
        ],
      ],
    );
  }

  Widget _buildResultTab({
    required FundamentalAnalysisResult? analysis,
    required User? user,
  }) {
    if (analysis == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _StatusCard(
            message:
                'Aucun titre chargé. Lance un tirage dans l’onglet Métriques pour ouvrir un round.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedSwitcher(
          duration: _stockAnalystRevealDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: .94, end: 1).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            );
          },
          child:
              _guessRecord == null
                  ? _MaskedScoreCard(
                    key: const ValueKey<String>('masked-score'),
                    canPlay: _hasPlayableRound && user != null,
                    isLoadingExistingGuess: _loadingGuessRecord,
                  )
                  : _ScoreOverviewCard(
                    key: const ValueKey<String>('revealed-score'),
                    record: _guessRecord!,
                    reveal: _revealController,
                  ),
        ),
        const SizedBox(height: 16),
        if (_guessRecord == null && _hasPlayableRound && user != null)
          _ScoreSliderCard(
            guessValue: _guessValue,
            submitting: _submittingGuess,
            onChanged: (value) {
              setState(() {
                _guessValue = value;
              });
            },
            onSubmit: _submitGuess,
          )
        else if (_guessRecord == null && !_loadingGuessRecord)
          _EducationOnlyCard(requiresLogin: user == null, analysis: analysis),
        if (_guessRecord != null) ...[
          const SizedBox(height: 16),
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _revealController,
              curve: const Interval(.12, .62, curve: Curves.easeOut),
            ),
            child: _RewardRevealCard(record: _guessRecord!),
          ),
          const SizedBox(height: 16),
          _StatusCard(
            message:
                'Ta note: ${_guessRecord!.guess}/100 • Correction: ${_guessRecord!.actual}/100 • Différence ${_guessRecord!.guess >= _guessRecord!.actual ? '+' : '-'}${_guessRecord!.diff} pts.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _closingReward ? null : _closeAndCollectReward,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: Icon(
                _closingReward
                    ? Icons.hourglass_top_rounded
                    : Icons.redeem_rounded,
              ),
              label: Text(
                _closingReward
                    ? 'Fermeture en cours…'
                    : 'Fermer et récupérer ma récompense',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMethodTab({required FundamentalAnalysisResult? analysis}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ScoreConstructionCard(
          analysis: analysis,
          config: _config,
          hasReveal: _guessRecord != null,
        ),
        if (analysis == null) ...[
          const SizedBox(height: 16),
          const _StatusCard(
            message:
                'Le détail de méthode se remplira après un tirage. Tu y verras les 5 sous-scores, les pondérations et les limites de confiance.',
          ),
        ] else ...[
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.analytics_rounded,
            title: 'Sous-scores',
          ),
          const SizedBox(height: 10),
          if (_guessRecord != null)
            ...analysis.subScores.map(_SubScoreCard.new)
          else
            ...analysis.subScores.map(
              (subScore) => _MethodSubScorePreviewCard(subScore: subScore),
            ),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.workspace_premium_rounded,
            title: 'Badges du moteur',
          ),
          const SizedBox(height: 10),
          _BadgesCard(badges: analysis.badges),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.short_text_rounded,
            title: 'Résumé pédagogique',
          ),
          const SizedBox(height: 10),
          _BulletCard(lines: analysis.summaryLines),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.fact_check_rounded,
            title: 'Checklist',
          ),
          const SizedBox(height: 10),
          _BulletCard(lines: analysis.checklist),
          if (analysis.missingData.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionTitle(
              icon: Icons.warning_amber_rounded,
              title: 'Données manquantes',
            ),
            const SizedBox(height: 10),
            _BulletCard(lines: analysis.missingData),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTicker = _selectedTicker;
    final analysis = _analysis;
    final gameData = _gameData;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Stock Analyst',
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE6E8EB)),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Geo',
                      fontSize: 16,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Métriques'),
                      Tab(text: 'Résultat'),
                      Tab(text: 'Méthode'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMetricsTab(
                      selectedTicker: selectedTicker,
                      analysis: analysis,
                      gameData: gameData,
                      user: user,
                    ),
                    _buildResultTab(analysis: analysis, user: user),
                    _buildMethodTab(analysis: analysis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RandomTickerDrawCard extends StatelessWidget {
  const _RandomTickerDrawCard({
    required this.motion,
    required this.loading,
    required this.selectedTicker,
    required this.onDraw,
  });

  final Animation<double> motion;
  final bool loading;
  final TickerSearchResult? selectedTicker;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final dx = math.sin(motion.value * math.pi * 2) * 9;
    final dy = math.cos(motion.value * math.pi * 2) * 7;
    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Devine le score fondamental d’une action',
            style: TextStyle(
              fontFamily: 'Geo',
              fontWeight: FontWeight.w700,
              fontSize: 26,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le jeu tire un titre parmi des actions riches en données pour que la correction soit vraiment pertinente.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedTicker == null
                          ? 'Aucun titre tiré pour le moment'
                          : 'Dernier tirage: ${selectedTicker!.symbol}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedTicker == null
                          ? 'Appuie sur le bouton pour lancer un tirage intelligent.'
                          : selectedTicker!.displayName,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(dx, dy),
                child: SvgPicture.string(_stockAnalystDrawSvg, width: 86),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onDraw,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon:
                  loading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.casino_rounded),
              label: Text(
                loading
                    ? 'Analyse du meilleur tirage en cours…'
                    : selectedTicker == null
                    ? 'Tirer un titre'
                    : 'Relancer un tirage',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreConstructionCard extends StatelessWidget {
  const _ScoreConstructionCard({
    required this.analysis,
    required this.config,
    required this.hasReveal,
  });

  final FundamentalAnalysisResult? analysis;
  final FundamentalGameConfig? config;
  final bool hasReveal;

  @override
  Widget build(BuildContext context) {
    final categories =
        analysis?.subScores
            .map(
              (subScore) => (
                title: subScore.title,
                weight: subScore.weight,
                partial: subScore.partial,
              ),
            )
            .toList() ??
        config?.categories.values
            .map(
              (category) => (
                title: category.title,
                weight: category.weight,
                partial: false,
              ),
            )
            .toList() ??
        const <({String title, double weight, bool partial})>[];

    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment le score est construit',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Le moteur additionne 5 sous-scores pondérés sur 100: profitabilité, valorisation, solidité bilancielle, cash-flow et qualité de retour aux actionnaires. Si des données manquent, la confiance baisse et certaines catégories deviennent partielles.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...categories.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      '${item.weight.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: detailsColor2,
                      ),
                    ),
                    if (item.partial) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: detailsColor1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasReveal
                ? 'Le détail chiffré est maintenant visible ci-dessous.'
                : 'Le détail chiffré reste masqué tant que tu n’as pas révélé la correction.',
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodSubScorePreviewCard extends StatelessWidget {
  const _MethodSubScorePreviewCard({required this.subScore});

  final FundamentalSubScore subScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subScore.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${subScore.metrics.length} métrique(s) • poids ${subScore.weight.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Masqué',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: detailsColor2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class StockAnalystUiPreview extends StatefulWidget {
  const StockAnalystUiPreview({
    super.key,
    this.revealed = false,
    this.playedToday = false,
    this.initialGuess = 48,
    this.actualScore = 63,
  });

  final bool revealed;
  final bool playedToday;
  final int initialGuess;
  final int actualScore;

  @override
  State<StockAnalystUiPreview> createState() => _StockAnalystUiPreviewState();
}

class _StockAnalystUiPreviewState extends State<StockAnalystUiPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  late double _guessValue;

  _StockAnalystGuessRecord? get _record {
    if (!widget.revealed && !widget.playedToday) return null;
    final diff = (widget.actualScore - widget.initialGuess).abs();
    final preview = stockAnalystRewardPreview(diff: diff, currentCoins: 100);
    return _StockAnalystGuessRecord(
      symbol: 'AAPL',
      companyName: 'Apple',
      guess: widget.initialGuess,
      actual: widget.actualScore,
      diff: diff,
      rewardBand: preview.rewardBand,
      rewardCoins: preview.rewardCoins,
      rewardGems: preview.rewardGems,
      penaltyCoins: preview.penaltyCoins,
      badgeKey: preview.badgeKey,
      qualitySummary: '5 catégorie(s) exploitables',
      verdict: 'Bonne',
      dayKey: stockAnalystDayKey(DateTime(2026, 3, 13)),
      createdAt: DateTime(2026, 3, 13, 10),
      oracleHitCount: preview.oracleHitCountAfterGuess,
      achievementUnlocked: preview.unlocksAchievement,
    );
  }

  @override
  void initState() {
    super.initState();
    _guessValue = widget.initialGuess.toDouble();
    _revealController = AnimationController(
      vsync: this,
      duration: _stockAnalystRevealDuration,
      value: widget.revealed || widget.playedToday ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return MaterialApp(
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE6E8EB)),
                    ),
                    child: const TabBar(
                      indicatorColor: detailsColor2,
                      labelColor: detailsColor2,
                      unselectedLabelColor: Colors.black54,
                      tabs: [
                        Tab(text: 'Métriques'),
                        Tab(text: 'Résultat'),
                        Tab(text: 'Méthode'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _RandomTickerDrawCard(
                            motion: kAlwaysCompleteAnimation,
                            loading: false,
                            selectedTicker: TickerSearchResult(
                              symbol: 'AAPL',
                              displayName: 'Apple',
                              exchange: 'NASDAQ',
                              quoteType: 'EQUITY',
                              region: 'US',
                              currency: 'USD',
                            ),
                            onDraw: () {},
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          AnimatedSwitcher(
                            duration: _stockAnalystRevealDuration,
                            child:
                                record == null
                                    ? _MaskedScoreCard(
                                      key: const ValueKey<String>(
                                        'preview-masked',
                                      ),
                                      canPlay: true,
                                      isLoadingExistingGuess: false,
                                    )
                                    : _ScoreOverviewCard(
                                      key: const ValueKey<String>(
                                        'preview-revealed',
                                      ),
                                      record: record,
                                      reveal: _revealController,
                                    ),
                          ),
                          const SizedBox(height: 16),
                          if (widget.playedToday)
                            const _StatusCard(
                              message: 'Déjà joué aujourd’hui sur ce ticker.',
                            )
                          else
                            _ScoreSliderCard(
                              guessValue: _guessValue,
                              submitting: false,
                              onChanged: (value) {
                                setState(() {
                                  _guessValue = value;
                                });
                              },
                              onSubmit: () {},
                            ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _ScoreConstructionCard(
                            analysis: null,
                            config: null,
                            hasReveal: record != null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockAnalystHeroCard extends StatelessWidget {
  const _StockAnalystHeroCard({
    required this.motion,
    required this.selectedTicker,
    required this.gameData,
    required this.analysis,
    required this.guessRecord,
    required this.loadingAnalysis,
    required this.loadingGuessRecord,
    required this.hasAuthenticatedUser,
  });

  final Animation<double> motion;
  final TickerSearchResult? selectedTicker;
  final FundamentalGameData? gameData;
  final FundamentalAnalysisResult? analysis;
  final _StockAnalystGuessRecord? guessRecord;
  final bool loadingAnalysis;
  final bool loadingGuessRecord;
  final bool hasAuthenticatedUser;

  @override
  Widget build(BuildContext context) {
    final String headline;
    final String subline;
    final List<_HeroPillData> pills = <_HeroPillData>[];

    if (selectedTicker == null) {
      headline = 'Tire un titre pour lancer une session';
      subline =
          'Le tirage choisit une action riche en données, puis tu lis les fondamentaux bruts avant d’estimer la note finale sur 100.';
    } else if (loadingAnalysis) {
      headline = 'Lecture des fondamentaux en cours';
      subline =
          'Le moteur récupère les états financiers et prépare les métriques jouables.';
      pills.add(
        const _HeroPillData(label: 'Chargement', accent: detailsColor2),
      );
    } else if (loadingGuessRecord) {
      headline = 'Vérification du cooldown local';
      subline =
          'On regarde si ce ticker a déjà été joué aujourd’hui sur ton profil.';
      pills.add(const _HeroPillData(label: 'Cooldown', accent: detailsColor2));
    } else if (guessRecord != null) {
      headline = 'Session du jour déjà enregistrée';
      subline =
          'Le reveal reste disponible, mais le ticker est bloqué jusqu’au prochain jour local.';
      pills.add(
        const _HeroPillData(
          label: 'Déjà joué aujourd’hui',
          accent: detailsColor2,
        ),
      );
      pills.add(
        _HeroPillData(
          label: 'Écart ${guessRecord!.diff} pts',
          accent: detailsColor1,
        ),
      );
    } else if (analysis == null) {
      headline = 'Prêt pour une nouvelle lecture';
      subline =
          'Dès qu’un ticker est chargé, tu verras les métriques brutes avant de poser ton verdict.';
    } else if (analysis!.isInsufficientData || analysis!.finalScore == null) {
      headline = 'Mode éducatif uniquement';
      subline =
          'Les données sont utiles pour apprendre, mais pas assez robustes pour ouvrir un round récompensé.';
      pills.add(
        _HeroPillData(label: analysis!.qualitySummary, accent: detailsColor2),
      );
    } else if (!hasAuthenticatedUser) {
      headline = 'Connecte-toi pour enregistrer ta prédiction';
      subline =
          'Les métriques sont visibles, mais le guess et la récompense nécessitent un profil Firestore.';
      pills.add(
        _HeroPillData(label: analysis!.qualitySummary, accent: detailsColor2),
      );
    } else {
      headline = 'Lis, estime, puis révèle';
      subline =
          'Le score final reste masqué jusqu’à validation. Une seule tentative par ticker et par jour local.';
      pills.add(
        _HeroPillData(label: analysis!.qualitySummary, accent: detailsColor2),
      );
      pills.add(
        const _HeroPillData(label: 'Jackpot ≤ 5 pts', accent: detailsColor1),
      );
    }

    final symbol = selectedTicker?.symbol ?? gameData?.symbol ?? 'TICK';
    final company =
        gameData?.companyName ?? selectedTicker?.displayName ?? 'Stock Analyst';
    final exchange = selectedTicker?.exchange ?? gameData?.exchange ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFFCF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9D8A0)),
        boxShadow: [
          BoxShadow(
            color: detailsColor1.withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -10,
              child: AnimatedBuilder(
                animation: motion,
                builder: (context, child) {
                  final dx = math.sin(motion.value * math.pi * 2) * 9;
                  final dy = math.cos(motion.value * math.pi * 2) * 7;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: child,
                  );
                },
                child: Opacity(
                  opacity: .94,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: SvgPicture.string(_stockAnalystHeroSvg),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: detailsColor1.withValues(alpha: .24),
                    ),
                  ),
                  child: Text(
                    symbol.toUpperCase(),
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 220,
                  child: Text(
                    company,
                    style: const TextStyle(
                      fontFamily: 'Geo',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: .95,
                      color: textColor,
                    ),
                  ),
                ),
                if (exchange.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exchange,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  headline,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 250,
                  child: Text(
                    subline,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        pills
                            .map(
                              (pill) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: pill.accent.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: pill.accent.withValues(alpha: .18),
                                  ),
                                ),
                                child: Text(
                                  pill.label,
                                  style: TextStyle(
                                    color: pill.accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricKpiStrip extends StatelessWidget {
  const _MetricKpiStrip({required this.gameData, required this.qualitySummary});

  final FundamentalGameData gameData;
  final String qualitySummary;

  @override
  Widget build(BuildContext context) {
    final currency = gameData.currency ?? '';
    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bandeau KPI',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            qualitySummary,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _KpiPill(
                label: 'CA',
                value: _formatMoney(gameData.revenue, currency: currency),
              ),
              _KpiPill(
                label: 'Résultat net',
                value: _formatMoney(gameData.netIncome, currency: currency),
              ),
              _KpiPill(
                label: 'FCF',
                value: _formatMoney(gameData.freeCashflow, currency: currency),
              ),
              _KpiPill(
                label: 'Cash',
                value: _formatMoney(gameData.totalCash, currency: currency),
              ),
              _KpiPill(
                label: 'Dette',
                value: _formatMoney(gameData.totalDebt, currency: currency),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskedScoreCard extends StatelessWidget {
  const _MaskedScoreCard({
    super.key,
    required this.canPlay,
    required this.isLoadingExistingGuess,
  });

  final bool canPlay;
  final bool isLoadingExistingGuess;

  @override
  Widget build(BuildContext context) {
    final caption =
        isLoadingExistingGuess
            ? 'Vérification de la tentative du jour...'
            : canPlay
            ? 'Le score final reste masqué jusqu’à validation.'
            : 'Le round n’est pas jouable sur ce ticker aujourd’hui.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score verrouillé',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '??/100',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              fontFamily: 'Geo',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            caption,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationOnlyCard extends StatelessWidget {
  const _EducationOnlyCard({
    required this.requiresLogin,
    required this.analysis,
  });

  final bool requiresLogin;
  final FundamentalAnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final message =
        requiresLogin
            ? 'Connecte-toi pour enregistrer un guess et activer la récompense.'
            : analysis.isInsufficientData
            ? 'Les données actuelles ne suffisent pas pour un score final fiable. Utilise cet écran comme support d’analyse.'
            : 'Le round reste désactivé pour ce ticker.';
    return _StatusCard(message: message);
  }
}

class _ScoreOverviewCard extends StatelessWidget {
  const _ScoreOverviewCard({
    super.key,
    required this.record,
    required this.reveal,
  });

  final _StockAnalystGuessRecord record;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    final diffColor =
        record.diff <= 5
            ? Colors.green.shade700
            : record.diff <= 10
            ? Colors.teal.shade700
            : record.diff <= 20
            ? Colors.orange.shade700
            : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score révélé',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: record.actual.toDouble()),
            duration: _stockAnalystRevealDuration,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: value.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Geo',
                      ),
                    ),
                    const TextSpan(
                      text: '/100',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScoreBadge(
                label: record.verdict,
                backgroundColor: Colors.white,
                foregroundColor: diffColor,
              ),
              _ScoreBadge(
                label: 'Ton guess ${record.guess}',
                backgroundColor: Colors.white.withValues(alpha: .16),
                foregroundColor: Colors.white,
              ),
              _ScoreBadge(
                label: 'Écart ${record.diff} pts',
                backgroundColor: Colors.white.withValues(alpha: .16),
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardRevealCard extends StatelessWidget {
  const _RewardRevealCard({required this.record});

  final _StockAnalystGuessRecord record;

  @override
  Widget build(BuildContext context) {
    final rewardTitle = switch (record.rewardBand) {
      'jackpot' => 'Jackpot fondamental',
      'strong' => 'Bonne lecture',
      'close' => 'Lecture correcte',
      _ => 'Lecture à recalibrer',
    };
    final rewardTone = switch (record.rewardBand) {
      'jackpot' => const Color(0xFF0F8B4C),
      'strong' => const Color(0xFF0C6E73),
      'close' => const Color(0xFFB27510),
      _ => const Color(0xFF9E3E32),
    };

    final rewardLine =
        record.rewardCoins > 0 || record.rewardGems > 0
            ? [
              if (record.rewardCoins > 0) '+${record.rewardCoins} coins',
              if (record.rewardGems > 0) '+${record.rewardGems} gems',
            ].join(' · ')
            : '-${record.penaltyCoins} coins';

    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rewardTone.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  record.badgeKey == 'oracle'
                      ? Icons.auto_awesome_rounded
                      : record.penaltyCoins > 0
                      ? Icons.replay_rounded
                      : Icons.insights_rounded,
                  color: rewardTone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rewardTitle,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rewardLine,
                      style: TextStyle(
                        color: rewardTone,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (record.badgeKey == 'oracle')
                _RewardChip(
                  label: 'Badge session: Oracle',
                  tone: detailsColor2,
                ),
              if (record.achievementUnlocked)
                _RewardChip(
                  label: 'Succès global débloqué',
                  tone: detailsColor1,
                ),
              if (record.badgeKey == 'oracle' && !record.achievementUnlocked)
                _RewardChip(
                  label:
                      'Progression Oracle: ${record.oracleHitCount}/$_stockAnalystOracleAchievementTarget',
                  tone: detailsColor1,
                ),
              _RewardChip(
                label:
                    'Cooldown local: ${stockAnalystLocalCooldownLabel(record.dayKey, fallbackDate: record.createdAt)}',
                tone: rewardTone,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: tone, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PlayableCategoryCard extends StatelessWidget {
  const _PlayableCategoryCard({required this.subScore});

  final FundamentalSubScore subScore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _IntroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subScore.title,
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: detailsColor1.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Sous-score masqué',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (subScore.note != null) ...[
              const SizedBox(height: 8),
              Text(
                subScore.note!,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...subScore.metrics.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RawMetricTile(metric: metric),
              ),
            ),
            if (subScore.missingMetrics.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Manque : ${subScore.missingMetrics.join(', ')}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RawMetricTile extends StatelessWidget {
  const _RawMetricTile({required this.metric});

  final FundamentalMetricEvaluation metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'Score masqué',
                style: TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            metric.displayValue,
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (metric.note != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.note!,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreSliderCard extends StatelessWidget {
  const _ScoreSliderCard({
    required this.guessValue,
    required this.submitting,
    required this.onChanged,
    required this.onSubmit,
  });

  final double guessValue;
  final bool submitting;
  final ValueChanged<double> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ton estimation',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: currentChild ?? const SizedBox.shrink(),
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: .94,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  guessValue.round().toString(),
                  key: ValueKey<String>('guess-${guessValue.round()}'),
                  style: const TextStyle(
                    fontFamily: 'Geo',
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: detailsColor2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Place ton curseur entre 0 et 100, puis valide pour révéler la note réelle.',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              activeTrackColor: detailsColor1,
              inactiveTrackColor: detailsColor2.withValues(alpha: .12),
              overlayColor: detailsColor1.withValues(alpha: .18),
              thumbColor: detailsColor2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: guessValue.clamp(0, 100),
              divisions: 100,
              min: 0,
              max: 100,
              label: '${guessValue.round()}',
              onChanged: submitting ? null : onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _SliderMark(label: '0'),
                _SliderMark(label: '25'),
                _SliderMark(label: '50'),
                _SliderMark(label: '75'),
                _SliderMark(label: '100'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: detailsColor1.withValues(alpha: .24),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child:
                  submitting
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Text(
                        'Révéler mon score (${guessValue.round()})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderMark extends StatelessWidget {
  const _SliderMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.black45,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: textColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SubScoreCard extends StatelessWidget {
  const _SubScoreCard(this.subScore);

  final FundamentalSubScore subScore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _IntroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subScore.title,
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                _MetricScorePill(
                  label:
                      subScore.score == null
                          ? 'N/A'
                          : '${subScore.score!.toStringAsFixed(0)}/20',
                ),
                if (subScore.partial) ...[
                  const SizedBox(width: 8),
                  const _MetricScorePill(label: 'Partiel'),
                ],
              ],
            ),
            if (subScore.note != null) ...[
              const SizedBox(height: 8),
              Text(
                subScore.note!,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...subScore.metrics.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MetricRow(metric: metric),
              ),
            ),
            if (subScore.missingMetrics.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Manque : ${subScore.missingMetrics.join(', ')}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final FundamentalMetricEvaluation metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _MetricScorePill(
                label:
                    metric.score == null
                        ? 'N/A'
                        : '${metric.score!.toStringAsFixed(0)}/20',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            metric.displayValue,
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (metric.note != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.note!,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricScorePill extends StatelessWidget {
  const _MetricScorePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.badges});

  final List<FundamentalBadge> badges;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child:
          badges.isEmpty
              ? const Text(
                'Aucun badge instantané déclenché sur les données disponibles.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              )
              : Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    badges
                        .map(
                          (badge) => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE6E8EB),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  badge.label,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    badge.description,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            lines
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: detailsColor2,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _IntroCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: detailsColor2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPillData {
  const _HeroPillData({required this.label, required this.accent});

  final String label;
  final Color accent;
}

class _StockAnalystRewardOutcome {
  const _StockAnalystRewardOutcome({
    required this.rewardBand,
    required this.rewardCoins,
    required this.rewardGems,
    required this.penaltyCoins,
    required this.badgeKey,
    required this.unlocksAchievement,
    required this.oracleHitCountAfterGuess,
  });

  final String rewardBand;
  final int rewardCoins;
  final int rewardGems;
  final int penaltyCoins;
  final String? badgeKey;
  final bool unlocksAchievement;
  final int oracleHitCountAfterGuess;

  factory _StockAnalystRewardOutcome.fromDiff({
    required int diff,
    required int currentCoins,
    required int oracleHitCount,
    required bool achievementAlreadyUnlocked,
  }) {
    if (diff <= 5) {
      final nextOracleHitCount = oracleHitCount + 1;
      return _StockAnalystRewardOutcome(
        rewardBand: 'jackpot',
        rewardCoins: 250,
        rewardGems: 8,
        penaltyCoins: 0,
        badgeKey: 'oracle',
        unlocksAchievement:
            !achievementAlreadyUnlocked &&
            nextOracleHitCount >= _stockAnalystOracleAchievementTarget,
        oracleHitCountAfterGuess: nextOracleHitCount,
      );
    }
    if (diff <= 10) {
      return const _StockAnalystRewardOutcome(
        rewardBand: 'strong',
        rewardCoins: 120,
        rewardGems: 0,
        penaltyCoins: 0,
        badgeKey: null,
        unlocksAchievement: false,
        oracleHitCountAfterGuess: 0,
      );
    }
    if (diff <= 20) {
      return const _StockAnalystRewardOutcome(
        rewardBand: 'close',
        rewardCoins: 40,
        rewardGems: 0,
        penaltyCoins: 0,
        badgeKey: null,
        unlocksAchievement: false,
        oracleHitCountAfterGuess: 0,
      );
    }
    return _StockAnalystRewardOutcome(
      rewardBand: 'miss',
      rewardCoins: 0,
      rewardGems: 0,
      penaltyCoins: math.min(25, currentCoins),
      badgeKey: null,
      unlocksAchievement: false,
      oracleHitCountAfterGuess: 0,
    );
  }
}

class _StockAnalystGuessRecord {
  const _StockAnalystGuessRecord({
    required this.symbol,
    required this.companyName,
    required this.guess,
    required this.actual,
    required this.diff,
    required this.rewardBand,
    required this.rewardCoins,
    required this.rewardGems,
    required this.penaltyCoins,
    required this.badgeKey,
    required this.qualitySummary,
    required this.verdict,
    required this.dayKey,
    required this.createdAt,
    required this.oracleHitCount,
    required this.achievementUnlocked,
  });

  final String symbol;
  final String companyName;
  final int guess;
  final int actual;
  final int diff;
  final String rewardBand;
  final int rewardCoins;
  final int rewardGems;
  final int penaltyCoins;
  final String? badgeKey;
  final String qualitySummary;
  final String verdict;
  final String dayKey;
  final DateTime createdAt;
  final int oracleHitCount;
  final bool achievementUnlocked;

  factory _StockAnalystGuessRecord.fromMap(
    Map<String, dynamic> map, {
    String? fallbackSymbol,
    String? fallbackCompanyName,
  }) {
    final timestamp = map['createdAt'];
    return _StockAnalystGuessRecord(
      symbol:
          ((map['symbol'] as String?) ?? fallbackSymbol ?? '').toUpperCase(),
      companyName: (map['companyName'] as String?) ?? fallbackCompanyName ?? '',
      guess: (map['guess'] as num?)?.toInt() ?? 0,
      actual: (map['actual'] as num?)?.toInt() ?? 0,
      diff: (map['diff'] as num?)?.toInt() ?? 0,
      rewardBand: (map['rewardBand'] as String? ?? 'miss').trim(),
      rewardCoins: (map['rewardCoins'] as num?)?.toInt() ?? 0,
      rewardGems: (map['rewardGems'] as num?)?.toInt() ?? 0,
      penaltyCoins: (map['penaltyCoins'] as num?)?.toInt() ?? 0,
      badgeKey: (map['badgeKey'] as String?)?.trim(),
      qualitySummary: (map['qualitySummary'] as String? ?? '').trim(),
      verdict: (map['verdict'] as String? ?? '').trim(),
      dayKey: (map['dayKey'] as String? ?? '').trim(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      oracleHitCount: (map['oracleHitCount'] as num?)?.toInt() ?? 0,
      achievementUnlocked: (map['achievementUnlocked'] as bool?) ?? false,
    );
  }
}

String _stockAnalystGuessDocId(String symbol, DateTime now) =>
    '${symbol.trim().toUpperCase()}_${stockAnalystDayKey(now)}';

String _formatMoney(double? value, {String currency = ''}) {
  if (value == null || value.isNaN) return 'N/A';
  final abs = value.abs();
  double divisor = 1;
  String suffix = '';
  if (abs >= 1e12) {
    divisor = 1e12;
    suffix = 'T';
  } else if (abs >= 1e9) {
    divisor = 1e9;
    suffix = 'Md';
  } else if (abs >= 1e6) {
    divisor = 1e6;
    suffix = 'M';
  } else if (abs >= 1e3) {
    divisor = 1e3;
    suffix = 'k';
  }
  final compact = value / divisor;
  final digits =
      compact.abs() >= 100
          ? 0
          : compact.abs() >= 10
          ? 1
          : 2;
  final number = compact.toStringAsFixed(digits);
  final currencyLabel = currency.trim().isEmpty ? '' : ' ${currency.trim()}';
  return '$number$suffix$currencyLabel';
}

const String _stockAnalystHeroSvg = '''
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
    <linearGradient id="plum" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2A0F45"/>
      <stop offset="100%" stop-color="#4E2279"/>
    </linearGradient>
  </defs>
  <rect x="22" y="36" width="138" height="118" rx="28" fill="#FFF7DE" stroke="#E7D39A" stroke-width="4"/>
  <path d="M42 118 C62 92, 82 104, 98 80 S132 58, 148 70" fill="none" stroke="url(#gold)" stroke-width="9" stroke-linecap="round"/>
  <rect x="44" y="128" width="16" height="18" rx="6" fill="url(#plum)" opacity="0.88"/>
  <rect x="70" y="108" width="16" height="38" rx="6" fill="url(#gold)" opacity="0.92"/>
  <rect x="96" y="92" width="16" height="54" rx="6" fill="url(#plum)" opacity="0.88"/>
  <rect x="122" y="74" width="16" height="72" rx="6" fill="url(#gold)" opacity="0.92"/>
  <circle cx="136" cy="126" r="44" fill="none" stroke="url(#plum)" stroke-width="12"/>
  <circle cx="136" cy="126" r="29" fill="#FFFFFF" opacity="0.94"/>
  <line x1="166" y1="156" x2="196" y2="186" stroke="url(#gold)" stroke-width="14" stroke-linecap="round"/>
  <circle cx="148" cy="110" r="6" fill="url(#gold)"/>
  <path d="M124 122 L138 108 L152 118" fill="none" stroke="url(#plum)" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="60" cy="58" r="10" fill="url(#gold)" opacity="0.45"/>
  <circle cx="176" cy="58" r="8" fill="url(#plum)" opacity="0.18"/>
</svg>
''';
