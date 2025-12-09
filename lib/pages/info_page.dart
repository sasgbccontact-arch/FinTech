import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintech/core/constants.dart';
import 'package:fintech/models/chart_models.dart';
import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/news_models.dart';
import 'package:fintech/services/portfolio_service.dart';
import 'package:fintech/services/yahoo_finance_service.dart';
import 'package:fintech/utils/decision_indicators.dart';
import 'package:fintech/utils/portfolio_dialogs.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    this.initialQuoteType,
  });

  final String? ticker;
  final String? initialName;
  final String? initialExchange;
  final String? initialCurrency;
  final String? initialQuoteType;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String? _ticker;
  String? _displayName;
  String? _exchange;
  String? _currency;
  String? _quoteType;

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
  Set<String> _newsFavoriteMatches = const <String>{};
  Set<String> _newsTickerMatches = const <String>{};
  _PeriodDelta? _periodDelta;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _favoriteSubscription;
  bool _favoriteStatusReady = false;
  bool _isFavorite = false;
  bool _favoriteUpdating = false;
  String? _favoriteListenSymbol;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _portfolioSubscription;
  List<_PortfolioInfo> _portfolios = const <_PortfolioInfo>[];
  bool _portfoliosReady = false;
  bool _portfolioUpdating = false;
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
    _quoteType = widget.initialQuoteType;
    _listenToPortfolios();
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
    required List<_InsightHighlight> highlights,
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
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPortfolioButton(theme),
                const SizedBox(width: 8),
                _buildFavoriteButton(theme),
                if (variationTexts.isNotEmpty) ...[
                  const SizedBox(width: 12),
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
              ],
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
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 14),
          _InsightHighlightRow(highlights: highlights),
        ],
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
          final rawType = args['quoteType'];
          if (rawType is String && rawType.trim().isNotEmpty) {
            _quoteType ??= rawType.trim();
          }
        }
      }
    }

    _ensureFavoriteListener();

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
    _favoriteSubscription?.cancel();
    _portfolioSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _listenToPortfolios() {
    _portfolioSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        _portfolios = const <_PortfolioInfo>[];
        _portfoliosReady = true;
        _portfolioUpdating = false;
        return;
      }
      setState(() {
        _portfolios = const <_PortfolioInfo>[];
        _portfoliosReady = true;
        _portfolioUpdating = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _portfoliosReady = false;
      });
    } else {
      _portfoliosReady = false;
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('portfolios')
        .orderBy('createdAt', descending: false);

    _portfolioSubscription = query.snapshots().listen(
      (snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          final rawName = (data['name'] as String?)?.trim() ?? '';
          final count = (data['positionsCount'] as num?)?.toInt() ?? 0;
          return _PortfolioInfo(
            id: doc.id,
            name: rawName.isEmpty ? 'Portefeuille' : rawName,
            positionsCount: count,
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _portfolios = items;
          _portfoliosReady = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _portfoliosReady = true;
        });
      },
    );
  }

  void _ensureFavoriteListener() {
    final symbol = _ticker?.trim();

    if (symbol == null || symbol.isEmpty) {
      _favoriteSubscription?.cancel();
      _favoriteSubscription = null;
      if (!mounted) {
        _favoriteStatusReady = false;
        _isFavorite = false;
        _favoriteUpdating = false;
        _favoriteListenSymbol = null;
        return;
      }
      setState(() {
        _favoriteStatusReady = false;
        _isFavorite = false;
        _favoriteUpdating = false;
        _favoriteListenSymbol = null;
      });
      return;
    }

    if (_favoriteListenSymbol == symbol) {
      return;
    }

    _favoriteSubscription?.cancel();
    _favoriteSubscription = null;
    _favoriteListenSymbol = symbol;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
        _favoriteStatusReady = true;
        _isFavorite = false;
        _favoriteUpdating = false;
        return;
      }
      setState(() {
        _favoriteStatusReady = true;
        _isFavorite = false;
        _favoriteUpdating = false;
      });
      return;
    }

    if (!mounted) {
      _favoriteStatusReady = false;
      _favoriteUpdating = false;
    } else {
      setState(() {
        _favoriteStatusReady = false;
        _favoriteUpdating = false;
      });
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoris')
        .doc(symbol);

    _favoriteSubscription = docRef.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _favoriteStatusReady = true;
          _isFavorite = snapshot.exists;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _favoriteStatusReady = true;
        });
      },
    );
  }

  Future<void> _toggleFavorite() async {
    final symbol = _ticker?.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (symbol == null || symbol.isEmpty) {
      return;
    }
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour gérer vos favoris.')),
      );
      return;
    }
    if (!_favoriteStatusReady || _favoriteUpdating) {
      return;
    }

    if (mounted) {
      setState(() {
        _favoriteUpdating = true;
      });
    } else {
      _favoriteUpdating = true;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoris')
        .doc(symbol);

    try {
      if (_isFavorite) {
        await docRef.delete();
      } else {
        final data = <String, dynamic>{
          'symbol': symbol,
          'name': _displayName ??
              _quote?.longName ??
              _quote?.shortName ??
              symbol,
          'exchange': _exchange ??
              _quote?.fullExchangeName ??
              _quote?.exchange ??
              '',
          'currency': _currency ?? _quote?.currency ?? '',
          'quoteType': _quoteType ?? _quote?.quoteType ?? 'UNKNOWN',
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await docRef.set(data, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de mettre à jour les favoris (${e.message ?? e.code}).',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour des favoris.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _favoriteUpdating = false;
        });
      } else {
        _favoriteUpdating = false;
      }
    }
  }

  Widget _buildFavoriteButton(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    final bool hasTicker = _ticker != null && _ticker!.trim().isNotEmpty;
    final bool isLoading = !_favoriteStatusReady || _favoriteUpdating;
    final bool selected = _isFavorite && _favoriteStatusReady;
    final Color iconColor =
        selected
            ? Colors.redAccent
            : theme.textTheme.bodyMedium?.color?.withOpacity(0.65) ?? Colors.black54;
    final bool enabled = user != null && hasTicker && !isLoading;

    final Widget visual =
        isLoading
            ? SizedBox(
                key: const ValueKey<String>('favorite-loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : Icon(
                selected ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                key: ValueKey<bool>(selected),
                color: iconColor,
                size: 22,
              );

    final tooltip =
        user == null
            ? 'Connectez-vous pour gérer vos favoris'
            : selected
                ? 'Retirer des favoris'
                : 'Ajouter aux favoris';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: enabled ? _toggleFavorite : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                selected
                    ? Colors.redAccent.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected
                      ? Colors.redAccent.withOpacity(0.4)
                      : Colors.black.withOpacity(0.05),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: visual,
          ),
        ),
      ),
    );
  }

  Future<void> _withPortfolioUpdating(Future<void> Function() task) async {
    if (mounted) {
      setState(() {
        _portfolioUpdating = true;
      });
    } else {
      _portfolioUpdating = true;
    }

    try {
      await task();
    } finally {
      if (mounted) {
        setState(() {
          _portfolioUpdating = false;
        });
      } else {
        _portfolioUpdating = false;
      }
    }
  }

  Future<void> _addSymbolToPortfolio(String portfolioId, String portfolioName) async {
    final symbol = _ticker?.trim();
    if (symbol == null || symbol.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connectez-vous pour gérer vos portefeuilles.')),
        );
      }
      return;
    }

    final quote = _quote;
    final currentPrice = quote?.regularMarketPrice ?? quote?.previousClose;
    final positionDetails = await _promptPositionDetails(currentPrice: currentPrice);
    if (positionDetails == null) {
      return;
    }

    await _withPortfolioUpdating(
      () => _addSymbolToPortfolioInternal(
        portfolioId,
        portfolioName,
        positionDetails,
      ),
    );
  }

  Future<void> _addSymbolToPortfolioInternal(
    String portfolioId,
    String portfolioName,
    _PositionFormResult details,
  ) async {
    final symbol = _ticker?.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (symbol == null || symbol.isEmpty) {
      return;
    }

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour gérer vos portefeuilles.')),
      );
      return;
    }

    final quote = _quote;
    final displayName = _displayName ??
        quote?.longName ??
        quote?.shortName ??
        symbol;

    final data = <String, dynamic>{
      'symbol': symbol,
      'displayName': displayName,
      'exchange': _exchange ?? quote?.fullExchangeName ?? quote?.exchange ?? '',
      'currency': _currency ?? quote?.currency ?? '',
      'regularMarketPrice': quote?.regularMarketPrice,
      'regularMarketChange': quote?.regularMarketChange,
      'regularMarketChangePercent': quote?.regularMarketChangePercent,
      'previousClose': quote?.previousClose,
      'quantity': details.quantity,
      'quoteType': _quoteType ?? quote?.quoteType ?? 'UNKNOWN',
    };

    final costBasis =
        details.costBasis ?? quote?.regularMarketPrice ?? quote?.previousClose;
    if (costBasis != null) {
      data['costBasis'] = costBasis;
    }

    try {
      await PortfolioService.addPosition(
        uid: user.uid,
        portfolioId: portfolioId,
        data: data,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajouté à "$portfolioName".')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’ajouter au portefeuille (${e.message ?? e.code}).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l’ajout au portefeuille.')),
      );
    }
  }

  Future<void> _handleCreatePortfolio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour créer un portefeuille.')),
      );
      return;
    }

    final name = await showCreatePortfolioDialog(context);
    if (name == null) {
      return;
    }

    String? newPortfolioId;
    await _withPortfolioUpdating(() async {
      newPortfolioId = await PortfolioService.createPortfolio(uid: user.uid, name: name);
    });

    if (!mounted || newPortfolioId == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Portefeuille "$name" créé.')),
    );

    final quote = _quote;
    final currentPrice = quote?.regularMarketPrice ?? quote?.previousClose;
    final positionDetails = await _promptPositionDetails(currentPrice: currentPrice);
    if (positionDetails == null) {
      return;
    }

    await _withPortfolioUpdating(
      () => _addSymbolToPortfolioInternal(
        newPortfolioId!,
        name,
        positionDetails,
      ),
    );
  }

  Future<_PositionFormResult?> _promptPositionDetails({double? currentPrice}) async {
    final quantityController = TextEditingController(text: '1');
    final costController = TextEditingController(
      text: currentPrice != null ? currentPrice.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<_PositionFormResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ajouter au portefeuille'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: quantityController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                  decoration: const InputDecoration(
                    labelText: 'Quantité',
                    hintText: 'Ex: 12.5',
                  ),
                  validator: (value) {
                    final parsed = _parseNumericInput(value);
                    if (parsed == null) {
                      return 'Indiquez une quantité valide.';
                    }
                    if (parsed <= 0) {
                      return 'La quantité doit être positive.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                  decoration: InputDecoration(
                    labelText: 'PRU (optionnel)',
                    hintText: currentPrice != null ? currentPrice.toStringAsFixed(2) : null,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final parsed = _parseNumericInput(trimmed);
                    if (parsed == null) {
                      return 'Entrez un PRU valide.';
                    }
                    if (parsed <= 0) {
                      return 'Le PRU doit être positif.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                final quantity = _parseNumericInput(quantityController.text.trim())!;
                final costBasis = _parseNumericInput(costController.text.trim());
                Navigator.of(dialogContext).pop(
                  _PositionFormResult(quantity: quantity, costBasis: costBasis),
                );
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  double? _parseNumericInput(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  List<PopupMenuEntry<_PortfolioMenuOption>> _buildPortfolioMenuEntries(ThemeData theme) {
    final entries = <PopupMenuEntry<_PortfolioMenuOption>>[];

    if (_portfolios.isEmpty) {
      entries.add(
        const PopupMenuItem<_PortfolioMenuOption>(
          enabled: false,
          child: Text('Aucun portefeuille.'),
        ),
      );
    } else {
      for (final portfolio in _portfolios) {
        entries.add(
          PopupMenuItem<_PortfolioMenuOption>(
            value: _PortfolioMenuOption.select(portfolio),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 18, color: Colors.black.withOpacity(0.65)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    portfolio.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (portfolio.positionsCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${portfolio.positionsCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      entries.add(const PopupMenuDivider(height: 10));
    }

    entries.add(
      PopupMenuItem<_PortfolioMenuOption>(
        value: const _PortfolioMenuOption.create(),
        child: const ListTile(
          dense: true,
          minLeadingWidth: 0,
          leading: Icon(Icons.add_rounded),
          title: Text('Créer un portefeuille'),
        ),
      ),
    );

    return entries;
  }

  Widget _buildPortfolioButton(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    final bool hasTicker = _ticker != null && _ticker!.trim().isNotEmpty;
    final bool ready = _portfoliosReady;
    final bool busy = _portfolioUpdating;
    final bool showSpinner = busy || !ready;
    final bool enabled = user != null && hasTicker && ready && !busy;

    final Color iconColor =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.65) ?? Colors.black54;

    final Widget visual =
        showSpinner
            ? SizedBox(
                key: const ValueKey<String>('portfolio-loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : Icon(
                Icons.folder_open_rounded,
                key: const ValueKey<String>('portfolio-icon'),
                color: iconColor,
                size: 22,
              );

    final tooltip =
        user == null
            ? 'Connectez-vous pour gérer vos portefeuilles'
            : 'Ajouter au portefeuille';

    final buttonStyleColor = showSpinner
        ? Colors.black.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    final borderColor = Colors.black.withOpacity(0.05);

    final button = PopupMenuButton<_PortfolioMenuOption>(
      enabled: enabled,
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      itemBuilder: (context) => _buildPortfolioMenuEntries(theme),
      onSelected: (option) {
        if (option.createNew) {
          _handleCreatePortfolio();
        } else if (option.portfolioId != null && option.portfolioName != null) {
          _addSymbolToPortfolio(option.portfolioId!, option.portfolioName!);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: buttonStyleColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: visual,
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: button,
    );
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
        _quoteType = quote.quoteType ?? _quoteType;
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
        _newsFavoriteMatches = const <String>{};
        _newsTickerMatches = const <String>{};
      });
      return;
    }

    final requestId = ++_newsRequestId;
    setState(() {
      _newsLoading = true;
      _newsError = null;
    });

    try {
      final favoriteSymbols = await _fetchFavoriteSymbolsForNews();
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
      final prioritized = _prioritizeNewsItems(items, favoriteSymbols, symbol);
      final favoriteMatches = _extractFavoriteMatches(prioritized, favoriteSymbols);
      final tickerMatches = _extractTickerMatches(prioritized, symbol);
      assert(() {
        debugPrint(
          '[InfoPage] Received ${prioritized.length} news item(s) for ' + symbol,
        );
        return true;
      }());
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _newsItems = prioritized;
        _newsLoading = false;
        _newsError = null;
        _newsFavoriteMatches = favoriteMatches;
        _newsTickerMatches = tickerMatches;
      });
    } on FinanceRequestException catch (e) {
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _newsLoading = false;
        _newsError = e.message;
        _newsItems = const <FinanceNewsItem>[];
        _newsFavoriteMatches = const <String>{};
        _newsTickerMatches = const <String>{};
      });
    } catch (e) {
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _newsLoading = false;
        _newsError = 'Erreur actualités: ${e.toString()}';
        _newsItems = const <FinanceNewsItem>[];
        _newsFavoriteMatches = const <String>{};
        _newsTickerMatches = const <String>{};
      });
    }
  }

  Future<Set<String>> _fetchFavoriteSymbolsForNews() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favoris')
          .get();
      final symbols = snap.docs.map((doc) {
        final data = doc.data();
        final symbol = (data['symbol'] as String? ?? doc.id).trim();
        return symbol.toUpperCase();
      }).where((symbol) => symbol.isNotEmpty).toSet();
      return symbols;
    } catch (_) {
      return const <String>{};
    }
  }

  List<FinanceNewsItem> _prioritizeNewsItems(
    List<FinanceNewsItem> items,
    Set<String> favorites,
    String symbol,
  ) {
    final favs = favorites.map((e) => e.toUpperCase()).toSet();
    final symbolUpper = symbol.toUpperCase();
    final scored = items.asMap().entries.map((entry) {
      final item = entry.value;
      final tickers = item.relatedTickers.map((t) => t.toUpperCase()).toSet();
      final matchesSymbol = tickers.contains(symbolUpper);
      final matchesFavorite = favs.isNotEmpty && tickers.any(favs.contains);
      final score = (matchesSymbol ? 2 : 0) + (matchesFavorite ? 1 : 0);
      return (_NewsRanking(item, score, entry.key));
    }).toList();
    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.index.compareTo(b.index);
    });
    return scored.map((entry) => entry.item).toList();
  }

  Set<String> _extractFavoriteMatches(
    List<FinanceNewsItem> items,
    Set<String> favorites,
  ) {
    if (favorites.isEmpty) return const <String>{};
    final favs = favorites.map((e) => e.toUpperCase()).toSet();
    return items
        .where((item) => item.relatedTickers.any((ticker) => favs.contains(ticker.toUpperCase())))
        .map((item) => item.id)
        .toSet();
  }

  Set<String> _extractTickerMatches(List<FinanceNewsItem> items, String symbol) {
    final upper = symbol.toUpperCase();
    return items
        .where((item) => item.relatedTickers.any((ticker) => ticker.toUpperCase() == upper))
        .map((item) => item.id)
        .toSet();
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
    final isEtf = (_quoteType ?? quote?.quoteType)?.toUpperCase() == 'ETF';
    final essentialTitles = <String>{
      'Devise',
      if (isEtf) 'Actifs nets' else 'Capitalisation',
      if (!isEtf) 'PER (TTM)',
      'Volume',
      'Rdt dividende',
      if (isEtf) 'Frais annuels',
      if (isEtf) 'Perf. YTD',
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

    final highlights = _buildHighlights(quote);

    final overview = _buildEssentialPage(
      theme: theme,
      priceText: priceText,
      changeText: changeText,
      percentText: percentText,
      changePositive: changePositive,
      periodLabel: periodLabel,
      lastUpdate: lastUpdate,
      essentialMetrics: essentialMetrics,
      highlights: highlights,
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
          highlightPrimary: _newsTickerMatches.contains(item.id),
          highlightFavorite: _newsFavoriteMatches.contains(item.id),
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
    final isEtf = (_quoteType ?? quote.quoteType)?.toUpperCase() == 'ETF';
    final snapshot = _financialSnapshot;
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
      if (!isEtf && quote.trailingPE != null)
        _MetricEntry(
          'PER (TTM)',
          _formatNumber(quote.trailingPE, fractionDigits: 2),
        ),
      if (!isEtf && quote.forwardPE != null)
        _MetricEntry(
          'PER (forward)',
          _formatNumber(quote.forwardPE, fractionDigits: 2),
        ),
      if (!isEtf && snapshot?.pegRatio != null)
        _MetricEntry(
          'PEG',
          _formatNumber(snapshot!.pegRatio, fractionDigits: 2),
        ),
      if (!isEtf && snapshot?.enterpriseToEbitda != null)
        _MetricEntry(
          'EV/EBITDA',
          _formatNumber(snapshot!.enterpriseToEbitda, fractionDigits: 2),
        ),
      if (!isEtf && snapshot?.enterpriseToRevenue != null)
        _MetricEntry(
          'EV/CA',
          _formatNumber(snapshot!.enterpriseToRevenue, fractionDigits: 2),
        ),
      if (!isEtf && quote.epsTrailingTwelveMonths != null)
        _MetricEntry(
          'BPA (TTM)',
          _formatCurrency(quote.epsTrailingTwelveMonths),
        ),
      if (quote.dividendYield != null)
        _MetricEntry(
          'Rdt dividende',
          _formatPercent(quote.dividendYield! * 100),
        ),
      if (isEtf && snapshot?.netAssets != null)
        _MetricEntry(
          'Actifs nets',
          _formatLargeNumber(snapshot!.netAssets!),
          _formatCurrency(snapshot.netAssets, withSeparators: true),
        ),
      if (isEtf && snapshot?.expenseRatio != null)
        _MetricEntry(
          'Frais annuels',
          _formatPercent(snapshot!.expenseRatio! * 100),
        ),
      if (isEtf && snapshot?.ytdReturn != null)
        _MetricEntry(
          'Perf. YTD',
          _formatPercent(snapshot!.ytdReturn! * 100),
        ),
      if (isEtf && snapshot?.threeYearAverageReturn != null)
        _MetricEntry(
          'Perf. 3 ans',
          _formatPercent(snapshot!.threeYearAverageReturn! * 100),
        ),
      if (isEtf && snapshot?.betaThreeYear != null)
        _MetricEntry(
          'Bêta 3 ans',
          _formatNumber(snapshot!.betaThreeYear!, fractionDigits: 2),
        ),
      if (isEtf && snapshot?.fundCategory != null && snapshot!.fundCategory!.isNotEmpty)
        _MetricEntry('Catégorie', snapshot.fundCategory!),
      if (!isEtf && snapshot?.returnOnEquity != null)
        _MetricEntry('ROE', _formatPercent(snapshot!.returnOnEquity! * 100)),
      if (!isEtf && snapshot?.returnOnAssets != null)
        _MetricEntry('ROA', _formatPercent(snapshot!.returnOnAssets! * 100)),
      if (!isEtf && snapshot?.operatingMargin != null)
        _MetricEntry('Marge op.', _formatPercent(snapshot!.operatingMargin! * 100)),
      if (!isEtf && snapshot?.netMargin != null)
        _MetricEntry('Marge nette', _formatPercent(snapshot!.netMargin! * 100)),
      if (!isEtf && snapshot?.revenueGrowth != null)
        _MetricEntry('Croissance CA', _formatPercent(snapshot!.revenueGrowth! * 100)),
      if (!isEtf && snapshot?.earningsGrowth != null)
        _MetricEntry('Croissance BPA', _formatPercent(snapshot!.earningsGrowth! * 100)),
      if (!isEtf && snapshot?.freeCashflowYield != null)
        _MetricEntry('FCF yield', _formatPercent(snapshot!.freeCashflowYield! * 100)),
      if (!isEtf && snapshot?.capexToRevenue != null)
        _MetricEntry('Capex/CA', _formatPercent(snapshot!.capexToRevenue! * 100)),
      if (quote.averageDailyVolume3Month != null)
        _MetricEntry('ADV 3m', _formatLargeNumber(quote.averageDailyVolume3Month), _formatInteger(quote.averageDailyVolume3Month)),
      if (quote.regularMarketVolume != null && quote.averageDailyVolume3Month != null && quote.averageDailyVolume3Month! > 0)
        _MetricEntry(
          'Turnover',
          '${(quote.regularMarketVolume! / quote.averageDailyVolume3Month! * 100).toStringAsFixed(1)} %',
          'vs moy. 3m',
        ),
    ];

    return metrics.whereType<_MetricEntry>().toList();
  }

  List<_InsightHighlight> _buildHighlights(QuoteDetail? quote) {
    final highlights = <_InsightHighlight>[];
    if (quote == null) return highlights;

    final changePercent = quote.regularMarketChangePercent;
    if (changePercent != null) {
      highlights.add(
        _InsightHighlight(
          label: 'Momentum',
          value: _formatPercent(changePercent) ?? '—',
          icon: changePercent >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: changePercent >= 0 ? Colors.green.shade600 : Colors.red.shade600,
        ),
      );
    }

    if (quote.regularMarketVolume != null && quote.averageDailyVolume3Month != null && quote.averageDailyVolume3Month! > 0) {
      final ratio = quote.regularMarketVolume! / quote.averageDailyVolume3Month!;
      highlights.add(
        _InsightHighlight(
          label: 'Volume',
          value: '${ratio.toStringAsFixed(2)}x moy.',
          icon: Icons.area_chart_rounded,
          color: ratio >= 1 ? Colors.blueAccent : Colors.blueGrey,
        ),
      );
    }

    if (quote.dividendYield != null) {
      highlights.add(
        _InsightHighlight(
          label: 'Dividende',
          value: _formatPercent(quote.dividendYield!) ?? '—',
          icon: Icons.savings_rounded,
          color: Colors.orange.shade700,
        ),
      );
    }

    if (quote.regularMarketPrice != null && quote.fiftyTwoWeekHigh != null && quote.fiftyTwoWeekLow != null) {
      final price = quote.regularMarketPrice!;
      final low = quote.fiftyTwoWeekLow!;
      final high = quote.fiftyTwoWeekHigh!;
      if (high > low) {
        final normalized = ((price - low) / (high - low)).clamp(0, 1);
        highlights.add(
          _InsightHighlight(
            label: '52 sem.',
            value: '${(normalized * 100).toStringAsFixed(0)}% du canal',
            icon: Icons.timelapse_rounded,
            color: Colors.purple.shade600,
          ),
        );
      }
    }

    return highlights;
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

class _InsightHighlight {
  const _InsightHighlight({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _InsightHighlightRow extends StatelessWidget {
  const _InsightHighlightRow({required this.highlights});

  final List<_InsightHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: highlights.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final highlight = highlights[index];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(highlight.icon, color: highlight.color, size: 20),
                const SizedBox(height: 6),
                Text(
                  highlight.label,
                  style: TextStyle(fontSize: _infoScaledFont(context, 12), color: Colors.black54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  highlight.value,
                  style: TextStyle(fontSize: _infoScaledFont(context, 15), fontWeight: FontWeight.w700, color: highlight.color),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _infoScaledFont(BuildContext context, double size) {
  final width = MediaQuery.sizeOf(context).width;
  final factor = (width / 390).clamp(0.85, 1.2);
  final base = size * factor;
  return MediaQuery.textScalerOf(context).scale(base);
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
    this.highlightPrimary = false,
    this.highlightFavorite = false,
  });

  final FinanceNewsItem article;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlightPrimary;
  final bool highlightFavorite;

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (highlightPrimary)
                    _NewsChip(label: 'Suivi', color: Colors.green.shade600),
                  if (highlightFavorite)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _NewsChip(label: 'Favori lié', color: Colors.blueAccent),
                    ),
                ],
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

class _NewsChip extends StatelessWidget {
  const _NewsChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _NewsRanking {
  const _NewsRanking(this.item, this.score, this.index);

  final FinanceNewsItem item;
  final int score;
  final int index;
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

class _PortfolioInfo {
  const _PortfolioInfo({
    required this.id,
    required this.name,
    required this.positionsCount,
  });

  final String id;
  final String name;
  final int positionsCount;
}

class _PositionFormResult {
  const _PositionFormResult({
    required this.quantity,
    this.costBasis,
  });

  final double quantity;
  final double? costBasis;
}

class _PortfolioMenuOption {
  const _PortfolioMenuOption._({
    this.portfolioId,
    this.portfolioName,
    this.createNew = false,
  });

  factory _PortfolioMenuOption.select(_PortfolioInfo info) {
    return _PortfolioMenuOption._(
      portfolioId: info.id,
      portfolioName: info.name,
      createNew: false,
    );
  }

  const _PortfolioMenuOption.create()
      : this._(
          portfolioId: null,
          portfolioName: null,
          createNew: true,
        );

  final String? portfolioId;
  final String? portfolioName;
  final bool createNew;
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
