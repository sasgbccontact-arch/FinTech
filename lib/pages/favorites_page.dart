import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/core/constants.dart';

import 'info_page.dart';

/// FavoritesPage
/// Affiche la liste des actions sauvegardées par l'utilisateur dans Firestore.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  // Palette (same style as SearchPage)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _muted = Colors.black54;
  static const Color _border = Color(0xFFE6E8EB);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;
  static const Color _chipBg = Color(0xFFF0F1F3);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: _bg,
      appBar:
          canPop
              ? AppBar(
                backgroundColor: _bg,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
              : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, canPop ? 12 : 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vos favoris',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
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
                  const SizedBox(height: 10),
                  const Text(
                    'Retrouvez ici vos actions suivies en raccourci.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(child: FavoritesListSection()),
          ],
        ),
      ),
    );
  }
}

class FavoritesListSection extends StatelessWidget {
  const FavoritesListSection({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: FavoritesPage._border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [FavoritesPage._gold, FavoritesPage._wine],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Connectez-vous pour retrouver vos favoris',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FavoritesPage._muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vos actions sauvegardées apparaîtront ici automatiquement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FavoritesPage._muted.withValues(alpha: .9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favoris')
            .orderBy('addedAt', descending: true)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FavoritesSkeletonList();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: FavoritesPage._border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: FavoritesPage._wine.withValues(alpha: .85),
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Impossible de charger vos favoris.\nVeuillez vérifier votre connexion.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FavoritesPage._muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final docs =
            snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: FavoritesPage._border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [FavoritesPage._gold, FavoritesPage._wine],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Aucun favori pour le moment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FavoritesPage._ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ajoutez des actions en cliquant sur le coeur\npour les retrouver instantanément.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FavoritesPage._muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: padding,
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final rawSymbol = (data['symbol'] as String? ?? doc.id).trim();
            if (rawSymbol.isEmpty) {
              return const SizedBox.shrink();
            }
            final name = (data['name'] as String? ?? '').trim();
            final exchange = (data['exchange'] as String? ?? '').trim();
            final currency = (data['currency'] as String? ?? '').trim();
            final type = (data['quoteType'] as String? ?? '').trim();
            final addedAtRaw = data['addedAt'];
            DateTime? addedAt;
            if (addedAtRaw is Timestamp) {
              addedAt = addedAtRaw.toDate();
            }

            return _FavoriteCard(
              symbol: rawSymbol,
              name: name.isEmpty ? rawSymbol : name,
              exchange: exchange,
              currency: currency,
              addedAt: addedAt,
              onTap:
                  () => _openInfoSheet(
                    context,
                    rawSymbol,
                    name.isEmpty ? rawSymbol : name,
                    exchange.isEmpty ? null : exchange,
                    currency.isEmpty ? null : currency,
                    type.isEmpty ? null : type,
                  ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInfoSheet(
    BuildContext context,
    String symbol,
    String? name,
    String? exchange,
    String? currency,
    String? quoteType,
  ) async {
    try {
      await showCupertinoModalBottomSheet(
        context: context,
        expand: true,
        builder:
            (ctx) => InfoPage(
              ticker: symbol,
              initialName: name,
              initialExchange: exchange,
              initialCurrency: currency,
              initialQuoteType: quoteType,
            ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir la fiche de l'action."),
        ),
      );
    }
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.currency,
    required this.onTap,
    this.addedAt,
  });

  final String symbol;
  final String name;
  final String exchange;
  final String currency;
  final DateTime? addedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySymbol = symbol.toUpperCase();
    final subtitleTags = <String>[];
    if (exchange.isNotEmpty) {
      subtitleTags.add(exchange.toUpperCase());
    }
    if (currency.isNotEmpty) {
      subtitleTags.add(currency.toUpperCase());
    }

    String? addedText;
    if (addedAt != null) {
      final day = addedAt!.day.toString().padLeft(2, '0');
      final month = addedAt!.month.toString().padLeft(2, '0');
      addedText = 'Ajouté le $day/$month/${addedAt!.year}';
    }

    Widget buildTag(String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: FavoritesPage._chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FavoritesPage._border),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Ouvrir le favori $displaySymbol',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FavoritesPage._border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [FavoritesPage._gold, FavoritesPage._wine],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .10),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  displaySymbol.substring(
                    0,
                    displaySymbol.length >= 4 ? 4 : displaySymbol.length,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: FavoritesPage._ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displaySymbol,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.6),
                        letterSpacing: .8,
                      ),
                    ),
                    if (subtitleTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: subtitleTags.map(buildTag).toList(),
                      ),
                    ],
                    if (addedText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        addedText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FavoritesPage._muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: FavoritesPage._muted.withValues(alpha: .7),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesSkeletonList extends StatelessWidget {
  const _FavoritesSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder:
          (_, __) => Container(
            height: 98,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FavoritesPage._border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
    );
  }
}
