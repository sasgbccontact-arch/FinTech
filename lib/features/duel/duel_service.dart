import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:fintech/features/duel/duel_models.dart';
import 'package:fintech/services/yahoo_finance_service.dart';

class DuelException implements Exception {
  DuelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DuelService {
  DuelService._();

  static const double minEligibleHoldingsValue = 10000;
  static const double closeMatchThreshold = 0.38;
  static const Duration responseWindow = Duration(days: 2);
  static const Duration duelDuration = Duration(days: 7);
  static const Duration activeProfileWindow = Duration(days: 14);
  static const List<int> performanceRevealCosts = <int>[250, 500, 900];
  static const int positionsRevealCost = 650;
  static const int lineRevealCost = 1400;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final math.Random _random = math.Random();

  static void _log(String message) {
    debugPrint('[Duel] $message');
  }

  static CollectionReference<Map<String, dynamic>> _positionsRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('portofolio')
        .collection('positions');
  }

  static DocumentReference<Map<String, dynamic>> duelProfileRef(String uid) {
    return _firestore.collection('duel_profiles').doc(uid);
  }

  static DocumentReference<Map<String, dynamic>> duelRequestRef(
    String requestId,
  ) {
    return _firestore.collection('duel_requests').doc(requestId);
  }

  static DocumentReference<Map<String, dynamic>> duelRef(String duelId) {
    return _firestore.collection('duels').doc(duelId);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(
    String uid,
  ) {
    return duelProfileRef(uid).snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchDuel(
    String duelId,
  ) {
    return duelRef(duelId).snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRequest(
    String requestId,
  ) {
    return duelRequestRef(requestId).snapshots();
  }

  static Future<DuelProfile> syncCurrentUserProfile({
    String? uid,
    bool bumpActivity = true,
  }) async {
    final currentUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw DuelException('Utilisateur non connecté.');
    }
    _log(
      'syncCurrentUserProfile: uid=$currentUid bumpActivity=$bumpActivity start',
    );

    final now = DateTime.now();
    final userRef = _firestore.collection('users').doc(currentUid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final existingProfileDoc = await duelProfileRef(currentUid).get();
    final existingProfile = DuelProfile.fromDoc(
      existingProfileDoc,
      fallbackUid: currentUid,
    );
    final holdings = await fetchGameHoldings(
      currentUid,
      updatePositionDocs: true,
    );
    final holdingsValue = holdings.fold<double>(
      0,
      (total, holding) => total + holding.marketValue,
    );
    final positionsCount =
        holdings.where((holding) => holding.quantity > 0).length;
    final level = _levelFromXp((userData['xp'] as num?)?.toInt() ?? 0);
    final reserveCoins = (userData['coins'] as num?)?.toDouble() ?? 0;
    final nextState = _normalizeProfileState(existingProfile.state);
    final eligible =
        nextState == 'idle' &&
        holdingsValue >= minEligibleHoldingsValue &&
        positionsCount >= 1;

    await duelProfileRef(currentUid).set({
      'displayName': _displayName(userData),
      'avatarId': userData['avatar_id'],
      'level': level,
      'reserveCoins': reserveCoins,
      'holdingsValueEstimate': holdingsValue,
      'positionsCount': positionsCount,
      'eligible': eligible,
      'state': nextState,
      'currentRequestId': existingProfile.currentRequestId,
      'currentDuelId': existingProfile.currentDuelId,
      'lastActiveAt':
          bumpActivity
              ? Timestamp.fromDate(now)
              : (existingProfile.lastActiveAt == null
                  ? null
                  : Timestamp.fromDate(existingProfile.lastActiveAt!)),
      'lastSyncedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    final refreshed = await duelProfileRef(currentUid).get();
    _log(
      'syncCurrentUserProfile: uid=$currentUid state=$nextState eligible=$eligible holdings=$holdingsValue positions=$positionsCount reserve=$reserveCoins',
    );
    return DuelProfile.fromDoc(refreshed, fallbackUid: currentUid);
  }

  static Future<List<DuelHolding>> fetchGameHoldings(
    String uid, {
    bool updatePositionDocs = false,
  }) async {
    _log('fetchGameHoldings: uid=$uid updatePositionDocs=$updatePositionDocs');
    final positionsSnap = await _positionsRef(uid).get();
    if (positionsSnap.docs.isEmpty) return const <DuelHolding>[];

    final holdings = <DuelHolding>[];
    final batch = updatePositionDocs ? _firestore.batch() : null;

    for (final doc in positionsSnap.docs) {
      final data = doc.data();
      final symbol = (data['symbol'] as String? ?? doc.id).trim();
      if (symbol.isEmpty) continue;
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      if (quantity <= 0) continue;
      final averagePrice = (data['averagePrice'] as num?)?.toDouble() ?? 0;

      QuoteDetail? quote;
      try {
        quote = await YahooFinanceService.fetchQuote(symbol);
      } catch (error) {
        debugPrint('[Duel] Quote indisponible pour $symbol: $error');
      }

      final marketPrice =
          quote?.regularMarketPrice ??
          (data['regularMarketPrice'] as num?)?.toDouble() ??
          averagePrice;
      final displayName =
          (quote?.longName ?? quote?.shortName)?.trim().isNotEmpty == true
              ? (quote?.longName ?? quote?.shortName)!.trim()
              : (data['displayName'] as String? ?? symbol).trim();
      final exchange =
          (quote?.fullExchangeName ?? quote?.exchange)?.trim() ??
          (data['exchange'] as String? ?? '').trim();
      final currency =
          (quote?.currency)?.trim() ??
          (data['currency'] as String? ?? '').trim();
      final quoteType =
          (quote?.quoteType)?.trim() ??
          (data['quoteType'] as String? ?? 'UNKNOWN').trim();

      final holding = DuelHolding(
        symbol: symbol,
        quantity: quantity,
        averagePrice: averagePrice,
        marketPrice: marketPrice,
        marketValue: marketPrice * quantity,
        displayName: displayName.isEmpty ? symbol : displayName,
        exchange: exchange,
        currency: currency,
        quoteType: quoteType,
      );
      holdings.add(holding);

      if (batch != null) {
        batch.set(doc.reference, {
          'displayName': holding.displayName,
          'exchange': holding.exchange,
          'currency': holding.currency,
          'quoteType': holding.quoteType,
          'regularMarketPrice': holding.marketPrice,
          'lastQuotedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    if (batch != null) {
      await batch.commit();
    }
    _log('fetchGameHoldings: uid=$uid holdings=${holdings.length}');
    return holdings;
  }

  static Future<DuelRequest> startMatchmaking() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw DuelException('Utilisateur non connecté.');
    }
    _log('startMatchmaking: uid=$uid');

    final profile = await syncCurrentUserProfile(uid: uid, bumpActivity: true);
    if (!profile.eligible) {
      _log(
        'startMatchmaking: profil non eligible uid=$uid holdings=${profile.holdingsValueEstimate} positions=${profile.positionsCount} state=${profile.state}',
      );
      throw DuelException(
        'Le duel est réservé aux portefeuilles de jeu avec au moins 10k coins de valeur et 1 ligne minimum.',
      );
    }

    final candidatesSnap =
        await _firestore
            .collection('duel_profiles')
            .where('eligible', isEqualTo: true)
            .orderBy('lastActiveAt', descending: true)
            .limit(80)
            .get();

    final now = DateTime.now();
    final candidates =
        candidatesSnap.docs
            .map((doc) => DuelProfile.fromDoc(doc, fallbackUid: doc.id))
            .where((candidate) => candidate.uid != uid)
            .where((candidate) => candidate.isIdle)
            .where(
              (candidate) =>
                  candidate.lastActiveAt != null &&
                  now.difference(candidate.lastActiveAt!) <=
                      activeProfileWindow,
            )
            .toList();

    _log('startMatchmaking: uid=$uid candidatsEligibles=${candidates.length}');
    if (candidates.isEmpty) {
      _log('startMatchmaking: aucun candidat recent disponible uid=$uid');
      throw DuelException(
        'Aucun adversaire proche de ton niveau de portefeuille n’est disponible pour le moment.',
      );
    }

    candidates.sort(
      (left, right) =>
          _matchScore(profile, left).compareTo(_matchScore(profile, right)),
    );
    final bestScore = _matchScore(profile, candidates.first);
    final closeCandidates =
        candidates
            .where(
              (candidate) =>
                  _matchScore(profile, candidate) <= closeMatchThreshold,
            )
            .toList();
    final fallbackPool =
        candidates.take(math.min(12, candidates.length)).toList();
    final target =
        closeCandidates.isNotEmpty
            ? closeCandidates.first
            : fallbackPool[_random.nextInt(fallbackPool.length)];
    if (closeCandidates.isEmpty) {
      _log(
        'startMatchmaking: aucun profil proche (bestScore=${bestScore.toStringAsFixed(3)}), fallback recent aleatoire=${target.uid}',
      );
    } else {
      _log(
        'startMatchmaking: match proche trouve uid=${target.uid} score=${_matchScore(profile, target).toStringAsFixed(3)}',
      );
    }
    final requestRef = _firestore.collection('duel_requests').doc();
    final matchScore = _matchScore(profile, target);
    final deadline = now.add(responseWindow);

    await _firestore.runTransaction((transaction) async {
      final selfSnap = await transaction.get(duelProfileRef(uid));
      final targetSnap = await transaction.get(duelProfileRef(target.uid));
      final latestSelf = DuelProfile.fromDoc(selfSnap, fallbackUid: uid);
      final latestTarget = DuelProfile.fromDoc(
        targetSnap,
        fallbackUid: target.uid,
      );

      if (!latestSelf.eligible || !latestSelf.isIdle) {
        throw DuelException('Tu ne peux pas lancer un duel pour le moment.');
      }
      if (!latestTarget.eligible || !latestTarget.isIdle) {
        throw DuelException(
          'Cet adversaire vient d’être pris par quelqu’un d’autre.',
        );
      }

      transaction.set(requestRef, {
        'initiatorUid': uid,
        'targetUid': target.uid,
        'status': 'pending_response',
        'createdAt': Timestamp.fromDate(now),
        'responseDeadline': Timestamp.fromDate(deadline),
        'matchScore': matchScore,
        'initiatorSnapshot': _profileSnapshotMap(latestSelf),
        'targetSnapshot': _profileSnapshotMap(latestTarget),
        'invitePushSentAt': null,
        'resolutionNotifiedAt': null,
      });

      transaction.set(duelProfileRef(uid), {
        'state': 'pending_sent',
        'currentRequestId': requestRef.id,
        'currentDuelId': null,
        'eligible': false,
        'lastActiveAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(target.uid), {
        'state': 'pending_received',
        'currentRequestId': requestRef.id,
        'currentDuelId': null,
        'eligible': false,
      }, SetOptions(merge: true));

      transaction.set(_inboxRef(target.uid, requestRef.id), {
        'type': 'duel_invite',
        'title': '${latestSelf.displayName} te provoque en duel',
        'body': 'Tu as 48h pour accepter ce défi hebdomadaire.',
        'createdAt': Timestamp.fromDate(now),
        'requestId': requestRef.id,
        'duelId': null,
        'actorUid': uid,
        'isRead': false,
      }, SetOptions(merge: true));
    });

    final requestDoc = await requestRef.get();
    _log(
      'startMatchmaking: requete creee requestId=${requestRef.id} initiator=$uid target=${target.uid} score=${matchScore.toStringAsFixed(3)}',
    );
    return DuelRequest.fromDoc(requestDoc);
  }

  static Future<void> acceptRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw DuelException('Utilisateur non connecté.');
    }
    _log('acceptRequest: requestId=$requestId uid=$uid');

    await syncCurrentUserProfile(uid: uid, bumpActivity: true);
    final requestDoc = await duelRequestRef(requestId).get();
    if (!requestDoc.exists) {
      _log('acceptRequest: invitation introuvable requestId=$requestId');
      throw DuelException('Invitation introuvable.');
    }
    final request = DuelRequest.fromDoc(requestDoc);
    if (request.targetUid != uid || !request.isPendingResponse) {
      if (request.status == 'cancelled') {
        _log(
          'acceptRequest: invitation annulee par initiateur requestId=$requestId',
        );
        throw DuelException(
          'Cette invitation a été annulée par son initiateur avant ton acceptation.',
        );
      }
      _log(
        'acceptRequest: invitation indisponible requestId=$requestId target=${request.targetUid} status=${request.status}',
      );
      throw DuelException('Cette invitation n’est plus disponible.');
    }
    if (request.responseDeadline != null &&
        request.responseDeadline!.isBefore(DateTime.now())) {
      _log('acceptRequest: invitation expiree requestId=$requestId');
      throw DuelException('Le délai de 48h est dépassé pour cette invitation.');
    }

    final duelDoc = _firestore.collection('duels').doc();
    final acceptedAt = DateTime.now();
    final endsAt = acceptedAt.add(duelDuration);

    await _firestore.runTransaction((transaction) async {
      final freshRequestSnap = await transaction.get(duelRequestRef(requestId));
      final freshRequest = DuelRequest.fromDoc(freshRequestSnap);
      final initiatorProfileSnap = await transaction.get(
        duelProfileRef(freshRequest.initiatorUid),
      );
      final targetProfileSnap = await transaction.get(duelProfileRef(uid));
      final initiatorProfile = DuelProfile.fromDoc(
        initiatorProfileSnap,
        fallbackUid: freshRequest.initiatorUid,
      );
      final targetProfile = DuelProfile.fromDoc(
        targetProfileSnap,
        fallbackUid: uid,
      );

      if (!freshRequest.isPendingResponse) {
        if (freshRequest.status == 'cancelled') {
          throw DuelException(
            'Cette invitation a été annulée par son initiateur avant ton acceptation.',
          );
        }
        throw DuelException('Cette invitation a déjà été traitée.');
      }
      if (freshRequest.responseDeadline != null &&
          freshRequest.responseDeadline!.isBefore(acceptedAt)) {
        throw DuelException(
          'Le délai de 48h est dépassé pour cette invitation.',
        );
      }
      if (initiatorProfile.currentRequestId != requestId ||
          targetProfile.currentRequestId != requestId) {
        throw DuelException('L’état du duel n’est plus cohérent.');
      }

      transaction.set(duelDoc, {
        'status': 'active',
        'participants': <String>[freshRequest.initiatorUid, uid],
        'acceptedAt': Timestamp.fromDate(acceptedAt),
        'endsAt': Timestamp.fromDate(endsAt),
        'requestId': requestId,
        'scoringMode': 'hybrid_v1',
        'resultAnimationReady': false,
        'resultNotifiedAt': null,
      });

      transaction.set(
        _duelParticipantRef(duelDoc.id, freshRequest.initiatorUid),
        {
          'startingHoldingsValue': initiatorProfile.holdingsValueEstimate,
          'startingReserveCoins': initiatorProfile.reserveCoins,
          'startingTotalCapital':
              initiatorProfile.holdingsValueEstimate +
              initiatorProfile.reserveCoins,
          'startingPositionsCount': initiatorProfile.positionsCount,
          'currentReturnPctCache': 0,
          'currentScoreCache': 0,
          'currentHoldingsValueCache': initiatorProfile.holdingsValueEstimate,
          'currentTotalCapitalCache':
              initiatorProfile.holdingsValueEstimate +
              initiatorProfile.reserveCoins,
          'currentReserveCoinsCache': initiatorProfile.reserveCoins,
          'currentPositionsCountCache': initiatorProfile.positionsCount,
          'performanceRevealTier': 0,
          'spyCoinsSpent': 0,
        },
        SetOptions(merge: true),
      );

      transaction.set(_duelParticipantRef(duelDoc.id, uid), {
        'startingHoldingsValue': targetProfile.holdingsValueEstimate,
        'startingReserveCoins': targetProfile.reserveCoins,
        'startingTotalCapital':
            targetProfile.holdingsValueEstimate + targetProfile.reserveCoins,
        'startingPositionsCount': targetProfile.positionsCount,
        'currentReturnPctCache': 0,
        'currentScoreCache': 0,
        'currentHoldingsValueCache': targetProfile.holdingsValueEstimate,
        'currentTotalCapitalCache':
            targetProfile.holdingsValueEstimate + targetProfile.reserveCoins,
        'currentReserveCoinsCache': targetProfile.reserveCoins,
        'currentPositionsCountCache': targetProfile.positionsCount,
        'performanceRevealTier': 0,
        'spyCoinsSpent': 0,
      }, SetOptions(merge: true));

      transaction.set(duelRequestRef(requestId), {
        'status': 'converted',
        'acceptedAt': Timestamp.fromDate(acceptedAt),
        'duelId': duelDoc.id,
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(freshRequest.initiatorUid), {
        'state': 'active_duel',
        'currentRequestId': null,
        'currentDuelId': duelDoc.id,
        'eligible': false,
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(uid), {
        'state': 'active_duel',
        'currentRequestId': null,
        'currentDuelId': duelDoc.id,
        'eligible': false,
        'lastActiveAt': Timestamp.fromDate(acceptedAt),
      }, SetOptions(merge: true));

      transaction.set(
        _inboxRef(freshRequest.initiatorUid, 'accepted_${duelDoc.id}'),
        {
          'type': 'duel_started',
          'title': '${targetProfile.displayName} a accepté le duel',
          'body':
              'Le défi hebdomadaire est lancé. Rendez-vous dans le dashboard duel.',
          'createdAt': Timestamp.fromDate(acceptedAt),
          'requestId': requestId,
          'duelId': duelDoc.id,
          'actorUid': uid,
          'isRead': false,
        },
        SetOptions(merge: true),
      );

      transaction.set(_inboxRef(uid, 'started_${duelDoc.id}'), {
        'type': 'duel_started',
        'title': 'Duel lancé contre ${initiatorProfile.displayName}',
        'body': 'Le défi démarre maintenant pour 7 jours.',
        'createdAt': Timestamp.fromDate(acceptedAt),
        'requestId': requestId,
        'duelId': duelDoc.id,
        'actorUid': freshRequest.initiatorUid,
        'isRead': false,
      }, SetOptions(merge: true));
    });
    _log('acceptRequest: succes requestId=$requestId duelId=${duelDoc.id}');
  }

  static Future<void> refuseRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw DuelException('Utilisateur non connecté.');
    }
    _log('refuseRequest: requestId=$requestId uid=$uid');

    final requestDoc = await duelRequestRef(requestId).get();
    if (!requestDoc.exists) {
      _log('refuseRequest: invitation introuvable requestId=$requestId');
      throw DuelException('Invitation introuvable.');
    }
    final request = DuelRequest.fromDoc(requestDoc);
    if (request.targetUid != uid || !request.isPendingResponse) {
      _log(
        'refuseRequest: invitation deja traitee requestId=$requestId status=${request.status}',
      );
      throw DuelException('Cette invitation a déjà été traitée.');
    }

    final now = DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final initiatorProfileSnap = await transaction.get(
        duelProfileRef(request.initiatorUid),
      );
      final targetProfileSnap = await transaction.get(duelProfileRef(uid));
      final initiatorProfile = DuelProfile.fromDoc(
        initiatorProfileSnap,
        fallbackUid: request.initiatorUid,
      );
      final targetProfile = DuelProfile.fromDoc(
        targetProfileSnap,
        fallbackUid: uid,
      );

      transaction.set(duelRequestRef(requestId), {
        'status': 'refused',
        'refusedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(request.initiatorUid), {
        'state': 'idle',
        'currentRequestId': null,
        'eligible': _profileCanBeEligible(initiatorProfile),
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(uid), {
        'state': 'idle',
        'currentRequestId': null,
        'eligible': _profileCanBeEligible(targetProfile),
      }, SetOptions(merge: true));

      transaction.set(
        _inboxRef(request.initiatorUid, 'refused_$requestId'),
        {
          'type': 'duel_refused',
          'title': '${targetProfile.displayName} a refusé le duel',
          'body': 'Tu peux relancer un matchmaking quand tu veux.',
          'createdAt': Timestamp.fromDate(now),
          'requestId': requestId,
          'duelId': null,
          'actorUid': uid,
          'isRead': false,
        },
        SetOptions(merge: true),
      );
    });
    _log('refuseRequest: succes requestId=$requestId');
  }

  static Future<void> cancelPendingRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw DuelException('Utilisateur non connecté.');
    }
    _log('cancelPendingRequest: requestId=$requestId uid=$uid');

    final requestDoc = await duelRequestRef(requestId).get();
    if (!requestDoc.exists) {
      _log('cancelPendingRequest: invitation introuvable requestId=$requestId');
      throw DuelException('Invitation introuvable.');
    }
    final request = DuelRequest.fromDoc(requestDoc);
    if (request.initiatorUid != uid || !request.isPendingResponse) {
      _log(
        'cancelPendingRequest: invitation non annulable requestId=$requestId status=${request.status}',
      );
      throw DuelException('Cette invitation ne peut plus être annulée.');
    }

    final now = DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final initiatorProfileSnap = await transaction.get(duelProfileRef(uid));
      final targetProfileSnap = await transaction.get(
        duelProfileRef(request.targetUid),
      );
      final initiatorProfile = DuelProfile.fromDoc(
        initiatorProfileSnap,
        fallbackUid: uid,
      );
      final targetProfile = DuelProfile.fromDoc(
        targetProfileSnap,
        fallbackUid: request.targetUid,
      );

      transaction.set(duelRequestRef(requestId), {
        'status': 'cancelled',
        'cancelledAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(uid), {
        'state': 'idle',
        'currentRequestId': null,
        'eligible': _profileCanBeEligible(initiatorProfile),
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(request.targetUid), {
        'state': 'idle',
        'currentRequestId': null,
        'eligible': _profileCanBeEligible(targetProfile),
      }, SetOptions(merge: true));

      transaction.set(
        _inboxRef(request.targetUid, 'cancelled_$requestId'),
        {
          'type': 'duel_cancelled',
          'title': 'Défi annulé',
          'body':
              '${initiatorProfile.displayName} a annulé son matchmaking avant le départ du duel.',
          'createdAt': Timestamp.fromDate(now),
          'requestId': requestId,
          'duelId': null,
          'actorUid': uid,
          'isRead': false,
        },
        SetOptions(merge: true),
      );
    });
    _log('cancelPendingRequest: succes requestId=$requestId');
  }

  static Future<DuelLiveMetrics> computeLiveMetrics({
    required String uid,
    required DuelParticipant participant,
  }) async {
    _log('computeLiveMetrics: duelParticipantUid=$uid');
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final reserveCoins = (userDoc.data()?['coins'] as num?)?.toDouble() ?? 0;
    final holdings = await fetchGameHoldings(uid, updatePositionDocs: true);
    final holdingsValue = holdings.fold<double>(
      0,
      (total, holding) => total + holding.marketValue,
    );
    final totalCapital = holdingsValue + reserveCoins;
    final baseline =
        participant.startingTotalCapital <= 0
            ? math.max(totalCapital, 1)
            : participant.startingTotalCapital;
    final returnPct = ((totalCapital - baseline) / baseline) * 100;
    final structureBonus = _structureBonus(holdings, holdingsValue);
    final concentrationPenalty = _concentrationPenalty(holdings, holdingsValue);
    final score = returnPct + structureBonus - concentrationPenalty;

    return DuelLiveMetrics(
      holdingsValue: holdingsValue,
      reserveCoins: reserveCoins,
      totalCapital: totalCapital,
      returnPct: returnPct,
      structureBonus: structureBonus,
      concentrationPenalty: concentrationPenalty,
      score: score,
      positionsCount: holdings.length,
      maxPositionWeight: _maxWeight(holdings, holdingsValue),
      holdings: holdings,
    );
  }

  static Future<DuelLiveMetrics> refreshActiveDuelMetrics({
    required String duelId,
    required String uid,
  }) async {
    _log('refreshActiveDuelMetrics: duelId=$duelId uid=$uid');
    final participantSnap = await _duelParticipantRef(duelId, uid).get();
    final participant = DuelParticipant.fromDoc(participantSnap, uid: uid);
    final metrics = await computeLiveMetrics(
      uid: uid,
      participant: participant,
    );
    final teaserHolding = _pickIntelHolding(duelId, holdings: metrics.holdings);
    await _duelParticipantRef(duelId, uid).set({
      'currentReturnPctCache': metrics.returnPct,
      'currentScoreCache': metrics.score,
      'currentHoldingsValueCache': metrics.holdingsValue,
      'currentTotalCapitalCache': metrics.totalCapital,
      'currentReserveCoinsCache': metrics.reserveCoins,
      'currentPositionsCountCache': metrics.positionsCount,
      'teaserLine': teaserHolding?.toMap(),
      'currentUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await syncCurrentUserProfile(uid: uid, bumpActivity: false);
    _log(
      'refreshActiveDuelMetrics: duelId=$duelId uid=$uid score=${metrics.score.toStringAsFixed(2)} return=${metrics.returnPct.toStringAsFixed(2)} positions=${metrics.positionsCount}',
    );
    return metrics;
  }

  static Future<void> purchasePerformanceIntel({
    required String duelId,
    required String uid,
  }) async {
    _log('purchasePerformanceIntel: duelId=$duelId uid=$uid');
    final userRef = _firestore.collection('users').doc(uid);
    final participantRef = _duelParticipantRef(duelId, uid);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final duelSnap = await transaction.get(duelRef(duelId));
      final participantSnap = await transaction.get(participantRef);
      final participant = DuelParticipant.fromDoc(participantSnap, uid: uid);
      final duel = DuelData.fromDoc(duelSnap);

      if (!duel.isActive) {
        throw DuelException('Le duel doit être actif pour acheter un reveal.');
      }
      final tier = participant.performanceRevealTier;
      if (tier >= performanceRevealCosts.length) {
        throw DuelException(
          'La performance adverse est déjà révélée au maximum.',
        );
      }

      final cost = performanceRevealCosts[tier];
      final coins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < cost) {
        throw DuelException('Pas assez de coins pour ce reveal.');
      }

      transaction.update(userRef, {'coins': coins - cost});
      transaction.set(participantRef, {
        'performanceRevealTier': tier + 1,
        'spyCoinsSpent': participant.spyCoinsSpent + cost,
      }, SetOptions(merge: true));
    });
    _log('purchasePerformanceIntel: duelId=$duelId uid=$uid succes');
  }

  static Future<void> purchasePositionsReveal({
    required String duelId,
    required String uid,
  }) async {
    _log('purchasePositionsReveal: duelId=$duelId uid=$uid');
    final userRef = _firestore.collection('users').doc(uid);
    final participantRef = _duelParticipantRef(duelId, uid);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final duelSnap = await transaction.get(duelRef(duelId));
      final participantSnap = await transaction.get(participantRef);
      final participant = DuelParticipant.fromDoc(participantSnap, uid: uid);
      final duel = DuelData.fromDoc(duelSnap);

      if (!duel.isActive) {
        throw DuelException('Le duel doit être actif pour acheter un reveal.');
      }
      if (participant.hasUnlockedPositionsCount) {
        throw DuelException('Le nombre de lignes adverses est déjà révélé.');
      }

      final coins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < positionsRevealCost) {
        throw DuelException('Pas assez de coins pour révéler les lignes.');
      }

      transaction.update(userRef, {'coins': coins - positionsRevealCost});
      transaction.set(participantRef, {
        'positionsCountRevealedAt': FieldValue.serverTimestamp(),
        'spyCoinsSpent': participant.spyCoinsSpent + positionsRevealCost,
      }, SetOptions(merge: true));
    });
    _log('purchasePositionsReveal: duelId=$duelId uid=$uid succes');
  }

  static Future<void> purchaseLineReveal({
    required String duelId,
    required String uid,
  }) async {
    _log('purchaseLineReveal: duelId=$duelId uid=$uid');
    final duelSnap = await duelRef(duelId).get();
    final duel = DuelData.fromDoc(duelSnap);
    if (!duel.isActive) {
      throw DuelException('Le duel doit être actif pour acheter un reveal.');
    }

    final opponentUid = duel.participants.firstWhere(
      (candidate) => candidate != uid,
      orElse: () => '',
    );
    if (opponentUid.isEmpty) {
      throw DuelException('Adversaire introuvable.');
    }

    final opponentHoldings = await fetchGameHoldings(
      opponentUid,
      updatePositionDocs: false,
    );
    if (opponentHoldings.isEmpty) {
      throw DuelException('Aucune ligne adverse disponible pour le reveal.');
    }
    final revealedHolding = _pickIntelHolding(
      '$duelId::$uid',
      holdings: opponentHoldings,
    );
    if (revealedHolding == null) {
      throw DuelException('Reveal indisponible pour le moment.');
    }

    final userRef = _firestore.collection('users').doc(uid);
    final participantRef = _duelParticipantRef(duelId, uid);
    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final participantSnap = await transaction.get(participantRef);
      final participant = DuelParticipant.fromDoc(participantSnap, uid: uid);

      if (participant.hasUnlockedLine) {
        throw DuelException('Une ligne adverse est déjà révélée.');
      }

      final coins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < lineRevealCost) {
        throw DuelException('Pas assez de coins pour révéler une ligne.');
      }

      transaction.update(userRef, {'coins': coins - lineRevealCost});
      transaction.set(participantRef, {
        'revealedLine': revealedHolding.toMap(),
        'spyCoinsSpent': participant.spyCoinsSpent + lineRevealCost,
      }, SetOptions(merge: true));
    });
    _log(
      'purchaseLineReveal: duelId=$duelId uid=$uid succes symbol=${revealedHolding.symbol}',
    );
  }

  static Future<String?> validateSaleDuringActiveDuel({
    required String uid,
    required int currentQuantity,
    required int sellQuantity,
  }) async {
    _log(
      'validateSaleDuringActiveDuel: uid=$uid currentQuantity=$currentQuantity sellQuantity=$sellQuantity',
    );
    if (sellQuantity < currentQuantity) return null;
    final profileDoc = await duelProfileRef(uid).get();
    final profile = DuelProfile.fromDoc(profileDoc, fallbackUid: uid);
    if (!profile.isActiveDuel || profile.currentDuelId == null) {
      return null;
    }
    final positionsSnap = await _positionsRef(uid).get();
    final positionsCount =
        positionsSnap.docs
            .map((doc) => (doc.data()['quantity'] as num?)?.toDouble() ?? 0)
            .where((qty) => qty > 0)
            .length;
    if (positionsCount <= 1) {
      _log(
        'validateSaleDuringActiveDuel: blocage vente derniere ligne uid=$uid',
      );
      return 'Impossible de vendre la dernière ligne pendant un duel actif.';
    }
    _log('validateSaleDuringActiveDuel: vente autorisee uid=$uid');
    return null;
  }

  static Future<void> revealWinnerResult({
    required String duelId,
    required String uid,
  }) async {
    _log('revealWinnerResult: duelId=$duelId uid=$uid');
    await _firestore.runTransaction((transaction) async {
      final duelSnap = await transaction.get(duelRef(duelId));
      final participantSnap = await transaction.get(
        _duelParticipantRef(duelId, uid),
      );
      final duel = DuelData.fromDoc(duelSnap);
      final participant = DuelParticipant.fromDoc(participantSnap, uid: uid);
      if (!duel.isSettled) {
        throw DuelException('Le duel n’est pas encore terminé.');
      }
      if (!participant.isWinner) {
        return;
      }
      transaction.set(_duelParticipantRef(duelId, uid), {
        'rewardClaimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (duel.status == 'settled') {
        transaction.set(duelRef(duelId), {
          'status': 'reward_revealed',
        }, SetOptions(merge: true));
      }
    });
    _log('revealWinnerResult: duelId=$duelId uid=$uid succes');
  }

  static Future<void> closeSettledDuel({
    required String duelId,
    required String uid,
  }) async {
    _log('closeSettledDuel: duelId=$duelId uid=$uid');
    final profileDoc = await duelProfileRef(uid).get();
    final profile = DuelProfile.fromDoc(profileDoc, fallbackUid: uid);
    await _firestore.runTransaction((transaction) async {
      final duelSnap = await transaction.get(duelRef(duelId));
      if (!duelSnap.exists) return;
      final duel = DuelData.fromDoc(duelSnap);
      if (!duel.isSettled) {
        throw DuelException('Le duel n’est pas encore terminé.');
      }
      final opponentUid = duel.participants.firstWhere(
        (candidate) => candidate != uid,
        orElse: () => '',
      );
      final opponentParticipantSnap =
          opponentUid.isEmpty
              ? null
              : await transaction.get(_duelParticipantRef(duelId, opponentUid));
      final opponentParticipant = DuelParticipant.fromDoc(
        opponentParticipantSnap,
        uid: opponentUid,
      );

      transaction.set(_duelParticipantRef(duelId, uid), {
        'resultDismissedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(duelProfileRef(uid), {
        'state': 'idle',
        'currentDuelId': null,
        'currentRequestId': null,
        'eligible':
            profile.holdingsValueEstimate >= minEligibleHoldingsValue &&
            profile.positionsCount >= 1,
      }, SetOptions(merge: true));

      if (opponentParticipant.resultDismissedAt != null) {
        transaction.set(duelRef(duelId), {
          'status': 'closed',
        }, SetOptions(merge: true));
      }
    });

    await syncCurrentUserProfile(uid: uid, bumpActivity: true);
    _log('closeSettledDuel: duelId=$duelId uid=$uid succes');
  }

  static DocumentReference<Map<String, dynamic>> _duelParticipantRef(
    String duelId,
    String uid,
  ) {
    return duelRef(duelId).collection('participants').doc(uid);
  }

  static int? nextPerformanceRevealCost(int tier) {
    if (tier < 0 || tier >= performanceRevealCosts.length) {
      return null;
    }
    return performanceRevealCosts[tier];
  }

  static DocumentReference<Map<String, dynamic>> _inboxRef(
    String uid,
    String itemId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .doc(itemId);
  }

  static Map<String, dynamic> _profileSnapshotMap(DuelProfile profile) {
    return <String, dynamic>{
      'uid': profile.uid,
      'displayName': profile.displayName,
      'avatarId': profile.avatarId,
      'level': profile.level,
      'reserveCoins': profile.reserveCoins,
      'holdingsValueEstimate': profile.holdingsValueEstimate,
      'positionsCount': profile.positionsCount,
    };
  }

  static String _normalizeProfileState(String rawState) {
    switch (rawState) {
      case 'pending_sent':
      case 'pending_received':
      case 'active_duel':
        return rawState;
      default:
        return 'idle';
    }
  }

  static bool _profileCanBeEligible(DuelProfile profile) {
    return profile.holdingsValueEstimate >= minEligibleHoldingsValue &&
        profile.positionsCount >= 1;
  }

  static String _displayName(Map<String, dynamic> data) {
    final name = (data['Name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = (data['name'] as String?)?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'Joueur';
  }

  static int _levelFromXp(int xp) {
    final safeXp = xp.clamp(0, 100000000);
    return (math.log((safeXp / 500) + 1) / math.log(1.2)).floor() + 1;
  }

  static double _matchScore(DuelProfile initiator, DuelProfile target) {
    return 0.45 *
            _relativeDiff(
              initiator.holdingsValueEstimate,
              target.holdingsValueEstimate,
            ) +
        0.45 * _relativeDiff(initiator.reserveCoins, target.reserveCoins) +
        0.10 *
            _relativeDiff(initiator.level.toDouble(), target.level.toDouble());
  }

  static double _relativeDiff(double left, double right) {
    final denom = math.max(math.max(left.abs(), right.abs()), 1);
    return (left - right).abs() / denom;
  }

  static double _structureBonus(
    List<DuelHolding> holdings,
    double holdingsValue,
  ) {
    if (holdings.isEmpty || holdingsValue <= 0) return 0;

    var bonus = 0.0;
    if (holdings.length >= 5) {
      bonus += 2.0;
    } else if (holdings.length >= 3) {
      bonus += 1.0;
    }

    final maxWeight = _maxWeight(holdings, holdingsValue);
    if (maxWeight <= 0.45) {
      bonus += 1.0;
    } else if (maxWeight <= 0.60) {
      bonus += 0.5;
    }

    final quoteTypes =
        holdings
            .map((holding) => holding.quoteType.trim().toUpperCase())
            .where((value) => value.isNotEmpty)
            .toSet();
    if (quoteTypes.length >= 2) {
      bonus += 0.5;
    }

    final zones =
        holdings
            .map((holding) => _marketZone(holding.exchange, holding.currency))
            .where((value) => value.isNotEmpty)
            .toSet();
    if (zones.length >= 2) {
      bonus += 0.5;
    }

    return bonus.clamp(0, 4).toDouble();
  }

  static double _concentrationPenalty(
    List<DuelHolding> holdings,
    double holdingsValue,
  ) {
    if (holdings.isEmpty || holdingsValue <= 0) return 0;
    final maxWeight = _maxWeight(holdings, holdingsValue);
    if (maxWeight > 0.85) return 2.0;
    if (maxWeight > 0.70) return 1.0;
    return 0;
  }

  static double _maxWeight(List<DuelHolding> holdings, double holdingsValue) {
    if (holdings.isEmpty || holdingsValue <= 0) return 0;
    var maxWeight = 0.0;
    for (final holding in holdings) {
      final weight = holding.marketValue / holdingsValue;
      if (weight > maxWeight) {
        maxWeight = weight;
      }
    }
    return maxWeight;
  }

  static String _marketZone(String exchange, String currency) {
    final merged = '${exchange.toUpperCase()} ${currency.toUpperCase()}';
    if (merged.contains('PARIS') ||
        merged.contains('EURONEXT') ||
        merged.contains('EUR')) {
      return 'EU';
    }
    if (merged.contains('NASDAQ') ||
        merged.contains('NYSE') ||
        merged.contains('USD')) {
      return 'US';
    }
    if (merged.contains('TOKYO') || merged.contains('JPY')) {
      return 'JP';
    }
    if (merged.contains('HK') || merged.contains('HONG')) {
      return 'HK';
    }
    return merged.trim();
  }

  static DuelHolding? _pickIntelHolding(
    String seed, {
    required List<DuelHolding> holdings,
  }) {
    if (holdings.isEmpty) return null;
    final sorted = [...holdings]
      ..sort((left, right) => left.symbol.compareTo(right.symbol));
    var hash = 0;
    for (final codeUnit in seed.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return sorted[hash % sorted.length];
  }
}
