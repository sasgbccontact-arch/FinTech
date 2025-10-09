import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/services/yahoo_finance_service.dart' show QuoteDetail;

enum DecisionValueType { currency, percent, ratio, quantity, text }

const Map<String, String> _indicatorDefinitions = {
  'revenue': 'Définition chiffre d\'affaires à renseigner.',
  'net_income': 'Définition résultat net à renseigner.',
  'eps': 'Définition BNA à renseigner.',
  'ebitda': 'Définition EBITDA à renseigner.',
  'ebit': 'Définition EBIT à renseigner.',
  'operating_margin': 'Définition marge d\'exploitation à renseigner.',
  'net_margin': 'Définition marge nette à renseigner.',
  'dividend_yield': 'Définition rendement à renseigner.',
  'dividend_history': 'Définition historique dividende à renseigner.',
  'payout_ratio': 'Définition taux de distribution à renseigner.',
  'per': 'Définition PER à renseigner.',
  'peg': 'Définition PEG à renseigner.',
  'book_value': 'Définition book value à renseigner.',
  'bvps': 'Définition BVPS à renseigner.',
  'intrinsic_value': 'Définition valeur intrinsèque à renseigner.',
  'pbr': 'Définition PBR à renseigner.',
  'equity': 'Définition capitaux propres à renseigner.',
  'roa': 'Définition ROA à renseigner.',
  'roe': 'Définition ROE à renseigner.',
  'cash_debt': 'Définition trésorerie/dette à renseigner.',
  'leverage': 'Définition levier financier à renseigner.',
  'float_shares': 'Définition actions flottantes à renseigner.',
};

class DecisionIndicator {
  DecisionIndicator({
    required this.id,
    required this.title,
    required this.valueType,
    this.value,
    this.secondaryValue,
    this.secondaryLabel,
    this.primaryLabel,
    this.customDisplay,
    this.definition = 'Définition ici',
    this.secondaryEmphasis = false,
  });

  final String id;
  final String title;
  final DecisionValueType valueType;
  final double? value;
  final double? secondaryValue;
  final String? secondaryLabel;
  final String? primaryLabel;
  final String? customDisplay;
  final String definition;
  final bool secondaryEmphasis;

  bool get hasPrimaryValue => value != null;
  bool get hasSecondaryValue => secondaryValue != null;
  bool get hasCustomDisplay => customDisplay != null && customDisplay!.isNotEmpty;
}

List<DecisionIndicator> buildDecisionIndicators(
  QuoteDetail? quote,
  FinancialSnapshot? snapshot,
) {
  final indicators = <DecisionIndicator>[];

  bool _isPlaceholder(String? text) {
    if (text == null) return false;
    final normalized = text.trim().toLowerCase();
    return normalized == 'donnée manquante';
  }

  void addIfAvailable(DecisionIndicator indicator) {
    final hasPrimary = indicator.hasPrimaryValue;
    final hasSecondary = indicator.hasSecondaryValue;
    final hasCustom = indicator.hasCustomDisplay && !_isPlaceholder(indicator.customDisplay);
    if (!hasPrimary && !hasSecondary && !hasCustom) return;
    indicators.add(indicator);
  }

  double? eps = quote?.epsTrailingTwelveMonths ?? snapshot?.eps;
  addIfAvailable(
    DecisionIndicator(
      id: 'revenue',
      title: 'Chiffre d\'affaires',
      valueType: DecisionValueType.currency,
      value: snapshot?.revenue,
      definition: _indicatorDefinitions['revenue']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'net_income',
      title: 'Résultat net',
      valueType: DecisionValueType.currency,
      value: snapshot?.netIncome,
      definition: _indicatorDefinitions['net_income']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'eps',
      title: 'Bénéfice net par action (BNA)',
      valueType: DecisionValueType.currency,
      value: eps,
      definition: _indicatorDefinitions['eps']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'ebitda',
      title: 'EBITDA',
      valueType: DecisionValueType.currency,
      value: snapshot?.ebitda,
      definition: _indicatorDefinitions['ebitda']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'ebit',
      title: 'EBIT',
      valueType: DecisionValueType.currency,
      value: snapshot?.ebit,
      definition: _indicatorDefinitions['ebit']!,
    ),
  );

  final operatingMargin = snapshot?.operatingMargin;
  addIfAvailable(
    DecisionIndicator(
      id: 'operating_margin',
      title: 'Marge d\'exploitation',
      valueType: DecisionValueType.percent,
      value: operatingMargin != null ? operatingMargin * 100 : null,
      definition: _indicatorDefinitions['operating_margin']!,
    ),
  );

  final netMargin = snapshot?.netMargin;
  addIfAvailable(
    DecisionIndicator(
      id: 'net_margin',
      title: 'Marge nette',
      valueType: DecisionValueType.percent,
      value: netMargin != null ? netMargin * 100 : null,
      definition: _indicatorDefinitions['net_margin']!,
    ),
  );

  final dividendYield =
      snapshot?.dividendYield ?? quote?.dividendYield;
  addIfAvailable(
    DecisionIndicator(
      id: 'dividend_yield',
      title: 'Rendement',
      valueType: DecisionValueType.percent,
      value: dividendYield != null ? dividendYield * 100 : null,
      definition: _indicatorDefinitions['dividend_yield']!,
    ),
  );

  final payoutRatio = snapshot?.payoutRatio;
  addIfAvailable(
    DecisionIndicator(
      id: 'payout_ratio',
      title: 'Taux de distribution',
      valueType: DecisionValueType.percent,
      value: payoutRatio != null ? payoutRatio * 100 : null,
      definition: _indicatorDefinitions['payout_ratio']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'per',
      title: 'PER (TTM)',
      valueType: DecisionValueType.ratio,
      value: quote?.trailingPE ?? snapshot?.trailingPe,
      definition: _indicatorDefinitions['per']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'peg',
      title: 'PEG',
      valueType: DecisionValueType.ratio,
      value: snapshot?.pegRatio,
      definition: _indicatorDefinitions['peg']!,
    ),
  );

  final bookValueAbsolute = snapshot?.bookValue;
  addIfAvailable(
    DecisionIndicator(
      id: 'book_value',
      title: 'Book Value',
      valueType: DecisionValueType.currency,
      value: bookValueAbsolute,
      definition: _indicatorDefinitions['book_value']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'bvps',
      title: 'BVPS',
      valueType: DecisionValueType.currency,
      value: snapshot?.bookValuePerShare,
      definition: _indicatorDefinitions['bvps']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'pbr',
      title: 'PBR',
      valueType: DecisionValueType.ratio,
      value: snapshot?.priceToBook,
      definition: _indicatorDefinitions['pbr']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'equity',
      title: 'Capitaux propres',
      valueType: DecisionValueType.currency,
      value: snapshot?.equity,
      definition: _indicatorDefinitions['equity']!,
    ),
  );

  final returnOnAssets = snapshot?.returnOnAssets;
  addIfAvailable(
    DecisionIndicator(
      id: 'roa',
      title: 'ROA',
      valueType: DecisionValueType.percent,
      value: returnOnAssets != null ? returnOnAssets * 100 : null,
      definition: _indicatorDefinitions['roa']!,
    ),
  );

  final returnOnEquity = snapshot?.returnOnEquity;
  addIfAvailable(
    DecisionIndicator(
      id: 'roe',
      title: 'ROE',
      valueType: DecisionValueType.percent,
      value: returnOnEquity != null ? returnOnEquity * 100 : null,
      definition: _indicatorDefinitions['roe']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'cash_debt',
      title: 'Trésorerie et dettes',
      valueType: DecisionValueType.currency,
      value: snapshot?.totalCash,
      secondaryValue: snapshot?.totalDebt,
      primaryLabel: 'Trésorerie',
      secondaryLabel: 'Dettes',
      secondaryEmphasis: true,
      definition: _indicatorDefinitions['cash_debt']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'leverage',
      title: 'Levier financier',
      valueType: DecisionValueType.ratio,
      value: snapshot?.debtToEbitda,
      definition: _indicatorDefinitions['leverage']!,
    ),
  );

  addIfAvailable(
    DecisionIndicator(
      id: 'float_shares',
      title: 'Actions flottantes',
      valueType: DecisionValueType.quantity,
      value: snapshot?.floatShares,
      definition: _indicatorDefinitions['float_shares']!,
    ),
  );

  return indicators;
}
