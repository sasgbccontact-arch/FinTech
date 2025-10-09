import 'dart:math' as math;

import 'package:fintech/core/constants.dart';
import 'package:fintech/models/chart_models.dart';
import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/news_models.dart';
import 'package:fintech/services/yahoo_finance_service.dart';
import 'package:fintech/utils/decision_indicators.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// InfoPage
/// Affiche les informations clés d'une action sélectionnée dans la recherche.
class InfoPage extends StatefulWidget {
  const InfoPage({
    super.key,
    this.ticker,
    this.initialName,
    this.initialExchange,
    this.initialCurrency,
  });

  final String? ticker;
  final String? initialName;
  final String? initialExchange;
  final String? initialCurrency;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String? _ticker;
  String? _displayName;
  String? _exchange;
  String? _currency;

  QuoteDetail? _quote;
  bool _loading = true;
  String? _error;
  bool _hasRequested = false;
  ChartInterval _selectedInterval = ChartInterval.oneDay;
  List<HistoricalPoint> _chartPoints = const <HistoricalPoint>[];
  bool _chartLoading = true;
  String? _chartError;
  int _chartRequestId = 0;
  FinancialSnapshot? _financialSnapshot;
  bool _financialLoading = true;
  String? _financialError;
  int _financialRequestId = 0;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<FinanceNewsItem> _newsItems = const <FinanceNewsItem>[];
  bool _newsLoading = true;
  String? _newsError;
  int _newsRequestId = 0;
  _PeriodDelta? _periodDelta;
  static const List<String> _shortMonths = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  @override
  void initState() {
    super.initState();
    _displayName = widget.initialName;
    _exchange = widget.initialExchange;
    _currency = widget.initialCurrency;
  }

  Widget _buildEssentialPage({
    required ThemeData theme,
    required String? priceText,
    required String? changeText,
    required String? percentText,
    required bool changePositive,
    required String periodLabel,
    required String? lastUpdate,
    required List<_MetricEntry> essentialMetrics,
  }) {
    final variationTexts = <String>[
      if (changeText != null) changeText,
      if (percentText != null) percentText,
    ];

    return ListView(
      key: const PageStorageKey<String>('overview_page'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName ?? _ticker ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _exchange ?? '—',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (variationTexts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: changePositive
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      periodLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      variationTexts.join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: changePositive
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              priceText ?? '—',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (lastUpdate != null) ...[
          const SizedBox(height: 6),
          Text(
            'Dernière mise à jour: $lastUpdate',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
        const SizedBox(height: 24),
        _QuoteChartSection(
          points: _chartPoints,
          loading: _chartLoading,
          error: _chartError,
          interval: _selectedInterval,
          onIntervalSelected: (value) => _loadChartData(interval: value),
          labelBuilder: _formatChartTick,
          currencyFormatter: _formatCurrency,
        ),
        if (essentialMetrics.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionHeader(label: 'Indicateurs essentiels'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                essentialMetrics
                    .map(
                      (metric) => _MetricCard(
                        title: metric.title,
                        value: metric.value,
                        subtitle: metric.subtitle,
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_ticker == null) {
      if (widget.ticker != null && widget.ticker!.trim().isNotEmpty) {
        _ticker = widget.ticker!.trim();
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map) {
          final rawTicker = args['ticker'] ?? args['symbol'];
          if (rawTicker is String && rawTicker.trim().isNotEmpty) {
            _ticker = rawTicker.trim();
          }
          final rawName = args['name'];
          if (rawName is String && rawName.trim().isNotEmpty) {
            _displayName ??= rawName.trim();
          }
          final rawExchange = args['exchange'];
          if (rawExchange is String && rawExchange.trim().isNotEmpty) {
            _exchange ??= rawExchange.trim();
          }
          final rawCurrency = args['currency'];
          if (rawCurrency is String && rawCurrency.trim().isNotEmpty) {
            _currency ??= rawCurrency.trim();
          }
        }
      }
    }

    if (!_hasRequested) {
      _hasRequested = true;
      final symbol = _ticker?.trim();
      if (symbol == null || symbol.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Aucun ticker fourni.';
        });
      } else {
        _fetchQuote(symbol);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuote(String symbol) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final quote = await YahooFinanceService.fetchQuote(symbol);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
        _displayName = _resolveDisplayName(quote);
        _exchange = _resolveExchange(quote);
        _currency = _resolveCurrency(quote);
        _currentPage = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _loadChartData();
      _loadFinancialSnapshot();
      _loadNews();
    } on QuoteNotFoundException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    } on FinanceRequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Une erreur est survenue. ${e.toString()}';
      });
    }
  }

  Future<void> _loadChartData({ChartInterval? interval}) async {
    final symbol = _ticker;
    if (symbol == null || symbol.isEmpty) return;

    final targetInterval = interval ?? _selectedInterval;
    final requestId = ++_chartRequestId;

    setState(() {
      if (interval != null) {
        _selectedInterval = interval;
      }
      _chartLoading = true;
      _chartError = null;
    });

    try {
      final points = await YahooFinanceService.fetchHistoricalSeries(
        symbol,
        targetInterval,
      );
      assert(() {
        debugPrint(
          '[InfoPage] Received ${points.length} chart point(s) for ' +
              '$symbol @ ${targetInterval.shortLabel}',
        );
        return true;
      }());

      if (!mounted || requestId != _chartRequestId) return;
      setState(() {
        _chartPoints = points;
        _chartLoading = false;
        _chartError = points.isEmpty ? 'Données indisponibles.' : null;
        _periodDelta = _computePeriodDelta(points);
      });
    } on FinanceRequestException catch (e) {
      if (!mounted || requestId != _chartRequestId) return;
      setState(() {
        _chartLoading = false;
        _chartError =
            e.message == 'consent_required'
                ? 'Consentement nécessaire pour afficher le graphique.'
                : e.message;
        _periodDelta = null;
      });
    } catch (e) {
      if (!mounted || requestId != _chartRequestId) return;
      setState(() {
        _chartLoading = false;
        _chartError = 'Erreur graphique: ${e.toString()}';
        _periodDelta = null;
      });
    }
  }

  Future<void> _loadFinancialSnapshot() async {
    final symbol = _ticker;
    if (symbol == null || symbol.isEmpty) return;

    final requestId = ++_financialRequestId;
    setState(() {
      _financialLoading = true;
      _financialError = null;
    });

    try {
      final snapshot = await YahooFinanceService.fetchFinancialSnapshot(symbol);
      if (!mounted || requestId != _financialRequestId) return;
      setState(() {
        _financialSnapshot = snapshot;
        _financialLoading = false;
        _financialError = null;
      });
    } on FinanceRequestException catch (e) {
      if (!mounted || requestId != _financialRequestId) return;
      setState(() {
        _financialLoading = false;
        _financialError = e.message;
        _financialSnapshot = null;
      });
    } catch (e) {
      if (!mounted || requestId != _financialRequestId) return;
      setState(() {
        _financialLoading = false;
        _financialError = 'Erreur financières: ${e.toString()}';
        _financialSnapshot = null;
      });
    }
  }

  _PeriodDelta? _computePeriodDelta(List<HistoricalPoint> points) {
    if (points.length < 2) return null;
    final start = points.first.close;
    final end = points.last.close;
    if (start.isNaN || end.isNaN) return null;
    final change = end - start;
    final percent = start.abs() < 1e-9 ? null : (change / start) * 100;
    if (percent == null) {
      return _PeriodDelta(start: start, end: end, change: change, percent: 0);
    }
    return _PeriodDelta(start: start, end: end, change: change, percent: percent);
  }

  Future<void> _loadNews() async {
    final symbol = _ticker;
    if (symbol == null || symbol.isEmpty) {
      setState(() {
        _newsItems = const <FinanceNewsItem>[];
        _newsLoading = false;
        _newsError = 'Aucun ticker fourni.';
      });
      return;
    }

    final requestId = ++_newsRequestId;
    setState(() {
      _newsLoading = true;
      _newsError = null;
    });

    try {
      final aliasCandidates = <String?>{
        symbol,
        _displayName,
        _quote?.longName,
        _quote?.shortName,
        _quote?.symbol,
      };
      final aliases = aliasCandidates
          .where((value) => (value?.trim().isNotEmpty ?? false))
          .map((value) => value!.trim())
          .toList();

      final items = await YahooFinanceService.fetchCompanyNews(
        symbol,
        aliases: aliases,
      );
      assert(() {
        debugPrint(
          '[InfoPage] Received ${items.length} news item(s) for ' + symbol,
        );
        return true;
      }());
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _newsItems = items;
        _newsLoading = false;
        _newsError = null;
      });
    } on FinanceRequestException catch (e) {
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _newsLoading = false;
        _newsError = e.message;
        _newsItems = const <FinanceNewsItem>[];
      });
    } catch (e) {
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _newsLoading = false;
        _newsError = 'Erreur actualités: ${e.toString()}';
        _newsItems = const <FinanceNewsItem>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_ticker ?? 'Info'),
        centerTitle: false,
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null)
                  ? _ErrorView(
                    key: const ValueKey('error'),
                    message: _error!,
                    onRetry:
                        _ticker == null ? null : () => _fetchQuote(_ticker!),
                  )
                  : _buildQuoteView(theme),
        ),
      ),
    );
  }

  Future<void> _openNewsLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien invalide.')),
      );
      return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la news.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la news.')),
      );
    }
  }

  Widget _buildQuoteView(ThemeData theme) {
    final quote = _quote;
    final priceText = _formatCurrency(quote?.regularMarketPrice);
    final delta = _periodDelta;
    final changeValue = delta?.change ?? quote?.regularMarketChange;
    final changePercentValue =
        delta?.percent ?? quote?.regularMarketChangePercent;
    final changeText =
        changeValue != null ? _formatSignedCurrency(changeValue) : null;
    final percentText =
        changePercentValue != null ? _formatPercent(changePercentValue) : null;
    final changeAnchor = changeValue ?? quote?.regularMarketChange ?? 0;
    final changePositive = changeAnchor >= 0;
    final periodLabel = 'Var. ${_selectedInterval.shortLabel}';
    final lastUpdate = _formatDateTime(quote?.regularMarketTime);

    final metrics = quote == null ? <_MetricEntry>[] : _buildMetrics(quote);
    const essentialTitles = <String>{
      'Capitalisation',
      'PER (TTM)',
      'Volume',
      'Rdt dividende',
      'Devise',
    };
    final essentialMetrics = <_MetricEntry>[];
    final complementaryMetrics = <_MetricEntry>[];
    for (final metric in metrics) {
      if (essentialTitles.contains(metric.title) &&
          essentialMetrics.every((entry) => entry.title != metric.title)) {
        essentialMetrics.add(metric);
      } else {
        complementaryMetrics.add(metric);
      }
    }

    final decisionIndicators =
        buildDecisionIndicators(quote, _financialSnapshot);

    final overview = _buildEssentialPage(
      theme: theme,
      priceText: priceText,
      changeText: changeText,
      percentText: percentText,
      changePositive: changePositive,
      periodLabel: periodLabel,
      lastUpdate: lastUpdate,
      essentialMetrics: essentialMetrics,
    );

    final extraPage = _buildExtraIndicatorsPage(
      theme,
      complementaryMetrics,
      decisionIndicators,
    );

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const PageScrollPhysics(),
            onPageChanged: (index) {
              if (_currentPage != index && mounted) {
                setState(() => _currentPage = index);
              }
            },
            children: [
              overview,
              extraPage,
              _buildNewsPage(theme),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PageIndicator(count: 3, currentIndex: _currentPage),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildExtraIndicatorsPage(
    ThemeData theme,
    List<_MetricEntry> complementaryMetrics,
    List<DecisionIndicator> decisionIndicators,
  ) {
    final showDecisionLoading = _financialLoading && _financialSnapshot == null;
    final showDecisionError =
        _financialError != null && !_financialLoading && _financialSnapshot == null;

    final children = <Widget>[];

    if (complementaryMetrics.isNotEmpty) {
      children
        ..add(_SectionHeader(label: 'Indicateurs complémentaires'))
        ..add(const SizedBox(height: 12))
        ..add(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                complementaryMetrics
                    .map(
                      (metric) => _MetricCard(
                        title: metric.title,
                        value: metric.value,
                        subtitle: metric.subtitle,
                      ),
                    )
                    .toList(),
          ),
        )
        ..add(const SizedBox(height: 24));
    }

    children.add(_SectionHeader(label: 'Indicateurs décisionnels'));
    children.add(const SizedBox(height: 12));

    if (showDecisionLoading) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else {
      if (showDecisionError) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _financialError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        );
      }

      for (final indicator in decisionIndicators) {
        final primaryText = _renderIndicatorValue(indicator);
        final secondaryText = _renderIndicatorSecondary(indicator);
        children.add(
          _DecisionIndicatorCard(
            indicator: indicator,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onTap: () => _showIndicatorDefinition(indicator),
          ),
        );
        children.add(const SizedBox(height: 12));
      }
    }

    if (children.isNotEmpty && children.last is SizedBox) {
      children.removeLast();
    }

    return ListView(
      key: const PageStorageKey<String>('extra_page'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  String _renderIndicatorValue(DecisionIndicator indicator) {
    if (indicator.hasCustomDisplay) {
      return indicator.customDisplay!;
    }
    final formatted = _formatDecisionNumeric(indicator.value, indicator.valueType);
    if (formatted == null) return 'Donnée manquante';
    if (indicator.primaryLabel != null) {
      return '${indicator.primaryLabel}: $formatted';
    }
    return formatted;
  }

  String? _renderIndicatorSecondary(DecisionIndicator indicator) {
    if (!indicator.hasSecondaryValue) return null;
    final formatted = _formatDecisionNumeric(indicator.secondaryValue, indicator.valueType);
    if (formatted == null) return null;
    final label = indicator.secondaryLabel ?? 'Valeur 2';
    return '$label: $formatted';
  }

  String? _formatDecisionNumeric(double? value, DecisionValueType type) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    switch (type) {
      case DecisionValueType.currency:
        return _formatCurrency(value, withSeparators: true);
      case DecisionValueType.percent:
        return _formatPercent(value);
      case DecisionValueType.ratio:
        return _formatNumber(value, fractionDigits: 2);
      case DecisionValueType.quantity:
        return _formatLargeNumber(value);
      case DecisionValueType.text:
        return value.toString();
    }
  }

  void _showIndicatorDefinition(DecisionIndicator indicator) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indicator.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                indicator.definition,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsPage(ThemeData theme) {
    if (_newsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_newsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _newsError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadNews,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_newsItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucune actualité disponible.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('news_page'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _newsItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _newsItems[index];
        final published = _formatDateTime(item.publishedAt);
        return _NewsArticleCard(
          article: item,
          subtitle: published == null
              ? item.publisher
              : '${item.publisher} • $published',
          onTap: () => _openNewsLink(item.url),
        );
      },
    );
  }

  String _resolveDisplayName(QuoteDetail quote) {
    final candidates = [
      quote.longName,
      quote.shortName,
      _displayName,
      quote.symbol,
      _ticker,
    ];
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return quote.symbol;
  }

  String? _resolveExchange(QuoteDetail quote) {
    final candidates = [quote.fullExchangeName, quote.exchange, _exchange];
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _resolveCurrency(QuoteDetail quote) {
    final candidates = [quote.currency, _currency];
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  List<_MetricEntry> _buildMetrics(QuoteDetail quote) {
    final metrics = <_MetricEntry?>[
      if (_currency != null && _currency!.isNotEmpty)
        _MetricEntry('Devise', _currency!),
      if (quote.previousClose != null)
        _MetricEntry('Clôture préc.', _formatCurrency(quote.previousClose)),
      if (quote.open != null)
        _MetricEntry('Ouverture', _formatCurrency(quote.open)),
      if (quote.regularMarketDayHigh != null)
        _MetricEntry(
          'Plus haut jour',
          _formatCurrency(quote.regularMarketDayHigh),
        ),
      if (quote.regularMarketDayLow != null)
        _MetricEntry(
          'Plus bas jour',
          _formatCurrency(quote.regularMarketDayLow),
        ),
      if (quote.fiftyTwoWeekHigh != null)
        _MetricEntry(
          'Plus haut 52 sem.',
          _formatCurrency(quote.fiftyTwoWeekHigh),
        ),
      if (quote.fiftyTwoWeekLow != null)
        _MetricEntry(
          'Plus bas 52 sem.',
          _formatCurrency(quote.fiftyTwoWeekLow),
        ),
      if (quote.marketCap != null)
        _MetricEntry(
          'Capitalisation',
          _formatLargeNumber(quote.marketCap),
          _formatCurrency(quote.marketCap, withSeparators: true),
        ),
      if (quote.regularMarketVolume != null)
        _MetricEntry(
          'Volume',
          _formatLargeNumber(quote.regularMarketVolume),
          _formatInteger(quote.regularMarketVolume),
        ),
      if (quote.averageDailyVolume3Month != null)
        _MetricEntry(
          'Volume moyen 3m',
          _formatLargeNumber(quote.averageDailyVolume3Month),
          _formatInteger(quote.averageDailyVolume3Month),
        ),
      if (quote.trailingPE != null)
        _MetricEntry(
          'PER (TTM)',
          _formatNumber(quote.trailingPE, fractionDigits: 2),
        ),
      if (quote.forwardPE != null)
        _MetricEntry(
          'PER (forward)',
          _formatNumber(quote.forwardPE, fractionDigits: 2),
        ),
      if (quote.epsTrailingTwelveMonths != null)
        _MetricEntry(
          'BPA (TTM)',
          _formatCurrency(quote.epsTrailingTwelveMonths),
        ),
      if (quote.dividendYield != null)
        _MetricEntry(
          'Rdt dividende',
          _formatPercent(quote.dividendYield! * 100),
        ),
    ];

    return metrics.whereType<_MetricEntry>().toList();
  }

  String? _formatCurrency(double? value, {bool withSeparators = false}) {
    if (value == null) return null;
    final sign = value < 0 ? '-' : '';
    final absValue = value.abs();
    final digits = absValue >= 1 ? 2 : 4;
    String amount = absValue.toStringAsFixed(digits);
    if (withSeparators) {
      amount = _formatWithThinSpaces(amount);
    }
    final symbol = _currencySymbol(_currency);
    if (symbol != null) {
      return '$sign$symbol$amount';
    }
    final suffix =
        _currency != null && _currency!.isNotEmpty ? ' ${_currency!}' : '';
    return '$sign$amount$suffix'.trim();
  }

  String? _formatSignedCurrency(double? value) {
    if (value == null) return null;
    if (value == 0) return _formatCurrency(0);
    final formatted = _formatCurrency(value.abs());
    if (formatted == null) return null;
    final prefix = value > 0 ? '+' : '-';
    return '$prefix$formatted';
  }

  String? _formatPercent(double? value) {
    if (value == null) return null;
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  String? _formatNumber(double? value, {int fractionDigits = 2}) {
    if (value == null) return null;
    return value.toStringAsFixed(fractionDigits);
  }

  String? _formatLargeNumber(double? value) {
    if (value == null) return null;
    double reduced = value;
    int unitIndex = 0;
    const units = ['', ' K', ' M', ' B', ' T'];
    while (reduced.abs() >= 1000 && unitIndex < units.length - 1) {
      reduced /= 1000;
      unitIndex++;
    }
    final digits = reduced.abs() >= 100 ? 1 : 2;
    return '${reduced.toStringAsFixed(digits)}${units[unitIndex]}';
  }

  String? _formatInteger(double? value) {
    if (value == null) return null;
    final rounded = value.round();
    final string = rounded.toString();
    return string.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  }

  String _formatWithThinSpaces(String value) {
    final parts = value.split('.');
    final integer = parts.first;
    final formattedInt = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    if (parts.length == 1) {
      return formattedInt;
    }
    return '$formattedInt.${parts[1]}';
  }

  String _formatChartTick(DateTime dt, ChartInterval interval) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    if (interval == ChartInterval.oneDay) {
      return '${two(local.hour)}:${two(local.minute)}';
    }
    final month = _shortMonths[local.month - 1];
    final includeDay =
        interval != ChartInterval.fiveYears && interval != ChartInterval.max;
    final includeYear =
        interval == ChartInterval.fiveYears ||
        interval == ChartInterval.max ||
        local.year != DateTime.now().year;
    final buffer = StringBuffer();
    if (includeDay) {
      buffer
        ..write(local.day)
        ..write(' ');
    }
    buffer.write(month);
    if (includeYear) {
      buffer
        ..write(' ')
        ..write(local.year);
    }
    return buffer.toString();
  }

  String? _formatDateTime(DateTime? dt) {
    if (dt == null) return null;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String? _currencySymbol(String? currency) {
    if (currency == null || currency.isEmpty) return null;
    switch (currency.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return r'$';
      case 'GBP':
        return '£';
      case 'CHF':
        return 'CHF ';
      case 'CAD':
        return r'C$';
      case 'JPY':
        return '¥';
    }
    return null;
  }
}

class _QuoteChartSection extends StatelessWidget {
  const _QuoteChartSection({
    required this.points,
    required this.loading,
    required this.error,
    required this.interval,
    required this.onIntervalSelected,
    required this.labelBuilder,
    required this.currencyFormatter,
  });

  final List<HistoricalPoint> points;
  final bool loading;
  final String? error;
  final ChartInterval interval;
  final ValueChanged<ChartInterval> onIntervalSelected;
  final String Function(DateTime, ChartInterval) labelBuilder;
  final String? Function(double?) currencyFormatter;

  static const List<ChartInterval> _intervals = <ChartInterval>[
    ChartInterval.oneDay,
    ChartInterval.sevenDays,
    ChartInterval.oneMonth,
    ChartInterval.sixMonths,
    ChartInterval.yearToDate,
    ChartInterval.fiveYears,
    ChartInterval.max,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = points.isNotEmpty;
    final startPoint = hasData ? points.first : null;
    final endPoint = hasData ? points.last : null;
    final rising = hasData && endPoint!.close >= startPoint!.close;
    final lineColor =
        hasData
            ? (rising ? Colors.green.shade600 : Colors.red.shade600)
            : theme.colorScheme.primary;
    final fillColor = lineColor.withOpacity(0.18);
    final startLabel =
        startPoint != null ? labelBuilder(startPoint.time, interval) : '—';
    final endLabel =
        endPoint != null ? labelBuilder(endPoint.time, interval) : '—';
    final startPrice =
        startPoint != null ? (currencyFormatter(startPoint.close) ?? '—') : '—';
    final endPrice =
        endPoint != null ? (currencyFormatter(endPoint.close) ?? '—') : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Évolution du cours',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children:
                  _intervals.map((ChartInterval option) {
                    final bool selected = option == interval;
                    return ChoiceChip(
                      label: Text(option.shortLabel),
                      selected: selected,
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: Colors.grey.shade200,
                      onSelected: (bool value) {
                        if (value && option != interval) {
                          onIntervalSelected(option);
                        }
                      },
                      pressElevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child:
                loading
                    ? const Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    )
                    : error != null
                    ? Center(
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                    : hasData
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _MinimalLineChart(
                        points: points,
                        lineColor: lineColor,
                        fillColor: fillColor,
                      ),
                    )
                    : Center(
                      child: Text(
                        'Aucune donnée disponible.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
          ),
          if (!loading && error == null && hasData) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _ChartLegend(
                  label: startLabel,
                  value: startPrice,
                  alignment: CrossAxisAlignment.start,
                ),
                _ChartLegend(
                  label: endLabel,
                  value: endPrice,
                  alignment: CrossAxisAlignment.end,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.label,
    required this.value,
    required this.alignment,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MinimalLineChart extends StatelessWidget {
  const _MinimalLineChart({
    required this.points,
    required this.lineColor,
    required this.fillColor,
  });

  final List<HistoricalPoint> points;
  final Color lineColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MinimalLineChartPainter(
        points: points,
        lineColor: lineColor,
        fillColor: fillColor,
      ),
      // SizedBox.expand ensures the painter receives the full allocated space.
      child: const SizedBox.expand(),
    );
  }
}

class _MinimalLineChartPainter extends CustomPainter {
  _MinimalLineChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
  });

  final List<HistoricalPoint> points;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final Paint axisPaint =
          Paint()
            ..color = lineColor.withOpacity(0.35)
            ..strokeWidth = 1.5;
      final double mid = size.height / 2;
      canvas.drawLine(Offset(0, mid), Offset(size.width, mid), axisPaint);
      return;
    }

    final List<double> values =
        points.map((HistoricalPoint p) => p.close).toList();
    double minY = values.reduce(math.min);
    double maxY = values.reduce(math.max);
    if ((maxY - minY).abs() < 1e-6) {
      final double delta = maxY.abs() * 0.02 + 1;
      minY -= delta;
      maxY += delta;
    }
    final double range = maxY - minY;

    final Path linePath = Path();
    final Path fillPath = Path();
    Offset? lastPoint;

    for (int i = 0; i < points.length; i++) {
      final double t = points.length == 1 ? 0 : i / (points.length - 1);
      final double x = t * size.width;
      final double normalized = (points[i].close - minY) / range;
      final double y = size.height - (normalized * size.height);
      final Offset current = Offset(x, y);
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      lastPoint = current;
    }

    if (lastPoint != null) {
      fillPath
        ..lineTo(lastPoint.dx, size.height)
        ..close();
    }

    final Paint gridPaint =
        Paint()
          ..color = lineColor.withOpacity(0.08)
          ..strokeWidth = 1;
    for (final double fraction in <double>[0.25, 0.5, 0.75]) {
      final double y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint fillPaint =
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[fillColor, fillColor.withOpacity(0.02)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final Paint strokePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    if (lastPoint != null) {
      canvas.drawCircle(
        lastPoint,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(lastPoint, 3.2, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalLineChartPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor) {
      return true;
    }
    if (identical(oldDelegate.points, points)) {
      return false;
    }
    if (oldDelegate.points.length != points.length) {
      return true;
    }
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final previous = oldDelegate.points[i];
      if (current.close != previous.close ||
          current.time.microsecondsSinceEpoch !=
              previous.time.microsecondsSinceEpoch) {
        return true;
      }
    }
    return false;
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 20 : 8,
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primary : Colors.black26,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _NewsArticleCard extends StatelessWidget {
  const _NewsArticleCard({
    required this.article,
    required this.subtitle,
    required this.onTap,
  });

  final FinanceNewsItem article;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.thumbnailUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    article.thumbnailUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                article.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (article.summary != null) ...[
                const SizedBox(height: 10),
                Text(
                  article.summary!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Lire sur Yahoo Finance',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodDelta {
  const _PeriodDelta({
    required this.start,
    required this.end,
    required this.change,
    required this.percent,
  });

  final double start;
  final double end;
  final double change;
  final double percent;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MetricEntry {
  _MetricEntry(this.title, String? value, [String? subtitle])
    : value = value ?? '—',
      subtitle = subtitle;

  final String title;
  final String value;
  final String? subtitle;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, this.subtitle});

  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionIndicatorCard extends StatelessWidget {
  const _DecisionIndicatorCard({
    required this.indicator,
    required this.primaryText,
    this.secondaryText,
    required this.onTap,
  });

  final DecisionIndicator indicator;
  final String primaryText;
  final String? secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        indicator.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        primaryText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (secondaryText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          secondaryText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: indicator.secondaryEmphasis
                                ? Colors.black87
                                : Colors.black54,
                            fontWeight: indicator.secondaryEmphasis
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.black45),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
