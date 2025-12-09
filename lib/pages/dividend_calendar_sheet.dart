import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintech/models/dividend_event.dart';
import 'package:fintech/services/yahoo_finance_service.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'info_page.dart';

enum _DividendFilter { all, favorites, portfolios }

class DividendCalendarSheet extends StatefulWidget {
  const DividendCalendarSheet({super.key, required this.userId});

  final String userId;

  @override
  State<DividendCalendarSheet> createState() => _DividendCalendarSheetState();
}

class _DividendCalendarSheetState extends State<DividendCalendarSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<_DividendCalendarEntry> _entries = const <_DividendCalendarEntry>[];
  _DividendFilter _filter = _DividendFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    _loadCalendar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final firestore = FirebaseFirestore.instance;
    final symbols = <String, _TrackedSymbol>{};

    void upsertSymbol(
      String rawSymbol, {
      String? name,
      String? exchange,
      String? currency,
      String? quoteType,
      bool markFavorite = false,
      String? portfolioName,
    }) {
      final symbol = rawSymbol.trim();
      if (symbol.isEmpty) return;
      final key = symbol.toUpperCase();
      final existing = symbols[key];
      if (existing == null) {
        symbols[key] = _TrackedSymbol(
          symbol: symbol,
          name: (name ?? symbol).trim().isEmpty ? symbol : name!.trim(),
          exchange: exchange?.trim() ?? '',
          currency: currency?.trim() ?? '',
          quoteType: quoteType?.trim().isEmpty ?? true ? 'UNKNOWN' : quoteType!.trim(),
          isFavorite: markFavorite,
          portfolios: portfolioName != null && portfolioName.trim().isNotEmpty
              ? {portfolioName.trim()}
              : <String>{},
        );
        return;
      }

      if (name != null && name.trim().isNotEmpty) {
        existing.name = name.trim();
      }
      if (exchange != null && exchange.trim().isNotEmpty) {
        existing.exchange = exchange.trim();
      }
      if (currency != null && currency.trim().isNotEmpty) {
        existing.currency = currency.trim();
      }
      if (quoteType != null && quoteType.trim().isNotEmpty && existing.quoteType == 'UNKNOWN') {
        existing.quoteType = quoteType.trim();
      }
      if (markFavorite) {
        existing.isFavorite = true;
      }
      if (portfolioName != null && portfolioName.trim().isNotEmpty) {
        existing.portfolios.add(portfolioName.trim());
      }
    }

    try {
      final favoritesSnap = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('favoris')
          .get();

      for (final doc in favoritesSnap.docs) {
        final data = doc.data();
        final symbol = (data['symbol'] as String? ?? doc.id).trim();
        if (symbol.isEmpty) continue;
        upsertSymbol(
          symbol,
          name: (data['name'] as String? ?? symbol).trim(),
          exchange: (data['exchange'] as String? ?? '').trim(),
          currency: (data['currency'] as String? ?? '').trim(),
          quoteType: (data['quoteType'] as String? ?? '').trim(),
          markFavorite: true,
        );
      }

      final portfoliosSnap = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('portfolios')
          .get();

      await Future.wait(
        portfoliosSnap.docs.map((portfolioDoc) async {
          final portfolioName = (portfolioDoc.data()['name'] as String? ?? portfolioDoc.id).trim();
          final positionsSnap = await portfolioDoc.reference.collection('positions').get();
          for (final positionDoc in positionsSnap.docs) {
            final data = positionDoc.data();
            final symbol = (data['symbol'] as String? ?? positionDoc.id).trim();
            if (symbol.isEmpty) continue;
            upsertSymbol(
              symbol,
              name: (data['displayName'] as String? ?? symbol).trim(),
              exchange: (data['exchange'] as String? ?? '').trim(),
              currency: (data['currency'] as String? ?? '').trim(),
              quoteType: (data['quoteType'] as String? ?? '').trim(),
              portfolioName: portfolioName.isEmpty ? portfolioDoc.id : portfolioName,
            );
          }
        }),
      );

      if (symbols.isEmpty) {
        setState(() {
          _entries = const [];
          _loading = false;
        });
        return;
      }

      final entries = <_DividendCalendarEntry>[];
      final now = DateTime.now();

      for (final meta in symbols.values) {
        try {
          final event = await YahooFinanceService.fetchDividendEvent(meta.symbol);
          if (event == null) continue;

          var exDate = event.exDate;
          var paymentDate = event.paymentDate;
          if (exDate == null && paymentDate != null) {
            exDate = paymentDate.subtract(const Duration(days: 3));
          }
          if (paymentDate == null && exDate != null) {
            paymentDate = exDate.add(const Duration(days: 3));
          }
          if (exDate != null && paymentDate != null && paymentDate.isBefore(exDate)) {
            paymentDate = exDate.add(const Duration(days: 3));
          }

          final normalizedEvent = event.copyWith(
            exDate: exDate,
            paymentDate: paymentDate,
          );

          final primaryDate = normalizedEvent.exDate ?? normalizedEvent.paymentDate ?? normalizedEvent.declarationDate;
          if (primaryDate != null && primaryDate.isBefore(now.subtract(const Duration(days: 60)))) {
            continue;
          }

          entries.add(
            _DividendCalendarEntry(
              metadata: meta,
              event: normalizedEvent,
            ),
          );
        } on FinanceRequestException catch (e) {
          if (e.message == 'consent_required') {
            setState(() {
              _error = 'Consentement Yahoo requis pour consulter les dividendes.';
              _loading = false;
            });
            return;
          }
        } catch (_) {
          // ignore individual failures
        }
      }

      entries.sort((a, b) {
        final aDate = a.primaryDate ?? now.add(const Duration(days: 365));
        final bDate = b.primaryDate ?? now.add(const Duration(days: 365));
        return aDate.compareTo(bDate);
      });

      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Impossible de charger le calendrier (${e.toString()}).';
      });
    }
  }

  void _changeFilter(_DividendFilter filter) {
    setState(() => _filter = filter);
  }

  List<_DividendCalendarEntry> get _filteredEntries {
    switch (_filter) {
      case _DividendFilter.all:
        return _entries;
      case _DividendFilter.favorites:
        return _entries.where((entry) => entry.metadata.isFavorite).toList();
      case _DividendFilter.portfolios:
        return _entries.where((entry) => entry.metadata.portfolios.isNotEmpty).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calendrier des dividendes',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Filtre sur tes favoris et portefeuilles',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: _loadCalendar,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black45,
                  indicatorColor: Colors.black,
                  tabs: const [
                    Tab(text: 'Liste'),
                    Tab(text: 'Calendrier'),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tabController.index == 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                          child: _DividendFilterChips(
                            current: _filter,
                            onChanged: _changeFilter,
                          ),
                        )
                      : const SizedBox(height: 12),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : (_error != null)
                            ? _CalendarError(message: _error!, onRetry: _loadCalendar)
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  _CalendarList(entries: _filteredEntries),
                                  _CalendarPlanner(entries: _filteredEntries),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarList extends StatelessWidget {
  const _CalendarList({required this.entries});

  final List<_DividendCalendarEntry> entries;

  static const List<String> _monthLabels = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _monthLabels[local.month - 1];
    return '$day $month ${local.year}';
  }

  Map<String, List<_DividendCalendarEntry>> _groupEntries() {
    final map = LinkedHashMap<String, List<_DividendCalendarEntry>>();
    for (final entry in entries) {
      final date = entry.primaryDate;
      final key = date == null
          ? 'À planifier'
          : '${_monthLabels[date.month - 1]} ${date.year}';
      map.putIfAbsent(key, () => <_DividendCalendarEntry>[]).add(entry);
    }
    return map;
  }

  String _formatAmount(double amount, String? currency) {
    final formatted = amount.abs() >= 1 ? amount.toStringAsFixed(2) : amount.toStringAsFixed(4);
    return currency != null && currency.isNotEmpty ? '$formatted $currency' : formatted;
  }

  void _openInfo(BuildContext context, _DividendCalendarEntry entry) {
    showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      builder: (_) => InfoPage(
        ticker: entry.metadata.symbol,
        initialName: entry.metadata.name,
        initialExchange: entry.metadata.exchange,
        initialCurrency: entry.metadata.currency,
        initialQuoteType: entry.metadata.quoteType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucun dividende à venir pour le moment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ),
      );
    }

    final grouped = _groupEntries();
    final labels = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: labels.length,
      itemBuilder: (context, index) {
        final label = labels[index];
        final groupEntries = grouped[label]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label[0].toUpperCase() + label.substring(1),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...groupEntries.map((entry) {
                final event = entry.event;
                final amount = event.amount;
                final amountText = amount != null
                    ? _formatAmount(amount, event.currency ?? entry.metadata.currency)
                    : '—';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DividendCard(
                    title: '${entry.metadata.symbol} · ${entry.metadata.name}',
                    subtitle: entry.metadata.exchange.isNotEmpty
                        ? '${entry.metadata.exchange.toUpperCase()} · ${entry.metadata.quoteType.toUpperCase()}'
                        : entry.metadata.quoteType.toUpperCase(),
                    exDate: _formatDate(event.exDate),
                    payDate: _formatDate(event.paymentDate),
                    amount: amountText,
                    isFavorite: entry.metadata.isFavorite,
                    portfolios: entry.metadata.portfolios,
                    onTap: () => _openInfo(context, entry),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarPlanner extends StatelessWidget {
  const _CalendarPlanner({required this.entries});

  final List<_DividendCalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final datedEntries = entries
        .where((entry) => entry.calendarDate != null)
        .toList();

    if (datedEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucun dividende daté à afficher pour l’instant.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ),
      );
    }

    final eventsByDate = SplayTreeMap<DateTime, List<_DividendCalendarEntry>>();
    final months = SplayTreeSet<DateTime>((a, b) => a.compareTo(b));

    for (final entry in datedEntries) {
      final date = entry.calendarDate!;
      final dayKey = DateTime(date.year, date.month, date.day);
      eventsByDate.putIfAbsent(dayKey, () => <_DividendCalendarEntry>[]).add(entry);
      months.add(DateTime(date.year, date.month));
    }

    final monthList = months.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: monthList.length,
      itemBuilder: (context, index) {
        final month = monthList[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _MonthCalendar(
            month: month,
            eventsByDate: eventsByDate,
          ),
        );
      },
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.month, required this.eventsByDate});

  final DateTime month;
  final SplayTreeMap<DateTime, List<_DividendCalendarEntry>> eventsByDate;

  static const List<String> _weekdayLabels = <String>['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = DateTime(month.year, month.month, 1);
    final daysInMonth = _daysInMonth(month);
    final startOffset = (start.weekday + 6) % 7; // Monday-first
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final cells = rows * 7;

    DateTime _dateForCell(int index) {
      final day = index - startOffset + 1;
      return DateTime(month.year, month.month, day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_CalendarList._monthLabels[month.month - 1]} ${month.year}'.replaceFirstMapped(
            RegExp('^.'),
            (match) => match.group(0)!.toUpperCase(),
          ),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 2.4,
          ),
          itemBuilder: (context, index) {
            return Center(
              child: Text(
                _weekdayLabels[index],
                style: theme.textTheme.labelMedium?.copyWith(color: Colors.black54),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            if (index < startOffset || index >= startOffset + daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = _dateForCell(index);
            final events = eventsByDate[DateTime(date.year, date.month, date.day)] ?? const <_DividendCalendarEntry>[];
            final isToday = DateTime.now().difference(date).inDays == 0 &&
                DateTime.now().month == date.month &&
                DateTime.now().year == date.year;

            return Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.day.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: events
                              .map(
                                (entry) => _CalendarDot(
                                  symbol: entry.metadata.symbol,
                                  amount: entry.event.amount,
                                  currency: entry.event.currency ?? entry.metadata.currency,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.symbol, this.amount, this.currency});

  final String symbol;
  final double? amount;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = amount == null
        ? ''
        : amount!.abs() >= 1
            ? amount!.toStringAsFixed(2)
            : amount!.toStringAsFixed(4);
    final label = amount == null
        ? symbol
        : '$symbol · $amountText${currency != null && currency!.isNotEmpty ? ' $currency' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _DividendCard extends StatelessWidget {
  const _DividendCard({
    required this.title,
    required this.subtitle,
    required this.exDate,
    required this.payDate,
    required this.amount,
    required this.isFavorite,
    required this.portfolios,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String exDate;
  final String payDate;
  final String amount;
  final bool isFavorite;
  final Set<String> portfolios;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CalendarBadge(label: 'Ex-date', value: exDate),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CalendarBadge(label: 'Paiement', value: payDate),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Dividende: $amount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            if (isFavorite || portfolios.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (isFavorite)
                    const Chip(
                      label: Text('Favori'),
                      avatar: Icon(Icons.favorite_rounded, size: 16),
                    ),
                  ...portfolios.map(
                    (name) => Chip(
                      label: Text(name),
                      avatar: const Icon(Icons.folder_special_rounded, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarBadge extends StatelessWidget {
  const _CalendarBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DividendFilterChips extends StatelessWidget {
  const _DividendFilterChips({required this.current, required this.onChanged});

  final _DividendFilter current;
  final ValueChanged<_DividendFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildChip(context, 'Tous', _DividendFilter.all),
        _buildChip(context, 'Favoris', _DividendFilter.favorites),
        _buildChip(context, 'Portefeuilles', _DividendFilter.portfolios),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String label, _DividendFilter filter) {
    final selected = current == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(filter),
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackedSymbol {
  _TrackedSymbol({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.currency,
    required this.quoteType,
    this.isFavorite = false,
    Set<String>? portfolios,
  }) : portfolios = portfolios ?? <String>{};

  final String symbol;
  String name;
  String exchange;
  String currency;
  String quoteType;
  bool isFavorite;
  final Set<String> portfolios;
}

class _DividendCalendarEntry {
  const _DividendCalendarEntry({required this.metadata, required this.event});

  final _TrackedSymbol metadata;
  final DividendEvent event;

  DateTime? get primaryDate => event.exDate ?? event.paymentDate ?? event.declarationDate;
  DateTime? get calendarDate => event.paymentDate ?? event.exDate ?? event.declarationDate;
}
