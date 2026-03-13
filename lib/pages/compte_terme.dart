import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fintech/core/constants.dart';
import 'package:fintech/models/term_deposit_game_models.dart';
import 'package:fintech/services/activity_tracking_service.dart';
import 'package:fintech/services/term_deposit_game_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const LinearGradient _treasuryGradient = LinearGradient(
  colors: <Color>[detailsColor1, detailsColor2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final List<BoxShadow> _treasuryShadow = <BoxShadow>[
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 20,
    offset: const Offset(0, 12),
  ),
];

const String _treasuryHeroSvg = '''
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
    <linearGradient id="violet" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2A0F45"/>
      <stop offset="100%" stop-color="#57307A"/>
    </linearGradient>
  </defs>
  <rect x="26" y="34" width="86" height="118" rx="20" fill="#FFF8E7" stroke="#E8D18D" stroke-width="6"/>
  <path d="M48 68 H92 M48 92 H92 M48 116 H78" stroke="#2A0F45" stroke-width="9" stroke-linecap="round"/>
  <circle cx="160" cy="78" r="34" fill="url(#gold)" opacity="0.96"/>
  <path d="M136 138 C148 104, 178 110, 188 86" fill="none" stroke="url(#violet)" stroke-width="10" stroke-linecap="round"/>
  <circle cx="188" cy="86" r="9" fill="#2A0F45"/>
  <circle cx="136" cy="138" r="9" fill="#D4AF37"/>
  <path d="M134 168 H194" stroke="#2A0F45" stroke-width="10" stroke-linecap="round"/>
  <path d="M150 168 V136 M170 168 V118 M190 168 V96" stroke="url(#gold)" stroke-width="10" stroke-linecap="round"/>
</svg>
''';

const String _slotSvg = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="slotGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <rect x="10" y="14" width="44" height="36" rx="12" fill="#FFF8E7" stroke="#E7CF8F" stroke-width="4"/>
  <path d="M20 24 H44 M20 34 H38" stroke="#2A0F45" stroke-width="5" stroke-linecap="round"/>
  <circle cx="46" cy="46" r="8" fill="url(#slotGold)"/>
</svg>
''';

const String _shieldSvg = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="shieldGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
  </defs>
  <path d="M32 10 L50 18 V30 C50 41 43 50 32 56 C21 50 14 41 14 30 V18 Z" fill="#FFF8E7" stroke="#2A0F45" stroke-width="4"/>
  <path d="M24 33 L30 39 L42 25" fill="none" stroke="url(#shieldGold)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const String _treasuryRefreshLoaderSvg = '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="loaderGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#D4AF37"/>
      <stop offset="100%" stop-color="#F5D76E"/>
    </linearGradient>
    <linearGradient id="loaderViolet" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2A0F45"/>
      <stop offset="100%" stop-color="#5B337C"/>
    </linearGradient>
  </defs>
  <circle cx="80" cy="80" r="48" fill="#FFF9EA" stroke="#E9D59B" stroke-width="4"/>
  <circle cx="80" cy="80" r="34" fill="none" stroke="url(#loaderGold)" stroke-width="10" stroke-linecap="round" stroke-dasharray="112 62"/>
  <circle cx="80" cy="80" r="22" fill="none" stroke="url(#loaderViolet)" stroke-width="8" stroke-linecap="round" stroke-dasharray="54 34"/>
  <rect x="42" y="96" width="16" height="20" rx="6" fill="url(#loaderGold)"/>
  <rect x="66" y="84" width="16" height="32" rx="6" fill="url(#loaderViolet)"/>
  <rect x="90" y="72" width="16" height="44" rx="6" fill="url(#loaderGold)"/>
  <path d="M48 58 C60 52, 72 60, 84 48 S106 36, 118 44" fill="none" stroke="url(#loaderViolet)" stroke-width="6" stroke-linecap="round"/>
  <circle cx="118" cy="44" r="6" fill="url(#loaderGold)"/>
</svg>
''';

@visibleForTesting
String treasuryQuestDateLabel([DateTime? now]) {
  final value = now ?? DateTime.now();
  return '${value.year}-${value.month}-${value.day}';
}

String _localTreasuryDayKey([DateTime? now]) {
  final value = now ?? DateTime.now();
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

class TermDepositSection extends StatefulWidget {
  const TermDepositSection({super.key});

  @override
  State<TermDepositSection> createState() => _TermDepositSectionState();
}

class _TermDepositSectionState extends State<TermDepositSection>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final AnimationController _motionCtrl;
  late final AnimationController _refreshLoaderCtrl;

  bool _isBootstrapping = true;
  bool _isActionLoading = false;
  bool _isRefreshingBoard = false;
  String? _errorText;
  Map<String, dynamic>? _userData;
  TreasuryMetaState? _metaState;
  TreasuryBoard? _board;
  TreasuryScoreBreakdown? _liveBreakdown;
  TreasuryResolutionPreview? _latestResolution;
  List<TreasuryPosition> _positions = const <TreasuryPosition>[];
  List<Map<String, dynamic>> _seasonLeaders = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _motionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _refreshLoaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    unawaited(_loadDashboard(showLoader: true));
  }

  @override
  void dispose() {
    _motionCtrl.dispose();
    _refreshLoaderCtrl.dispose();
    super.dispose();
  }

  User? get _user => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _metaRef(String uid) =>
      _userRef(uid).collection('games').doc('term_deposit');

  CollectionReference<Map<String, dynamic>> _positionsRef(String uid) =>
      _userRef(uid).collection('term_deposits');

  DocumentReference<Map<String, dynamic>> _boardRef(
    String uid,
    String dayKey,
  ) => _userRef(uid).collection('term_deposit_boards').doc(dayKey);

  DocumentReference<Map<String, dynamic>> _questRef(String uid) =>
      _userRef(uid).collection('quests').doc('daily');

  DocumentReference<Map<String, dynamic>> _gamesProgressRef(String uid) =>
      _userRef(uid).collection('games').doc('progress');

  DocumentReference<Map<String, dynamic>> _seasonPlayerRef(
    String seasonKey,
    String uid,
  ) => _firestore
      .collection('termDepositSeasons')
      .doc(seasonKey)
      .collection('players')
      .doc(uid);

  Future<void> _loadDashboard({
    bool showLoader = false,
    bool showRefreshOverlay = false,
  }) async {
    final user = _user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
          _isRefreshingBoard = false;
          _errorText = 'Connexion requise.';
        });
      }
      return;
    }

    final preserveVisibleState =
        showRefreshOverlay && _board != null && _metaState != null;

    if (mounted) {
      if (showLoader) {
        setState(() {
          _isBootstrapping = true;
          _isRefreshingBoard = false;
          _errorText = null;
        });
      } else if (showRefreshOverlay) {
        setState(() {
          _isRefreshingBoard = true;
          _errorText = null;
        });
      }
    }

    try {
      final now = DateTime.now();
      final uid = user.uid;
      final userSnap = await _userRef(uid).get();
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final unlocked = (userData['is_term_deposit_unlocked'] as bool?) ?? false;

      if (!unlocked) {
        if (!mounted) return;
        setState(() {
          _userData = userData;
          _metaState = null;
          _board = null;
          _liveBreakdown = null;
          _latestResolution = null;
          _positions = const <TreasuryPosition>[];
          _seasonLeaders = const <Map<String, dynamic>>[];
          _isBootstrapping = false;
          _errorText = null;
        });
        return;
      }

      final metaSnap = await _metaRef(uid).get();
      final positionsSnap = await _positionsRef(uid).get();
      final boardsSnap =
          await _userRef(uid).collection('term_deposit_boards').get();

      final metaState = TreasuryMetaState.fromMap(metaSnap.data());
      final positions = _sortPositions(
        positionsSnap.docs
            .map((doc) => TreasuryPosition.fromMap(doc.id, doc.data()))
            .toList(),
      );
      final boards =
          boardsSnap.docs
              .map((doc) => TreasuryBoard.fromMap(doc.data()))
              .toList()
            ..sort((a, b) => a.dayKey.compareTo(b.dayKey));

      final syncResult = await _synchronizeTreasury(
        uid: uid,
        userData: userData,
        metaState: metaState,
        positions: positions,
        boards: boards,
        now: now,
      );

      final freshUserSnap = await _userRef(uid).get();
      final freshUserData = freshUserSnap.data() ?? const <String, dynamic>{};
      final freshMetaSnap = await _metaRef(uid).get();
      final freshMeta = TermDepositGameEngine.normalizeMetaState(
        TreasuryMetaState.fromMap(freshMetaSnap.data()),
        now: now,
      );
      final freshPositionsSnap = await _positionsRef(uid).get();
      final freshPositions = _sortPositions(
        freshPositionsSnap.docs
            .map((doc) => TreasuryPosition.fromMap(doc.id, doc.data()))
            .toList(),
      );
      final todayKey = _localTreasuryDayKey(now);
      final todayBoardSnap = await _boardRef(uid, todayKey).get();
      final board =
          todayBoardSnap.exists
              ? TreasuryBoard.fromMap(todayBoardSnap.data()!)
              : TermDepositGameEngine.buildBoard(
                uid: uid,
                dayKey: todayKey,
                metaState: freshMeta,
                rerollsUsed: 0,
                now: now,
              );
      final refreshedPositions =
          freshPositions
              .map(
                (position) =>
                    position.isActive && !position.isLegacy
                        ? TermDepositGameEngine.applyOpportunityCost(
                          position,
                          board.offers,
                        )
                        : position,
              )
              .toList();
      final liveBreakdown = TermDepositGameEngine.scoreTreasury(
        board: board,
        positions: refreshedPositions,
        availableCoins: (freshUserData['coins'] as num?)?.toInt() ?? 0,
        skillState: freshMeta.toSkillState(
          forecastTomorrow: board.forecastTomorrow,
        ),
      );
      final seasonLeaders = await _fetchSeasonLeaders(freshMeta.seasonKey);

      if (!mounted) return;
      setState(() {
        _userData = freshUserData;
        _metaState = freshMeta;
        _board = board;
        _positions = refreshedPositions;
        _liveBreakdown = liveBreakdown;
        _latestResolution = syncResult?.latestResolution;
        _seasonLeaders = seasonLeaders;
        _isBootstrapping = false;
        _isRefreshingBoard = false;
        _errorText = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Erreur dashboard trésorerie: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      if (preserveVisibleState) {
        setState(() {
          _isRefreshingBoard = false;
        });
        _showSnack('Impossible d’actualiser le board.', error: true);
      } else {
        setState(() {
          _isBootstrapping = false;
          _isRefreshingBoard = false;
          _errorText = 'Impossible de charger le cockpit de trésorerie.';
        });
      }
    }
  }

  Future<void> _refreshBoard() async {
    if (_isRefreshingBoard || _isBootstrapping) return;
    await _loadDashboard(showRefreshOverlay: true);
  }

  Future<List<Map<String, dynamic>>> _fetchSeasonLeaders(
    String seasonKey,
  ) async {
    try {
      final snap =
          await _firestore
              .collection('termDepositSeasons')
              .doc(seasonKey)
              .collection('players')
              .orderBy('finalAverageScore', descending: true)
              .limit(5)
              .get();
      final rows =
          snap.docs
              .map((doc) => <String, dynamic>{'uid': doc.id, ...doc.data()})
              .toList()
            ..sort((a, b) {
              final scoreCompare =
                  ((b['finalAverageScore'] as num?)?.toDouble() ?? 0).compareTo(
                    (a['finalAverageScore'] as num?)?.toDouble() ?? 0,
                  );
              if (scoreCompare != 0) return scoreCompare;
              return ((b['bestLadder'] as num?)?.toInt() ?? 0).compareTo(
                ((a['bestLadder'] as num?)?.toInt() ?? 0),
              );
            });
      return rows;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<_TreasurySyncResult?> _synchronizeTreasury({
    required String uid,
    required Map<String, dynamic> userData,
    required TreasuryMetaState metaState,
    required List<TreasuryPosition> positions,
    required List<TreasuryBoard> boards,
    required DateTime now,
  }) async {
    final todayKey = _localTreasuryDayKey(now);
    final normalizedMeta = TermDepositGameEngine.normalizeMetaState(
      metaState,
      now: now,
    );
    final unresolvedBoards =
        boards
            .where(
              (board) =>
                  board.dayKey.compareTo(todayKey) < 0 &&
                  board.resolvedAt == null,
            )
            .toList()
          ..sort((a, b) => a.dayKey.compareTo(b.dayKey));
    final hasAutoMatures = positions.any(
      (position) =>
          !position.isLegacy &&
          position.isActive &&
          !position.maturesAt.isAfter(now),
    );
    final todayBoard = boards.cast<TreasuryBoard?>().firstWhere(
      (board) => board?.dayKey == todayKey,
      orElse: () => null,
    );

    if (!_metaChanged(metaState, normalizedMeta) &&
        unresolvedBoards.isEmpty &&
        !hasAutoMatures &&
        todayBoard != null) {
      return null;
    }

    final userRef = _userRef(uid);
    final metaRef = _metaRef(uid);
    final questRef = _questRef(uid);
    final progressRef = _gamesProgressRef(uid);

    final result = await _firestore.runTransaction<_TreasurySyncResult>((
      tx,
    ) async {
      final freshUserSnap = await tx.get(userRef);
      final questSnap = await tx.get(questRef);
      final freshUserData = freshUserSnap.data() ?? userData;
      var availableCoins = (freshUserData['coins'] as num?)?.toInt() ?? 0;
      var liveMeta = normalizedMeta;
      var workingPositions = _sortPositions(
        List<TreasuryPosition>.from(positions),
      );
      final originalById = <String, TreasuryPosition>{
        for (final position in positions) position.id: position,
      };

      TreasuryResolutionPreview? latestResolution;
      var resolvedBoardsCount = 0;
      var liquidityQuestHits = 0;
      var ladderQuestHits = 0;
      var activityPoints = 0;

      for (final board in unresolvedBoards) {
        final preview = TermDepositGameEngine.previewResolution(
          board: board,
          positions: workingPositions,
          availableCoins: availableCoins,
          metaState: liveMeta,
          now: now,
        );
        latestResolution = preview;
        resolvedBoardsCount += 1;
        if (preview.scoreBreakdown.liquidityScore >= 70) {
          liquidityQuestHits += 1;
        }
        if (preview.scoreBreakdown.ladderBonus > 0) {
          ladderQuestHits += 1;
        }
        activityPoints += 20 + preview.scoreBreakdown.finalScore;
        final realizedYieldRate = _realizedYieldRate(
          beforePositions: workingPositions,
          afterPositions: preview.updatedPositions,
        );
        liveMeta = _applyResolutionToMeta(
          meta: liveMeta,
          breakdown: preview.scoreBreakdown,
          dayKey: board.dayKey,
          now: now,
          realizedYieldRate: realizedYieldRate,
        );
        availableCoins = preview.newCoinsBalance;
        workingPositions = _sortPositions(preview.updatedPositions);

        tx.set(
          _boardRef(uid, board.dayKey),
          board
              .copyWith(
                events:
                    board.events
                        .map((event) => event.copyWith(resolved: true))
                        .toList(),
                scoreBreakdown: preview.scoreBreakdown,
                resolvedAt: now,
              )
              .toMap()
            ..['updatedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
      }

      final settlement = _settleAutoMatures(
        positions: workingPositions,
        now: now,
      );
      if (settlement.changed) {
        availableCoins += settlement.coinsDelta;
        workingPositions = _sortPositions(settlement.positions);
      }

      TreasuryBoard liveBoard =
          todayBoard ??
          TermDepositGameEngine.buildBoard(
            uid: uid,
            dayKey: todayKey,
            metaState: liveMeta,
            rerollsUsed: 0,
            now: now,
          );

      if (todayBoard == null) {
        tx.set(
          _boardRef(uid, todayKey),
          liveBoard.toMap()
            ..['createdAt'] = FieldValue.serverTimestamp()
            ..['updatedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
      }

      workingPositions =
          workingPositions
              .map(
                (position) =>
                    position.isActive && !position.isLegacy
                        ? TermDepositGameEngine.applyOpportunityCost(
                          position,
                          liveBoard.offers,
                        )
                        : position,
              )
              .toList();

      for (final position in workingPositions) {
        if (position.isLegacy) continue;
        final previous = originalById[position.id];
        if (!_positionChanged(previous, position)) continue;
        tx.set(
          _positionsRef(uid).doc(position.id),
          position.toMap()..['updatedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
      }

      tx.set(userRef, <String, dynamic>{
        'coins': availableCoins,
      }, SetOptions(merge: true));
      tx.set(metaRef, liveMeta.toMap(), SetOptions(merge: true));

      if (resolvedBoardsCount > 0) {
        final questData = questSnap.data() ?? const <String, dynamic>{};
        final todayLabel = treasuryQuestDateLabel(now);
        final sameDay = questData['date'] == todayLabel;
        tx.set(progressRef, {
          'xp': FieldValue.increment(math.max(12, activityPoints ~/ 2)),
        }, SetOptions(merge: true));
        tx.set(questRef, {
          'date': todayLabel,
          'treasury_runs_done':
              sameDay
                  ? FieldValue.increment(resolvedBoardsCount)
                  : resolvedBoardsCount,
          'treasury_liquidity_days':
              sameDay
                  ? FieldValue.increment(liquidityQuestHits)
                  : liquidityQuestHits,
          'treasury_ladder_hits':
              sameDay ? FieldValue.increment(ladderQuestHits) : ladderQuestHits,
          'claimed_treasury':
              sameDay
                  ? (questData['claimed_treasury'] as bool?) ?? false
                  : false,
        }, SetOptions(merge: true));
      }

      tx.set(_seasonPlayerRef(liveMeta.seasonKey, uid), {
        'finalAverageScore': liveMeta.seasonFinalAverage,
        'yieldAverage': liveMeta.seasonYieldAverage,
        'liquidityAverage': liveMeta.seasonLiquidityAverage,
        'disciplineAverage': liveMeta.seasonDisciplineAverage,
        'bestLadder': liveMeta.bestLadder,
        'displayName':
            (freshUserData['displayName'] as String?) ??
            (freshUserData['Name'] as String?) ??
            _auth.currentUser?.displayName ??
            'Joueur',
        'avatar':
            freshUserData['selected_avatar'] ?? freshUserData['avatar'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return _TreasurySyncResult(
        latestResolution: latestResolution,
        resolvedBoardsCount: resolvedBoardsCount,
        activityPoints: activityPoints,
      );
    });

    if (result.resolvedBoardsCount > 0) {
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_board_resolved',
        points: result.activityPoints,
        counters: <String, int>{
          'treasury_runs_completed': result.resolvedBoardsCount,
        },
      );
    }
    return result;
  }

  Future<void> _unlockFeature() async {
    final user = _user;
    final gems = (_userData?['gems'] as num?)?.toInt() ?? 0;
    if (user == null) return;
    if (gems < 100) {
      _showSnack(
        '100 gems sont nécessaires pour débloquer le cockpit.',
        error: true,
      );
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _userRef(user.uid);
        final snap = await tx.get(ref);
        final currentGems = (snap.data()?['gems'] as num?)?.toInt() ?? 0;
        if (currentGems < 100) {
          throw StateError('Solde insuffisant');
        }
        tx.set(ref, {
          'gems': currentGems - 100,
          'is_term_deposit_unlocked': true,
        }, SetOptions(merge: true));
        tx.set(
          _metaRef(user.uid),
          TermDepositGameEngine.defaultMetaState(now: DateTime.now()).toMap(),
          SetOptions(merge: true),
        );
      });
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_unlocked',
        points: 40,
        counters: const <String, int>{'treasury_unlocks': 1},
      );
      _showSnack('Cockpit de trésorerie débloqué.');
      await _loadDashboard(showLoader: true);
    } catch (_) {
      _showSnack('Impossible de débloquer le mini-jeu.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _showOpenOfferSheet(TreasuryOffer offer) async {
    final availableCoins = (_userData?['coins'] as num?)?.toInt() ?? 0;
    if (availableCoins <= 0) {
      _showSnack('Solde insuffisant en coins.', error: true);
      return;
    }
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              _OfferDepositSheet(offer: offer, availableCoins: availableCoins),
    );
    if (amount == null) return;
    await _openOffer(offer, amount);
  }

  Future<void> _openOffer(TreasuryOffer offer, int amount) async {
    final user = _user;
    final meta = _metaState;
    final board = _board;
    if (user == null || meta == null || board == null) return;

    final usedSlots = _countUsedSlots(_positions);
    if (usedSlots + offer.slotCost > meta.slotCount) {
      _showSnack('Slots saturés. Libère ou upgrade ta structure.', error: true);
      return;
    }
    if (offer.requiresPremiumSlot && !meta.premiumSlotUnlocked) {
      _showSnack('Ce produit exige un premium slot débloqué.', error: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final userSnap = await tx.get(userRef);
        final currentCoins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (currentCoins < amount) {
          throw StateError('coins insuffisants');
        }
        final depositRef = _positionsRef(user.uid).doc();
        final position = TermDepositGameEngine.buildNewPosition(
          id: depositRef.id,
          principalCoins: amount,
          offer: offer,
          now: DateTime.now(),
        );
        tx.set(userRef, <String, dynamic>{
          'coins': currentCoins - amount,
        }, SetOptions(merge: true));
        tx.set(
          depositRef,
          position.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
        );
      });
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_position_opened',
        points: 10 + (offer.durationDays * 2),
        counters: const <String, int>{'treasury_positions_opened': 1},
        label: offer.productType.key,
      );
      _showSnack('Position ouverte sur ${offer.label.toLowerCase()}.');
      await _loadDashboard();
    } catch (_) {
      _showSnack('Ouverture du dépôt impossible.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _rerollBoard() async {
    final user = _user;
    final meta = _metaState;
    final board = _board;
    if (user == null || meta == null || board == null) return;

    final rerollCost = TermDepositGameEngine.previewRerollGemCost(
      metaState: meta,
      board: board,
    );

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final userSnap = await tx.get(userRef);
        final currentGems = (userSnap.data()?['gems'] as num?)?.toInt() ?? 0;
        if (currentGems < rerollCost) {
          throw StateError('gems insuffisants');
        }
        final rerollsUsed = board.rerollsUsed + 1;
        final rebuiltBoard = TermDepositGameEngine.buildBoard(
          uid: user.uid,
          dayKey: board.dayKey,
          metaState: meta,
          rerollsUsed: rerollsUsed,
          now: DateTime.now(),
        );
        tx.set(userRef, <String, dynamic>{
          'gems': currentGems - rerollCost,
        }, SetOptions(merge: true));
        tx.set(
          _boardRef(user.uid, board.dayKey),
          rebuiltBoard.toMap()..['updatedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
        for (final position in _positions.where(
          (item) => item.isActive && !item.isLegacy,
        )) {
          final updated = TermDepositGameEngine.applyOpportunityCost(
            position,
            rebuiltBoard.offers,
          );
          tx.set(
            _positionsRef(user.uid).doc(position.id),
            updated.toMap()..['updatedAt'] = FieldValue.serverTimestamp(),
            SetOptions(merge: true),
          );
        }
      });
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_reroll',
        points: 8,
        counters: const <String, int>{'treasury_rerolls': 1},
      );
      _showSnack(
        rerollCost == 0
            ? 'Board quotidien rerollé.'
            : 'Board rerollé pour $rerollCost gems.',
      );
      await _loadDashboard();
    } catch (_) {
      _showSnack('Reroll impossible.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _breakFlexiblePosition(TreasuryPosition position) async {
    final user = _user;
    final meta = _metaState;
    if (user == null ||
        meta == null ||
        position.isLegacy ||
        !position.isFlexible) {
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final metaRef = _metaRef(user.uid);
        final userSnap = await tx.get(userRef);
        final metaSnap = await tx.get(metaRef);
        final currentCoins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        final liveMeta = TermDepositGameEngine.normalizeMetaState(
          TreasuryMetaState.fromMap(metaSnap.data()),
          now: DateTime.now(),
        );
        final freeExit = liveMeta.freeWithdrawalsRemaining > 0;
        final payout =
            freeExit
                ? position.principalCoins
                : (position.principalCoins * 0.92).floor();
        tx.set(userRef, <String, dynamic>{
          'coins': currentCoins + payout,
        }, SetOptions(merge: true));
        tx.set(
          metaRef,
          liveMeta
              .copyWith(
                freeWithdrawalsRemaining:
                    freeExit
                        ? liveMeta.freeWithdrawalsRemaining - 1
                        : liveMeta.freeWithdrawalsRemaining,
              )
              .toMap(),
          SetOptions(merge: true),
        );
        tx.set(
          _positionsRef(user.uid).doc(position.id),
          position
              .copyWith(
                status: 'broken',
                brokenEarly: true,
                payoutCoins: payout,
              )
              .toMap()
            ..['updatedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
      });
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_early_exit',
        points: 6,
        counters: const <String, int>{'treasury_early_exits': 1},
      );
      _showSnack('Sortie anticipée exécutée.');
      await _loadDashboard();
    } catch (_) {
      _showSnack('Sortie anticipée impossible.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _claimLegacyPosition(TreasuryPosition position) async {
    final user = _user;
    if (user == null || !position.isLegacy) return;

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final userSnap = await tx.get(userRef);
        final currentBalance =
            (userSnap.data()?[position.legacyCurrencyType] as num?)?.toInt() ??
            0;
        tx.set(userRef, <String, dynamic>{
          position.legacyCurrencyType: currentBalance + position.payoutCoins,
        }, SetOptions(merge: true));
        tx.delete(_positionsRef(user.uid).doc(position.id));
      });
      _showSnack(
        'Legacy récupéré: +${position.payoutCoins} ${position.legacyCurrencyType}.',
      );
      await _loadDashboard();
    } catch (_) {
      _showSnack('Claim legacy impossible.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _unlockSkill(TreasurySkillDefinition definition) async {
    final user = _user;
    final meta = _metaState;
    final currentGems = (_userData?['gems'] as num?)?.toInt() ?? 0;
    if (user == null || meta == null) return;
    if (_isSkillUnlocked(definition, meta)) return;
    final reason = _skillLockReason(
      definition: definition,
      meta: meta,
      gems: currentGems,
    );
    if (reason != null) {
      _showSnack(reason, error: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final metaRef = _metaRef(user.uid);
        final userSnap = await tx.get(userRef);
        final metaSnap = await tx.get(metaRef);
        final liveMeta = TermDepositGameEngine.normalizeMetaState(
          TreasuryMetaState.fromMap(metaSnap.data()),
          now: DateTime.now(),
        );
        final liveGems = (userSnap.data()?['gems'] as num?)?.toInt() ?? 0;
        if (_isSkillUnlocked(definition, liveMeta)) {
          return;
        }
        if (!TermDepositGameEngine.meetsSkillRequirements(
              definition: definition,
              metaState: liveMeta,
            ) ||
            (definition.usesSeasonPointsCurrency &&
                liveMeta.seasonPoints < definition.seasonPointCost) ||
            (!definition.usesSeasonPointsCurrency &&
                liveGems < definition.gemCost)) {
          throw StateError('prérequis');
        }
        final nextSkills =
            <String>{...liveMeta.unlockedSkillIds, definition.id}.toList()
              ..sort();
        var updatedMeta = liveMeta.copyWith(
          unlockedSkillIds: nextSkills,
          seasonPoints:
              definition.usesSeasonPointsCurrency
                  ? liveMeta.seasonPoints - definition.seasonPointCost
                  : liveMeta.seasonPoints,
          premiumSlotUnlocked:
              liveMeta.premiumSlotUnlocked ||
              definition.id == kTreasurySkillPremiumSlot,
          freeWithdrawalsRemaining:
              definition.id == kTreasurySkillFreeEarlyExit &&
                      liveMeta.freeWithdrawalsRemaining == 0
                  ? 1
                  : liveMeta.freeWithdrawalsRemaining,
          eventShieldRemaining:
              definition.id == kTreasurySkillEventShield &&
                      liveMeta.eventShieldRemaining == 0
                  ? 1
                  : liveMeta.eventShieldRemaining,
        );
        updatedMeta = TermDepositGameEngine.normalizeMetaState(
          updatedMeta,
          now: DateTime.now(),
        );
        if (!definition.usesSeasonPointsCurrency && definition.gemCost > 0) {
          tx.set(userRef, <String, dynamic>{
            'gems': liveGems - definition.gemCost,
          }, SetOptions(merge: true));
        }
        tx.set(metaRef, updatedMeta.toMap(), SetOptions(merge: true));
      });
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_skill_unlocked',
        points: 18,
        counters: const <String, int>{'treasury_skills_unlocked': 1},
        label: definition.id,
      );
      _showSnack('${definition.label} débloqué.');
      await _loadDashboard();
    } catch (_) {
      _showSnack('Déblocage de compétence impossible.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _buySlotUpgrade(TreasurySlotUpgradeDefinition definition) async {
    final user = _user;
    final meta = _metaState;
    final currentGems = (_userData?['gems'] as num?)?.toInt() ?? 0;
    if (user == null || meta == null) return;

    final reason = _slotUpgradeLockReason(
      definition: definition,
      meta: meta,
      gems: currentGems,
    );
    if (reason != null) {
      _showSnack(reason, error: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _firestore.runTransaction((tx) async {
        final userRef = _userRef(user.uid);
        final metaRef = _metaRef(user.uid);
        final userSnap = await tx.get(userRef);
        final metaSnap = await tx.get(metaRef);
        final liveGems = (userSnap.data()?['gems'] as num?)?.toInt() ?? 0;
        final liveMeta = TermDepositGameEngine.normalizeMetaState(
          TreasuryMetaState.fromMap(metaSnap.data()),
          now: DateTime.now(),
        );
        final liveUpgrade = TermDepositGameEngine.nextSlotUpgradeFor(liveMeta);
        if (liveUpgrade == null ||
            liveUpgrade.targetSlotCount != definition.targetSlotCount ||
            !TermDepositGameEngine.meetsSlotUpgradeRequirements(
              definition: liveUpgrade,
              metaState: liveMeta,
            ) ||
            liveGems < liveUpgrade.gemCost) {
          throw StateError('slot-prerequis');
        }
        tx.set(userRef, <String, dynamic>{
          'gems': liveGems - liveUpgrade.gemCost,
        }, SetOptions(merge: true));
        tx.set(
          metaRef,
          liveMeta.copyWith(slotCount: liveUpgrade.targetSlotCount).toMap(),
          SetOptions(merge: true),
        );
      });
      await ActivityTrackingService.trackCurrentUser(
        type: 'term_deposit_slot_upgraded',
        points: 22,
        counters: const <String, int>{'treasury_slot_upgrades': 1},
        label: 'slot_${definition.targetSlotCount}',
      );
      _showSnack('Slot ${definition.targetSlotCount} débloqué.');
      await _loadDashboard();
    } catch (_) {
      _showSnack('Upgrade de slot impossible.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade600 : detailsColor2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    if (_isBootstrapping) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(22),
        decoration: _panelDecoration(),
        child: Center(
          child: CircularProgressIndicator(
            color: detailsColor2,
            backgroundColor: detailsColor1.withValues(alpha: 0.18),
          ),
        ),
      );
    }

    if (_errorText != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(),
        child: Column(
          children: <Widget>[
            Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _GradientButton(
              label: 'Réessayer',
              onTap: () => _loadDashboard(showLoader: true),
            ),
          ],
        ),
      );
    }

    final isUnlocked =
        (_userData?['is_term_deposit_unlocked'] as bool?) ?? false;
    if (!isUnlocked) {
      return _TreasuryUnlockCard(
        gems: (_userData?['gems'] as num?)?.toInt() ?? 0,
        isLoading: _isActionLoading,
        onUnlock: _unlockFeature,
      );
    }

    final meta = _metaState;
    final board = _board;
    final breakdown = _liveBreakdown;
    if (meta == null || board == null || breakdown == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _motionCtrl,
      builder: (context, _) {
        return _TreasuryDashboard(
          animation: _motionCtrl,
          userData: _userData ?? const <String, dynamic>{},
          meta: meta,
          board: board,
          positions: _positions,
          liveBreakdown: breakdown,
          latestResolution: _latestResolution,
          seasonLeaders: _seasonLeaders,
          isBusy: _isActionLoading,
          isRefreshingBoard: _isRefreshingBoard,
          refreshLoaderAnimation: _refreshLoaderCtrl,
          onRefresh: _refreshBoard,
          onOpenOffer: _showOpenOfferSheet,
          onReroll: _rerollBoard,
          onBreakPosition: _breakFlexiblePosition,
          onClaimLegacy: _claimLegacyPosition,
          onUnlockSkill: _unlockSkill,
          onBuySlotUpgrade: _buySlotUpgrade,
        );
      },
    );
  }
}

class _TreasuryDashboard extends StatelessWidget {
  const _TreasuryDashboard({
    required this.animation,
    required this.userData,
    required this.meta,
    required this.board,
    required this.positions,
    required this.liveBreakdown,
    required this.latestResolution,
    required this.seasonLeaders,
    required this.isBusy,
    required this.isRefreshingBoard,
    required this.refreshLoaderAnimation,
    required this.onRefresh,
    required this.onOpenOffer,
    required this.onReroll,
    required this.onBreakPosition,
    required this.onClaimLegacy,
    required this.onUnlockSkill,
    required this.onBuySlotUpgrade,
  });

  final Animation<double> animation;
  final Map<String, dynamic> userData;
  final TreasuryMetaState meta;
  final TreasuryBoard board;
  final List<TreasuryPosition> positions;
  final TreasuryScoreBreakdown liveBreakdown;
  final TreasuryResolutionPreview? latestResolution;
  final List<Map<String, dynamic>> seasonLeaders;
  final bool isBusy;
  final bool isRefreshingBoard;
  final Animation<double> refreshLoaderAnimation;
  final VoidCallback onRefresh;
  final ValueChanged<TreasuryOffer> onOpenOffer;
  final VoidCallback onReroll;
  final ValueChanged<TreasuryPosition> onBreakPosition;
  final ValueChanged<TreasuryPosition> onClaimLegacy;
  final ValueChanged<TreasurySkillDefinition> onUnlockSkill;
  final ValueChanged<TreasurySlotUpgradeDefinition> onBuySlotUpgrade;

  @override
  Widget build(BuildContext context) {
    final coins = (userData['coins'] as num?)?.toInt() ?? 0;
    final gems = (userData['gems'] as num?)?.toInt() ?? 0;
    final activePositions =
        positions.where((position) => position.isActive).toList();
    final usedSlots = _countUsedSlots(positions);
    final nextSlotUpgrade = TermDepositGameEngine.nextSlotUpgradeFor(meta);
    final rerollCost = TermDepositGameEngine.previewRerollGemCost(
      metaState: meta,
      board: board,
    );

    return DefaultTabController(
      length: 4,
      child: Stack(
        children: <Widget>[
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    children: <Widget>[
                      _TreasuryHeroCard(
                        animation: animation,
                        board: board,
                        meta: meta,
                        liveBreakdown: liveBreakdown,
                        onRefresh: onRefresh,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE6E8EB)),
                          boxShadow: _treasuryShadow,
                        ),
                        child: const TabBar(
                          indicator: BoxDecoration(
                            gradient: _treasuryGradient,
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.black54,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: <Widget>[
                            Tab(text: 'Vue'),
                            Tab(text: 'Offres'),
                            Tab(text: 'Échéances'),
                            Tab(text: 'Pilotage'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: <Widget>[
                _TreasuryTabScrollView(
                  storageKey: 'treasury-tab-overview',
                  onRefresh: onRefresh,
                  children: <Widget>[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        _TreasuryKpiCard(
                          title: 'Cash disponible',
                          value: '${_formatCoins(coins)} coins',
                          subtitle:
                              'Buffer requis ${_formatCoins(liveBreakdown.requiredLiquidBuffer)}',
                          svg: _slotSvg,
                        ),
                        _TreasuryKpiCard(
                          title: 'Ressources premium',
                          value: '$gems gems',
                          subtitle:
                              board.rerollsLeft > 0
                                  ? '${board.rerollsLeft} reroll gratuit restant'
                                  : 'Reroll suivant: $rerollCost gems',
                          svg: _shieldSvg,
                        ),
                        _TreasuryKpiCard(
                          title: 'Slots',
                          value: '$usedSlots / ${meta.slotCount}',
                          subtitle:
                              nextSlotUpgrade != null
                                  ? 'Prochain: slot ${nextSlotUpgrade.targetSlotCount} · ${nextSlotUpgrade.gemCost} gems'
                                  : 'Structure max atteinte',
                          svg: _slotSvg,
                        ),
                        _TreasuryKpiCard(
                          title: 'Saison',
                          value: '${meta.seasonPoints} pts',
                          subtitle: 'Niveau ${meta.level} · ${meta.seasonKey}',
                          svg: _shieldSvg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ObjectivesRibbon(meta: meta, liveBreakdown: liveBreakdown),
                    const SizedBox(height: 14),
                    _TreasuryAdaptiveGrid(
                      children: <Widget>[
                        if (latestResolution != null)
                          _ResolutionCard(resolution: latestResolution!),
                        _LiquidityAlertCard(
                          coins: coins,
                          board: board,
                          liveBreakdown: liveBreakdown,
                        ),
                      ],
                    ),
                  ],
                ),
                _TreasuryTabScrollView(
                  storageKey: 'treasury-tab-offers',
                  onRefresh: onRefresh,
                  children: <Widget>[
                    _YieldCurveCard(
                      animation: animation,
                      board: board,
                      meta: meta,
                      liveBreakdown: liveBreakdown,
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Board du jour',
                      trailing: _InlineActionChip(
                        label:
                            rerollCost == 0
                                ? 'Reroll gratuit'
                                : 'Reroll $rerollCost gems',
                        onTap: onReroll,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          board.offers
                              .map(
                                (offer) => _TreasuryOfferCard(
                                  offer: offer,
                                  availableCoins: coins,
                                  remainingSlots: math.max(
                                    0,
                                    meta.slotCount - usedSlots,
                                  ),
                                  premiumUnlocked: meta.premiumSlotUnlocked,
                                  isBusy: isBusy,
                                  onTap: () => onOpenOffer(offer),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
                _TreasuryTabScrollView(
                  storageKey: 'treasury-tab-timeline',
                  onRefresh: onRefresh,
                  children: <Widget>[
                    _SectionHeader(
                      title: 'Frise d’échéances',
                      trailing: Text(
                        '${activePositions.length} position(s) active(s)',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CashflowTimelineCard(
                      positions: positions,
                      onBreakPosition: onBreakPosition,
                      onClaimLegacy: onClaimLegacy,
                      freeEarlyExitRemaining: meta.freeWithdrawalsRemaining,
                    ),
                  ],
                ),
                _TreasuryTabScrollView(
                  storageKey: 'treasury-tab-pilotage',
                  onRefresh: onRefresh,
                  children: <Widget>[
                    _TreasuryAdaptiveGrid(
                      minChildWidth: 360,
                      children: <Widget>[
                        _TreasurySectionCard(
                          title: 'Compétences & slots',
                          child: _SkillsCard(
                            meta: meta,
                            gems: gems,
                            onUnlockSkill: onUnlockSkill,
                            onBuySlotUpgrade: onBuySlotUpgrade,
                          ),
                        ),
                        _TreasurySectionCard(
                          title: 'Historique / saison',
                          child: _SeasonSummaryCard(
                            meta: meta,
                            seasonLeaders: seasonLeaders,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isRefreshingBoard)
            Positioned.fill(
              child: _TreasuryRefreshLoaderOverlay(
                animation: refreshLoaderAnimation,
              ),
            )
          else if (isBusy)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xBFFFFFFF)),
                child: Center(
                  child: CircularProgressIndicator(color: detailsColor2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TreasuryUnlockCard extends StatelessWidget {
  const _TreasuryUnlockCard({
    required this.gems,
    required this.isLoading,
    required this.onUnlock,
  });

  final int gems;
  final bool isLoading;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Compte à terme',
            style: TextStyle(
              fontFamily: 'Geo',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: <Color>[
                  detailsColor1.withValues(alpha: 0.18),
                  detailsColor2.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text(
              'Tu deviens trésorier: chaque jour, un board de taux apparaît. Tu arbitres entre liquidité, rendement, slots et timing. Les coins servent au cœur du jeu. Les gems servent au premium, aux rerolls, à certains upgrades et au déblocage.',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Solde actuel: $gems gems',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _GradientButton(
            label: isLoading ? 'Déblocage...' : 'Débloquer pour 100 gems',
            onTap: isLoading ? null : onUnlock,
          ),
        ],
      ),
    );
  }
}

class _TreasuryHeroCard extends StatelessWidget {
  const _TreasuryHeroCard({
    required this.animation,
    required this.board,
    required this.meta,
    required this.liveBreakdown,
    required this.onRefresh,
  });

  final Animation<double> animation;
  final TreasuryBoard board;
  final TreasuryMetaState meta;
  final TreasuryScoreBreakdown liveBreakdown;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            detailsColor1.withValues(alpha: 0.16),
            detailsColor2.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: detailsColor1.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Cockpit de trésorerie',
                      style: TextStyle(
                        fontFamily: 'Geo',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      board.regime.label,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      board.regime.description,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final dx = math.sin(animation.value * math.pi * 2) * 9;
                  final dy = math.cos(animation.value * math.pi * 2) * 7;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: child,
                  );
                },
                child: SvgPicture.string(
                  _treasuryHeroSvg,
                  width: 98,
                  height: 98,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _InfoChip(label: 'Score live ${liveBreakdown.finalScore}/100'),
              _InfoChip(
                label: 'Ladder ${liveBreakdown.distinctMaturityCount}/3',
              ),
              _InfoChip(
                label:
                    'Buffer ${_formatCoins(liveBreakdown.requiredLiquidBuffer)}',
              ),
              if (board.forecastTomorrow != null)
                _InfoChip(label: 'Demain: ${board.forecastTomorrow!.label}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _GradientButton(
                  label: 'Actualiser le board',
                  onTap: onRefresh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiquidityAlertCard extends StatelessWidget {
  const _LiquidityAlertCard({
    required this.coins,
    required this.board,
    required this.liveBreakdown,
  });

  final int coins;
  final TreasuryBoard board;
  final TreasuryScoreBreakdown liveBreakdown;

  @override
  Widget build(BuildContext context) {
    final requiredBuffer = liveBreakdown.requiredLiquidBuffer;
    final safe = coins >= requiredBuffer;
    return _TreasurySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                safe ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: safe ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  safe
                      ? 'Buffer liquide solide pour absorber les événements du jour.'
                      : 'Trésorerie tendue: un choc peut forcer une pénalité ou casser un dépôt flexible.',
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...board.events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color:
                            event.severity == TreasuryEventSeverity.high
                                ? Colors.red.shade400
                                : Colors.orange.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            style: const TextStyle(
                              color: Colors.black54,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_formatCoins(event.requiredLiquidCoins)}\nliquides',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YieldCurveCard extends StatelessWidget {
  const _YieldCurveCard({
    required this.animation,
    required this.board,
    required this.meta,
    required this.liveBreakdown,
  });

  final Animation<double> animation;
  final TreasuryBoard board;
  final TreasuryMetaState meta;
  final TreasuryScoreBreakdown liveBreakdown;

  @override
  Widget build(BuildContext context) {
    return _TreasurySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Mini yield curve',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lis la pente avant de bloquer trop longtemps. Le score live sépare rendement, liquidité et discipline.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.58),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _YieldCurvePainter(
                    shortRate: board.shortRate,
                    mediumRate: board.mediumRate,
                    longRate: board.longRate,
                    phase: animation.value,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _CurveRateLabel(label: 'Court', value: board.shortRate),
              _CurveRateLabel(label: 'Moyen', value: board.mediumRate),
              _CurveRateLabel(label: 'Long', value: board.longRate),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ScorePill(label: 'Rendement', score: liveBreakdown.yieldScore),
              _ScorePill(
                label: 'Liquidité',
                score: liveBreakdown.liquidityScore,
              ),
              _ScorePill(
                label: 'Discipline',
                score: liveBreakdown.disciplineScore,
              ),
              _InfoChip(label: 'Ladder bonus +${liveBreakdown.ladderBonus}'),
              if (meta.unlockedSkillIds.contains(
                    kTreasurySkillForecastTomorrow,
                  ) &&
                  board.forecastTomorrow != null)
                _InfoChip(label: 'Prévision: ${board.forecastTomorrow!.label}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashflowTimelineCard extends StatelessWidget {
  const _CashflowTimelineCard({
    required this.positions,
    required this.onBreakPosition,
    required this.onClaimLegacy,
    required this.freeEarlyExitRemaining,
  });

  final List<TreasuryPosition> positions;
  final ValueChanged<TreasuryPosition> onBreakPosition;
  final ValueChanged<TreasuryPosition> onClaimLegacy;
  final int freeEarlyExitRemaining;

  @override
  Widget build(BuildContext context) {
    final active = positions.where((position) => position.isActive).toList();
    if (active.isEmpty) {
      return _TreasurySurfaceCard(
        child: Row(
          children: const <Widget>[
            Icon(Icons.schedule_rounded, color: Colors.black54),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucune position active. Utilise le board du jour pour construire une ladder.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _TreasurySurfaceCard(
      child: Column(
        children:
            active
                .map(
                  (position) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PositionCard(
                      position: position,
                      freeEarlyExitRemaining: freeEarlyExitRemaining,
                      onBreakPosition: onBreakPosition,
                      onClaimLegacy: onClaimLegacy,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _TreasuryAdaptiveGrid extends StatelessWidget {
  const _TreasuryAdaptiveGrid({
    required this.children,
    this.minChildWidth = 320,
  });

  final List<Widget> children;
  final double minChildWidth;

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.toList();
    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final canUseTwoColumns =
            constraints.maxWidth >= (minChildWidth * 2) + spacing;
        if (!canUseTwoColumns) {
          return Column(
            children: <Widget>[
              for (
                var index = 0;
                index < visibleChildren.length;
                index++
              ) ...<Widget>[
                visibleChildren[index],
                if (index != visibleChildren.length - 1)
                  SizedBox(height: spacing),
              ],
            ],
          );
        }

        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              visibleChildren
                  .map((child) => SizedBox(width: itemWidth, child: child))
                  .toList(),
        );
      },
    );
  }
}

class _TreasurySectionCard extends StatelessWidget {
  const _TreasurySectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(title: title),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _TreasuryRefreshLoaderOverlay extends StatelessWidget {
  const _TreasuryRefreshLoaderOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xCFFFFFFF)),
      child: Center(
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6E8EB)),
            boxShadow: _treasuryShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final angle = animation.value * math.pi * 2;
                  final dx = math.sin(angle) * 5;
                  final dy = math.cos(angle) * 4;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.rotate(angle: angle, child: child),
                  );
                },
                child: SvgPicture.string(
                  _treasuryRefreshLoaderSvg,
                  width: 92,
                  height: 92,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Actualisation du board',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nouveaux taux, événements et opportunités en cours de recalcul.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreasuryTabScrollView extends StatelessWidget {
  const _TreasuryTabScrollView({
    required this.storageKey,
    required this.onRefresh,
    required this.children,
  });

  final String storageKey;
  final VoidCallback onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: detailsColor2,
      onRefresh: () async => onRefresh(),
      child: ListView(
        key: PageStorageKey<String>(storageKey),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 18),
        children: children,
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({
    required this.meta,
    required this.gems,
    required this.onUnlockSkill,
    required this.onBuySlotUpgrade,
  });

  final TreasuryMetaState meta;
  final int gems;
  final ValueChanged<TreasurySkillDefinition> onUnlockSkill;
  final ValueChanged<TreasurySlotUpgradeDefinition> onBuySlotUpgrade;

  @override
  Widget build(BuildContext context) {
    final slotUpgrade = TermDepositGameEngine.nextSlotUpgradeFor(meta);
    final slotReason =
        slotUpgrade == null
            ? null
            : _slotUpgradeLockReason(
              definition: slotUpgrade,
              meta: meta,
              gems: gems,
            );
    final canBuySlot = slotUpgrade != null && slotReason == null;
    return _TreasurySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Slots: ${meta.slotCount} · Retraits gratuits: ${meta.freeWithdrawalsRemaining} · Shields: ${meta.eventShieldRemaining} · $gems gems',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (slotUpgrade != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6E8EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: _treasuryGradient,
                      ),
                      child: const Icon(
                        Icons.space_dashboard_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Débloquer slot ${slotUpgrade.targetSlotCount}',
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${slotUpgrade.gemCost} gems',
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Préreq: niv. ${slotUpgrade.requiredLevel} + ${slotUpgrade.requiredSeasonPoints} pts',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          if (slotReason != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              slotReason,
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _InlineActionChip(
                      label: 'Débloquer slot ${slotUpgrade.targetSlotCount}',
                      onTap:
                          canBuySlot
                              ? () => onBuySlotUpgrade(slotUpgrade)
                              : null,
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: detailsColor1.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: detailsColor1.withValues(alpha: 0.24),
                  ),
                ),
                child: const Text(
                  'Structure maximale atteinte: 4 slots opérationnels.',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ...TermDepositGameEngine.skillCatalog.map((definition) {
            final unlocked = _isSkillUnlocked(definition, meta);
            final reason =
                unlocked
                    ? null
                    : _skillLockReason(
                      definition: definition,
                      meta: meta,
                      gems: gems,
                    );
            final canUnlock = !unlocked && reason == null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      unlocked
                          ? detailsColor1.withValues(alpha: 0.10)
                          : const Color(0xFFF6F7F8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        unlocked
                            ? detailsColor1.withValues(alpha: 0.35)
                            : const Color(0xFFE6E8EB),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: unlocked ? _treasuryGradient : null,
                        color: unlocked ? null : Colors.white,
                      ),
                      child: Icon(
                        unlocked
                            ? Icons.check_rounded
                            : Icons.auto_awesome_rounded,
                        color: unlocked ? Colors.white : detailsColor2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            definition.label,
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            definition.description,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _skillCostLabel(definition),
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Préreq: niv. ${definition.requiredLevel} + ${definition.requiredSeasonPoints} pts',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          if (reason != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              reason,
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (unlocked)
                      const _InfoChip(label: 'Actif')
                    else
                      _InlineActionChip(
                        label: canUnlock ? 'Débloquer' : 'Verrouillé',
                        onTap:
                            canUnlock ? () => onUnlockSkill(definition) : null,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SeasonSummaryCard extends StatelessWidget {
  const _SeasonSummaryCard({required this.meta, required this.seasonLeaders});

  final TreasuryMetaState meta;
  final List<Map<String, dynamic>> seasonLeaders;

  @override
  Widget build(BuildContext context) {
    return _TreasurySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _InfoChip(
                label:
                    'Moy. finale ${meta.seasonFinalAverage.toStringAsFixed(1)}',
              ),
              _InfoChip(
                label:
                    'Moy. rendement ${meta.seasonYieldAverage.toStringAsFixed(1)}',
              ),
              _InfoChip(
                label:
                    'Moy. liquidité ${meta.seasonLiquidityAverage.toStringAsFixed(1)}',
              ),
              _InfoChip(label: 'Meilleur ladder ${meta.bestLadder}'),
            ],
          ),
          const SizedBox(height: 16),
          if (seasonLeaders.isEmpty)
            const Text(
              'Aucun classement saisonnier visible pour l’instant.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...seasonLeaders.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: index == 0 ? _treasuryGradient : null,
                        color: index == 0 ? null : const Color(0xFFF1F2F4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index == 0 ? Colors.white : textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (row['displayName'] as String?)?.trim().isNotEmpty ==
                                true
                            ? (row['displayName'] as String).trim()
                            : 'Joueur',
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      ((row['finalAverageScore'] as num?)?.toDouble() ?? 0)
                          .toStringAsFixed(1),
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
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

class _ObjectivesRibbon extends StatelessWidget {
  const _ObjectivesRibbon({required this.meta, required this.liveBreakdown});

  final TreasuryMetaState meta;
  final TreasuryScoreBreakdown liveBreakdown;

  @override
  Widget build(BuildContext context) {
    final objectives = <_ObjectiveTileData>[
      _ObjectiveTileData(
        title: 'Buffer 7 jours',
        subtitle: 'Rester liquide sans casser la structure',
        progress: (meta.liquidityStreakDays / 7).clamp(0, 1),
        footer: '${meta.liquidityStreakDays}/7',
      ),
      _ObjectiveTileData(
        title: '8% cumulés',
        subtitle: 'Rendement capté depuis le début de saison',
        progress: ((meta.cumulativeYieldRate * 100) / 8).clamp(0, 1),
        footer: '${(meta.cumulativeYieldRate * 100).toStringAsFixed(1)}%',
      ),
      _ObjectiveTileData(
        title: 'Ladder propre',
        subtitle: 'Atteindre 3 buckets distincts',
        progress: (liveBreakdown.distinctMaturityCount / 3).clamp(0, 1),
        footer: '${liveBreakdown.distinctMaturityCount}/3',
      ),
    ];

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: objectives.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder:
            (context, index) => _ObjectiveTile(data: objectives[index]),
      ),
    );
  }
}

class _TreasuryKpiCard extends StatelessWidget {
  const _TreasuryKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.svg,
  });

  final String title;
  final String value;
  final String subtitle;
  final String svg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: _TreasurySurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SvgPicture.string(svg, width: 34, height: 34),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreasuryOfferCard extends StatelessWidget {
  const _TreasuryOfferCard({
    required this.offer,
    required this.availableCoins,
    required this.remainingSlots,
    required this.premiumUnlocked,
    required this.isBusy,
    required this.onTap,
  });

  final TreasuryOffer offer;
  final int availableCoins;
  final int remainingSlots;
  final bool premiumUnlocked;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blockedBySlot = remainingSlots < offer.slotCost;
    final blockedByPremium = offer.requiresPremiumSlot && !premiumUnlocked;
    final disabled =
        isBusy || availableCoins <= 0 || blockedBySlot || blockedByPremium;
    final payoutPreview = TermDepositGameEngine.payoutForOffer(250, offer);

    return SizedBox(
      width: 168,
      child: _TreasurySurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              offer.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            _InfoChip(label: offer.productType.label),
            const SizedBox(height: 10),
            Text(
              _formatPercent(offer.apy),
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            Text(
              '${offer.durationDays} jours · ${offer.lockMode.key}',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  label:
                      '${offer.slotCost} slot${offer.slotCost > 1 ? 's' : ''}',
                ),
                if (offer.requiresPremiumSlot)
                  const _InfoChip(label: 'Premium'),
              ],
            ),
            if (offer.boostReason != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                offer.boostReason!,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Exemple: 250 -> $payoutPreview coins',
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _GradientButton(
              label:
                  blockedByPremium
                      ? 'Premium slot requis'
                      : blockedBySlot
                      ? 'Slots insuffisants'
                      : 'Placer un dépôt',
              onTap: disabled ? null : onTap,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.position,
    required this.freeEarlyExitRemaining,
    required this.onBreakPosition,
    required this.onClaimLegacy,
  });

  final TreasuryPosition position;
  final int freeEarlyExitRemaining;
  final ValueChanged<TreasuryPosition> onBreakPosition;
  final ValueChanged<TreasuryPosition> onClaimLegacy;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isReady = !position.maturesAt.isAfter(now);
    final isSoon = !isReady && position.maturesAt.difference(now).inDays <= 2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isSoon
                  ? detailsColor1.withValues(alpha: 0.35)
                  : const Color(0xFFE6E8EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  position.isLegacy
                      ? 'Legacy ${position.legacyCurrencyType}'
                      : position.offerSnapshot.label,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              _InfoChip(
                label:
                    position.isLegacy
                        ? 'Legacy'
                        : position.offerSnapshot.productType.label,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _InfoChip(
                label:
                    '${_formatCoins(position.principalCoins)} -> ${_formatCoins(position.payoutCoins)}',
              ),
              _InfoChip(label: _formatMaturity(position.maturesAt)),
              if (!position.isLegacy)
                _InfoChip(
                  label:
                      '${position.slotCost} slot${position.slotCost > 1 ? 's' : ''}',
                ),
              if (position.opportunityCostCoins > 0)
                _InfoChip(
                  label:
                      'Coût opp. ${_formatCoins(position.opportunityCostCoins)}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (position.isLegacy && isReady)
            _GradientButton(
              label: 'Claim legacy',
              onTap: () => onClaimLegacy(position),
              compact: true,
            )
          else if (!position.isLegacy &&
              position.isFlexible &&
              position.isActive)
            Row(
              children: <Widget>[
                Expanded(
                  child: _GradientButton(
                    label:
                        freeEarlyExitRemaining > 0
                            ? 'Sortie flexible gratuite'
                            : 'Sortie flexible (-8%)',
                    onTap: () => onBreakPosition(position),
                    compact: true,
                  ),
                ),
              ],
            )
          else
            Text(
              isReady
                  ? 'Position réglée au prochain passage.'
                  : isSoon
                  ? 'Maturité imminente: surveille les besoins de liquidité.'
                  : 'Structure active.',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({required this.resolution});

  final TreasuryResolutionPreview resolution;

  @override
  Widget build(BuildContext context) {
    return _TreasurySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Debrief précédent board',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            resolution.summary,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ScorePill(
                label: 'Rendement',
                score: resolution.scoreBreakdown.yieldScore,
              ),
              _ScorePill(
                label: 'Liquidité',
                score: resolution.scoreBreakdown.liquidityScore,
              ),
              _ScorePill(
                label: 'Discipline',
                score: resolution.scoreBreakdown.disciplineScore,
              ),
              _InfoChip(
                label: 'Final ${resolution.scoreBreakdown.finalScore}/100',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            resolution.scoreBreakdown.debrief,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferDepositSheet extends StatefulWidget {
  const _OfferDepositSheet({required this.offer, required this.availableCoins});

  final TreasuryOffer offer;
  final int availableCoins;

  @override
  State<_OfferDepositSheet> createState() => _OfferDepositSheetState();
}

class _OfferDepositSheetState extends State<_OfferDepositSheet> {
  late int _amount;

  int get _minAmount =>
      widget.availableCoins >= 50 ? 50 : math.max(1, widget.availableCoins);

  @override
  void initState() {
    super.initState();
    _amount = math.max(_minAmount, math.min(widget.availableCoins, 250));
  }

  @override
  Widget build(BuildContext context) {
    final payout = TermDepositGameEngine.payoutForOffer(_amount, widget.offer);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.offer.label,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choisis ton allocation en coins. Le payout est garanti si tu tiens jusqu’à l’échéance.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Allocation: ${_formatCoins(_amount)} coins',
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Slider(
                  value: _amount.toDouble(),
                  min: _minAmount.toDouble(),
                  max: widget.availableCoins.toDouble(),
                  divisions: math.max(
                    1,
                    ((widget.availableCoins - _minAmount) ~/
                        math.max(1, widget.availableCoins >= 1000 ? 50 : 10)),
                  ),
                  activeColor: detailsColor1,
                  inactiveColor: detailsColor2.withValues(alpha: 0.12),
                  onChanged:
                      widget.availableCoins == _minAmount
                          ? null
                          : (value) {
                            setState(() {
                              _amount = value.round();
                            });
                          },
                ),
                Wrap(
                  spacing: 8,
                  children:
                      <int>[100, 250, 500, 1000]
                          .where((value) => value <= widget.availableCoins)
                          .map(
                            (value) => ActionChip(
                              label: Text('$value'),
                              onPressed: () => setState(() => _amount = value),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Payout estimé: ${_formatCoins(payout)} coins',
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'APY ${_formatPercent(widget.offer.apy)} · ${widget.offer.durationDays} jours · ${widget.offer.productType.label}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GradientButton(
                  label: 'Confirmer le dépôt',
                  onTap: () => Navigator.of(context).pop(_amount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreasurySurfaceCard extends StatelessWidget {
  const _TreasurySurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: _treasuryShadow,
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          height: compact ? 42 : 52,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: _treasuryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _treasuryShadow,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineActionChip extends StatelessWidget {
  const _InlineActionChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: onTap == null ? const Color(0xFFF1F2F4) : detailsColor2,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? Colors.black45 : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _scoreColor(score),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label $score',
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurveRateLabel extends StatelessWidget {
  const _CurveRateLabel({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatPercent(value),
          style: const TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ObjectiveTileData {
  const _ObjectiveTileData({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String footer;
}

class _ObjectiveTile extends StatelessWidget {
  const _ObjectiveTile({required this.data});

  final _ObjectiveTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: <Color>[
            detailsColor1.withValues(alpha: 0.14),
            detailsColor2.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: detailsColor1.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: data.progress,
              color: detailsColor1,
              backgroundColor: detailsColor2.withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.footer,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _YieldCurvePainter extends CustomPainter {
  _YieldCurvePainter({
    required this.shortRate,
    required this.mediumRate,
    required this.longRate,
    required this.phase,
  });

  final double shortRate;
  final double mediumRate;
  final double longRate;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 18.0;
    final points = <Offset>[
      Offset(padding, _project(shortRate, size.height, padding)),
      Offset(size.width / 2, _project(mediumRate, size.height, padding)),
      Offset(size.width - padding, _project(longRate, size.height, padding)),
    ];

    final axisPaint =
        Paint()
          ..color = const Color(0xFFE4E6EA)
          ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      final y = padding + ((size.height - (padding * 2)) / 3) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        axisPaint,
      );
    }

    final fillPath =
        Path()
          ..moveTo(points.first.dx, size.height - padding)
          ..lineTo(points.first.dx, points.first.dy)
          ..quadraticBezierTo(
            points[1].dx - 28,
            points[1].dy,
            points[1].dx,
            points[1].dy,
          )
          ..quadraticBezierTo(
            points[2].dx - 28,
            points[2].dy,
            points[2].dx,
            points[2].dy,
          )
          ..lineTo(points.last.dx, size.height - padding)
          ..close();

    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[
              detailsColor1.withValues(alpha: 0.22),
              detailsColor2.withValues(alpha: 0.06),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    path.quadraticBezierTo(
      points[1].dx - 28,
      points[1].dy,
      points[1].dx,
      points[1].dy,
    );
    path.quadraticBezierTo(
      points[2].dx - 28,
      points[2].dy,
      points[2].dx,
      points[2].dy,
    );

    final curvePaint =
        Paint()
          ..shader = _treasuryGradient.createShader(Offset.zero & size)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, curvePaint);

    final pulse = 0.6 + (math.sin(phase * math.pi * 2) * 0.4);
    for (final point in points) {
      final glow =
          Paint()
            ..color = detailsColor1.withValues(alpha: 0.18 + (0.12 * pulse))
            ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 11 + (pulse * 2), glow);
      final dot =
          Paint()
            ..color = detailsColor2
            ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 5, dot);
    }
  }

  double _project(double rate, double height, double padding) {
    final normalized = ((rate - 0.04) / 0.40).clamp(0.0, 1.0);
    return height - padding - ((height - (padding * 2)) * normalized);
  }

  @override
  bool shouldRepaint(covariant _YieldCurvePainter oldDelegate) {
    return shortRate != oldDelegate.shortRate ||
        mediumRate != oldDelegate.mediumRate ||
        longRate != oldDelegate.longRate ||
        phase != oldDelegate.phase;
  }
}

class _TreasurySyncResult {
  const _TreasurySyncResult({
    required this.latestResolution,
    required this.resolvedBoardsCount,
    required this.activityPoints,
  });

  final TreasuryResolutionPreview? latestResolution;
  final int resolvedBoardsCount;
  final int activityPoints;
}

class _AutoSettlementResult {
  const _AutoSettlementResult({
    required this.positions,
    required this.coinsDelta,
    required this.changed,
  });

  final List<TreasuryPosition> positions;
  final int coinsDelta;
  final bool changed;
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE6E8EB)),
    boxShadow: _treasuryShadow,
  );
}

String _skillCostLabel(TreasurySkillDefinition definition) {
  if (definition.usesSeasonPointsCurrency) {
    return '${definition.seasonPointCost} pts saison';
  }
  return '${definition.gemCost} gems';
}

bool _isSkillUnlocked(
  TreasurySkillDefinition definition,
  TreasuryMetaState meta,
) {
  if (meta.unlockedSkillIds.contains(definition.id)) return true;
  if (definition.id == kTreasurySkillPremiumSlot && meta.premiumSlotUnlocked) {
    return true;
  }
  return false;
}

String? _skillLockReason({
  required TreasurySkillDefinition definition,
  required TreasuryMetaState meta,
  required int gems,
}) {
  if (meta.level < definition.requiredLevel) {
    return 'Niveau requis';
  }
  if (meta.seasonPoints < definition.requiredSeasonPoints) {
    return 'Points de saison requis';
  }
  if (definition.usesSeasonPointsCurrency &&
      meta.seasonPoints < definition.seasonPointCost) {
    return 'Pas assez de points de saison';
  }
  if (!definition.usesSeasonPointsCurrency && gems < definition.gemCost) {
    return 'Gems insuffisants';
  }
  return null;
}

String? _slotUpgradeLockReason({
  required TreasurySlotUpgradeDefinition definition,
  required TreasuryMetaState meta,
  required int gems,
}) {
  if (meta.level < definition.requiredLevel) {
    return 'Niveau requis';
  }
  if (meta.seasonPoints < definition.requiredSeasonPoints) {
    return 'Points de saison requis';
  }
  if (gems < definition.gemCost) {
    return 'Gems insuffisants';
  }
  return null;
}

Color _scoreColor(int score) {
  if (score >= 75) return Colors.green.shade600;
  if (score >= 55) return detailsColor1;
  return Colors.orange.shade700;
}

List<TreasuryPosition> _sortPositions(List<TreasuryPosition> positions) {
  final next = List<TreasuryPosition>.from(positions);
  next.sort((a, b) => a.maturesAt.compareTo(b.maturesAt));
  return next;
}

int _countUsedSlots(List<TreasuryPosition> positions) {
  return positions
      .where((position) => position.isActive && !position.isLegacy)
      .fold<int>(0, (total, position) => total + position.slotCost);
}

String _formatCoins(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _formatMaturity(DateTime value) {
  final now = DateTime.now();
  if (!value.isAfter(now)) return 'Échu';
  final diff = value.difference(now);
  if (diff.inDays > 0) return 'Dans ${diff.inDays}j';
  if (diff.inHours > 0) return 'Dans ${diff.inHours}h';
  return 'Dans ${math.max(1, diff.inMinutes)}min';
}

bool _metaChanged(TreasuryMetaState a, TreasuryMetaState b) {
  return a.level != b.level ||
      a.xp != b.xp ||
      a.slotCount != b.slotCount ||
      a.premiumSlotUnlocked != b.premiumSlotUnlocked ||
      a.seasonKey != b.seasonKey ||
      a.seasonPoints != b.seasonPoints ||
      a.freeWithdrawalsRemaining != b.freeWithdrawalsRemaining ||
      a.eventShieldRemaining != b.eventShieldRemaining ||
      a.lastResolvedDayKey != b.lastResolvedDayKey ||
      a.liquidityStreakDays != b.liquidityStreakDays ||
      a.ladderHitCount != b.ladderHitCount ||
      a.cumulativeYieldRate != b.cumulativeYieldRate ||
      a.weekKey != b.weekKey ||
      a.seasonRuns != b.seasonRuns ||
      a.bestLadder != b.bestLadder ||
      a.seasonYieldAverage != b.seasonYieldAverage ||
      a.seasonLiquidityAverage != b.seasonLiquidityAverage ||
      a.seasonDisciplineAverage != b.seasonDisciplineAverage ||
      a.seasonFinalAverage != b.seasonFinalAverage ||
      !listEquals(a.unlockedSkillIds, b.unlockedSkillIds);
}

bool _positionChanged(TreasuryPosition? previous, TreasuryPosition current) {
  if (previous == null) return true;
  return previous.status != current.status ||
      previous.brokenEarly != current.brokenEarly ||
      previous.liquidityPenaltyPreview != current.liquidityPenaltyPreview ||
      previous.opportunityCostCoins != current.opportunityCostCoins ||
      previous.payoutCoins != current.payoutCoins;
}

double _realizedYieldRate({
  required List<TreasuryPosition> beforePositions,
  required List<TreasuryPosition> afterPositions,
}) {
  final beforeById = <String, TreasuryPosition>{
    for (final position in beforePositions) position.id: position,
  };
  var principal = 0;
  var profit = 0;
  for (final updated in afterPositions) {
    final before = beforeById[updated.id];
    if (before == null || before.isLegacy || !before.isActive) continue;
    final settled = updated.status == 'settled' || updated.status == 'broken';
    if (!settled) continue;
    principal += updated.principalCoins;
    profit += updated.payoutCoins - updated.principalCoins;
  }
  if (principal <= 0) return 0;
  return profit / principal;
}

TreasuryMetaState _applyResolutionToMeta({
  required TreasuryMetaState meta,
  required TreasuryScoreBreakdown breakdown,
  required String dayKey,
  required DateTime now,
  required double realizedYieldRate,
}) {
  final nextRuns = meta.seasonRuns + 1;
  double avg(double previous, double incoming) {
    if (meta.seasonRuns == 0) return incoming;
    return ((previous * meta.seasonRuns) + incoming) / nextRuns;
  }

  final nextMeta = meta.copyWith(
    xp: meta.xp + math.max(16, breakdown.finalScore),
    seasonPoints: meta.seasonPoints + math.max(8, breakdown.finalScore ~/ 4),
    lastResolvedDayKey: dayKey,
    liquidityStreakDays:
        breakdown.liquidityScore >= 70 ? meta.liquidityStreakDays + 1 : 0,
    ladderHitCount: meta.ladderHitCount + (breakdown.ladderBonus > 0 ? 1 : 0),
    cumulativeYieldRate: math.max(
      0,
      meta.cumulativeYieldRate + realizedYieldRate,
    ),
    seasonRuns: nextRuns,
    bestLadder: math.max(meta.bestLadder, breakdown.distinctMaturityCount),
    seasonYieldAverage: avg(
      meta.seasonYieldAverage,
      breakdown.yieldScore.toDouble(),
    ),
    seasonLiquidityAverage: avg(
      meta.seasonLiquidityAverage,
      breakdown.liquidityScore.toDouble(),
    ),
    seasonDisciplineAverage: avg(
      meta.seasonDisciplineAverage,
      breakdown.disciplineScore.toDouble(),
    ),
    seasonFinalAverage: avg(
      meta.seasonFinalAverage,
      breakdown.finalScore.toDouble(),
    ),
  );
  return TermDepositGameEngine.normalizeMetaState(nextMeta, now: now);
}

_AutoSettlementResult _settleAutoMatures({
  required List<TreasuryPosition> positions,
  required DateTime now,
}) {
  var changed = false;
  var coinsDelta = 0;
  final nextPositions = <TreasuryPosition>[];
  for (final position in positions) {
    if (position.isLegacy ||
        !position.isActive ||
        position.maturesAt.isAfter(now)) {
      nextPositions.add(position);
      continue;
    }
    changed = true;
    coinsDelta += position.payoutCoins;
    nextPositions.add(position.copyWith(status: 'settled'));
  }
  return _AutoSettlementResult(
    positions: nextPositions,
    coinsDelta: coinsDelta,
    changed: changed,
  );
}

@visibleForTesting
class TermDepositUiPreview extends StatelessWidget {
  const TermDepositUiPreview({
    super.key,
    this.lowLiquidity = false,
    this.premiumLocked = true,
    this.showDebrief = true,
  });

  final bool lowLiquidity;
  final bool premiumLocked;
  final bool showDebrief;

  @override
  Widget build(BuildContext context) {
    final now = DateTime(2026, 3, 13, 10);
    final baseMeta = TermDepositGameEngine.defaultMetaState(now: now).copyWith(
      xp: 460,
      seasonPoints: 180,
      premiumSlotUnlocked: !premiumLocked,
      unlockedSkillIds:
          premiumLocked
              ? <String>[kTreasurySkillExtraReroll]
              : <String>[
                kTreasurySkillExtraReroll,
                kTreasurySkillForecastTomorrow,
                kTreasurySkillPremiumSlot,
              ],
      liquidityStreakDays: 5,
      ladderHitCount: 2,
      cumulativeYieldRate: 0.056,
      seasonRuns: 4,
      bestLadder: 3,
      seasonYieldAverage: 69,
      seasonLiquidityAverage: 73,
      seasonDisciplineAverage: 66,
      seasonFinalAverage: 71,
    );
    final meta = TermDepositGameEngine.normalizeMetaState(baseMeta, now: now);
    final generatedBoard = TermDepositGameEngine.buildBoard(
      uid: 'preview',
      dayKey: _localTreasuryDayKey(now),
      metaState: meta,
      rerollsUsed: 0,
      now: now,
    );
    final previewOffers = List<TreasuryOffer>.from(generatedBoard.offers);
    if (premiumLocked && previewOffers.isNotEmpty) {
      final firstOffer = previewOffers.first;
      previewOffers[0] = TreasuryOffer(
        id: firstOffer.id,
        productType: TreasuryProductType.premium,
        durationDays: firstOffer.durationDays,
        apy: firstOffer.apy,
        lockMode: firstOffer.lockMode,
        slotCost: math.max(1, firstOffer.slotCost),
        requiresPremiumSlot: true,
        label: 'Offre premium visible',
        boostReason: firstOffer.boostReason ?? 'Nécessite un premium slot.',
      );
    }
    final board = generatedBoard.copyWith(offers: previewOffers);
    final positions = _sortPositions(<TreasuryPosition>[
      TreasuryPosition(
        id: 'pos_1',
        principalCoins: 240,
        offerSnapshot: board.offers.first,
        openedAt: now.subtract(const Duration(days: 1)),
        maturesAt: now.add(const Duration(days: 2)),
        status: 'active',
        brokenEarly: false,
        liquidityPenaltyPreview: 0,
        opportunityCostCoins: 16,
        payoutCoins: TermDepositGameEngine.payoutForOffer(
          240,
          board.offers.first,
        ),
        isLegacy: false,
        legacyCurrencyType: 'coins',
        startDayKey: _localTreasuryDayKey(
          now.subtract(const Duration(days: 1)),
        ),
        maturesDayKey: _localTreasuryDayKey(now.add(const Duration(days: 2))),
      ),
      TreasuryPosition(
        id: 'pos_2',
        principalCoins: 360,
        offerSnapshot: board.offers[1],
        openedAt: now.subtract(const Duration(days: 3)),
        maturesAt: now.add(const Duration(days: 6)),
        status: 'active',
        brokenEarly: false,
        liquidityPenaltyPreview: 0,
        opportunityCostCoins: 0,
        payoutCoins: TermDepositGameEngine.payoutForOffer(360, board.offers[1]),
        isLegacy: false,
        legacyCurrencyType: 'coins',
        startDayKey: _localTreasuryDayKey(
          now.subtract(const Duration(days: 3)),
        ),
        maturesDayKey: _localTreasuryDayKey(now.add(const Duration(days: 6))),
      ),
      TreasuryPosition(
        id: 'legacy_1',
        principalCoins: 150,
        offerSnapshot: board.offers[2],
        openedAt: now.subtract(const Duration(days: 10)),
        maturesAt: now.subtract(const Duration(hours: 2)),
        status: 'active',
        brokenEarly: false,
        liquidityPenaltyPreview: 0,
        opportunityCostCoins: 0,
        payoutCoins: 165,
        isLegacy: true,
        legacyCurrencyType: 'gems',
        startDayKey: '',
        maturesDayKey: '',
      ),
    ]);
    final breakdown = TermDepositGameEngine.scoreTreasury(
      board: board,
      positions: positions,
      availableCoins: lowLiquidity ? 90 : 520,
      skillState: meta.toSkillState(forecastTomorrow: board.forecastTomorrow),
    );
    final resolution = TreasuryResolutionPreview(
      newCoinsBalance: 640,
      maturedPayoutCoins: 150,
      bonusCoins: 30,
      penaltyCoins: 0,
      forcedBreakCoins: 0,
      brokenPositionIds: const <String>[],
      updatedPositions: positions,
      shieldUsed: false,
      scoreBreakdown: breakdown,
      summary: '+150 coins libérés à échéance · +30 de bonus de liquidité',
    );

    return MaterialApp(
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: _TreasuryDashboard(
            animation: const AlwaysStoppedAnimation<double>(0.3),
            userData: <String, dynamic>{
              'coins': lowLiquidity ? 90 : 520,
              'gems': 220,
              'is_term_deposit_unlocked': true,
            },
            meta: meta,
            board: board,
            positions: positions,
            liveBreakdown: breakdown,
            latestResolution: showDebrief ? resolution : null,
            seasonLeaders: const <Map<String, dynamic>>[
              <String, dynamic>{
                'displayName': 'Loic',
                'finalAverageScore': 78.4,
                'bestLadder': 3,
              },
            ],
            isBusy: false,
            isRefreshingBoard: false,
            refreshLoaderAnimation: const AlwaysStoppedAnimation<double>(0.4),
            onRefresh: () {},
            onOpenOffer: (_) {},
            onReroll: () {},
            onBreakPosition: (_) {},
            onClaimLegacy: (_) {},
            onUnlockSkill: (_) {},
            onBuySlotUpgrade: (_) {},
          ),
        ),
      ),
    );
  }
}
