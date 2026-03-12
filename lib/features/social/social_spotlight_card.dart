import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/core/constants.dart';

enum _LeaderboardScope { global, friends }

enum _LeaderboardMetric { level, streak, coins, gems }

enum SocialProfileMetric { level, streak, coins, gems }

enum _ConnectionsTab { requests, search }

typedef _AsyncSocialUserAction = Future<void> Function(_SocialUserEntry entry);
typedef _AsyncFriendRequestAction =
    Future<void> Function(_FriendRequestEntry request);

Future<void> showSocialProfileSheet({
  required BuildContext context,
  required String userId,
  Map<String, dynamic>? initialUserData,
  SocialProfileMetric metric = SocialProfileMetric.level,
}) async {
  await showCupertinoModalBottomSheet<void>(
    context: context,
    expand: false,
    builder:
        (_) => _SocialProfileSheetLoader(
          userId: userId,
          initialUserData: initialUserData,
          metric: _leaderboardMetricFromProfileMetric(metric),
        ),
  );
}

class SocialSpotlightCard extends StatefulWidget {
  const SocialSpotlightCard({
    super.key,
    required this.currentUserId,
    required this.onOpenCommunity,
  });

  final String currentUserId;
  final VoidCallback onOpenCommunity;

  @override
  State<SocialSpotlightCard> createState() => _SocialSpotlightCardState();
}

class _SocialSpotlightCardState extends State<SocialSpotlightCard> {
  _LeaderboardScope _scope = _LeaderboardScope.global;
  _LeaderboardMetric _metric = _LeaderboardMetric.level;

  void _log(String message) {
    debugPrint('[SocialFriends] $message');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _currentUserStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _friendshipsStream() {
    return FirebaseFirestore.instance
        .collection('friendships')
        .where('participants', arrayContains: widget.currentUserId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _incomingRequestsStream() {
    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: widget.currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _globalUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  Future<void> _sendFriendRequest(_SocialUserEntry target) async {
    _log('Tentative envoi demande ami vers ${target.uid} (${target.name})');
    final requestId = '${widget.currentUserId}_${target.uid}';
    final reverseId = '${target.uid}_${widget.currentUserId}';
    final requests = FirebaseFirestore.instance.collection('friend_requests');
    final friendships = FirebaseFirestore.instance.collection('friendships');
    final friendshipId = _friendshipId(widget.currentUserId, target.uid);
    String? outgoingStatus;

    final existingFriendship = await friendships.doc(friendshipId).get();
    if (existingFriendship.exists) {
      _log('Blocage: deja amis avec ${target.uid}');
      _snack('Vous êtes déjà amis.');
      return;
    }

    final existingOutgoing = await requests.doc(requestId).get();
    outgoingStatus = existingOutgoing.data()?['status']?.toString();
    if (outgoingStatus == 'pending') {
      _log('Blocage: demande deja en attente vers ${target.uid}');
      _snack('Une demande est déjà en attente.');
      return;
    }
    if (outgoingStatus == 'accepted') {
      _log('Blocage: demande deja acceptee avec ${target.uid}');
      _snack('Vous êtes déjà amis.');
      return;
    }

    final reverseRequest = await requests.doc(reverseId).get();
    final reverseStatus = reverseRequest.data()?['status']?.toString();
    if (reverseStatus == 'pending') {
      _log('Blocage: demande inverse deja recue depuis ${target.uid}');
      _snack('Cette personne t’a déjà envoyé une demande.');
      return;
    }
    if (reverseStatus == 'accepted') {
      _log('Blocage: relation deja acceptee via demande inverse ${target.uid}');
      _snack('Vous êtes déjà amis.');
      return;
    }

    final now = Timestamp.now();
    final senderDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
    final senderName = _displayName(
      senderDoc.data() ?? const <String, dynamic>{},
    );

    final payload = <String, dynamic>{
      'fromUid': widget.currentUserId,
      'toUid': target.uid,
      'status': 'pending',
      'createdAt': now,
    };

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(requests.doc(requestId), payload);
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(target.uid)
            .collection('inbox')
            .doc('friend_$requestId'),
        {
          'type': 'friend_request',
          'title': '$senderName veut etre ton ami',
          'body':
              'Traite cette demande dans le centre de notifications ou dans Amis & demandes.',
          'createdAt': now,
          'requestId': requestId,
          'duelId': null,
          'actorUid': widget.currentUserId,
          'isRead': false,
        },
      );
      await batch.commit();
      _log('Succes envoi demande ami requestId=$requestId');
    } on FirebaseException catch (error) {
      _log(
        'Erreur Firebase envoi demande ami requestId=$requestId code=${error.code} message=${error.message}',
      );
      if (error.code == 'permission-denied' &&
          (outgoingStatus == 'declined' || outgoingStatus == 'cancelled')) {
        _snack(
          'La relance d’une demande refusée nécessite la mise à jour des règles Firestore.',
        );
        return;
      }
      _snack('Impossible d’envoyer la demande pour le moment.');
      return;
    }

    _snack('Demande envoyée à ${target.name}.');
  }

  Future<void> _acceptRequest(_FriendRequestEntry request) async {
    _log('Acceptation demande amie requestId=${request.id}');
    final requests = FirebaseFirestore.instance.collection('friend_requests');
    final friendships = FirebaseFirestore.instance.collection('friendships');
    final friendshipId = _friendshipId(request.fromUid, request.toUid);
    final now = Timestamp.now();

    final batch = FirebaseFirestore.instance.batch();
    batch.set(friendships.doc(friendshipId), {
      'participants': <String>[request.fromUid, request.toUid]..sort(),
      'createdAt': now,
      'createdBy': request.toUid,
    }, SetOptions(merge: true));
    batch.update(requests.doc(request.id), {
      'status': 'accepted',
      'acceptedAt': now,
    });
    batch.set(
      FirebaseFirestore.instance
          .collection('users')
          .doc(request.fromUid)
          .collection('inbox')
          .doc('friend_accept_${request.id}'),
      {
        'type': 'friend_request_accepted',
        'title': 'Ta demande d’ami a été acceptée',
        'body': 'Ton cercle social vient de s’agrandir dans FinHub.',
        'createdAt': now,
        'requestId': request.id,
        'duelId': null,
        'actorUid': request.toUid,
        'isRead': false,
      },
    );
    await batch.commit();
    _log('Succes acceptation demande amie requestId=${request.id}');
    _snack('Demande acceptée.');
  }

  Future<void> _declineRequest(_FriendRequestEntry request) async {
    _log('Refus demande amie requestId=${request.id}');
    final now = Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('friend_requests').doc(request.id),
      {'status': 'declined', 'declinedAt': now},
    );
    batch.set(
      FirebaseFirestore.instance
          .collection('users')
          .doc(request.fromUid)
          .collection('inbox')
          .doc('friend_decline_${request.id}'),
      {
        'type': 'friend_request_declined',
        'title': 'Ta demande d’ami a été refusée',
        'body': 'Tu peux rechercher un autre joueur quand tu veux.',
        'createdAt': now,
        'requestId': request.id,
        'duelId': null,
        'actorUid': request.toUid,
        'isRead': false,
      },
    );
    await batch.commit();
    _log('Succes refus demande amie requestId=${request.id}');
    _snack('Demande refusée.');
  }

  Future<void> _cancelRequest(_FriendRequestEntry request) async {
    _log('Annulation demande amie requestId=${request.id}');
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(request.id)
        .update({'status': 'cancelled', 'cancelledAt': Timestamp.now()});
    _log('Succes annulation demande amie requestId=${request.id}');
    _snack('Invitation annulée.');
  }

  Future<void> _openConnectionsSheet({
    required _ConnectionsTab initialTab,
  }) async {
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: true,
      builder:
          (_) => _SocialConnectionsSheet(
            currentUserId: widget.currentUserId,
            initialTab: initialTab,
            onSendRequest: _sendFriendRequest,
            onAcceptRequest: _acceptRequest,
            onDeclineRequest: _declineRequest,
            onCancelRequest: _cancelRequest,
          ),
    );
  }

  Future<void> _openProfile(_SocialUserEntry entry) async {
    await showSocialProfileSheet(
      context: context,
      userId: entry.uid,
      metric: _profileMetricFromLeaderboardMetric(_metric),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _currentUserStream(),
        builder: (context, currentUserSnapshot) {
          final currentEntry = _SocialUserEntry.fromUserDoc(
            currentUserSnapshot.data,
            fallbackUid: widget.currentUserId,
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _friendshipsStream(),
            builder: (context, friendshipSnapshot) {
              final friendIds = _extractFriendIds(friendshipSnapshot.data);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Social & badges',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onOpenCommunity,
                        child: const Text('Challenges'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ajoute des amis, compare ton niveau, ta streak, tes coins ou tes gemmes.',
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  _CurrentPlayerCard(
                    entry: currentEntry,
                    metric: _metric,
                    friendsCount: friendIds.length,
                    onTap: () => _openProfile(currentEntry),
                  ),
                  const SizedBox(height: 14),
                  _ScopeSelector(
                    scope: _scope,
                    onChanged: (scope) => setState(() => _scope = scope),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _LeaderboardMetric.values.map((metric) {
                          final selected = metric == _metric;
                          return FilterChip(
                            label: Text(_metricLabel(metric)),
                            selected: selected,
                            onSelected: (_) => setState(() => _metric = metric),
                            selectedColor: detailsColor1.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF7F8FA),
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: selected ? detailsColor2 : textColor,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color:
                                  selected
                                      ? detailsColor2.withValues(alpha: 0.18)
                                      : const Color(0xFFE6E8EB),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _incomingRequestsStream(),
                    builder: (context, requestSnapshot) {
                      final requests =
                          (requestSnapshot.data?.docs ?? const [])
                              .map(_FriendRequestEntry.fromDoc)
                              .toList();
                      return _ConnectionsGatewayCard(
                        friendsCount: friendIds.length,
                        pendingRequests: requests.length,
                        onTap:
                            () => _openConnectionsSheet(
                              initialTab:
                                  requests.isNotEmpty
                                      ? _ConnectionsTab.requests
                                      : _ConnectionsTab.search,
                            ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _LeaderboardSection(
                    scope: _scope,
                    metric: _metric,
                    globalStream: _globalUsersStream(),
                    currentUserId: widget.currentUserId,
                    friendIds: friendIds,
                    onOpenProfile: _openProfile,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<String> _extractFriendIds(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final ids = <String>{widget.currentUserId};
    for (final doc in snapshot?.docs ?? const []) {
      final participants = (doc.data()['participants'] as List<dynamic>? ??
              const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty);
      for (final uid in participants) {
        if (uid != widget.currentUserId) {
          ids.add(uid);
        }
      }
    }
    return ids.toList();
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.scope,
    required this.metric,
    required this.globalStream,
    required this.currentUserId,
    required this.friendIds,
    required this.onOpenProfile,
  });

  final _LeaderboardScope scope;
  final _LeaderboardMetric metric;
  final Stream<QuerySnapshot<Map<String, dynamic>>> globalStream;
  final String currentUserId;
  final List<String> friendIds;
  final ValueChanged<_SocialUserEntry> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final title =
        scope == _LeaderboardScope.global
            ? 'Top 10 global'
            : 'Classement entre amis';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tri actuel: ${_metricLabel(metric)}',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (scope == _LeaderboardScope.global)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: globalStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _EmptyLeaderboard(
                  message:
                      'Impossible de charger le classement global pour le moment.',
                );
              }
              final entries =
                  (snapshot.data?.docs ?? const [])
                      .map(
                        (doc) => _SocialUserEntry.fromUserDoc(
                          doc,
                          fallbackUid: doc.id,
                        ),
                      )
                      .whereType<_SocialUserEntry>()
                      .toList();
              return _LeaderboardList(
                entries: _sortEntries(entries, metric),
                metric: metric,
                onOpenProfile: onOpenProfile,
              );
            },
          )
        else
          _FriendsLeaderboard(
            friendIds: friendIds,
            metric: metric,
            onOpenProfile: onOpenProfile,
          ),
      ],
    );
  }
}

class _FriendsLeaderboard extends StatelessWidget {
  const _FriendsLeaderboard({
    required this.friendIds,
    required this.metric,
    required this.onOpenProfile,
  });

  final List<String> friendIds;
  final _LeaderboardMetric metric;
  final ValueChanged<_SocialUserEntry> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final ids = friendIds.take(30).toList();
    if (ids.length <= 1) {
      return const _EmptyLeaderboard(
        message: 'Ajoute des amis pour débloquer ce classement.',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: ids)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyLeaderboard(
            message:
                'Impossible de charger le classement entre amis pour le moment.',
          );
        }
        final entries =
            (snapshot.data?.docs ?? const [])
                .map(
                  (doc) =>
                      _SocialUserEntry.fromUserDoc(doc, fallbackUid: doc.id),
                )
                .whereType<_SocialUserEntry>()
                .toList();
        return _LeaderboardList(
          entries: _sortEntries(entries, metric),
          metric: metric,
          onOpenProfile: onOpenProfile,
        );
      },
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.metric,
    required this.onOpenProfile,
  });

  final List<_SocialUserEntry> entries;
  final _LeaderboardMetric metric;
  final ValueChanged<_SocialUserEntry> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyLeaderboard(
        message: 'Aucun joueur disponible pour ce filtre pour le moment.',
      );
    }
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == entries.length - 1 ? 0 : 10,
            ),
            child: _LeaderboardTile(
              rank: index + 1,
              entry: entries[index],
              metric: metric,
              onTap: () => onOpenProfile(entries[index]),
            ),
          ),
      ],
    );
  }
}

class _CurrentPlayerCard extends StatelessWidget {
  const _CurrentPlayerCard({
    required this.entry,
    required this.metric,
    required this.friendsCount,
    required this.onTap,
  });

  final _SocialUserEntry entry;
  final _LeaderboardMetric metric;
  final int friendsCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir mon profil social',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              _AvatarBadge(avatarId: entry.avatarId, rank: null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Niveau ${entry.level} · ${entry.streak} jours de streak',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_metricLabel(metric)}: ${_metricValueLabel(entry, metric)} · $friendsCount ami(s)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.profilePublic ? 'Public' : 'Privé',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionsGatewayCard extends StatelessWidget {
  const _ConnectionsGatewayCard({
    required this.friendsCount,
    required this.pendingRequests,
    required this.onTap,
  });

  final int friendsCount;
  final int pendingRequests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir Amis et demandes',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      if (pendingRequests > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amis & demandes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pendingRequests > 0
                            ? '$pendingRequests demande(s) en attente, $friendsCount ami(s) dans ton cercle.'
                            : 'Recherche un pseudo, envoie une invitation et gère ton cercle social.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _GatewayPill(label: '$friendsCount ami(s)'),
                          _GatewayPill(
                            label:
                                pendingRequests > 0
                                    ? '$pendingRequests à valider'
                                    : 'Ajouter un ami',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GatewayPill extends StatelessWidget {
  const _GatewayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _PendingRequestsCard extends StatelessWidget {
  const _PendingRequestsCard({
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  final List<_FriendRequestEntry> requests;
  final _AsyncFriendRequestAction onAccept;
  final _AsyncFriendRequestAction onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demandes d’amis',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < requests.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == requests.length - 1 ? 0 : 10,
              ),
              child: _PendingRequestRow(
                request: requests[index],
                onAccept: () {
                  onAccept(requests[index]);
                },
                onDecline: () {
                  onDecline(requests[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectionsRequestsView extends StatelessWidget {
  const _ConnectionsRequestsView({
    required this.incomingStream,
    required this.outgoingStream,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> incomingStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> outgoingStream;
  final _AsyncFriendRequestAction onAccept;
  final _AsyncFriendRequestAction onDecline;
  final _AsyncFriendRequestAction onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: incomingStream,
          builder: (context, snapshot) {
            final requests =
                (snapshot.data?.docs ?? const [])
                    .map(_FriendRequestEntry.fromDoc)
                    .toList();
            if (requests.isEmpty) {
              return const _ConnectionsEmptyCard(
                title: 'Aucune demande reçue',
                subtitle:
                    'Quand un autre joueur t’ajoute, la demande apparaîtra ici.',
              );
            }
            return _PendingRequestsCard(
              requests: requests,
              onAccept: onAccept,
              onDecline: onDecline,
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: outgoingStream,
          builder: (context, snapshot) {
            final requests =
                (snapshot.data?.docs ?? const [])
                    .map(_FriendRequestEntry.fromDoc)
                    .toList();
            if (requests.isEmpty) {
              return const _ConnectionsEmptyCard(
                title: 'Aucune invitation envoyée',
                subtitle:
                    'Utilise l’onglet Ajouter pour rechercher un pseudo et envoyer une demande.',
              );
            }
            return _OutgoingRequestsCard(
              requests: requests,
              onCancel: onCancel,
            );
          },
        ),
      ],
    );
  }
}

class _OutgoingRequestsCard extends StatelessWidget {
  const _OutgoingRequestsCard({required this.requests, required this.onCancel});

  final List<_FriendRequestEntry> requests;
  final _AsyncFriendRequestAction onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invitations envoyées',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < requests.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == requests.length - 1 ? 0 : 10,
              ),
              child: _OutgoingRequestRow(
                request: requests[index],
                onCancel: () {
                  onCancel(requests[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OutgoingRequestRow extends StatelessWidget {
  const _OutgoingRequestRow({required this.request, required this.onCancel});

  final _FriendRequestEntry request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(request.toUid)
              .get(),
      builder: (context, snapshot) {
        final entry = _SocialUserEntry.fromUserDoc(
          snapshot.data,
          fallbackUid: request.toUid,
        );
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _AvatarBadge(avatarId: entry.avatarId, rank: null),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.name,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: detailsColor1.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'En attente',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onCancel, child: const Text('Annuler')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionsEmptyCard extends StatelessWidget {
  const _ConnectionsEmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SearchSuggestionsHeader extends StatelessWidget {
  const _SearchSuggestionsHeader({
    required this.query,
    required this.isSearching,
  });

  final String query;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final label =
        query.isEmpty ? 'Suggestions du moment' : 'Suggestions pour "$query"';
    final subtitle =
        query.isEmpty
            ? 'Profils actifs et visibles rapidement dans FinHub.'
            : 'Les meilleurs profils proches de ta saisie remontent ici.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            detailsColor1.withValues(alpha: 0.14),
            detailsColor2.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                isSearching
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                    : Container(
                      key: const ValueKey('ready'),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: detailsColor2,
                        size: 18,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestRow extends StatelessWidget {
  const _PendingRequestRow({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final _FriendRequestEntry request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(request.fromUid)
              .get(),
      builder: (context, snapshot) {
        final entry = _SocialUserEntry.fromUserDoc(
          snapshot.data,
          fallbackUid: request.fromUid,
        );
        final name = entry.name;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _AvatarBadge(avatarId: entry.avatarId, rank: null),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(onPressed: onDecline, child: const Text('Refuser')),
              ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accepter'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SocialConnectionsSheet extends StatefulWidget {
  const _SocialConnectionsSheet({
    required this.currentUserId,
    required this.initialTab,
    required this.onSendRequest,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onCancelRequest,
  });

  final String currentUserId;
  final _ConnectionsTab initialTab;
  final _AsyncSocialUserAction onSendRequest;
  final _AsyncFriendRequestAction onAcceptRequest;
  final _AsyncFriendRequestAction onDeclineRequest;
  final _AsyncFriendRequestAction onCancelRequest;

  @override
  State<_SocialConnectionsSheet> createState() =>
      _SocialConnectionsSheetState();
}

class _SocialConnectionsSheetState extends State<_SocialConnectionsSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _searchDebounce;
  late _ConnectionsTab _tab;
  late Future<List<_SocialUserEntry>> _searchFuture;
  String _query = '';
  String _debouncedQuery = '';
  final Set<String> _busyUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _searchFuture = _searchEntries('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final nextQuery = value.trim();
      setState(() {
        _debouncedQuery = nextQuery;
        _searchFuture = _searchEntries(nextQuery);
      });
    });
  }

  Future<List<_SocialUserEntry>> _searchEntries(String rawQuery) async {
    final users = FirebaseFirestore.instance.collection('users');
    final normalizedQuery = _normalizeFriendSearch(rawQuery);
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      users
          .orderBy('xp', descending: true)
          .limit(rawQuery.isEmpty ? 12 : 80)
          .get(),
    ];

    if (rawQuery.isNotEmpty) {
      for (final prefix in _searchPrefixes(rawQuery)) {
        futures.add(
          users
              .orderBy('Name')
              .startAt(<String>[prefix])
              .endAt(<String>['$prefix\uf8ff'])
              .limit(20)
              .get(),
        );
      }
    }

    final snapshots = await Future.wait(futures);
    final entriesById = <String, _SocialUserEntry>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final entry = _SocialUserEntry.fromUserDoc(doc, fallbackUid: doc.id);
        if (entry.uid == widget.currentUserId) continue;
        entriesById[entry.uid] = entry;
      }
    }

    final entries =
        entriesById.values.where((entry) {
          if (normalizedQuery.isEmpty) return true;
          return _friendSearchScore(entry, normalizedQuery) >= 0;
        }).toList();

    entries.sort(
      (left, right) =>
          _compareFriendSearchEntries(left, right, normalizedQuery),
    );
    return entries.take(12).toList();
  }

  Future<void> _handleSendRequest(_SocialUserEntry entry) async {
    FocusScope.of(context).unfocus();
    debugPrint('[SocialFriends] UI Ajouter: clic sur ${entry.uid}');
    setState(() => _busyUserIds.add(entry.uid));
    try {
      await widget.onSendRequest(entry);
    } on FirebaseException catch (error) {
      debugPrint(
        '[SocialFriends] UI Ajouter: erreur Firebase sur ${entry.uid} code=${error.code}',
      );
      final message =
          error.code == 'permission-denied'
              ? 'Firestore refuse cette demande. Mets à jour les règles puis réessaie.'
              : 'Impossible d’envoyer la demande pour le moment.';
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      debugPrint(
        '[SocialFriends] UI Ajouter: erreur inattendue sur ${entry.uid}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’envoyer la demande pour le moment.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(entry.uid));
      }
    }
  }

  Future<void> _handleRequestAction(
    String uid,
    Future<void> Function() action,
  ) async {
    debugPrint('[SocialFriends] UI Demandes: action sur $uid');
    setState(() => _busyUserIds.add(uid));
    try {
      await action();
      debugPrint('[SocialFriends] UI Demandes: action terminee sur $uid');
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(uid));
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _friendshipsStream() {
    return FirebaseFirestore.instance
        .collection('friendships')
        .where('participants', arrayContains: widget.currentUserId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _incomingRequestsStream() {
    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: widget.currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _outgoingRequestsStream() {
    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUid', isEqualTo: widget.currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Amis & demandes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Recherche des profils, envoie une invitation et accepte les demandes depuis un seul endroit.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _GatewayPill(
                          label:
                              _tab == _ConnectionsTab.requests
                                  ? 'Validation rapide'
                                  : 'Recherche par pseudo',
                        ),
                        _GatewayPill(
                          label:
                              _tab == _ConnectionsTab.requests
                                  ? 'Réceptions + envois'
                                  : 'Ajout instantané',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: CupertinoSlidingSegmentedControl<_ConnectionsTab>(
                groupValue: _tab,
                thumbColor: detailsColor2.withValues(alpha: 0.18),
                backgroundColor: Colors.black.withValues(alpha: 0.06),
                children: const <_ConnectionsTab, Widget>{
                  _ConnectionsTab.requests: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Demandes'),
                  ),
                  _ConnectionsTab.search: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Ajouter'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _tab = value);
                },
              ),
            ),
            Expanded(
              child:
                  _tab == _ConnectionsTab.requests
                      ? _ConnectionsRequestsView(
                        incomingStream: _incomingRequestsStream(),
                        outgoingStream: _outgoingRequestsStream(),
                        onAccept: widget.onAcceptRequest,
                        onDecline: widget.onDeclineRequest,
                        onCancel: widget.onCancelRequest,
                      )
                      : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE6E8EB),
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                onChanged: _onSearchChanged,
                                onTapOutside:
                                    (_) =>
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus(),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Rechercher un pseudo...',
                                  icon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: _friendshipsStream(),
                              builder: (context, friendshipSnapshot) {
                                final friendIds =
                                    (friendshipSnapshot.data?.docs ?? const [])
                                        .expand(
                                          (doc) =>
                                              (doc.data()['participants']
                                                      as List<dynamic>? ??
                                                  const <dynamic>[]),
                                        )
                                        .map((value) => value.toString())
                                        .where((value) => value.isNotEmpty)
                                        .toSet()
                                      ..remove(widget.currentUserId);
                                return StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: _incomingRequestsStream(),
                                  builder: (context, incomingSnapshot) {
                                    final incomingByUser =
                                        <String, _FriendRequestEntry>{
                                          for (final request
                                              in (incomingSnapshot.data?.docs ??
                                                      const [])
                                                  .map(
                                                    _FriendRequestEntry.fromDoc,
                                                  ))
                                            request.fromUid: request,
                                        };
                                    return StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >(
                                      stream: _outgoingRequestsStream(),
                                      builder: (context, outgoingSnapshot) {
                                        final outgoingByUser = <
                                          String,
                                          _FriendRequestEntry
                                        >{
                                          for (final request
                                              in (outgoingSnapshot.data?.docs ??
                                                      const [])
                                                  .map(
                                                    _FriendRequestEntry.fromDoc,
                                                  ))
                                            request.toUid: request,
                                        };
                                        return FutureBuilder<
                                          List<_SocialUserEntry>
                                        >(
                                          future: _searchFuture,
                                          builder: (context, snapshot) {
                                            final entries =
                                                snapshot.data ??
                                                const <_SocialUserEntry>[];
                                            final trimmedQuery = _query.trim();
                                            final isSearching =
                                                _debouncedQuery != trimmedQuery;
                                            if (snapshot.connectionState ==
                                                    ConnectionState.waiting &&
                                                entries.isEmpty) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            if (entries.isEmpty) {
                                              return Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    24,
                                                  ),
                                                  child: Text(
                                                    trimmedQuery.isEmpty
                                                        ? 'Les profils les plus actifs apparaissent ici.'
                                                        : 'Aucun profil proche de "$trimmedQuery".',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: textColor,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            return ListView.separated(
                                              key: ValueKey(_debouncedQuery),
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    16,
                                                    16,
                                                    24,
                                                  ),
                                              itemCount: entries.length + 1,
                                              separatorBuilder:
                                                  (_, __) => const SizedBox(
                                                    height: 10,
                                                  ),
                                              itemBuilder: (context, index) {
                                                if (index == 0) {
                                                  return _SearchSuggestionsHeader(
                                                    query: trimmedQuery,
                                                    isSearching: isSearching,
                                                  );
                                                }
                                                final entry =
                                                    entries[index - 1];
                                                final isBusy = _busyUserIds
                                                    .contains(entry.uid);
                                                final isFriend = friendIds
                                                    .contains(entry.uid);
                                                final outgoingRequest =
                                                    outgoingByUser[entry.uid];
                                                final incomingRequest =
                                                    incomingByUser[entry.uid];
                                                return Container(
                                                  padding: const EdgeInsets.all(
                                                    14,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFE6E8EB,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      _AvatarBadge(
                                                        avatarId:
                                                            entry.avatarId,
                                                        rank: null,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              entry.name,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              'Niveau ${entry.level} · ${entry.streak} jours · ${entry.coins} coins',
                                                              style: const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .black54,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      _ConnectionActionArea(
                                                        isBusy: isBusy,
                                                        isFriend: isFriend,
                                                        hasOutgoingRequest:
                                                            outgoingRequest !=
                                                            null,
                                                        hasIncomingRequest:
                                                            incomingRequest !=
                                                            null,
                                                        onAdd:
                                                            () =>
                                                                _handleSendRequest(
                                                                  entry,
                                                                ),
                                                        onAccept:
                                                            incomingRequest ==
                                                                    null
                                                                ? null
                                                                : () => _handleRequestAction(
                                                                  entry.uid,
                                                                  () => widget
                                                                      .onAcceptRequest(
                                                                        incomingRequest,
                                                                      ),
                                                                ),
                                                        onDecline:
                                                            incomingRequest ==
                                                                    null
                                                                ? null
                                                                : () => _handleRequestAction(
                                                                  entry.uid,
                                                                  () => widget
                                                                      .onDeclineRequest(
                                                                        incomingRequest,
                                                                      ),
                                                                ),
                                                      ),
                                                    ],
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
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionActionArea extends StatelessWidget {
  const _ConnectionActionArea({
    required this.isBusy,
    required this.isFriend,
    required this.hasOutgoingRequest,
    required this.hasIncomingRequest,
    required this.onAdd,
    required this.onAccept,
    required this.onDecline,
  });

  final bool isBusy;
  final bool isFriend;
  final bool hasOutgoingRequest;
  final bool hasIncomingRequest;
  final VoidCallback onAdd;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    if (isFriend) {
      return const _ConnectionStatePill(
        label: 'Ami',
        icon: Icons.verified_rounded,
      );
    }
    if (hasOutgoingRequest) {
      return const _ConnectionStatePill(
        label: 'En attente',
        icon: Icons.schedule_rounded,
      );
    }
    if (hasIncomingRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FilledButton.tonalIcon(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: detailsColor1.withValues(alpha: 0.14),
              foregroundColor: detailsColor2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Accepter'),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onDecline, child: const Text('Refuser')),
        ],
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onAdd,
      style: FilledButton.styleFrom(
        backgroundColor: detailsColor1.withValues(alpha: 0.14),
        foregroundColor: detailsColor2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Ajouter'),
    );
  }
}

class _ConnectionStatePill extends StatelessWidget {
  const _ConnectionStatePill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: detailsColor2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: detailsColor2),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: detailsColor2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    required this.metric,
    required this.onTap,
  });

  final int rank;
  final _SocialUserEntry entry;
  final _LeaderboardMetric metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeLabel =
        entry.badges.isEmpty ? 'Profil actif' : entry.badges.first;
    return Semantics(
      button: true,
      label: 'Ouvrir le profil de ${entry.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Row(
            children: [
              _AvatarBadge(avatarId: entry.avatarId, rank: rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Niveau ${entry.level} · ${entry.streak} jours de streak',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _metricValueLabel(entry, metric),
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: detailsColor2.withValues(alpha: 0.08),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: detailsColor2,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.avatarId, required this.rank});

  final String? avatarId;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final asset = _avatarAsset(avatarId);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child:
                  asset == null
                      ? const DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      )
                      : Image.asset(asset, fit: BoxFit.cover),
            ),
          ),
        ),
        if (rank != null)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SocialProfileSheetLoader extends StatelessWidget {
  const _SocialProfileSheetLoader({
    required this.userId,
    required this.initialUserData,
    required this.metric,
  });

  final String userId;
  final Map<String, dynamic>? initialUserData;
  final _LeaderboardMetric metric;

  @override
  Widget build(BuildContext context) {
    if (initialUserData != null) {
      return _SocialProfileSheet(
        entry: _SocialUserEntry.fromMap(initialUserData, fallbackUid: userId),
        metric: metric,
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Material(
            color: backgroundColor,
            child: SafeArea(
              top: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return _SocialProfileSheet(
          entry: _SocialUserEntry.fromUserDoc(
            snapshot.data,
            fallbackUid: userId,
          ),
          metric: metric,
        );
      },
    );
  }
}

class _SocialProfileSheet extends StatelessWidget {
  const _SocialProfileSheet({required this.entry, required this.metric});

  final _SocialUserEntry entry;
  final _LeaderboardMetric metric;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ListView(
            children: [
              Row(
                children: [
                  const SizedBox(width: 34, height: 34),
                  const Spacer(),
                  Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: textColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    _AvatarBadge(avatarId: entry.avatarId, rank: null),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Niveau ${entry.level} · ${entry.xp} XP',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_metricLabel(metric)}: ${_metricValueLabel(entry, metric)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ProfileMetric(
                      title: 'Streak',
                      value: '${entry.streak}',
                      subtitle: 'jours actifs',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileMetric(
                      title: 'Coins',
                      value: '${entry.coins}',
                      subtitle: 'simulation',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileMetric(
                      title: 'Gemmes',
                      value: '${entry.gems}',
                      subtitle: 'progression',
                    ),
                  ),
                ],
              ),
              if (entry.badges.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ProfileCard(
                  title: 'Badges visibles',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        entry.badges
                            .map(
                              (badge) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: detailsColor1.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
              if (entry.interests.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ProfileCard(
                  title: 'Centres d’intérêt',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        entry.interests
                            .map(
                              (interest) => Chip(
                                label: Text(interest),
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.05,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.scope, required this.onChanged});

  final _LeaderboardScope scope;
  final ValueChanged<_LeaderboardScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          _LeaderboardScope.values.map((candidate) {
            final selected = candidate == scope;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: candidate == _LeaderboardScope.global ? 8 : 0,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(candidate),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? detailsColor2.withValues(alpha: 0.10)
                              : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            selected
                                ? detailsColor2.withValues(alpha: 0.20)
                                : const Color(0xFFE6E8EB),
                      ),
                    ),
                    child: Text(
                      candidate == _LeaderboardScope.global ? 'Global' : 'Amis',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? detailsColor2 : textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.black54, height: 1.35),
      ),
    );
  }
}

class _FriendRequestEntry {
  const _FriendRequestEntry({
    required this.id,
    required this.fromUid,
    required this.toUid,
  });

  final String id;
  final String fromUid;
  final String toUid;

  factory _FriendRequestEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _FriendRequestEntry(
      id: doc.id,
      fromUid: (data['fromUid'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
    );
  }
}

class _SocialUserEntry {
  const _SocialUserEntry({
    required this.uid,
    required this.name,
    required this.avatarId,
    required this.profilePublic,
    required this.badges,
    required this.interests,
    required this.xp,
    required this.level,
    required this.streak,
    required this.coins,
    required this.gems,
  });

  final String uid;
  final String name;
  final String? avatarId;
  final bool profilePublic;
  final List<String> badges;
  final List<String> interests;
  final int xp;
  final int level;
  final int streak;
  final int coins;
  final int gems;

  factory _SocialUserEntry.fromMap(
    Map<String, dynamic>? data, {
    required String fallbackUid,
  }) {
    if (data == null) {
      return _SocialUserEntry(
        uid: fallbackUid,
        name: 'Utilisateur',
        avatarId: null,
        profilePublic: true,
        badges: const <String>[],
        interests: const <String>[],
        xp: 0,
        level: 1,
        streak: 0,
        coins: 0,
        gems: 0,
      );
    }
    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    return _SocialUserEntry(
      uid: fallbackUid,
      name: _displayName(data),
      avatarId: data['avatar_id'] as String?,
      profilePublic: (data['profile_public'] as bool?) != false,
      badges: _prettyBadges(data['achievements_claimed']),
      interests:
          (data['interests'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .take(4)
              .toList(),
      xp: xp,
      level: _levelForXp(xp),
      streak: (data['current_streak'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      gems: (data['gems'] as num?)?.toInt() ?? 0,
    );
  }

  factory _SocialUserEntry.fromUserDoc(
    DocumentSnapshot<Map<String, dynamic>>? doc, {
    required String fallbackUid,
  }) {
    return _SocialUserEntry.fromMap(
      doc?.data(),
      fallbackUid: doc?.id ?? fallbackUid,
    );
  }
}

List<_SocialUserEntry> _sortEntries(
  List<_SocialUserEntry> entries,
  _LeaderboardMetric metric,
) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final left = _metricNumericValue(a, metric);
    final right = _metricNumericValue(b, metric);
    final compare = right.compareTo(left);
    if (compare != 0) return compare;
    return b.xp.compareTo(a.xp);
  });
  return sorted.take(10).toList();
}

List<String> _searchPrefixes(String rawQuery) {
  final trimmed = rawQuery.trim();
  if (trimmed.isEmpty) return const <String>[];
  final titleCased =
      trimmed.length == 1
          ? trimmed.toUpperCase()
          : '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  return <String>{
    trimmed,
    trimmed.toLowerCase(),
    trimmed.toUpperCase(),
    titleCased,
  }.where((value) => value.isNotEmpty).toList();
}

String _normalizeFriendSearch(String value) {
  final lowered = value.trim().toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };
  var normalized = lowered;
  replacements.forEach((source, target) {
    normalized = normalized.replaceAll(source, target);
  });
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

int _friendSearchScore(_SocialUserEntry entry, String normalizedQuery) {
  final normalizedName = _normalizeFriendSearch(entry.name);
  if (normalizedQuery.isEmpty) return entry.xp;
  if (normalizedName == normalizedQuery) return 5000 + entry.xp;
  if (normalizedName.startsWith(normalizedQuery)) {
    return 4200 - normalizedName.length + entry.xp;
  }
  final tokenMatch = normalizedName
      .split(' ')
      .where((token) => token.isNotEmpty)
      .any((token) => token.startsWith(normalizedQuery));
  if (tokenMatch) return 3500 + entry.xp;
  final containsIndex = normalizedName.indexOf(normalizedQuery);
  if (containsIndex >= 0) return 2600 - (containsIndex * 12) + entry.xp;
  if (_isLooseSubsequence(normalizedQuery, normalizedName)) {
    return 1800 + entry.xp;
  }
  return -1;
}

int _compareFriendSearchEntries(
  _SocialUserEntry left,
  _SocialUserEntry right,
  String normalizedQuery,
) {
  final scoreCompare = _friendSearchScore(
    right,
    normalizedQuery,
  ).compareTo(_friendSearchScore(left, normalizedQuery));
  if (scoreCompare != 0) return scoreCompare;
  final nameCompare = left.name.toLowerCase().compareTo(
    right.name.toLowerCase(),
  );
  if (nameCompare != 0) return nameCompare;
  return right.xp.compareTo(left.xp);
}

bool _isLooseSubsequence(String needle, String haystack) {
  if (needle.isEmpty) return true;
  var cursor = 0;
  for (final rune in haystack.runes) {
    if (cursor < needle.length && String.fromCharCode(rune) == needle[cursor]) {
      cursor += 1;
      if (cursor == needle.length) return true;
    }
  }
  return false;
}

num _metricNumericValue(_SocialUserEntry entry, _LeaderboardMetric metric) {
  switch (metric) {
    case _LeaderboardMetric.level:
      return entry.level;
    case _LeaderboardMetric.streak:
      return entry.streak;
    case _LeaderboardMetric.coins:
      return entry.coins;
    case _LeaderboardMetric.gems:
      return entry.gems;
  }
}

_LeaderboardMetric _leaderboardMetricFromProfileMetric(
  SocialProfileMetric metric,
) {
  switch (metric) {
    case SocialProfileMetric.level:
      return _LeaderboardMetric.level;
    case SocialProfileMetric.streak:
      return _LeaderboardMetric.streak;
    case SocialProfileMetric.coins:
      return _LeaderboardMetric.coins;
    case SocialProfileMetric.gems:
      return _LeaderboardMetric.gems;
  }
}

SocialProfileMetric _profileMetricFromLeaderboardMetric(
  _LeaderboardMetric metric,
) {
  switch (metric) {
    case _LeaderboardMetric.level:
      return SocialProfileMetric.level;
    case _LeaderboardMetric.streak:
      return SocialProfileMetric.streak;
    case _LeaderboardMetric.coins:
      return SocialProfileMetric.coins;
    case _LeaderboardMetric.gems:
      return SocialProfileMetric.gems;
  }
}

String _metricLabel(_LeaderboardMetric metric) {
  switch (metric) {
    case _LeaderboardMetric.level:
      return 'Niveau';
    case _LeaderboardMetric.streak:
      return 'Streak';
    case _LeaderboardMetric.coins:
      return 'Coins';
    case _LeaderboardMetric.gems:
      return 'Gemmes';
  }
}

String _metricValueLabel(_SocialUserEntry entry, _LeaderboardMetric metric) {
  switch (metric) {
    case _LeaderboardMetric.level:
      return 'Niveau ${entry.level}';
    case _LeaderboardMetric.streak:
      return '${entry.streak} jours';
    case _LeaderboardMetric.coins:
      return '${entry.coins} coins';
    case _LeaderboardMetric.gems:
      return '${entry.gems} gemmes';
  }
}

String _friendshipId(String uidA, String uidB) {
  final ids = <String>[uidA, uidB]..sort();
  return '${ids[0]}_${ids[1]}';
}

int _levelForXp(int xp) {
  final safeXp = xp.clamp(0, 100000000);
  return (math.log((safeXp / 500) + 1) / math.log(1.2)).floor() + 1;
}

String _displayName(Map<String, dynamic> data) {
  final name = (data['Name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;
  final fallback = (data['name'] as String?)?.trim();
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return 'Utilisateur';
}

List<String> _prettyBadges(dynamic raw) {
  final values =
      (raw as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();

  return values.map((value) {
    switch (value) {
      case 'investor_50k':
        return 'Investisseur 50k';
      case 'wealthy_10k':
        return 'Capital 10k';
      default:
        return value
            .replaceAll('_', ' ')
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map(
              (part) => part[0].toUpperCase() + part.substring(1).toLowerCase(),
            )
            .join(' ');
    }
  }).toList();
}

String? _avatarAsset(String? id) {
  if (id == null || id.isEmpty) return null;
  if (id == '_easteregg') return 'assets/avatars/easteregg.png';
  if (id == '_sydsteregg') return 'assets/avatars/sydsteregg.png';
  if (id == '_call') return 'assets/avatars/avatar_call.png';
  if (id == '_happy') return 'assets/avatars/avatar_happy.png';
  if (id == '_wealthy') return 'assets/avatars/avatar_wealthy.png';
  if (id == '_rich') return 'assets/avatars/avatar_rich.png';
  if (id == '_geek') return 'assets/avatars/avatar_geek.png';
  return 'assets/avatars/avatar$id.png';
}
