import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/features/duel/duel_service.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _gold = detailsColor1;
  static const int _maxInboxItems = 36;

  bool _isPruningInbox = false;
  final Set<String> _busyRequestIds = <String>{};

  User? get _user => FirebaseAuth.instance.currentUser;

  void _log(String message) {
    print('[NotifCenter] $message');
    debugPrint('[NotifCenter] $message');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _tryWritePeerInboxNotification({
    required String targetUserId,
    required String docId,
    required Map<String, dynamic> payload,
    required String debugContext,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('inbox')
          .doc(docId)
          .set(payload);
      _log('Notif perso ecrite pour $targetUserId contexte=$debugContext');
    } on FirebaseException catch (error) {
      _log(
        'Notif perso ignoree pour $targetUserId contexte=$debugContext code=${error.code} message=${error.message}',
      );
    }
  }

  Future<void> _markInboxRead(_NotificationItem item) async {
    final user = _user;
    if (user == null || !item.isInboxItem || item.docId == null) return;
    _log('Marquage lu docId=${item.docId} type=${item.type}');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inbox')
        .doc(item.docId)
        .set({'isRead': true}, SetOptions(merge: true));
  }

  void _scheduleInboxPrune(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final user = _user;
    if (user == null || docs.length <= _maxInboxItems || _isPruningInbox) {
      return;
    }
    _isPruningInbox = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_pruneInboxOverflow(user.uid, docs));
    });
  }

  Future<void> _pruneInboxOverflow(
    String userId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    try {
      final sorted = [...docs]..sort((left, right) {
        final leftDate = _dateFromAny(left.data()['createdAt']);
        final rightDate = _dateFromAny(right.data()['createdAt']);
        return rightDate.compareTo(leftDate);
      });
      final overflow = sorted.length - _maxInboxItems;
      if (overflow <= 0) return;
      final toDelete = sorted.skip(_maxInboxItems).toList();
      _log(
        'Pruning inbox utilisateur=$userId totalAvant=${sorted.length} suppression=${toDelete.length}',
      );
      for (final doc in toDelete) {
        await doc.reference.delete();
        _log('Inbox supprimee docId=${doc.id}');
      }
    } on FirebaseException catch (error) {
      _log(
        'Erreur pruning inbox utilisateur=$userId code=${error.code} message=${error.message}',
      );
    } catch (error) {
      _log('Erreur pruning inbox utilisateur=$userId error=$error');
    } finally {
      _isPruningInbox = false;
    }
  }

  Future<void> _acceptFriendRequest(_NotificationItem item) async {
    final user = _user;
    if (user == null || item.requestId == null) return;
    _log('Acceptation demande ami requestId=${item.requestId}');
    final requestRef = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(item.requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      _log('Demande ami introuvable requestId=${item.requestId}');
      _snack('Cette demande n’existe plus.');
      return;
    }
    final data = requestSnap.data() ?? const <String, dynamic>{};
    if ((data['toUid'] as String?) != user.uid ||
        (data['status'] as String?) != 'pending') {
      _log(
        'Demande ami deja traitee requestId=${item.requestId} status=${data['status']}',
      );
      _snack('Cette demande a déjà été traitée.');
      return;
    }

    final fromUid = (data['fromUid'] as String?) ?? '';
    final now = Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(requestRef, {'status': 'accepted', 'acceptedAt': now});
    batch.set(
      FirebaseFirestore.instance
          .collection('friendships')
          .doc(_friendshipId(fromUid, user.uid)),
      {
        'participants': <String>[fromUid, user.uid]..sort(),
        'createdAt': now,
        'createdBy': user.uid,
      },
      SetOptions(merge: true),
    );
    if (item.docId != null) {
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inbox')
            .doc(item.docId),
        {'isRead': true},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    await _tryWritePeerInboxNotification(
      targetUserId: fromUid,
      docId: 'friend_accept_${item.requestId}',
      debugContext: 'notification_center_friend_accept',
      payload: {
        'type': 'friend_request_accepted',
        'title': 'Ta demande d’ami a été acceptée',
        'body': 'Retrouve ce joueur dans ton classement amis.',
        'createdAt': now,
        'requestId': item.requestId,
        'duelId': null,
        'actorUid': user.uid,
        'isRead': false,
      },
    );
    _log('Succes acceptation demande ami requestId=${item.requestId}');
    _snack('Demande acceptée.');
  }

  Future<void> _runBusyRequest(
    String requestId,
    Future<void> Function() action,
  ) async {
    if (_busyRequestIds.contains(requestId)) return;
    if (mounted) {
      setState(() => _busyRequestIds.add(requestId));
    }
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busyRequestIds.remove(requestId));
      }
    }
  }

  Future<void> _declineFriendRequest(_NotificationItem item) async {
    final user = _user;
    if (user == null || item.requestId == null) return;
    _log('Refus demande ami requestId=${item.requestId}');
    final requestRef = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(item.requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      _log('Demande ami introuvable requestId=${item.requestId}');
      _snack('Cette demande n’existe plus.');
      return;
    }
    final data = requestSnap.data() ?? const <String, dynamic>{};
    if ((data['toUid'] as String?) != user.uid ||
        (data['status'] as String?) != 'pending') {
      _log(
        'Demande ami deja traitee requestId=${item.requestId} status=${data['status']}',
      );
      _snack('Cette demande a déjà été traitée.');
      return;
    }

    final fromUid = (data['fromUid'] as String?) ?? '';
    final now = Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(requestRef, {'status': 'declined', 'declinedAt': now});
    if (item.docId != null) {
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inbox')
            .doc(item.docId),
        {'isRead': true},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    await _tryWritePeerInboxNotification(
      targetUserId: fromUid,
      docId: 'friend_decline_${item.requestId}',
      debugContext: 'notification_center_friend_decline',
      payload: {
        'type': 'friend_request_declined',
        'title': 'Ta demande d’ami a été refusée',
        'body': 'Tu peux inviter un autre joueur à tout moment.',
        'createdAt': now,
        'requestId': item.requestId,
        'duelId': null,
        'actorUid': user.uid,
        'isRead': false,
      },
    );
    _log('Succes refus demande ami requestId=${item.requestId}');
    _snack('Demande refusée.');
  }

  Future<void> _acceptDuelInvite(_NotificationItem item) async {
    if (item.requestId == null) return;
    _log('Acceptation duel requestId=${item.requestId}');
    try {
      await DuelService.acceptRequest(item.requestId!);
      await _markInboxRead(item);
      _log('Succes acceptation duel requestId=${item.requestId}');
      _snack('Duel accepté.');
    } on DuelException catch (error) {
      _log(
        'Erreur metier acceptation duel requestId=${item.requestId} message=${error.message}',
      );
      _snack(error.message);
    } on FirebaseException catch (error) {
      _log(
        'Erreur Firebase acceptation duel requestId=${item.requestId} code=${error.code} message=${error.message}',
      );
      _snack('Firestore refuse l’acceptation du duel pour le moment.');
    } catch (error) {
      _log(
        'Erreur inattendue acceptation duel requestId=${item.requestId} error=$error',
      );
      _snack('Impossible d’accepter ce duel pour le moment.');
    }
  }

  Future<void> _refuseDuelInvite(_NotificationItem item) async {
    if (item.requestId == null) return;
    _log('Refus duel requestId=${item.requestId}');
    try {
      await DuelService.refuseRequest(item.requestId!);
      await _markInboxRead(item);
      _log('Succes refus duel requestId=${item.requestId}');
      _snack('Duel refusé.');
    } on DuelException catch (error) {
      _log(
        'Erreur metier refus duel requestId=${item.requestId} message=${error.message}',
      );
      _snack(error.message);
    } catch (_) {
      _log('Erreur inattendue refus duel requestId=${item.requestId}');
      _snack('Impossible de refuser ce duel pour le moment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final broadcastsStream =
        FirebaseFirestore.instance.collection('broadcasts').snapshots();
    final incomingFriendRequestsStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('friend_requests')
                .where('toUid', isEqualTo: user.uid)
                .snapshots();
    final incomingDuelRequestsStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('duel_requests')
                .where('targetUid', isEqualTo: user.uid)
                .snapshots();
    final inboxStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('inbox')
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
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: incomingFriendRequestsStream,
                  builder: (context, friendRequestsSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: incomingDuelRequestsStream,
                      builder: (context, duelRequestsSnapshot) {
                        if (broadcastsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            inboxSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            friendRequestsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            duelRequestsSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _gold,
                              strokeWidth: 2.5,
                            ),
                          );
                        }

                        if (broadcastsSnapshot.hasError) {
                          _log(
                            'Erreur stream broadcasts: ${broadcastsSnapshot.error}',
                          );
                        }
                        if (inboxSnapshot.hasError) {
                          _log('Erreur stream inbox: ${inboxSnapshot.error}');
                        }
                        if (friendRequestsSnapshot.hasError) {
                          _log(
                            'Erreur stream friend_requests: ${friendRequestsSnapshot.error}',
                          );
                        }
                        if (duelRequestsSnapshot.hasError) {
                          _log(
                            'Erreur stream duel_requests: ${duelRequestsSnapshot.error}',
                          );
                        }

                        final items = _dedupeItems(<_NotificationItem>[
                          ..._broadcastItems(
                            broadcastsSnapshot.data?.docs ?? const [],
                          ),
                          ..._inboxItems(inboxSnapshot.data?.docs ?? const []),
                          ..._friendRequestItems(
                            friendRequestsSnapshot.data?.docs ?? const [],
                          ),
                          ..._duelInviteItems(
                            duelRequestsSnapshot.data?.docs ?? const [],
                          ),
                        ])..sort(
                          (left, right) =>
                              right.createdAt.compareTo(left.createdAt),
                        );
                        final visibleItems = items.take(50).toList();
                        _scheduleInboxPrune(
                          inboxSnapshot.data?.docs ?? const [],
                        );

                        _log(
                          'Render centre notifications: broadcasts=${broadcastsSnapshot.data?.docs.length ?? 0} inbox=${inboxSnapshot.data?.docs.length ?? 0} friendRequests=${friendRequestsSnapshot.data?.docs.length ?? 0} duelRequests=${duelRequestsSnapshot.data?.docs.length ?? 0} visibles=${visibleItems.length}',
                        );

                        if (visibleItems.isEmpty) {
                          return const _EmptyState(
                            title: 'Aucune notification enregistrée',
                            subtitle:
                                'Les demandes d’amis, invitations de duel et broadcasts FinHub apparaîtront ici.',
                            icon: Icons.notifications_none_rounded,
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: visibleItems.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return _NotificationCard(
                              item: item,
                              currentUserId: user?.uid,
                              isBusy:
                                  item.requestId != null &&
                                  _busyRequestIds.contains(item.requestId),
                              onAcceptFriendRequest:
                                  () => _runBusyRequest(
                                    item.requestId!,
                                    () => _acceptFriendRequest(item),
                                  ),
                              onDeclineFriendRequest:
                                  () => _runBusyRequest(
                                    item.requestId!,
                                    () => _declineFriendRequest(item),
                                  ),
                              onAcceptDuelInvite:
                                  () => _runBusyRequest(
                                    item.requestId!,
                                    () => _acceptDuelInvite(item),
                                  ),
                              onDeclineDuelInvite:
                                  () => _runBusyRequest(
                                    item.requestId!,
                                    () => _refuseDuelInvite(item),
                                  ),
                            );
                          },
                        );
                      },
                    );
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
        docId: doc.id,
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
        docId: doc.id,
        isInboxItem: true,
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
        requestId: (data['requestId'] as String?)?.trim(),
        duelId: (data['duelId'] as String?)?.trim(),
        actorUid: (data['actorUid'] as String?)?.trim(),
      );
    }).toList();
  }

  List<_NotificationItem> _friendRequestItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) => (doc.data()['status'] as String?) == 'pending').map((
      doc,
    ) {
      final data = doc.data();
      return _NotificationItem(
        title: 'Nouvelle demande d’ami',
        body:
            'Un autre joueur veut rejoindre ton cercle social. Tu peux traiter cette demande ici.',
        topic: 'social',
        type: 'friend_request',
        createdAt: _dateFromAny(data['createdAt']),
        sourceLabel: 'Demande',
        requestId: doc.id,
        actorUid: (data['fromUid'] as String?)?.trim(),
      );
    }).toList();
  }

  List<_NotificationItem> _duelInviteItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((doc) => (doc.data()['status'] as String?) == 'pending_response')
        .map((doc) {
          final data = doc.data();
          final initiatorSnapshot =
              data['initiatorSnapshot'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
          final initiatorName =
              (initiatorSnapshot['displayName'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? (initiatorSnapshot['displayName'] as String).trim()
                  : 'Un joueur';
          return _NotificationItem(
            title: '$initiatorName te provoque en duel',
            body: 'Tu as 48h pour accepter ce défi hebdomadaire.',
            topic: 'duel',
            type: 'duel_invite',
            createdAt: _dateFromAny(data['createdAt']),
            sourceLabel: 'Duel',
            requestId: doc.id,
            actorUid: (data['initiatorUid'] as String?)?.trim(),
          );
        })
        .toList();
  }

  List<_NotificationItem> _dedupeItems(List<_NotificationItem> items) {
    final byKey = <String, _NotificationItem>{};
    for (final item in items) {
      final key =
          item.requestId != null
              ? '${item.type}:${item.requestId}'
              : '${item.type}:${item.docId ?? item.createdAt.microsecondsSinceEpoch}:${item.title}';
      byKey.putIfAbsent(key, () => item);
    }
    return byKey.values.toList();
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
      case 'friend_request':
        return 'Nouvelle demande d’ami';
      case 'friend_request_accepted':
        return 'Demande acceptée';
      case 'friend_request_declined':
        return 'Demande refusée';
      case 'duel_invite':
        return 'Invitation duel';
      case 'duel_cancelled':
        return 'Défi annulé';
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
  const _NotificationCard({
    required this.item,
    required this.currentUserId,
    required this.isBusy,
    required this.onAcceptFriendRequest,
    required this.onDeclineFriendRequest,
    required this.onAcceptDuelInvite,
    required this.onDeclineDuelInvite,
  });

  final _NotificationItem item;
  final String? currentUserId;
  final bool isBusy;
  final Future<void> Function() onAcceptFriendRequest;
  final Future<void> Function() onDeclineFriendRequest;
  final Future<void> Function() onAcceptDuelInvite;
  final Future<void> Function() onDeclineDuelInvite;

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
      case 'friend_request':
        return Icons.person_add_alt_1_rounded;
      case 'friend_request_accepted':
        return Icons.favorite_rounded;
      case 'friend_request_declined':
        return Icons.person_off_rounded;
      case 'duel_invite':
        return Icons.sports_kabaddi_rounded;
      case 'duel_cancelled':
        return Icons.person_remove_alt_1_rounded;
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
      case 'friend_request':
        return 'Amitié';
      case 'friend_request_accepted':
      case 'friend_request_declined':
        return 'Réseau';
      case 'duel_invite':
        return 'Invitation';
      case 'duel_cancelled':
        return 'Annulation';
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
          if (item.type == 'friend_request' && item.requestId != null) ...[
            const SizedBox(height: 14),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('friend_requests')
                      .doc(item.requestId)
                      .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final status = (data?['status'] as String?) ?? '';
                final isPending =
                    status == 'pending' &&
                    (data?['toUid'] as String?) == currentUserId;
                if (!isPending) {
                  return _ResolutionBanner(
                    label:
                        status == 'accepted'
                            ? 'Demande déjà acceptée'
                            : status == 'declined'
                            ? 'Demande refusée'
                            : 'Demande déjà traitée',
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy ? null : onDeclineFriendRequest,
                        child:
                            isBusy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.1,
                                  ),
                                )
                                : const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isBusy ? null : onAcceptFriendRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            isBusy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.1,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text('Accepter'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (item.type == 'duel_invite' && item.requestId != null) ...[
            const SizedBox(height: 14),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('duel_requests')
                      .doc(item.requestId)
                      .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final status = (data?['status'] as String?) ?? '';
                final isPending =
                    status == 'pending_response' &&
                    (data?['targetUid'] as String?) == currentUserId;
                if (!isPending) {
                  return _ResolutionBanner(
                    label:
                        status == 'converted'
                            ? 'Duel déjà lancé'
                            : status == 'refused'
                            ? 'Invitation déjà refusée'
                            : status == 'cancelled'
                            ? 'Invitation annulée par l’initiateur'
                            : 'Invitation déjà traitée',
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy ? null : onDeclineDuelInvite,
                        child:
                            isBusy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.1,
                                  ),
                                )
                                : const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isBusy ? null : onAcceptDuelInvite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            isBusy
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.1,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Acceptation...'),
                                  ],
                                )
                                : const Text('Accepter'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
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

class _ResolutionBanner extends StatelessWidget {
  const _ResolutionBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: detailsColor2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: detailsColor2,
          fontWeight: FontWeight.w700,
        ),
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
    this.docId,
    this.requestId,
    this.duelId,
    this.actorUid,
    this.isInboxItem = false,
  });

  final String title;
  final String body;
  final String topic;
  final String type;
  final DateTime createdAt;
  final String sourceLabel;
  final String? docId;
  final String? requestId;
  final String? duelId;
  final String? actorUid;
  final bool isInboxItem;
}

String _friendshipId(String uidA, String uidB) {
  final ids = <String>[uidA, uidB]..sort();
  return '${ids[0]}_${ids[1]}';
}
