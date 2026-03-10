import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fintech/core/constants.dart';

import '../widgets/help_fab.dart';

const Color _gameMuted = Colors.black54;
const Color _line = Color(0xFFE6E8EB);
const Color _chipBg = Color(0xFFF0F1F3);
const Color _bg = backgroundColor;
const Color _ink = textColor;
const Color _gold = detailsColor1;
const Color _wine = detailsColor2;

double _scaledFont(BuildContext context, double size) {
  final width = MediaQuery.sizeOf(context).width;
  final factor = (width / 390).clamp(0.85, 1.2);
  final base = size * factor;
  return MediaQuery.textScalerOf(context).scale(base);
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

  factory PortfolioScenario.fromJson(Map<String, dynamic> json) {
    return PortfolioScenario(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      focus: json['focus'],
      risk: json['risk'],
      stageId: json['stageId'],
      rewardXp: json['rewardXp'],
      prompts: List<String>.from(json['prompts']),
      config: SimulationConfig.fromJson(json['config']),
    );
  }

  static Future<List<PortfolioScenario>> loadScenarios() async {
    final String response = await rootBundle.loadString('assets/scenario.json');
    final List<dynamic> data = json.decode(response);
    return data.map((json) => PortfolioScenario.fromJson(json)).toList();
  }
}

class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    this.onTap,
    this.isCompleted = false,
    this.isLocked = false,
    this.requiredLevel = 1,
  });

  final PortfolioScenario scenario;
  final VoidCallback? onTap;
  final bool isCompleted;
  final bool isLocked;
  final int requiredLevel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFFF0F1F3) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLocked ? Colors.black.withValues(alpha: 0.08) : _wine.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLocked ? "Verrouillé" : scenario.focus,
                    style: TextStyle(
                      color: isLocked ? Colors.black54 : _wine,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (isLocked)
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("Niv. $requiredLevel", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  )
                else ...[
                  if (isCompleted)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  if (isCompleted)
                    const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _wine.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _wine.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      '${scenario.rewardXp} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _wine,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scenario.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.black45 : _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scenario.description,
              style: TextStyle(
                color: isLocked ? Colors.black38 : _gameMuted,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class ScenarioBriefing extends StatelessWidget {
  const ScenarioBriefing({super.key, required this.scenario});
  final PortfolioScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  scenario.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 6,
                  width: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [_gold, _wine],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        scenario.focus,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _wine.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _wine.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        scenario.risk,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: _wine),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  scenario.description,
                  style: const TextStyle(fontSize: 15.5, height: 1.35, color: Colors.black87),
                ),
                const SizedBox(height: 18),
                const Text('Objectifs', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 10),
                ...scenario.prompts.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _wine.withValues(alpha: 0.10),
                            border: Border.all(color: _wine.withValues(alpha: 0.22)),
                          ),
                          child: const Icon(Icons.check_rounded, size: 14, color: _wine),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p, style: const TextStyle(color: Colors.black87))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Commencer la simulation',
                  icon: Icons.play_arrow_rounded,
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimulationRunner extends StatefulWidget {
  const SimulationRunner({super.key, required this.scenario});
  final PortfolioScenario scenario;

  @override
  State<SimulationRunner> createState() => _SimulationRunnerState();
}

class _SimulationRunnerState extends State<SimulationRunner> {
  late SimulationConfig _config;
  final Map<String, double> _allocation = {};
  int _step = -1; // -1: Allocation, 0..N: Running, N+1: Result
  Timer? _timer;
  double _currentValue = 0;
  double _initialValue = 0;
  double _drawdown = 0;
  double _peak = 0;
  double _userCoins = 0;
  double _stake = 100;
  bool _loadingCoins = true;
  bool _resultsProcessed = false;
  StreamSubscription<DocumentSnapshot>? _coinsSubscription;

  @override
  void initState() {
    super.initState();
    _config = widget.scenario.config;
    _initialValue = _config.initialCash;
    _currentValue = _initialValue;
    _peak = _initialValue;
    for (var asset in _config.assets) {
      if (asset.id != 'cash') _allocation[asset.id] = 0;
    }
    _listenToCoins();
  }

  void _listenToCoins() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _coinsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _userCoins = (snapshot.data()?['coins'] as num?)?.toDouble() ?? 0.0;
          if (_stake > _userCoins) _stake = _userCoins > 0 ? _userCoins : 0;
          _loadingCoins = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _coinsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startSimulation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Débiter la mise
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.set({'coins': FieldValue.increment(-_stake)}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error deducting coins: $e');
      }
    }

    _initialValue = _stake;
    _currentValue = _stake;
    _peak = _stake;

    setState(() => _step = 0);
    _timer = Timer.periodic(Duration(milliseconds: _config.playbackMs), (timer) {
      if (_step < _config.timelineLength - 1) {
        setState(() {
          _step++;
          _updateSimulation();
        });
      } else {
        timer.cancel();
        setState(() => _step++);
      }
    });
  }

  void _updateSimulation() {
    double val = 0;
    double allocatedPct = _allocation.values.fold(0.0, (a, b) => a + b);
    double cashPct = 100 - allocatedPct;

    for (var asset in _config.assets) {
      if (asset.id == 'cash') continue;
      double alloc = _allocation[asset.id] ?? 0;
      double qty = (_initialValue * (alloc / 100)) / asset.prices[0];
      val += qty * asset.prices[_step];
    }
    val += _initialValue * (cashPct / 100);

    _currentValue = val;
    if (_currentValue > _peak) _peak = _currentValue;
    _drawdown = (_peak - _currentValue) / _peak * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (_step == -1) return _buildAllocationView();
    if (_step >= _config.timelineLength) return _buildResultView();
    return _buildRunningView();
  }

  Widget _buildAllocationView() {
    double total = _allocation.values.fold(0, (a, b) => a + b);
    bool isValid = (total - 100).abs() < 0.1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Allocation',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink, letterSpacing: .2),
        ),
        backgroundColor: _bg,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const _PremiumAppBarUnderline(),
      ),
      floatingActionButton: const HelpFab(
        helpText: "Répartissez votre capital initial entre les différents actifs. Utilisez les curseurs pour ajuster les pourcentages. Le total doit faire exactement 100% pour commencer.",
      ),
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Votre solde :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    _loadingCoins
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('${_userCoins.toStringAsFixed(0)} coins', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mise :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text('${_stake.toStringAsFixed(0)} coins', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _stake,
                  min: 0,
                  max: _userCoins > 0 ? _userCoins : 100,
                  divisions: _userCoins > 0 ? (_userCoins / 10).ceil() : 1,
                  activeColor: _wine,
                  inactiveColor: _gold.withValues(alpha: 0.18),
                  onChanged: _userCoins > 0 ? (v) => setState(() => _stake = v) : null,
                ),
                Divider(color: _line),
                const Text('Répartissez votre investissement (Total doit faire 100%)', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: _allocation.keys.map((key) {
                final asset = _config.assets.firstWhere((a) => a.id == key);
                return Column(
                  children: [
                    ListTile(
                      title: Text(asset.label),
                      subtitle: Text(asset.role),
                      trailing: Text('${_allocation[key]!.toStringAsFixed(0)}%'),
                    ),
                    Slider(
                      value: _allocation[key]!,
                      min: 0,
                      max: 100,
                      activeColor: _wine,
                      inactiveColor: _gold.withValues(alpha: 0.18),
                      onChanged: (v) {
                        double diff = v - _allocation[key]!;
                        if (total + diff <= 100.1) { // Petite marge pour float
                          setState(() => _allocation[key] = v);
                        }
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total investi: ${total.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('Cash: ${(100 - total).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                _GradientButton(
                  label: isValid ? 'Lancer la simulation' : 'Total doit être 100%',
                  icon: Icons.show_chart_rounded,
                  disabled: !(isValid && _stake > 0),
                  onTap: isValid && _stake > 0 ? _startSimulation : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningView() {
    double pnl = (_currentValue - _initialValue) / _initialValue * 100;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _config.headline,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, letterSpacing: .2),
        ),
        backgroundColor: _bg,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: const _PremiumAppBarUnderline(),
      ),
      backgroundColor: _bg,
      floatingActionButton: const HelpFab(
        helpText: "Observez l'évolution de votre portefeuille semaine après semaine. Analysez comment vos choix d'allocation réagissent aux événements du marché.",
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SimulationTicker(
              accent: _wine,
              currentValue: _currentValue,
              pnlPct: pnl,
              drawdownPct: _drawdown,
              rebalanceUsed: false,
              onRebalance: null,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PriceTape(
                assets: _config.assets.where((a) => a.id != 'cash').toList(),
                step: _step,
                accent: _wine,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markScenarioAsCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final scenarioId = widget.scenario.id;
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('games').doc('progress');
      await docRef.set({
        'completed_scenarios': FieldValue.arrayUnion([scenarioId])
      }, SetOptions(merge: true));

      final learningRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('learning').doc('progress');
      await learningRef.set({
        'xp': FieldValue.increment(widget.scenario.rewardXp)
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking scenario as completed: $e');
    }
  }

  Future<void> _creditGains() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.set({'coins': FieldValue.increment(_currentValue)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error crediting coins: $e');
    }
  }

  Widget _buildResultView() {
    double pnl = (_currentValue - _initialValue) / _initialValue * 100;
    if (!_resultsProcessed) {
      _creditGains(); // Créditer les gains à la fin (ou perte si < mise)
      _markScenarioAsCompleted();
      _resultsProcessed = true;
    }

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: const HelpFab(
        helpText: "Simulation terminée ! Voici votre performance finale. Si elle est positive, vous avez gagné des pièces et de l'XP.",
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [_gold, _wine],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Simulation terminée',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    width: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [_gold, _wine],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Performance finale: ${pnl > 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: pnl >= 0 ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Solde récupéré : ${_currentValue.toStringAsFixed(0)} coins',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 18),
                  _GradientButton(
                    label: 'Retour',
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimulationTicker extends StatelessWidget {
  const SimulationTicker({
    super.key,
    required this.accent,
    required this.currentValue,
    required this.pnlPct,
    required this.drawdownPct,
    required this.rebalanceUsed,
    required this.onRebalance,
  });

  final Color accent;
  final double currentValue;
  final double pnlPct;
  final double drawdownPct;
  final bool rebalanceUsed;
  final VoidCallback? onRebalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valeur', style: TextStyle(color: _gameMuted, fontSize: _scaledFont(context, 12))),
                    Text('${currentValue.toStringAsFixed(0)} coins', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _scaledFont(context, 18))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('P&L', style: TextStyle(color: _gameMuted, fontSize: _scaledFont(context, 12))),
                  Text(
                    '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)} %',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: _scaledFont(context, 18),
                      color: pnlPct >= 0 ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, color: accent),
                    const SizedBox(width: 6),
                    Text('Drawdown ${drawdownPct.toStringAsFixed(1)}%', style: TextStyle(color: _gameMuted)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRebalance,
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text(rebalanceUsed ? 'Rééquilibrage fait' : 'Rééquilibrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PriceTape extends StatelessWidget {
  const PriceTape({
    super.key,
    required this.assets,
    required this.step,
    required this.accent,
  });

  final List<SimulationAsset> assets;
  final int step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: assets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final asset = assets[index];
        final price = asset.prices[step];
        final start = asset.prices.first;
        final pct = ((price - start) / start) * 100;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(asset.role, style: TextStyle(color: _gameMuted, fontSize: _scaledFont(context, 12))),
                  ],
                ),
              ),
              Text(
                price.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pct >= 0 ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                  style: TextStyle(color: pct >= 0 ? Colors.green : Colors.redAccent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: _gameMuted))),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: highlight ? Colors.green : Colors.black),
          ),
        ],
      ),
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
      headline: json['headline'],
      periodLabel: json['periodLabel'],
      durationLabel: json['durationLabel'],
      stepLabel: json['stepLabel'],
      initialCash: (json['initialCash'] as num).toDouble(),
      assets: (json['assets'] as List).map((e) => SimulationAsset.fromJson(e)).toList(),
      cues: List<String>.from(json['cues']),
      suggestedAllocation: Map<String, double>.from(
          (json['suggestedAllocation'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      playbackMs: json['playbackMs'],
    );
  }
}

class SimulationAsset {
  const SimulationAsset({
    required this.id,
    required this.label,
    required this.prices,
    required this.role,
  });

  final String id;
  final String label;
  final List<double> prices;
  final String role;

  factory SimulationAsset.fromJson(Map<String, dynamic> json) {
    return SimulationAsset(
      id: json['id'],
      label: json['label'],
      prices: (json['prices'] as List).map((e) => (e as num).toDouble()).toList(),
      role: json['role'],
    );
  }
}
// --- Premium UI helpers ---

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final enabled = !disabled && onTap != null;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: enabled
                ? const LinearGradient(
                    colors: [_gold, _wine],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumAppBarUnderline extends StatelessWidget implements PreferredSizeWidget {
  const _PremiumAppBarUnderline();

  @override
  Size get preferredSize => const Size.fromHeight(12);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 6,
          width: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [_gold, _wine],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
    );
  }
}