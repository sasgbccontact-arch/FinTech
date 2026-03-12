import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _gold = detailsColor1;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final broadcastsStream =
        FirebaseFirestore.instance
            .collection('broadcasts')
            .orderBy('createdAt', descending: true)
            .limit(40)
            .snapshots();
    final inboxStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('inbox')
                .orderBy('createdAt', descending: true)
                .limit(40)
                .snapshots();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Centre de notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: broadcastsStream,
          builder: (context, broadcastsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: inboxStream,
              builder: (context, inboxSnapshot) {
                if (broadcastsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    inboxSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _gold,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (broadcastsSnapshot.hasError || inboxSnapshot.hasError) {
                  return const _EmptyState(
                    title: 'Notifications indisponibles',
                    subtitle:
                        'Le flux in-app sera visible dès que les prochaines diffusions seront enregistrées.',
                    icon: Icons.wifi_off_rounded,
                  );
                }

                final items = <_NotificationItem>[
                  ..._broadcastItems(broadcastsSnapshot.data?.docs ?? const []),
                  ..._inboxItems(inboxSnapshot.data?.docs ?? const []),
                ]..sort(
                  (left, right) => right.createdAt.compareTo(left.createdAt),
                );

                if (items.isEmpty) {
                  return const _EmptyState(
                    title: 'Aucune notification enregistrée',
                    subtitle:
                        'Les invitations de duel, résultats et broadcasts FinHub apparaîtront ici.',
                    icon: Icons.notifications_none_rounded,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationCard(item: item);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_NotificationItem> _broadcastItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      return _NotificationItem(
        title: _safeText(data['title'], fallback: 'Notification FinHub'),
        body: _safeText(data['body'], fallback: 'Aucun contenu disponible.'),
        topic: _safeText(data['topic'], fallback: 'general'),
        type: _safeText(data['type'], fallback: 'broadcast'),
        createdAt: _dateFromAny(data['createdAt']),
        sourceLabel: 'Broadcast',
      );
    }).toList();
  }

  List<_NotificationItem> _inboxItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final type = _safeText(data['type'], fallback: 'inbox');
      return _NotificationItem(
        title: _safeText(data['title'], fallback: _titleForInboxType(type)),
        body: _safeText(
          data['body'],
          fallback: 'Une mise à jour liée à ton espace social est disponible.',
        ),
        topic:
            (data['duelId'] as String?)?.trim().isNotEmpty == true
                ? 'duel'
                : 'social',
        type: type,
        createdAt: _dateFromAny(data['createdAt']),
        sourceLabel: 'Perso',
      );
    }).toList();
  }

  String _safeText(dynamic raw, {required String fallback}) {
    final value = (raw as String?)?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  DateTime _dateFromAny(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _titleForInboxType(String type) {
    switch (type) {
      case 'duel_invite':
        return 'Invitation duel';
      case 'duel_started':
        return 'Duel lancé';
      case 'duel_refused':
        return 'Duel refusé';
      case 'duel_expired':
        return 'Invitation expirée';
      case 'duel_finished':
        return 'Duel terminé';
      default:
        return 'Notification personnelle';
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final _NotificationItem item;

  String _formatDate(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'À l’instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
  }

  IconData get _icon {
    switch (item.type) {
      case 'daily_metals':
        return Icons.workspace_premium_rounded;
      case 'manual':
        return Icons.campaign_rounded;
      case 'duel_invite':
        return Icons.sports_kabaddi_rounded;
      case 'duel_started':
        return Icons.flash_on_rounded;
      case 'duel_refused':
      case 'duel_expired':
        return Icons.hourglass_disabled_rounded;
      case 'duel_finished':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String get _typeLabel {
    switch (item.type) {
      case 'daily_metals':
        return 'Métaux';
      case 'manual':
        return 'Annonce';
      case 'duel_invite':
        return 'Invitation';
      case 'duel_started':
        return 'Duel';
      case 'duel_refused':
      case 'duel_expired':
        return 'Résolution';
      case 'duel_finished':
        return 'Résultat';
      default:
        return item.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(item.createdAt),
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.body,
            style: const TextStyle(color: Colors.black87, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: item.sourceLabel),
              _MetaChip(label: item.topic),
              _MetaChip(label: _typeLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: detailsColor1.withValues(alpha: 0.12),
        border: Border.all(color: detailsColor2.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: detailsColor1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: detailsColor2, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.body,
    required this.topic,
    required this.type,
    required this.createdAt,
    required this.sourceLabel,
  });

  final String title;
  final String body;
  final String topic;
  final String type;
  final DateTime createdAt;
  final String sourceLabel;
}
