import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/services/activity_tracking_service.dart';
import 'package:fintech/services/learning_progress_service.dart';
import 'package:fintech/services/scenario_game_engine.dart';

import '../models/scenario_game_models.dart';
import '../widgets/help_fab.dart';

export '../models/scenario_game_models.dart'
    show
        PortfolioScenario,
        ScenarioCampaignProgress,
        ScenarioChapter,
        ScenarioMedal,
        ScenarioThesis,
        kScenarioChapters;

const Color _gameMuted = Colors.black54;
const Color _line = Color(0xFFE6E8EB);
const Color _chipBg = Color(0xFFF0F1F3);
const Color _bg = backgroundColor;
const Color _ink = textColor;
const Color _gold = detailsColor1;
const Color _wine = detailsColor2;

typedef _ScenarioPersistCallback =
    Future<_ScenarioPersistResult> Function(_ScenarioPersistPayload payload);

class _ScenarioFlowSeed {
  const _ScenarioFlowSeed({
    required this.stage,
    this.thesis,
    this.plan,
    this.resources,
    this.currentActIndex = 0,
    this.journal = const <ScenarioDecisionJournalEntry>[],
    this.mutators = const ScenarioMutatorSet(),
    this.outcome,
    this.settlement,
  });

  final int stage;
  final ScenarioThesis? thesis;
  final ScenarioInitialPlan? plan;
  final ScenarioResourceState? resources;
  final int currentActIndex;
  final List<ScenarioDecisionJournalEntry> journal;
  final ScenarioMutatorSet mutators;
  final ScenarioRunOutcome? outcome;
  final ScenarioRunSettlement? settlement;
}

class _ScenarioPersistPayload {
  const _ScenarioPersistPayload({
    required this.scenario,
    required this.outcome,
    required this.thesis,
    required this.plan,
    required this.mutators,
    required this.stakeCoins,
    required this.journal,
  });

  final PortfolioScenario scenario;
  final ScenarioRunOutcome outcome;
  final ScenarioThesis thesis;
  final ScenarioInitialPlan plan;
  final ScenarioMutatorSet mutators;
  final int stakeCoins;
  final List<ScenarioDecisionJournalEntry> journal;
}

class _ScenarioPersistResult {
  const _ScenarioPersistResult({
    required this.settlement,
    required this.campaignProgress,
  });

  final ScenarioRunSettlement settlement;
  final ScenarioCampaignProgress campaignProgress;
}

double _scaledFont(BuildContext context, double size) {
  final width = MediaQuery.sizeOf(context).width;
  final factor = (width / 390).clamp(0.85, 1.2);
  final base = size * factor;
  return MediaQuery.textScalerOf(context).scale(base);
}

String _currency(int value) => '${value.toStringAsFixed(0)} coins';

class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    this.onTap,
    this.isCompleted = false,
    this.isLocked = false,
    this.requiredLevel = 1,
    this.bestMedal,
    this.bestScore,
    this.dailySettlementConsumed = false,
    this.chapterLabel,
  });

  final PortfolioScenario scenario;
  final VoidCallback? onTap;
  final bool isCompleted;
  final bool isLocked;
  final int requiredLevel;
  final String? bestMedal;
  final int? bestScore;
  final bool dailySettlementConsumed;
  final String? chapterLabel;

  @override
  Widget build(BuildContext context) {
    final medal = ScenarioMedalX.fromKey(bestMedal);
    final accent = isLocked ? Colors.black38 : _wine;
    final badgeText =
        isLocked ? 'Niv. $requiredLevel' : chapterLabel ?? scenario.focus;
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFFF4F4F4) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipLabel(
                        label: badgeText,
                        color:
                            isLocked
                                ? Colors.black.withValues(alpha: 0.08)
                                : _wine.withValues(alpha: 0.10),
                        textColor: accent,
                      ),
                      _ChipLabel(
                        label: scenario.risk,
                        color: _gold.withValues(alpha: 0.14),
                        textColor: _wine,
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Niv. $requiredLevel',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ScorePill(
                        score: bestScore,
                        medal: medal,
                        rewardXp: scenario.rewardXp,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dailySettlementConsumed
                            ? 'PnL du jour consommé'
                            : 'PnL réel dispo',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color:
                              dailySettlementConsumed
                                  ? Colors.black45
                                  : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              scenario.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isLocked ? Colors.black45 : _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scenario.description,
              style: TextStyle(
                color: isLocked ? Colors.black38 : _gameMuted,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _InlineStat(
                  icon: Icons.timeline_rounded,
                  label: '${scenario.acts.length + 1} actes',
                ),
                _InlineStat(
                  icon: Icons.auto_graph_rounded,
                  label: scenario.config.periodLabel,
                ),
              ],
            ),
            if (isCompleted || medal != ScenarioMedal.none) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (medal != ScenarioMedal.none)
                    _ChipLabel(
                      label: 'Médaille ${medal.label}',
                      color: _gold.withValues(alpha: 0.16),
                      textColor: _wine,
                    ),
                  if (isCompleted)
                    _ChipLabel(
                      label: 'Premier clear',
                      color: Colors.green.withValues(alpha: 0.10),
                      textColor: Colors.green.shade700,
                    ),
                ],
              ),
            ],
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
    final chapter = ScenarioGameEngine.chapterForScenario(scenario);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _ink,
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
                    _ChipLabel(
                      label: chapter.title,
                      color: _chipBg,
                      textColor: _ink,
                    ),
                    _ChipLabel(
                      label: scenario.focus,
                      color: _wine.withValues(alpha: 0.10),
                      textColor: _wine,
                    ),
                    _ChipLabel(
                      label: 'Niv. ${scenario.requiredLevel}',
                      color: _gold.withValues(alpha: 0.16),
                      textColor: _wine,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  scenario.description,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                _SectionTitle('Structure du run'),
                const SizedBox(height: 10),
                const _BriefingBullet('Briefing, thèse et mise'),
                const _BriefingBullet('Plan initial à 3 presets'),
                const _BriefingBullet('Trois décisions sous incertitude'),
                const _BriefingBullet('Debrief multi-critères et médailles'),
                const SizedBox(height: 18),
                _SectionTitle('Points d’attention'),
                const SizedBox(height: 10),
                ...scenario.prompts
                    .take(3)
                    .map((prompt) => _BriefingBullet(prompt)),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Commencer le scénario',
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
  bool _loading = true;
  int _coins = 0;
  ScenarioCampaignProgress _campaign = ScenarioCampaignProgress.empty;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBootstrap();
  }

  Future<void> _loadBootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Connexion requise pour jouer ce scénario.';
      });
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final campaignRef = userRef.collection('games').doc('scenario_campaign');
      final result = await Future.wait([userRef.get(), campaignRef.get()]);
      final userDoc = result[0];
      final campaignDoc = result[1];
      if (!mounted) {
        return;
      }
      setState(() {
        _coins = ((userDoc.data()?['coins'] as num?)?.toDouble() ?? 0).round();
        _campaign = ScenarioCampaignProgress.fromMap(campaignDoc.data());
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Impossible de charger la campagne.';
      });
    }
  }

  Future<_ScenarioPersistResult> _persistRun(
    _ScenarioPersistPayload payload,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _ScenarioPersistResult(
        settlement: ScenarioGameEngine.settlementForOutcome(
          scenario: payload.scenario,
          outcome: payload.outcome,
          campaign: _campaign,
          now: DateTime.now(),
          stakeCoins: payload.stakeCoins,
        ),
        campaignProgress: _campaign,
      );
    }
    final now = DateTime.now();
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final progressRef = userRef.collection('games').doc('progress');
    final campaignRef = userRef.collection('games').doc('scenario_campaign');
    final runsRef = userRef
        .collection('scenario_runs')
        .doc(
          '${payload.scenario.id}_${ScenarioGameEngine.scenarioDayKey(now)}_${DateTime.now().millisecondsSinceEpoch}',
        );

    late ScenarioRunSettlement settlement;
    late ScenarioCampaignProgress nextCampaign;

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final userSnap = await txn.get(userRef);
      final progressSnap = await txn.get(progressRef);
      final campaignSnap = await txn.get(campaignRef);

      final currentCampaign = ScenarioCampaignProgress.fromMap(
        campaignSnap.data(),
      );
      settlement = ScenarioGameEngine.settlementForOutcome(
        scenario: payload.scenario,
        outcome: payload.outcome,
        campaign: currentCampaign,
        now: now,
        stakeCoins: payload.stakeCoins,
      );
      nextCampaign = ScenarioGameEngine.applyRunToCampaign(
        scenario: payload.scenario,
        current: currentCampaign,
        outcome: payload.outcome,
        mutators: payload.mutators,
        now: now,
      );

      final currentCoins =
          ((userSnap.data()?['coins'] as num?)?.toDouble() ?? 0).round();
      final nextCoins = math.max(0, currentCoins + settlement.netCoins);
      txn.set(userRef, {'coins': nextCoins}, SetOptions(merge: true));

      final progressData = progressSnap.data() ?? const <String, dynamic>{};
      final completed =
          (progressData['completed_scenarios'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((value) => value.toString())
              .toSet();
      if (settlement.isFirstClear) {
        completed.add(payload.scenario.id);
      }
      final currentXp = (progressData['xp'] as num?)?.toInt() ?? 0;
      txn.set(progressRef, <String, dynamic>{
        'xp': currentXp + settlement.xpGranted,
        'completed_scenarios': completed.toList(),
      }, SetOptions(merge: true));

      txn.set(campaignRef, nextCampaign.toMap(), SetOptions(merge: true));
      txn.set(runsRef, <String, dynamic>{
        'scenarioId': payload.scenario.id,
        'chapterId': payload.scenario.chapterId,
        'thesisId': payload.thesis.key,
        'mutators': payload.mutators.toMap(),
        'stakeCoins': payload.stakeCoins,
        'branchPath': payload.outcome.branchPath,
        'decisionJournal':
            payload.journal.map((entry) => entry.toMap()).toList(),
        'scoreBreakdown': payload.outcome.breakdown.toMap(),
        'finalPortfolioValue': payload.outcome.finalValue,
        'finalPnlPct': payload.outcome.finalPnlPct,
        'coinsSettled': settlement.netCoins,
        'xpGranted': settlement.xpGranted,
        'isFirstClear': settlement.isFirstClear,
        'isDailyRealSettlement': settlement.isDailyRealSettlement,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    try {
      final progress = await LearningProgressService.loadProgress(user.uid);
      final completedScenarioIds = <String>{...progress.completedScenarioIds};
      if (settlement.isFirstClear) {
        completedScenarioIds.add(payload.scenario.id);
      }
      final updated = progress
          .updateStage(payload.scenario.stageId, settlement.stageDelta)
          .copyWith(
            totalXp: progress.totalXp + settlement.xpGranted,
            dailyXp: progress.dailyXp + settlement.xpGranted,
            scenariosDoneToday: progress.scenariosDoneToday + 1,
            completedScenarioIds: completedScenarioIds,
          );
      await LearningProgressService.saveProgress(user.uid, updated);
    } catch (_) {
      // Ne doit pas bloquer la fin de partie.
    }

    await ActivityTrackingService.trackCurrentUser(
      type:
          settlement.isFirstClear ? 'scenario_first_clear' : 'scenario_replay',
      points: settlement.xpGranted,
      counters: <String, int>{
        'scenario_runs': 1,
        if (settlement.isDailyRealSettlement) 'scenario_real_settlement': 1,
        'scenario_stars': payload.outcome.breakdown.stars,
      },
      label: payload.scenario.id,
    );

    if (mounted) {
      setState(() {
        _campaign = nextCampaign;
        _coins = math.max(0, _coins + settlement.netCoins);
      });
    }

    return _ScenarioPersistResult(
      settlement: settlement,
      campaignProgress: nextCampaign,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    return _ScenarioGameFlow(
      scenario: widget.scenario,
      initialCoins: _coins,
      initialCampaignProgress: _campaign,
      onPersist: _persistRun,
    );
  }
}

class ScenarioGameUiPreview extends StatelessWidget {
  const ScenarioGameUiPreview({
    super.key,
    this.mutatorsUnlocked = false,
    this.dailySettlementAvailable = true,
    this.previewStage = 0,
  });

  final bool mutatorsUnlocked;
  final bool dailySettlementAvailable;
  final int previewStage;

  @override
  Widget build(BuildContext context) {
    final scenario = PortfolioScenario.fromJson(const <String, dynamic>{
      'id': 'preview',
      'title': 'Rotation Tech vs Défensif',
      'description': 'Un mini scénario de preview pour les tests UI.',
      'focus': 'Macro',
      'risk': 'Taux',
      'stageId': 'fundamentals',
      'rewardXp': 20,
      'prompts': <String>[
        'La duration devient punitive.',
        'La rotation sectorielle demande du timing.',
      ],
      'config': <String, dynamic>{
        'headline': 'Preview',
        'periodLabel': '6 pas',
        'durationLabel': '6 semaines',
        'stepLabel': '1 semaine',
        'initialCash': 30000,
        'playbackMs': 850,
        'assets': <Map<String, dynamic>>[
          {
            'id': 'tech',
            'label': 'Tech',
            'prices': <int>[100, 94, 88, 86, 90, 93],
            'role': 'Croissance',
          },
          {
            'id': 'banks',
            'label': 'Banques',
            'prices': <int>[100, 102, 105, 108, 109, 110],
            'role': 'Marge',
          },
          {
            'id': 'short_bonds',
            'label': 'Bons du Trésor court',
            'prices': <double>[100, 100.2, 100.4, 100.7, 101, 101.2],
            'role': 'Refuge',
          },
          {
            'id': 'cash',
            'label': 'Cash',
            'prices': <int>[1, 1, 1, 1, 1, 1],
            'role': 'Liquidité',
          },
        ],
        'cues': <String>[
          'La Tech décroche après un CPI plus chaud.',
          'Les banques profitent de la pente des taux.',
          'Le cash court redevient compétitif.',
        ],
        'suggestedAllocation': <String, int>{
          'tech': 20,
          'banks': 35,
          'short_bonds': 25,
          'cash': 20,
        },
      },
    });
    final campaign = ScenarioCampaignProgress(
      chapterStars: const <String, int>{'macro_cycles': 6},
      chapterBestScores: const <String, int>{'macro_cycles': 220},
      scenarioBestScores: const <String, int>{},
      scenarioBestMedals: const <String, String>{},
      firstClearScenarioIds:
          mutatorsUnlocked ? const <String>['preview'] : const <String>[],
      dailyRealSettlementByScenario:
          dailySettlementAvailable
              ? const <String, String>{}
              : <String, String>{
                'preview': ScenarioGameEngine.scenarioDayKey(DateTime.now()),
              },
      bestMutatorScoreByScenario: const <String, int>{},
      lastPlayedScenarioId: null,
    );
    final seed = _buildSeed(scenario, campaign);
    return MaterialApp(
      home: _ScenarioGameFlow(
        scenario: scenario,
        initialCoins: 1500,
        initialCampaignProgress: campaign,
        seed: seed,
        onPersist:
            (payload) async => _ScenarioPersistResult(
              settlement: ScenarioGameEngine.settlementForOutcome(
                scenario: payload.scenario,
                outcome: payload.outcome,
                campaign: campaign,
                now: DateTime.now(),
                stakeCoins: payload.stakeCoins,
              ),
              campaignProgress: ScenarioGameEngine.applyRunToCampaign(
                scenario: payload.scenario,
                current: campaign,
                outcome: payload.outcome,
                mutators: payload.mutators,
                now: DateTime.now(),
              ),
            ),
      ),
    );
  }

  _ScenarioFlowSeed? _buildSeed(
    PortfolioScenario scenario,
    ScenarioCampaignProgress campaign,
  ) {
    if (previewStage <= 0) {
      return null;
    }
    final thesis = ScenarioThesis.riskOn;
    final plan = scenario.initialPlans.firstWhere(
      (value) => value.id == 'balanced',
    );
    if (previewStage == 1) {
      return _ScenarioFlowSeed(
        stage: 1,
        thesis: thesis,
        currentActIndex: 0,
        mutators: const ScenarioMutatorSet(),
      );
    }
    if (previewStage == 2) {
      return _ScenarioFlowSeed(
        stage: 2,
        thesis: thesis,
        plan: plan,
        resources: ScenarioGameEngine.defaultResources,
        currentActIndex: 0,
        mutators: const ScenarioMutatorSet(),
      );
    }
    final journal = <ScenarioDecisionJournalEntry>[
      ScenarioDecisionJournalEntry(
        actId: scenario.acts[0].id,
        decisionType: ScenarioDecisionType.hedge,
        decisionLabel: 'Couvrir',
        justificationId: scenario.acts[0].justificationOptions.first.id,
        justificationLabel: scenario.acts[0].justificationOptions.first.label,
        branchTag: 'hedged',
        revealedInfo: true,
        allocationAfterDecision: plan.weights,
        tradeCost: 1,
        convictionCost: 20,
      ),
      ScenarioDecisionJournalEntry(
        actId: scenario.acts[1].id,
        decisionType: ScenarioDecisionType.rotate,
        decisionLabel: 'Arbitrer',
        justificationId: scenario.acts[1].justificationOptions[1].id,
        justificationLabel: scenario.acts[1].justificationOptions[1].label,
        branchTag: 'rotated',
        revealedInfo: false,
        allocationAfterDecision: plan.weights,
        tradeCost: 1,
        convictionCost: 30,
      ),
      ScenarioDecisionJournalEntry(
        actId: scenario.acts[2].id,
        decisionType: ScenarioDecisionType.reinforce,
        decisionLabel: 'Renforcer',
        justificationId: scenario.acts[2].justificationOptions.last.id,
        justificationLabel: scenario.acts[2].justificationOptions.last.label,
        branchTag: 'pressed',
        revealedInfo: false,
        allocationAfterDecision: plan.weights,
        tradeCost: 1,
        convictionCost: 30,
      ),
    ];
    final outcome = ScenarioGameEngine.evaluateRun(
      scenario: scenario,
      stakeCoins: 200,
      thesis: thesis,
      initialPlan: plan,
      journal: journal,
      mutators: const ScenarioMutatorSet(),
    );
    final settlement = ScenarioGameEngine.settlementForOutcome(
      scenario: scenario,
      outcome: outcome,
      campaign: campaign,
      now: DateTime.now(),
      stakeCoins: 200,
    );
    return _ScenarioFlowSeed(
      stage: 3,
      thesis: thesis,
      plan: plan,
      resources: ScenarioGameEngine.defaultResources.copyWith(
        tradeCredits: 1,
        infoCredits: 1,
        convictionBudget: 20,
      ),
      currentActIndex: 0,
      journal: journal,
      mutators: const ScenarioMutatorSet(),
      outcome: outcome,
      settlement: settlement,
    );
  }
}

class _ScenarioGameFlow extends StatefulWidget {
  const _ScenarioGameFlow({
    required this.scenario,
    required this.initialCoins,
    required this.initialCampaignProgress,
    required this.onPersist,
    this.seed,
  });

  final PortfolioScenario scenario;
  final int initialCoins;
  final ScenarioCampaignProgress initialCampaignProgress;
  final _ScenarioPersistCallback onPersist;
  final _ScenarioFlowSeed? seed;

  @override
  State<_ScenarioGameFlow> createState() => _ScenarioGameFlowState();
}

class _ScenarioGameFlowState extends State<_ScenarioGameFlow> {
  late int _coins;
  late ScenarioCampaignProgress _campaign;
  ScenarioThesis? _selectedThesis;
  ScenarioInitialPlan? _selectedPlan;
  ScenarioMutatorSet _mutators = const ScenarioMutatorSet();
  ScenarioResourceState _resources = ScenarioGameEngine.defaultResources;
  final List<ScenarioDecisionJournalEntry> _journal =
      <ScenarioDecisionJournalEntry>[];
  final Set<String> _revealedActIds = <String>{};

  int _stage = 0;
  int _stakeCoins = 200;
  int _currentActIndex = 0;
  ScenarioRunOutcome? _outcome;
  ScenarioRunSettlement? _settlement;
  bool _saving = false;
  String? _message;
  ScenarioDecisionOption? _pendingDecision;
  ScenarioJustificationOption? _pendingJustification;

  PortfolioScenario get _scenario => widget.scenario;

  bool get _mutatorsUnlocked => ScenarioGameEngine.canUseMutators(
    scenario: _scenario,
    campaign: _campaign,
  );

  bool get _dailySettlementAvailable =>
      ScenarioGameEngine.hasDailySettlementAvailable(
        scenarioId: _scenario.id,
        campaign: _campaign,
        now: DateTime.now(),
      );

  ScenarioAct get _currentAct => _scenario.acts[_currentActIndex];

  bool get _showBeginnerHelp => _scenario.requiredLevel <= 2;

  @override
  void initState() {
    super.initState();
    _coins = widget.initialCoins;
    _campaign = widget.initialCampaignProgress;
    _stakeCoins = math.min(_coins.clamp(0, 999999), 200);
    final seed = widget.seed;
    if (seed != null) {
      _stage = seed.stage;
      _selectedThesis = seed.thesis;
      _selectedPlan = seed.plan;
      _resources = seed.resources ?? _resources;
      _currentActIndex = seed.currentActIndex;
      _journal.addAll(seed.journal);
      _mutators = seed.mutators;
      _outcome = seed.outcome;
      _settlement = seed.settlement;
    }
  }

  void _goToPlanStage() {
    if (_selectedThesis == null || _stakeCoins <= 0) {
      setState(() {
        _message = 'Choisis une thèse et une mise valide.';
      });
      return;
    }
    setState(() {
      _stage = 1;
      _message = null;
    });
  }

  void _startRun() {
    if (_selectedPlan == null) {
      setState(() {
        _message = 'Sélectionne un plan initial.';
      });
      return;
    }
    setState(() {
      _resources = ScenarioGameEngine.resourcesForMutators(_mutators);
      _journal.clear();
      _revealedActIds.clear();
      _currentActIndex = 0;
      _stage = 2;
      _message = null;
      _pendingDecision = null;
      _pendingJustification = null;
    });
  }

  void _toggleExpertMode(bool value) {
    setState(() {
      _mutators = _mutators.copyWith(expertMode: value);
      _resources = ScenarioGameEngine.resourcesForMutators(_mutators);
    });
  }

  void _toggleMutator({required bool value, required String key}) {
    setState(() {
      switch (key) {
        case 'volatilityBoost':
          _mutators = _mutators.copyWith(volatilityBoost: value);
          break;
        case 'highFees':
          _mutators = _mutators.copyWith(highFees: value);
          break;
        case 'delayedInfo':
          _mutators = _mutators.copyWith(delayedInfo: value);
          break;
        case 'contradictoryNews':
          _mutators = _mutators.copyWith(contradictoryNews: value);
          break;
      }
      _resources = ScenarioGameEngine.resourcesForMutators(_mutators);
    });
  }

  void _revealInfoForAct() {
    if (_resources.infoCredits <= 0) {
      setState(() {
        _message = 'Plus de crédits info disponibles.';
      });
      return;
    }
    if (_mutators.delayedInfo || _mutators.expertMode) {
      setState(() {
        _message =
            'Info retardée: ce mutateur bloque l’info premium sur cet acte.';
      });
      return;
    }
    setState(() {
      _revealedActIds.add(_currentAct.id);
      _resources = _resources.copyWith(infoCredits: _resources.infoCredits - 1);
      _message = null;
    });
  }

  bool _canUseDecision(ScenarioDecisionOption option) {
    return _resources.tradeCredits >= option.tradeCost &&
        _resources.convictionBudget >= option.convictionCost;
  }

  Future<void> _commitAct() async {
    final thesis = _selectedThesis;
    final plan = _selectedPlan;
    final decision = _pendingDecision;
    final justification = _pendingJustification;
    if (thesis == null ||
        plan == null ||
        decision == null ||
        justification == null) {
      setState(() {
        _message = 'Choisis une décision et une justification.';
      });
      return;
    }
    final lastAllocation =
        _journal.isEmpty
            ? Map<String, double>.from(plan.weights)
            : Map<String, double>.from(_journal.last.allocationAfterDecision);
    final nextAllocation = ScenarioGameEngine.applyDecision(
      allocation: lastAllocation,
      scenario: _scenario,
      decisionType: decision.type,
      thesis: thesis,
      currentStep: _currentAct.stepIndex,
    );
    _journal.add(
      ScenarioDecisionJournalEntry(
        actId: _currentAct.id,
        decisionType: decision.type,
        decisionLabel: decision.label,
        justificationId: justification.id,
        justificationLabel: justification.label,
        branchTag: decision.branchTag,
        revealedInfo: _revealedActIds.contains(_currentAct.id),
        allocationAfterDecision: nextAllocation,
        tradeCost: decision.tradeCost,
        convictionCost: decision.convictionCost,
      ),
    );
    setState(() {
      _resources = _resources.copyWith(
        tradeCredits: _resources.tradeCredits - decision.tradeCost,
        convictionBudget: _resources.convictionBudget - decision.convictionCost,
      );
      _pendingDecision = null;
      _pendingJustification = null;
      _message = null;
    });

    if (_currentActIndex < _scenario.acts.length - 1) {
      setState(() {
        _currentActIndex += 1;
      });
      return;
    }

    await _finishRun();
  }

  Future<void> _finishRun() async {
    final thesis = _selectedThesis;
    final plan = _selectedPlan;
    if (thesis == null || plan == null) {
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    final outcome = ScenarioGameEngine.evaluateRun(
      scenario: _scenario,
      stakeCoins: _stakeCoins,
      thesis: thesis,
      initialPlan: plan,
      journal: _journal,
      mutators: _mutators,
    );
    final result = await widget.onPersist(
      _ScenarioPersistPayload(
        scenario: _scenario,
        outcome: outcome,
        thesis: thesis,
        plan: plan,
        mutators: _mutators,
        stakeCoins: _stakeCoins,
        journal: List<ScenarioDecisionJournalEntry>.from(_journal),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _outcome = outcome;
      _settlement = result.settlement;
      _campaign = result.campaignProgress;
      _coins = math.max(0, _coins + result.settlement.netCoins);
      _stage = 3;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          _appBarTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: .2,
          ),
        ),
        backgroundColor: _bg,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const _PremiumAppBarUnderline(),
      ),
      floatingActionButton: const HelpFab(
        helpText:
            "Construis ta thèse, choisis un plan, puis enchaîne trois décisions sous incertitude. Le score final ne dépend pas que du PnL: drawdown, cohérence et timing comptent aussi.",
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          child: switch (_stage) {
            0 => _buildBriefingStage(),
            1 => _buildPlanStage(),
            2 => _buildActStage(),
            _ => _buildDebriefStage(),
          },
        ),
      ),
    );
  }

  String _appBarTitle() {
    switch (_stage) {
      case 0:
        return 'Briefing';
      case 1:
        return 'Plan initial';
      case 2:
        return 'Acte ${_currentActIndex + 2}/${_scenario.acts.length + 1}';
      default:
        return 'Debrief';
    }
  }

  List<_ScenarioTermHintData> _scenarioGlossaryHints(
    PortfolioScenario scenario,
  ) {
    final text = [
      scenario.description,
      scenario.focus,
      scenario.risk,
      ...scenario.prompts.take(3),
      ...ScenarioThesis.values.map((thesis) => thesis.description),
    ].join(' ');
    return _matchScenarioTerms(text, scenario.acts.first.eventType);
  }

  List<_ScenarioTermHintData> _actGlossaryHints(ScenarioAct act) {
    return _matchScenarioTerms(
      '${act.title} ${act.narrative} ${act.decisionPrompt} ${act.extraInfo}',
      act.eventType,
    );
  }

  List<_ScenarioTermHintData> _matchScenarioTerms(
    String rawText,
    ScenarioEventType eventType,
  ) {
    final lower = rawText.toLowerCase();
    final hints = <_ScenarioTermHintData>[];

    void addIf(bool condition, _ScenarioTermHintData hint) {
      if (condition && !hints.any((item) => item.term == hint.term)) {
        hints.add(hint);
      }
    }

    addIf(
      lower.contains('cpi') || eventType == ScenarioEventType.cpi,
      const _ScenarioTermHintData(
        term: 'CPI',
        definition:
            'Indicateur d’inflation consommateur. Plus il surprend, plus les taux et les valorisations peuvent bouger.',
        whyItMatters:
            'Une inflation plus forte pousse souvent les rendements vers le haut et pèse sur les actifs de duration.',
      ),
    );
    addIf(
      lower.contains('drawdown'),
      const _ScenarioTermHintData(
        term: 'Drawdown',
        definition:
            'Baisse maximale subie entre un pic et un creux pendant le run.',
        whyItMatters:
            'Un bon scénario ne récompense pas seulement le PnL final, mais aussi la façon dont tu contrôles la casse.',
      ),
    );
    addIf(
      lower.contains('hedge') || lower.contains('couvr'),
      const _ScenarioTermHintData(
        term: 'Hedge / Couverture',
        definition:
            'Action qui réduit une partie du risque sans forcément fermer totalement la position.',
        whyItMatters:
            'Couvrir protège le portefeuille quand l’incertitude monte ou quand le timing est fragile.',
      ),
    );
    addIf(
      lower.contains('rotation'),
      const _ScenarioTermHintData(
        term: 'Rotation sectorielle',
        definition: 'Déplacement des flux d’un style ou secteur vers un autre.',
        whyItMatters:
            'Le marché ne baisse pas toujours partout: il change souvent simplement de leadership.',
      ),
    );
    addIf(
      lower.contains('guidance') || eventType == ScenarioEventType.guidanceCut,
      const _ScenarioTermHintData(
        term: 'Guidance',
        definition:
            'Prévisions communiquées par l’entreprise sur l’activité ou les marges à venir.',
        whyItMatters:
            'Une baisse de guidance touche les anticipations futures, souvent plus que les chiffres déjà publiés.',
      ),
    );
    addIf(
      lower.contains('duration') || lower.contains('taux'),
      const _ScenarioTermHintData(
        term: 'Duration',
        definition:
            'Sensibilité d’un actif à l’évolution des taux d’intérêt et de l’actualisation.',
        whyItMatters:
            'Quand les taux montent, les actifs les plus dépendants des profits futurs souffrent davantage.',
      ),
    );
    addIf(
      lower.contains('liquidit') ||
          eventType == ScenarioEventType.liquidityStress,
      const _ScenarioTermHintData(
        term: 'Stress de liquidité',
        definition:
            'Moment où le financement ou la capacité à exécuter devient plus rare et plus cher.',
        whyItMatters:
            'Quand la liquidité se tend, le marché punit vite les positions trop agressives ou mal couvertes.',
      ),
    );

    addIf(hints.isEmpty, _fallbackEventHint(eventType));
    return hints.take(4).toList();
  }

  String _whyItMattersForAct(ScenarioAct act) => switch (act.eventType) {
    ScenarioEventType.cpi =>
      'Pourquoi ça compte: un CPI plus chaud ou plus froid modifie la lecture des taux, puis rejaillit sur les secteurs sensibles à la duration.',
    ScenarioEventType.fed =>
      'Pourquoi ça compte: le ton de la Fed change le coût du capital, la tolérance au risque et la hiérarchie entre growth, value et cash.',
    ScenarioEventType.earnings =>
      'Pourquoi ça compte: les résultats déplacent les attentes de bénéfices, donc la valorisation et la confiance dans le scénario.',
    ScenarioEventType.guidanceCut =>
      'Pourquoi ça compte: une coupe de guidance avertit que l’élan futur ralentit, ce qui pèse souvent avant même que les chiffres se dégradent.',
    ScenarioEventType.geopolitical =>
      'Pourquoi ça compte: le risque géopolitique fait remonter les primes de risque, favorise les refuges et peut secouer l’énergie ou les devises.',
    ScenarioEventType.sectorRotation =>
      'Pourquoi ça compte: les flux changent de secteur quand le marché modifie sa priorité entre croissance, marge, défensif ou cyclicité.',
    ScenarioEventType.commodityShock =>
      'Pourquoi ça compte: un choc sur l’énergie ou les matières premières finit souvent par toucher l’inflation, les marges et les attentes de politique monétaire.',
    ScenarioEventType.regulation =>
      'Pourquoi ça compte: une règle nouvelle peut changer directement l’économie d’un secteur, même si les prix n’ont pas encore intégré tout l’impact.',
    ScenarioEventType.liquidityStress =>
      'Pourquoi ça compte: quand le financement se tend, les erreurs de timing et le levier deviennent beaucoup plus coûteux.',
  };

  String _justificationHintForAct(ScenarioAct act) {
    final base =
        'Ta justification sert à noter la cohérence entre ta thèse, ton plan initial et ta décision.';
    return switch (act.eventType) {
      ScenarioEventType.cpi || ScenarioEventType.fed =>
        '$base Ici, explique surtout ton lien avec les taux et la duration.',
      ScenarioEventType.earnings || ScenarioEventType.guidanceCut =>
        '$base Ici, relie plutôt la décision aux attentes futures de bénéfices et de marges.',
      ScenarioEventType.geopolitical || ScenarioEventType.commodityShock =>
        '$base Ici, pense propagation du choc, risque et actifs refuges.',
      _ =>
        '$base Montre la logique de risque, de timing et d’allocation derrière ton choix.',
    };
  }

  String _teachingExplanationForAct(ScenarioAct act) {
    return '${act.eventType.label}: ${_whyItMattersForAct(act).replaceFirst('Pourquoi ça compte: ', '')}';
  }

  Widget _buildBriefingStage() {
    final chapter = ScenarioGameEngine.chapterForScenario(_scenario);
    final briefingHints = _scenarioGlossaryHints(_scenario);
    return ListView(
      key: const ValueKey('scenario-briefing'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroCard(
          title: _scenario.title,
          subtitle: _scenario.description,
          chips: <String>[
            chapter.title,
            _scenario.focus,
            _scenario.risk,
            _dailySettlementAvailable
                ? 'PnL réel disponible'
                : 'Mode entraînement',
          ],
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currency(_coins),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _wine,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_scenario.rewardXp} XP base',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Mise du run'),
              const SizedBox(height: 10),
              Text(
                _dailySettlementAvailable
                    ? 'Ce scénario peut encore régler un PnL réel aujourd’hui.'
                    : 'Le PnL réel du jour est déjà consommé. Ce run restera entraînement + score.',
                style: const TextStyle(color: Colors.black87, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mise sélectionnée',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_stakeCoins.toStringAsFixed(0)} coins',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _wine,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _stakeCoins.toDouble().clamp(
                  0,
                  math.max(50, _coins).toDouble(),
                ),
                min: 50,
                max: math.max(50, _coins).toDouble(),
                divisions: math.max(1, (math.max(50, _coins) / 25).round()),
                activeColor: _wine,
                inactiveColor: _gold.withValues(alpha: 0.18),
                onChanged: (value) {
                  setState(() {
                    _stakeCoins = value.round();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Choisis ta thèse'),
              const SizedBox(height: 12),
              ...ScenarioThesis.values.map(
                (thesis) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ThesisCard(
                    thesis: thesis,
                    selected: thesis == _selectedThesis,
                    onTap: () => setState(() => _selectedThesis = thesis),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Mutateurs'),
              const SizedBox(height: 8),
              Text(
                _mutatorsUnlocked
                    ? 'Active des mutateurs pour pousser la difficulté et comparer tes runs.'
                    : 'Débloque d’abord un premier clear pour activer les mutateurs en replay.',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _mutators.expertMode,
                onChanged: _mutatorsUnlocked ? _toggleExpertMode : null,
                activeThumbColor: _wine,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mode Expert',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Active volatilité, frais, info retardée, news contradictoires et réduit les trades à 3.',
                ),
              ),
              const Divider(height: 12),
              _MutatorSwitchRow(
                label: 'Volatilité renforcée',
                enabled: _mutatorsUnlocked,
                value: _mutators.volatilityBoost || _mutators.expertMode,
                onChanged:
                    (value) =>
                        _toggleMutator(value: value, key: 'volatilityBoost'),
              ),
              _MutatorSwitchRow(
                label: 'Frais plus élevés',
                enabled: _mutatorsUnlocked,
                value: _mutators.highFees || _mutators.expertMode,
                onChanged:
                    (value) => _toggleMutator(value: value, key: 'highFees'),
              ),
              _MutatorSwitchRow(
                label: 'Information retardée',
                enabled: _mutatorsUnlocked,
                value: _mutators.delayedInfo || _mutators.expertMode,
                onChanged:
                    (value) => _toggleMutator(value: value, key: 'delayedInfo'),
              ),
              _MutatorSwitchRow(
                label: 'News contradictoires',
                enabled: _mutatorsUnlocked,
                value: _mutators.contradictoryNews || _mutators.expertMode,
                onChanged:
                    (value) =>
                        _toggleMutator(value: value, key: 'contradictoryNews'),
              ),
            ],
          ),
        ),
        if (_showBeginnerHelp && briefingHints.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ScenarioHelpPanel(
            title: 'Glossaire rapide',
            subtitle:
                'Sur les premiers niveaux, on explicite le jargon et son impact de marché.',
            hints: briefingHints,
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _GradientButton(
          label: 'Valider la thèse',
          icon: Icons.flag_rounded,
          onTap: _goToPlanStage,
        ),
      ],
    );
  }

  Widget _buildPlanStage() {
    return ListView(
      key: const ValueKey('scenario-plan'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroCard(
          title: 'Plan initial',
          subtitle:
              'Trois presets pour démarrer. Le score de cohérence jugera ensuite si tes arbitrages restent alignés avec ta thèse.',
          chips: <String>[
            _selectedThesis?.label ?? 'Thèse non choisie',
            '${_scenario.acts.length} décisions',
            'Trades ${ScenarioGameEngine.resourcesForMutators(_mutators).tradeCredits}',
          ],
          trailing: const Icon(Icons.layers_rounded, size: 28, color: _wine),
        ),
        const SizedBox(height: 16),
        ..._scenario.initialPlans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              plan: plan,
              selected: plan.id == _selectedPlan?.id,
              assets: _scenario.config.assets,
              onTap:
                  () => setState(() {
                    _selectedPlan = plan;
                    _message = null;
                  }),
            ),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _GradientButton(
          label: 'Lancer le scénario',
          icon: Icons.auto_graph_rounded,
          onTap: _startRun,
        ),
      ],
    );
  }

  Widget _buildActStage() {
    final thesis = _selectedThesis!;
    final plan = _selectedPlan!;
    final partialJournal =
        _journal.isEmpty ? const <ScenarioDecisionJournalEntry>[] : _journal;
    final snapshot =
        partialJournal.isNotEmpty
            ? ScenarioGameEngine.buildActSnapshot(
              scenario: _scenario,
              stakeCoins: _stakeCoins,
              thesis: thesis,
              initialPlan: plan,
              journal: partialJournal,
              mutators: _mutators,
            )
            : null;

    return Column(
      key: const ValueKey('scenario-acts'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _TimelineHeader(
            totalActs: _scenario.acts.length,
            currentAct: _currentActIndex,
            provisionalScore: snapshot?.provisionalScore,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _HeroCard(
                title: _currentAct.title,
                subtitle: _currentAct.narrative,
                chips: <String>[
                  _currentAct.eventType.label,
                  _currentAct.marketMood,
                  _currentAct.riskTone,
                ],
                trailing: _RiskDial(
                  label: 'Risque',
                  value:
                      32 +
                      (_currentActIndex * 18) +
                      (_mutators.expertMode ? 12 : 0),
                ),
              ),
              if (_showBeginnerHelp) ...[
                const SizedBox(height: 12),
                _ScenarioHelpPanel(
                  title: 'Aide lecture débutant',
                  subtitle:
                      'Lis le terme, comprends la mécanique, puis décide.',
                  hints: _actGlossaryHints(_currentAct),
                ),
              ],
              const SizedBox(height: 12),
              _ResourceStrip(resources: _resources),
              if (snapshot != null) ...[
                const SizedBox(height: 12),
                _Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          label: 'P&L',
                          value:
                              '${snapshot.pnlPct >= 0 ? '+' : ''}${snapshot.pnlPct.toStringAsFixed(1)}%',
                          positive: snapshot.pnlPct >= 0,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Drawdown',
                          value: '${snapshot.drawdownPct.toStringAsFixed(1)}%',
                          positive: false,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Portefeuille',
                          value: _currency(snapshot.portfolioValue.round()),
                          positive: snapshot.portfolioValue >= _stakeCoins,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('Info de marché')),
                        TextButton.icon(
                          onPressed:
                              _revealedActIds.contains(_currentAct.id) ||
                                      _resources.infoCredits <= 0
                                  ? null
                                  : _revealInfoForAct,
                          icon: const Icon(Icons.visibility_rounded),
                          label: Text(
                            _mutators.delayedInfo || _mutators.expertMode
                                ? 'Info retardée'
                                : 'Révéler (1 info)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentAct.decisionPrompt,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_showBeginnerHelp) ...[
                      const SizedBox(height: 12),
                      _WhyItMattersCard(text: _whyItMattersForAct(_currentAct)),
                    ],
                    if (_revealedActIds.contains(_currentAct.id)) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          _currentAct.extraInfo,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Décision'),
                    const SizedBox(height: 10),
                    ..._currentAct.decisionOptions.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DecisionCard(
                          option: option,
                          selected: option.id == _pendingDecision?.id,
                          enabled: _canUseDecision(option),
                          onTap:
                              () => setState(() {
                                _pendingDecision = option;
                                _message = null;
                              }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Justification'),
                    const SizedBox(height: 10),
                    if (_showBeginnerHelp) ...[
                      Text(
                        _justificationHintForAct(_currentAct),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          _currentAct.justificationOptions.map((option) {
                            final selected =
                                option.id == _pendingJustification?.id;
                            return ChoiceChip(
                              label: Text(option.label),
                              selected: selected,
                              onSelected:
                                  _pendingDecision == null
                                      ? null
                                      : (_) => setState(() {
                                        _pendingJustification = option;
                                        _message = null;
                                      }),
                              selectedColor: _wine.withValues(alpha: 0.14),
                              backgroundColor: _chipBg,
                              labelStyle: TextStyle(
                                color: selected ? _wine : _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_message != null)
                Text(
                  _message!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 8),
              _GradientButton(
                label:
                    _currentActIndex == _scenario.acts.length - 1
                        ? 'Clôturer le run'
                        : 'Valider l’acte',
                icon:
                    _currentActIndex == _scenario.acts.length - 1
                        ? Icons.emoji_events_rounded
                        : Icons.arrow_forward_rounded,
                onTap: _saving ? null : _commitAct,
              ),
              if (_saving) ...[
                const SizedBox(height: 14),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebriefStage() {
    final outcome = _outcome;
    final settlement = _settlement;
    if (outcome == null || settlement == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      key: const ValueKey('scenario-debrief'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroCard(
          title: 'Run terminé',
          subtitle:
              'Le score final compare performance, drawdown, cohérence, gestion du risque et timing. Tu peux réussir sans avoir le meilleur PnL.',
          chips: <String>[
            'Score ${outcome.breakdown.finalScore}/100',
            'Médaille ${outcome.breakdown.medal.label}',
            '${outcome.breakdown.stars} étoile(s)',
          ],
          trailing: _MedalBadge(medal: outcome.breakdown.medal),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Score multidimensionnel'),
              const SizedBox(height: 14),
              _ScoreBar(
                label: 'Performance',
                value: outcome.breakdown.performance,
              ),
              _ScoreBar(label: 'Drawdown', value: outcome.breakdown.drawdown),
              _ScoreBar(label: 'Cohérence', value: outcome.breakdown.coherence),
              _ScoreBar(
                label: 'Gestion du risque',
                value: outcome.breakdown.riskManagement,
              ),
              _ScoreBar(label: 'Timing', value: outcome.breakdown.timing),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Settlement'),
              const SizedBox(height: 12),
              _MiniMetric(
                label:
                    settlement.isDailyRealSettlement
                        ? 'Règlement du jour'
                        : 'Run d’entraînement',
                value:
                    settlement.isDailyRealSettlement
                        ? 'PnL réel + bonus'
                        : 'Bonus réduit sans PnL réel',
                positive: settlement.isDailyRealSettlement,
              ),
              const SizedBox(height: 8),
              _MiniMetric(
                label: 'Coins gagnés',
                value:
                    '${settlement.netCoins >= 0 ? '+' : ''}${settlement.netCoins} coins',
                positive: settlement.netCoins >= 0,
              ),
              const SizedBox(height: 8),
              _MiniMetric(
                label: 'XP',
                value: '+${settlement.xpGranted} XP',
                positive: true,
              ),
              const SizedBox(height: 8),
              _MiniMetric(
                label: 'Valeur finale simulée',
                value: _currency(outcome.finalValue.round()),
                positive: outcome.finalValue >= _stakeCoins,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Comparaison d’archétypes'),
              const SizedBox(height: 10),
              ...outcome.archetypes.map(
                (archetype) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArchetypeCard(archetype: archetype),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Journal de décision'),
              const SizedBox(height: 10),
              ..._journal.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DecisionJournalCard(
                    index: entry.key,
                    journal: entry.value,
                    branchNote: ScenarioGameEngine.branchNoteForTag(
                      entry.value.branchTag,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Notions apprises'),
              const SizedBox(height: 8),
              ..._scenario.acts.map(
                (act) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TeachingPointCard(
                    title: act.teachingPoint,
                    explanation: _teachingExplanationForAct(act),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _GradientButton(
          label: 'Retour',
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final List<String> chips;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0.14),
            _wine.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      chips
                          .map(
                            (chip) => _ChipLabel(
                              label: chip,
                              color: Colors.white.withValues(alpha: 0.72),
                              textColor: _ink,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.totalActs,
    required this.currentAct,
    this.provisionalScore,
  });

  final int totalActs;
  final int currentAct;
  final int? provisionalScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List<Widget>.generate(totalActs, (index) {
              final active = index <= currentAct;
              return Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(
                    right: index == totalActs - 1 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient:
                        active
                            ? const LinearGradient(
                              colors: [_gold, _wine],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                            : null,
                    color: active ? null : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Text(
            provisionalScore != null
                ? 'Score provisoire ${provisionalScore!}'
                : 'Acte ${currentAct + 1}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ResourceStrip extends StatelessWidget {
  const _ResourceStrip({required this.resources});

  final ScenarioResourceState resources;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: _MiniMetric(
              label: 'Trades',
              value: '${resources.tradeCredits}',
              positive: resources.tradeCredits > 0,
            ),
          ),
          Expanded(
            child: _MiniMetric(
              label: 'Info',
              value: '${resources.infoCredits}',
              positive: resources.infoCredits > 0,
            ),
          ),
          Expanded(
            child: _MiniMetric(
              label: 'Conviction',
              value: '${resources.convictionBudget}',
              positive: resources.convictionBudget > 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThesisCard extends StatelessWidget {
  const _ThesisCard({
    required this.thesis,
    required this.selected,
    required this.onTap,
  });

  final ScenarioThesis thesis;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _wine.withValues(alpha: 0.08) : _chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _wine : Colors.black.withValues(alpha: 0.06),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(switch (thesis) {
              ScenarioThesis.riskOn => Icons.bolt_rounded,
              ScenarioThesis.defensive => Icons.shield_rounded,
              ScenarioThesis.contrarian => Icons.change_circle_rounded,
            }, color: selected ? _wine : Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thesis.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected ? _wine : _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thesis.description,
                    style: const TextStyle(color: Colors.black87, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.assets,
    required this.onTap,
  });

  final ScenarioInitialPlan plan;
  final bool selected;
  final List<SimulationAsset> assets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sorted =
        plan.weights.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _gold.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _gold : _line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: selected ? _wine : _ink,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _wine,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.description,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 14),
            ...sorted.take(4).map((entry) {
              final asset = assets.firstWhere(
                (value) => value.id == entry.key,
                orElse: () => assets.first,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        asset.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: entry.value / 100,
                          minHeight: 8,
                          backgroundColor: Colors.black.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _wine,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ScenarioDecisionOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _wine.withValues(alpha: 0.08) : _chipBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _wine : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? _wine : _ink,
                      ),
                    ),
                  ),
                  _ChipLabel(
                    label:
                        '${option.tradeCost} trade · ${option.convictionCost} conv.',
                    color: Colors.white.withValues(alpha: 0.7),
                    textColor: _ink,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                option.description,
                style: const TextStyle(color: Colors.black87, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionJournalCard extends StatelessWidget {
  const _DecisionJournalCard({
    required this.index,
    required this.journal,
    required this.branchNote,
  });

  final int index;
  final ScenarioDecisionJournalEntry journal;
  final String branchNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Décision ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: _wine),
          ),
          const SizedBox(height: 8),
          Text(
            journal.decisionLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            journal.justificationLabel,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            branchNote,
            style: const TextStyle(
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioTermHintData {
  const _ScenarioTermHintData({
    required this.term,
    required this.definition,
    required this.whyItMatters,
  });

  final String term;
  final String definition;
  final String whyItMatters;
}

_ScenarioTermHintData _fallbackEventHint(ScenarioEventType eventType) {
  return switch (eventType) {
    ScenarioEventType.cpi => const _ScenarioTermHintData(
      term: 'CPI',
      definition:
          'Mesure de l’inflation consommateur suivie de près par le marché.',
      whyItMatters:
          'Une surprise d’inflation déplace vite les anticipations de taux et donc les valorisations.',
    ),
    ScenarioEventType.fed => const _ScenarioTermHintData(
      term: 'Fed',
      definition:
          'Banque centrale américaine, clé pour les taux et le coût du capital.',
      whyItMatters:
          'Son ton modifie l’appétit pour le risque bien au-delà des États-Unis.',
    ),
    ScenarioEventType.earnings => const _ScenarioTermHintData(
      term: 'Earnings',
      definition: 'Publication des résultats financiers d’une entreprise.',
      whyItMatters:
          'Le marché reprice immédiatement la crédibilité des profits futurs.',
    ),
    ScenarioEventType.guidanceCut => const _ScenarioTermHintData(
      term: 'Guidance cut',
      definition: 'Révision baissière des prévisions futures.',
      whyItMatters:
          'Le marché regarde le futur avant le passé: une guidance dégradée pèse vite.',
    ),
    ScenarioEventType.geopolitical => const _ScenarioTermHintData(
      term: 'Géopolitique',
      definition:
          'Risque politique, militaire ou diplomatique affectant les flux et primes de risque.',
      whyItMatters:
          'Ces chocs peuvent toucher devises, énergie, refuges et confiance globale.',
    ),
    ScenarioEventType.sectorRotation => const _ScenarioTermHintData(
      term: 'Rotation sectorielle',
      definition: 'Déplacement des flux entre secteurs ou styles.',
      whyItMatters:
          'Un marché peut rester solide tout en changeant totalement de leadership.',
    ),
    ScenarioEventType.commodityShock => const _ScenarioTermHintData(
      term: 'Choc commodity',
      definition: 'Variation brutale d’une matière première clé.',
      whyItMatters:
          'Les marges, l’inflation et les anticipations de taux peuvent être contaminées.',
    ),
    ScenarioEventType.regulation => const _ScenarioTermHintData(
      term: 'Régulation',
      definition: 'Changement de règles qui modifie l’économie d’un secteur.',
      whyItMatters:
          'Les gagnants et perdants peuvent changer avant même que les résultats ne bougent.',
    ),
    ScenarioEventType.liquidityStress => const _ScenarioTermHintData(
      term: 'Stress de liquidité',
      definition:
          'Tension sur le financement ou la capacité à sortir d’une position.',
      whyItMatters:
          'Quand la liquidité disparaît, le mauvais timing coûte beaucoup plus cher.',
    ),
  };
}

class _ScenarioHelpPanel extends StatelessWidget {
  const _ScenarioHelpPanel({
    required this.title,
    required this.subtitle,
    required this.hints,
  });

  final String title;
  final String subtitle;
  final List<_ScenarioTermHintData> hints;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...hints.map(
            (hint) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hint.term,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _wine,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint.definition,
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pourquoi: ${hint.whyItMatters}',
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
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

class _WhyItMattersCard extends StatelessWidget {
  const _WhyItMattersCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TeachingPointCard extends StatelessWidget {
  const _TeachingPointCard({required this.title, required this.explanation});

  final String title;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_rounded, size: 16, color: _wine),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  explanation,
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  const _ArchetypeCard({required this.archetype});

  final ScenarioArchetypeComparison archetype;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [_gold, _wine],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                '${archetype.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  archetype.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  archetype.note,
                  style: const TextStyle(color: Colors.black87, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _wine),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.positive,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _gameMuted,
            fontSize: _scaledFont(context, 12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: _scaledFont(context, 15),
            color: positive ? Colors.green.shade700 : _ink,
          ),
        ),
      ],
    );
  }
}

class _RiskDial extends StatelessWidget {
  const _RiskDial({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: CircularProgressIndicator(
                  value: value.clamp(0, 100) / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.65),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    value > 65 ? Colors.redAccent : _wine,
                  ),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 10,
                backgroundColor: Colors.black.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(_wine),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalBadge extends StatelessWidget {
  const _MedalBadge({required this.medal});

  final ScenarioMedal medal;

  @override
  Widget build(BuildContext context) {
    final label = medal == ScenarioMedal.none ? '0' : '${medal.stars}';
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [_gold, _wine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            Text(
              medal.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.score,
    required this.medal,
    required this.rewardXp,
  });

  final int? score;
  final ScenarioMedal medal;
  final int rewardXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _wine.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _wine.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            score == null ? '$rewardXp XP' : '${score!}/100',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _wine,
              fontSize: 13,
            ),
          ),
          if (score != null)
            Text(
              medal == ScenarioMedal.none ? 'Tentative' : medal.label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _MutatorSwitchRow extends StatelessWidget {
  const _MutatorSwitchRow({
    required this.label,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: _wine,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: _ink,
        fontSize: 16.5,
      ),
    );
  }
}

class _BriefingBullet extends StatelessWidget {
  const _BriefingBullet(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _wine.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _wine.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.check_rounded, size: 14, color: _wine),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black87, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient:
                enabled
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
            boxShadow:
                enabled
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                    : const [],
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

class _PremiumAppBarUnderline extends StatelessWidget
    implements PreferredSizeWidget {
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
