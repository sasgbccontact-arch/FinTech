import 'dart:math' as math;

import 'package:fintech/services/daily_reward_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyRewardService', () {
    test('détecte correctement un claim le même jour', () {
      final now = DateTime(2026, 3, 14, 20, 15);

      expect(
        DailyRewardService.hasClaimedToday(
          DateTime(2026, 3, 14, 8, 30),
          now: now,
        ),
        isTrue,
      );
      expect(
        DailyRewardService.hasClaimedToday(
          DateTime(2026, 3, 13, 23, 59),
          now: now,
        ),
        isFalse,
      );
    });

    test('génère une récompense gratuite dans les bornes prévues', () {
      final grant = DailyRewardService.rollDailyReward(random: math.Random(1));

      expect(<String>['coins', 'gems'], contains(grant.currencyKey));
      if (grant.isCoins) {
        expect(<int>[100, 200, 300], contains(grant.amount));
      } else {
        expect(<int>[2, 4, 6], contains(grant.amount));
      }
    });

    test('génère un bonus pub plus faible que le cadeau gratuit', () {
      final grant = DailyRewardService.rollAdBonusReward(
        random: math.Random(7),
      );

      expect(<String>['coins', 'gems'], contains(grant.currencyKey));
      if (grant.isCoins) {
        expect(<int>[40, 60, 80], contains(grant.amount));
      } else {
        expect(<int>[1, 2], contains(grant.amount));
      }
    });
  });
}
