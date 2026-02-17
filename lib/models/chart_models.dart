enum ChartInterval {
  oneDay,
  sevenDays,
  oneMonth,
  sixMonths,
  yearToDate,
  fiveYears,
  max,
}

class ChartIntervalMeta {
  const ChartIntervalMeta({
    required this.range,
    required this.granularity,
    required this.intraday,
  });

  final String range;
  final String granularity;
  final bool intraday;
}

class HistoricalPoint {
  HistoricalPoint({required this.time, required this.close});

  final DateTime time;
  final double close;
}

const Map<ChartInterval, ChartIntervalMeta> chartIntervalMetas = {
  ChartInterval.oneDay: ChartIntervalMeta(
    range: '1d',
    granularity: '5m',
    intraday: true,
  ),
  ChartInterval.sevenDays: ChartIntervalMeta(
    range: '5d',
    granularity: '15m',
    intraday: true,
  ),
  ChartInterval.oneMonth: ChartIntervalMeta(
    range: '1mo',
    granularity: '1d',
    intraday: false,
  ),
  ChartInterval.sixMonths: ChartIntervalMeta(
    range: '6mo',
    granularity: '1d',
    intraday: false,
  ),
  ChartInterval.yearToDate: ChartIntervalMeta(
    range: 'ytd',
    granularity: '1d',
    intraday: false,
  ),
  ChartInterval.fiveYears: ChartIntervalMeta(
    range: '5y',
    granularity: '1wk',
    intraday: false,
  ),
  ChartInterval.max: ChartIntervalMeta(
    range: 'max',
    granularity: '1mo',
    intraday: false,
  ),
};

extension ChartIntervalLabel on ChartInterval {
  String get shortLabel {
    switch (this) {
      case ChartInterval.oneDay:
        return '1J';
      case ChartInterval.sevenDays:
        return '7J';
      case ChartInterval.oneMonth:
        return '1M';
      case ChartInterval.sixMonths:
        return '6M';
      case ChartInterval.yearToDate:
        return 'AAJ';
      case ChartInterval.fiveYears:
        return '5A';
      case ChartInterval.max:
        return 'Tout';
    }
  }

  bool get isIntraday => chartIntervalMetas[this]?.intraday ?? false;

  ChartIntervalMeta get meta =>
      chartIntervalMetas[this] ??
      const ChartIntervalMeta(range: '1mo', granularity: '1d', intraday: false);
}
