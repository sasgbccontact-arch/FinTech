import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/help_fab.dart';

const Color _gameMuted = Colors.black54;

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
  const ScenarioCard({super.key, required this.scenario, this.onTap, this.isCompleted = false});
  final PortfolioScenario scenario;
  final VoidCallback? onTap;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(scenario.focus, style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                if (isCompleted)
                  const SizedBox(width: 8),
                Text('${scenario.rewardXp} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            Text(scenario.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(scenario.description, style: const TextStyle(color: Colors.black54, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
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
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scenario.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text(scenario.focus), backgroundColor: Colors.blue.shade50),
                  const SizedBox(width: 8),
                  Chip(label: Text(scenario.risk), backgroundColor: Colors.orange.shade50),
                ],
              ),
              const SizedBox(height: 16),
              Text(scenario.description, style: const TextStyle(fontSize: 16, height: 1.4)),
              const SizedBox(height: 24),
              const Text('Objectifs :', style: TextStyle(fontWeight: FontWeight.bold)),
              ...scenario.prompts.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p)),
                      ],
                    ),
                  )),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Commencer la simulation'),
                ),
              ),
            ],
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
      appBar: AppBar(title: const Text('Allocation'), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      floatingActionButton: const HelpFab(
        helpText: "Répartissez votre capital initial entre les différents actifs. Utilisez les curseurs pour ajuster les pourcentages. Le total doit faire exactement 100% pour commencer.",
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
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
                  activeColor: Colors.black,
                  onChanged: _userCoins > 0 ? (v) => setState(() => _stake = v) : null,
                ),
                const Divider(),
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
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total investi: ${total.toStringAsFixed(0)}%'),
                    Text('Cash: ${(100 - total).toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isValid && _stake > 0 ? _startSimulation : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), disabledBackgroundColor: Colors.grey.shade300),
                    child: Text(isValid ? 'Lancer la simulation' : 'Total doit être 100%'),
                  ),
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
      appBar: AppBar(title: Text(_config.headline), automaticallyImplyLeading: false),
      floatingActionButton: const HelpFab(
        helpText: "Observez l'évolution de votre portefeuille semaine après semaine. Analysez comment vos choix d'allocation réagissent aux événements du marché.",
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SimulationTicker(
              accent: Colors.blue,
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
                accent: Colors.blue,
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
      floatingActionButton: const HelpFab(
        helpText: "Simulation terminée ! Voici votre performance finale. Si elle est positive, vous avez gagné des pièces et de l'XP.",
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Simulation terminée', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Performance finale: ${pnl > 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 32, color: pnl >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Solde récupéré : ${_currentValue.toStringAsFixed(0)} coins',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
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
        border: Border.all(color: Colors.black.withOpacity(0.05)),
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
            border: Border.all(color: Colors.black.withOpacity(0.04)),
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
                decoration: BoxDecoration(color: pct >= 0 ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
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