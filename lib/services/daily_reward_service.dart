import 'dart:math' as math;

class DailyRewardGrant {
  const DailyRewardGrant({
    required this.currencyKey,
    required this.amount,
    required this.label,
    required this.activityPoints,
  });

  final String currencyKey;
  final int amount;
  final String label;
  final int activityPoints;

  bool get isCoins => currencyKey == 'coins';
}

class DailyRewardService {
  const DailyRewardService._();

  static bool isSameCalendarDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static bool hasClaimedToday(DateTime? lastClaimAt, {DateTime? now}) {
    if (lastClaimAt == null) return false;
    return isSameCalendarDay(lastClaimAt, now ?? DateTime.now());
  }

  static DailyRewardGrant rollDailyReward({math.Random? random}) {
    final source = random ?? math.Random();
    final isCoins = source.nextBool();
    if (isCoins) {
      final amount = _pickAmount(source, const <int>[100, 200, 300]);
      return DailyRewardGrant(
        currencyKey: 'coins',
        amount: amount,
        label: 'Pièces',
        activityPoints: 14 + (amount ~/ 20),
      );
    }

    final amount = _pickAmount(source, const <int>[2, 4, 6]);
    return DailyRewardGrant(
      currencyKey: 'gems',
      amount: amount,
      label: 'Gemmes',
      activityPoints: 14 + (amount * 8),
    );
  }

  static DailyRewardGrant rollAdBonusReward({math.Random? random}) {
    final source = random ?? math.Random();
    final isCoins = source.nextInt(4) < 3;
    if (isCoins) {
      final amount = _pickAmount(source, const <int>[40, 60, 80]);
      return DailyRewardGrant(
        currencyKey: 'coins',
        amount: amount,
        label: 'Pièces',
        activityPoints: 8 + (amount ~/ 20),
      );
    }

    final amount = _pickAmount(source, const <int>[1, 2]);
    return DailyRewardGrant(
      currencyKey: 'gems',
      amount: amount,
      label: 'Gemmes',
      activityPoints: 8 + (amount * 10),
    );
  }

  static int _pickAmount(math.Random random, List<int> options) {
    return options[random.nextInt(options.length)];
  }
}
