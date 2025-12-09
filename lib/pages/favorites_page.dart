import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'info_page.dart';

/// FavoritesPage
/// Affiche la liste des actions sauvegardées par l'utilisateur dans Firestore.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  static const Color _bg = Color(0xFFF5F6F7);
  static const Color _muted = Colors.black54;
  static const Color _border = Color(0xFFE6E8EB);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        color: _bg,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline_rounded, color: _muted, size: 32),
            SizedBox(height: 12),
            Text(
              'Connectez-vous pour retrouver vos favoris',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoris')
        .orderBy('addedAt', descending: true)
        .snapshots();

    return Container(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Vos favoris',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: .2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Retrouvez ici vos actions suivies en raccourci.',
                  style: TextStyle(
                    fontSize: 15,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.black38, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'Impossible de charger vos favoris.\nVeuillez vérifier votre connexion.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.favorite_border_rounded, color: Colors.black38, size: 36),
                        SizedBox(height: 12),
                        Text(
                          'Ajoutez des actions en cliquant sur le coeur\npour les retrouver instantanément.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                      onTap: () => _openInfoSheet(
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
            ),
          ),
        ],
      ),
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
        builder: (ctx) => InfoPage(
          ticker: symbol,
          initialName: name,
          initialExchange: exchange,
          initialCurrency: currency,
          initialQuoteType: quoteType,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir la fiche de l'action.")),
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
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FavoritesPage._border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                displaySymbol.substring(0, displaySymbol.length >= 4 ? 4 : displaySymbol.length),
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displaySymbol,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.6),
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
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38, size: 26),
          ],
        ),
      ),
    );
  }
}
