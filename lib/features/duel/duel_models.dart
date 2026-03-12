import 'package:cloud_firestore/cloud_firestore.dart';

class DuelHolding {
  const DuelHolding({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
    required this.marketPrice,
    required this.marketValue,
    required this.displayName,
    required this.exchange,
    required this.currency,
    required this.quoteType,
  });

  final String symbol;
  final double quantity;
  final double averagePrice;
  final double marketPrice;
  final double marketValue;
  final String displayName;
  final String exchange;
  final String currency;
  final String quoteType;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'symbol': symbol,
      'quantity': quantity,
      'averagePrice': averagePrice,
      'marketPrice': marketPrice,
      'marketValue': marketValue,
      'displayName': displayName,
      'exchange': exchange,
      'currency': currency,
      'quoteType': quoteType,
    };
  }

  factory DuelHolding.fromMap(Map<String, dynamic> data) {
    return DuelHolding(
      symbol: (data['symbol'] as String? ?? '').trim(),
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      averagePrice: (data['averagePrice'] as num?)?.toDouble() ?? 0,
      marketPrice: (data['marketPrice'] as num?)?.toDouble() ?? 0,
      marketValue: (data['marketValue'] as num?)?.toDouble() ?? 0,
      displayName: (data['displayName'] as String? ?? '').trim(),
      exchange: (data['exchange'] as String? ?? '').trim(),
      currency: (data['currency'] as String? ?? '').trim(),
      quoteType: (data['quoteType'] as String? ?? '').trim(),
    );
  }
}

class DuelProfile {
  const DuelProfile({
    required this.uid,
    required this.displayName,
    required this.avatarId,
    required this.level,
    required this.reserveCoins,
    required this.holdingsValueEstimate,
    required this.positionsCount,
    required this.eligible,
    required this.state,
    required this.currentRequestId,
    required this.currentDuelId,
    required this.lastActiveAt,
    required this.lastSyncedAt,
  });

  final String uid;
  final String displayName;
  final String? avatarId;
  final int level;
  final double reserveCoins;
  final double holdingsValueEstimate;
  final int positionsCount;
  final bool eligible;
  final String state;
  final String? currentRequestId;
  final String? currentDuelId;
  final DateTime? lastActiveAt;
  final DateTime? lastSyncedAt;

  bool get isIdle => state == 'idle';
  bool get isPendingSent => state == 'pending_sent';
  bool get isPendingReceived => state == 'pending_received';
  bool get isActiveDuel => state == 'active_duel';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'displayName': displayName,
      'avatarId': avatarId,
      'level': level,
      'reserveCoins': reserveCoins,
      'holdingsValueEstimate': holdingsValueEstimate,
      'positionsCount': positionsCount,
      'eligible': eligible,
      'state': state,
      'currentRequestId': currentRequestId,
      'currentDuelId': currentDuelId,
      'lastActiveAt':
          lastActiveAt == null ? null : Timestamp.fromDate(lastActiveAt!),
      'lastSyncedAt':
          lastSyncedAt == null ? null : Timestamp.fromDate(lastSyncedAt!),
    };
  }

  factory DuelProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>>? doc, {
    required String fallbackUid,
  }) {
    final data = doc?.data() ?? const <String, dynamic>{};
    return DuelProfile(
      uid: doc?.id ?? fallbackUid,
      displayName: (data['displayName'] as String? ?? 'Joueur').trim(),
      avatarId: data['avatarId'] as String?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      reserveCoins: (data['reserveCoins'] as num?)?.toDouble() ?? 0,
      holdingsValueEstimate:
          (data['holdingsValueEstimate'] as num?)?.toDouble() ?? 0,
      positionsCount: (data['positionsCount'] as num?)?.toInt() ?? 0,
      eligible: data['eligible'] == true,
      state: (data['state'] as String? ?? 'idle').trim(),
      currentRequestId: (data['currentRequestId'] as String?)?.trim(),
      currentDuelId: (data['currentDuelId'] as String?)?.trim(),
      lastActiveAt: _dateFromAny(data['lastActiveAt']),
      lastSyncedAt: _dateFromAny(data['lastSyncedAt']),
    );
  }
}

class DuelRequest {
  const DuelRequest({
    required this.id,
    required this.initiatorUid,
    required this.targetUid,
    required this.status,
    required this.createdAt,
    required this.responseDeadline,
    required this.matchScore,
    required this.initiatorSnapshot,
    required this.targetSnapshot,
    required this.duelId,
    required this.invitePushSentAt,
    required this.resolutionNotifiedAt,
  });

  final String id;
  final String initiatorUid;
  final String targetUid;
  final String status;
  final DateTime? createdAt;
  final DateTime? responseDeadline;
  final double matchScore;
  final Map<String, dynamic> initiatorSnapshot;
  final Map<String, dynamic> targetSnapshot;
  final String? duelId;
  final DateTime? invitePushSentAt;
  final DateTime? resolutionNotifiedAt;

  bool get isPendingResponse => status == 'pending_response';

  factory DuelRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DuelRequest(
      id: doc.id,
      initiatorUid: (data['initiatorUid'] as String? ?? '').trim(),
      targetUid: (data['targetUid'] as String? ?? '').trim(),
      status: (data['status'] as String? ?? 'pending_response').trim(),
      createdAt: _dateFromAny(data['createdAt']),
      responseDeadline: _dateFromAny(data['responseDeadline']),
      matchScore: (data['matchScore'] as num?)?.toDouble() ?? 999,
      initiatorSnapshot: Map<String, dynamic>.from(
        data['initiatorSnapshot'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      targetSnapshot: Map<String, dynamic>.from(
        data['targetSnapshot'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      duelId: (data['duelId'] as String?)?.trim(),
      invitePushSentAt: _dateFromAny(data['invitePushSentAt']),
      resolutionNotifiedAt: _dateFromAny(data['resolutionNotifiedAt']),
    );
  }
}

class DuelParticipant {
  const DuelParticipant({
    required this.uid,
    required this.startingHoldingsValue,
    required this.startingReserveCoins,
    required this.startingTotalCapital,
    required this.startingPositionsCount,
    required this.currentHoldingsValueCache,
    required this.currentTotalCapitalCache,
    required this.currentReserveCoinsCache,
    required this.currentUpdatedAt,
    required this.currentPositionsCountCache,
    required this.currentReturnPctCache,
    required this.currentScoreCache,
    required this.finalReturnPct,
    required this.finalScore,
    required this.structureBonus,
    required this.concentrationPenalty,
    required this.result,
    required this.rewardClaimedAt,
    required this.resultDismissedAt,
    required this.rewardPosition,
    required this.lossPosition,
    required this.teaserLine,
    required this.performanceRevealTier,
    required this.positionsCountRevealedAt,
    required this.revealedLine,
    required this.spyCoinsSpent,
  });

  final String uid;
  final double startingHoldingsValue;
  final double startingReserveCoins;
  final double startingTotalCapital;
  final int startingPositionsCount;
  final double? currentHoldingsValueCache;
  final double? currentTotalCapitalCache;
  final double? currentReserveCoinsCache;
  final DateTime? currentUpdatedAt;
  final int? currentPositionsCountCache;
  final double? currentReturnPctCache;
  final double? currentScoreCache;
  final double? finalReturnPct;
  final double? finalScore;
  final double? structureBonus;
  final double? concentrationPenalty;
  final String? result;
  final DateTime? rewardClaimedAt;
  final DateTime? resultDismissedAt;
  final Map<String, dynamic>? rewardPosition;
  final Map<String, dynamic>? lossPosition;
  final Map<String, dynamic>? teaserLine;
  final int performanceRevealTier;
  final DateTime? positionsCountRevealedAt;
  final Map<String, dynamic>? revealedLine;
  final double spyCoinsSpent;

  bool get isWinner => result == 'win';
  bool get isLoser => result == 'lose';
  bool get hasUnlockedPositionsCount => positionsCountRevealedAt != null;
  bool get hasUnlockedLine => revealedLine != null;
  bool get hasMaxPerformanceReveal => performanceRevealTier >= 3;

  factory DuelParticipant.fromDoc(
    DocumentSnapshot<Map<String, dynamic>>? doc, {
    required String uid,
  }) {
    final data = doc?.data() ?? const <String, dynamic>{};
    return DuelParticipant(
      uid: uid,
      startingHoldingsValue:
          (data['startingHoldingsValue'] as num?)?.toDouble() ?? 0,
      startingReserveCoins:
          (data['startingReserveCoins'] as num?)?.toDouble() ?? 0,
      startingTotalCapital:
          (data['startingTotalCapital'] as num?)?.toDouble() ?? 0,
      startingPositionsCount:
          (data['startingPositionsCount'] as num?)?.toInt() ?? 0,
      currentHoldingsValueCache:
          (data['currentHoldingsValueCache'] as num?)?.toDouble(),
      currentTotalCapitalCache:
          (data['currentTotalCapitalCache'] as num?)?.toDouble(),
      currentReserveCoinsCache:
          (data['currentReserveCoinsCache'] as num?)?.toDouble(),
      currentUpdatedAt: _dateFromAny(data['currentUpdatedAt']),
      currentPositionsCountCache:
          (data['currentPositionsCountCache'] as num?)?.toInt(),
      currentReturnPctCache:
          (data['currentReturnPctCache'] as num?)?.toDouble(),
      currentScoreCache: (data['currentScoreCache'] as num?)?.toDouble(),
      finalReturnPct: (data['finalReturnPct'] as num?)?.toDouble(),
      finalScore: (data['finalScore'] as num?)?.toDouble(),
      structureBonus: (data['structureBonus'] as num?)?.toDouble(),
      concentrationPenalty: (data['concentrationPenalty'] as num?)?.toDouble(),
      result: (data['result'] as String?)?.trim(),
      rewardClaimedAt: _dateFromAny(data['rewardClaimedAt']),
      resultDismissedAt: _dateFromAny(data['resultDismissedAt']),
      rewardPosition:
          data['rewardPosition'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                data['rewardPosition'] as Map<String, dynamic>,
              )
              : null,
      lossPosition:
          data['lossPosition'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                data['lossPosition'] as Map<String, dynamic>,
              )
              : null,
      teaserLine:
          data['teaserLine'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                data['teaserLine'] as Map<String, dynamic>,
              )
              : null,
      performanceRevealTier:
          (data['performanceRevealTier'] as num?)?.toInt() ?? 0,
      positionsCountRevealedAt: _dateFromAny(data['positionsCountRevealedAt']),
      revealedLine:
          data['revealedLine'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                data['revealedLine'] as Map<String, dynamic>,
              )
              : null,
      spyCoinsSpent: (data['spyCoinsSpent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DuelData {
  const DuelData({
    required this.id,
    required this.status,
    required this.participants,
    required this.acceptedAt,
    required this.endsAt,
    required this.settledAt,
    required this.winnerUid,
    required this.loserUid,
    required this.scoringMode,
    required this.resultAnimationReady,
    required this.resultNotifiedAt,
  });

  final String id;
  final String status;
  final List<String> participants;
  final DateTime? acceptedAt;
  final DateTime? endsAt;
  final DateTime? settledAt;
  final String? winnerUid;
  final String? loserUid;
  final String scoringMode;
  final bool resultAnimationReady;
  final DateTime? resultNotifiedAt;

  bool get isActive => status == 'active';
  bool get isSettled =>
      status == 'settled' || status == 'reward_revealed' || status == 'closed';

  factory DuelData.fromDoc(DocumentSnapshot<Map<String, dynamic>>? doc) {
    final data = doc?.data() ?? const <String, dynamic>{};
    return DuelData(
      id: doc?.id ?? '',
      status: (data['status'] as String? ?? 'active').trim(),
      participants:
          (data['participants'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(),
      acceptedAt: _dateFromAny(data['acceptedAt']),
      endsAt: _dateFromAny(data['endsAt']),
      settledAt: _dateFromAny(data['settledAt']),
      winnerUid: (data['winnerUid'] as String?)?.trim(),
      loserUid: (data['loserUid'] as String?)?.trim(),
      scoringMode: (data['scoringMode'] as String? ?? 'hybrid_v1').trim(),
      resultAnimationReady: data['resultAnimationReady'] != false,
      resultNotifiedAt: _dateFromAny(data['resultNotifiedAt']),
    );
  }
}

class DuelLiveMetrics {
  const DuelLiveMetrics({
    required this.holdingsValue,
    required this.reserveCoins,
    required this.totalCapital,
    required this.returnPct,
    required this.structureBonus,
    required this.concentrationPenalty,
    required this.score,
    required this.positionsCount,
    required this.maxPositionWeight,
    required this.holdings,
  });

  final double holdingsValue;
  final double reserveCoins;
  final double totalCapital;
  final double returnPct;
  final double structureBonus;
  final double concentrationPenalty;
  final double score;
  final int positionsCount;
  final double maxPositionWeight;
  final List<DuelHolding> holdings;
}

DateTime? _dateFromAny(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}
