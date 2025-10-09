class FinancialSnapshot {
  const FinancialSnapshot({
    this.revenue,
    this.netIncome,
    this.eps,
    this.ebitda,
    this.ebit,
    this.operatingMargin,
    this.netMargin,
    this.dividendYield,
    this.payoutRatio,
    this.pegRatio,
    this.bookValue,
    this.bookValuePerShare,
    this.priceToBook,
    this.equity,
    this.returnOnAssets,
    this.returnOnEquity,
    this.totalCash,
    this.totalDebt,
    this.debtToEbitda,
    this.floatShares,
    this.trailingPe,
    this.trailingAnnualDividendRate,
    this.trailingAnnualDividendYield,
  });

  final double? revenue;
  final double? netIncome;
  final double? eps;
  final double? ebitda;
  final double? ebit;
  final double? operatingMargin;
  final double? netMargin;
  final double? dividendYield;
  final double? payoutRatio;
  final double? pegRatio;
  final double? bookValue;
  final double? bookValuePerShare;
  final double? priceToBook;
  final double? equity;
  final double? returnOnAssets;
  final double? returnOnEquity;
  final double? totalCash;
  final double? totalDebt;
  final double? debtToEbitda;
  final double? floatShares;
  final double? trailingPe;
  final double? trailingAnnualDividendRate;
  final double? trailingAnnualDividendYield;

  static FinancialSnapshot fromQuoteSummary(Map<String, dynamic> summary) {
    double? readNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      if (value is Map<String, dynamic>) {
        final raw = value['raw'];
        if (raw is num) return raw.toDouble();
        final fmt = value['fmt'];
        if (fmt is String) {
          final sanitized = fmt.replaceAll(',', '');
          return double.tryParse(sanitized);
        }
      }
      return null;
    }

    Map<String, dynamic>? asMap(dynamic value) =>
        value is Map<String, dynamic> ? value : null;

    List<dynamic>? asList(dynamic value) =>
        value is List<dynamic> ? value : null;

    final financialData = asMap(summary['financialData']);
    final summaryDetail = asMap(summary['summaryDetail']);
    final defaultKeyStatistics = asMap(summary['defaultKeyStatistics']);
    final balanceSheetHistory = asMap(summary['balanceSheetHistory']);
    final balanceSheetHistoryQuarterly = asMap(summary['balanceSheetHistoryQuarterly']);
    final incomeStatementHistory = asMap(summary['incomeStatementHistory']);
    final incomeStatementHistoryQuarterly = asMap(summary['incomeStatementHistoryQuarterly']);

    Map<String, dynamic>? firstFromHistory(Map<String, dynamic>? history, String key) {
      if (history == null) return null;
      final list = asList(history[key]);
      if (list == null || list.isEmpty) return null;
      return asMap(list.first);
    }

    Map<String, dynamic>? _latestBalanceSheet() {
      final yearly = firstFromHistory(balanceSheetHistory, 'balanceSheetStatements');
      if (yearly != null) return yearly;
      return firstFromHistory(balanceSheetHistoryQuarterly, 'balanceSheetStatements');
    }

    Map<String, dynamic>? _latestIncomeStatement() {
      final yearly = firstFromHistory(incomeStatementHistory, 'incomeStatementHistory');
      if (yearly != null) return yearly;
      return firstFromHistory(incomeStatementHistoryQuarterly, 'incomeStatementHistory');
    }

    final latestBalanceSheet = _latestBalanceSheet();
    final latestIncomeStatement = _latestIncomeStatement();

    double? readFinancialData(String key) =>
        financialData == null ? null : readNum(financialData[key]);
    double? readSummaryDetail(String key) =>
        summaryDetail == null ? null : readNum(summaryDetail[key]);
    double? readKeyStatistic(String key) =>
        defaultKeyStatistics == null ? null : readNum(defaultKeyStatistics[key]);
    double? readBalanceSheet(String key) =>
        latestBalanceSheet == null ? null : readNum(latestBalanceSheet[key]);
    double? readIncomeStatement(String key) =>
        latestIncomeStatement == null ? null : readNum(latestIncomeStatement[key]);

    double? readBalanceOrFinancial(String primary, {String? alternate}) {
      final fromBalance = readBalanceSheet(primary);
      if (fromBalance != null) return fromBalance;
      if (alternate != null) {
        final alt = readBalanceSheet(alternate);
        if (alt != null) return alt;
      }
      return readFinancialData(primary);
    }

    final totalAssets = readBalanceOrFinancial('totalAssets');
    final totalLiabilities = readBalanceOrFinancial('totalLiab', alternate: 'totalLiabilities');
    final stockholderEquity = readBalanceOrFinancial(
          'totalStockholderEquity',
          alternate: 'totalEquityGrossMinorityInterest',
        ) ?? readBalanceOrFinancial('commonStockEquity');
    final sharesOutstanding = readKeyStatistic('sharesOutstanding') ??
        readKeyStatistic('shares') ??
        readFinancialData('sharesOutstanding');

    double? computeBookValue(double? bvps) {
      if (bvps != null && sharesOutstanding != null) {
        return bvps * sharesOutstanding;
      }
      if (totalAssets != null && totalLiabilities != null) {
        return totalAssets - totalLiabilities;
      }
      return stockholderEquity;
    }

    return FinancialSnapshot(
      revenue: readFinancialData('totalRevenue') ?? readIncomeStatement('totalRevenue'),
      netIncome: readIncomeStatement('netIncome'),
      eps: readFinancialData('eps'),
      ebitda: readFinancialData('ebitda'),
      ebit: readIncomeStatement('ebit') ??
          readIncomeStatement('operatingIncome') ??
          readFinancialData('ebit') ??
          readFinancialData('operatingIncome'),
      operatingMargin: readFinancialData('operatingMargins'),
      netMargin: readFinancialData('profitMargins'),
      dividendYield: readSummaryDetail('dividendYield') ?? readFinancialData('dividendYield'),
      payoutRatio: readSummaryDetail('payoutRatio'),
      pegRatio: readKeyStatistic('pegRatio') ??
          readFinancialData('pegRatio') ??
          readSummaryDetail('pegRatio'),
      bookValuePerShare: readKeyStatistic('bookValue') ?? readFinancialData('bookValue'),
      bookValue: computeBookValue(
        readKeyStatistic('bookValue') ?? readFinancialData('bookValue'),
      ),
      priceToBook: readKeyStatistic('priceToBook'),
      equity: stockholderEquity,
      returnOnAssets: readFinancialData('returnOnAssets'),
      returnOnEquity: readFinancialData('returnOnEquity'),
      totalCash: readFinancialData('totalCash'),
      totalDebt: readFinancialData('totalDebt'),
      debtToEbitda: _computeDebtToEbitda(
        totalDebt: readFinancialData('totalDebt'),
        ebitda: readFinancialData('ebitda'),
      ),
      floatShares: readKeyStatistic('floatShares'),
      trailingPe: readKeyStatistic('trailingPE') ?? readFinancialData('trailingPE'),
      trailingAnnualDividendRate: readSummaryDetail('trailingAnnualDividendRate'),
      trailingAnnualDividendYield: readSummaryDetail('trailingAnnualDividendYield'),
    );
  }

  static double? _computeDebtToEbitda({double? totalDebt, double? ebitda}) {
    if (totalDebt == null || ebitda == null) return null;
    if (ebitda.abs() < 1e-9) return null;
    return totalDebt / ebitda;
  }
}
