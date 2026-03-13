import 'package:cloud_firestore/cloud_firestore.dart';

enum TreasuryMarketRegime {
  risingRates,
  fallingRates,
  invertedCurve,
  bankingStress,
  normalization,
}

extension TreasuryMarketRegimeX on TreasuryMarketRegime {
  String get key => switch (this) {
    TreasuryMarketRegime.risingRates => 'taux_en_hausse',
    TreasuryMarketRegime.fallingRates => 'taux_en_baisse',
    TreasuryMarketRegime.invertedCurve => 'courbe_inversee',
    TreasuryMarketRegime.bankingStress => 'stress_bancaire',
    TreasuryMarketRegime.normalization => 'normalisation',
  };

  String get label => switch (this) {
    TreasuryMarketRegime.risingRates => 'Taux en hausse',
    TreasuryMarketRegime.fallingRates => 'Taux en baisse',
    TreasuryMarketRegime.invertedCurve => 'Courbe inversée',
    TreasuryMarketRegime.bankingStress => 'Stress bancaire',
    TreasuryMarketRegime.normalization => 'Normalisation',
  };

  String get description => switch (this) {
    TreasuryMarketRegime.risingRates =>
      'Le court terme domine. La liquidité devient précieuse et la duration longue est plus risquée.',
    TreasuryMarketRegime.fallingRates =>
      'Le long terme redevient attractif. Les produits plus longs paient mieux le bon timing.',
    TreasuryMarketRegime.invertedCurve =>
      'Le cash court paie presque autant que le moyen terme. Le laddering devient essentiel.',
    TreasuryMarketRegime.bankingStress =>
      'Les produits flexibles et le buffer liquide prennent de la valeur. Les événements sont plus durs.',
    TreasuryMarketRegime.normalization =>
      'Le marché récompense une structure propre, sans excès de duration ni de concentration.',
  };

  static TreasuryMarketRegime fromKey(String? raw) {
    return TreasuryMarketRegime.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => TreasuryMarketRegime.normalization,
    );
  }
}

enum TreasuryProductType { simple, flexible, locked, premium, boosted }

extension TreasuryProductTypeX on TreasuryProductType {
  String get key => switch (this) {
    TreasuryProductType.simple => 'simple',
    TreasuryProductType.flexible => 'flexible',
    TreasuryProductType.locked => 'locked',
    TreasuryProductType.premium => 'premium',
    TreasuryProductType.boosted => 'boosted',
  };

  String get label => switch (this) {
    TreasuryProductType.simple => 'Simple',
    TreasuryProductType.flexible => 'Flexible',
    TreasuryProductType.locked => 'Verrouillé',
    TreasuryProductType.premium => 'Premium',
    TreasuryProductType.boosted => 'Boosté',
  };

  static TreasuryProductType fromKey(String? raw) {
    return TreasuryProductType.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => TreasuryProductType.simple,
    );
  }
}

enum TreasuryLockMode { standard, flexible, locked }

extension TreasuryLockModeX on TreasuryLockMode {
  String get key => switch (this) {
    TreasuryLockMode.standard => 'standard',
    TreasuryLockMode.flexible => 'flexible',
    TreasuryLockMode.locked => 'locked',
  };

  static TreasuryLockMode fromKey(String? raw) {
    return TreasuryLockMode.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => TreasuryLockMode.standard,
    );
  }
}

enum TreasuryEventType { bonusWindow, liquidityCall, marginShock }

extension TreasuryEventTypeX on TreasuryEventType {
  String get key => switch (this) {
    TreasuryEventType.bonusWindow => 'bonus_window',
    TreasuryEventType.liquidityCall => 'liquidity_call',
    TreasuryEventType.marginShock => 'margin_shock',
  };

  String get label => switch (this) {
    TreasuryEventType.bonusWindow => 'Fenêtre d’opportunité',
    TreasuryEventType.liquidityCall => 'Besoin de liquidité',
    TreasuryEventType.marginShock => 'Choc de marge',
  };

  static TreasuryEventType fromKey(String? raw) {
    return TreasuryEventType.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => TreasuryEventType.liquidityCall,
    );
  }
}

enum TreasuryEventSeverity { low, medium, high }

extension TreasuryEventSeverityX on TreasuryEventSeverity {
  String get key => switch (this) {
    TreasuryEventSeverity.low => 'low',
    TreasuryEventSeverity.medium => 'medium',
    TreasuryEventSeverity.high => 'high',
  };

  String get label => switch (this) {
    TreasuryEventSeverity.low => 'Faible',
    TreasuryEventSeverity.medium => 'Modérée',
    TreasuryEventSeverity.high => 'Sévère',
  };

  static TreasuryEventSeverity fromKey(String? raw) {
    return TreasuryEventSeverity.values.firstWhere(
      (value) => value.key == raw,
      orElse: () => TreasuryEventSeverity.medium,
    );
  }
}

class TreasuryOffer {
  const TreasuryOffer({
    required this.id,
    required this.productType,
    required this.durationDays,
    required this.apy,
    required this.lockMode,
    required this.slotCost,
    required this.requiresPremiumSlot,
    required this.label,
    this.boostReason,
  });

  final String id;
  final TreasuryProductType productType;
  final int durationDays;
  final double apy;
  final TreasuryLockMode lockMode;
  final int slotCost;
  final bool requiresPremiumSlot;
  final String label;
  final String? boostReason;

  double get termRate => apy * (durationDays / 30);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'productType': productType.key,
    'durationDays': durationDays,
    'apy': apy,
    'lockMode': lockMode.key,
    'slotCost': slotCost,
    'requiresPremiumSlot': requiresPremiumSlot,
    'label': label,
    if (boostReason != null) 'boostReason': boostReason,
  };

  factory TreasuryOffer.fromMap(Map<String, dynamic> map) {
    return TreasuryOffer(
      id: (map['id'] as String?) ?? '',
      productType: TreasuryProductTypeX.fromKey(
        (map['productType'] as String?) ?? (map['type'] as String?),
      ),
      durationDays:
          (map['durationDays'] as num?)?.toInt() ??
          (map['duration_days'] as num?)?.toInt() ??
          0,
      apy:
          (map['apy'] as num?)?.toDouble() ??
          (map['rate'] as num?)?.toDouble() ??
          0,
      lockMode: TreasuryLockModeX.fromKey(map['lockMode'] as String?),
      slotCost: (map['slotCost'] as num?)?.toInt() ?? 1,
      requiresPremiumSlot: (map['requiresPremiumSlot'] as bool?) ?? false,
      label: (map['label'] as String?) ?? '',
      boostReason: map['boostReason'] as String?,
    );
  }
}

class TreasuryEvent {
  const TreasuryEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.requiredLiquidCoins,
    required this.penaltyCoins,
    required this.bonusCoins,
    required this.severity,
    required this.resolved,
  });

  final String id;
  final String title;
  final String description;
  final TreasuryEventType eventType;
  final int requiredLiquidCoins;
  final int penaltyCoins;
  final int bonusCoins;
  final TreasuryEventSeverity severity;
  final bool resolved;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'eventType': eventType.key,
    'requiredLiquidCoins': requiredLiquidCoins,
    'penaltyCoins': penaltyCoins,
    'bonusCoins': bonusCoins,
    'severity': severity.key,
    'resolved': resolved,
  };

  factory TreasuryEvent.fromMap(Map<String, dynamic> map) {
    return TreasuryEvent(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      eventType: TreasuryEventTypeX.fromKey(map['eventType'] as String?),
      requiredLiquidCoins: (map['requiredLiquidCoins'] as num?)?.toInt() ?? 0,
      penaltyCoins: (map['penaltyCoins'] as num?)?.toInt() ?? 0,
      bonusCoins: (map['bonusCoins'] as num?)?.toInt() ?? 0,
      severity: TreasuryEventSeverityX.fromKey(map['severity'] as String?),
      resolved: (map['resolved'] as bool?) ?? false,
    );
  }

  TreasuryEvent copyWith({bool? resolved}) {
    return TreasuryEvent(
      id: id,
      title: title,
      description: description,
      eventType: eventType,
      requiredLiquidCoins: requiredLiquidCoins,
      penaltyCoins: penaltyCoins,
      bonusCoins: bonusCoins,
      severity: severity,
      resolved: resolved ?? this.resolved,
    );
  }
}

class TreasuryScoreBreakdown {
  const TreasuryScoreBreakdown({
    required this.yieldScore,
    required this.liquidityScore,
    required this.disciplineScore,
    required this.ladderBonus,
    required this.finalScore,
    required this.requiredLiquidBuffer,
    required this.distinctMaturityCount,
    required this.debrief,
  });

  final int yieldScore;
  final int liquidityScore;
  final int disciplineScore;
  final int ladderBonus;
  final int finalScore;
  final int requiredLiquidBuffer;
  final int distinctMaturityCount;
  final String debrief;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'yieldScore': yieldScore,
    'liquidityScore': liquidityScore,
    'disciplineScore': disciplineScore,
    'ladderBonus': ladderBonus,
    'finalScore': finalScore,
    'requiredLiquidBuffer': requiredLiquidBuffer,
    'distinctMaturityCount': distinctMaturityCount,
    'debrief': debrief,
  };

  factory TreasuryScoreBreakdown.fromMap(Map<String, dynamic> map) {
    return TreasuryScoreBreakdown(
      yieldScore: (map['yieldScore'] as num?)?.toInt() ?? 0,
      liquidityScore: (map['liquidityScore'] as num?)?.toInt() ?? 0,
      disciplineScore: (map['disciplineScore'] as num?)?.toInt() ?? 0,
      ladderBonus: (map['ladderBonus'] as num?)?.toInt() ?? 0,
      finalScore: (map['finalScore'] as num?)?.toInt() ?? 0,
      requiredLiquidBuffer: (map['requiredLiquidBuffer'] as num?)?.toInt() ?? 0,
      distinctMaturityCount:
          (map['distinctMaturityCount'] as num?)?.toInt() ?? 0,
      debrief: (map['debrief'] as String?) ?? '',
    );
  }
}

class TreasuryBoard {
  const TreasuryBoard({
    required this.dayKey,
    required this.regime,
    required this.offers,
    required this.events,
    required this.rerollsLeft,
    required this.rerollsUsed,
    required this.seasonKey,
    required this.shortRate,
    required this.mediumRate,
    required this.longRate,
    this.forecastTomorrow,
    this.scoreBreakdown,
    this.resolvedAt,
  });

  final String dayKey;
  final TreasuryMarketRegime regime;
  final List<TreasuryOffer> offers;
  final List<TreasuryEvent> events;
  final int rerollsLeft;
  final int rerollsUsed;
  final String seasonKey;
  final double shortRate;
  final double mediumRate;
  final double longRate;
  final TreasuryMarketRegime? forecastTomorrow;
  final TreasuryScoreBreakdown? scoreBreakdown;
  final DateTime? resolvedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'dayKey': dayKey,
    'regime': regime.key,
    'offers': offers.map((offer) => offer.toMap()).toList(),
    'events': events.map((event) => event.toMap()).toList(),
    'rerollsLeft': rerollsLeft,
    'rerollsUsed': rerollsUsed,
    'seasonKey': seasonKey,
    'shortRate': shortRate,
    'mediumRate': mediumRate,
    'longRate': longRate,
    if (forecastTomorrow != null) 'forecastTomorrow': forecastTomorrow!.key,
    if (scoreBreakdown != null) 'scoreBreakdown': scoreBreakdown!.toMap(),
    if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
  };

  factory TreasuryBoard.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return TreasuryBoard(
      dayKey: (map['dayKey'] as String?) ?? '',
      regime: TreasuryMarketRegimeX.fromKey(map['regime'] as String?),
      offers:
          ((map['offers'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (entry) =>
                    TreasuryOffer.fromMap(Map<String, dynamic>.from(entry)),
              )
              .toList(),
      events:
          ((map['events'] as List<dynamic>?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (entry) =>
                    TreasuryEvent.fromMap(Map<String, dynamic>.from(entry)),
              )
              .toList(),
      rerollsLeft: (map['rerollsLeft'] as num?)?.toInt() ?? 0,
      rerollsUsed: (map['rerollsUsed'] as num?)?.toInt() ?? 0,
      seasonKey: (map['seasonKey'] as String?) ?? '',
      shortRate: (map['shortRate'] as num?)?.toDouble() ?? 0,
      mediumRate: (map['mediumRate'] as num?)?.toDouble() ?? 0,
      longRate: (map['longRate'] as num?)?.toDouble() ?? 0,
      forecastTomorrow:
          map['forecastTomorrow'] == null
              ? null
              : TreasuryMarketRegimeX.fromKey(
                map['forecastTomorrow'] as String?,
              ),
      scoreBreakdown:
          map['scoreBreakdown'] is Map<dynamic, dynamic>
              ? TreasuryScoreBreakdown.fromMap(
                Map<String, dynamic>.from(map['scoreBreakdown'] as Map),
              )
              : null,
      resolvedAt: parseDate(map['resolvedAt']),
    );
  }

  TreasuryBoard copyWith({
    List<TreasuryOffer>? offers,
    List<TreasuryEvent>? events,
    int? rerollsLeft,
    int? rerollsUsed,
    TreasuryScoreBreakdown? scoreBreakdown,
    DateTime? resolvedAt,
  }) {
    return TreasuryBoard(
      dayKey: dayKey,
      regime: regime,
      offers: offers ?? this.offers,
      events: events ?? this.events,
      rerollsLeft: rerollsLeft ?? this.rerollsLeft,
      rerollsUsed: rerollsUsed ?? this.rerollsUsed,
      seasonKey: seasonKey,
      shortRate: shortRate,
      mediumRate: mediumRate,
      longRate: longRate,
      forecastTomorrow: forecastTomorrow,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class TreasuryPosition {
  const TreasuryPosition({
    required this.id,
    required this.principalCoins,
    required this.offerSnapshot,
    required this.openedAt,
    required this.maturesAt,
    required this.status,
    required this.brokenEarly,
    required this.liquidityPenaltyPreview,
    required this.opportunityCostCoins,
    required this.payoutCoins,
    required this.isLegacy,
    required this.legacyCurrencyType,
    required this.startDayKey,
    required this.maturesDayKey,
  });

  final String id;
  final int principalCoins;
  final TreasuryOffer offerSnapshot;
  final DateTime openedAt;
  final DateTime maturesAt;
  final String status;
  final bool brokenEarly;
  final int liquidityPenaltyPreview;
  final int opportunityCostCoins;
  final int payoutCoins;
  final bool isLegacy;
  final String legacyCurrencyType;
  final String startDayKey;
  final String maturesDayKey;

  bool get isActive => status == 'active';
  bool get isFlexible =>
      offerSnapshot.lockMode == TreasuryLockMode.flexible ||
      offerSnapshot.productType == TreasuryProductType.flexible;
  bool get requiresPremiumSlot => offerSnapshot.requiresPremiumSlot;
  int get slotCost => offerSnapshot.slotCost;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'principalCoins': principalCoins,
    'productType': offerSnapshot.productType.key,
    'durationDays': offerSnapshot.durationDays,
    'apy': offerSnapshot.apy,
    'slotCost': offerSnapshot.slotCost,
    'requiresPremiumSlot': offerSnapshot.requiresPremiumSlot,
    'offerSnapshot': offerSnapshot.toMap(),
    'openedAt': Timestamp.fromDate(openedAt),
    'maturesAt': Timestamp.fromDate(maturesAt),
    'status': status,
    'brokenEarly': brokenEarly,
    'liquidityPenaltyPreview': liquidityPenaltyPreview,
    'opportunityCostCoins': opportunityCostCoins,
    'payoutCoins': payoutCoins,
    'isLegacy': isLegacy,
    'legacyCurrencyType': legacyCurrencyType,
    'startDayKey': startDayKey,
    'maturesDayKey': maturesDayKey,
    'start_date': Timestamp.fromDate(openedAt),
    'end_date': Timestamp.fromDate(maturesAt),
    'duration_days': offerSnapshot.durationDays,
    'rate': offerSnapshot.apy,
    'type': isLegacy ? legacyCurrencyType : 'coins',
    'amount': principalCoins,
  };

  factory TreasuryPosition.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? fallback;
      return fallback;
    }

    final hasNewShape =
        map['offerSnapshot'] is Map<dynamic, dynamic> ||
        map.containsKey('principalCoins');
    if (hasNewShape) {
      final openedAt = parseDate(
        map['openedAt'] ?? map['start_date'],
        DateTime.now(),
      );
      final maturesAt = parseDate(
        map['maturesAt'] ?? map['end_date'],
        openedAt,
      );
      return TreasuryPosition(
        id: id,
        principalCoins: (map['principalCoins'] as num?)?.toInt() ?? 0,
        offerSnapshot: TreasuryOffer.fromMap(
          Map<String, dynamic>.from(
            (map['offerSnapshot'] as Map<dynamic, dynamic>?) ?? const {},
          ),
        ),
        openedAt: openedAt,
        maturesAt: maturesAt,
        status: (map['status'] as String?) ?? 'active',
        brokenEarly: (map['brokenEarly'] as bool?) ?? false,
        liquidityPenaltyPreview:
            (map['liquidityPenaltyPreview'] as num?)?.toInt() ?? 0,
        opportunityCostCoins:
            (map['opportunityCostCoins'] as num?)?.toInt() ?? 0,
        payoutCoins: (map['payoutCoins'] as num?)?.toInt() ?? 0,
        isLegacy: (map['isLegacy'] as bool?) ?? false,
        legacyCurrencyType: (map['legacyCurrencyType'] as String?) ?? 'coins',
        startDayKey: (map['startDayKey'] as String?) ?? '',
        maturesDayKey: (map['maturesDayKey'] as String?) ?? '',
      );
    }

    final openedAt = parseDate(map['start_date'], DateTime.now());
    final maturesAt = parseDate(map['end_date'], openedAt);
    final rate = (map['rate'] as num?)?.toDouble() ?? 0;
    final durationDays =
        (map['duration_days'] as num?)?.toInt() ??
        mathMax(1, maturesAt.difference(openedAt).inDays);
    final legacyType = (map['type'] as String?) ?? 'coins';
    final principal = (map['amount'] as num?)?.toInt() ?? 0;
    final offer = TreasuryOffer(
      id: 'legacy_$id',
      productType: TreasuryProductType.simple,
      durationDays: durationDays,
      apy: rate,
      lockMode: TreasuryLockMode.standard,
      slotCost: 1,
      requiresPremiumSlot: legacyType == 'gems',
      label: legacyType == 'gems' ? 'Legacy Gems' : 'Legacy Simple',
      boostReason: null,
    );
    return TreasuryPosition(
      id: id,
      principalCoins: principal,
      offerSnapshot: offer,
      openedAt: openedAt,
      maturesAt: maturesAt,
      status: (map['status'] as String?) ?? 'active',
      brokenEarly: false,
      liquidityPenaltyPreview: 0,
      opportunityCostCoins: 0,
      payoutCoins: (principal * (1 + rate)).floor(),
      isLegacy: true,
      legacyCurrencyType: legacyType,
      startDayKey: '',
      maturesDayKey: '',
    );
  }

  TreasuryPosition copyWith({
    String? status,
    bool? brokenEarly,
    int? liquidityPenaltyPreview,
    int? opportunityCostCoins,
    int? payoutCoins,
  }) {
    return TreasuryPosition(
      id: id,
      principalCoins: principalCoins,
      offerSnapshot: offerSnapshot,
      openedAt: openedAt,
      maturesAt: maturesAt,
      status: status ?? this.status,
      brokenEarly: brokenEarly ?? this.brokenEarly,
      liquidityPenaltyPreview:
          liquidityPenaltyPreview ?? this.liquidityPenaltyPreview,
      opportunityCostCoins: opportunityCostCoins ?? this.opportunityCostCoins,
      payoutCoins: payoutCoins ?? this.payoutCoins,
      isLegacy: isLegacy,
      legacyCurrencyType: legacyCurrencyType,
      startDayKey: startDayKey,
      maturesDayKey: maturesDayKey,
    );
  }
}

class TreasurySkillState {
  const TreasurySkillState({
    required this.unlockedSkillIds,
    required this.forecastTomorrow,
    required this.freeEarlyExitWeekly,
    required this.extraReroll,
    required this.eventShieldRemaining,
    required this.premiumSlotUnlocked,
  });

  final List<String> unlockedSkillIds;
  final TreasuryMarketRegime? forecastTomorrow;
  final int freeEarlyExitWeekly;
  final int extraReroll;
  final int eventShieldRemaining;
  final bool premiumSlotUnlocked;

  bool hasSkill(String skillId) => unlockedSkillIds.contains(skillId);
}

class TreasuryMetaState {
  const TreasuryMetaState({
    required this.level,
    required this.xp,
    required this.slotCount,
    required this.premiumSlotUnlocked,
    required this.unlockedSkillIds,
    required this.seasonKey,
    required this.seasonPoints,
    required this.freeWithdrawalsRemaining,
    required this.eventShieldRemaining,
    required this.lastResolvedDayKey,
    required this.liquidityStreakDays,
    required this.ladderHitCount,
    required this.cumulativeYieldRate,
    required this.weekKey,
    required this.seasonRuns,
    required this.bestLadder,
    required this.seasonYieldAverage,
    required this.seasonLiquidityAverage,
    required this.seasonDisciplineAverage,
    required this.seasonFinalAverage,
  });

  final int level;
  final int xp;
  final int slotCount;
  final bool premiumSlotUnlocked;
  final List<String> unlockedSkillIds;
  final String seasonKey;
  final int seasonPoints;
  final int freeWithdrawalsRemaining;
  final int eventShieldRemaining;
  final String lastResolvedDayKey;
  final int liquidityStreakDays;
  final int ladderHitCount;
  final double cumulativeYieldRate;
  final String weekKey;
  final int seasonRuns;
  final int bestLadder;
  final double seasonYieldAverage;
  final double seasonLiquidityAverage;
  final double seasonDisciplineAverage;
  final double seasonFinalAverage;

  TreasurySkillState toSkillState({TreasuryMarketRegime? forecastTomorrow}) {
    return TreasurySkillState(
      unlockedSkillIds: unlockedSkillIds,
      forecastTomorrow: forecastTomorrow,
      freeEarlyExitWeekly: freeWithdrawalsRemaining,
      extraReroll: unlockedSkillIds.contains('extra_reroll_daily') ? 1 : 0,
      eventShieldRemaining: eventShieldRemaining,
      premiumSlotUnlocked:
          premiumSlotUnlocked ||
          unlockedSkillIds.contains('premium_slot_unlock'),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'level': level,
    'xp': xp,
    'slotCount': slotCount,
    'premiumSlotUnlocked': premiumSlotUnlocked,
    'unlockedSkillIds': unlockedSkillIds,
    'seasonKey': seasonKey,
    'seasonPoints': seasonPoints,
    'freeWithdrawalsRemaining': freeWithdrawalsRemaining,
    'eventShieldRemaining': eventShieldRemaining,
    'lastResolvedDayKey': lastResolvedDayKey,
    'liquidityStreakDays': liquidityStreakDays,
    'ladderHitCount': ladderHitCount,
    'cumulativeYieldRate': cumulativeYieldRate,
    'weekKey': weekKey,
    'seasonRuns': seasonRuns,
    'bestLadder': bestLadder,
    'seasonYieldAverage': seasonYieldAverage,
    'seasonLiquidityAverage': seasonLiquidityAverage,
    'seasonDisciplineAverage': seasonDisciplineAverage,
    'seasonFinalAverage': seasonFinalAverage,
  };

  factory TreasuryMetaState.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return TreasuryMetaState(
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      slotCount: (data['slotCount'] as num?)?.toInt() ?? 2,
      premiumSlotUnlocked: (data['premiumSlotUnlocked'] as bool?) ?? false,
      unlockedSkillIds:
          ((data['unlockedSkillIds'] as List<dynamic>?) ?? const [])
              .map((entry) => entry.toString())
              .toList(),
      seasonKey: (data['seasonKey'] as String?) ?? '',
      seasonPoints: (data['seasonPoints'] as num?)?.toInt() ?? 0,
      freeWithdrawalsRemaining:
          (data['freeWithdrawalsRemaining'] as num?)?.toInt() ?? 0,
      eventShieldRemaining:
          (data['eventShieldRemaining'] as num?)?.toInt() ?? 0,
      lastResolvedDayKey: (data['lastResolvedDayKey'] as String?) ?? '',
      liquidityStreakDays: (data['liquidityStreakDays'] as num?)?.toInt() ?? 0,
      ladderHitCount: (data['ladderHitCount'] as num?)?.toInt() ?? 0,
      cumulativeYieldRate:
          (data['cumulativeYieldRate'] as num?)?.toDouble() ?? 0,
      weekKey: (data['weekKey'] as String?) ?? '',
      seasonRuns: (data['seasonRuns'] as num?)?.toInt() ?? 0,
      bestLadder: (data['bestLadder'] as num?)?.toInt() ?? 0,
      seasonYieldAverage: (data['seasonYieldAverage'] as num?)?.toDouble() ?? 0,
      seasonLiquidityAverage:
          (data['seasonLiquidityAverage'] as num?)?.toDouble() ?? 0,
      seasonDisciplineAverage:
          (data['seasonDisciplineAverage'] as num?)?.toDouble() ?? 0,
      seasonFinalAverage: (data['seasonFinalAverage'] as num?)?.toDouble() ?? 0,
    );
  }

  TreasuryMetaState copyWith({
    int? level,
    int? xp,
    int? slotCount,
    bool? premiumSlotUnlocked,
    List<String>? unlockedSkillIds,
    String? seasonKey,
    int? seasonPoints,
    int? freeWithdrawalsRemaining,
    int? eventShieldRemaining,
    String? lastResolvedDayKey,
    int? liquidityStreakDays,
    int? ladderHitCount,
    double? cumulativeYieldRate,
    String? weekKey,
    int? seasonRuns,
    int? bestLadder,
    double? seasonYieldAverage,
    double? seasonLiquidityAverage,
    double? seasonDisciplineAverage,
    double? seasonFinalAverage,
  }) {
    return TreasuryMetaState(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      slotCount: slotCount ?? this.slotCount,
      premiumSlotUnlocked: premiumSlotUnlocked ?? this.premiumSlotUnlocked,
      unlockedSkillIds: unlockedSkillIds ?? this.unlockedSkillIds,
      seasonKey: seasonKey ?? this.seasonKey,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      freeWithdrawalsRemaining:
          freeWithdrawalsRemaining ?? this.freeWithdrawalsRemaining,
      eventShieldRemaining: eventShieldRemaining ?? this.eventShieldRemaining,
      lastResolvedDayKey: lastResolvedDayKey ?? this.lastResolvedDayKey,
      liquidityStreakDays: liquidityStreakDays ?? this.liquidityStreakDays,
      ladderHitCount: ladderHitCount ?? this.ladderHitCount,
      cumulativeYieldRate: cumulativeYieldRate ?? this.cumulativeYieldRate,
      weekKey: weekKey ?? this.weekKey,
      seasonRuns: seasonRuns ?? this.seasonRuns,
      bestLadder: bestLadder ?? this.bestLadder,
      seasonYieldAverage: seasonYieldAverage ?? this.seasonYieldAverage,
      seasonLiquidityAverage:
          seasonLiquidityAverage ?? this.seasonLiquidityAverage,
      seasonDisciplineAverage:
          seasonDisciplineAverage ?? this.seasonDisciplineAverage,
      seasonFinalAverage: seasonFinalAverage ?? this.seasonFinalAverage,
    );
  }
}

class TreasuryResolutionPreview {
  const TreasuryResolutionPreview({
    required this.newCoinsBalance,
    required this.maturedPayoutCoins,
    required this.bonusCoins,
    required this.penaltyCoins,
    required this.forcedBreakCoins,
    required this.brokenPositionIds,
    required this.updatedPositions,
    required this.shieldUsed,
    required this.scoreBreakdown,
    required this.summary,
  });

  final int newCoinsBalance;
  final int maturedPayoutCoins;
  final int bonusCoins;
  final int penaltyCoins;
  final int forcedBreakCoins;
  final List<String> brokenPositionIds;
  final List<TreasuryPosition> updatedPositions;
  final bool shieldUsed;
  final TreasuryScoreBreakdown scoreBreakdown;
  final String summary;
}

int mathMax(int a, int b) => a > b ? a : b;
