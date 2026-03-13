import 'dart:math' as math;

import '../models/scenario_game_models.dart';

class ScenarioActSnapshot {
  const ScenarioActSnapshot({
    required this.actId,
    required this.stepIndex,
    required this.portfolioValue,
    required this.pnlPct,
    required this.drawdownPct,
    required this.provisionalScore,
    required this.branchNote,
  });

  final String actId;
  final int stepIndex;
  final double portfolioValue;
  final double pnlPct;
  final double drawdownPct;
  final int provisionalScore;
  final String branchNote;
}

class ScenarioGameEngine {
  const ScenarioGameEngine._();

  static const ScenarioResourceState defaultResources = ScenarioResourceState(
    tradeCredits: 4,
    infoCredits: 2,
    convictionBudget: 100,
  );

  static String scenarioDayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  static int levelFromXp(int xp) =>
      (math.log((xp / 500) + 1) / math.log(1.2)).floor() + 1;

  static ScenarioChapter chapterForScenario(PortfolioScenario scenario) {
    return kScenarioChapters.firstWhere(
      (chapter) => chapter.id == scenario.chapterId,
      orElse: () => kScenarioChapters.first,
    );
  }

  static bool isChapterUnlocked({
    required ScenarioChapter chapter,
    required int level,
    required ScenarioCampaignProgress campaign,
  }) {
    if (level < chapter.requiredLevel) {
      return false;
    }
    final chapterIndex = kScenarioChapters.indexOf(chapter);
    if (chapterIndex <= 0) {
      return true;
    }
    final previous = kScenarioChapters[chapterIndex - 1];
    final previousStars = campaign.chapterStars[previous.id] ?? 0;
    return previousStars >= chapter.requiredStarsFromPrevious;
  }

  static bool isScenarioUnlocked({
    required PortfolioScenario scenario,
    required int level,
    required ScenarioCampaignProgress campaign,
  }) {
    if (level < scenario.requiredLevel) {
      return false;
    }
    return isChapterUnlocked(
      chapter: chapterForScenario(scenario),
      level: level,
      campaign: campaign,
    );
  }

  static bool canUseMutators({
    required PortfolioScenario scenario,
    required ScenarioCampaignProgress campaign,
  }) {
    return campaign.firstClearScenarioIds.contains(scenario.id);
  }

  static bool hasDailySettlementAvailable({
    required String scenarioId,
    required ScenarioCampaignProgress campaign,
    DateTime? now,
  }) {
    final dayKey = scenarioDayKey(now ?? DateTime.now());
    return campaign.dailyRealSettlementByScenario[scenarioId] != dayKey;
  }

  static ScenarioMutatorSet normalizeMutators(ScenarioMutatorSet value) {
    if (!value.expertMode) {
      return value;
    }
    return value.copyWith(
      volatilityBoost: true,
      highFees: true,
      delayedInfo: true,
      contradictoryNews: true,
    );
  }

  static ScenarioResourceState resourcesForMutators(ScenarioMutatorSet value) {
    final normalized = normalizeMutators(value);
    return defaultResources.copyWith(
      tradeCredits: normalized.expertMode ? 3 : defaultResources.tradeCredits,
    );
  }

  static ScenarioRunOutcome evaluateRun({
    required PortfolioScenario scenario,
    required int stakeCoins,
    required ScenarioThesis thesis,
    required ScenarioInitialPlan initialPlan,
    required List<ScenarioDecisionJournalEntry> journal,
    required ScenarioMutatorSet mutators,
  }) {
    final normalizedMutators = normalizeMutators(mutators);
    final acts = scenario.acts;
    var allocation = normalizeAllocation(
      Map<String, double>.from(initialPlan.weights),
      scenario.config.assets,
    );
    var currentValue = stakeCoins.toDouble();
    var peak = currentValue;
    var maxDrawdownPct = 0.0;
    var lastStep = 0;
    var feesPaid = 0.0;
    final branchPath = <String>[];

    for (final entry in journal) {
      final act = acts.firstWhere(
        (item) => item.id == entry.actId,
        orElse: () => acts.first,
      );
      currentValue = projectValue(
        scenario: scenario,
        allocation: allocation,
        principal: currentValue,
        fromStep: lastStep,
        toStep: act.stepIndex,
        mutators: normalizedMutators,
      );
      peak = math.max(peak, currentValue);
      maxDrawdownPct = math.max(
        maxDrawdownPct,
        _drawdownPct(peak: peak, currentValue: currentValue),
      );
      final decisionAllocation = applyDecision(
        allocation: allocation,
        scenario: scenario,
        decisionType: entry.decisionType,
        thesis: thesis,
        currentStep: act.stepIndex,
      );
      final changed = !_sameAllocation(allocation, decisionAllocation);
      allocation = decisionAllocation;
      if (changed && normalizedMutators.highFees) {
        final feeRate = normalizedMutators.expertMode ? 0.010 : 0.0075;
        final fee = currentValue * feeRate;
        currentValue = math.max(0, currentValue - fee);
        feesPaid += fee;
      }
      branchPath.add(entry.branchTag);
      lastStep = act.stepIndex;
    }

    currentValue = projectValue(
      scenario: scenario,
      allocation: allocation,
      principal: currentValue,
      fromStep: lastStep,
      toStep: scenario.config.timelineLength - 1,
      mutators: normalizedMutators,
    );
    peak = math.max(peak, currentValue);
    maxDrawdownPct = math.max(
      maxDrawdownPct,
      _drawdownPct(peak: peak, currentValue: currentValue),
    );

    final pnlPct =
        stakeCoins <= 0
            ? 0.0
            : ((currentValue - stakeCoins) / stakeCoins) * 100;
    final benchmarkPct = benchmarkPnlPct(
      scenario: scenario,
      mutators: normalizedMutators,
    );

    final coherence = _coherenceScore(
      thesis: thesis,
      scenario: scenario,
      journal: journal,
    );
    final timing = _timingScore(
      thesis: thesis,
      scenario: scenario,
      journal: journal,
      mutators: normalizedMutators,
    );
    final performance = _performanceScore(
      pnlPct: pnlPct,
      benchmarkPct: benchmarkPct,
      feesPaidPct: stakeCoins <= 0 ? 0 : (feesPaid / stakeCoins) * 100,
    );
    final riskManagement = _riskManagementScore(
      drawdownPct: maxDrawdownPct,
      journal: journal,
      finalAllocation: allocation,
      thesis: thesis,
    );
    final drawdown = _drawdownScore(maxDrawdownPct);
    final finalScore = _clampScore(
      (performance * 0.30) +
          (drawdown * 0.20) +
          (coherence * 0.20) +
          (riskManagement * 0.20) +
          (timing * 0.10),
    );
    final medal = medalForScore(finalScore);
    final breakdown = ScenarioScoreBreakdown(
      performance: performance,
      drawdown: drawdown,
      coherence: coherence,
      riskManagement: riskManagement,
      timing: timing,
      finalScore: finalScore,
      stars: medal.stars,
      medal: medal,
    );
    final archetypes = buildArchetypes(
      breakdown: breakdown,
      pnlPct: pnlPct,
      drawdownPct: maxDrawdownPct,
    );

    return ScenarioRunOutcome(
      finalValue: currentValue,
      finalPnlPct: pnlPct,
      maxDrawdownPct: maxDrawdownPct,
      branchPath: branchPath,
      breakdown: breakdown,
      archetypes: archetypes,
      provisionalScore: finalScore,
      feesPaid: feesPaid,
    );
  }

  static ScenarioActSnapshot buildActSnapshot({
    required PortfolioScenario scenario,
    required int stakeCoins,
    required ScenarioThesis thesis,
    required ScenarioInitialPlan initialPlan,
    required List<ScenarioDecisionJournalEntry> journal,
    required ScenarioMutatorSet mutators,
  }) {
    if (journal.isEmpty) {
      return const ScenarioActSnapshot(
        actId: 'preview',
        stepIndex: 0,
        portfolioValue: 0,
        pnlPct: 0,
        drawdownPct: 0,
        provisionalScore: 0,
        branchNote: 'Aucune décision enregistrée.',
      );
    }
    final normalizedMutators = normalizeMutators(mutators);
    final outcome = evaluateRun(
      scenario: scenario,
      stakeCoins: stakeCoins,
      thesis: thesis,
      initialPlan: initialPlan,
      journal: journal,
      mutators: normalizedMutators,
    );
    final last = journal.last;
    return ScenarioActSnapshot(
      actId: last.actId,
      stepIndex:
          scenario.acts.firstWhere((act) => act.id == last.actId).stepIndex,
      portfolioValue: outcome.finalValue,
      pnlPct: outcome.finalPnlPct,
      drawdownPct: outcome.maxDrawdownPct,
      provisionalScore: outcome.breakdown.finalScore,
      branchNote: branchNoteForTag(last.branchTag),
    );
  }

  static Map<String, double> normalizeAllocation(
    Map<String, double> allocation,
    List<SimulationAsset> assets,
  ) {
    final normalized = <String, double>{};
    for (final asset in assets) {
      normalized[asset.id] = allocation[asset.id] ?? 0;
    }
    final total = normalized.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    if (total <= 0) {
      final balanced = 100 / assets.length;
      for (final asset in assets) {
        normalized[asset.id] = asset.isCash ? 0 : balanced;
      }
      final cash = assets.where((asset) => asset.isCash);
      if (cash.isNotEmpty) {
        normalized[cash.first.id] = math.max(
          0,
          100 - normalized.values.fold<double>(0, (s, v) => s + v),
        );
      }
      return normalized;
    }
    for (final key in normalized.keys.toList()) {
      normalized[key] = ((normalized[key] ?? 0) / total) * 100;
    }
    return _roundAllocation(normalized);
  }

  static Map<String, double> applyDecision({
    required Map<String, double> allocation,
    required PortfolioScenario scenario,
    required ScenarioDecisionType decisionType,
    required ScenarioThesis thesis,
    required int currentStep,
  }) {
    final adjusted = <String, double>{...allocation};
    final assets = scenario.config.assets;
    final cashAsset = assets.where((asset) => asset.isCash).firstOrNull;
    final risky = _assetRanking(
      assets: assets,
      currentStep: currentStep,
      scenario: scenario,
      preferRisk: true,
    );
    final defensive = _assetRanking(
      assets: assets,
      currentStep: currentStep,
      scenario: scenario,
      preferRisk: false,
    );
    final bestForward = _bestForwardAsset(
      assets: assets,
      currentStep: currentStep,
      scenario: scenario,
      thesis: thesis,
    );
    final worstForward = _worstForwardAsset(
      assets: assets,
      currentStep: currentStep,
      scenario: scenario,
    );

    switch (decisionType) {
      case ScenarioDecisionType.wait:
        break;
      case ScenarioDecisionType.hedge:
        _moveWeight(
          adjusted,
          fromIds: risky.take(2).map((asset) => asset.id).toList(),
          toIds: <String>[
            if (cashAsset != null) cashAsset.id,
            ...defensive.take(2).map((asset) => asset.id),
          ],
          amount: 18,
        );
        break;
      case ScenarioDecisionType.cut:
        _moveWeight(
          adjusted,
          fromIds: <String>[worstForward.id],
          toIds: <String>[if (cashAsset != null) cashAsset.id],
          amount: 16,
        );
        break;
      case ScenarioDecisionType.rotate:
        _moveWeight(
          adjusted,
          fromIds: risky.take(2).map((asset) => asset.id).toList(),
          toIds: <String>[
            bestForward.id,
            ...defensive.take(1).map((asset) => asset.id),
          ],
          amount: 20,
        );
        break;
      case ScenarioDecisionType.reinforce:
        _moveWeight(
          adjusted,
          fromIds: <String>[
            if (cashAsset != null) cashAsset.id,
            worstForward.id,
          ],
          toIds: <String>[bestForward.id],
          amount: 18,
        );
        break;
    }
    return normalizeAllocation(adjusted, assets);
  }

  static double projectValue({
    required PortfolioScenario scenario,
    required Map<String, double> allocation,
    required double principal,
    required int fromStep,
    required int toStep,
    required ScenarioMutatorSet mutators,
  }) {
    final normalizedMutators = normalizeMutators(mutators);
    var value = principal;
    for (final asset in scenario.config.assets) {
      final weight = (allocation[asset.id] ?? 0) / 100;
      if (weight <= 0) {
        continue;
      }
      final fromPrice = effectivePrice(
        asset: asset,
        step: fromStep,
        mutators: normalizedMutators,
      );
      final toPrice = effectivePrice(
        asset: asset,
        step: toStep,
        mutators: normalizedMutators,
      );
      if (fromPrice <= 0) {
        continue;
      }
      final contribution = principal * weight * (toPrice / fromPrice);
      value -= principal * weight;
      value += contribution;
    }
    return value;
  }

  static double effectivePrice({
    required SimulationAsset asset,
    required int step,
    required ScenarioMutatorSet mutators,
  }) {
    final safeStep = step.clamp(0, asset.prices.length - 1);
    final raw = asset.prices[safeStep];
    if (asset.isCash) {
      return raw;
    }
    var value = raw;
    final start = asset.prices.first;
    if (mutators.volatilityBoost) {
      value = start + ((raw - start) * 1.18);
    }
    if (mutators.contradictoryNews) {
      final seed = asset.id.codeUnits.fold<int>(0, (sum, item) => sum + item);
      final noise = (((seed + (safeStep * 13)) % 7) - 3) / 100;
      value = value * (1 + noise);
    }
    return value;
  }

  static double benchmarkPnlPct({
    required PortfolioScenario scenario,
    required ScenarioMutatorSet mutators,
  }) {
    final asset = scenario.config.assets.firstWhere(
      (entry) => entry.id == scenario.benchmarkAssetId,
      orElse: () => scenario.config.assets.firstWhere((entry) => !entry.isCash),
    );
    final first = effectivePrice(asset: asset, step: 0, mutators: mutators);
    final last = effectivePrice(
      asset: asset,
      step: scenario.config.timelineLength - 1,
      mutators: mutators,
    );
    if (first <= 0) {
      return 0;
    }
    return ((last - first) / first) * 100;
  }

  static ScenarioMedal medalForScore(int score) {
    if (score >= 85) {
      return ScenarioMedal.gold;
    }
    if (score >= 70) {
      return ScenarioMedal.silver;
    }
    if (score >= 55) {
      return ScenarioMedal.bronze;
    }
    return ScenarioMedal.none;
  }

  static ScenarioRunSettlement settlementForOutcome({
    required PortfolioScenario scenario,
    required ScenarioRunOutcome outcome,
    required ScenarioCampaignProgress campaign,
    required DateTime now,
    required int stakeCoins,
  }) {
    final firstClear = !campaign.firstClearScenarioIds.contains(scenario.id);
    final dailySettlement = hasDailySettlementAvailable(
      scenarioId: scenario.id,
      campaign: campaign,
      now: now,
    );
    final medal = outcome.breakdown.medal;
    final baseBonus = switch (medal) {
      ScenarioMedal.none => 0,
      ScenarioMedal.bronze => 60,
      ScenarioMedal.silver => 120,
      ScenarioMedal.gold => 180,
    };
    final bonusCoins = firstClear ? baseBonus : (baseBonus * 0.35).round();
    final xp =
        (scenario.rewardXp *
                (firstClear
                    ? switch (medal) {
                      ScenarioMedal.gold => 1.5,
                      ScenarioMedal.silver => 1.25,
                      _ => 1.0,
                    }
                    : 0.35))
            .round();
    final stageDelta =
        !firstClear
            ? 0.0
            : switch (medal) {
              ScenarioMedal.gold => 0.16,
              ScenarioMedal.silver => 0.12,
              ScenarioMedal.bronze => 0.08,
              ScenarioMedal.none => 0.04,
            };
    final realNet =
        dailySettlement ? (outcome.finalValue - stakeCoins).round() : 0;
    return ScenarioRunSettlement(
      netCoins: realNet + bonusCoins,
      bonusCoins: bonusCoins,
      xpGranted: xp,
      stageDelta: stageDelta,
      isFirstClear: firstClear,
      isDailyRealSettlement: dailySettlement,
    );
  }

  static ScenarioCampaignProgress applyRunToCampaign({
    required PortfolioScenario scenario,
    required ScenarioCampaignProgress current,
    required ScenarioRunOutcome outcome,
    required ScenarioMutatorSet mutators,
    required DateTime now,
  }) {
    final bestScores = <String, int>{...current.scenarioBestScores};
    final bestMedals = <String, String>{...current.scenarioBestMedals};
    final chapterScores = <String, int>{...current.chapterBestScores};
    final chapterStars = <String, int>{...current.chapterStars};
    final firstClears = <String>[...current.firstClearScenarioIds];
    final dailySettlement = <String, String>{
      ...current.dailyRealSettlementByScenario,
    };
    final bestMutatorScore = <String, int>{
      ...current.bestMutatorScoreByScenario,
    };

    final previousBestScore = bestScores[scenario.id] ?? 0;
    final newBest = math.max(previousBestScore, outcome.breakdown.finalScore);
    bestScores[scenario.id] = newBest;
    final previousMedal = ScenarioMedalX.fromKey(bestMedals[scenario.id]);
    if (outcome.breakdown.medal.stars >= previousMedal.stars) {
      bestMedals[scenario.id] = outcome.breakdown.medal.key;
    }
    if (!firstClears.contains(scenario.id)) {
      firstClears.add(scenario.id);
    }
    dailySettlement[scenario.id] = scenarioDayKey(now);
    if (mutators.anyEnabled) {
      bestMutatorScore[scenario.id] = math.max(
        bestMutatorScore[scenario.id] ?? 0,
        outcome.breakdown.finalScore,
      );
    }

    for (final chapter in kScenarioChapters) {
      var stars = 0;
      var totalScore = 0;
      for (final scenarioId in chapter.scenarioIds) {
        final medal = ScenarioMedalX.fromKey(bestMedals[scenarioId]);
        stars += medal.stars;
        totalScore += bestScores[scenarioId] ?? 0;
      }
      chapterStars[chapter.id] = stars;
      chapterScores[chapter.id] = totalScore;
    }

    return ScenarioCampaignProgress(
      chapterStars: chapterStars,
      chapterBestScores: chapterScores,
      scenarioBestScores: bestScores,
      scenarioBestMedals: bestMedals,
      firstClearScenarioIds: firstClears,
      dailyRealSettlementByScenario: dailySettlement,
      bestMutatorScoreByScenario: bestMutatorScore,
      lastPlayedScenarioId: scenario.id,
    );
  }

  static List<ScenarioArchetypeComparison> buildArchetypes({
    required ScenarioScoreBreakdown breakdown,
    required double pnlPct,
    required double drawdownPct,
  }) {
    final defensive = _clampScore(
      (breakdown.drawdown * 0.50) +
          (breakdown.riskManagement * 0.30) +
          (breakdown.coherence * 0.20),
    );
    final aggressive = _clampScore(
      (breakdown.performance * 0.55) +
          (breakdown.timing * 0.25) +
          (breakdown.coherence * 0.20),
    );
    final expert = _clampScore(
      (breakdown.finalScore * 0.7) + ((100 - drawdownPct).clamp(0, 100) * 0.3),
    );
    return <ScenarioArchetypeComparison>[
      ScenarioArchetypeComparison(
        id: 'defensive',
        label: 'Défensif',
        score: defensive,
        note:
            drawdownPct <= 12
                ? 'Tu as bien protégé le capital.'
                : 'Le drawdown reste trop élevé pour un profil défensif.',
      ),
      ScenarioArchetypeComparison(
        id: 'aggressive',
        label: 'Agressif',
        score: aggressive,
        note:
            pnlPct >= 0
                ? 'La trajectoire capte bien l’upside.'
                : 'L’agressivité n’a pas payé sur ce run.',
      ),
      ScenarioArchetypeComparison(
        id: 'expert',
        label: 'Expert',
        score: expert,
        note:
            breakdown.finalScore >= 75
                ? 'Lecture marché solide et disciplinée.'
                : 'Le process manque encore de constance.',
      ),
    ];
  }

  static String branchNoteForTag(String branchTag) {
    switch (branchTag) {
      case 'hedged':
        return 'Ta couverture limite la casse, mais réduit l’explosivité.';
      case 'pressed':
        return 'Tu presses la conviction: upside élevé, erreur plus coûteuse.';
      case 'rotated':
        return 'Tu pivotes avec le régime et acceptes le coût de timing.';
      case 'reduced':
        return 'Tu réduis l’exposition et reprends le contrôle du risque.';
      default:
        return 'Tu conserves de l’optionnalité pour la suite du scénario.';
    }
  }

  static int _performanceScore({
    required double pnlPct,
    required double benchmarkPct,
    required double feesPaidPct,
  }) {
    final excess = pnlPct - benchmarkPct;
    return _clampScore(
      (50 + (pnlPct * 1.8) + (excess * 1.2) - (feesPaidPct * 3)),
    );
  }

  static int _drawdownScore(double drawdownPct) {
    return _clampScore(100 - (drawdownPct * 2.3));
  }

  static int _coherenceScore({
    required ScenarioThesis thesis,
    required PortfolioScenario scenario,
    required List<ScenarioDecisionJournalEntry> journal,
  }) {
    if (journal.isEmpty) {
      return 0;
    }
    var total = 0.0;
    for (final entry in journal) {
      final act = scenario.acts.firstWhere((item) => item.id == entry.actId);
      var score = 42.0;
      if (act.preferredDecisionTypes.contains(entry.decisionType)) {
        score += 18;
      }
      final justification = act.justificationOptions.firstWhere(
        (item) => item.id == entry.justificationId,
        orElse: () => act.justificationOptions.first,
      );
      if (act.supportingScoreTags.contains(justification.scoreTag)) {
        score += 14;
      }
      score += switch (thesis) {
        ScenarioThesis.riskOn =>
          entry.decisionType == ScenarioDecisionType.reinforce ||
                  entry.decisionType == ScenarioDecisionType.rotate
              ? 12
              : entry.decisionType == ScenarioDecisionType.wait
              ? 4
              : -6,
        ScenarioThesis.defensive =>
          entry.decisionType == ScenarioDecisionType.hedge ||
                  entry.decisionType == ScenarioDecisionType.cut ||
                  entry.decisionType == ScenarioDecisionType.wait
              ? 12
              : -8,
        ScenarioThesis.contrarian =>
          justification.scoreTag == 'mean_reversion' ||
                  entry.decisionType == ScenarioDecisionType.rotate
              ? 12
              : 2,
      };
      if (entry.revealedInfo) {
        score += 4;
      }
      total += score;
    }
    return _clampScore(total / journal.length);
  }

  static int _riskManagementScore({
    required double drawdownPct,
    required List<ScenarioDecisionJournalEntry> journal,
    required Map<String, double> finalAllocation,
    required ScenarioThesis thesis,
  }) {
    if (journal.isEmpty) {
      return 0;
    }
    final protectiveActions = journal.where(
      (entry) =>
          entry.decisionType == ScenarioDecisionType.hedge ||
          entry.decisionType == ScenarioDecisionType.cut ||
          entry.decisionType == ScenarioDecisionType.wait,
    );
    final finalCash = finalAllocation.entries
        .where(
          (entry) => entry.key.contains('cash') || entry.key.contains('dollar'),
        )
        .fold<double>(0, (sum, entry) => sum + entry.value);
    var score = 100 - (drawdownPct * 1.7);
    score += protectiveActions.length * 6;
    score += math.min(12, finalCash / 4);
    if (thesis == ScenarioThesis.riskOn) {
      score -= 6;
    }
    return _clampScore(score);
  }

  static int _timingScore({
    required ScenarioThesis thesis,
    required PortfolioScenario scenario,
    required List<ScenarioDecisionJournalEntry> journal,
    required ScenarioMutatorSet mutators,
  }) {
    if (journal.isEmpty) {
      return 0;
    }
    var total = 0.0;
    for (final entry in journal) {
      final act = scenario.acts.firstWhere((item) => item.id == entry.actId);
      final nextStep =
          act == scenario.acts.last
              ? scenario.config.timelineLength - 1
              : scenario.acts[scenario.acts.indexOf(act) + 1].stepIndex;
      final best = _bestForwardAsset(
        assets: scenario.config.assets,
        currentStep: act.stepIndex,
        scenario: scenario,
        thesis: thesis,
        nextWindowStep: nextStep,
      );
      final worst = _worstForwardAsset(
        assets: scenario.config.assets,
        currentStep: act.stepIndex,
        scenario: scenario,
        nextWindowStep: nextStep,
      );
      var score = 36.0;
      if (entry.decisionType == ScenarioDecisionType.reinforce &&
          !best.isCash) {
        score += 26;
      }
      if (entry.decisionType == ScenarioDecisionType.cut && !worst.isCash) {
        score += 22;
      }
      if (entry.decisionType == ScenarioDecisionType.hedge) {
        score += 18;
      }
      if (entry.decisionType == ScenarioDecisionType.wait &&
          mutators.contradictoryNews) {
        score += 14;
      }
      total += score;
    }
    return _clampScore(total / journal.length);
  }

  static List<SimulationAsset> _assetRanking({
    required List<SimulationAsset> assets,
    required int currentStep,
    required PortfolioScenario scenario,
    required bool preferRisk,
  }) {
    final filtered = assets.where((asset) => !asset.isCash).toList();
    filtered.sort((a, b) {
      final aScore = _assetRiskScore(a, preferRisk);
      final bScore = _assetRiskScore(b, preferRisk);
      if (aScore == bScore) {
        return _forwardReturnPct(
          scenario: scenario,
          asset: b,
          fromStep: currentStep,
          toStep: scenario.config.timelineLength - 1,
          mutators: const ScenarioMutatorSet(),
        ).compareTo(
          _forwardReturnPct(
            scenario: scenario,
            asset: a,
            fromStep: currentStep,
            toStep: scenario.config.timelineLength - 1,
            mutators: const ScenarioMutatorSet(),
          ),
        );
      }
      return bScore.compareTo(aScore);
    });
    return filtered;
  }

  static SimulationAsset _bestForwardAsset({
    required List<SimulationAsset> assets,
    required int currentStep,
    required PortfolioScenario scenario,
    required ScenarioThesis thesis,
    int? nextWindowStep,
  }) {
    final toStep = nextWindowStep ?? scenario.config.timelineLength - 1;
    final sorted =
        assets.where((asset) => !asset.isCash).toList()..sort((a, b) {
          final aReturn = _forwardReturnPct(
            scenario: scenario,
            asset: a,
            fromStep: currentStep,
            toStep: toStep,
            mutators: const ScenarioMutatorSet(),
          );
          final bReturn = _forwardReturnPct(
            scenario: scenario,
            asset: b,
            fromStep: currentStep,
            toStep: toStep,
            mutators: const ScenarioMutatorSet(),
          );
          final thesisBiasA = _assetBiasForThesis(a, thesis);
          final thesisBiasB = _assetBiasForThesis(b, thesis);
          return (bReturn + thesisBiasB).compareTo(aReturn + thesisBiasA);
        });
    return sorted.first;
  }

  static SimulationAsset _worstForwardAsset({
    required List<SimulationAsset> assets,
    required int currentStep,
    required PortfolioScenario scenario,
    int? nextWindowStep,
  }) {
    final toStep = nextWindowStep ?? scenario.config.timelineLength - 1;
    final sorted =
        assets.where((asset) => !asset.isCash).toList()..sort((a, b) {
          final aReturn = _forwardReturnPct(
            scenario: scenario,
            asset: a,
            fromStep: currentStep,
            toStep: toStep,
            mutators: const ScenarioMutatorSet(),
          );
          final bReturn = _forwardReturnPct(
            scenario: scenario,
            asset: b,
            fromStep: currentStep,
            toStep: toStep,
            mutators: const ScenarioMutatorSet(),
          );
          return aReturn.compareTo(bReturn);
        });
    return sorted.first;
  }

  static double _assetBiasForThesis(
    SimulationAsset asset,
    ScenarioThesis thesis,
  ) {
    switch (thesis) {
      case ScenarioThesis.riskOn:
        return asset.tags.contains('growth') || asset.tags.contains('momentum')
            ? 4
            : 0;
      case ScenarioThesis.defensive:
        return asset.tags.contains('defensive') ||
                asset.tags.contains('hedge') ||
                asset.tags.contains('cash')
            ? 4
            : 0;
      case ScenarioThesis.contrarian:
        return asset.tags.contains('hedge') || asset.tags.contains('quality')
            ? 2
            : 1;
    }
  }

  static double _assetRiskScore(SimulationAsset asset, bool preferRisk) {
    final score = asset.tags.fold<double>(0, (sum, tag) {
      switch (tag) {
        case 'growth':
        case 'risky':
        case 'momentum':
        case 'commodity':
          return sum + 2;
        case 'defensive':
        case 'hedge':
        case 'cash':
        case 'bond':
          return sum - 2;
        default:
          return sum;
      }
    });
    return preferRisk ? score : -score;
  }

  static double _forwardReturnPct({
    required PortfolioScenario scenario,
    required SimulationAsset asset,
    required int fromStep,
    required int toStep,
    required ScenarioMutatorSet mutators,
  }) {
    final from = effectivePrice(
      asset: asset,
      step: fromStep,
      mutators: mutators,
    );
    final to = effectivePrice(asset: asset, step: toStep, mutators: mutators);
    if (from == 0) {
      return 0;
    }
    return ((to - from) / from) * 100;
  }

  static bool _sameAllocation(
    Map<String, double> left,
    Map<String, double> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (((right[entry.key] ?? 0) - entry.value).abs() > 0.2) {
        return false;
      }
    }
    return true;
  }

  static void _moveWeight(
    Map<String, double> allocation, {
    required List<String> fromIds,
    required List<String> toIds,
    required double amount,
  }) {
    if (fromIds.isEmpty || toIds.isEmpty || amount <= 0) {
      return;
    }
    final existingFrom = fromIds.where(allocation.containsKey).toList();
    final existingTo = toIds.where(allocation.containsKey).toList();
    if (existingFrom.isEmpty || existingTo.isEmpty) {
      return;
    }
    final movePerFrom = amount / existingFrom.length;
    final movePerTo = amount / existingTo.length;
    for (final id in existingFrom) {
      allocation[id] = math.max(0, (allocation[id] ?? 0) - movePerFrom);
    }
    for (final id in existingTo) {
      allocation[id] = (allocation[id] ?? 0) + movePerTo;
    }
  }

  static double _drawdownPct({
    required double peak,
    required double currentValue,
  }) {
    if (peak <= 0) {
      return 0;
    }
    return ((peak - currentValue) / peak) * 100;
  }

  static Map<String, double> _roundAllocation(Map<String, double> raw) {
    final rounded = <String, double>{};
    for (final entry in raw.entries) {
      rounded[entry.key] = double.parse(entry.value.toStringAsFixed(1));
    }
    final total = rounded.values.fold<double>(0, (sum, value) => sum + value);
    final delta = double.parse((100 - total).toStringAsFixed(1));
    final key =
        rounded.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (key.isNotEmpty) {
      final first = key.first.key;
      rounded[first] = double.parse(
        ((rounded[first] ?? 0) + delta).toStringAsFixed(1),
      );
    }
    return rounded;
  }

  static int _clampScore(num value) => value.round().clamp(0, 100);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
