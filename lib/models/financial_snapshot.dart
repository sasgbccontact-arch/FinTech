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
    this.enterpriseValue,
    this.enterpriseToEbitda,
    this.enterpriseToRevenue,
    this.revenueGrowth,
    this.earningsGrowth,
    this.operatingCashflow,
    this.capitalExpenditures,
    this.freeCashflow,
    this.capexToRevenue,
    this.freeCashflowYield,
    this.marketCap,
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
    this.netAssets,
    this.expenseRatio,
    this.ytdReturn,
    this.threeYearAverageReturn,
    this.betaThreeYear,
    this.fundCategory,
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
  final double? enterpriseValue;
  final double? enterpriseToEbitda;
  final double? enterpriseToRevenue;
  final double? revenueGrowth;
  final double? earningsGrowth;
  final double? operatingCashflow;
  final double? capitalExpenditures;
  final double? freeCashflow;
  final double? capexToRevenue;
  final double? freeCashflowYield;
  final double? marketCap;
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
  final double? netAssets;
  final double? expenseRatio;
  final double? ytdReturn;
  final double? threeYearAverageReturn;
  final double? betaThreeYear;
  final String? fundCategory;

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
    final price = asMap(summary['price']);
    final summaryDetail = asMap(summary['summaryDetail']);
    final defaultKeyStatistics = asMap(summary['defaultKeyStatistics']);
    final summaryProfile = asMap(summary['summaryProfile']);
    final fundProfile = asMap(summary['fundProfile']);
    final balanceSheetHistory = asMap(summary['balanceSheetHistory']);
    final balanceSheetHistoryQuarterly = asMap(
      summary['balanceSheetHistoryQuarterly'],
    );
    final incomeStatementHistory = asMap(summary['incomeStatementHistory']);
    final incomeStatementHistoryQuarterly = asMap(
      summary['incomeStatementHistoryQuarterly'],
    );
    final cashflowStatementHistory = asMap(summary['cashflowStatementHistory']);
    final cashflowStatementHistoryQuarterly = asMap(
      summary['cashflowStatementHistoryQuarterly'],
    );

    Map<String, dynamic>? firstFromHistory(
      Map<String, dynamic>? history,
      String key,
    ) {
      if (history == null) return null;
      final list = asList(history[key]);
      if (list == null || list.isEmpty) return null;
      return asMap(list.first);
    }

    Map<String, dynamic>? _latestBalanceSheet() {
      final yearly = firstFromHistory(
        balanceSheetHistory,
        'balanceSheetStatements',
      );
      if (yearly != null) return yearly;
      return firstFromHistory(
        balanceSheetHistoryQuarterly,
        'balanceSheetStatements',
      );
    }

    Map<String, dynamic>? _latestIncomeStatement() {
      final yearly = firstFromHistory(
        incomeStatementHistory,
        'incomeStatementHistory',
      );
      if (yearly != null) return yearly;
      return firstFromHistory(
        incomeStatementHistoryQuarterly,
        'incomeStatementHistory',
      );
    }

    Map<String, dynamic>? _latestCashflowStatement() {
      final yearly = firstFromHistory(
        cashflowStatementHistory,
        'cashflowStatements',
      );
      if (yearly != null) return yearly;
      return firstFromHistory(
        cashflowStatementHistoryQuarterly,
        'cashflowStatements',
      );
    }

    List<Map<String, dynamic>> historyEntries(
      Map<String, dynamic>? history,
      String key,
    ) {
      if (history == null) return const <Map<String, dynamic>>[];
      final list = asList(history[key]);
      if (list == null || list.isEmpty) return const <Map<String, dynamic>>[];
      return list.whereType<Map<String, dynamic>>().toList();
    }

    DateTime? readDate(dynamic value) {
      if (value == null) return null;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          value.toInt() * 1000,
          isUtc: true,
        );
      }
      if (value is String) return DateTime.tryParse(value);
      if (value is Map<String, dynamic>) {
        final raw = value['raw'];
        if (raw is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            raw.toInt() * 1000,
            isUtc: true,
          );
        }
      }
      return null;
    }

    double? computeGrowthFromHistory(
      List<Map<String, dynamic>> statements,
      double? Function(Map<String, dynamic>) extractor,
    ) {
      if (statements.length < 2) return null;
      final sorted = List<Map<String, dynamic>>.from(statements)..sort((a, b) {
        final aDate = readDate(a['endDate']);
        final bDate = readDate(b['endDate']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      final values = <double>[];
      for (final statement in sorted) {
        final value = extractor(statement);
        if (value == null) continue;
        values.add(value);
        if (values.length == 2) break;
      }
      if (values.length < 2) return null;
      final latest = values[0];
      final previous = values[1];
      if (previous.abs() < 1e-9) return null;
      return (latest - previous) / previous.abs();
    }

    double? computeFreeCashflow(double? operatingCashflow, double? capex) {
      if (operatingCashflow == null || capex == null) return null;
      return capex < 0 ? operatingCashflow + capex : operatingCashflow - capex;
    }

    final latestBalanceSheet = _latestBalanceSheet();
    final latestIncomeStatement = _latestIncomeStatement();
    final latestCashflowStatement = _latestCashflowStatement();
    final yearlyIncomeStatements = historyEntries(
      incomeStatementHistory,
      'incomeStatementHistory',
    );

    double? readFinancialData(String key) =>
        financialData == null ? null : readNum(financialData[key]);
    double? readPrice(String key) => price == null ? null : readNum(price[key]);
    double? readSummaryDetail(String key) =>
        summaryDetail == null ? null : readNum(summaryDetail[key]);
    double? readKeyStatistic(String key) =>
        defaultKeyStatistics == null
            ? null
            : readNum(defaultKeyStatistics[key]);
    double? readBalanceSheet(String key) =>
        latestBalanceSheet == null ? null : readNum(latestBalanceSheet[key]);
    double? readIncomeStatement(String key) =>
        latestIncomeStatement == null
            ? null
            : readNum(latestIncomeStatement[key]);
    double? readCashflowStatement(String key) =>
        latestCashflowStatement == null
            ? null
            : readNum(latestCashflowStatement[key]);
    String? readFundCategory() {
      final value = fundProfile?["category"] ?? summaryProfile?["category"];
      if (value == null) return null;
      if (value is String) return value.trim();
      if (value is Map<String, dynamic>) {
        final fmt = value['fmt'];
        if (fmt is String) return fmt.trim();
      }
      return value.toString().trim();
    }

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
    final totalLiabilities = readBalanceOrFinancial(
      'totalLiab',
      alternate: 'totalLiabilities',
    );
    final stockholderEquity =
        readBalanceOrFinancial(
          'totalStockholderEquity',
          alternate: 'totalEquityGrossMinorityInterest',
        ) ??
        readBalanceOrFinancial('commonStockEquity');
    final sharesOutstanding =
        readKeyStatistic('sharesOutstanding') ??
        readKeyStatistic('shares') ??
        readFinancialData('sharesOutstanding') ??
        readPrice('sharesOutstanding');
    final marketCap =
        readKeyStatistic('marketCap') ??
        readFinancialData('marketCap') ??
        readPrice('marketCap');
    final operatingCashflow =
        readFinancialData('operatingCashflow') ??
        readCashflowStatement('operatingCashflow') ??
        readCashflowStatement('totalCashFromOperatingActivities');
    final capitalExpenditures =
        readFinancialData('capitalExpenditures') ??
        readCashflowStatement('capitalExpenditures') ??
        readCashflowStatement('capitalExpenditure');
    final freeCashflow =
        readFinancialData('freeCashflow') ??
        computeFreeCashflow(operatingCashflow, capitalExpenditures);
    final revenueGrowth =
        readFinancialData('revenueGrowth') ??
        computeGrowthFromHistory(
          yearlyIncomeStatements,
          (statement) => readNum(statement['totalRevenue']),
        );
    final earningsGrowth =
        readFinancialData('earningsGrowth') ??
        computeGrowthFromHistory(yearlyIncomeStatements, (statement) {
          final directKeys = <String>[
            'dilutedEPS',
            'basicEPS',
            'reportedEPS',
            'epsActual',
            'normalizedDilutedEPS',
          ];
          for (final key in directKeys) {
            final value = readNum(statement[key]);
            if (value != null) return value;
          }
          final netIncome =
              readNum(statement['netIncomeApplicableToCommonShares']) ??
              readNum(statement['netIncome']);
          final shareCount =
              readNum(statement['dilutedAverageShares']) ??
              readNum(statement['basicAverageShares']) ??
              readNum(statement['weightedAverageShsOutDil']) ??
              readNum(statement['weightedAverageShsOut']) ??
              sharesOutstanding;
          if (netIncome == null ||
              shareCount == null ||
              shareCount.abs() < 1e-9) {
            return null;
          }
          return netIncome / shareCount;
        });

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
      revenue:
          readFinancialData('totalRevenue') ??
          readIncomeStatement('totalRevenue'),
      netIncome: readIncomeStatement('netIncome'),
      eps: readFinancialData('eps'),
      ebitda: readFinancialData('ebitda'),
      ebit:
          readIncomeStatement('ebit') ??
          readIncomeStatement('operatingIncome') ??
          readFinancialData('ebit') ??
          readFinancialData('operatingIncome'),
      operatingMargin: readFinancialData('operatingMargins'),
      netMargin: readFinancialData('profitMargins'),
      dividendYield:
          readSummaryDetail('dividendYield') ??
          readFinancialData('dividendYield'),
      payoutRatio: readSummaryDetail('payoutRatio'),
      pegRatio:
          readKeyStatistic('pegRatio') ??
          readFinancialData('pegRatio') ??
          readSummaryDetail('pegRatio'),
      enterpriseValue:
          readFinancialData('enterpriseValue') ??
          readKeyStatistic('enterpriseValue') ??
          readSummaryDetail('enterpriseValue'),
      enterpriseToEbitda:
          readFinancialData('enterpriseToEbitda') ??
          readKeyStatistic('enterpriseToEbitda') ??
          readSummaryDetail('enterpriseToEbitda'),
      enterpriseToRevenue:
          readFinancialData('enterpriseToRevenue') ??
          readKeyStatistic('enterpriseToRevenue') ??
          readSummaryDetail('enterpriseToRevenue'),
      revenueGrowth: revenueGrowth,
      earningsGrowth: earningsGrowth,
      operatingCashflow: operatingCashflow,
      capitalExpenditures: capitalExpenditures,
      freeCashflow: freeCashflow,
      capexToRevenue: _computeCapexToRevenue(
        revenue:
            readFinancialData('totalRevenue') ??
            readIncomeStatement('totalRevenue'),
        capex: capitalExpenditures,
      ),
      freeCashflowYield: _computeFcfYield(
        freeCashflow: freeCashflow,
        marketCap: marketCap,
      ),
      marketCap: marketCap,
      bookValuePerShare:
          readKeyStatistic('bookValue') ?? readFinancialData('bookValue'),
      bookValue: computeBookValue(
        readKeyStatistic('bookValue') ?? readFinancialData('bookValue'),
      ),
      priceToBook: readKeyStatistic('priceToBook'),
      equity: stockholderEquity,
      returnOnAssets: readFinancialData('returnOnAssets'),
      returnOnEquity: readFinancialData('returnOnEquity'),
      totalCash:
          readFinancialData('totalCash') ??
          readBalanceSheet('cash') ??
          readBalanceSheet('cashAndCashEquivalents'),
      totalDebt:
          readFinancialData('totalDebt') ??
          readBalanceSheet('totalDebt') ??
          readBalanceSheet('longTermDebt'),
      debtToEbitda: _computeDebtToEbitda(
        totalDebt:
            readFinancialData('totalDebt') ??
            readBalanceSheet('totalDebt') ??
            readBalanceSheet('longTermDebt'),
        ebitda:
            readFinancialData('ebitda') ??
            readIncomeStatement('ebitda') ??
            readIncomeStatement('operatingIncome'),
      ),
      floatShares: readKeyStatistic('floatShares'),
      trailingPe:
          readKeyStatistic('trailingPE') ??
          readFinancialData('trailingPE') ??
          readSummaryDetail('trailingPE') ??
          readPrice('trailingPE'),
      trailingAnnualDividendRate: readSummaryDetail(
        'trailingAnnualDividendRate',
      ),
      trailingAnnualDividendYield: readSummaryDetail(
        'trailingAnnualDividendYield',
      ),
      netAssets: readSummaryDetail('netAssets'),
      expenseRatio:
          readSummaryDetail('annualReportExpenseRatio') ??
          readSummaryDetail('managementExpenseRatio'),
      ytdReturn:
          readSummaryDetail('ytdReturn') ?? readFinancialData('ytdReturn'),
      threeYearAverageReturn:
          readSummaryDetail('threeYearAverageReturn') ??
          readFinancialData('threeYearAverageReturn'),
      betaThreeYear:
          readKeyStatistic('beta3Year') ?? readSummaryDetail('beta3Year'),
      fundCategory: readFundCategory(),
    );
  }

  static double? _computeDebtToEbitda({double? totalDebt, double? ebitda}) {
    if (totalDebt == null || ebitda == null) return null;
    if (ebitda.abs() < 1e-9) return null;
    return totalDebt / ebitda;
  }

  static double? _computeCapexToRevenue({double? revenue, double? capex}) {
    if (revenue == null || capex == null || revenue.abs() < 1e-9) return null;
    return capex / revenue;
  }

  static double? _computeFcfYield({double? freeCashflow, double? marketCap}) {
    if (freeCashflow == null || marketCap == null || marketCap.abs() < 1e-9)
      return null;
    return freeCashflow / marketCap;
  }
}
