import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fintech/services/yahoo_finance_service.dart';

/// Page Communauté : mini-jeux communautaires basés sur les cours réels.
/// - Défis “Cible de cours”
/// - Duels Tendance (CAC40/SBF120)
/// - Challenges de volatilité (Range vs Breakout)
///
/// Firestore:
/// collection `community_games` :
///   id, type ('target','duel','range'), ticker, currency, targetPrice, rangeLow, rangeHigh,
///   horizonDays, bandPct, creatorId, creatorName, createdAt, state ('open','closed'),
///   longPool, shortPool, creationFee, creatorStake, deadline (timestamp), meta fields.
/// subcollection `participants` : {userId, userName, side ('long','short'), stake, joinedAt}
/// Sides: target -> 'zone' (long) vs 'off' (short), duel -> 'bull'/'bear', range -> 'range'/'breakout'.
///
/// NB: Settlement non implémenté ici (back-end/job nécessaire). Cette page gère création et participation
/// avec contrôle basic (pas de double participation, pas de mise sur son propre défi).
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        title: const Text('Communauté'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Cibles de cours'),
            Tab(text: 'Duels tendance'),
            Tab(text: 'Volatilité'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TargetTab(firestore: _firestore, auth: _auth),
          _DuelTab(firestore: _firestore, auth: _auth),
          _RangeTab(firestore: _firestore, auth: _auth),
        ],
      ),
    );
  }
}

/// -------------- MODELS --------------

enum _GameType { target, duel, range }

class _CommunityGame {
  _CommunityGame({
    required this.id,
    required this.type,
    required this.ticker,
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
    required this.deadline,
    required this.longPool,
    required this.shortPool,
    required this.state,
    this.currency,
    this.horizonDays,
    this.targetPrice,
    this.bandPct,
    this.rangeLow,
    this.rangeHigh,
    this.creationFee,
    this.creatorStake,
    this.entryPrice,
  });

  final String id;
  final _GameType type;
  final String ticker;
  final String creatorId;
  final String creatorName;
  final DateTime createdAt;
  final DateTime deadline;
  final double longPool;
  final double shortPool;
  final String state;
  final String? currency;
  final int? horizonDays;
  final double? targetPrice;
  final double? bandPct;
  final double? rangeLow;
  final double? rangeHigh;
  final double? creationFee;
  final double? creatorStake;
  final double? entryPrice;

  factory _CommunityGame.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    _GameType type;
    switch (data['type']) {
      case 'duel':
        type = _GameType.duel;
        break;
      case 'range':
        type = _GameType.range;
        break;
      default:
        type = _GameType.target;
    }
    DateTime _readDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.now();
    }

    return _CommunityGame(
      id: doc.id,
      type: type,
      ticker: (data['ticker'] ?? '').toString(),
      creatorId: (data['creatorId'] ?? '').toString(),
      creatorName: (data['creatorName'] ?? 'Anonyme').toString(),
      createdAt: _readDate(data['createdAt']),
      deadline: _readDate(data['deadline']),
      longPool: (data['longPool'] as num?)?.toDouble() ?? 0,
      shortPool: (data['shortPool'] as num?)?.toDouble() ?? 0,
      state: (data['state'] ?? 'open').toString(),
      currency: data['currency']?.toString(),
      horizonDays: (data['horizonDays'] as num?)?.toInt(),
      targetPrice: (data['targetPrice'] as num?)?.toDouble(),
      bandPct: (data['bandPct'] as num?)?.toDouble(),
      rangeLow: (data['rangeLow'] as num?)?.toDouble(),
      rangeHigh: (data['rangeHigh'] as num?)?.toDouble(),
      creationFee: (data['creationFee'] as num?)?.toDouble(),
      creatorStake: (data['creatorStake'] as num?)?.toDouble(),
      entryPrice: (data['entryPrice'] as num?)?.toDouble(),
    );
  }

  double oddsLong() {
    final total = (longPool + shortPool).clamp(0.01, double.infinity);
    final pool = longPool.clamp(0.01, double.infinity);
    return (total / pool).clamp(1.1, 6.0);
  }

  double oddsShort() {
    final total = (longPool + shortPool).clamp(0.01, double.infinity);
    final pool = shortPool.clamp(0.01, double.infinity);
    return (total / pool).clamp(1.1, 6.0);
  }
}

/// -------------- TARGET TAB --------------

class _TargetTab extends StatefulWidget {
  const _TargetTab({required this.firestore, required this.auth});
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  @override
  State<_TargetTab> createState() => _TargetTabState();
}

class _TargetTabState extends State<_TargetTab> {
  static const double _fee7 = 320;
  static const double _fee30 = 220;
  static const double _fee90 = 160;
  static const double _minStake = 120;
  static const double _maxStake = 800;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return widget.firestore
        .collection('community_games')
        .where('type', isEqualTo: 'target')
        .where('state', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeaderAction(
          title: 'Défis “Cible de cours”',
          subtitle: 'Choisis une cible, paye un frais de création, gagne la mise des perdants.',
          buttonLabel: 'Créer un défi',
          onPressed: _openCreate,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Aucun défi pour l’instant.'));
              }
              final games = docs.map(_CommunityGame.fromDoc).toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final g = games[i];
                  return _GameCard(
                    game: g,
                    type: _GameType.target,
                    onJoin: (side, stake) => _joinGame(g, side, stake),
                    disableJoin: g.creatorId == widget.auth.currentUser?.uid,
                    sideLabels: const ['Dans la zone', 'Hors zone'],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openCreate() async {
    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour créer un défi.')));
      return;
    }
    final created = await showModalBottomSheet<_CreateResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CreateTargetSheet(
        fee7: _fee7,
        fee30: _fee30,
        fee90: _fee90,
        minStake: _minStake,
        maxStake: _maxStake,
      ),
    );
    if (created == null) return;

    final ref = widget.firestore.collection('community_games').doc();
    await ref.set({
      'type': 'target',
      'ticker': created.ticker,
      'currency': created.currency,
      'targetPrice': created.targetPrice,
      'bandPct': created.bandPct,
      'horizonDays': created.horizonDays,
      'creatorId': user.uid,
      'creatorName': user.displayName ?? 'Anonyme',
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': DateTime.now().add(Duration(days: created.horizonDays)),
      'longPool': created.stake,
      'shortPool': 0.0,
      'state': 'open',
      'creationFee': created.creationFee,
      'creatorStake': created.stake,
      'entryPrice': created.entryPrice,
    });
    await ref.collection('participants').doc(user.uid).set({
      'userId': user.uid,
      'userName': user.displayName ?? 'Anonyme',
      'side': 'long',
      'stake': created.stake,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Défi créé.')));
  }

  Future<void> _joinGame(_CommunityGame game, _Side side, double stake) async {
    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour rejoindre.')));
      return;
    }
    if (game.creatorId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de rejoindre ton propre défi.')));
      return;
    }
    final participantRef = widget.firestore.collection('community_games').doc(game.id).collection('participants').doc(user.uid);
    final doc = await participantRef.get();
    if (doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déjà inscrit sur ce défi.')));
      return;
    }
    await widget.firestore.runTransaction((tx) async {
      final gameRef = widget.firestore.collection('community_games').doc(game.id);
      final snapshot = await tx.get(gameRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      double longPool = (data['longPool'] as num?)?.toDouble() ?? 0;
      double shortPool = (data['shortPool'] as num?)?.toDouble() ?? 0;
      if (side == _Side.long) {
        longPool += stake;
      } else {
        shortPool += stake;
      }
      tx.update(gameRef, {'longPool': longPool, 'shortPool': shortPool});
      tx.set(participantRef, {
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonyme',
        'side': side == _Side.long ? 'long' : 'short',
        'stake': stake,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscription enregistrée.')));
  }
}

/// -------------- DUELS TAB --------------

class _DuelTab extends StatefulWidget {
  const _DuelTab({required this.firestore, required this.auth});
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  @override
  State<_DuelTab> createState() => _DuelTabState();
}

class _DuelTabState extends State<_DuelTab> {
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return widget.firestore
        .collection('community_games')
        .where('type', isEqualTo: 'duel')
        .where('state', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _HeaderAction(
          title: 'Duels Tendance',
          subtitle: 'CAC40 / SBF120 chaque lundi 8h30, durée 5j. Camp Hausse vs Baisse.',
          buttonLabel: 'Duels auto (pas de création)',
          onPressed: null,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Aucun duel en cours.'));
              }
              final games = docs.map(_CommunityGame.fromDoc).toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final g = games[i];
                  return _GameCard(
                    game: g,
                    type: _GameType.duel,
                    onJoin: (side, stake) => _join(g, side, stake),
                    disableJoin: g.creatorId == widget.auth.currentUser?.uid,
                    sideLabels: const ['Hausse', 'Baisse'],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _join(_CommunityGame game, _Side side, double stake) async {
    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour rejoindre.')));
      return;
    }
    final participantRef = widget.firestore.collection('community_games').doc(game.id).collection('participants').doc(user.uid);
    final doc = await participantRef.get();
    if (doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déjà inscrit sur ce duel.')));
      return;
    }
    await widget.firestore.runTransaction((tx) async {
      final gameRef = widget.firestore.collection('community_games').doc(game.id);
      final snap = await tx.get(gameRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      double longPool = (data['longPool'] as num?)?.toDouble() ?? 0;
      double shortPool = (data['shortPool'] as num?)?.toDouble() ?? 0;
      if (side == _Side.long) {
        longPool += stake;
      } else {
        shortPool += stake;
      }
      tx.update(gameRef, {'longPool': longPool, 'shortPool': shortPool});
      tx.set(participantRef, {
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonyme',
        'side': side == _Side.long ? 'long' : 'short',
        'stake': stake,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participation duel enregistrée.')));
  }
}

/// -------------- RANGE TAB --------------

class _RangeTab extends StatefulWidget {
  const _RangeTab({required this.firestore, required this.auth});
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  @override
  State<_RangeTab> createState() => _RangeTabState();
}

class _RangeTabState extends State<_RangeTab> {
  static const double _fee = 200;
  static const double _minStake = 120;
  static const double _maxStake = 800;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return widget.firestore
        .collection('community_games')
        .where('type', isEqualTo: 'range')
        .where('state', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeaderAction(
          title: 'Challenges de volatilité',
          subtitle: 'Range vs Breakout. Créateur paie des frais, récupère la mise des perdants s’il gagne.',
          buttonLabel: 'Créer un challenge',
          onPressed: _openCreate,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Aucun challenge de volatilité.'));
              }
              final games = docs.map(_CommunityGame.fromDoc).toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final g = games[i];
                  return _GameCard(
                    game: g,
                    type: _GameType.range,
                    sideLabels: const ['Range', 'Breakout'],
                    disableJoin: g.creatorId == widget.auth.currentUser?.uid,
                    onJoin: (side, stake) => _join(g, side, stake),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openCreate() async {
    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour créer.')));
      return;
    }
    final created = await showModalBottomSheet<_CreateRangeResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CreateRangeSheet(
        fee: _fee,
        minStake: _minStake,
        maxStake: _maxStake,
      ),
    );
    if (created == null) return;
    final ref = widget.firestore.collection('community_games').doc();
    await ref.set({
      'type': 'range',
      'ticker': created.ticker,
      'currency': created.currency,
      'rangeLow': created.rangeLow,
      'rangeHigh': created.rangeHigh,
      'horizonDays': created.horizonDays,
      'creatorId': user.uid,
      'creatorName': user.displayName ?? 'Anonyme',
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': DateTime.now().add(Duration(days: created.horizonDays)),
      'longPool': created.stake,
      'shortPool': 0.0,
      'state': 'open',
      'creationFee': created.creationFee,
      'creatorStake': created.stake,
      'entryPrice': created.entryPrice,
    });
    await ref.collection('participants').doc(user.uid).set({
      'userId': user.uid,
      'userName': user.displayName ?? 'Anonyme',
      'side': 'long',
      'stake': created.stake,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge créé.')));
  }

  Future<void> _join(_CommunityGame game, _Side side, double stake) async {
    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour rejoindre.')));
      return;
    }
    if (game.creatorId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de rejoindre ton propre challenge.')));
      return;
    }
    final participantRef = widget.firestore.collection('community_games').doc(game.id).collection('participants').doc(user.uid);
    final doc = await participantRef.get();
    if (doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déjà inscrit sur ce challenge.')));
      return;
    }
    await widget.firestore.runTransaction((tx) async {
      final gameRef = widget.firestore.collection('community_games').doc(game.id);
      final snap = await tx.get(gameRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      double longPool = (data['longPool'] as num?)?.toDouble() ?? 0;
      double shortPool = (data['shortPool'] as num?)?.toDouble() ?? 0;
      if (side == _Side.long) {
        longPool += stake;
      } else {
        shortPool += stake;
      }
      tx.update(gameRef, {'longPool': longPool, 'shortPool': shortPool});
      tx.set(participantRef, {
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonyme',
        'side': side == _Side.long ? 'long' : 'short',
        'stake': stake,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participation enregistrée.')));
  }
}

/// -------------- CREATE SHEETS --------------

class _CreateResult {
  const _CreateResult({
    required this.ticker,
    required this.currency,
    required this.targetPrice,
    required this.bandPct,
    required this.horizonDays,
    required this.stake,
    required this.creationFee,
    required this.entryPrice,
  });
  final String ticker;
  final String? currency;
  final double targetPrice;
  final double bandPct;
  final int horizonDays;
  final double stake;
  final double creationFee;
  final double? entryPrice;
}

class _CreateTargetSheet extends StatefulWidget {
  const _CreateTargetSheet({
    required this.fee7,
    required this.fee30,
    required this.fee90,
    required this.minStake,
    required this.maxStake,
  });
  final double fee7;
  final double fee30;
  final double fee90;
  final double minStake;
  final double maxStake;

  @override
  State<_CreateTargetSheet> createState() => _CreateTargetSheetState();
}

class _CreateTargetSheetState extends State<_CreateTargetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tickerCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _stakeCtrl = TextEditingController(text: '200');
  int _horizon = 30;
  double? _lastPrice;
  String? _currency;
  bool _loadingQuote = false;
  Timer? _debounce;
  final List<TickerSearchResult> _suggestions = [];
  final FocusNode _tickerFocus = FocusNode();
  static const _bands = {7: 0.003, 30: 0.01, 90: 0.025};

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fee = _horizon == 7 ? widget.fee7 : (_horizon == 30 ? widget.fee30 : widget.fee90);
    final band = _bands[_horizon] ?? 0.01;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer un défi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tickerCtrl,
                  decoration: const InputDecoration(labelText: 'Ticker (ex: MC.PA, AAPL)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                  onChanged: _onTickerChanged,
                  focusNode: _tickerFocus,
                ),
                const SizedBox(height: 6),
                _TickerSuggestions(
                  suggestions: _suggestions,
                  searching: _loadingQuote,
                  onTap: _applySuggestion,
                ),
                TextFormField(
                  controller: _targetCtrl,
                  decoration: const InputDecoration(labelText: 'Cible de cours'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Nombre requis' : null,
                ),
                TextFormField(
                  controller: _stakeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mise (coins) – min ${widget.minStake.toInt()}, max ${widget.maxStake.toInt()}',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null) return 'Nombre requis';
                    if (val < widget.minStake || val > widget.maxStake) {
                      return 'Entre ${widget.minStake.toInt()} et ${widget.maxStake.toInt()}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _horizon,
                  decoration: const InputDecoration(labelText: 'Horizon'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 jours (band ±0,3%)')),
                    DropdownMenuItem(value: 30, child: Text('30 jours (band ±1%)')),
                    DropdownMenuItem(value: 90, child: Text('90 jours (band ±2,5%)')),
                  ],
                  onChanged: (v) => setState(() => _horizon = v ?? 30),
                ),
                const SizedBox(height: 8),
                Text('Frais de création: ${fee.toStringAsFixed(0)} coins', style: const TextStyle(color: Colors.black54)),
                if (_lastPrice != null) ...[
                  const SizedBox(height: 6),
                  Text('Dernier cours: ${_lastPrice!.toStringAsFixed(2)} ${_currency ?? ''}'),
                  Text('Zone cible: ±${(band * 100).toStringAsFixed(2)}% autour de la cible'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _loadingQuote ? null : _submit,
                      child: const Text('Publier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTickerChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loadingQuote = true);
      try {
        final results = await YahooFinanceService.searchEquities(value.trim());
        if (!mounted) return;
        setState(() {
          _suggestions
            ..clear()
            ..addAll(results.take(10));
          _loadingQuote = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _suggestions.clear();
          _loadingQuote = false;
        });
      }
    });
  }

  void _applySuggestion(TickerSearchResult s) {
    _tickerCtrl.text = s.symbol;
    _currency = s.currency;
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    if (_tickerCtrl.text.isEmpty) return;
    setState(() => _loadingQuote = true);
    try {
      final quote = await YahooFinanceService.fetchQuote(_tickerCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _lastPrice = quote.regularMarketPrice ?? quote.previousClose ?? quote.open;
        _currency = quote.currency;
        _loadingQuote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingQuote = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final target = double.tryParse(_targetCtrl.text);
    final stake = double.tryParse(_stakeCtrl.text);
    if (target == null || stake == null) return;
    final band = _bands[_horizon] ?? 0.01;
    final fee = _horizon == 7 ? widget.fee7 : (_horizon == 30 ? widget.fee30 : widget.fee90);
    final result = _CreateResult(
      ticker: _tickerCtrl.text.trim().toUpperCase(),
      currency: _currency,
      targetPrice: target,
      bandPct: band,
      horizonDays: _horizon,
      stake: stake,
      creationFee: fee,
      entryPrice: _lastPrice,
    );
    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tickerFocus.dispose();
    _tickerCtrl.dispose();
    _targetCtrl.dispose();
    _stakeCtrl.dispose();
    super.dispose();
  }
}

class _CreateRangeResult {
  const _CreateRangeResult({
    required this.ticker,
    required this.currency,
    required this.rangeLow,
    required this.rangeHigh,
    required this.horizonDays,
    required this.stake,
    required this.creationFee,
    required this.entryPrice,
  });

  final String ticker;
  final String? currency;
  final double rangeLow;
  final double rangeHigh;
  final int horizonDays;
  final double stake;
  final double creationFee;
  final double? entryPrice;
}

class _CreateRangeSheet extends StatefulWidget {
  const _CreateRangeSheet({
    required this.fee,
    required this.minStake,
    required this.maxStake,
  });
  final double fee;
  final double minStake;
  final double maxStake;

  @override
  State<_CreateRangeSheet> createState() => _CreateRangeSheetState();
}

class _CreateRangeSheetState extends State<_CreateRangeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tickerCtrl = TextEditingController();
  final _lowCtrl = TextEditingController();
  final _highCtrl = TextEditingController();
  final _stakeCtrl = TextEditingController(text: '200');
  double? _lastPrice;
  String? _currency;
  bool _loadingQuote = false;
  Timer? _debounce;
  final List<TickerSearchResult> _suggestions = [];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer un challenge de volatilité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tickerCtrl,
                  decoration: const InputDecoration(labelText: 'Ticker'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                  onChanged: _onTickerChanged,
                ),
                const SizedBox(height: 6),
                _TickerSuggestions(
                  suggestions: _suggestions,
                  searching: _loadingQuote,
                  onTap: _applySuggestion,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lowCtrl,
                        decoration: const InputDecoration(labelText: 'Borne basse'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || double.tryParse(v) == null) ? 'Nombre requis' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _highCtrl,
                        decoration: const InputDecoration(labelText: 'Borne haute'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || double.tryParse(v) == null) ? 'Nombre requis' : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _stakeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mise (coins) – min ${widget.minStake.toInt()}, max ${widget.maxStake.toInt()}',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null) return 'Nombre requis';
                    if (val < widget.minStake || val > widget.maxStake) {
                      return 'Entre ${widget.minStake.toInt()} et ${widget.maxStake.toInt()}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text('Frais de création: ${widget.fee.toStringAsFixed(0)} coins', style: const TextStyle(color: Colors.black54)),
                if (_lastPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Dernier cours: ${_lastPrice!.toStringAsFixed(2)} ${_currency ?? ''}'),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _loadingQuote ? null : _submit,
                      child: const Text('Publier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTickerChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loadingQuote = true);
      try {
        final results = await YahooFinanceService.searchEquities(value.trim());
        if (!mounted) return;
        setState(() {
          _suggestions
            ..clear()
            ..addAll(results.take(10));
          _loadingQuote = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _suggestions.clear();
          _loadingQuote = false;
        });
      }
    });
  }

  void _applySuggestion(TickerSearchResult s) {
    _tickerCtrl.text = s.symbol;
    _currency = s.currency;
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    if (_tickerCtrl.text.isEmpty) return;
    setState(() => _loadingQuote = true);
    try {
      final quote = await YahooFinanceService.fetchQuote(_tickerCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _lastPrice = quote.regularMarketPrice ?? quote.previousClose ?? quote.open;
        _currency = quote.currency;
        _loadingQuote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingQuote = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final low = double.tryParse(_lowCtrl.text);
    final high = double.tryParse(_highCtrl.text);
    final stake = double.tryParse(_stakeCtrl.text);
    if (low == null || high == null || stake == null || high <= low) return;
    final result = _CreateRangeResult(
      ticker: _tickerCtrl.text.trim().toUpperCase(),
      currency: _currency,
      rangeLow: low,
      rangeHigh: high,
      horizonDays: 14,
      stake: stake,
      creationFee: widget.fee,
      entryPrice: _lastPrice,
    );
    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tickerCtrl.dispose();
    _lowCtrl.dispose();
    _highCtrl.dispose();
    _stakeCtrl.dispose();
    super.dispose();
  }
}

/// -------------- COMMON UI --------------

class _TickerSuggestions extends StatelessWidget {
  const _TickerSuggestions({required this.suggestions, required this.searching, required this.onTap});
  final List<TickerSearchResult> suggestions;
  final bool searching;
  final ValueChanged<TickerSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    if (searching && suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          return ListTile(
            dense: true,
            title: Text('${s.symbol} • ${s.displayName}', overflow: TextOverflow.ellipsis),
            subtitle: Text('${s.exchange} ${s.currency}'),
            onTap: () => onTap(s),
          );
        },
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.game,
    required this.type,
    required this.sideLabels,
    required this.onJoin,
    required this.disableJoin,
  });

  final _CommunityGame game;
  final _GameType type;
  final List<String> sideLabels;
  final bool disableJoin;
  final Future<void> Function(_Side side, double stake) onJoin;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  final _stakeCtrl = TextEditingController(text: '150');

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final oddsLong = g.oddsLong();
    final oddsShort = g.oddsShort();
    final now = DateTime.now();
    final remaining = g.deadline.difference(now);
    final remainingText = remaining.isNegative
        ? 'Échu'
        : '${remaining.inHours ~/ 24}j ${remaining.inHours % 24}h';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.ticker,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(remainingText, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Créé par ${g.creatorName}', style: const TextStyle(color: Colors.black54), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          _buildContextLine(),
          const SizedBox(height: 10),
          Row(
            children: [
              _PoolChip(label: widget.sideLabels[0], value: g.longPool, color: Colors.green),
              const SizedBox(width: 8),
              _PoolChip(label: widget.sideLabels[1], value: g.shortPool, color: Colors.redAccent),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Cote ${widget.sideLabels[0]}: ${oddsLong.toStringAsFixed(2)}x',
                      style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  Text('Cote ${widget.sideLabels[1]}: ${oddsShort.toStringAsFixed(2)}x',
                      style: const TextStyle(color: Colors.black54), overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stakeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mise (coins)'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: widget.disableJoin ? null : () => _onJoin(_Side.long),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                child: Text(widget.sideLabels[0]),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: widget.disableJoin ? null : () => _onJoin(_Side.short),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                child: Text(widget.sideLabels[1]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gain potentiel pour 100 coins : ${(oddsLong * 100).toStringAsFixed(0)} / ${(oddsShort * 100).toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildContextLine() {
    final g = widget.game;
    switch (widget.type) {
      case _GameType.target:
        final bandPct = (g.bandPct ?? 0) * 100;
        return Text('Cible ${g.targetPrice?.toStringAsFixed(2) ?? '?'} ${g.currency ?? ''} • Zone ±${bandPct.toStringAsFixed(2)}%',
            overflow: TextOverflow.ellipsis);
      case _GameType.duel:
        return const Text('Duels automatiques CAC40/SBF120 • Horizon 5j', overflow: TextOverflow.ellipsis);
      case _GameType.range:
        return Text('Range ${g.rangeLow?.toStringAsFixed(2)} - ${g.rangeHigh?.toStringAsFixed(2)} ${g.currency ?? ''}',
            overflow: TextOverflow.ellipsis);
    }
  }

  Future<void> _onJoin(_Side side) async {
    final stake = double.tryParse(_stakeCtrl.text);
    if (stake == null || stake <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mise invalide')));
      return;
    }
    await widget.onJoin(side, stake);
  }
}

class _PoolChip extends StatelessWidget {
  const _PoolChip({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${value.toStringAsFixed(0)}'),
      backgroundColor: color.withOpacity(0.08),
      labelStyle: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.w700),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

enum _Side { long, short }
