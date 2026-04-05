import 'package:flutter/foundation.dart';

import 'news_article.dart';
import '../utils/news_text_sanitizer.dart';

String _sanitizePersistedNewsText(String raw) {
  return sanitizeNewsGameText(raw);
}

enum NewsMacroCategory {
  inflation,
  centralBanks,
  earnings,
  mergers,
  geopolitics,
  commodities,
  fx,
  rates,
  general,
}

extension NewsMacroCategoryX on NewsMacroCategory {
  String get key => switch (this) {
    NewsMacroCategory.inflation => 'inflation',
    NewsMacroCategory.centralBanks => 'central_banks',
    NewsMacroCategory.earnings => 'earnings',
    NewsMacroCategory.mergers => 'mergers',
    NewsMacroCategory.geopolitics => 'geopolitics',
    NewsMacroCategory.commodities => 'commodities',
    NewsMacroCategory.fx => 'fx',
    NewsMacroCategory.rates => 'rates',
    NewsMacroCategory.general => 'general',
  };

  String get label => switch (this) {
    NewsMacroCategory.inflation => 'Inflation',
    NewsMacroCategory.centralBanks => 'Banques centrales',
    NewsMacroCategory.earnings => 'Earnings',
    NewsMacroCategory.mergers => 'M&A',
    NewsMacroCategory.geopolitics => 'Géopolitique',
    NewsMacroCategory.commodities => 'Commodities',
    NewsMacroCategory.fx => 'FX',
    NewsMacroCategory.rates => 'Taux',
    NewsMacroCategory.general => 'Macro',
  };

  static NewsMacroCategory fromKey(String? raw) {
    return NewsMacroCategory.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => NewsMacroCategory.general,
    );
  }
}

enum NewsDifficulty { easy, medium, hard }

extension NewsDifficultyX on NewsDifficulty {
  String get key => switch (this) {
    NewsDifficulty.easy => 'easy',
    NewsDifficulty.medium => 'medium',
    NewsDifficulty.hard => 'hard',
  };

  String get label => switch (this) {
    NewsDifficulty.easy => 'Lisible',
    NewsDifficulty.medium => 'Nuancé',
    NewsDifficulty.hard => 'Avancé',
  };

  static NewsDifficulty fromKey(String? raw) {
    return NewsDifficulty.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => NewsDifficulty.medium,
    );
  }
}

enum NewsImpactKind { asset, sector, region, theme }

extension NewsImpactKindX on NewsImpactKind {
  String get key => switch (this) {
    NewsImpactKind.asset => 'asset',
    NewsImpactKind.sector => 'sector',
    NewsImpactKind.region => 'region',
    NewsImpactKind.theme => 'theme',
  };

  static NewsImpactKind fromKey(String? raw) {
    return NewsImpactKind.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => NewsImpactKind.asset,
    );
  }
}

enum PredictionDirection { bullish, bearish, neutral }

extension PredictionDirectionX on PredictionDirection {
  String get key => switch (this) {
    PredictionDirection.bullish => 'bullish',
    PredictionDirection.bearish => 'bearish',
    PredictionDirection.neutral => 'neutral',
  };

  String get label => switch (this) {
    PredictionDirection.bullish => 'Bullish',
    PredictionDirection.bearish => 'Bearish',
    PredictionDirection.neutral => 'Neutre',
  };

  static PredictionDirection fromKey(String? raw) {
    return PredictionDirection.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => PredictionDirection.neutral,
    );
  }
}

enum NewsConfidenceLevel { prudente, assumee, forte }

extension NewsConfidenceLevelX on NewsConfidenceLevel {
  String get key => switch (this) {
    NewsConfidenceLevel.prudente => 'prudente',
    NewsConfidenceLevel.assumee => 'assumee',
    NewsConfidenceLevel.forte => 'forte',
  };

  String get label => switch (this) {
    NewsConfidenceLevel.prudente => 'Prudente',
    NewsConfidenceLevel.assumee => 'Assumée',
    NewsConfidenceLevel.forte => 'Forte',
  };

  double get gainMultiplier => switch (this) {
    NewsConfidenceLevel.prudente => 1.0,
    NewsConfidenceLevel.assumee => 1.35,
    NewsConfidenceLevel.forte => 1.8,
  };

  double get penaltyMultiplier => switch (this) {
    NewsConfidenceLevel.prudente => 0.25,
    NewsConfidenceLevel.assumee => 0.6,
    NewsConfidenceLevel.forte => 1.0,
  };

  static NewsConfidenceLevel fromKey(String? raw) {
    return NewsConfidenceLevel.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => NewsConfidenceLevel.prudente,
    );
  }
}

enum NewsGameSubMode { sprint, analyse, worldRoute }

extension NewsGameSubModeX on NewsGameSubMode {
  String get key => switch (this) {
    NewsGameSubMode.sprint => 'sprint',
    NewsGameSubMode.analyse => 'analyse',
    NewsGameSubMode.worldRoute => 'world_route',
  };

  String get label => switch (this) {
    NewsGameSubMode.sprint => 'Sprint',
    NewsGameSubMode.analyse => 'Analyse',
    NewsGameSubMode.worldRoute => 'Route',
  };

  static NewsGameSubMode fromKey(String? raw) {
    return NewsGameSubMode.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => NewsGameSubMode.analyse,
    );
  }
}

enum NewsQuestionKind { theme, entity, causalChain }

extension NewsQuestionKindX on NewsQuestionKind {
  String get key => switch (this) {
    NewsQuestionKind.theme => 'theme',
    NewsQuestionKind.entity => 'entity',
    NewsQuestionKind.causalChain => 'causal_chain',
  };

  static NewsQuestionKind fromKey(String? raw) {
    return NewsQuestionKind.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => NewsQuestionKind.theme,
    );
  }
}

class NewsImpactOption {
  final String id;
  final String label;
  final NewsImpactKind kind;
  final PredictionDirection expectedDirection;
  final bool isExpectedTarget;
  final String explanation;

  const NewsImpactOption({
    required this.id,
    required this.label,
    required this.kind,
    required this.expectedDirection,
    required this.isExpectedTarget,
    required this.explanation,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'label': label,
    'kind': kind.key,
    'expectedDirection': expectedDirection.key,
    'isExpectedTarget': isExpectedTarget,
    'explanation': explanation,
  };

  factory NewsImpactOption.fromMap(Map<String, dynamic> map) {
    return NewsImpactOption(
      id: (map['id'] as String?) ?? '',
      label: _sanitizePersistedNewsText((map['label'] as String?) ?? ''),
      kind: NewsImpactKindX.fromKey(map['kind'] as String?),
      expectedDirection: PredictionDirectionX.fromKey(
        map['expectedDirection'] as String?,
      ),
      isExpectedTarget: (map['isExpectedTarget'] as bool?) ?? false,
      explanation: _sanitizePersistedNewsText(
        (map['explanation'] as String?) ?? '',
      ),
    );
  }
}

class NewsComprehensionQuestion {
  final String id;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final NewsQuestionKind kind;
  final String explanation;

  const NewsComprehensionQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.kind,
    required this.explanation,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'prompt': prompt,
    'choices': choices,
    'correctIndex': correctIndex,
    'kind': kind.key,
    'explanation': explanation,
  };

  factory NewsComprehensionQuestion.fromMap(Map<String, dynamic> map) {
    return NewsComprehensionQuestion(
      id: (map['id'] as String?) ?? '',
      prompt: _sanitizePersistedNewsText((map['prompt'] as String?) ?? ''),
      choices:
          List<String>.from(
            (map['choices'] as List<dynamic>?) ?? const [],
          ).map(_sanitizePersistedNewsText).toList(),
      correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
      kind: NewsQuestionKindX.fromKey(map['kind'] as String?),
      explanation: _sanitizePersistedNewsText(
        (map['explanation'] as String?) ?? '',
      ),
    );
  }
}

class NewsImpactPrediction {
  final String targetId;
  final PredictionDirection direction;
  final NewsConfidenceLevel confidenceLevel;

  const NewsImpactPrediction({
    required this.targetId,
    required this.direction,
    required this.confidenceLevel,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'targetId': targetId,
    'direction': direction.key,
    'confidenceLevel': confidenceLevel.key,
  };

  factory NewsImpactPrediction.fromMap(Map<String, dynamic> map) {
    return NewsImpactPrediction(
      targetId: (map['targetId'] as String?) ?? '',
      direction: PredictionDirectionX.fromKey(map['direction'] as String?),
      confidenceLevel: NewsConfidenceLevelX.fromKey(
        map['confidenceLevel'] as String?,
      ),
    );
  }
}

class NewsGameDeckItem {
  final String articleId;
  final NewsArticle article;
  final String displayTitle;
  final String displaySnippet;
  final String region;
  final String regionKey;
  final NewsMacroCategory macroCategory;
  final NewsDifficulty difficulty;
  final int qualityScore;
  final List<NewsImpactOption> impactOptions;
  final List<String> causalChain;
  final List<NewsComprehensionQuestion> comprehensionQuestions;
  final String debrief;
  final int rewardPotential;

  const NewsGameDeckItem({
    required this.articleId,
    required this.article,
    required this.displayTitle,
    required this.displaySnippet,
    required this.region,
    required this.regionKey,
    required this.macroCategory,
    required this.difficulty,
    required this.qualityScore,
    required this.impactOptions,
    required this.causalChain,
    required this.comprehensionQuestions,
    required this.debrief,
    required this.rewardPotential,
  });

  bool get isDeckReady =>
      displayTitle.trim().isNotEmpty &&
      impactOptions.isNotEmpty &&
      comprehensionQuestions.isNotEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'articleId': articleId,
    'article': article.toFirestore(),
    'displayTitle': displayTitle,
    'displaySnippet': displaySnippet,
    'region': region,
    'regionKey': regionKey,
    'macroCategory': macroCategory.key,
    'difficulty': difficulty.key,
    'qualityScore': qualityScore,
    'impactOptions': impactOptions.map((item) => item.toMap()).toList(),
    'causalChain': causalChain,
    'comprehensionQuestions':
        comprehensionQuestions.map((item) => item.toMap()).toList(),
    'debrief': debrief,
    'rewardPotential': rewardPotential,
  };

  factory NewsGameDeckItem.fromMap(Map<String, dynamic> map) {
    return NewsGameDeckItem(
      articleId: (map['articleId'] as String?) ?? '',
      article: NewsArticle.fromFirestore(
        Map<String, dynamic>.from(
          (map['article'] as Map<dynamic, dynamic>?) ?? const {},
        ),
      ),
      displayTitle: _sanitizePersistedNewsText(
        (map['displayTitle'] as String?) ?? '',
      ),
      displaySnippet: _sanitizePersistedNewsText(
        (map['displaySnippet'] as String?) ?? '',
      ),
      region: (map['region'] as String?) ?? 'Monde',
      regionKey: (map['regionKey'] as String?) ?? 'world',
      macroCategory: NewsMacroCategoryX.fromKey(
        map['macroCategory'] as String?,
      ),
      difficulty: NewsDifficultyX.fromKey(map['difficulty'] as String?),
      qualityScore: (map['qualityScore'] as num?)?.toInt() ?? 0,
      impactOptions:
          ((map['impactOptions'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) =>
                    NewsImpactOption.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
      causalChain:
          ((map['causalChain'] as List<dynamic>?) ?? const [])
              .map((item) => _sanitizePersistedNewsText(item.toString()))
              .where((item) => item.trim().isNotEmpty)
              .toList(),
      comprehensionQuestions:
          ((map['comprehensionQuestions'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => NewsComprehensionQuestion.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      debrief: _sanitizePersistedNewsText((map['debrief'] as String?) ?? ''),
      rewardPotential: (map['rewardPotential'] as num?)?.toInt() ?? 0,
    );
  }
}

class NewsWorldRouteNode {
  final String id;
  final String title;
  final String prompt;
  final List<NewsImpactOption> impactOptions;
  final List<String> causalChain;
  final String explanation;

  const NewsWorldRouteNode({
    required this.id,
    required this.title,
    required this.prompt,
    required this.impactOptions,
    required this.causalChain,
    required this.explanation,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'prompt': prompt,
    'impactOptions': impactOptions.map((item) => item.toMap()).toList(),
    'causalChain': causalChain,
    'explanation': explanation,
  };

  factory NewsWorldRouteNode.fromMap(Map<String, dynamic> map) {
    return NewsWorldRouteNode(
      id: (map['id'] as String?) ?? '',
      title: _sanitizePersistedNewsText((map['title'] as String?) ?? ''),
      prompt: _sanitizePersistedNewsText((map['prompt'] as String?) ?? ''),
      impactOptions:
          ((map['impactOptions'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) =>
                    NewsImpactOption.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
      causalChain:
          ((map['causalChain'] as List<dynamic>?) ?? const [])
              .map((item) => item.toString())
              .toList(),
      explanation: _sanitizePersistedNewsText(
        (map['explanation'] as String?) ?? '',
      ),
    );
  }
}

class NewsWorldRoute {
  final String sourceCountryIso2;
  final String sourceCountryNameFr;
  final NewsGameDeckItem sourceItem;
  final List<NewsWorldRouteNode> routeNodes;

  const NewsWorldRoute({
    required this.sourceCountryIso2,
    required this.sourceCountryNameFr,
    required this.sourceItem,
    required this.routeNodes,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'sourceCountryIso2': sourceCountryIso2,
    'sourceCountryNameFr': sourceCountryNameFr,
    'sourceItem': sourceItem.toMap(),
    'routeNodes': routeNodes.map((item) => item.toMap()).toList(),
  };

  factory NewsWorldRoute.fromMap(Map<String, dynamic> map) {
    return NewsWorldRoute(
      sourceCountryIso2: (map['sourceCountryIso2'] as String?) ?? '',
      sourceCountryNameFr: (map['sourceCountryNameFr'] as String?) ?? '',
      sourceItem: NewsGameDeckItem.fromMap(
        Map<String, dynamic>.from(
          (map['sourceItem'] as Map<dynamic, dynamic>?) ?? const {},
        ),
      ),
      routeNodes:
          ((map['routeNodes'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) =>
                    NewsWorldRouteNode.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
    );
  }
}

class NewsRoundResult {
  final String nodeId;
  final List<NewsImpactPrediction> predictions;
  final List<int?> comprehensionAnswers;
  final int marketScore;
  final int comprehensionScore;
  final int comboAfterRound;
  final bool marketPerfect;
  final String debrief;
  final String themeKey;

  const NewsRoundResult({
    required this.nodeId,
    required this.predictions,
    required this.comprehensionAnswers,
    required this.marketScore,
    required this.comprehensionScore,
    required this.comboAfterRound,
    required this.marketPerfect,
    required this.debrief,
    required this.themeKey,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'nodeId': nodeId,
    'predictions': predictions.map((item) => item.toMap()).toList(),
    'comprehensionAnswers': comprehensionAnswers,
    'marketScore': marketScore,
    'comprehensionScore': comprehensionScore,
    'comboAfterRound': comboAfterRound,
    'marketPerfect': marketPerfect,
    'debrief': debrief,
    'themeKey': themeKey,
  };

  factory NewsRoundResult.fromMap(Map<String, dynamic> map) {
    return NewsRoundResult(
      nodeId: (map['nodeId'] as String?) ?? '',
      predictions:
          ((map['predictions'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => NewsImpactPrediction.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      comprehensionAnswers:
          ((map['comprehensionAnswers'] as List<dynamic>?) ?? const [])
              .map((item) => item is num ? item.toInt() : null)
              .toList(),
      marketScore: (map['marketScore'] as num?)?.toInt() ?? 0,
      comprehensionScore: (map['comprehensionScore'] as num?)?.toInt() ?? 0,
      comboAfterRound: (map['comboAfterRound'] as num?)?.toInt() ?? 0,
      marketPerfect: (map['marketPerfect'] as bool?) ?? false,
      debrief: (map['debrief'] as String?) ?? '',
      themeKey: (map['themeKey'] as String?) ?? NewsMacroCategory.general.key,
    );
  }
}

class NewsSessionScoreBreakdown {
  final int comprehensionScore;
  final int marketScore;
  final int comboBonus;
  final int finalScore;
  final double accuracy;
  final int maxCombo;
  final Map<String, int> themeScores;

  const NewsSessionScoreBreakdown({
    required this.comprehensionScore,
    required this.marketScore,
    required this.comboBonus,
    required this.finalScore,
    required this.accuracy,
    required this.maxCombo,
    required this.themeScores,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'comprehensionScore': comprehensionScore,
    'marketScore': marketScore,
    'comboBonus': comboBonus,
    'finalScore': finalScore,
    'accuracy': accuracy,
    'maxCombo': maxCombo,
    'themeScores': themeScores,
  };

  factory NewsSessionScoreBreakdown.fromMap(Map<String, dynamic> map) {
    return NewsSessionScoreBreakdown(
      comprehensionScore: (map['comprehensionScore'] as num?)?.toInt() ?? 0,
      marketScore: (map['marketScore'] as num?)?.toInt() ?? 0,
      comboBonus: (map['comboBonus'] as num?)?.toInt() ?? 0,
      finalScore: (map['finalScore'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      maxCombo: (map['maxCombo'] as num?)?.toInt() ?? 0,
      themeScores: Map<String, int>.from(
        ((map['themeScores'] as Map<dynamic, dynamic>?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      ),
    );
  }
}

class NewsGameDeckResult {
  final List<NewsGameDeckItem> deck;
  final bool fetchFailed;
  final bool sprintAvailable;
  final String sourceType;
  final String qualitySummary;
  final List<String> queriesTried;

  const NewsGameDeckResult({
    required this.deck,
    required this.fetchFailed,
    required this.sprintAvailable,
    required this.sourceType,
    required this.qualitySummary,
    required this.queriesTried,
  });

  bool get hasPlayableDeck => deck.isNotEmpty;
}

class NewsSessionProfile {
  final Map<String, double> themeAccuracy;
  final Map<String, double> countryAccuracy;
  final Map<String, double> assetAccuracy;
  final double weeklyAverageAccuracy;
  final double weeklyAverageCombined;
  final int bestCombo;
  final int currentStreak;
  final int sessionsCount;

  const NewsSessionProfile({
    required this.themeAccuracy,
    required this.countryAccuracy,
    required this.assetAccuracy,
    required this.weeklyAverageAccuracy,
    required this.weeklyAverageCombined,
    required this.bestCombo,
    required this.currentStreak,
    required this.sessionsCount,
  });

  static const empty = NewsSessionProfile(
    themeAccuracy: <String, double>{},
    countryAccuracy: <String, double>{},
    assetAccuracy: <String, double>{},
    weeklyAverageAccuracy: 0,
    weeklyAverageCombined: 0,
    bestCombo: 0,
    currentStreak: 0,
    sessionsCount: 0,
  );

  factory NewsSessionProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return NewsSessionProfile.empty;
    Map<String, double> readDoubleMap(String key) {
      final raw = map[key];
      if (raw is! Map) return const <String, double>{};
      return raw.map<String, double>(
        (dynamic mapKey, dynamic value) =>
            MapEntry(mapKey.toString(), value is num ? value.toDouble() : 0),
      );
    }

    return NewsSessionProfile(
      themeAccuracy: readDoubleMap('themeStats'),
      countryAccuracy: readDoubleMap('countryStats'),
      assetAccuracy: readDoubleMap('assetStats'),
      weeklyAverageAccuracy:
          (map['weeklyAverageAccuracy'] as num?)?.toDouble() ?? 0,
      weeklyAverageCombined:
          (map['weeklyAverageCombined'] as num?)?.toDouble() ?? 0,
      bestCombo: (map['bestCombo'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      sessionsCount: (map['sessionsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

@visibleForTesting
double newsConfidenceGainMultiplier(NewsConfidenceLevel level) =>
    level.gainMultiplier;

@visibleForTesting
double newsConfidencePenaltyMultiplier(NewsConfidenceLevel level) =>
    level.penaltyMultiplier;
