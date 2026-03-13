import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

enum ScenarioThesis { riskOn, defensive, contrarian }

extension ScenarioThesisX on ScenarioThesis {
  String get key => switch (this) {
    ScenarioThesis.riskOn => 'risk_on',
    ScenarioThesis.defensive => 'defensif',
    ScenarioThesis.contrarian => 'contrarian',
  };

  String get label => switch (this) {
    ScenarioThesis.riskOn => 'Risk-on',
    ScenarioThesis.defensive => 'Défensif',
    ScenarioThesis.contrarian => 'Contrarian',
  };

  String get description => switch (this) {
    ScenarioThesis.riskOn =>
      'Tu assumes le momentum et tu acceptes davantage de volatilité.',
    ScenarioThesis.defensive =>
      'Tu protèges le capital et priorises la survie au bon timing.',
    ScenarioThesis.contrarian =>
      'Tu cherches les sur-réactions du marché et les points de retournement.',
  };

  static ScenarioThesis fromKey(String? raw) {
    return ScenarioThesis.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => ScenarioThesis.defensive,
    );
  }
}

enum ScenarioDecisionType { wait, hedge, cut, rotate, reinforce }

extension ScenarioDecisionTypeX on ScenarioDecisionType {
  String get key => switch (this) {
    ScenarioDecisionType.wait => 'wait',
    ScenarioDecisionType.hedge => 'hedge',
    ScenarioDecisionType.cut => 'cut',
    ScenarioDecisionType.rotate => 'rotate',
    ScenarioDecisionType.reinforce => 'reinforce',
  };

  String get label => switch (this) {
    ScenarioDecisionType.wait => 'Attendre',
    ScenarioDecisionType.hedge => 'Couvrir',
    ScenarioDecisionType.cut => 'Couper',
    ScenarioDecisionType.rotate => 'Arbitrer',
    ScenarioDecisionType.reinforce => 'Renforcer',
  };

  static ScenarioDecisionType fromKey(String? raw) {
    return ScenarioDecisionType.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => ScenarioDecisionType.wait,
    );
  }
}

enum ScenarioEventType {
  cpi,
  fed,
  earnings,
  guidanceCut,
  geopolitical,
  sectorRotation,
  commodityShock,
  regulation,
  liquidityStress,
}

extension ScenarioEventTypeX on ScenarioEventType {
  String get key => switch (this) {
    ScenarioEventType.cpi => 'cpi',
    ScenarioEventType.fed => 'fed',
    ScenarioEventType.earnings => 'earnings',
    ScenarioEventType.guidanceCut => 'guidance_cut',
    ScenarioEventType.geopolitical => 'geopolitical',
    ScenarioEventType.sectorRotation => 'sector_rotation',
    ScenarioEventType.commodityShock => 'commodity_shock',
    ScenarioEventType.regulation => 'regulation',
    ScenarioEventType.liquidityStress => 'liquidity_stress',
  };

  String get label => switch (this) {
    ScenarioEventType.cpi => 'CPI',
    ScenarioEventType.fed => 'Fed',
    ScenarioEventType.earnings => 'Earnings',
    ScenarioEventType.guidanceCut => 'Guidance cut',
    ScenarioEventType.geopolitical => 'Géopolitique',
    ScenarioEventType.sectorRotation => 'Rotation sectorielle',
    ScenarioEventType.commodityShock => 'Choc commodity',
    ScenarioEventType.regulation => 'Régulation',
    ScenarioEventType.liquidityStress => 'Stress de liquidité',
  };

  static ScenarioEventType fromKey(String? raw) {
    return ScenarioEventType.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => ScenarioEventType.sectorRotation,
    );
  }
}

enum ScenarioMedal { none, bronze, silver, gold }

extension ScenarioMedalX on ScenarioMedal {
  String get key => switch (this) {
    ScenarioMedal.none => 'none',
    ScenarioMedal.bronze => 'bronze',
    ScenarioMedal.silver => 'silver',
    ScenarioMedal.gold => 'gold',
  };

  String get label => switch (this) {
    ScenarioMedal.none => 'Aucune',
    ScenarioMedal.bronze => 'Bronze',
    ScenarioMedal.silver => 'Silver',
    ScenarioMedal.gold => 'Gold',
  };

  int get stars => switch (this) {
    ScenarioMedal.none => 0,
    ScenarioMedal.bronze => 1,
    ScenarioMedal.silver => 2,
    ScenarioMedal.gold => 3,
  };

  static ScenarioMedal fromKey(String? raw) {
    return ScenarioMedal.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => ScenarioMedal.none,
    );
  }
}

class ScenarioChapter {
  const ScenarioChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.requiredLevel,
    required this.requiredStarsFromPrevious,
    required this.scenarioIds,
  });

  final String id;
  final String title;
  final String subtitle;
  final int requiredLevel;
  final int requiredStarsFromPrevious;
  final List<String> scenarioIds;
}

class ScenarioMutatorSet {
  const ScenarioMutatorSet({
    this.expertMode = false,
    this.volatilityBoost = false,
    this.highFees = false,
    this.delayedInfo = false,
    this.contradictoryNews = false,
  });

  final bool expertMode;
  final bool volatilityBoost;
  final bool highFees;
  final bool delayedInfo;
  final bool contradictoryNews;

  ScenarioMutatorSet copyWith({
    bool? expertMode,
    bool? volatilityBoost,
    bool? highFees,
    bool? delayedInfo,
    bool? contradictoryNews,
  }) {
    return ScenarioMutatorSet(
      expertMode: expertMode ?? this.expertMode,
      volatilityBoost: volatilityBoost ?? this.volatilityBoost,
      highFees: highFees ?? this.highFees,
      delayedInfo: delayedInfo ?? this.delayedInfo,
      contradictoryNews: contradictoryNews ?? this.contradictoryNews,
    );
  }

  bool get anyEnabled =>
      expertMode ||
      volatilityBoost ||
      highFees ||
      delayedInfo ||
      contradictoryNews;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'expertMode': expertMode,
    'volatilityBoost': volatilityBoost,
    'highFees': highFees,
    'delayedInfo': delayedInfo,
    'contradictoryNews': contradictoryNews,
  };

  factory ScenarioMutatorSet.fromMap(Map<String, dynamic>? map) {
    final raw = map ?? const <String, dynamic>{};
    return ScenarioMutatorSet(
      expertMode: raw['expertMode'] as bool? ?? false,
      volatilityBoost: raw['volatilityBoost'] as bool? ?? false,
      highFees: raw['highFees'] as bool? ?? false,
      delayedInfo: raw['delayedInfo'] as bool? ?? false,
      contradictoryNews: raw['contradictoryNews'] as bool? ?? false,
    );
  }
}

class ScenarioDecisionOption {
  const ScenarioDecisionOption({
    required this.id,
    required this.type,
    required this.label,
    required this.description,
    required this.tradeCost,
    required this.infoCost,
    required this.convictionCost,
    required this.branchTag,
    required this.timingWindow,
  });

  final String id;
  final ScenarioDecisionType type;
  final String label;
  final String description;
  final int tradeCost;
  final int infoCost;
  final int convictionCost;
  final String branchTag;
  final String timingWindow;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'type': type.key,
    'label': label,
    'description': description,
    'tradeCost': tradeCost,
    'infoCost': infoCost,
    'convictionCost': convictionCost,
    'branchTag': branchTag,
    'timingWindow': timingWindow,
  };

  factory ScenarioDecisionOption.fromMap(Map<String, dynamic> map) {
    return ScenarioDecisionOption(
      id: (map['id'] as String?) ?? '',
      type: ScenarioDecisionTypeX.fromKey(map['type'] as String?),
      label: (map['label'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      tradeCost: (map['tradeCost'] as num?)?.toInt() ?? 0,
      infoCost: (map['infoCost'] as num?)?.toInt() ?? 0,
      convictionCost: (map['convictionCost'] as num?)?.toInt() ?? 0,
      branchTag: (map['branchTag'] as String?) ?? '',
      timingWindow: (map['timingWindow'] as String?) ?? '',
    );
  }
}

class ScenarioJustificationOption {
  const ScenarioJustificationOption({
    required this.id,
    required this.label,
    required this.thesisTags,
    required this.scoreTag,
  });

  final String id;
  final String label;
  final List<String> thesisTags;
  final String scoreTag;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'label': label,
    'thesisTags': thesisTags,
    'scoreTag': scoreTag,
  };

  factory ScenarioJustificationOption.fromMap(Map<String, dynamic> map) {
    return ScenarioJustificationOption(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      thesisTags:
          (map['thesisTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(),
      scoreTag: (map['scoreTag'] as String?) ?? '',
    );
  }
}

class ScenarioAct {
  const ScenarioAct({
    required this.id,
    required this.stepIndex,
    required this.eventType,
    required this.title,
    required this.narrative,
    required this.marketMood,
    required this.riskTone,
    required this.extraInfo,
    required this.decisionPrompt,
    required this.teachingPoint,
    required this.decisionOptions,
    required this.justificationOptions,
    required this.preferredDecisionTypes,
    required this.supportingScoreTags,
  });

  final String id;
  final int stepIndex;
  final ScenarioEventType eventType;
  final String title;
  final String narrative;
  final String marketMood;
  final String riskTone;
  final String extraInfo;
  final String decisionPrompt;
  final String teachingPoint;
  final List<ScenarioDecisionOption> decisionOptions;
  final List<ScenarioJustificationOption> justificationOptions;
  final List<ScenarioDecisionType> preferredDecisionTypes;
  final List<String> supportingScoreTags;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'stepIndex': stepIndex,
    'eventType': eventType.key,
    'title': title,
    'narrative': narrative,
    'marketMood': marketMood,
    'riskTone': riskTone,
    'extraInfo': extraInfo,
    'decisionPrompt': decisionPrompt,
    'teachingPoint': teachingPoint,
    'decisionOptions': decisionOptions.map((value) => value.toMap()).toList(),
    'justificationOptions':
        justificationOptions.map((value) => value.toMap()).toList(),
    'preferredDecisionTypes':
        preferredDecisionTypes.map((value) => value.key).toList(),
    'supportingScoreTags': supportingScoreTags,
  };

  factory ScenarioAct.fromMap(Map<String, dynamic> map) {
    return ScenarioAct(
      id: (map['id'] as String?) ?? '',
      stepIndex: (map['stepIndex'] as num?)?.toInt() ?? 0,
      eventType: ScenarioEventTypeX.fromKey(map['eventType'] as String?),
      title: (map['title'] as String?) ?? '',
      narrative: (map['narrative'] as String?) ?? '',
      marketMood: (map['marketMood'] as String?) ?? '',
      riskTone: (map['riskTone'] as String?) ?? '',
      extraInfo: (map['extraInfo'] as String?) ?? '',
      decisionPrompt: (map['decisionPrompt'] as String?) ?? '',
      teachingPoint: (map['teachingPoint'] as String?) ?? '',
      decisionOptions:
          (map['decisionOptions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ScenarioDecisionOption.fromMap)
              .toList(),
      justificationOptions:
          (map['justificationOptions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ScenarioJustificationOption.fromMap)
              .toList(),
      preferredDecisionTypes:
          (map['preferredDecisionTypes'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => ScenarioDecisionTypeX.fromKey(value.toString()))
              .toList(),
      supportingScoreTags:
          (map['supportingScoreTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(),
    );
  }
}

class ScenarioInitialPlan {
  const ScenarioInitialPlan({
    required this.id,
    required this.label,
    required this.description,
    required this.weights,
  });

  final String id;
  final String label;
  final String description;
  final Map<String, double> weights;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'label': label,
    'description': description,
    'weights': weights,
  };

  factory ScenarioInitialPlan.fromMap(Map<String, dynamic> map) {
    return ScenarioInitialPlan(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      weights: (map['weights'] as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .map((key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0)),
    );
  }
}

class SimulationAsset {
  const SimulationAsset({
    required this.id,
    required this.label,
    required this.prices,
    required this.role,
    required this.tags,
  });

  final String id;
  final String label;
  final List<double> prices;
  final String role;
  final List<String> tags;

  bool get isCash => tags.contains('cash');

  factory SimulationAsset.fromJson(Map<String, dynamic> json) {
    final assetId = (json['id'] as String?) ?? '';
    final label = (json['label'] as String?) ?? '';
    final role = (json['role'] as String?) ?? '';
    final rawTags =
        (json['tags'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList();
    return SimulationAsset(
      id: assetId,
      label: label,
      prices:
          (json['prices'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => (value as num?)?.toDouble() ?? 0)
              .toList(),
      role: role,
      tags:
          rawTags.isNotEmpty ? rawTags : _inferAssetTags(assetId, label, role),
    );
  }
}

class SimulationConfig {
  const SimulationConfig({
    required this.headline,
    required this.periodLabel,
    required this.durationLabel,
    required this.stepLabel,
    required this.initialCash,
    required this.assets,
    required this.cues,
    required this.suggestedAllocation,
    required this.playbackMs,
  });

  final String headline;
  final String periodLabel;
  final String durationLabel;
  final String stepLabel;
  final double initialCash;
  final List<SimulationAsset> assets;
  final List<String> cues;
  final Map<String, double> suggestedAllocation;
  final int playbackMs;

  int get timelineLength => assets.isEmpty ? 1 : assets.first.prices.length;

  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      headline: (json['headline'] as String?) ?? '',
      periodLabel: (json['periodLabel'] as String?) ?? '',
      durationLabel: (json['durationLabel'] as String?) ?? '',
      stepLabel: (json['stepLabel'] as String?) ?? '',
      initialCash: (json['initialCash'] as num?)?.toDouble() ?? 0,
      assets:
          (json['assets'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(SimulationAsset.fromJson)
              .toList(),
      cues:
          (json['cues'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(),
      suggestedAllocation: (json['suggestedAllocation']
                  as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .map((key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0)),
      playbackMs: (json['playbackMs'] as num?)?.toInt() ?? 850,
    );
  }
}

class PortfolioScenario {
  const PortfolioScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.focus,
    required this.risk,
    required this.stageId,
    required this.rewardXp,
    required this.prompts,
    required this.config,
    required this.chapterId,
    required this.requiredLevel,
    required this.benchmarkAssetId,
    required this.initialPlans,
    required this.acts,
    required this.mutatorAvailability,
  });

  final String id;
  final String title;
  final String description;
  final String focus;
  final String risk;
  final String stageId;
  final int rewardXp;
  final List<String> prompts;
  final SimulationConfig config;
  final String chapterId;
  final int requiredLevel;
  final String benchmarkAssetId;
  final List<ScenarioInitialPlan> initialPlans;
  final List<ScenarioAct> acts;
  final ScenarioMutatorSet mutatorAvailability;

  factory PortfolioScenario.fromJson(Map<String, dynamic> json) {
    final config = SimulationConfig.fromJson(
      (json['config'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
    );
    final id = (json['id'] as String?) ?? '';
    final chapterId = (json['chapterId'] as String?) ?? _chapterForScenario(id);
    final requiredLevel =
        (json['requiredLevel'] as num?)?.toInt() ??
        _requiredLevelForScenario(id, chapterId);
    final benchmarkAssetId =
        (json['benchmarkAssetId'] as String?) ??
        _benchmarkAssetForScenario(config.assets);
    final initialPlans =
        (json['initialPlans'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ScenarioInitialPlan.fromMap)
            .toList();
    final acts =
        (json['acts'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ScenarioAct.fromMap)
            .toList();

    return PortfolioScenario(
      id: id,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      focus: (json['focus'] as String?) ?? '',
      risk: (json['risk'] as String?) ?? '',
      stageId: (json['stageId'] as String?) ?? 'intuition',
      rewardXp: (json['rewardXp'] as num?)?.toInt() ?? 10,
      prompts:
          (json['prompts'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(),
      config: config,
      chapterId: chapterId,
      requiredLevel: requiredLevel,
      benchmarkAssetId: benchmarkAssetId,
      initialPlans:
          initialPlans.isNotEmpty
              ? initialPlans
              : _defaultInitialPlans(config.assets, config.suggestedAllocation),
      acts: acts.isNotEmpty ? acts : _defaultActsForScenario(json, config),
      mutatorAvailability: ScenarioMutatorSet.fromMap(
        json['mutatorAvailability'] as Map<String, dynamic>?,
      ),
    );
  }

  static Future<List<PortfolioScenario>> loadScenarios() async {
    final response = await rootBundle.loadString('assets/scenario.json');
    final List<dynamic> data = json.decode(response) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(PortfolioScenario.fromJson)
        .toList();
  }
}

class ScenarioResourceState {
  const ScenarioResourceState({
    required this.tradeCredits,
    required this.infoCredits,
    required this.convictionBudget,
  });

  final int tradeCredits;
  final int infoCredits;
  final int convictionBudget;

  ScenarioResourceState copyWith({
    int? tradeCredits,
    int? infoCredits,
    int? convictionBudget,
  }) {
    return ScenarioResourceState(
      tradeCredits: tradeCredits ?? this.tradeCredits,
      infoCredits: infoCredits ?? this.infoCredits,
      convictionBudget: convictionBudget ?? this.convictionBudget,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'tradeCredits': tradeCredits,
    'infoCredits': infoCredits,
    'convictionBudget': convictionBudget,
  };

  factory ScenarioResourceState.fromMap(Map<String, dynamic> map) {
    return ScenarioResourceState(
      tradeCredits: (map['tradeCredits'] as num?)?.toInt() ?? 0,
      infoCredits: (map['infoCredits'] as num?)?.toInt() ?? 0,
      convictionBudget: (map['convictionBudget'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScenarioDecisionJournalEntry {
  const ScenarioDecisionJournalEntry({
    required this.actId,
    required this.decisionType,
    required this.decisionLabel,
    required this.justificationId,
    required this.justificationLabel,
    required this.branchTag,
    required this.revealedInfo,
    required this.allocationAfterDecision,
    required this.tradeCost,
    required this.convictionCost,
  });

  final String actId;
  final ScenarioDecisionType decisionType;
  final String decisionLabel;
  final String justificationId;
  final String justificationLabel;
  final String branchTag;
  final bool revealedInfo;
  final Map<String, double> allocationAfterDecision;
  final int tradeCost;
  final int convictionCost;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'actId': actId,
    'decisionType': decisionType.key,
    'decisionLabel': decisionLabel,
    'justificationId': justificationId,
    'justificationLabel': justificationLabel,
    'branchTag': branchTag,
    'revealedInfo': revealedInfo,
    'allocationAfterDecision': allocationAfterDecision,
    'tradeCost': tradeCost,
    'convictionCost': convictionCost,
  };
}

class ScenarioRunState {
  const ScenarioRunState({
    required this.stakeCoins,
    required this.thesisId,
    required this.initialPlanId,
    required this.resources,
    required this.currentAllocation,
    required this.currentStep,
    required this.branchPath,
    required this.decisionJournal,
  });

  final int stakeCoins;
  final String thesisId;
  final String initialPlanId;
  final ScenarioResourceState resources;
  final Map<String, double> currentAllocation;
  final int currentStep;
  final List<String> branchPath;
  final List<ScenarioDecisionJournalEntry> decisionJournal;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'stakeCoins': stakeCoins,
    'thesisId': thesisId,
    'initialPlanId': initialPlanId,
    'resources': resources.toMap(),
    'currentAllocation': currentAllocation,
    'currentStep': currentStep,
    'branchPath': branchPath,
    'decisionJournal': decisionJournal.map((value) => value.toMap()).toList(),
  };
}

class ScenarioScoreBreakdown {
  const ScenarioScoreBreakdown({
    required this.performance,
    required this.drawdown,
    required this.coherence,
    required this.riskManagement,
    required this.timing,
    required this.finalScore,
    required this.stars,
    required this.medal,
  });

  final int performance;
  final int drawdown;
  final int coherence;
  final int riskManagement;
  final int timing;
  final int finalScore;
  final int stars;
  final ScenarioMedal medal;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'performance': performance,
    'drawdown': drawdown,
    'coherence': coherence,
    'riskManagement': riskManagement,
    'timing': timing,
    'finalScore': finalScore,
    'stars': stars,
    'medal': medal.key,
  };

  factory ScenarioScoreBreakdown.fromMap(Map<String, dynamic> map) {
    return ScenarioScoreBreakdown(
      performance: (map['performance'] as num?)?.toInt() ?? 0,
      drawdown: (map['drawdown'] as num?)?.toInt() ?? 0,
      coherence: (map['coherence'] as num?)?.toInt() ?? 0,
      riskManagement: (map['riskManagement'] as num?)?.toInt() ?? 0,
      timing: (map['timing'] as num?)?.toInt() ?? 0,
      finalScore: (map['finalScore'] as num?)?.toInt() ?? 0,
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      medal: ScenarioMedalX.fromKey(map['medal'] as String?),
    );
  }
}

class ScenarioArchetypeComparison {
  const ScenarioArchetypeComparison({
    required this.id,
    required this.label,
    required this.score,
    required this.note,
  });

  final String id;
  final String label;
  final int score;
  final String note;
}

class ScenarioCampaignProgress {
  const ScenarioCampaignProgress({
    required this.chapterStars,
    required this.chapterBestScores,
    required this.scenarioBestScores,
    required this.scenarioBestMedals,
    required this.firstClearScenarioIds,
    required this.dailyRealSettlementByScenario,
    required this.bestMutatorScoreByScenario,
    required this.lastPlayedScenarioId,
  });

  final Map<String, int> chapterStars;
  final Map<String, int> chapterBestScores;
  final Map<String, int> scenarioBestScores;
  final Map<String, String> scenarioBestMedals;
  final List<String> firstClearScenarioIds;
  final Map<String, String> dailyRealSettlementByScenario;
  final Map<String, int> bestMutatorScoreByScenario;
  final String? lastPlayedScenarioId;

  static const ScenarioCampaignProgress empty = ScenarioCampaignProgress(
    chapterStars: <String, int>{},
    chapterBestScores: <String, int>{},
    scenarioBestScores: <String, int>{},
    scenarioBestMedals: <String, String>{},
    firstClearScenarioIds: <String>[],
    dailyRealSettlementByScenario: <String, String>{},
    bestMutatorScoreByScenario: <String, int>{},
    lastPlayedScenarioId: null,
  );

  factory ScenarioCampaignProgress.fromMap(Map<String, dynamic>? map) {
    final raw = map ?? const <String, dynamic>{};
    Map<String, int> readIntMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value.map(
          (key, inner) => MapEntry(key, (inner as num?)?.toInt() ?? 0),
        );
      }
      return const <String, int>{};
    }

    Map<String, String> readStringMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value.map((key, inner) => MapEntry(key, inner.toString()));
      }
      return const <String, String>{};
    }

    return ScenarioCampaignProgress(
      chapterStars: readIntMap(raw['chapterStars']),
      chapterBestScores: readIntMap(raw['chapterBestScores']),
      scenarioBestScores: readIntMap(raw['scenarioBestScores']),
      scenarioBestMedals: readStringMap(raw['scenarioBestMedals']),
      firstClearScenarioIds:
          (raw['firstClearScenarioIds'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
      dailyRealSettlementByScenario: readStringMap(
        raw['dailyRealSettlementByScenario'],
      ),
      bestMutatorScoreByScenario: readIntMap(raw['bestMutatorScoreByScenario']),
      lastPlayedScenarioId: raw['lastPlayedScenarioId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'chapterStars': chapterStars,
    'chapterBestScores': chapterBestScores,
    'scenarioBestScores': scenarioBestScores,
    'scenarioBestMedals': scenarioBestMedals,
    'firstClearScenarioIds': firstClearScenarioIds,
    'dailyRealSettlementByScenario': dailyRealSettlementByScenario,
    'bestMutatorScoreByScenario': bestMutatorScoreByScenario,
    if (lastPlayedScenarioId != null)
      'lastPlayedScenarioId': lastPlayedScenarioId,
  };
}

class ScenarioRunSettlement {
  const ScenarioRunSettlement({
    required this.netCoins,
    required this.bonusCoins,
    required this.xpGranted,
    required this.stageDelta,
    required this.isFirstClear,
    required this.isDailyRealSettlement,
  });

  final int netCoins;
  final int bonusCoins;
  final int xpGranted;
  final double stageDelta;
  final bool isFirstClear;
  final bool isDailyRealSettlement;
}

class ScenarioRunOutcome {
  const ScenarioRunOutcome({
    required this.finalValue,
    required this.finalPnlPct,
    required this.maxDrawdownPct,
    required this.branchPath,
    required this.breakdown,
    required this.archetypes,
    required this.provisionalScore,
    required this.feesPaid,
  });

  final double finalValue;
  final double finalPnlPct;
  final double maxDrawdownPct;
  final List<String> branchPath;
  final ScenarioScoreBreakdown breakdown;
  final List<ScenarioArchetypeComparison> archetypes;
  final int provisionalScore;
  final double feesPaid;
}

String scenarioReadTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  }
  return value?.toString() ?? '';
}

const List<ScenarioChapter> kScenarioChapters = <ScenarioChapter>[
  ScenarioChapter(
    id: 'macro_cycles',
    title: 'Macro & Cycles',
    subtitle: 'Taux, inflation, récession et allocation de cycle.',
    requiredLevel: 1,
    requiredStarsFromPrevious: 0,
    scenarioIds: <String>[
      'scenario_defensive',
      'scenario_emerging',
      'scenario_rate_hike',
      'scenario_recession',
      'scenario_stagflation',
      'scenario_deflation',
      'scenario_gold_rush',
    ],
  ),
  ScenarioChapter(
    id: 'sector_rotations',
    title: 'Rotations Sectorielles',
    subtitle: 'Arbitrer entre styles, secteurs et gagnants structurels.',
    requiredLevel: 2,
    requiredStarsFromPrevious: 9,
    scenarioIds: <String>[
      'scenario_green_energy',
      'scenario_energy_shock',
      'scenario_commercial_re',
      'scenario_retail_apocalypse',
      'scenario_infrastructure_plan',
      'scenario_ev_price_war',
      'scenario_luxury_slowdown',
    ],
  ),
  ScenarioChapter(
    id: 'global_stress',
    title: 'Stress Global',
    subtitle: 'Géopolitique, pandémie, supply chain et risques systémiques.',
    requiredLevel: 3,
    requiredStarsFromPrevious: 9,
    scenarioIds: <String>[
      'scenario_trade_war',
      'scenario_bank_run',
      'scenario_pandemic_2',
      'scenario_climate_disaster',
      'scenario_supply_chain',
      'scenario_cybersecurity',
      'scenario_politics',
    ],
  ),
  ScenarioChapter(
    id: 'momentum_rupture',
    title: 'Momentum & Rupture',
    subtitle: 'Psychologie, bulles, squeeze et asymétries extrêmes.',
    requiredLevel: 4,
    requiredStarsFromPrevious: 9,
    scenarioIds: <String>[
      'scenario_growth',
      'scenario_ai_bubble',
      'scenario_short_squeeze',
      'scenario_ipo_fever',
      'scenario_biotech_approval',
      'scenario_crypto_winter',
    ],
  ),
];

String _chapterForScenario(String scenarioId) {
  for (final chapter in kScenarioChapters) {
    if (chapter.scenarioIds.contains(scenarioId)) {
      return chapter.id;
    }
  }
  return kScenarioChapters.first.id;
}

int _requiredLevelForScenario(String scenarioId, String chapterId) {
  final chapterIndex = kScenarioChapters.indexWhere(
    (chapter) => chapter.id == chapterId,
  );
  final chapter = chapterIndex >= 0 ? kScenarioChapters[chapterIndex] : null;
  if (chapter == null) {
    return 1;
  }
  final itemIndex = chapter.scenarioIds.indexOf(scenarioId);
  if (itemIndex < 0) {
    return chapter.requiredLevel;
  }
  return chapter.requiredLevel + (itemIndex ~/ 3);
}

String _benchmarkAssetForScenario(List<SimulationAsset> assets) {
  final preferred = assets.where((asset) => !asset.isCash);
  return preferred.isNotEmpty ? preferred.first.id : 'cash';
}

List<String> _inferAssetTags(String id, String label, String role) {
  final source = '$id ${label.toLowerCase()} ${role.toLowerCase()}';
  final tags = <String>{};
  if (source.contains('cash') || source.contains('dollar')) {
    tags.addAll(const <String>['cash', 'liquidity', 'defensive']);
  }
  if (source.contains('bond') ||
      source.contains('oblig') ||
      source.contains('treasury')) {
    tags.addAll(const <String>['bond', 'defensive']);
    if (source.contains('short') || source.contains('court')) {
      tags.add('short_duration');
    } else {
      tags.add('long_duration');
    }
  }
  if (source.contains('gold') || source.contains('or ')) {
    tags.addAll(const <String>['hedge', 'commodity', 'defensive']);
  }
  if (source.contains('oil') ||
      source.contains('energy') ||
      source.contains('pétrol') ||
      source.contains('tankers')) {
    tags.addAll(const <String>['commodity', 'cyclical']);
  }
  if (source.contains('bank')) {
    tags.addAll(const <String>['financial', 'cyclical']);
  }
  if (source.contains('tech') ||
      source.contains('saas') ||
      source.contains('cloud') ||
      source.contains('ai') ||
      source.contains('biotech') ||
      source.contains('ipo') ||
      source.contains('altcoin') ||
      source.contains('crypto')) {
    tags.addAll(const <String>['growth', 'risky']);
  }
  if (source.contains('inverse') ||
      source.contains('short ') ||
      source.contains('vix')) {
    tags.addAll(const <String>['hedge', 'volatility']);
  }
  if (source.contains('utilities') ||
      source.contains('staples') ||
      source.contains('pharma') ||
      source.contains('aristocrats') ||
      source.contains('quality')) {
    tags.addAll(const <String>['defensive', 'quality']);
  }
  if (source.contains('defense')) {
    tags.addAll(const <String>['defensive', 'quality']);
  }
  if (source.contains('reit') ||
      source.contains('immo') ||
      source.contains('real estate')) {
    tags.addAll(const <String>['rate_sensitive', 'cyclical']);
  }
  if (source.contains('meme') ||
      source.contains('casino') ||
      source.contains('specul') ||
      source.contains('high beta')) {
    tags.addAll(const <String>['risky', 'momentum']);
  }
  if (tags.isEmpty) {
    tags.addAll(const <String>['core']);
  }
  return tags.toList();
}

List<ScenarioInitialPlan> _defaultInitialPlans(
  List<SimulationAsset> assets,
  Map<String, double> suggestedAllocation,
) {
  final balanced = _normalizeWeights(suggestedAllocation, assets);
  final aggressive = _tiltWeights(
    balanced,
    assets,
    boostTags: const <String>['growth', 'risky', 'momentum', 'commodity'],
    trimTags: const <String>['cash', 'defensive', 'short_duration'],
  );
  final defensive = _tiltWeights(
    balanced,
    assets,
    boostTags: const <String>['cash', 'defensive', 'hedge', 'quality', 'bond'],
    trimTags: const <String>['growth', 'risky', 'momentum', 'commodity'],
  );
  return <ScenarioInitialPlan>[
    ScenarioInitialPlan(
      id: 'aggressive',
      label: 'Agressif',
      description:
          'Accent sur les actifs à fort bêta et les rotations franches.',
      weights: aggressive,
    ),
    ScenarioInitialPlan(
      id: 'balanced',
      label: 'Équilibré',
      description: 'Point de départ le plus neutre, inspiré du scénario.',
      weights: balanced,
    ),
    ScenarioInitialPlan(
      id: 'defensive',
      label: 'Défensif',
      description:
          'Buffer de liquidité et couverture avant de chercher le PnL.',
      weights: defensive,
    ),
  ];
}

Map<String, double> _normalizeWeights(
  Map<String, double> weights,
  List<SimulationAsset> assets,
) {
  final normalized = <String, double>{};
  for (final asset in assets) {
    normalized[asset.id] = weights[asset.id] ?? 0;
  }
  final total = normalized.values.fold<double>(0, (acc, value) => acc + value);
  if (total <= 0) {
    final nonCash = assets.where((asset) => !asset.isCash).toList();
    final share = nonCash.isEmpty ? 0.0 : 100.0 / nonCash.length;
    for (final asset in nonCash) {
      normalized[asset.id] = share;
    }
    final cashAsset = assets.where((asset) => asset.isCash);
    if (cashAsset.isNotEmpty) {
      normalized[cashAsset.first.id] = 0;
    }
    return normalized;
  }
  for (final entry in normalized.entries.toList()) {
    normalized[entry.key] = (entry.value / total) * 100;
  }
  return _roundWeights(normalized);
}

Map<String, double> _tiltWeights(
  Map<String, double> base,
  List<SimulationAsset> assets, {
  required List<String> boostTags,
  required List<String> trimTags,
}) {
  final adjusted = <String, double>{...base};
  for (final asset in assets) {
    var value = adjusted[asset.id] ?? 0;
    if (asset.tags.any(boostTags.contains)) {
      value += 6;
    }
    if (asset.tags.any(trimTags.contains)) {
      value -= 6;
    }
    adjusted[asset.id] = value.clamp(0, 80).toDouble();
  }
  return _normalizeWeights(adjusted, assets);
}

Map<String, double> _roundWeights(Map<String, double> raw) {
  final rounded = <String, double>{};
  for (final entry in raw.entries) {
    rounded[entry.key] = double.parse(entry.value.toStringAsFixed(1));
  }
  final total = rounded.values.fold<double>(0, (acc, value) => acc + value);
  final delta = double.parse((100 - total).toStringAsFixed(1));
  final sorted =
      rounded.keys.toList()
        ..sort((a, b) => (rounded[b] ?? 0).compareTo(rounded[a] ?? 0));
  if (sorted.isNotEmpty) {
    rounded[sorted.first] = double.parse(
      ((rounded[sorted.first] ?? 0) + delta).toStringAsFixed(1),
    );
  }
  return rounded;
}

List<ScenarioAct> _defaultActsForScenario(
  Map<String, dynamic> rawScenario,
  SimulationConfig config,
) {
  final title = (rawScenario['title'] as String?) ?? 'Scénario';
  final focus = (rawScenario['focus'] as String?) ?? '';
  final risk = (rawScenario['risk'] as String?) ?? '';
  final cues =
      (rawScenario['config'] as Map<String, dynamic>? ??
              const <String, dynamic>{})['cues']
          as List<dynamic>? ??
      const <dynamic>[];
  final prompts =
      (rawScenario['prompts'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList();
  final cueTexts = cues.map((value) => value.toString()).toList();
  final eventFlow = _eventFlowForScenario(focus, risk, title);
  final moods = <String>['Stress ciblé', 'Rotation nerveuse', 'Clôture tendue'];
  final supporting = <List<String>>[
    <String>['capital_preservation', 'confirmation'],
    <String>['rotation', 'quality_bias'],
    <String>['timing', 'discipline'],
  ];
  final preferred = <List<ScenarioDecisionType>>[
    <ScenarioDecisionType>[
      ScenarioDecisionType.hedge,
      ScenarioDecisionType.cut,
      ScenarioDecisionType.wait,
    ],
    <ScenarioDecisionType>[
      ScenarioDecisionType.rotate,
      ScenarioDecisionType.hedge,
      ScenarioDecisionType.reinforce,
    ],
    <ScenarioDecisionType>[
      ScenarioDecisionType.rotate,
      ScenarioDecisionType.reinforce,
      ScenarioDecisionType.cut,
    ],
  ];
  final stepSlots = <int>[
    1,
    config.timelineLength > 4 ? 3 : 2,
    config.timelineLength > 5 ? 4 : config.timelineLength - 2,
  ];
  return List<ScenarioAct>.generate(3, (index) {
    final cue =
        cueTexts.isNotEmpty
            ? cueTexts[index.clamp(0, cueTexts.length - 1)]
            : config.headline;
    final prompt =
        prompts.isNotEmpty
            ? prompts[index.clamp(0, prompts.length - 1)]
            : 'Reste cohérent avec ta thèse initiale.';
    return ScenarioAct(
      id: 'act_${index + 1}',
      stepIndex: stepSlots[index],
      eventType: eventFlow[index],
      title: _actTitleForIndex(index, focus, risk),
      narrative: cue,
      marketMood: moods[index],
      riskTone: risk,
      extraInfo: prompt,
      decisionPrompt: _decisionPromptForIndex(index, focus),
      teachingPoint: prompt,
      decisionOptions: _defaultDecisionOptions(index),
      justificationOptions: _defaultJustifications(focus),
      preferredDecisionTypes: preferred[index],
      supportingScoreTags: supporting[index],
    );
  });
}

List<ScenarioDecisionOption> _defaultDecisionOptions(int actIndex) {
  final suffix = '${actIndex + 1}';
  return <ScenarioDecisionOption>[
    ScenarioDecisionOption(
      id: 'wait_$suffix',
      type: ScenarioDecisionType.wait,
      label: 'Attendre une confirmation',
      description:
          'Tu gardes du temps de décision et évites de brûler du capital trop tôt.',
      tradeCost: 0,
      infoCost: 0,
      convictionCost: 10,
      branchTag: 'patient',
      timingWindow: 'Fenêtre courte',
    ),
    ScenarioDecisionOption(
      id: 'hedge_$suffix',
      type: ScenarioDecisionType.hedge,
      label: 'Couvrir le portefeuille',
      description:
          'Tu privilégies le drawdown et transfères du poids vers le hedge ou le cash.',
      tradeCost: 1,
      infoCost: 0,
      convictionCost: 20,
      branchTag: 'hedged',
      timingWindow: 'Avant le prochain choc',
    ),
    ScenarioDecisionOption(
      id: 'cut_$suffix',
      type: ScenarioDecisionType.cut,
      label: 'Couper le maillon faible',
      description:
          'Tu soldes la partie la plus vulnérable et augmentes la liquidité.',
      tradeCost: 1,
      infoCost: 0,
      convictionCost: 20,
      branchTag: 'reduced',
      timingWindow: 'Stop tactique',
    ),
    ScenarioDecisionOption(
      id: 'rotate_$suffix',
      type: ScenarioDecisionType.rotate,
      label: 'Arbitrer vers les leaders',
      description:
          'Tu pivotes vers les actifs mieux placés pour le régime en cours.',
      tradeCost: 1,
      infoCost: 0,
      convictionCost: 30,
      branchTag: 'rotated',
      timingWindow: 'Rotation active',
    ),
    ScenarioDecisionOption(
      id: 'reinforce_$suffix',
      type: ScenarioDecisionType.reinforce,
      label: 'Renforcer la conviction',
      description:
          'Tu accentues le pari central pour chercher un score de timing plus élevé.',
      tradeCost: 1,
      infoCost: 0,
      convictionCost: 30,
      branchTag: 'pressed',
      timingWindow: 'Momentum / rebond',
    ),
  ];
}

List<ScenarioJustificationOption> _defaultJustifications(String focus) {
  return <ScenarioJustificationOption>[
    ScenarioJustificationOption(
      id: 'capital_preservation',
      label: 'Je protège le capital avant de chercher l’upside sur $focus.',
      thesisTags: const <String>['defensif'],
      scoreTag: 'capital_preservation',
    ),
    ScenarioJustificationOption(
      id: 'rotation_signal',
      label: 'Je joue une rotation claire du marché avant le consensus.',
      thesisTags: const <String>['risk_on', 'defensif'],
      scoreTag: 'rotation',
    ),
    ScenarioJustificationOption(
      id: 'contrarian_dislocation',
      label: 'Je traite la dislocation comme une sur-réaction exploitable.',
      thesisTags: const <String>['contrarian', 'risk_on'],
      scoreTag: 'mean_reversion',
    ),
  ];
}

List<ScenarioEventType> _eventFlowForScenario(
  String focus,
  String risk,
  String title,
) {
  final source = '$focus $risk $title'.toLowerCase();
  if (source.contains('taux') || source.contains('inflation')) {
    return const <ScenarioEventType>[
      ScenarioEventType.cpi,
      ScenarioEventType.fed,
      ScenarioEventType.sectorRotation,
    ];
  }
  if (source.contains('géo') ||
      source.contains('trade') ||
      source.contains('polit')) {
    return const <ScenarioEventType>[
      ScenarioEventType.geopolitical,
      ScenarioEventType.commodityShock,
      ScenarioEventType.liquidityStress,
    ];
  }
  if (source.contains('biotech') ||
      source.contains('tech') ||
      source.contains('ipo') ||
      source.contains('ai')) {
    return const <ScenarioEventType>[
      ScenarioEventType.earnings,
      ScenarioEventType.guidanceCut,
      ScenarioEventType.regulation,
    ];
  }
  if (source.contains('crypto') || source.contains('régul')) {
    return const <ScenarioEventType>[
      ScenarioEventType.regulation,
      ScenarioEventType.liquidityStress,
      ScenarioEventType.sectorRotation,
    ];
  }
  return const <ScenarioEventType>[
    ScenarioEventType.sectorRotation,
    ScenarioEventType.guidanceCut,
    ScenarioEventType.liquidityStress,
  ];
}

String _actTitleForIndex(int index, String focus, String risk) {
  switch (index) {
    case 0:
      return 'Acte I · Premier choc sur $focus';
    case 1:
      return 'Acte II · Branche critique';
    default:
      return 'Acte III · Fenêtre finale sous $risk';
  }
}

String _decisionPromptForIndex(int index, String focus) {
  switch (index) {
    case 0:
      return 'Quel arbitrage initial te semble le plus cohérent pour $focus ?';
    case 1:
      return 'Le marché bifurque. Comment réalloues-tu le risque ?';
    default:
      return 'Dernière décision: sécuriser, pivoter ou presser le scénario ?';
  }
}
