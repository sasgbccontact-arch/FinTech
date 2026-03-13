import 'package:fintech/models/term_deposit_game_models.dart';
import 'package:fintech/services/term_deposit_game_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TermDepositGameEngine', () {
    test(
      'mappe correctement les coûts premium et la monnaie de chaque skill',
      () {
        final extraReroll = TermDepositGameEngine.skillDefinitionById(
          kTreasurySkillExtraReroll,
        );
        final ladderMaster = TermDepositGameEngine.skillDefinitionById(
          kTreasurySkillLadderMaster,
        );
        final premiumSlot = TermDepositGameEngine.skillDefinitionById(
          kTreasurySkillPremiumSlot,
        );

        expect(extraReroll, isNotNull);
        expect(extraReroll!.requiredSeasonPoints, 70);
        expect(extraReroll.gemCost, 60);
        expect(extraReroll.seasonPointCost, 0);
        expect(extraReroll.usesSeasonPointsCurrency, isFalse);

        expect(ladderMaster, isNotNull);
        expect(ladderMaster!.requiredSeasonPoints, 130);
        expect(ladderMaster.seasonPointCost, 130);
        expect(ladderMaster.gemCost, 0);
        expect(ladderMaster.usesSeasonPointsCurrency, isTrue);

        expect(premiumSlot, isNotNull);
        expect(premiumSlot!.requiredSeasonPoints, 180);
        expect(premiumSlot.gemCost, 120);
        expect(premiumSlot.usesSeasonPointsCurrency, isFalse);
      },
    );

    test('génère un dayKey local stable', () {
      expect(treasuryDayKey(DateTime(2026, 3, 13)), '20260313');
      expect(treasuryDayKey(DateTime(2026, 11, 5)), '20261105');
    });

    test('génère un board quotidien déterministe pour un uid + dayKey', () {
      final meta = TermDepositGameEngine.defaultMetaState(
        now: DateTime(2026, 3, 13),
      );
      final boardA = TermDepositGameEngine.buildBoard(
        uid: 'player-1',
        dayKey: '20260313',
        metaState: meta,
        rerollsUsed: 0,
        now: DateTime(2026, 3, 13),
      );
      final boardB = TermDepositGameEngine.buildBoard(
        uid: 'player-1',
        dayKey: '20260313',
        metaState: meta,
        rerollsUsed: 0,
        now: DateTime(2026, 3, 13),
      );

      expect(boardA.regime, boardB.regime);
      expect(boardA.shortRate, boardB.shortRate);
      expect(boardA.mediumRate, boardB.mediumRate);
      expect(boardA.longRate, boardB.longRate);
      expect(
        boardA.offers.map((offer) => offer.toMap()).toList(),
        boardB.offers.map((offer) => offer.toMap()).toList(),
      );
      expect(
        boardA.events.map((event) => event.toMap()).toList(),
        boardB.events.map((event) => event.toMap()).toList(),
      );
    });

    test(
      'produit une courbe inversée cohérente quand le régime correspond',
      () {
        final meta = TermDepositGameEngine.defaultMetaState(
          now: DateTime(2026, 1, 1),
        );
        TreasuryBoard? invertedBoard;
        for (var day = 1; day <= 40; day++) {
          final dayKey = '202601${day.toString().padLeft(2, '0')}';
          final board = TermDepositGameEngine.buildBoard(
            uid: 'curve-seeker',
            dayKey: dayKey,
            metaState: meta,
            rerollsUsed: 0,
            now: DateTime(2026, 1, day.clamp(1, 28)),
          );
          if (board.regime == TreasuryMarketRegime.invertedCurve) {
            invertedBoard = board;
            break;
          }
        }

        expect(invertedBoard, isNotNull);
        expect(invertedBoard!.shortRate, greaterThan(invertedBoard.mediumRate));
        expect(invertedBoard.mediumRate, greaterThan(invertedBoard.longRate));
      },
    );

    test('calcule correctement l’éligibilité des upgrades de slots', () {
      final lockedMeta = TermDepositGameEngine.normalizeMetaState(
        TermDepositGameEngine.defaultMetaState(
          now: DateTime(2026, 3, 13),
        ).copyWith(xp: 360, seasonPoints: 80, slotCount: 2),
        now: DateTime(2026, 3, 13),
      );
      final eligibleMeta = TermDepositGameEngine.normalizeMetaState(
        TermDepositGameEngine.defaultMetaState(
          now: DateTime(2026, 3, 13),
        ).copyWith(xp: 360, seasonPoints: 120, slotCount: 2),
        now: DateTime(2026, 3, 13),
      );
      final nextUpgrade = TermDepositGameEngine.nextSlotUpgradeFor(
        eligibleMeta,
      );

      expect(nextUpgrade, isNotNull);
      expect(nextUpgrade!.targetSlotCount, 3);
      expect(
        TermDepositGameEngine.meetsSlotUpgradeRequirements(
          definition: nextUpgrade,
          metaState: lockedMeta,
        ),
        isFalse,
      );
      expect(
        TermDepositGameEngine.meetsSlotUpgradeRequirements(
          definition: nextUpgrade,
          metaState: eligibleMeta,
        ),
        isTrue,
      );
    });

    test('les upgrades premium ne consomment pas les season points', () {
      final premiumSkill =
          TermDepositGameEngine.skillDefinitionById(kTreasurySkillEventShield)!;

      expect(premiumSkill.usesSeasonPointsCurrency, isFalse);
      expect(premiumSkill.seasonPointCost, 0);
      expect(premiumSkill.gemCost, 100);
    });

    test('Ladder Master reste acheté en points de saison', () {
      final ladderMaster =
          TermDepositGameEngine.skillDefinitionById(
            kTreasurySkillLadderMaster,
          )!;

      expect(ladderMaster.usesSeasonPointsCurrency, isTrue);
      expect(ladderMaster.seasonPointCost, 130);
      expect(ladderMaster.gemCost, 0);
    });

    test(
      'accorde un ladder bonus quand trois maturités distinctes sont tenues',
      () {
        const board = TreasuryBoard(
          dayKey: '20260313',
          regime: TreasuryMarketRegime.normalization,
          offers: <TreasuryOffer>[
            TreasuryOffer(
              id: 's',
              productType: TreasuryProductType.simple,
              durationDays: 4,
              apy: 0.10,
              lockMode: TreasuryLockMode.standard,
              slotCost: 1,
              requiresPremiumSlot: false,
              label: 'Simple',
            ),
            TreasuryOffer(
              id: 'm',
              productType: TreasuryProductType.flexible,
              durationDays: 12,
              apy: 0.14,
              lockMode: TreasuryLockMode.flexible,
              slotCost: 1,
              requiresPremiumSlot: false,
              label: 'Flexible',
            ),
            TreasuryOffer(
              id: 'l',
              productType: TreasuryProductType.locked,
              durationDays: 24,
              apy: 0.20,
              lockMode: TreasuryLockMode.locked,
              slotCost: 1,
              requiresPremiumSlot: false,
              label: 'Locked',
            ),
          ],
          events: <TreasuryEvent>[],
          rerollsLeft: 1,
          rerollsUsed: 0,
          seasonKey: '2026-Q1',
          shortRate: 0.07,
          mediumRate: 0.14,
          longRate: 0.20,
        );
        final positions = <TreasuryPosition>[
          _position('1', board.offers[0], 120, DateTime(2026, 3, 10)),
          _position('2', board.offers[1], 180, DateTime(2026, 3, 10)),
          _position('3', board.offers[2], 260, DateTime(2026, 3, 10)),
        ];

        final breakdown = TermDepositGameEngine.scoreTreasury(
          board: board,
          positions: positions,
          availableCoins: 400,
          skillState: const TreasurySkillState(
            unlockedSkillIds: <String>[],
            forecastTomorrow: null,
            freeEarlyExitWeekly: 0,
            extraReroll: 0,
            eventShieldRemaining: 0,
            premiumSlotUnlocked: false,
          ),
        );

        expect(breakdown.ladderBonus, greaterThan(0));
        expect(breakdown.distinctMaturityCount, 3);
      },
    );

    test('résout un choc sévère avec pénalité puis cassure flexible', () {
      final now = DateTime(2026, 3, 13, 9);
      const board = TreasuryBoard(
        dayKey: '20260312',
        regime: TreasuryMarketRegime.bankingStress,
        offers: <TreasuryOffer>[],
        events: <TreasuryEvent>[
          TreasuryEvent(
            id: 'event',
            title: 'Appel de collatéral',
            description: 'Le marché demande du cash.',
            eventType: TreasuryEventType.marginShock,
            requiredLiquidCoins: 500,
            penaltyCoins: 120,
            bonusCoins: 0,
            severity: TreasuryEventSeverity.high,
            resolved: false,
          ),
        ],
        rerollsLeft: 1,
        rerollsUsed: 0,
        seasonKey: '2026-Q1',
        shortRate: 0.12,
        mediumRate: 0.16,
        longRate: 0.19,
      );
      final flexibleOffer = TreasuryOffer(
        id: 'flex',
        productType: TreasuryProductType.flexible,
        durationDays: 12,
        apy: 0.12,
        lockMode: TreasuryLockMode.flexible,
        slotCost: 1,
        requiresPremiumSlot: false,
        label: 'Flexible',
      );
      final positions = <TreasuryPosition>[
        _position(
          'flex-1',
          flexibleOffer,
          300,
          now.subtract(const Duration(days: 2)),
        ),
      ];

      final preview = TermDepositGameEngine.previewResolution(
        board: board,
        positions: positions,
        availableCoins: 90,
        metaState: TermDepositGameEngine.defaultMetaState(now: now),
        now: now,
      );

      expect(preview.penaltyCoins, greaterThan(0));
      expect(preview.brokenPositionIds, contains('flex-1'));
      expect(preview.forcedBreakCoins, greaterThan(0));
    });

    test(
      'calcule un coût d’opportunité quand une offre meilleure apparaît ensuite',
      () {
        final position = _position(
          'opportunity',
          const TreasuryOffer(
            id: 'old',
            productType: TreasuryProductType.simple,
            durationDays: 12,
            apy: 0.10,
            lockMode: TreasuryLockMode.standard,
            slotCost: 1,
            requiresPremiumSlot: false,
            label: 'Old',
          ),
          300,
          DateTime(2026, 3, 10),
        );
        final offers = <TreasuryOffer>[
          const TreasuryOffer(
            id: 'better',
            productType: TreasuryProductType.simple,
            durationDays: 12,
            apy: 0.18,
            lockMode: TreasuryLockMode.standard,
            slotCost: 1,
            requiresPremiumSlot: false,
            label: 'Better',
          ),
        ];

        final updated = TermDepositGameEngine.applyOpportunityCost(
          position,
          offers,
        );

        expect(updated.opportunityCostCoins, greaterThan(0));
      },
    );

    test('rehydrate un dépôt legacy sans casser le claim manuel', () {
      final legacy = TreasuryPosition.fromMap('legacy-id', <String, dynamic>{
        'type': 'gems',
        'amount': 120,
        'rate': 0.10,
        'duration_days': 7,
        'start_date': DateTime(2026, 3, 1),
        'end_date': DateTime(2026, 3, 8),
        'status': 'active',
      });

      expect(legacy.isLegacy, isTrue);
      expect(legacy.legacyCurrencyType, 'gems');
      expect(legacy.payoutCoins, 132);
    });
  });
}

TreasuryPosition _position(
  String id,
  TreasuryOffer offer,
  int principal,
  DateTime openedAt,
) {
  final maturesAt = openedAt.add(Duration(days: offer.durationDays));
  return TreasuryPosition(
    id: id,
    principalCoins: principal,
    offerSnapshot: offer,
    openedAt: openedAt,
    maturesAt: maturesAt,
    status: 'active',
    brokenEarly: false,
    liquidityPenaltyPreview: 0,
    opportunityCostCoins: 0,
    payoutCoins: TermDepositGameEngine.payoutForOffer(principal, offer),
    isLegacy: false,
    legacyCurrencyType: 'coins',
    startDayKey: treasuryDayKey(openedAt),
    maturesDayKey: treasuryDayKey(maturesAt),
  );
}
