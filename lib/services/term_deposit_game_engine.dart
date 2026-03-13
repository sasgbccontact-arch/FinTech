import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/term_deposit_game_models.dart';

const String kTreasurySkillExtraReroll = 'extra_reroll_daily';
const String kTreasurySkillForecastTomorrow = 'forecast_regime_tomorrow';
const String kTreasurySkillFreeEarlyExit = 'free_early_exit_weekly';
const String kTreasurySkillLadderMaster = 'ladder_master_bonus';
const String kTreasurySkillEventShield = 'event_shield_once_per_week';
const String kTreasurySkillPremiumSlot = 'premium_slot_unlock';

@visibleForTesting
String treasuryDayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

@visibleForTesting
String treasuryWeekKey(DateTime value) {
  final startOfYear = DateTime(value.year, 1, 1);
  final dayIndex = value.difference(startOfYear).inDays;
  final week = ((dayIndex + startOfYear.weekday - 1) / 7).floor() + 1;
  return '${value.year}W${week.toString().padLeft(2, '0')}';
}

@visibleForTesting
String treasurySeasonKey(DateTime value) {
  final quarter = ((value.month - 1) ~/ 3) + 1;
  return '${value.year}-Q$quarter';
}

class TreasurySkillDefinition {
  const TreasurySkillDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.requiredLevel,
    required this.requiredSeasonPoints,
    required this.seasonPointCost,
    required this.gemCost,
    required this.usesSeasonPointsCurrency,
  });

  final String id;
  final String label;
  final String description;
  final int requiredLevel;
  final int requiredSeasonPoints;
  final int seasonPointCost;
  final int gemCost;
  final bool usesSeasonPointsCurrency;
}

class TreasurySlotUpgradeDefinition {
  const TreasurySlotUpgradeDefinition({
    required this.targetSlotCount,
    required this.requiredLevel,
    required this.requiredSeasonPoints,
    required this.gemCost,
  });

  final int targetSlotCount;
  final int requiredLevel;
  final int requiredSeasonPoints;
  final int gemCost;
}

class TermDepositGameEngine {
  const TermDepositGameEngine._();

  static const List<TreasurySkillDefinition>
  skillCatalog = <TreasurySkillDefinition>[
    TreasurySkillDefinition(
      id: kTreasurySkillExtraReroll,
      label: '+1 reroll / jour',
      description:
          'Offre un reroll gratuit supplémentaire pour reconfigurer le board quotidien.',
      requiredLevel: 2,
      requiredSeasonPoints: 70,
      seasonPointCost: 0,
      gemCost: 60,
      usesSeasonPointsCurrency: false,
    ),
    TreasurySkillDefinition(
      id: kTreasurySkillForecastTomorrow,
      label: 'Prévision demain',
      description:
          'Affiche le régime attendu demain pour anticiper ta duration.',
      requiredLevel: 2,
      requiredSeasonPoints: 90,
      seasonPointCost: 0,
      gemCost: 75,
      usesSeasonPointsCurrency: false,
    ),
    TreasurySkillDefinition(
      id: kTreasurySkillFreeEarlyExit,
      label: 'Retrait anticipé gratuit',
      description:
          'Permet une sortie gratuite par semaine sur un dépôt flexible.',
      requiredLevel: 3,
      requiredSeasonPoints: 120,
      seasonPointCost: 0,
      gemCost: 90,
      usesSeasonPointsCurrency: false,
    ),
    TreasurySkillDefinition(
      id: kTreasurySkillLadderMaster,
      label: 'Ladder Master',
      description:
          'Augmente le bonus quand la structure d’échéances est vraiment propre.',
      requiredLevel: 3,
      requiredSeasonPoints: 130,
      seasonPointCost: 130,
      gemCost: 0,
      usesSeasonPointsCurrency: true,
    ),
    TreasurySkillDefinition(
      id: kTreasurySkillEventShield,
      label: 'Shield événement',
      description:
          'Absorbe un choc sévère par semaine avant qu’il ne pénalise la trésorerie.',
      requiredLevel: 4,
      requiredSeasonPoints: 150,
      seasonPointCost: 0,
      gemCost: 100,
      usesSeasonPointsCurrency: false,
    ),
    TreasurySkillDefinition(
      id: kTreasurySkillPremiumSlot,
      label: 'Premium slot',
      description:
          'Débloque les produits premium et boostés qui consomment un slot rare.',
      requiredLevel: 4,
      requiredSeasonPoints: 180,
      seasonPointCost: 0,
      gemCost: 120,
      usesSeasonPointsCurrency: false,
    ),
  ];

  static const List<TreasurySlotUpgradeDefinition> slotUpgradeCatalog =
      <TreasurySlotUpgradeDefinition>[
        TreasurySlotUpgradeDefinition(
          targetSlotCount: 3,
          requiredLevel: 3,
          requiredSeasonPoints: 100,
          gemCost: 80,
        ),
        TreasurySlotUpgradeDefinition(
          targetSlotCount: 4,
          requiredLevel: 5,
          requiredSeasonPoints: 180,
          gemCost: 120,
        ),
      ];

  static TreasuryMetaState defaultMetaState({DateTime? now}) {
    final value = now ?? DateTime.now();
    final seasonKey = treasurySeasonKey(value);
    return TreasuryMetaState(
      level: 1,
      xp: 0,
      slotCount: 2,
      premiumSlotUnlocked: false,
      unlockedSkillIds: const <String>[],
      seasonKey: seasonKey,
      seasonPoints: 0,
      freeWithdrawalsRemaining: 0,
      eventShieldRemaining: 0,
      lastResolvedDayKey: '',
      liquidityStreakDays: 0,
      ladderHitCount: 0,
      cumulativeYieldRate: 0,
      weekKey: treasuryWeekKey(value),
      seasonRuns: 0,
      bestLadder: 0,
      seasonYieldAverage: 0,
      seasonLiquidityAverage: 0,
      seasonDisciplineAverage: 0,
      seasonFinalAverage: 0,
    );
  }

  static TreasuryMetaState normalizeMetaState(
    TreasuryMetaState state, {
    DateTime? now,
  }) {
    final value = now ?? DateTime.now();
    final seasonKey = treasurySeasonKey(value);
    final weekKey = treasuryWeekKey(value);
    final seasonReset = state.seasonKey != seasonKey;
    final hasFreeExitSkill = state.unlockedSkillIds.contains(
      kTreasurySkillFreeEarlyExit,
    );
    final hasShieldSkill = state.unlockedSkillIds.contains(
      kTreasurySkillEventShield,
    );
    final normalizedLevel = _levelForXp(state.xp);
    return state.copyWith(
      level: normalizedLevel,
      slotCount: state.slotCount.clamp(2, 4),
      premiumSlotUnlocked:
          state.premiumSlotUnlocked ||
          state.unlockedSkillIds.contains(kTreasurySkillPremiumSlot),
      seasonKey: seasonKey,
      seasonPoints: seasonReset ? 0 : state.seasonPoints,
      weekKey: weekKey,
      freeWithdrawalsRemaining:
          seasonReset
              ? (hasFreeExitSkill ? 1 : 0)
              : state.weekKey == weekKey
              ? state.freeWithdrawalsRemaining
              : (hasFreeExitSkill ? 1 : 0),
      eventShieldRemaining:
          seasonReset
              ? (hasShieldSkill ? 1 : 0)
              : state.weekKey == weekKey
              ? state.eventShieldRemaining
              : (hasShieldSkill ? 1 : 0),
      seasonRuns: seasonReset ? 0 : state.seasonRuns,
      bestLadder: seasonReset ? 0 : state.bestLadder,
      seasonYieldAverage: seasonReset ? 0 : state.seasonYieldAverage,
      seasonLiquidityAverage: seasonReset ? 0 : state.seasonLiquidityAverage,
      seasonDisciplineAverage: seasonReset ? 0 : state.seasonDisciplineAverage,
      seasonFinalAverage: seasonReset ? 0 : state.seasonFinalAverage,
    );
  }

  static TreasuryBoard buildBoard({
    required String uid,
    required String dayKey,
    required TreasuryMetaState metaState,
    required int rerollsUsed,
    DateTime? now,
  }) {
    final currentDate = now ?? DateTime.now();
    final regime = _regimeFor(uid: uid, dayKey: dayKey);
    final tomorrow = currentDate.add(const Duration(days: 1));
    final forecastTomorrow =
        metaState.unlockedSkillIds.contains(kTreasurySkillForecastTomorrow)
            ? _regimeFor(uid: uid, dayKey: treasuryDayKey(tomorrow))
            : null;
    final curve = _curveFor(regime);
    final offers = _buildOffers(
      uid: uid,
      dayKey: dayKey,
      rerollsUsed: rerollsUsed,
      regime: regime,
      curve: curve,
      metaState: metaState,
    );
    final events = _buildEvents(
      uid: uid,
      dayKey: dayKey,
      rerollsUsed: rerollsUsed,
      regime: regime,
    );
    final freeRerolls =
        1 +
        (metaState.unlockedSkillIds.contains(kTreasurySkillExtraReroll)
            ? 1
            : 0);
    return TreasuryBoard(
      dayKey: dayKey,
      regime: regime,
      offers: offers,
      events: events,
      rerollsLeft: math.max(0, freeRerolls - rerollsUsed),
      rerollsUsed: rerollsUsed,
      seasonKey: treasurySeasonKey(currentDate),
      shortRate: curve.$1,
      mediumRate: curve.$2,
      longRate: curve.$3,
      forecastTomorrow: forecastTomorrow,
      scoreBreakdown: null,
      resolvedAt: null,
    );
  }

  static TreasuryScoreBreakdown scoreTreasury({
    required TreasuryBoard board,
    required List<TreasuryPosition> positions,
    required int availableCoins,
    required TreasurySkillState skillState,
  }) {
    final activePositions =
        positions
            .where((position) => position.isActive && !position.isLegacy)
            .toList()
          ..sort((a, b) => a.maturesAt.compareTo(b.maturesAt));
    final invested = activePositions.fold<int>(
      0,
      (total, position) => total + position.principalCoins,
    );
    final realizedYield = activePositions.fold<double>(
      0,
      (total, position) =>
          total + (position.principalCoins * position.offerSnapshot.termRate),
    );
    final bestOffers = List<TreasuryOffer>.from(board.offers)
      ..sort((a, b) => b.termRate.compareTo(a.termRate));
    final comparableCount = math.min(
      bestOffers.length,
      math.max(1, activePositions.length),
    );
    final bestTermRate =
        comparableCount == 0
            ? 0.0
            : bestOffers
                    .take(comparableCount)
                    .fold<double>(0, (total, offer) => total + offer.termRate) /
                comparableCount;
    final capturedRate = invested <= 0 ? 0.0 : realizedYield / invested;
    final yieldScore =
        invested <= 0
            ? 24
            : ((capturedRate / math.max(0.001, bestTermRate)) * 100)
                .round()
                .clamp(0, 100);

    final requiredBuffer = board.events.fold<int>(
      0,
      (maxValue, event) => math.max(maxValue, event.requiredLiquidCoins),
    );
    final availableVsBuffer =
        requiredBuffer == 0
            ? 100.0
            : (availableCoins / requiredBuffer).clamp(0.0, 1.5);
    final shortagePenalty = board.events.fold<int>(
      0,
      (total, event) =>
          total +
          (availableCoins >= event.requiredLiquidCoins
              ? 0
              : event.penaltyCoins ~/ 4),
    );
    final liquidityScore = ((availableVsBuffer * 85) - shortagePenalty)
        .round()
        .clamp(0, 100);

    final distinctDurations =
        activePositions
            .map(
              (position) =>
                  _durationBucket(position.offerSnapshot.durationDays),
            )
            .toSet()
            .length;
    final brokenCount =
        activePositions.where((position) => position.brokenEarly).length;
    final concentrationRatio =
        invested <= 0
            ? 0.0
            : activePositions.fold<int>(
                  0,
                  (maxValue, position) =>
                      math.max(maxValue, position.principalCoins),
                ) /
                invested;
    var disciplineScore = 52 + (distinctDurations * 10) - (brokenCount * 18);
    if (concentrationRatio > 0.72) {
      disciplineScore -= 18;
    } else if (concentrationRatio > 0.56) {
      disciplineScore -= 10;
    } else {
      disciplineScore += 8;
    }
    disciplineScore = disciplineScore.clamp(0, 100);

    var ladderBonus = distinctDurations >= 3 ? 10 : 0;
    if (ladderBonus > 0 && skillState.hasSkill(kTreasurySkillLadderMaster)) {
      ladderBonus += 4;
    }
    ladderBonus = ladderBonus.clamp(0, 15);

    final finalScore = math.min(
      100,
      ((yieldScore * 0.4) + (liquidityScore * 0.35) + (disciplineScore * 0.25))
              .round() +
          ladderBonus,
    );

    return TreasuryScoreBreakdown(
      yieldScore: yieldScore,
      liquidityScore: liquidityScore,
      disciplineScore: disciplineScore,
      ladderBonus: ladderBonus,
      finalScore: finalScore,
      requiredLiquidBuffer: requiredBuffer,
      distinctMaturityCount: distinctDurations,
      debrief: _buildDebrief(
        board: board,
        yieldScore: yieldScore,
        liquidityScore: liquidityScore,
        disciplineScore: disciplineScore,
        distinctDurations: distinctDurations,
      ),
    );
  }

  static TreasuryResolutionPreview previewResolution({
    required TreasuryBoard board,
    required List<TreasuryPosition> positions,
    required int availableCoins,
    required TreasuryMetaState metaState,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final workingPositions = positions.map((position) => position).toList();
    var coinsBalance = availableCoins;
    var maturedPayoutCoins = 0;
    var bonusCoins = 0;
    var penaltyCoins = 0;
    var forcedBreakCoins = 0;
    var shieldUsed = false;
    final brokenPositionIds = <String>[];

    final updatedPositions = <TreasuryPosition>[];
    for (final position in workingPositions) {
      if (position.isLegacy || !position.isActive) {
        updatedPositions.add(position);
        continue;
      }
      if (position.maturesAt.isAfter(currentTime)) {
        updatedPositions.add(position);
        continue;
      }
      final payout =
          position.payoutCoins > 0
              ? position.payoutCoins
              : (position.principalCoins *
                      (1 + position.offerSnapshot.termRate))
                  .floor();
      maturedPayoutCoins += payout;
      coinsBalance += payout;
      updatedPositions.add(
        position.copyWith(status: 'settled', payoutCoins: payout),
      );
    }

    final stillActive =
        updatedPositions
            .where((position) => position.isActive && !position.isLegacy)
            .toList();

    final resolvedEvents = <TreasuryEvent>[];
    for (final event in board.events) {
      if (event.resolved) {
        resolvedEvents.add(event);
        continue;
      }
      if (coinsBalance >= event.requiredLiquidCoins) {
        coinsBalance += event.bonusCoins;
        bonusCoins += event.bonusCoins;
        resolvedEvents.add(event.copyWith(resolved: true));
        continue;
      }

      final shortage = event.requiredLiquidCoins - coinsBalance;
      final canShield =
          !shieldUsed &&
          metaState.unlockedSkillIds.contains(kTreasurySkillEventShield) &&
          metaState.eventShieldRemaining > 0 &&
          event.severity == TreasuryEventSeverity.high;
      if (canShield) {
        shieldUsed = true;
        resolvedEvents.add(event.copyWith(resolved: true));
        continue;
      }

      penaltyCoins += event.penaltyCoins;
      coinsBalance = math.max(0, coinsBalance - event.penaltyCoins);

      var remainingShortage = math.max(0, shortage - coinsBalance);
      if (remainingShortage > 0) {
        final breakable =
            stillActive..sort((a, b) => a.maturesAt.compareTo(b.maturesAt));
        for (final position in breakable) {
          if (!position.isFlexible || brokenPositionIds.contains(position.id)) {
            continue;
          }
          final recovered = (position.principalCoins * 0.92).floor();
          forcedBreakCoins += recovered;
          coinsBalance += recovered;
          remainingShortage = math.max(0, remainingShortage - recovered);
          brokenPositionIds.add(position.id);
          final updatedIndex = updatedPositions.indexWhere(
            (item) => item.id == position.id,
          );
          if (updatedIndex >= 0) {
            updatedPositions[updatedIndex] = updatedPositions[updatedIndex]
                .copyWith(
                  status: 'broken',
                  brokenEarly: true,
                  payoutCoins: recovered,
                );
          }
          if (remainingShortage == 0) {
            break;
          }
        }
      }

      resolvedEvents.add(event.copyWith(resolved: true));
    }

    final resolvedBoard = board.copyWith(events: resolvedEvents);
    final breakdown = scoreTreasury(
      board: resolvedBoard,
      positions: updatedPositions,
      availableCoins: coinsBalance,
      skillState: metaState.toSkillState(
        forecastTomorrow: board.forecastTomorrow,
      ),
    );

    return TreasuryResolutionPreview(
      newCoinsBalance: coinsBalance,
      maturedPayoutCoins: maturedPayoutCoins,
      bonusCoins: bonusCoins,
      penaltyCoins: penaltyCoins,
      forcedBreakCoins: forcedBreakCoins,
      brokenPositionIds: brokenPositionIds,
      updatedPositions: updatedPositions,
      shieldUsed: shieldUsed,
      scoreBreakdown: breakdown,
      summary: _resolutionSummary(
        maturedPayoutCoins: maturedPayoutCoins,
        bonusCoins: bonusCoins,
        penaltyCoins: penaltyCoins,
        forcedBreakCoins: forcedBreakCoins,
        brokenCount: brokenPositionIds.length,
      ),
    );
  }

  static int previewRerollGemCost({
    required TreasuryMetaState metaState,
    required TreasuryBoard board,
  }) {
    final freeRerolls =
        1 +
        (metaState.unlockedSkillIds.contains(kTreasurySkillExtraReroll)
            ? 1
            : 0);
    return board.rerollsUsed >= freeRerolls ? 20 : 0;
  }

  static int payoutForOffer(int principalCoins, TreasuryOffer offer) {
    return (principalCoins * (1 + offer.termRate)).floor();
  }

  static double opportunityCostForPosition({
    required TreasuryPosition position,
    required List<TreasuryOffer> offers,
  }) {
    final comparable =
        offers
            .where(
              (offer) =>
                  offer.durationDays == position.offerSnapshot.durationDays,
            )
            .toList();
    if (comparable.isEmpty) return 0;
    comparable.sort((a, b) => b.termRate.compareTo(a.termRate));
    final best = comparable.first.termRate;
    final current = position.offerSnapshot.termRate;
    if (best <= current) return 0;
    return position.principalCoins * (best - current);
  }

  static TreasuryPosition applyOpportunityCost(
    TreasuryPosition position,
    List<TreasuryOffer> offers,
  ) {
    return position.copyWith(
      opportunityCostCoins:
          opportunityCostForPosition(
            position: position,
            offers: offers,
          ).round(),
    );
  }

  static TreasuryPosition buildNewPosition({
    required String id,
    required int principalCoins,
    required TreasuryOffer offer,
    required DateTime now,
  }) {
    final maturesAt = now.add(Duration(days: offer.durationDays));
    return TreasuryPosition(
      id: id,
      principalCoins: principalCoins,
      offerSnapshot: offer,
      openedAt: now,
      maturesAt: maturesAt,
      status: 'active',
      brokenEarly: false,
      liquidityPenaltyPreview: 0,
      opportunityCostCoins: 0,
      payoutCoins: payoutForOffer(principalCoins, offer),
      isLegacy: false,
      legacyCurrencyType: 'coins',
      startDayKey: treasuryDayKey(now),
      maturesDayKey: treasuryDayKey(maturesAt),
    );
  }

  static int _levelForXp(int xp) {
    return (1 + (xp ~/ 180)).clamp(1, 12);
  }

  static TreasurySkillDefinition? skillDefinitionById(String id) {
    for (final definition in skillCatalog) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static bool meetsSkillRequirements({
    required TreasurySkillDefinition definition,
    required TreasuryMetaState metaState,
  }) {
    if (metaState.level < definition.requiredLevel) return false;
    if (metaState.seasonPoints < definition.requiredSeasonPoints) return false;
    if (definition.usesSeasonPointsCurrency &&
        metaState.seasonPoints < definition.seasonPointCost) {
      return false;
    }
    return true;
  }

  static TreasurySlotUpgradeDefinition? nextSlotUpgradeFor(
    TreasuryMetaState metaState,
  ) {
    for (final definition in slotUpgradeCatalog) {
      if (metaState.slotCount < definition.targetSlotCount) {
        return definition;
      }
    }
    return null;
  }

  static bool meetsSlotUpgradeRequirements({
    required TreasurySlotUpgradeDefinition definition,
    required TreasuryMetaState metaState,
  }) {
    if (metaState.slotCount >= definition.targetSlotCount) return false;
    if (metaState.level < definition.requiredLevel) return false;
    if (metaState.seasonPoints < definition.requiredSeasonPoints) return false;
    return true;
  }

  static TreasuryMarketRegime _regimeFor({
    required String uid,
    required String dayKey,
  }) {
    final seed = _seed('$uid|$dayKey|regime');
    final index = seed % TreasuryMarketRegime.values.length;
    return TreasuryMarketRegime.values[index];
  }

  static (double, double, double) _curveFor(TreasuryMarketRegime regime) {
    return switch (regime) {
      TreasuryMarketRegime.risingRates => (0.08, 0.16, 0.21),
      TreasuryMarketRegime.fallingRates => (0.06, 0.19, 0.28),
      TreasuryMarketRegime.invertedCurve => (0.17, 0.14, 0.12),
      TreasuryMarketRegime.bankingStress => (0.12, 0.16, 0.19),
      TreasuryMarketRegime.normalization => (0.07, 0.14, 0.20),
    };
  }

  static List<TreasuryOffer> _buildOffers({
    required String uid,
    required String dayKey,
    required int rerollsUsed,
    required TreasuryMarketRegime regime,
    required (double, double, double) curve,
    required TreasuryMetaState metaState,
  }) {
    final random = math.Random(_seed('$uid|$dayKey|offers|$rerollsUsed'));
    final shortDurations = <int>[2, 4, 6];
    final mediumDurations = <int>[8, 12, 16];
    final longDurations = <int>[20, 24, 28];
    final offers = <TreasuryOffer>[
      _makeOffer(
        id: 'simple_short',
        label: 'Simple court',
        productType: TreasuryProductType.simple,
        durationDays: shortDurations[random.nextInt(shortDurations.length)],
        apy: curve.$1,
        lockMode: TreasuryLockMode.standard,
      ),
      _makeOffer(
        id: 'flex_medium',
        label: 'Flexible moyen',
        productType: TreasuryProductType.flexible,
        durationDays: mediumDurations[random.nextInt(mediumDurations.length)],
        apy: curve.$2 - 0.03,
        lockMode: TreasuryLockMode.flexible,
      ),
      _makeOffer(
        id: 'locked_long',
        label: 'Verrouillé long',
        productType: TreasuryProductType.locked,
        durationDays: longDurations[random.nextInt(longDurations.length)],
        apy: curve.$3 + 0.03,
        lockMode: TreasuryLockMode.locked,
      ),
      _makeOffer(
        id: 'premium_curve',
        label: 'Premium de courbe',
        productType: TreasuryProductType.premium,
        durationDays: mediumDurations[random.nextInt(mediumDurations.length)],
        apy: (curve.$2 + curve.$3) / 2 + 0.05,
        lockMode: TreasuryLockMode.locked,
        requiresPremiumSlot: true,
      ),
      _makeOffer(
        id: 'boost_event',
        label: 'Boost événementiel',
        productType: TreasuryProductType.boosted,
        durationDays:
            shortDurations[random.nextInt(shortDurations.length)] +
            mediumDurations[random.nextInt(mediumDurations.length)] ~/ 2,
        apy: switch (regime) {
          TreasuryMarketRegime.risingRates => curve.$1 + 0.08,
          TreasuryMarketRegime.fallingRates => curve.$3 + 0.06,
          TreasuryMarketRegime.invertedCurve => curve.$1 + 0.09,
          TreasuryMarketRegime.bankingStress => curve.$2 + 0.07,
          TreasuryMarketRegime.normalization => curve.$2 + 0.05,
        },
        lockMode: TreasuryLockMode.standard,
        slotCost: 2,
        requiresPremiumSlot: true,
        boostReason: switch (regime) {
          TreasuryMarketRegime.risingRates =>
            'Le marché paie le cash court premium.',
          TreasuryMarketRegime.fallingRates =>
            'Le timing de duration est récompensé.',
          TreasuryMarketRegime.invertedCurve =>
            'Le board récompense le ladder opportuniste.',
          TreasuryMarketRegime.bankingStress =>
            'Le stress augmente la prime de flexibilité rare.',
          TreasuryMarketRegime.normalization =>
            'Prime technique sur une fenêtre de normalisation.',
        },
      ),
    ];
    return offers
        .map(
          (offer) => offer.copyWithApy(
            (offer.apy + (random.nextDouble() * 0.02) - 0.01).clamp(0.04, 0.42),
          ),
        )
        .toList();
  }

  static List<TreasuryEvent> _buildEvents({
    required String uid,
    required String dayKey,
    required int rerollsUsed,
    required TreasuryMarketRegime regime,
  }) {
    final random = math.Random(_seed('$uid|$dayKey|events|$rerollsUsed'));
    final baseBuffer = switch (regime) {
      TreasuryMarketRegime.risingRates => 300,
      TreasuryMarketRegime.fallingRates => 260,
      TreasuryMarketRegime.invertedCurve => 240,
      TreasuryMarketRegime.bankingStress => 420,
      TreasuryMarketRegime.normalization => 220,
    };
    return <TreasuryEvent>[
      TreasuryEvent(
        id: 'liquidity_${rerollsUsed}_0',
        title:
            regime == TreasuryMarketRegime.bankingStress
                ? 'Retraits clients soudains'
                : 'Fenêtre tactique de liquidité',
        description:
            regime == TreasuryMarketRegime.bankingStress
                ? 'Le board te force à conserver plus de cash pour absorber un choc de confiance.'
                : 'Un besoin de cash tactique peut capter un bonus si tu gardes assez de liquidité.',
        eventType:
            regime == TreasuryMarketRegime.bankingStress
                ? TreasuryEventType.marginShock
                : TreasuryEventType.bonusWindow,
        requiredLiquidCoins: baseBuffer + (random.nextInt(4) * 40),
        penaltyCoins: baseBuffer ~/ 3,
        bonusCoins: baseBuffer ~/ 5,
        severity:
            regime == TreasuryMarketRegime.bankingStress
                ? TreasuryEventSeverity.high
                : TreasuryEventSeverity.medium,
        resolved: false,
      ),
      TreasuryEvent(
        id: 'liquidity_${rerollsUsed}_1',
        title: switch (regime) {
          TreasuryMarketRegime.risingRates => 'Stress de refinancement court',
          TreasuryMarketRegime.fallingRates => 'Opportunité de duration',
          TreasuryMarketRegime.invertedCurve => 'Fenêtre de roulement',
          TreasuryMarketRegime.bankingStress => 'Appel de collatéral',
          TreasuryMarketRegime.normalization => 'Réallocation disciplinée',
        },
        description: switch (regime) {
          TreasuryMarketRegime.risingRates =>
            'Sans buffer, tu subis le coût d’un refinancement trop tardif.',
          TreasuryMarketRegime.fallingRates =>
            'Le marché récompense ceux qui ont gardé assez de cash pour allonger proprement.',
          TreasuryMarketRegime.invertedCurve =>
            'Le coût d’opportunité grimpe si tu es trop concentré sur une seule échéance.',
          TreasuryMarketRegime.bankingStress =>
            'Un choc sévère peut forcer la cassure d’un dépôt flexible si le cash manque.',
          TreasuryMarketRegime.normalization =>
            'La discipline est récompensée si tu peux arbitrer sans te tendre.',
        },
        eventType: TreasuryEventType.liquidityCall,
        requiredLiquidCoins: baseBuffer + 120 + (random.nextInt(3) * 50),
        penaltyCoins: baseBuffer ~/ 2,
        bonusCoins: baseBuffer ~/ 6,
        severity:
            regime == TreasuryMarketRegime.bankingStress
                ? TreasuryEventSeverity.high
                : TreasuryEventSeverity.medium,
        resolved: false,
      ),
    ];
  }

  static TreasuryOffer _makeOffer({
    required String id,
    required String label,
    required TreasuryProductType productType,
    required int durationDays,
    required double apy,
    required TreasuryLockMode lockMode,
    int slotCost = 1,
    bool requiresPremiumSlot = false,
    String? boostReason,
  }) {
    return TreasuryOffer(
      id: id,
      productType: productType,
      durationDays: durationDays,
      apy: apy,
      lockMode: lockMode,
      slotCost: slotCost,
      requiresPremiumSlot: requiresPremiumSlot,
      label: label,
      boostReason: boostReason,
    );
  }

  static int _durationBucket(int days) {
    if (days <= 7) return 0;
    if (days <= 18) return 1;
    return 2;
  }

  static String _buildDebrief({
    required TreasuryBoard board,
    required int yieldScore,
    required int liquidityScore,
    required int disciplineScore,
    required int distinctDurations,
  }) {
    if (liquidityScore < 45) {
      return 'Ton principal angle faible reste la liquidité: dans le régime ${board.regime.label.toLowerCase()}, garder un buffer cash était plus important que chasser le meilleur taux.';
    }
    if (disciplineScore < 45) {
      return 'Ta structure reste trop concentrée. Un bon trésorier aurait étagé davantage les maturités pour éviter de dépendre d’une seule grosse échéance.';
    }
    if (yieldScore < 45) {
      return 'Tu as protégé la liquidité mais laissé trop de rendement sur la table. Le board du jour permettait une meilleure capture de pente sans se sur-tendre.';
    }
    if (distinctDurations >= 3) {
      return 'Lecture propre de la courbe: ta structure en ladder absorbe mieux les chocs et garde du timing pour réallouer demain.';
    }
    return 'Structure saine mais perfectible: tu tiens le risque, cependant un ladder plus net aurait amélioré la discipline et le timing.';
  }

  static String _resolutionSummary({
    required int maturedPayoutCoins,
    required int bonusCoins,
    required int penaltyCoins,
    required int forcedBreakCoins,
    required int brokenCount,
  }) {
    final parts = <String>[];
    if (maturedPayoutCoins > 0) {
      parts.add('+$maturedPayoutCoins coins libérés à échéance');
    }
    if (bonusCoins > 0) {
      parts.add('+$bonusCoins de bonus de liquidité');
    }
    if (penaltyCoins > 0) {
      parts.add('-$penaltyCoins de pénalité');
    }
    if (brokenCount > 0) {
      parts.add(
        '$brokenCount dépôt(s) flexible(s) cassé(s) pour $forcedBreakCoins coins',
      );
    }
    if (parts.isEmpty) {
      return 'Aucun événement critique: la trésorerie a tenu sans friction majeure.';
    }
    return parts.join(' · ');
  }

  static int _seed(String raw) {
    var hash = 5381;
    for (final codeUnit in raw.codeUnits) {
      hash = ((hash << 5) + hash + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}

extension on TreasuryOffer {
  TreasuryOffer copyWithApy(double value) {
    return TreasuryOffer(
      id: id,
      productType: productType,
      durationDays: durationDays,
      apy: value,
      lockMode: lockMode,
      slotCost: slotCost,
      requiresPremiumSlot: requiresPremiumSlot,
      label: label,
      boostReason: boostReason,
    );
  }
}
