import 'package:fintech/models/scenario_game_models.dart';
import 'package:fintech/services/scenario_game_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PortfolioScenario buildScenario() {
    return PortfolioScenario.fromJson(const <String, dynamic>{
      'id': 'scenario_rate_hike',
      'title': 'Choc Inflation & Taux',
      'description': 'Rotation sectorielle violente.',
      'focus': 'Macro',
      'risk': 'Taux',
      'stageId': 'fundamentals',
      'rewardXp': 20,
      'prompts': <String>[
        'La duration longue souffre.',
        'Le cash court redevient compétitif.',
      ],
      'config': <String, dynamic>{
        'headline': 'Hausse des taux',
        'periodLabel': '6 pas',
        'durationLabel': '6 mois',
        'stepLabel': '1 mois',
        'initialCash': 30000,
        'playbackMs': 850,
        'assets': <Map<String, dynamic>>[
          {
            'id': 'tech',
            'label': 'Tech',
            'prices': <int>[100, 92, 88, 84, 82, 80],
            'role': 'Croissance',
          },
          {
            'id': 'banks',
            'label': 'Banques',
            'prices': <int>[100, 102, 105, 108, 110, 112],
            'role': 'Bénéficiaire',
          },
          {
            'id': 'short_bonds',
            'label': 'Bons du Trésor court',
            'prices': <double>[100, 100.1, 100.4, 100.8, 101.1, 101.4],
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
          'Le CPI surprend à la hausse.',
          'Les banques surperforment.',
          'La duration longue souffre.',
        ],
        'suggestedAllocation': <String, int>{
          'tech': 20,
          'banks': 35,
          'short_bonds': 25,
          'cash': 20,
        },
      },
    });
  }

  group('ScenarioGameEngine', () {
    test('génère un dayKey local sur 8 chiffres', () {
      expect(
        ScenarioGameEngine.scenarioDayKey(DateTime(2026, 3, 13)),
        '20260313',
      );
    });

    testWidgets('charge les 27 scénarios et les enrichit en v2', (
      tester,
    ) async {
      final scenarios = await PortfolioScenario.loadScenarios();

      expect(scenarios, hasLength(27));
      expect(
        scenarios.every((scenario) => scenario.chapterId.isNotEmpty),
        isTrue,
      );
      expect(
        scenarios.every((scenario) => scenario.initialPlans.length == 3),
        isTrue,
      );
      expect(scenarios.every((scenario) => scenario.acts.length == 3), isTrue);
      expect(
        scenarios.every(
          (scenario) =>
              scenario.acts.every((act) => act.decisionOptions.length == 5),
        ),
        isTrue,
      );
    });

    test('débloque les chapitres avec niveau + étoiles', () {
      const campaign = ScenarioCampaignProgress(
        chapterStars: <String, int>{'macro_cycles': 9},
        chapterBestScores: <String, int>{},
        scenarioBestScores: <String, int>{},
        scenarioBestMedals: <String, String>{},
        firstClearScenarioIds: <String>[],
        dailyRealSettlementByScenario: <String, String>{},
        bestMutatorScoreByScenario: <String, int>{},
        lastPlayedScenarioId: null,
      );

      expect(
        ScenarioGameEngine.isChapterUnlocked(
          chapter: kScenarioChapters[1],
          level: 2,
          campaign: campaign,
        ),
        isTrue,
      );
      expect(
        ScenarioGameEngine.isChapterUnlocked(
          chapter: kScenarioChapters[2],
          level: 2,
          campaign: campaign,
        ),
        isFalse,
      );
    });

    test('calcule un settlement first clear avec PnL réel', () {
      final scenario = buildScenario();
      final outcome = ScenarioRunOutcome(
        finalValue: 260,
        finalPnlPct: 30,
        maxDrawdownPct: 8,
        branchPath: const <String>['hedged', 'rotated', 'pressed'],
        breakdown: const ScenarioScoreBreakdown(
          performance: 82,
          drawdown: 76,
          coherence: 80,
          riskManagement: 78,
          timing: 74,
          finalScore: 79,
          stars: 2,
          medal: ScenarioMedal.silver,
        ),
        archetypes: const <ScenarioArchetypeComparison>[],
        provisionalScore: 79,
        feesPaid: 0,
      );

      final settlement = ScenarioGameEngine.settlementForOutcome(
        scenario: scenario,
        outcome: outcome,
        campaign: ScenarioCampaignProgress.empty,
        now: DateTime(2026, 3, 13),
        stakeCoins: 200,
      );

      expect(settlement.isFirstClear, isTrue);
      expect(settlement.isDailyRealSettlement, isTrue);
      expect(settlement.netCoins, 180);
      expect(settlement.bonusCoins, 120);
      expect(settlement.xpGranted, 25);
    });

    test('réduit fortement les gains sur replay sans PnL réel', () {
      final scenario = buildScenario();
      final outcome = ScenarioRunOutcome(
        finalValue: 260,
        finalPnlPct: 30,
        maxDrawdownPct: 8,
        branchPath: const <String>['hedged'],
        breakdown: const ScenarioScoreBreakdown(
          performance: 82,
          drawdown: 76,
          coherence: 80,
          riskManagement: 78,
          timing: 74,
          finalScore: 79,
          stars: 2,
          medal: ScenarioMedal.silver,
        ),
        archetypes: const <ScenarioArchetypeComparison>[],
        provisionalScore: 79,
        feesPaid: 0,
      );
      final campaign = ScenarioCampaignProgress(
        chapterStars: const <String, int>{},
        chapterBestScores: const <String, int>{},
        scenarioBestScores: const <String, int>{},
        scenarioBestMedals: const <String, String>{},
        firstClearScenarioIds: <String>[scenario.id],
        dailyRealSettlementByScenario: <String, String>{
          scenario.id: ScenarioGameEngine.scenarioDayKey(DateTime(2026, 3, 13)),
        },
        bestMutatorScoreByScenario: const <String, int>{},
        lastPlayedScenarioId: null,
      );

      final settlement = ScenarioGameEngine.settlementForOutcome(
        scenario: scenario,
        outcome: outcome,
        campaign: campaign,
        now: DateTime(2026, 3, 13),
        stakeCoins: 200,
      );

      expect(settlement.isFirstClear, isFalse);
      expect(settlement.isDailyRealSettlement, isFalse);
      expect(settlement.netCoins, 42);
      expect(settlement.xpGranted, 7);
    });

    test('évalue un run et retourne un score borné', () {
      final scenario = buildScenario();
      final plan = scenario.initialPlans.firstWhere(
        (plan) => plan.id == 'balanced',
      );
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
        thesis: ScenarioThesis.riskOn,
        initialPlan: plan,
        journal: journal,
        mutators: const ScenarioMutatorSet(),
      );

      expect(outcome.breakdown.finalScore, inInclusiveRange(0, 100));
      expect(outcome.breakdown.stars, inInclusiveRange(0, 3));
      expect(outcome.branchPath, hasLength(3));
      expect(outcome.archetypes, hasLength(3));
    });
  });
}
