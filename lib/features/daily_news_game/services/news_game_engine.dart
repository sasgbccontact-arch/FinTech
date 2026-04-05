import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/news_article.dart';
import '../models/news_game_models.dart';
import '../utils/news_text_sanitizer.dart';
export '../utils/news_text_sanitizer.dart' show sanitizeNewsGameText;

const int kNewsGameMinQualityScore = 55;

@visibleForTesting
int scoreNewsArticleQuality(NewsArticle article) =>
    NewsGameEngine.scoreArticleQuality(article);

class NewsGameEngine {
  const NewsGameEngine._();

  static const List<String> _financeSignals = <String>[
    'market',
    'markets',
    'stock',
    'stocks',
    'equity',
    'equities',
    'inflation',
    'rates',
    'rate',
    'yield',
    'bond',
    'earnings',
    'guidance',
    'merger',
    'acquisition',
    'recession',
    'oil',
    'commodities',
    'central bank',
    'fed',
    'ecb',
    'boj',
    'currency',
    'forex',
    'dollar',
    'euro',
    'yuan',
    'actions',
    'marchés',
    'bourse',
    'banque centrale',
    'résultats',
    'matières premières',
    'taux',
    'devise',
    'pétrole',
  ];

  static const List<String> _badSignals = <String>[
    'celebrity',
    'music',
    'movie',
    'sport',
    'sports',
    'fashion',
    'gossip',
    'viral',
    'gaming',
    'recipe',
  ];

  static const List<String> _vagueSignals = <String>[
    'what to know',
    'live updates',
    'morning news',
    'top stories',
    'must watch',
    'here is why',
    'breaking news',
  ];

  static const List<String> _reliableSources = <String>[
    'reuters',
    'bloomberg',
    'financial times',
    'ft',
    'wall street journal',
    'wsj',
    'cnbc',
    'bbc',
    'ap',
    'associated press',
    'marketwatch',
    'les echos',
    'le monde',
  ];

  static const List<String> _themeDistractors = <String>[
    'Inflation',
    'Banques centrales',
    'Earnings',
    'M&A',
    'Géopolitique',
    'Commodities',
    'FX',
    'Taux',
  ];

  static const List<String> _entityDistractors = <String>[
    'Réserve fédérale',
    'BCE',
    'Bank of Japan',
    'OPEP',
    'S&P 500',
    'Nasdaq',
    'Dollar',
    'Or',
  ];

  static int scoreArticleQuality(NewsArticle article) {
    final title = sanitizeNewsGameText(article.title);
    final snippet = sanitizeNewsGameText(article.snippet ?? '');
    final text = '$title $snippet'.toLowerCase();
    if (title.isEmpty) return 0;
    if (_badSignals.any(text.contains)) return 0;
    if (!_financeSignals.any(text.contains)) return 18;

    var score = 42;
    final category = _detectCategory(text);
    if (category != NewsMacroCategory.general) {
      score += 12;
    }
    if (snippet.isNotEmpty) {
      score += 8;
    }
    final ageHours =
        DateTime.now().difference(article.publishedAt.toLocal()).inHours;
    if (ageHours <= 24) {
      score += 16;
    } else if (ageHours <= 72) {
      score += 8;
    } else {
      score -= 10;
    }
    final source = article.source.toLowerCase();
    if (_reliableSources.any(source.contains)) {
      score += 10;
    }
    if (_vagueSignals.any(text.contains)) {
      score -= 18;
    }
    if (!_hasCausalAngle(text)) {
      score -= 12;
    }
    if (title.split(' ').length < 5) {
      score -= 6;
    }
    return score.clamp(0, 100);
  }

  static List<NewsGameDeckItem> buildDailyDeck(List<NewsArticle> articles) {
    final enriched =
        articles
            .map(buildDeckItem)
            .where((item) => item.qualityScore >= kNewsGameMinQualityScore)
            .where((item) => item.isDeckReady)
            .toList()
          ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    if (enriched.length <= 5) return enriched;
    return enriched.take(5).toList();
  }

  static NewsGameDeckItem buildDeckItem(
    NewsArticle article, {
    String? forcedRegion,
    String? forcedRegionKey,
  }) {
    final cleanTitle = sanitizeNewsGameText(article.title);
    final cleanSnippet = sanitizeNewsGameText(article.snippet ?? '');
    final lower = '$cleanTitle $cleanSnippet'.toLowerCase();
    final category = _detectCategory(lower);
    final signal = _detectSignal(lower, category);
    final regionInfo = _detectRegion(
      lower,
      fallbackRegion: forcedRegion,
      fallbackKey: forcedRegionKey,
    );
    final quality = scoreArticleQuality(article);
    final difficulty = _detectDifficulty(
      quality: quality,
      category: category,
      signal: signal,
    );
    final impactOptions = _buildImpactOptions(
      category: category,
      signal: signal,
      regionLabel: regionInfo.label,
      seed: _seedFrom(article.id, quality),
    );
    final causalChain = _buildCausalChain(
      category: category,
      signal: signal,
      regionLabel: regionInfo.label,
    );
    final questions = _buildQuestions(
      article: article,
      category: category,
      causalChain: causalChain,
      signal: signal,
      seed: _seedFrom(article.url, quality + 17),
    );
    final rewardPotential = switch (difficulty) {
      NewsDifficulty.easy => 24,
      NewsDifficulty.medium => 34,
      NewsDifficulty.hard => 46,
    };
    return NewsGameDeckItem(
      articleId: article.id,
      article: article,
      displayTitle: cleanTitle,
      displaySnippet: cleanSnippet,
      region: regionInfo.label,
      regionKey: regionInfo.key,
      macroCategory: category,
      difficulty: difficulty,
      qualityScore: quality,
      impactOptions: impactOptions,
      causalChain: causalChain,
      comprehensionQuestions: questions,
      debrief: _buildDebrief(
        category: category,
        signal: signal,
        regionLabel: regionInfo.label,
        impactOptions: impactOptions,
      ),
      rewardPotential: rewardPotential,
    );
  }

  static NewsWorldRoute buildWorldRoute({
    required String sourceCountryIso2,
    required String sourceCountryNameFr,
    required NewsArticle article,
  }) {
    final sourceItem = buildDeckItem(
      article,
      forcedRegion: sourceCountryNameFr,
      forcedRegionKey: sourceCountryIso2.toLowerCase(),
    );
    final seed = _seedFrom(sourceCountryIso2, sourceItem.qualityScore + 71);
    final firstRegion = _buildPropagationRegionNode(sourceItem, seed);
    final secondWave = _buildSecondWaveNode(sourceItem, seed + 19);
    return NewsWorldRoute(
      sourceCountryIso2: sourceCountryIso2.toUpperCase(),
      sourceCountryNameFr: sourceCountryNameFr,
      sourceItem: sourceItem,
      routeNodes: <NewsWorldRouteNode>[firstRegion, secondWave],
    );
  }

  static NewsRoundResult resolveDeckRound({
    required NewsGameDeckItem item,
    required List<NewsImpactPrediction> predictions,
    required List<int?> comprehensionAnswers,
    required int currentCombo,
    required int questionCount,
  }) {
    final marketScore = _scoreMarketPrediction(
      options: item.impactOptions,
      predictions: predictions,
    );
    final comprehensionScore = _scoreComprehension(
      questions: item.comprehensionQuestions.take(questionCount).toList(),
      answers: comprehensionAnswers,
    );
    final comboAfterRound = marketScore >= 70 ? currentCombo + 1 : 0;
    return NewsRoundResult(
      nodeId: item.articleId,
      predictions: predictions,
      comprehensionAnswers: comprehensionAnswers,
      marketScore: marketScore,
      comprehensionScore: comprehensionScore,
      comboAfterRound: comboAfterRound,
      marketPerfect: marketScore >= 85,
      debrief: item.debrief,
      themeKey: item.macroCategory.key,
    );
  }

  static NewsRoundResult resolveRouteNode({
    required NewsWorldRouteNode node,
    required NewsMacroCategory category,
    required List<NewsImpactPrediction> predictions,
    required int currentCombo,
  }) {
    final marketScore = _scoreMarketPrediction(
      options: node.impactOptions,
      predictions: predictions,
    );
    final comboAfterRound = marketScore >= 70 ? currentCombo + 1 : 0;
    return NewsRoundResult(
      nodeId: node.id,
      predictions: predictions,
      comprehensionAnswers: const <int?>[],
      marketScore: marketScore,
      comprehensionScore: 100,
      comboAfterRound: comboAfterRound,
      marketPerfect: marketScore >= 85,
      debrief: node.explanation,
      themeKey: category.key,
    );
  }

  static NewsSessionScoreBreakdown buildSessionBreakdown(
    List<NewsRoundResult> rounds,
  ) {
    if (rounds.isEmpty) {
      return const NewsSessionScoreBreakdown(
        comprehensionScore: 0,
        marketScore: 0,
        comboBonus: 0,
        finalScore: 0,
        accuracy: 0,
        maxCombo: 0,
        themeScores: <String, int>{},
      );
    }

    final totalMarket = rounds.fold<int>(
      0,
      (sum, round) => sum + round.marketScore,
    );
    final totalComprehension = rounds.fold<int>(
      0,
      (sum, round) => sum + round.comprehensionScore,
    );
    final marketAverage = (totalMarket / rounds.length).round();
    final comprehensionAverage = (totalComprehension / rounds.length).round();
    final maxCombo = rounds.fold<int>(
      0,
      (maxValue, round) => math.max(maxValue, round.comboAfterRound),
    );
    final comboBonus = math.min(math.max(0, maxCombo - 1) * 2, 10);
    final baseScore =
        (marketAverage * 0.6 + comprehensionAverage * 0.4).round();
    final themeBuckets = <String, List<int>>{};
    for (final round in rounds) {
      themeBuckets
          .putIfAbsent(round.themeKey, () => <int>[])
          .add(
            ((round.marketScore * 0.6) + (round.comprehensionScore * 0.4))
                .round(),
          );
    }
    final themeScores = <String, int>{
      for (final entry in themeBuckets.entries)
        entry.key:
            (entry.value.reduce((a, b) => a + b) / entry.value.length).round(),
    };
    return NewsSessionScoreBreakdown(
      comprehensionScore: comprehensionAverage,
      marketScore: marketAverage,
      comboBonus: comboBonus,
      finalScore: math.min(100, baseScore + comboBonus),
      accuracy: marketAverage / 100,
      maxCombo: maxCombo,
      themeScores: themeScores,
    );
  }

  static int _scoreMarketPrediction({
    required List<NewsImpactOption> options,
    required List<NewsImpactPrediction> predictions,
  }) {
    if (predictions.isEmpty || options.isEmpty) return 0;
    final byId = <String, NewsImpactOption>{
      for (final option in options) option.id: option,
    };
    var rawScore = 0.0;
    var maxRaw = 0.0;
    for (final prediction in predictions) {
      final option = byId[prediction.targetId];
      final gain = prediction.confidenceLevel.gainMultiplier;
      final penalty = prediction.confidenceLevel.penaltyMultiplier;
      maxRaw += 10 * gain;
      if (option == null) {
        rawScore -= 4 * penalty;
        continue;
      }
      if (option.isExpectedTarget &&
          prediction.direction == option.expectedDirection) {
        rawScore += 10 * gain;
      } else if (option.isExpectedTarget &&
          prediction.direction == PredictionDirection.neutral &&
          option.expectedDirection == PredictionDirection.neutral) {
        rawScore += 8 * gain;
      } else if (option.isExpectedTarget) {
        rawScore -= 8 * penalty;
      } else if (prediction.direction == PredictionDirection.neutral) {
        rawScore -= 4 * penalty;
      } else {
        rawScore -= 6 * penalty;
      }
    }
    if (maxRaw <= 0) return 0;
    final score = ((math.max(0.0, rawScore) / maxRaw) * 100).round();
    return score.clamp(0, 100);
  }

  static int _scoreComprehension({
    required List<NewsComprehensionQuestion> questions,
    required List<int?> answers,
  }) {
    if (questions.isEmpty) return 100;
    var correct = 0;
    for (var index = 0; index < questions.length; index++) {
      final answer = index < answers.length ? answers[index] : null;
      if (answer != null && answer == questions[index].correctIndex) {
        correct += 1;
      }
    }
    return ((correct / questions.length) * 100).round();
  }

  static _RegionInfo _detectRegion(
    String text, {
    String? fallbackRegion,
    String? fallbackKey,
  }) {
    if (fallbackRegion != null &&
        fallbackRegion.trim().isNotEmpty &&
        fallbackKey != null &&
        fallbackKey.trim().isNotEmpty) {
      return _RegionInfo(fallbackKey.trim(), fallbackRegion.trim());
    }
    const regions = <String, _RegionInfo>{
      'united states': _RegionInfo('us', 'États-Unis'),
      'us ': _RegionInfo('us', 'États-Unis'),
      'euro zone': _RegionInfo('europe', 'Europe'),
      'europe': _RegionInfo('europe', 'Europe'),
      'china': _RegionInfo('china', 'Chine'),
      'japan': _RegionInfo('japan', 'Japon'),
      'middle east': _RegionInfo('middle_east', 'Moyen-Orient'),
      'india': _RegionInfo('india', 'Inde'),
      'uk ': _RegionInfo('uk', 'Royaume-Uni'),
      'france': _RegionInfo('france', 'France'),
    };
    for (final entry in regions.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return const _RegionInfo('world', 'Monde');
  }

  static NewsMacroCategory _detectCategory(String text) {
    if (_containsAny(text, const <String>[
      'inflation',
      'cpi',
      'ppi',
      'prices',
    ])) {
      return NewsMacroCategory.inflation;
    }
    if (_containsAny(text, const <String>[
      'central bank',
      'fed',
      'ecb',
      'boj',
      'rate decision',
      'banque centrale',
    ])) {
      return NewsMacroCategory.centralBanks;
    }
    if (_containsAny(text, const <String>[
      'earnings',
      'profit',
      'guidance',
      'results',
      'revenue',
      'bénéfices',
      'résultats',
    ])) {
      return NewsMacroCategory.earnings;
    }
    if (_containsAny(text, const <String>[
      'merger',
      'acquisition',
      'deal',
      'takeover',
      'm&a',
      'fusion',
      'rachat',
    ])) {
      return NewsMacroCategory.mergers;
    }
    if (_containsAny(text, const <String>[
      'war',
      'sanctions',
      'ceasefire',
      'tariffs',
      'election',
      'guerre',
      'géopolitique',
      'trade tensions',
    ])) {
      return NewsMacroCategory.geopolitics;
    }
    if (_containsAny(text, const <String>[
      'oil',
      'gas',
      'copper',
      'commodity',
      'opec',
      'pétrole',
      'matières premières',
    ])) {
      return NewsMacroCategory.commodities;
    }
    if (_containsAny(text, const <String>[
      'dollar',
      'euro',
      'yen',
      'yuan',
      'forex',
      'currency',
      'devise',
    ])) {
      return NewsMacroCategory.fx;
    }
    if (_containsAny(text, const <String>[
      'yield',
      'bond',
      'treasury',
      'spread',
      'rates',
      'taux',
      'obligations',
    ])) {
      return NewsMacroCategory.rates;
    }
    return NewsMacroCategory.general;
  }

  static String _detectSignal(String text, NewsMacroCategory category) {
    if (_containsAny(text, const <String>[
      'beat',
      'strong',
      'record',
      'surge',
      'jump',
      'raises guidance',
      'better than expected',
      'cooling',
      'cut rates',
      'ceasefire',
      'eases',
      'ease',
    ])) {
      return 'positive';
    }
    if (_containsAny(text, const <String>[
      'miss',
      'warning',
      'cuts forecast',
      'slump',
      'drop',
      'stickier',
      'hotter',
      'hike',
      'escalates',
      'surges',
      'sanctions',
    ])) {
      return 'negative';
    }
    return switch (category) {
      NewsMacroCategory.inflation => 'negative',
      NewsMacroCategory.centralBanks => 'negative',
      NewsMacroCategory.earnings => 'positive',
      NewsMacroCategory.mergers => 'positive',
      NewsMacroCategory.geopolitics => 'negative',
      NewsMacroCategory.commodities => 'negative',
      NewsMacroCategory.fx => 'positive',
      NewsMacroCategory.rates => 'negative',
      NewsMacroCategory.general => 'neutral',
    };
  }

  static bool _hasCausalAngle(String text) {
    return _containsAny(text, const <String>[
      'because',
      'after',
      'amid',
      'as',
      'on fears',
      'on hopes',
      'due to',
      'after data',
      'following',
      'après',
      'en raison',
      'face à',
    ]);
  }

  static NewsDifficulty _detectDifficulty({
    required int quality,
    required NewsMacroCategory category,
    required String signal,
  }) {
    if (quality >= 78 &&
        category != NewsMacroCategory.general &&
        signal != 'neutral') {
      return NewsDifficulty.hard;
    }
    if (quality >= 64) return NewsDifficulty.medium;
    return NewsDifficulty.easy;
  }

  static List<NewsImpactOption> _buildImpactOptions({
    required NewsMacroCategory category,
    required String signal,
    required String regionLabel,
    required int seed,
  }) {
    final positive = signal == 'positive';
    final templates = switch (category) {
      NewsMacroCategory.inflation ||
      NewsMacroCategory.centralBanks => <NewsImpactOption>[
        _impact(
          'long_rates',
          'Taux longs',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Des taux plus durs soutiennent les rendements, des chiffres plus froids les calment.',
        ),
        _impact(
          'growth',
          'Actions growth',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Les valeurs de croissance respirent quand la pression sur les taux retombe.',
        ),
        _impact(
          'usd',
          'Dollar',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Un discours plus restrictif soutient le dollar, un pivot plus doux le détend.',
        ),
        _impact(
          'gold',
          'Or',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          false,
          'L’or réagit parfois en contre-tendance, mais ce n’est pas le relais principal ici.',
        ),
        _impact(
          'airlines',
          'Compagnies aériennes',
          NewsImpactKind.sector,
          PredictionDirection.neutral,
          false,
          'Le lien est trop indirect pour être le premier réflexe de marché.',
        ),
      ],
      NewsMacroCategory.earnings => <NewsImpactOption>[
        _impact(
          'sector_sentiment',
          'Secteur lié',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Des résultats qui surprennent revalorisent d’abord le secteur directement concerné.',
        ),
        _impact(
          'local_index',
          'Indice local',
          NewsImpactKind.region,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Une surprise de résultats peut infuser rapidement dans l’indice domestique.',
        ),
        _impact(
          'defensives',
          'Actions défensives',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Le risk-on pénalise souvent la rotation défensive, et inversement.',
        ),
        _impact(
          'oil',
          'Pétrole',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Le pétrole n’est pas la lecture directe d’une publication de résultats.',
        ),
        _impact(
          'sovereign_bonds',
          'Obligations souveraines',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Le lien existe parfois, mais ce n’est pas le canal dominant.',
        ),
      ],
      NewsMacroCategory.mergers => <NewsImpactOption>[
        _impact(
          'target_equity',
          'Actions de la cible',
          NewsImpactKind.asset,
          PredictionDirection.bullish,
          true,
          'Une opération de rachat crée souvent une prime immédiate sur la cible.',
        ),
        _impact(
          'peer_sector',
          'Pairs du secteur',
          NewsImpactKind.sector,
          PredictionDirection.bullish,
          true,
          'Le marché revalorise souvent des pairs quand la consolidation s’accélère.',
        ),
        _impact(
          'buyer_equity',
          'Actions de l’acquéreur',
          NewsImpactKind.asset,
          positive ? PredictionDirection.neutral : PredictionDirection.bearish,
          true,
          'L’acquéreur est parfois sanctionné si le deal paraît coûteux.',
        ),
        _impact(
          'gold',
          'Or',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'L’or n’est pas l’expression naturelle d’une annonce M&A.',
        ),
        _impact(
          'rates',
          'Taux longs',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Les taux ne sont pas le premier canal d’une fusion ciblée.',
        ),
      ],
      NewsMacroCategory.geopolitics => <NewsImpactOption>[
        _impact(
          'oil',
          'Pétrole',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Un apaisement détend l’énergie, une escalade la soutient.',
        ),
        _impact(
          'safe_havens',
          'Valeurs refuges',
          NewsImpactKind.theme,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Le risque géopolitique favorise les refuges quand il monte.',
        ),
        _impact(
          'regional_equity',
          'Actions régionales',
          NewsImpactKind.region,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'L’appétit pour le risque local dépend fortement du niveau de tension.',
        ),
        _impact(
          'software',
          'Logiciels',
          NewsImpactKind.sector,
          PredictionDirection.neutral,
          false,
          'Le software n’est pas la première traduction d’une crise géopolitique.',
        ),
        _impact(
          'real_estate',
          'Immobilier coté',
          NewsImpactKind.sector,
          PredictionDirection.neutral,
          false,
          'L’effet existe mais n’est pas le premier prix qui bouge.',
        ),
      ],
      NewsMacroCategory.commodities => <NewsImpactOption>[
        _impact(
          'energy',
          'Énergie',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Un choc sur la ressource se répercute d’abord sur le secteur producteur.',
        ),
        _impact(
          'airlines',
          'Compagnies aériennes',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Les coûts énergétiques rejaillissent vite sur les transporteurs.',
        ),
        _impact(
          'inflation_theme',
          'Inflation anticipée',
          NewsImpactKind.theme,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Le marché relit rapidement le choc matière première via l’inflation.',
        ),
        _impact(
          'biotech',
          'Biotech',
          NewsImpactKind.sector,
          PredictionDirection.neutral,
          false,
          'Le lien est trop faible pour être le bon premier réflexe.',
        ),
        _impact(
          'yen',
          'Yen',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'La devise peut bouger, mais ce n’est pas la lecture la plus directe ici.',
        ),
      ],
      NewsMacroCategory.fx => <NewsImpactOption>[
        _impact(
          'dollar',
          'Dollar',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'La logique devise est le canal principal de cette news.',
        ),
        _impact(
          'em_fx',
          'Devises émergentes',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Un dollar plus fort tend à mettre les devises EM sous pression.',
        ),
        _impact(
          'importers',
          'Importateurs',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Le change modifie vite les marges des acteurs exposés aux importations.',
        ),
        _impact(
          'oil',
          'Pétrole',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Le pétrole peut réagir mais ce n’est pas la traduction la plus simple ici.',
        ),
        _impact(
          'banks',
          'Banques',
          NewsImpactKind.sector,
          PredictionDirection.neutral,
          false,
          'Le secteur bancaire n’est pas le meilleur premier relais d’une news FX générique.',
        ),
      ],
      NewsMacroCategory.rates => <NewsImpactOption>[
        _impact(
          'bonds',
          'Obligations souveraines',
          NewsImpactKind.asset,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Un mouvement de taux redessine directement le marché obligataire.',
        ),
        _impact(
          'growth',
          'Actions growth',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Les valeurs longues de duration souffrent quand les rendements remontent.',
        ),
        _impact(
          'banks',
          'Banques',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Une pente de taux plus favorable soutient souvent le secteur bancaire.',
        ),
        _impact(
          'gold',
          'Or',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'L’or n’est pas le premier actif à lire pour une news de taux pure.',
        ),
        _impact(
          'oil',
          'Pétrole',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Le pétrole dépend d’autres moteurs avant les taux purs.',
        ),
      ],
      NewsMacroCategory.general => <NewsImpactOption>[
        _impact(
          'broad_equity',
          '$regionLabel actions',
          NewsImpactKind.region,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'Le premier réflexe reste l’impact sur les actions de la zone concernée.',
        ),
        _impact(
          'risk_appetite',
          'Appétit pour le risque',
          NewsImpactKind.theme,
          positive ? PredictionDirection.bullish : PredictionDirection.bearish,
          true,
          'La news change d’abord le ton du marché.',
        ),
        _impact(
          'defensives',
          'Valeurs défensives',
          NewsImpactKind.sector,
          positive ? PredictionDirection.bearish : PredictionDirection.bullish,
          true,
          'Le risk-off favorise souvent les défensives et inversement.',
        ),
        _impact(
          'long_rates',
          'Taux longs',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Sans angle taux explicite, ce n’est pas la réponse la plus nette.',
        ),
        _impact(
          'oil',
          'Pétrole',
          NewsImpactKind.asset,
          PredictionDirection.neutral,
          false,
          'Le pétrole ne capte pas chaque actualité macro généraliste.',
        ),
      ],
    };
    final list = List<NewsImpactOption>.from(templates);
    _shuffleInPlace(list, seed);
    return list;
  }

  static List<String> _buildCausalChain({
    required NewsMacroCategory category,
    required String signal,
    required String regionLabel,
  }) {
    final riskUp = signal == 'positive';
    return switch (category) {
      NewsMacroCategory.inflation || NewsMacroCategory.centralBanks => <String>[
        riskUp ? 'détente sur les taux' : 'tension sur les taux',
        riskUp ? 'reprise du growth' : 'pression sur les valeurs longues',
        'rotation rapide dans les indices',
      ],
      NewsMacroCategory.earnings => <String>[
        riskUp ? 'surprise bénéficiaire' : 'déception sur les résultats',
        riskUp ? 'revalorisation sectorielle' : 'compression des multiples',
        'lecture élargie du cycle',
      ],
      NewsMacroCategory.mergers => <String>[
        'annonce de deal',
        'prime de consolidation',
        'réévaluation des pairs',
      ],
      NewsMacroCategory.geopolitics => <String>[
        riskUp ? 'apaisement des tensions' : 'hausse de l’aversion au risque',
        riskUp ? 'retour du risk-on' : 'recherche de refuges',
        'impact global sur $regionLabel',
      ],
      NewsMacroCategory.commodities => <String>[
        riskUp
            ? 'normalisation de la ressource'
            : 'choc sur la matière première',
        riskUp
            ? 'respiration sur les coûts'
            : 'relance des craintes inflationnistes',
        'relecture sectorielle immédiate',
      ],
      NewsMacroCategory.fx => <String>[
        'mouvement de change',
        'ajustement des marges import/export',
        'rotation sur les devises à risque',
      ],
      NewsMacroCategory.rates => <String>[
        'mouvement de rendement',
        'réévaluation de la duration',
        'rotation growth / value',
      ],
      NewsMacroCategory.general => <String>[
        'signal macro',
        'changement de ton sur le risque',
        'repositionnement des investisseurs',
      ],
    };
  }

  static List<NewsComprehensionQuestion> _buildQuestions({
    required NewsArticle article,
    required NewsMacroCategory category,
    required List<String> causalChain,
    required String signal,
    required int seed,
  }) {
    final questions = <NewsComprehensionQuestion>[
      _buildThemeQuestion(category, seed),
    ];
    final entity = _extractEntity(sanitizeNewsGameText(article.title));
    if (entity != null) {
      questions.add(_buildEntityQuestion(entity, seed + 17));
    } else {
      questions.add(_buildCausalQuestion(causalChain, signal, seed + 29));
    }
    return questions;
  }

  static NewsComprehensionQuestion _buildThemeQuestion(
    NewsMacroCategory category,
    int seed,
  ) {
    final choices = <String>[
      category.label,
      ..._themeDistractors.where((label) => label != category.label).take(5),
    ];
    _shuffleInPlace(choices, seed);
    return NewsComprehensionQuestion(
      id: 'theme_$seed',
      prompt: 'Quel thème macro résume le mieux cette actualité ?',
      choices: choices.take(4).toList(),
      correctIndex: choices.take(4).toList().indexOf(category.label),
      kind: NewsQuestionKind.theme,
      explanation:
          'La bonne lecture consiste d’abord à classer la news dans sa vraie famille macro.',
    );
  }

  static NewsComprehensionQuestion _buildEntityQuestion(
    String entity,
    int seed,
  ) {
    final choices = <String>[entity];
    final wrongs = _entityDistractors.where((item) => item != entity).toList();
    _shuffleInPlace(wrongs, seed);
    choices.addAll(wrongs.take(3));
    _shuffleInPlace(choices, seed + 1);
    return NewsComprehensionQuestion(
      id: 'entity_$seed',
      prompt: 'Quel acteur est explicitement au centre de cette news ?',
      choices: choices,
      correctIndex: choices.indexOf(entity),
      kind: NewsQuestionKind.entity,
      explanation:
          'Identifier l’acteur clé évite de mal attribuer l’impact de marché.',
    );
  }

  static NewsComprehensionQuestion _buildCausalQuestion(
    List<String> causalChain,
    String signal,
    int seed,
  ) {
    final correct = causalChain.join(' -> ');
    final options = <String>[
      correct,
      signal == 'positive'
          ? 'hausse de la peur -> fuite vers la qualité -> baisse des indices'
          : 'détente complète -> rallye généralisé -> reprise cyclique',
      'choc isolé -> aucune lecture macro -> statu quo complet',
      'surprise technique -> hausse des volumes -> absence d’impact sectoriel',
    ];
    _shuffleInPlace(options, seed);
    return NewsComprehensionQuestion(
      id: 'causal_$seed',
      prompt: 'Quelle chaîne de causalité est la plus cohérente ?',
      choices: options,
      correctIndex: options.indexOf(correct),
      kind: NewsQuestionKind.causalChain,
      explanation:
          'Le bon réflexe n’est pas de mémoriser la news, mais de relier cause, variable macro et prix de marché.',
    );
  }

  static String _buildDebrief({
    required NewsMacroCategory category,
    required String signal,
    required String regionLabel,
    required List<NewsImpactOption> impactOptions,
  }) {
    final positives = impactOptions
        .where((item) => item.isExpectedTarget)
        .map(
          (item) =>
              '${item.label} ${item.expectedDirection.label.toLowerCase()}',
        )
        .join(', ');
    final tone = signal == 'positive' ? 'plus constructif' : 'plus prudent';
    return 'Lecture $tone sur $regionLabel : le marché regarde d’abord ${category.label.toLowerCase()}, puis price $positives.';
  }

  static NewsWorldRouteNode _buildPropagationRegionNode(
    NewsGameDeckItem sourceItem,
    int seed,
  ) {
    final region = sourceItem.region;
    final positive =
        !_isRiskOffCategory(sourceItem.macroCategory, sourceItem.debrief);
    final options = <NewsImpactOption>[
      _impact(
        'europe_route',
        'Europe',
        NewsImpactKind.region,
        positive ? PredictionDirection.bullish : PredictionDirection.bearish,
        region != 'Europe',
        'L’Europe réagit vite aux chocs globaux de prix, d’énergie et de taux.',
      ),
      _impact(
        'us_route',
        'États-Unis',
        NewsImpactKind.region,
        positive ? PredictionDirection.bullish : PredictionDirection.bearish,
        region != 'États-Unis',
        'Les US absorbent rapidement les chocs macro via les indices et les taux.',
      ),
      _impact(
        'asia_route',
        'Asie',
        NewsImpactKind.region,
        positive ? PredictionDirection.bullish : PredictionDirection.bearish,
        region != 'Asie',
        'L’Asie répercute vite les chocs de demande, change et matières premières.',
      ),
      _impact(
        'em_route',
        'Marchés émergents',
        NewsImpactKind.region,
        positive ? PredictionDirection.bearish : PredictionDirection.bullish,
        sourceItem.macroCategory == NewsMacroCategory.fx ||
            sourceItem.macroCategory == NewsMacroCategory.rates,
        'Les émergents sont sensibles au dollar, aux taux et au risk-off.',
      ),
      _impact(
        'home_route',
        region,
        NewsImpactKind.region,
        PredictionDirection.neutral,
        false,
        'Le but est ici d’identifier le premier relais hors pays source.',
      ),
    ];
    _shuffleInPlace(options, seed);
    return NewsWorldRouteNode(
      id: 'route_region_${sourceItem.articleId}',
      title: 'Premier relais',
      prompt:
          'Hors du pays source, quelle zone encaisse le premier choc de propagation ?',
      impactOptions: options,
      causalChain: <String>[
        sourceItem.region,
        'relecture internationale',
        'rotation des flux',
      ],
      explanation:
          'Après la source, le marché regarde la zone la plus exposée au thème, à la devise ou à l’énergie.',
    );
  }

  static NewsWorldRouteNode _buildSecondWaveNode(
    NewsGameDeckItem sourceItem,
    int seed,
  ) {
    final positive =
        !_isRiskOffCategory(sourceItem.macroCategory, sourceItem.debrief);
    final options = <NewsImpactOption>[
      _impact(
        'global_rates',
        'Taux mondiaux',
        NewsImpactKind.asset,
        positive ? PredictionDirection.bearish : PredictionDirection.bullish,
        sourceItem.macroCategory == NewsMacroCategory.inflation ||
            sourceItem.macroCategory == NewsMacroCategory.centralBanks ||
            sourceItem.macroCategory == NewsMacroCategory.rates,
        'Le deuxième effet de propagation passe souvent par les rendements.',
      ),
      _impact(
        'global_energy',
        'Énergie mondiale',
        NewsImpactKind.asset,
        positive ? PredictionDirection.bearish : PredictionDirection.bullish,
        sourceItem.macroCategory == NewsMacroCategory.geopolitics ||
            sourceItem.macroCategory == NewsMacroCategory.commodities,
        'Les chocs géopolitiques et de matières premières contaminent vite l’énergie.',
      ),
      _impact(
        'global_growth',
        'Actions growth mondiales',
        NewsImpactKind.sector,
        positive ? PredictionDirection.bullish : PredictionDirection.bearish,
        sourceItem.macroCategory == NewsMacroCategory.earnings ||
            sourceItem.macroCategory == NewsMacroCategory.rates ||
            sourceItem.macroCategory == NewsMacroCategory.inflation,
        'Le second round se lit souvent sur la duration et la tech mondiale.',
      ),
      _impact(
        'gold_wave',
        'Or',
        NewsImpactKind.asset,
        positive ? PredictionDirection.bearish : PredictionDirection.bullish,
        sourceItem.macroCategory == NewsMacroCategory.geopolitics,
        'L’or devient souvent le langage global du stress.',
      ),
      _impact(
        'home_consumers',
        'Consommation domestique',
        NewsImpactKind.sector,
        PredictionDirection.neutral,
        false,
        'Trop local pour être la meilleure lecture de la deuxième onde.',
      ),
    ];
    _shuffleInPlace(options, seed);
    return NewsWorldRouteNode(
      id: 'route_asset_${sourceItem.articleId}',
      title: 'Deuxième onde',
      prompt:
          'Quel actif mondial résume le mieux la propagation finale du scénario ?',
      impactOptions: options,
      causalChain: <String>[
        'choc initial',
        'relais régional',
        'prix mondial le plus parlant',
      ],
      explanation:
          'La meilleure lecture finale est l’actif global qui concentre vraiment la propagation du choc.',
    );
  }

  static String? _extractEntity(String title) {
    final matches =
        RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b')
            .allMatches(title)
            .map((match) => match.group(0)?.trim() ?? '')
            .where((value) => value.length >= 4)
            .where((value) => !_themeDistractors.contains(value))
            .toList();
    if (matches.isEmpty) return null;
    return matches.first;
  }

  static bool _isRiskOffCategory(NewsMacroCategory category, String debrief) {
    if (debrief.toLowerCase().contains('plus prudent')) return true;
    return switch (category) {
      NewsMacroCategory.geopolitics => true,
      NewsMacroCategory.commodities => true,
      NewsMacroCategory.inflation => true,
      NewsMacroCategory.centralBanks => true,
      NewsMacroCategory.rates => true,
      _ => false,
    };
  }

  static NewsImpactOption _impact(
    String id,
    String label,
    NewsImpactKind kind,
    PredictionDirection expectedDirection,
    bool isExpectedTarget,
    String explanation,
  ) {
    return NewsImpactOption(
      id: id,
      label: label,
      kind: kind,
      expectedDirection: expectedDirection,
      isExpectedTarget: isExpectedTarget,
      explanation: explanation,
    );
  }

  static bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  static int _seedFrom(String raw, int fallback) {
    if (raw.trim().isEmpty) return fallback;
    return raw.codeUnits.fold<int>(fallback, (sum, value) => sum + value);
  }

  static void _shuffleInPlace<T>(List<T> list, int seed) {
    final random = math.Random(seed);
    for (var index = list.length - 1; index > 0; index--) {
      final swapIndex = random.nextInt(index + 1);
      final current = list[index];
      list[index] = list[swapIndex];
      list[swapIndex] = current;
    }
  }
}

class _RegionInfo {
  final String key;
  final String label;

  const _RegionInfo(this.key, this.label);
}
