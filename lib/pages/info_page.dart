import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintech/core/constants.dart';
import 'package:fintech/features/duel/duel_models.dart';
import 'package:fintech/features/duel/duel_service.dart';
import 'package:fintech/models/chart_models.dart';
import 'package:fintech/models/dividend_event.dart';
import 'package:fintech/models/financial_snapshot.dart';
import 'package:fintech/models/fundamental_game_models.dart';
import 'package:fintech/models/news_models.dart';
import 'package:fintech/services/activity_tracking_service.dart';
import 'package:fintech/services/fundamental_game_engine.dart';
import 'package:fintech/services/portfolio_service.dart';
import 'package:fintech/services/yahoo_finance_service.dart';
import 'package:fintech/utils/decision_indicators.dart';
import 'package:fintech/utils/fundamental_score_presenter.dart';
import 'package:fintech/utils/portfolio_dialogs.dart';
import 'package:fintech/widgets/fundamental_score_hero_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// InfoPage
/// Affiche les informations clés d'une action sélectionnée dans la recherche.
enum _ChartDisplayMode { price, performance }

enum _NewsFilter { all, ticker, favorites, macro }

class InfoPage extends StatefulWidget {
  const InfoPage({
    super.key,
    this.ticker,
    this.initialName,
    this.initialExchange,
    this.initialCurrency,
    this.initialQuoteType,
    this.isAdmin = false,
  });

  final String? ticker;
  final String? initialName;
  final String? initialExchange;
  final String? initialCurrency;
  final String? initialQuoteType;
  final bool isAdmin;

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
  FundamentalGameData? _fundamentalGameData;
  FundamentalAnalysisResult? _fundamentalAnalysis;
  FinancialSnapshot? _financialSnapshot;
  bool _fundamentalLoading = true;
  String? _fundamentalError;
  int _fundamentalRequestId = 0;
  DividendEvent? _dividendEvent;
  bool _dividendLoading = true;
  String? _dividendError;
  List<FinanceNewsItem> _newsItems = const <FinanceNewsItem>[];
  bool _newsLoading = true;
  String? _newsError;
  int _newsRequestId = 0;
  Set<String> _newsFavoriteMatches = const <String>{};
  Set<String> _newsTickerMatches = const <String>{};
  _PeriodDelta? _periodDelta;
  _ChartDisplayMode _chartDisplayMode = _ChartDisplayMode.price;
  _NewsFilter _newsFilter = _NewsFilter.all;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _favoriteSubscription;
  bool _favoriteStatusReady = false;
  bool _isFavorite = false;
  bool _favoriteUpdating = false;
  String? _favoriteListenSymbol;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _portfolioSubscription;
  List<_PortfolioInfo> _portfolios = const <_PortfolioInfo>[];
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  bool _portfoliosReady = false;
  bool _portfolioUpdating = false;
  bool _isAdmin = false;
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

  // Palette (same style as SearchPage)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;
  static const Color _chipBg = Color(0xFFF0F1F3);

  @override
  void initState() {
    super.initState();
    _displayName = widget.initialName;
    _exchange = widget.initialExchange;
    _currency = widget.initialCurrency;
    _quoteType = widget.initialQuoteType;
    _listenToUserAdmin();
    _listenToPortfolios();
  }

  Widget _buildEssentialPage({
    required ThemeData theme,
    required String? changeText,
    required String? percentText,
    required bool changePositive,
    required String periodLabel,
    required String? lastUpdate,
    required List<_MetricEntry> essentialMetrics,
    required List<_InsightHighlight> highlights,
    required _DataCoverageSummary coverage,
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
        _InfoSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ContextPill(
                    icon: Icons.timeline_rounded,
                    label: periodLabel,
                    foreground: _wine,
                    background: _wine.withValues(alpha: 0.10),
                  ),
                  _ContextPill(
                    icon: coverage.icon,
                    label: coverage.label,
                    foreground: coverage.accent,
                    background: coverage.soft,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Vue d’ensemble',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lecture rapide du comportement récent, de la qualité des données et des principaux repères de marché.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _OverviewStatCard(
                    label: 'Variation',
                    value:
                        variationTexts.isEmpty
                            ? '—'
                            : variationTexts.join(' · '),
                    accent:
                        changePositive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                    soft:
                        changePositive
                            ? Colors.green.withValues(alpha: 0.10)
                            : Colors.red.withValues(alpha: 0.10),
                  ),
                  _OverviewStatCard(
                    label: 'Dernière mise à jour',
                    value: lastUpdate ?? 'Indisponible',
                    accent: textColor,
                    soft: _chipBg,
                  ),
                  _OverviewStatCard(
                    label: 'Couverture',
                    value: coverage.ratioLabel,
                    accent: coverage.accent,
                    soft: coverage.soft,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 14),
          _InsightHighlightRow(highlights: highlights),
        ],
        const SizedBox(height: 24),
        _QuoteChartSection(
          points: _chartPoints,
          loading: _chartLoading,
          error: _chartError,
          interval: _selectedInterval,
          onIntervalSelected: (value) => _loadChartData(interval: value),
          displayMode: _chartDisplayMode,
          onDisplayModeChanged:
              (mode) => setState(() => _chartDisplayMode = mode),
          labelBuilder: _formatChartTick,
          currencyFormatter: _formatCurrency,
          percentFormatter: _formatPercent,
          annotations: _buildChartAnnotations(),
        ),
        if (essentialMetrics.isNotEmpty) ...[
          const SizedBox(height: 28),
          _MetricGroupCard(
            title: 'Indicateurs essentiels',
            subtitle:
                'Repères immédiats pour situer l’actif avant d’ouvrir les blocs plus détaillés.',
            metrics: essentialMetrics,
          ),
        ],
        const SizedBox(height: 16),
        _buildDividendOverviewCard(theme),
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
    _userSubscription?.cancel();
    _portfolioSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _isAdmin = snapshot.data()?['isAdmin'] ?? false;
            });
          }
        });
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
        final items =
            snapshot.docs.map((doc) {
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
          'name':
              _displayName ?? _quote?.longName ?? _quote?.shortName ?? symbol,
          'exchange':
              _exchange ?? _quote?.fullExchangeName ?? _quote?.exchange ?? '',
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
          const SnackBar(
            content: Text('Erreur lors de la mise à jour des favoris.'),
          ),
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
            ? _wine
            : (theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65) ??
                Colors.black54);
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
              selected
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
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
                    ? _wine.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected
                      ? _wine.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder:
                (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
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

  Future<void> _addSymbolToPortfolio(
    String portfolioId,
    String portfolioName,
  ) async {
    final symbol = _ticker?.trim();
    if (symbol == null || symbol.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connectez-vous pour gérer vos portefeuilles.'),
          ),
        );
      }
      return;
    }

    final quote = _quote;
    final currentPrice = quote?.regularMarketPrice ?? quote?.previousClose;
    final positionDetails = await _promptPositionDetails(
      currentPrice: currentPrice,
    );
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
        const SnackBar(
          content: Text('Connectez-vous pour gérer vos portefeuilles.'),
        ),
      );
      return;
    }

    final quote = _quote;
    final displayName =
        _displayName ?? quote?.longName ?? quote?.shortName ?? symbol;

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
        SnackBar(
          content: Text(
            'Ajoute a "$portfolioName". Verifie ensuite le prix d\'achat, la concentration et la diversification.',
          ),
        ),
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
        const SnackBar(
          content: Text('Erreur lors de l’ajout au portefeuille.'),
        ),
      );
    }
  }

  Future<void> _handleCreatePortfolio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour créer un portefeuille.'),
        ),
      );
      return;
    }

    final name = await showCreatePortfolioDialog(context);
    if (name == null) {
      return;
    }

    String? newPortfolioId;
    await _withPortfolioUpdating(() async {
      newPortfolioId = await PortfolioService.createPortfolio(
        uid: user.uid,
        name: name,
      );
    });

    if (!mounted || newPortfolioId == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Portefeuille "$name" créé.')));

    final quote = _quote;
    final currentPrice = quote?.regularMarketPrice ?? quote?.previousClose;
    final positionDetails = await _promptPositionDetails(
      currentPrice: currentPrice,
    );
    if (positionDetails == null) {
      return;
    }

    await _withPortfolioUpdating(
      () =>
          _addSymbolToPortfolioInternal(newPortfolioId!, name, positionDetails),
    );
  }

  Future<_PositionFormResult?> _promptPositionDetails({
    double? currentPrice,
  }) async {
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  decoration: InputDecoration(
                    labelText: 'PRU (optionnel)',
                    hintText:
                        currentPrice != null
                            ? currentPrice.toStringAsFixed(2)
                            : null,
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
                final quantity =
                    _parseNumericInput(quantityController.text.trim())!;
                final costBasis = _parseNumericInput(
                  costController.text.trim(),
                );
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

  List<PopupMenuEntry<_PortfolioMenuOption>> _buildPortfolioMenuEntries(
    ThemeData theme,
  ) {
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
                Icon(
                  Icons.folder_open_rounded,
                  size: 18,
                  color: Colors.black.withOpacity(0.65),
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
    final buttonStyleColor =
        showSpinner ? _chipBg.withValues(alpha: 0.85) : _chipBg;

    final borderColor = Colors.black.withValues(alpha: 0.05);

    final Color iconColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65) ??
        Colors.black54;

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
          transitionBuilder:
              (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
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

  Widget _buildTradeButtons(ThemeData theme) {
    final bool canTrade = _quote?.regularMarketPrice != null;
    final user = FirebaseAuth.instance.currentUser;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user != null)
          StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final zeroFeesUntil = data?['zero_fees_until'] as Timestamp?;
              final boostCount =
                  (data?['boost_zero_fees_count'] as num?)?.toInt() ?? 0;

              final bool isActive =
                  zeroFeesUntil != null &&
                  zeroFeesUntil.toDate().isAfter(DateTime.now());

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed:
                      () => _showBoostInventory(
                        context,
                        isActive,
                        boostCount,
                        zeroFeesUntil?.toDate(),
                      ),
                  icon: Icon(
                    Icons.flash_on_rounded,
                    color:
                        isActive
                            ? Colors.green
                            : (boostCount > 0
                                ? Colors.amber
                                : Colors.grey.shade300),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        isActive
                            ? Colors.green.withOpacity(0.1)
                            : (boostCount > 0
                                ? Colors.amber.withOpacity(0.1)
                                : Colors.grey.shade100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  tooltip: "Boosts & Bonus",
                ),
              );
            },
          ),
        ElevatedButton(
          onPressed: canTrade ? () => _showTradeDialog(isBuy: true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            "Acheter",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: canTrade ? () => _showTradeDialog(isBuy: false) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            "Vendre",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showBoostInventory(
    BuildContext context,
    bool isActive,
    int count,
    DateTime? expiry,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Inventaire de Boosts",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? Colors.green : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          isActive ? Colors.green : Colors.blueAccent,
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "0% de Frais (12h)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isActive)
                            Text(
                              "Actif jusqu'à ${_formatDateTime(expiry)}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          else
                            Text(
                              "En stock : $count",
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    if (!isActive)
                      ElevatedButton(
                        onPressed:
                            count > 0
                                ? () {
                                  Navigator.pop(context);
                                  _activateBoost();
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Activer"),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _activateBoost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final snapshot = await transaction.get(userRef);
        final count =
            (snapshot.data()?['boost_zero_fees_count'] as num?)?.toInt() ?? 0;

        if (count > 0) {
          final now = DateTime.now();
          final expiry = now.add(const Duration(hours: 12));

          transaction.update(userRef, {
            'boost_zero_fees_count': FieldValue.increment(-1),
            'zero_fees_until': Timestamp.fromDate(expiry),
          });
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Boost activé ! Profitez de 0% de frais."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur activation boost: $e");
    }
  }

  Future<void> _showTradeDialog({required bool isBuy}) async {
    // Vérification des horaires de marché (9h00 - 17h30, Lundi-Vendredi)
    final now = DateTime.now();
    final isWeekend = now.weekday >= 6; // 6 = Samedi, 7 = Dimanche
    final totalMinutes = now.hour * 60 + now.minute;
    final isMarketHours =
        totalMinutes >= 540 && totalMinutes < 1050; // 9*60 à 17*60+30

    if (!_isAdmin && (isWeekend || !isMarketHours)) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Marché fermé"),
              content: const Text(
                "Les transactions sont possibles uniquement du lundi au vendredi, de 9h00 à 17h30.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter pour trader.")),
      );
      return;
    }

    // Vérification du Chapitre 1 (via l'avatar _student)
    if (!_isAdmin) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final unlockedAvatars = List<String>.from(
        userDoc.data()?['unlocked_avatars'] ?? [],
      );
      if (!unlockedAvatars.contains('_student')) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Fonctionnalité verrouillée"),
                content: const Text(
                  "Vous devez terminer le Chapitre 1 dans l'onglet Apprendre pour débloquer le trading.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
        return;
      }
    }

    final double price = _quote!.regularMarketPrice!;
    final TextEditingController qtyController = TextEditingController(
      text: "1",
    );
    final ValueNotifier<int> qtyNotifier = ValueNotifier<int>(1);

    showDialog(
      context: context,
      builder:
          (context) => StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
            builder: (context, userSnapshot) {
              final userData =
                  userSnapshot.data?.data() as Map<String, dynamic>?;
              final zeroFeesUntil = userData?['zero_fees_until'] as Timestamp?;
              final bool isBoostActive =
                  zeroFeesUntil != null &&
                  zeroFeesUntil.toDate().isAfter(DateTime.now());

              return StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('games')
                        .doc('portofolio')
                        .collection('positions')
                        .doc(_ticker)
                        .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final double? pru =
                      (data?['averagePrice'] as num?)?.toDouble();

                  return AlertDialog(
                    title: Text(
                      isBuy ? "Acheter $_ticker" : "Vendre $_ticker",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prix unitaire : ${_formatCurrency(price)}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (pru != null)
                          Text(
                            "PRU actuel : ${_formatCurrency(pru)}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Nombre d'actions",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            final int? val = int.tryParse(value);
                            qtyNotifier.value =
                                (val != null && val > 0) ? val : 0;
                          },
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<int>(
                          valueListenable: qtyNotifier,
                          builder: (context, qty, child) {
                            final double rawTotal = price * qty;
                            final double fees =
                                isBoostActive
                                    ? 0.0
                                    : rawTotal *
                                        0.005; // 0.5% frais ou 0% si boost
                            final double total =
                                isBuy ? rawTotal + fees : rawTotal - fees;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Sous-total :"),
                                      Text(_formatCurrency(rawTotal) ?? ""),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isBoostActive
                                            ? "Frais (0% - Boost) :"
                                            : "Frais (0.5%) :",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isBoostActive
                                                  ? Colors.green
                                                  : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(fees) ?? "",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isBoostActive
                                                  ? Colors.green
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Total :",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(total) ?? "",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isBuy ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isBuy
                                        ? "(Débité de vos Coins)"
                                        : "(Crédité en Coins)",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Annuler",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: qtyNotifier,
                        builder: (context, qty, _) {
                          return ElevatedButton(
                            onPressed:
                                qty > 0
                                    ? () {
                                      Navigator.pop(context);
                                      _executeTrade(
                                        user.uid,
                                        isBuy,
                                        qty,
                                        price,
                                      );
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Valider"),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
    );
  }

  Future<void> _executeTrade(
    String uid,
    bool isBuy,
    int qty,
    double price,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final portfolioRef = userRef
        .collection('games')
        .doc('portofolio')
        .collection('positions')
        .doc(_ticker);
    String? duelBlockReason;
    var wasProfitableSale = false;

    if (!isBuy) {
      final portfolioDoc = await portfolioRef.get();
      final currentQty =
          (portfolioDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
      duelBlockReason = await DuelService.validateSaleDuringActiveDuel(
        uid: uid,
        currentQuantity: currentQty,
        sellQuantity: qty,
      );
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final portfolioDoc = await transaction.get(portfolioRef);
        final duelProfileDoc = await transaction.get(
          DuelService.duelProfileRef(uid),
        );

        // Vérification Boost
        final zeroFeesUntil = userDoc.data()?['zero_fees_until'] as Timestamp?;
        final bool isBoostActive =
            zeroFeesUntil != null &&
            zeroFeesUntil.toDate().isAfter(DateTime.now());

        final double rawTotal = price * qty;
        final double fees = isBoostActive ? 0.0 : rawTotal * 0.005;
        final double totalAmount = isBuy ? rawTotal + fees : rawTotal - fees;

        final int currentCoins =
            (userDoc.data()?['coins'] as num?)?.toInt() ?? 0;
        final int currentQty =
            (portfolioDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
        final double currentAvgPrice =
            (portfolioDoc.data()?['averagePrice'] as num?)?.toDouble() ?? 0.0;
        final int currentSellStreak =
            (userDoc.data()?['game_profitable_sell_streak'] as num?)?.toInt() ??
            0;
        final int bestSellStreak =
            (userDoc.data()?['game_best_profitable_sell_streak'] as num?)
                ?.toInt() ??
            0;
        final duelProfile = DuelProfile.fromDoc(
          duelProfileDoc,
          fallbackUid: uid,
        );

        if (isBuy) {
          if (currentCoins < totalAmount) {
            throw Exception(
              "Pas assez de coins ! (Manque ${(totalAmount - currentCoins).toStringAsFixed(2)})",
            );
          }
          // Calcul nouveau PRU (Prix de Revient Unitaire)
          final double newAvgPrice =
              ((currentQty * currentAvgPrice) + (qty * price)) /
              (currentQty + qty);

          transaction.update(userRef, {
            'coins': currentCoins - totalAmount.toInt(),
          });
          if (userDoc.data()?['game_first_trade_at'] == null) {
            transaction.set(userRef, {
              'game_first_trade_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          transaction.set(portfolioRef, {
            'symbol': _ticker,
            'quantity': currentQty + qty,
            'averagePrice': newAvgPrice,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // Vente
          if (currentQty < qty) {
            throw Exception("Pas assez d'actions ! (Possédé: $currentQty)");
          }
          if (currentQty - qty == 0 &&
              duelProfile.isActiveDuel &&
              duelBlockReason != null) {
            throw Exception(duelBlockReason);
          }
          wasProfitableSale = currentAvgPrice > 0 && price > currentAvgPrice;
          final nextSellStreak = wasProfitableSale ? currentSellStreak + 1 : 0;
          transaction.update(userRef, {
            'coins': currentCoins + totalAmount.toInt(),
            'last_game_sell_at': FieldValue.serverTimestamp(),
            'game_profitable_sell_streak': nextSellStreak,
            if (wasProfitableSale && nextSellStreak > bestSellStreak)
              'game_best_profitable_sell_streak': nextSellStreak,
          });

          if (currentQty - qty == 0) {
            transaction.delete(portfolioRef);
          } else {
            transaction.update(portfolioRef, {'quantity': currentQty - qty});
          }
        }
      });

      await DuelService.syncCurrentUserProfile(uid: uid, bumpActivity: false);

      unawaited(
        ActivityTrackingService.trackForUser(
          uid: uid,
          type:
              isBuy
                  ? 'game_portfolio_buy'
                  : wasProfitableSale
                  ? 'game_portfolio_sell_profit'
                  : 'game_portfolio_sell',
          label: _ticker,
          points:
              isBuy
                  ? 20
                  : wasProfitableSale
                  ? 30
                  : 18,
          counters: <String, int>{
            'portfolio_trades': 1,
            if (isBuy) 'game_portfolio_buys': 1,
            if (!isBuy) 'portfolio_positions_sold': 1,
            if (!isBuy && wasProfitableSale) 'portfolio_profitable_sells': 1,
          },
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ordre exécuté !"),
          backgroundColor: Colors.green,
        ),
      );

      // --- Mise à jour Quête Quotidienne (Trade) ---
      try {
        final today = DateTime.now();
        final dateStr = "${today.year}-${today.month}-${today.day}";
        final questRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('quests')
            .doc('daily');

        // On utilise une transaction ou un update simple (ici update simple suffisant car post-transaction critique)
        final doc = await questRef.get();
        if (!doc.exists || doc.data()?['date'] != dateStr) {
          await questRef.set({
            'date': dateStr,
            'quizzes_done': 0,
            'lessons_done': 0,
            'trades_done': 1,
          });
        } else {
          await questRef.update({'trades_done': FieldValue.increment(1)});
        }
      } catch (e) {
        debugPrint("Erreur quête trade : $e");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      });
      _loadChartData();
      _loadFundamentalData();
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

  Future<void> _loadFundamentalData() async {
    final symbol = _ticker;
    if (symbol == null || symbol.isEmpty) return;

    final requestId = ++_fundamentalRequestId;
    setState(() {
      _fundamentalLoading = true;
      _fundamentalError = null;
      _dividendLoading = true;
      _dividendError = null;
    });

    try {
      final results = await Future.wait<Object>([
        YahooFinanceService.fetchFundamentalGameData(symbol),
        FundamentalGameEngine.loadConfig(),
      ]);
      final gameData = results[0] as FundamentalGameData;
      final config = results[1] as FundamentalGameConfig;
      final analysis =
          gameData.isEquity
              ? FundamentalGameEngine.analyze(data: gameData, config: config)
              : null;
      DividendEvent? dividendEvent;
      String? dividendError;
      try {
        dividendEvent = await YahooFinanceService.fetchDividendEvent(symbol);
      } on FinanceRequestException catch (e) {
        if (e.message != 'consent_required') {
          dividendError = e.message;
        }
      } catch (_) {
        dividendError = 'Calendrier de dividendes indisponible.';
      }
      if (!mounted || requestId != _fundamentalRequestId) return;
      setState(() {
        _fundamentalGameData = gameData;
        _fundamentalAnalysis = analysis;
        _financialSnapshot = gameData.snapshot;
        _fundamentalLoading = false;
        _fundamentalError = null;
        _dividendEvent = dividendEvent;
        _dividendLoading = false;
        _dividendError = dividendError;
      });
    } on FinanceRequestException catch (e) {
      if (!mounted || requestId != _fundamentalRequestId) return;
      setState(() {
        _fundamentalLoading = false;
        _fundamentalError = e.message;
        _fundamentalGameData = null;
        _fundamentalAnalysis = null;
        _financialSnapshot = null;
        _dividendEvent = null;
        _dividendLoading = false;
        _dividendError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _fundamentalRequestId) return;
      setState(() {
        _fundamentalLoading = false;
        _fundamentalError = 'Erreur financières: ${e.toString()}';
        _fundamentalGameData = null;
        _fundamentalAnalysis = null;
        _financialSnapshot = null;
        _dividendEvent = null;
        _dividendLoading = false;
        _dividendError = null;
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
    return _PeriodDelta(
      start: start,
      end: end,
      change: change,
      percent: percent,
    );
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
      final aliases =
          aliasCandidates
              .where((value) => (value?.trim().isNotEmpty ?? false))
              .map((value) => value!.trim())
              .toList();

      final items = await YahooFinanceService.fetchCompanyNews(
        symbol,
        aliases: aliases,
      );
      final prioritized = _prioritizeNewsItems(items, favoriteSymbols, symbol);
      final favoriteMatches = _extractFavoriteMatches(
        prioritized,
        favoriteSymbols,
      );
      final tickerMatches = _extractTickerMatches(prioritized, symbol);
      assert(() {
        debugPrint(
          '[InfoPage] Received ${prioritized.length} news item(s) for ' +
              symbol,
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
      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('favoris')
              .get();
      final symbols =
          snap.docs
              .map((doc) {
                final data = doc.data();
                final symbol = (data['symbol'] as String? ?? doc.id).trim();
                return symbol.toUpperCase();
              })
              .where((symbol) => symbol.isNotEmpty)
              .toSet();
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
    final scored =
        items.asMap().entries.map((entry) {
          final item = entry.value;
          final tickers =
              item.relatedTickers.map((t) => t.toUpperCase()).toSet();
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
        .where(
          (item) => item.relatedTickers.any(
            (ticker) => favs.contains(ticker.toUpperCase()),
          ),
        )
        .map((item) => item.id)
        .toSet();
  }

  Set<String> _extractTickerMatches(
    List<FinanceNewsItem> items,
    String symbol,
  ) {
    final upper = symbol.toUpperCase();
    return items
        .where(
          (item) => item.relatedTickers.any(
            (ticker) => ticker.toUpperCase() == upper,
          ),
        )
        .map((item) => item.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _ticker ?? 'Info',
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        centerTitle: false,
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 6,
                width: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    colors: [_gold, _wine],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child:
              _loading
                  ? Center(
                    child: CircularProgressIndicator(
                      color: _wine,
                      backgroundColor: _gold.withValues(alpha: .20),
                      strokeWidth: 3,
                    ),
                  )
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

  Future<void> _openExternalUrl(
    String url, {
    String invalidMessage = 'Lien invalide.',
    String failureMessage = 'Impossible d’ouvrir le lien.',
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(invalidMessage)));
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _openNewsLink(String url) {
    return _openExternalUrl(
      url,
      failureMessage: 'Impossible d\'ouvrir la news.',
    );
  }

  bool _isEtfQuote(QuoteDetail? quote) {
    return (_quoteType ?? quote?.quoteType)?.toUpperCase() == 'ETF';
  }

  Widget _buildQuoteView(ThemeData theme) {
    final quote = _quote;
    final priceText = _formatCurrency(quote?.regularMarketPrice);
    // For 1D, always use Yahoo's official values (vs previous close).
    // The chart delta computes % from today's open, which gives a wrong result.
    final delta =
        _selectedInterval == ChartInterval.oneDay ? null : _periodDelta;
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
    final isEtf = _isEtfQuote(quote);
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

    final decisionIndicators = buildDecisionIndicators(
      quote,
      _financialSnapshot,
    );

    final highlights = _buildHighlights(quote);
    final coverage = _buildDataCoverageSummary(
      quote,
      _financialSnapshot,
      isEtf,
    );
    final fundamentalGroups = _buildFundamentalMetricGroups(quote, isEtf);

    final overview = _buildEssentialPage(
      theme: theme,
      changeText: changeText,
      percentText: percentText,
      changePositive: changePositive,
      periodLabel: periodLabel,
      lastUpdate: lastUpdate,
      essentialMetrics: essentialMetrics,
      highlights: highlights,
      coverage: coverage,
    );

    final heroCard = _AssetHeroCard(
      title: _displayName ?? _ticker ?? 'Actif',
      ticker: _ticker ?? '—',
      quoteType: isEtf ? 'ETF' : 'Action',
      exchange: _exchange ?? 'Marché indisponible',
      currency: _currency ?? '—',
      sectorOrCategory:
          isEtf
              ? (_financialSnapshot?.fundCategory ??
                  _financialSnapshot?.fundFamily)
              : (_financialSnapshot?.sector ?? _financialSnapshot?.industry),
      priceText: priceText ?? '—',
      changeText: [
        if (changeText != null) changeText,
        if (percentText != null) percentText,
      ].join(' · '),
      changePositive: changePositive,
      lastUpdate: lastUpdate,
      portfolioButton: _buildPortfolioButton(theme),
      favoriteButton: _buildFavoriteButton(theme),
      tradeButtons: _buildTradeButtons(theme),
    );

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: heroCard,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              child: ColoredBox(
                color: backgroundColor,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _InfoTabStrip(),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            overview,
            _buildFundamentalsTab(
              theme: theme,
              complementaryMetrics: complementaryMetrics,
              decisionIndicators: decisionIndicators,
              groups: fundamentalGroups,
            ),
            _buildProfileTab(
              theme: theme,
              quote: quote,
              coverage: coverage,
            ),
            _buildNewsPage(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFundamentalsTab({
    required ThemeData theme,
    required List<_MetricEntry> complementaryMetrics,
    required List<DecisionIndicator> decisionIndicators,
    required List<_MetricGroupData> groups,
  }) {
    final showDecisionLoading =
        _fundamentalLoading && _financialSnapshot == null;
    final showDecisionError =
        _fundamentalError != null &&
        !_fundamentalLoading &&
        _financialSnapshot == null;

    final children = <Widget>[];

    children.add(_buildFundamentalHeroCard());

    final historyCards = _buildHistoryCards();
    if (historyCards.isNotEmpty) {
      children
        ..add(const SizedBox(height: 16))
        ..add(_SectionHeader(label: 'Historique synthétique'))
        ..add(const SizedBox(height: 12))
        ..addAll(historyCards);
    }

    children
      ..add(const SizedBox(height: 16))
      ..add(_buildDividendOverviewCard(theme, compact: false));

    for (final group in groups) {
      children
        ..add(const SizedBox(height: 16))
        ..add(
          _MetricGroupCard(
            title: group.title,
            subtitle: group.subtitle,
            metrics: group.metrics,
          ),
        );
    }

    if (complementaryMetrics.isNotEmpty) {
      children
        ..add(const SizedBox(height: 16))
        ..add(
          _MetricGroupCard(
            title: 'Marché & liquidité',
            subtitle:
                'Repères complémentaires liés au cours, aux volumes et au comportement de marché.',
            metrics: complementaryMetrics,
          ),
        );
    }

    children
      ..add(const SizedBox(height: 16))
      ..add(_SectionHeader(label: 'Indicateurs pédagogiques'))
      ..add(const SizedBox(height: 12));

    if (showDecisionLoading) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else {
      if (showDecisionError) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _fundamentalError!,
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
      key: const PageStorageKey<String>('fundamentals_page'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _buildProfileTab({
    required ThemeData theme,
    required QuoteDetail? quote,
    required _DataCoverageSummary coverage,
  }) {
    final isEtf = _isEtfQuote(quote);
    final snapshot = _financialSnapshot;
    final profileSummary =
        isEtf ? snapshot?.fundSummary : snapshot?.longBusinessSummary;
    final facts = <_MetricEntry>[
      if (isEtf && snapshot?.fundCategory != null)
        _MetricEntry('Catégorie', snapshot!.fundCategory),
      if (isEtf && snapshot?.fundFamily != null)
        _MetricEntry('Famille', snapshot!.fundFamily),
      if (isEtf && snapshot?.fundLegalType != null)
        _MetricEntry('Structure', snapshot!.fundLegalType),
      if (isEtf && snapshot?.fundInceptionDate != null)
        _MetricEntry('Création', _formatDate(snapshot!.fundInceptionDate)),
      if (!isEtf && snapshot?.sector != null)
        _MetricEntry('Secteur', snapshot!.sector),
      if (!isEtf && snapshot?.industry != null)
        _MetricEntry('Industrie', snapshot!.industry),
      if (_exchange != null && _exchange!.trim().isNotEmpty)
        _MetricEntry('Marché', _exchange),
      if (_currency != null && _currency!.trim().isNotEmpty)
        _MetricEntry('Devise', _currency),
      if (snapshot?.website != null)
        _MetricEntry('Site web', snapshot!.website),
    ];

    return ListView(
      key: const PageStorageKey<String>('profile_page'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildDataCoverageCard(theme, coverage),
        const SizedBox(height: 16),
        _InfoSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEtf ? 'Profil du fonds' : 'Profil de l’entreprise',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profileSummary ??
                    'Les informations de profil détaillées ne sont pas encore disponibles pour cet actif.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (snapshot?.website != null) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed:
                        () => _openExternalUrl(
                          snapshot!.website!,
                          failureMessage: 'Impossible d’ouvrir le site.',
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _wine,
                      side: BorderSide(color: _wine.withValues(alpha: 0.24)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Ouvrir le site'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MetricGroupCard(
            title: isEtf ? 'Identité du fonds' : 'Identité de l’actif',
            subtitle:
                'Faits descriptifs utiles pour contextualiser la lecture des données financières.',
            metrics: facts,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildHistoryCards() {
    final data = _fundamentalGameData;
    if (data == null) return const <Widget>[];

    final cards = <Widget>[];
    if (data.revenueHistory.isNotEmpty) {
      cards.add(
        _HistorySeriesCard(
          title: 'Chiffre d’affaires',
          subtitle: 'Dernières années disponibles',
          values: data.revenueHistory,
          formatter: (value) => _formatLargeNumber(value) ?? '—',
        ),
      );
    }
    if (data.epsHistory.isNotEmpty) {
      cards.add(
        _HistorySeriesCard(
          title: 'BPA',
          subtitle: 'Bénéfice par action',
          values: data.epsHistory,
          formatter: (value) => _formatCurrency(value) ?? '—',
        ),
      );
    }
    final dividendHistory =
        data.dividendPerYear.entries
            .map(
              (entry) => YearlyMetricValue(year: entry.key, value: entry.value),
            )
            .toList()
          ..sort((a, b) => b.year.compareTo(a.year));
    if (dividendHistory.isNotEmpty) {
      cards.add(
        _HistorySeriesCard(
          title: 'Dividendes annuels',
          subtitle: 'Montants observés par année',
          values: dividendHistory,
          formatter: (value) => _formatCurrency(value) ?? '—',
        ),
      );
    }

    if (cards.isEmpty) return const <Widget>[];
    return cards
        .expand((card) => <Widget>[card, const SizedBox(height: 12)])
        .toList()
      ..removeLast();
  }

  Widget _buildDividendOverviewCard(ThemeData theme, {bool compact = true}) {
    final data = _fundamentalGameData;
    final history = data?.dividendPerYear.entries.toList() ?? [];
    history.sort((a, b) => b.key.compareTo(a.key));
    final recentHistory = history.take(compact ? 3 : 5).toList();
    final hasDividendData =
        _dividendLoading ||
        _dividendEvent != null ||
        recentHistory.isNotEmpty ||
        (_financialSnapshot?.dividendYield != null);

    if (!hasDividendData) {
      return _InfoSectionCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.payments_outlined, color: _wine),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dividendes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aucune donnée de distribution exploitable n’a été trouvée pour cet actif.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _InfoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dividendes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            compact
                ? 'Calendrier et historique récent de distribution quand les données sont disponibles.'
                : 'Calendrier, fréquence et historique annuel de distribution, à titre purement descriptif.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (_dividendLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_financialSnapshot?.dividendYield != null)
                  _OverviewStatCard(
                    label: 'Rendement',
                    value:
                        _formatPercent(
                          _financialSnapshot!.dividendYield! * 100,
                        ) ??
                        '—',
                    accent: Colors.orange.shade800,
                    soft: Colors.orange.withValues(alpha: 0.10),
                  ),
                if (_dividendEvent?.amount != null)
                  _OverviewStatCard(
                    label: 'Montant',
                    value:
                        _formatCurrency(_dividendEvent!.amount) ??
                        _dividendEvent!.amount!.toStringAsFixed(2),
                    accent: _wine,
                    soft: _wine.withValues(alpha: 0.10),
                  ),
                if (_dividendEvent?.frequency != null)
                  _OverviewStatCard(
                    label: 'Fréquence',
                    value: _dividendEvent!.frequency!,
                    accent: textColor,
                    soft: _chipBg,
                  ),
              ],
            ),
            if (_dividendEvent != null || _dividendError != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_dividendEvent?.exDate != null)
                    _ContextPill(
                      icon: Icons.event_available_rounded,
                      label: 'Ex-date ${_formatDate(_dividendEvent!.exDate)}',
                      foreground: _wine,
                      background: _wine.withValues(alpha: 0.10),
                    ),
                  if (_dividendEvent?.paymentDate != null)
                    _ContextPill(
                      icon: Icons.calendar_month_rounded,
                      label:
                          'Paiement ${_formatDate(_dividendEvent!.paymentDate)}',
                      foreground: Colors.green.shade700,
                      background: Colors.green.withValues(alpha: 0.10),
                    ),
                  if (_dividendError != null)
                    _ContextPill(
                      icon: Icons.info_outline_rounded,
                      label: _dividendError!,
                      foreground: Colors.black54,
                      background: _chipBg,
                    ),
                ],
              ),
            ],
            if (recentHistory.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                compact ? 'Historique récent' : 'Historique annuel',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    recentHistory
                        .map(
                          (entry) => _YearValueChip(
                            year: entry.key,
                            value: _formatCurrency(entry.value) ?? '—',
                          ),
                        )
                        .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<_ChartAnnotationData> _buildChartAnnotations() {
    final quote = _quote;
    final annotations = <_ChartAnnotationData>[];
    if (quote?.fiftyTwoWeekHigh != null && quote?.fiftyTwoWeekLow != null) {
      annotations.add(
        _ChartAnnotationData(
          label:
              '52 sem. ${_formatCurrency(quote!.fiftyTwoWeekLow)} → ${_formatCurrency(quote.fiftyTwoWeekHigh)}',
          icon: Icons.unfold_more_rounded,
          tint: _chipBg,
          foreground: Colors.black87,
        ),
      );
    }
    if (_periodDelta != null && _selectedInterval != ChartInterval.oneDay) {
      annotations.add(
        _ChartAnnotationData(
          label:
              'Période ${_formatSignedCurrency(_periodDelta!.change)} · ${_formatPercent(_periodDelta!.percent) ?? '—'}',
          icon: Icons.show_chart_rounded,
          tint:
              _periodDelta!.change >= 0
                  ? Colors.green.withValues(alpha: 0.10)
                  : Colors.red.withValues(alpha: 0.10),
          foreground:
              _periodDelta!.change >= 0
                  ? Colors.green.shade700
                  : Colors.red.shade700,
        ),
      );
    }
    if (_dividendEvent?.exDate != null) {
      annotations.add(
        _ChartAnnotationData(
          label: 'Ex-div. ${_formatDate(_dividendEvent!.exDate)}',
          icon: Icons.payments_outlined,
          tint: Colors.orange.withValues(alpha: 0.10),
          foreground: Colors.orange.shade800,
        ),
      );
    }
    return annotations;
  }

  _DataCoverageSummary _buildDataCoverageSummary(
    QuoteDetail? quote,
    FinancialSnapshot? snapshot,
    bool isEtf,
  ) {
    final checks = <MapEntry<String, bool>>[
      MapEntry('prix', quote?.regularMarketPrice != null),
      MapEntry('graphique', _chartPoints.isNotEmpty),
      MapEntry(
        'devise',
        ((_currency ?? quote?.currency)?.trim().isNotEmpty) ?? false,
      ),
      MapEntry(
        'marché',
        ((_exchange ?? quote?.fullExchangeName)?.trim().isNotEmpty) ?? false,
      ),
      MapEntry('variation', _periodDelta != null),
      if (isEtf) ...[
        MapEntry('catégorie', snapshot?.fundCategory != null),
        MapEntry('frais', snapshot?.expenseRatio != null),
        MapEntry('encours', snapshot?.netAssets != null),
        MapEntry('perf. YTD', snapshot?.ytdReturn != null),
        MapEntry('profil', snapshot?.fundSummary != null),
      ] else ...[
        MapEntry('secteur', snapshot?.sector != null),
        MapEntry('industrie', snapshot?.industry != null),
        MapEntry('résumé', snapshot?.longBusinessSummary != null),
        MapEntry('croissance', snapshot?.revenueGrowth != null),
        MapEntry('cash-flow', snapshot?.freeCashflow != null),
      ],
    ];
    final total = checks.length;
    final available = checks.where((entry) => entry.value).length;
    final ratio = total == 0 ? 0.0 : available / total;
    final missing =
        checks
            .where((entry) => !entry.value)
            .map((entry) => entry.key)
            .take(4)
            .toList();
    if (ratio >= 0.75) {
      return _DataCoverageSummary(
        label: 'Couverture élevée',
        ratioLabel: '$available/$total champs',
        accent: Colors.green.shade700,
        soft: Colors.green.withValues(alpha: 0.10),
        icon: Icons.verified_rounded,
        missing: missing,
      );
    }
    if (ratio >= 0.45) {
      return _DataCoverageSummary(
        label: 'Couverture intermédiaire',
        ratioLabel: '$available/$total champs',
        accent: Colors.orange.shade800,
        soft: Colors.orange.withValues(alpha: 0.10),
        icon: Icons.rule_folder_outlined,
        missing: missing,
      );
    }
    return _DataCoverageSummary(
      label: 'Couverture partielle',
      ratioLabel: '$available/$total champs',
      accent: Colors.black54,
      soft: _chipBg,
      icon: Icons.info_outline_rounded,
      missing: missing,
    );
  }

  List<_MetricGroupData> _buildFundamentalMetricGroups(
    QuoteDetail? quote,
    bool isEtf,
  ) {
    final snapshot = _financialSnapshot;
    if (snapshot == null) return const <_MetricGroupData>[];

    List<_MetricEntry> entries(List<_MetricEntry?> values) =>
        values.whereType<_MetricEntry>().toList();

    if (isEtf) {
      return [
        _MetricGroupData(
          title: 'Structure du fonds',
          subtitle: 'Nature du véhicule, frais et encours.',
          metrics: entries([
            if (snapshot.fundCategory != null)
              _MetricEntry('Catégorie', snapshot.fundCategory),
            if (snapshot.fundFamily != null)
              _MetricEntry('Famille', snapshot.fundFamily),
            if (snapshot.fundLegalType != null)
              _MetricEntry('Structure', snapshot.fundLegalType),
            if (snapshot.netAssets != null)
              _MetricEntry(
                'Actifs nets',
                _formatLargeNumber(snapshot.netAssets),
                _formatCurrency(snapshot.netAssets, withSeparators: true),
              ),
            if (snapshot.expenseRatio != null)
              _MetricEntry(
                'Frais annuels',
                _formatPercent(snapshot.expenseRatio! * 100),
              ),
          ]),
        ),
        _MetricGroupData(
          title: 'Performance & risque',
          subtitle: 'Mesures descriptives disponibles pour situer le fonds.',
          metrics: entries([
            if (snapshot.ytdReturn != null)
              _MetricEntry(
                'Perf. YTD',
                _formatPercent(snapshot.ytdReturn! * 100),
              ),
            if (snapshot.threeYearAverageReturn != null)
              _MetricEntry(
                'Perf. 3 ans',
                _formatPercent(snapshot.threeYearAverageReturn! * 100),
              ),
            if (snapshot.betaThreeYear != null)
              _MetricEntry(
                'Bêta 3 ans',
                _formatNumber(snapshot.betaThreeYear, fractionDigits: 2),
              ),
            if (quote?.dividendYield != null)
              _MetricEntry(
                'Rdt dividende',
                _formatPercent(quote!.dividendYield! * 100),
              ),
          ]),
        ),
      ].where((group) => group.metrics.isNotEmpty).toList();
    }

    return [
      _MetricGroupData(
        title: 'Valorisation',
        subtitle:
            'Repères de prix relatifs au résultat, à l’activité et aux capitaux.',
        metrics: entries([
          if (quote?.trailingPE != null ||
              _fundamentalGameData?.trailingPe != null)
            _MetricEntry(
              'PER (TTM)',
              _formatNumber(
                quote?.trailingPE ?? _fundamentalGameData?.trailingPe,
                fractionDigits: 2,
              ),
            ),
          if (quote?.forwardPE != null)
            _MetricEntry(
              'PER (forward)',
              _formatNumber(quote?.forwardPE, fractionDigits: 2),
            ),
          if (snapshot.pegRatio != null)
            _MetricEntry(
              'PEG',
              _formatNumber(snapshot.pegRatio, fractionDigits: 2),
            ),
          if (snapshot.enterpriseToEbitda != null)
            _MetricEntry(
              'EV/EBITDA',
              _formatNumber(snapshot.enterpriseToEbitda, fractionDigits: 2),
            ),
          if (snapshot.enterpriseToRevenue != null)
            _MetricEntry(
              'EV/CA',
              _formatNumber(snapshot.enterpriseToRevenue, fractionDigits: 2),
            ),
          if (snapshot.priceToBook != null)
            _MetricEntry(
              'Price to book',
              _formatNumber(snapshot.priceToBook, fractionDigits: 2),
            ),
        ]),
      ),
      _MetricGroupData(
        title: 'Croissance',
        subtitle: 'Évolution récente de l’activité et du bénéfice par action.',
        metrics: entries([
          if (snapshot.revenueGrowth != null)
            _MetricEntry(
              'Croissance CA',
              _formatPercent(snapshot.revenueGrowth! * 100),
            ),
          if (snapshot.earningsGrowth != null)
            _MetricEntry(
              'Croissance BPA',
              _formatPercent(snapshot.earningsGrowth! * 100),
            ),
          if (snapshot.revenue != null)
            _MetricEntry(
              'Chiffre d’affaires',
              _formatLargeNumber(snapshot.revenue),
            ),
          if (snapshot.eps != null)
            _MetricEntry('BPA', _formatCurrency(snapshot.eps)),
        ]),
      ),
      _MetricGroupData(
        title: 'Rentabilité',
        subtitle:
            'Capacité à convertir l’activité en marge et rendement des fonds.',
        metrics: entries([
          if (snapshot.returnOnEquity != null)
            _MetricEntry('ROE', _formatPercent(snapshot.returnOnEquity! * 100)),
          if (snapshot.returnOnAssets != null)
            _MetricEntry('ROA', _formatPercent(snapshot.returnOnAssets! * 100)),
          if (snapshot.operatingMargin != null)
            _MetricEntry(
              'Marge op.',
              _formatPercent(snapshot.operatingMargin! * 100),
            ),
          if (snapshot.netMargin != null)
            _MetricEntry(
              'Marge nette',
              _formatPercent(snapshot.netMargin! * 100),
            ),
          if (snapshot.netIncome != null)
            _MetricEntry(
              'Résultat net',
              _formatLargeNumber(snapshot.netIncome),
            ),
        ]),
      ),
      _MetricGroupData(
        title: 'Bilan',
        subtitle:
            'Structure de financement, liquidité et niveau d’endettement.',
        metrics: entries([
          if (snapshot.totalCash != null)
            _MetricEntry('Cash total', _formatLargeNumber(snapshot.totalCash)),
          if (snapshot.totalDebt != null)
            _MetricEntry(
              'Dette totale',
              _formatLargeNumber(snapshot.totalDebt),
            ),
          if (snapshot.debtToEbitda != null)
            _MetricEntry(
              'Dette/EBITDA',
              _formatNumber(snapshot.debtToEbitda, fractionDigits: 2),
            ),
          if (snapshot.equity != null)
            _MetricEntry(
              'Capitaux propres',
              _formatLargeNumber(snapshot.equity),
            ),
          if (snapshot.bookValue != null)
            _MetricEntry('Book value', _formatLargeNumber(snapshot.bookValue)),
        ]),
      ),
      _MetricGroupData(
        title: 'Cash-flow',
        subtitle: 'Génération de trésorerie et intensité d’investissement.',
        metrics: entries([
          if (snapshot.operatingCashflow != null)
            _MetricEntry(
              'Cash-flow op.',
              _formatLargeNumber(snapshot.operatingCashflow),
            ),
          if (snapshot.capitalExpenditures != null)
            _MetricEntry(
              'Capex',
              _formatLargeNumber(snapshot.capitalExpenditures),
            ),
          if (snapshot.freeCashflow != null)
            _MetricEntry(
              'Free cash-flow',
              _formatLargeNumber(snapshot.freeCashflow),
            ),
          if (snapshot.freeCashflowYield != null)
            _MetricEntry(
              'FCF yield',
              _formatPercent(snapshot.freeCashflowYield! * 100),
            ),
          if (snapshot.capexToRevenue != null)
            _MetricEntry(
              'Capex/CA',
              _formatPercent(snapshot.capexToRevenue! * 100),
            ),
        ]),
      ),
      _MetricGroupData(
        title: 'Distribution',
        subtitle:
            'Politique de distribution observée à partir des données publiques.',
        metrics: entries([
          if (snapshot.dividendYield != null)
            _MetricEntry(
              'Rdt dividende',
              _formatPercent(snapshot.dividendYield! * 100),
            ),
          if (snapshot.payoutRatio != null)
            _MetricEntry(
              'Payout ratio',
              _formatPercent(snapshot.payoutRatio! * 100),
            ),
          if (snapshot.trailingAnnualDividendRate != null)
            _MetricEntry(
              'Dividende annuel',
              _formatCurrency(snapshot.trailingAnnualDividendRate),
            ),
          if (snapshot.trailingAnnualDividendYield != null)
            _MetricEntry(
              'Yield annuel',
              _formatPercent(snapshot.trailingAnnualDividendYield! * 100),
            ),
        ]),
      ),
    ].where((group) => group.metrics.isNotEmpty).toList();
  }

  Widget _buildDataCoverageCard(
    ThemeData theme,
    _DataCoverageSummary coverage,
  ) {
    return _InfoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Complétude des données',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              _ContextPill(
                icon: coverage.icon,
                label: coverage.label,
                foreground: coverage.accent,
                background: coverage.soft,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Cette jauge indique combien de champs utiles sont actuellement exploitables pour cet actif.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: coverage.progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8EBEF),
              valueColor: AlwaysStoppedAnimation<Color>(coverage.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            coverage.ratioLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: coverage.accent,
            ),
          ),
          if (coverage.missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Champs encore partiels : ${coverage.missing.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  FundamentalScorePresentation _buildFundamentalPresentation() {
    return buildFundamentalScorePresentation(
      loading: _fundamentalLoading,
      error: _fundamentalError,
      data: _fundamentalGameData,
      analysis: _fundamentalAnalysis,
    );
  }

  Widget _buildFundamentalHeroCard() {
    final presentation = _buildFundamentalPresentation();
    return FundamentalScoreHeroCard(
      presentation: presentation,
      onTap: presentation.canOpenDetails ? _showFundamentalScoreDetails : null,
    );
  }

  void _showFundamentalScoreDetails() {
    final analysis = _fundamentalAnalysis;
    if (analysis == null) return;

    final presentation = _buildFundamentalPresentation();
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lecture fondamentale',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Repère quantitatif à visée pédagogique, calculé sur des données publiques sans intention de recommandation.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: detailsColor1.withValues(alpha: .28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: detailsColor2.withValues(alpha: .08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          presentation.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: textColor),
                            children: [
                              TextSpan(
                                text:
                                    analysis.finalScore == null
                                        ? 'N/A'
                                        : analysis.finalScore!.toStringAsFixed(
                                          0,
                                        ),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const TextSpan(
                                text: '/100',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FundamentalSheetChip(
                              label:
                                  presentation.verdictLabel ??
                                  'Lecture informative',
                              backgroundColor: _fundamentalVerdictColor(
                                presentation.verdictLabel,
                              ).withValues(alpha: .12),
                              foregroundColor: _fundamentalVerdictColor(
                                presentation.verdictLabel,
                              ),
                            ),
                            if (presentation.confidenceLabel != null)
                              _FundamentalSheetChip(
                                label: presentation.confidenceLabel!,
                                backgroundColor: detailsColor1.withValues(
                                  alpha: .14,
                                ),
                                foregroundColor: textColor,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          presentation.disclaimer,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        if (presentation.summary != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            presentation.summary!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (presentation.strongestSubScore != null ||
                      presentation.weakestSubScore != null) ...[
                    _SectionHeader(label: 'Lecture rapide'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (presentation.strongestSubScore != null)
                          Expanded(
                            child: _FundamentalFocusCard(
                              title: 'Force',
                              value: presentation.strongestSubScore!.title,
                              score:
                                  presentation.strongestSubScore!.score
                                      ?.toStringAsFixed(0) ??
                                  'N/A',
                              accentColor: detailsColor1,
                            ),
                          ),
                        if (presentation.strongestSubScore != null &&
                            presentation.weakestSubScore != null)
                          const SizedBox(width: 12),
                        if (presentation.weakestSubScore != null)
                          Expanded(
                            child: _FundamentalFocusCard(
                              title: 'Vigilance',
                              value: presentation.weakestSubScore!.title,
                              score:
                                  presentation.weakestSubScore!.score
                                      ?.toStringAsFixed(0) ??
                                  'N/A',
                              accentColor: detailsColor2,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  _SectionHeader(label: 'Sous-scores'),
                  const SizedBox(height: 12),
                  ...analysis.subScores.map(
                    (subScore) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FundamentalSubScoreCard(subScore: subScore),
                    ),
                  ),
                  if (analysis.missingData.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionHeader(label: 'Données manquantes'),
                    const SizedBox(height: 12),
                    ...analysis.missingData.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: detailsColor2.withValues(alpha: .8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _fundamentalVerdictColor(String? verdictLabel) {
    switch (verdictLabel) {
      case 'Lecture élevée':
        return const Color(0xFF8C6A12);
      case 'Lecture solide':
        return detailsColor2;
      case 'Lecture mitigée':
        return const Color(0xFF6F657D);
      case 'Lecture fragile':
        return const Color(0xFF4E3A66);
      default:
        return textColor;
    }
  }

  String _renderIndicatorValue(DecisionIndicator indicator) {
    if (indicator.hasCustomDisplay) {
      return indicator.customDisplay!;
    }
    final formatted = _formatDecisionNumeric(
      indicator.value,
      indicator.valueType,
    );
    if (formatted == null) return 'Donnée manquante';
    if (indicator.primaryLabel != null) {
      return '${indicator.primaryLabel}: $formatted';
    }
    return formatted;
  }

  String? _renderIndicatorSecondary(DecisionIndicator indicator) {
    if (!indicator.hasSecondaryValue) return null;
    final formatted = _formatDecisionNumeric(
      indicator.secondaryValue,
      indicator.valueType,
    );
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
              Text(indicator.definition, style: theme.textTheme.bodyMedium),
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
              TextButton(onPressed: _loadNews, child: const Text('Réessayer')),
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

    final filteredItems = _filteredNewsItems();

    return ListView(
      key: const PageStorageKey<String>('news_page'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _InfoSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actualités',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Filtre les news directement liées au ticker, à tes favoris ou plus larges de marché.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _NewsFilter.values
                        .map(
                          (filter) => _SelectablePill(
                            label: _newsFilterLabel(filter),
                            selected: _newsFilter == filter,
                            onTap: () => setState(() => _newsFilter = filter),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '${filteredItems.length} article(s) affiché(s)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _wine,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filteredItems.isEmpty)
          _InfoSectionCard(
            child: Text(
              'Aucune actualité ne correspond au filtre sélectionné.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...filteredItems.expand((item) {
              final published = _formatDateTime(item.publishedAt);
              return <Widget>[
                _NewsArticleCard(
                  article: item,
                  subtitle:
                      published == null
                          ? item.publisher
                          : '${item.publisher} • $published',
                  onTap: () => _openNewsLink(item.url),
                  highlightPrimary: _newsTickerMatches.contains(item.id),
                  highlightFavorite: _newsFavoriteMatches.contains(item.id),
                  macroContext: _isMacroNews(item),
                ),
                const SizedBox(height: 12),
              ];
            }).toList()
            ..removeLast(),
      ],
    );
  }

  List<FinanceNewsItem> _filteredNewsItems() {
    switch (_newsFilter) {
      case _NewsFilter.all:
        return _newsItems;
      case _NewsFilter.ticker:
        return _newsItems
            .where((item) => _newsTickerMatches.contains(item.id))
            .toList();
      case _NewsFilter.favorites:
        return _newsItems
            .where((item) => _newsFavoriteMatches.contains(item.id))
            .toList();
      case _NewsFilter.macro:
        return _newsItems.where(_isMacroNews).toList();
    }
  }

  bool _isMacroNews(FinanceNewsItem item) {
    return !_newsTickerMatches.contains(item.id) &&
        !_newsFavoriteMatches.contains(item.id);
  }

  String _newsFilterLabel(_NewsFilter filter) {
    switch (filter) {
      case _NewsFilter.all:
        return 'Toutes';
      case _NewsFilter.ticker:
        return 'Ticker';
      case _NewsFilter.favorites:
        return 'Favoris';
      case _NewsFilter.macro:
        return 'Macro';
    }
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
      if (!isEtf &&
          (quote.trailingPE != null ||
              _fundamentalGameData?.trailingPe != null))
        _MetricEntry(
          'PER (TTM)',
          _formatNumber(
            quote.trailingPE ?? _fundamentalGameData?.trailingPe,
            fractionDigits: 2,
          ),
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
        _MetricEntry('Perf. YTD', _formatPercent(snapshot!.ytdReturn! * 100)),
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
      if (isEtf &&
          snapshot?.fundCategory != null &&
          snapshot!.fundCategory!.isNotEmpty)
        _MetricEntry('Catégorie', snapshot.fundCategory!),
      if (!isEtf && snapshot?.returnOnEquity != null)
        _MetricEntry('ROE', _formatPercent(snapshot!.returnOnEquity! * 100)),
      if (!isEtf && snapshot?.returnOnAssets != null)
        _MetricEntry('ROA', _formatPercent(snapshot!.returnOnAssets! * 100)),
      if (!isEtf && snapshot?.operatingMargin != null)
        _MetricEntry(
          'Marge op.',
          _formatPercent(snapshot!.operatingMargin! * 100),
        ),
      if (!isEtf && snapshot?.netMargin != null)
        _MetricEntry('Marge nette', _formatPercent(snapshot!.netMargin! * 100)),
      if (!isEtf && snapshot?.revenueGrowth != null)
        _MetricEntry(
          'Croissance CA',
          _formatPercent(snapshot!.revenueGrowth! * 100),
        ),
      if (!isEtf && snapshot?.earningsGrowth != null)
        _MetricEntry(
          'Croissance BPA',
          _formatPercent(snapshot!.earningsGrowth! * 100),
        ),
      if (!isEtf && snapshot?.freeCashflowYield != null)
        _MetricEntry(
          'FCF yield',
          _formatPercent(snapshot!.freeCashflowYield! * 100),
        ),
      if (!isEtf && snapshot?.capexToRevenue != null)
        _MetricEntry(
          'Capex/CA',
          _formatPercent(snapshot!.capexToRevenue! * 100),
        ),
      if (quote.averageDailyVolume3Month != null)
        _MetricEntry(
          'ADV 3m',
          _formatLargeNumber(quote.averageDailyVolume3Month),
          _formatInteger(quote.averageDailyVolume3Month),
        ),
      if (quote.regularMarketVolume != null &&
          quote.averageDailyVolume3Month != null &&
          quote.averageDailyVolume3Month! > 0)
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
          icon:
              changePercent >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
          color:
              changePercent >= 0 ? Colors.green.shade600 : Colors.red.shade600,
        ),
      );
    }

    if (quote.regularMarketVolume != null &&
        quote.averageDailyVolume3Month != null &&
        quote.averageDailyVolume3Month! > 0) {
      final ratio =
          quote.regularMarketVolume! / quote.averageDailyVolume3Month!;
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
          value: _formatPercent(quote.dividendYield! * 100) ?? '—',
          icon: Icons.savings_rounded,
          color: Colors.orange.shade700,
        ),
      );
    }

    if (quote.regularMarketPrice != null &&
        quote.fiftyTwoWeekHigh != null &&
        quote.fiftyTwoWeekLow != null) {
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

  String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
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
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.labelBuilder,
    required this.currencyFormatter,
    required this.percentFormatter,
    this.annotations = const <_ChartAnnotationData>[],
  });

  final List<HistoricalPoint> points;
  final bool loading;
  final String? error;
  final ChartInterval interval;
  final ValueChanged<ChartInterval> onIntervalSelected;
  final _ChartDisplayMode displayMode;
  final ValueChanged<_ChartDisplayMode> onDisplayModeChanged;
  final String Function(DateTime, ChartInterval) labelBuilder;
  final String? Function(double?) currencyFormatter;
  final String? Function(double?) percentFormatter;
  final List<_ChartAnnotationData> annotations;

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
    final displayPoints = _displayPoints();
    final startPoint = hasData ? displayPoints.first : null;
    final endPoint = hasData ? displayPoints.last : null;
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
        startPoint != null ? _formatValue(startPoint.close) : '—';
    final endPrice = endPoint != null ? _formatValue(endPoint.close) : '—';

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _ChartDisplayMode.values
                    .map(
                      (mode) => _SelectablePill(
                        label:
                            mode == _ChartDisplayMode.price
                                ? 'Prix'
                                : 'Perf. %',
                        selected: displayMode == mode,
                        onTap: () => onDisplayModeChanged(mode),
                      ),
                    )
                    .toList(),
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
          if (annotations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  annotations
                      .map(
                        (annotation) => _ContextPill(
                          icon: annotation.icon,
                          label: annotation.label,
                          foreground: annotation.foreground,
                          background: annotation.tint,
                        ),
                      )
                      .toList(),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
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
                      child: _InteractiveLineChart(
                        points: displayPoints,
                        lineColor: lineColor,
                        fillColor: fillColor,
                        valueFormatter: _formatValue,
                        labelBuilder: labelBuilder,
                        interval: interval,
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

  List<HistoricalPoint> _displayPoints() {
    if (displayMode == _ChartDisplayMode.price || points.isEmpty) {
      return points;
    }
    final base = points.first.close;
    if (base.abs() < 1e-9) return points;
    return points
        .map(
          (point) => HistoricalPoint(
            time: point.time,
            close: ((point.close / base) - 1) * 100,
          ),
        )
        .toList();
  }

  String _formatValue(double value) {
    if (displayMode == _ChartDisplayMode.performance) {
      final formatted = percentFormatter(value);
      return formatted ?? '${value.toStringAsFixed(2)} %';
    }
    return currencyFormatter(value) ?? '—';
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(highlight.icon, color: highlight.color, size: 18),
                const SizedBox(height: 4),
                Text(
                  highlight.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _infoScaledFont(context, 11),
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  highlight.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _infoScaledFont(context, 14),
                    fontWeight: FontWeight.w700,
                    color: highlight.color,
                  ),
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

/// Version interactive: grid verticale, touche/drag pour voir le prix et la date.
class _InteractiveLineChart extends StatefulWidget {
  const _InteractiveLineChart({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.valueFormatter,
    required this.labelBuilder,
    required this.interval,
  });

  final List<HistoricalPoint> points;
  final Color lineColor;
  final Color fillColor;
  final String Function(double value) valueFormatter;
  final String Function(DateTime, ChartInterval) labelBuilder;
  final ChartInterval interval;

  @override
  State<_InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<_InteractiveLineChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanDown: (d) => _onTouch(d.localPosition, context.size?.width ?? 0),
      onPanUpdate: (d) => _onTouch(d.localPosition, context.size?.width ?? 0),
      onPanEnd: (_) => setState(() => _hoverIndex = null),
      onTapUp: (_) => setState(() => _hoverIndex = null),
      child: Stack(
        children: [
          CustomPaint(
            painter: _MinimalLineChartPainter(
              points: widget.points,
              lineColor: widget.lineColor,
              fillColor: widget.fillColor,
              showHorizontalGrid: true,
              verticalLineX:
                  _hoverIndex != null ? _xForIndex(_hoverIndex!) : null,
            ),
            child: const SizedBox.expand(),
          ),
          if (_hoverIndex != null)
            Positioned.fill(
              child: _TooltipOverlay(
                point: widget.points[_hoverIndex!],
                x: _xForIndex(_hoverIndex!),
                valueFormatter: widget.valueFormatter,
                labelBuilder: widget.labelBuilder,
                interval: widget.interval,
              ),
            ),
        ],
      ),
    );
  }

  void _onTouch(Offset localPosition, double width) {
    _updateHover(localPosition.dx, width);
  }

  void _updateHover(double dx, double width) {
    if (widget.points.isEmpty || width <= 0) return;
    final clampedX = dx.clamp(0, width);
    final idx = ((clampedX / width) * (widget.points.length - 1)).round();
    setState(() => _hoverIndex = idx.clamp(0, widget.points.length - 1));
  }

  double _xForIndex(int index) {
    if (widget.points.length <= 1) return 0;
    final fraction = index / (widget.points.length - 1);
    return fraction;
  }
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.point,
    required this.x,
    required this.valueFormatter,
    required this.labelBuilder,
    required this.interval,
  });

  final HistoricalPoint point;

  /// x fraction [0,1] of the chart width.
  final double x;
  final String Function(double value) valueFormatter;
  final String Function(DateTime, ChartInterval) labelBuilder;
  final ChartInterval interval;

  @override
  Widget build(BuildContext context) {
    final price = valueFormatter(point.close);
    final dateLabel = labelBuilder(point.time, interval);
    return LayoutBuilder(
      builder: (context, constraints) {
        final px = x * constraints.maxWidth;
        final tooltipWidth = 140.0;
        final left = (px - tooltipWidth / 2).clamp(
          8.0,
          constraints.maxWidth - tooltipWidth - 8,
        );

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _VerticalCursorPainter(px: px),
              ),
            ),
            Positioned(
              left: left,
              top: 8,
              child: Container(
                width: tooltipWidth,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VerticalCursorPainter extends CustomPainter {
  const _VerticalCursorPainter({required this.px});
  final double px;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = Colors.black.withOpacity(0.25)
          ..strokeWidth = 1.2;
    canvas.drawLine(Offset(px, 0), Offset(px, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _VerticalCursorPainter oldDelegate) =>
      oldDelegate.px != px;
}

class _MinimalLineChartPainter extends CustomPainter {
  _MinimalLineChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    this.showHorizontalGrid = true,
    this.verticalLineX,
  });

  final List<HistoricalPoint> points;
  final Color lineColor;
  final Color fillColor;
  final bool showHorizontalGrid;

  /// If provided, draw a vertical line at this fraction [0,1] of width.
  final double? verticalLineX;

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
    if (showHorizontalGrid) {
      for (final double fraction in <double>[0.25, 0.5, 0.75]) {
        final double y = size.height * fraction;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
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

    if (verticalLineX != null) {
      final double x = verticalLineX!.clamp(0, 1) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = lineColor.withOpacity(0.2)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

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

class _MetricGroupData {
  const _MetricGroupData({
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final List<_MetricEntry> metrics;
}

class _DataCoverageSummary {
  const _DataCoverageSummary({
    required this.label,
    required this.ratioLabel,
    required this.accent,
    required this.soft,
    required this.icon,
    required this.missing,
  });

  final String label;
  final String ratioLabel;
  final Color accent;
  final Color soft;
  final IconData icon;
  final List<String> missing;

  double get progress {
    final parts = ratioLabel.split('/');
    if (parts.length != 2) return 0;
    final available = int.tryParse(parts.first) ?? 0;
    final total = int.tryParse(parts.last.split(' ').first) ?? 0;
    if (total <= 0) return 0;
    return available / total;
  }
}

class _ChartAnnotationData {
  const _ChartAnnotationData({
    required this.label,
    required this.icon,
    required this.tint,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color foreground;
}

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoTabStrip extends StatelessWidget {
  const _InfoTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Vue'),
          Tab(text: 'Fondamentaux'),
          Tab(text: 'Profil'),
          Tab(text: 'News'),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabBarDelegate({required this.child});
  final Widget child;

  // TabBar ~46px + top padding 4 + bottom padding 12 = 62
  static const double _height = 62.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => old.child != child;
}

class _AssetHeroCard extends StatelessWidget {
  const _AssetHeroCard({
    required this.title,
    required this.ticker,
    required this.quoteType,
    required this.exchange,
    required this.currency,
    required this.sectorOrCategory,
    required this.priceText,
    required this.changeText,
    required this.changePositive,
    required this.lastUpdate,
    required this.portfolioButton,
    required this.favoriteButton,
    required this.tradeButtons,
  });

  final String title;
  final String ticker;
  final String quoteType;
  final String exchange;
  final String currency;
  final String? sectorOrCategory;
  final String priceText;
  final String changeText;
  final bool changePositive;
  final String? lastUpdate;
  final Widget portfolioButton;
  final Widget favoriteButton;
  final Widget tradeButtons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            detailsColor2.withValues(alpha: 0.96),
            detailsColor1.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: detailsColor2.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: quoteType, icon: Icons.pie_chart_rounded),
              _HeroChip(label: exchange, icon: Icons.public_rounded),
              _HeroChip(label: currency, icon: Icons.payments_rounded),
              if (sectorOrCategory != null &&
                  sectorOrCategory!.trim().isNotEmpty)
                _HeroChip(label: sectorOrCategory!, icon: Icons.layers_rounded),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticker,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                priceText,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (changeText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        changePositive
                            ? Colors.green.withValues(alpha: 0.20)
                            : Colors.red.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          changePositive
                              ? Colors.green.withValues(alpha: 0.26)
                              : Colors.red.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Text(
                    changeText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          if (lastUpdate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Dernière mise à jour : $lastUpdate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actions de portefeuille',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [portfolioButton, favoriteButton, tradeButtons],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectablePill extends StatelessWidget {
  const _SelectablePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? detailsColor2 : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textColor,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.soft,
  });

  final String label;
  final String value;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGroupCard extends StatelessWidget {
  const _MetricGroupCard({
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final List<_MetricEntry> metrics;

  @override
  Widget build(BuildContext context) {
    return _InfoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                metrics
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
      ),
    );
  }
}

class _HistorySeriesCard extends StatelessWidget {
  const _HistorySeriesCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.formatter,
  });

  final String title;
  final String subtitle;
  final List<YearlyMetricValue> values;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    final limited = values.take(4).toList();
    return _InfoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...limited.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '${entry.year}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatter(entry.value),
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearValueChip extends StatelessWidget {
  const _YearValueChip({required this.year, required this.value});

  final int year;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$year',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
    this.macroContext = false,
  });

  final FinanceNewsItem article;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlightPrimary;
  final bool highlightFavorite;
  final bool macroContext;

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
                    _NewsChip(label: 'Ticker', color: Colors.green.shade600),
                  if (highlightFavorite)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _NewsChip(
                        label: 'Favori lié',
                        color: Colors.blueAccent,
                      ),
                    ),
                  if (macroContext)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _NewsChip(
                        label: 'Macro',
                        color: Colors.deepPurple.shade400,
                      ),
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

class _FundamentalSheetChip extends StatelessWidget {
  const _FundamentalSheetChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _FundamentalFocusCard extends StatelessWidget {
  const _FundamentalFocusCard({
    required this.title,
    required this.value,
    required this.score,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String score;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
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
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score/20',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundamentalSubScoreCard extends StatelessWidget {
  const _FundamentalSubScoreCard({required this.subScore});

  final FundamentalSubScore subScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subScore.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              _FundamentalSheetChip(
                label:
                    subScore.score == null
                        ? 'N/A'
                        : '${subScore.score!.toStringAsFixed(0)}/20',
                backgroundColor: detailsColor1.withValues(alpha: .14),
                foregroundColor: textColor,
              ),
            ],
          ),
          if (subScore.note != null) ...[
            const SizedBox(height: 8),
            Text(
              subScore.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...subScore.metrics.map(
            (metric) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${metric.label} · ${metric.displayValue}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    metric.score == null
                        ? 'N/A'
                        : '${metric.score!.toStringAsFixed(0)}/20',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                            color:
                                indicator.secondaryEmphasis
                                    ? Colors.black87
                                    : Colors.black54,
                            fontWeight:
                                indicator.secondaryEmphasis
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black45,
                ),
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
  const _PositionFormResult({required this.quantity, this.costBasis});

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
    : this._(portfolioId: null, portfolioName: null, createNew: true);

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
