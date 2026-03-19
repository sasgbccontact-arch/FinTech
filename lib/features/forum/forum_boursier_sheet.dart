import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/models/chart_models.dart';
import 'package:fintech/services/yahoo_finance_service.dart';

// ─── Constantes ──────────────────────────────────────────────────────────────

const List<String> _forumPostTypes = <String>[
  'discussion',
  'question',
  'analyse',
  'alerte',
  'pitch',
];

const List<String> _forumTagOptions = <String>[
  'Actions',
  'ETF',
  'Dividendes',
  'Macro',
  'Débutant',
  'Portefeuille',
  'Swing',
  'Long terme',
];

const String _composerFabSvg = '''
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="pg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F5D76E"/>
      <stop offset="100%" stop-color="#D4AF37"/>
    </linearGradient>
  </defs>
  <path d="M62 18 L78 34 L36 76 L18 80 L22 62 Z" fill="url(#pg)" stroke="#2A0F45" stroke-width="3" stroke-linejoin="round"/>
  <path d="M56 24 L72 40" stroke="#2A0F45" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M22 62 L34 74" stroke="#2A0F45" stroke-width="2.5" stroke-linecap="round"/>
  <circle cx="76" cy="22" r="7" fill="#2A0F45" opacity="0.14"/>
</svg>
''';

// ─── Widget racine ────────────────────────────────────────────────────────────

class ForumBoursierSheet extends StatefulWidget {
  const ForumBoursierSheet({super.key});

  @override
  State<ForumBoursierSheet> createState() => _ForumBoursierSheetState();
}

// ─── State principal ──────────────────────────────────────────────────────────

class _ForumBoursierSheetState extends State<ForumBoursierSheet>
    with TickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  // Feed state
  String _searchQuery = '';
  String? _activeTagFilter;
  bool _bookmarksOnly = false;
  bool _sortByTop = true;
  bool _filtersCollapsed = false;
  bool _canModerate = false;
  String? _expandedMessageId;
  // 5.1 — posts négatifs dont l'user a forcé l'affichage
  final Set<String> _forceExpandedNegative = {};

  // Pagination
  int _queryLimit = 30;
  bool _isLoadingMore = false;

  // Thèmes suivis
  Set<String> _followedThemeIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _followedThemesSub;

  // 4.1 — notifications in-app
  int _unreadNotifCount = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

  // FAB animation
  late final AnimationController _fabCtrl;

  @override
  void initState() {
    super.initState();
    _loadModeratorStatus();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _listenFollowedThemes();
    _listenNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabCtrl.dispose();
    _followedThemesSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  // ── Thèmes suivis ────────────────────────────────────────────────────────

  void _listenFollowedThemes() {
    final user = _user;
    if (user == null) return;
    _followedThemesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('followed_themes')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() => _followedThemeIds = snap.docs.map((d) => d.id).toSet());
    });
  }

  Future<void> _toggleFollowTheme(String themeId, String themeName) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour suivre un thème.');
      return;
    }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('followed_themes')
        .doc(themeId);
    try {
      if (_followedThemeIds.contains(themeId)) {
        await ref.delete();
        _snack('Thème "$themeName" retiré de tes suivis.');
      } else {
        await ref.set({'name': themeName, 'followedAt': Timestamp.now()});
        _snack('Tu suis maintenant "$themeName".');
      }
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  // ── 4.1 — Notifications in-app ───────────────────────────────────────────

  void _listenNotifications() {
    final user = _user;
    if (user == null) return;
    _notifSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('forum_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() => _unreadNotifCount = snap.docs.length);
    });
  }

  Future<void> _writeNotification({
    required String targetUid,
    required String type,
    required String postId,
    String? score,
  }) async {
    final user = _user;
    if (user == null || targetUid == user.uid) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('forum_notifications')
          .add({
        'type': type,
        'postId': postId,
        'fromUid': user.uid,
        'fromName': _authorName(user),
        'createdAt': Timestamp.now(),
        'read': false,
        if (score != null) 'score': score,
      });
    } catch (_) {}
  }

  Future<void> _markAllNotificationsRead() async {
    final user = _user;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('forum_notifications')
          .where('read', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  void _openNotificationsSheet() {
    _markAllNotificationsRead();
    showCupertinoModalBottomSheet<void>(
      context: context,
      expand: false,
      builder: (_) => _NotificationsSheet(uid: _user!.uid),
    );
  }

  // ── Pagination ───────────────────────────────────────────────────────────

  void _loadMore() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _queryLimit += 30;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoadingMore = false);
    });
  }

  // ── Composer (FAB) ───────────────────────────────────────────────────────

  void _openComposer() {
    showCupertinoModalBottomSheet<void>(
      context: context,
      expand: false,
      builder: (_) => _ComposerBottomSheet(
        user: _user,
        themesQuery: _themesQuery(),
      ),
    );
  }

  // ── Hot score ────────────────────────────────────────────────────────────

  double _hotScore(_ForumMessage m) {
    final ageHours = m.createdAt != null
        ? DateTime.now()
                .difference(m.createdAt!.toDate())
                .inMinutes
                .toDouble() /
            60.0
        : 0.0;
    return m.score / math.pow(ageHours + 2.0, 1.5);
  }

  // ── Firestore queries ────────────────────────────────────────────────────

  Future<void> _loadModeratorStatus() async {
    final user = _user;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() => _canModerate = snap.data()?['isAdmin'] == true);
    } catch (_) {}
  }

  Query<Map<String, dynamic>> _themesQuery() {
    return FirebaseFirestore.instance
        .collection('forum_themes')
        .orderBy('name');
  }

  Query<Map<String, dynamic>> _messagesQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('forum_chat_messages');
    if (_sortByTop) {
      query = query
          .orderBy('score', descending: true)
          .orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    return query.limit(_queryLimit);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _bookmarksStream() {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('forum_bookmarks')
        .snapshots();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ── Actions messages ─────────────────────────────────────────────────────

  Future<void> _sendReply(_ForumMessage message, String text) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour répondre.');
      return;
    }
    final replyText = text.trim();
    if (replyText.isEmpty) return;
    try {
      // Fetch pseudo + avatar depuis Firestore
      String replyAuthorName = _authorName(user);
      String? replyAvatarId;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final d = snap.data() ?? {};
        final firestoreName = (d['Name'] as String?)?.trim() ?? '';
        if (firestoreName.isNotEmpty) replyAuthorName = firestoreName;
        replyAvatarId = d['avatar_id'] as String?;
      } catch (_) {}

      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .doc(message.id)
          .collection('replies')
          .add({
        'text': replyText,
        'uid': user.uid,
        'authorName': replyAuthorName,
        'authorAvatarId': replyAvatarId,
        'photoURL': user.photoURL,
        'createdAt': now,
        'upVotes': 0,
        'downVotes': 0,
        'score': 0,
      });
      // 4.1 — notif reply → auteur du post
      unawaited(_writeNotification(
        targetUid: message.uid,
        type: 'reply',
        postId: message.id,
      ));
      // 4.1 — notif mention → chaque @pseudo dans le texte
      final mentionRegex = RegExp(r'@(\w+)');
      for (final m in mentionRegex.allMatches(replyText)) {
        final mentionedName = m.group(1) ?? '';
        if (mentionedName.isEmpty) continue;
        // Cherche l'uid dans les réponses existantes (best-effort)
        try {
          final snap = await FirebaseFirestore.instance
              .collection('forum_chat_messages')
              .doc(message.id)
              .collection('replies')
              .where('authorName', isEqualTo: mentionedName)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final targetUid =
                (snap.docs.first.data()['uid'] as String?) ?? '';
            if (targetUid.isNotEmpty) {
              unawaited(_writeNotification(
                targetUid: targetUid,
                type: 'mention',
                postId: message.id,
              ));
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _expandedMessageId = message.id);
    } catch (e) {
      _snack('Impossible de répondre : $e');
    }
  }

  Future<void> _toggleBookmark(_ForumMessage message) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour enregistrer un message.');
      return;
    }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('forum_bookmarks')
        .doc(message.id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'messageId': message.id,
        'themeId': message.themeId,
        'themeName': message.themeName,
        'postType': message.postType,
        'createdAt': Timestamp.now(),
      });
    }
  }

  Future<void> _voteMessage({
    required _ForumMessage message,
    required int value,
  }) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour voter.');
      return;
    }
    if (message.uid == user.uid) {
      _snack('Tu ne peux pas voter pour ton propre message.');
      return;
    }
    final messageRef = FirebaseFirestore.instance
        .collection('forum_chat_messages')
        .doc(message.id);
    final voteRef = messageRef.collection('votes').doc(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final now = Timestamp.now();
        final voteSnap = await tx.get(voteRef);
        final previous =
            voteSnap.exists ? ((voteSnap.data()?['value'] as int?) ?? 0) : 0;
        final next = previous == value ? 0 : value;
        var deltaUp = 0;
        var deltaDown = 0;
        var deltaScore = 0;
        if (previous == 1) {
          deltaUp -= 1;
          deltaScore -= 1;
        } else if (previous == -1) {
          deltaDown -= 1;
          deltaScore += 1;
        }
        if (next == 1) {
          deltaUp += 1;
          deltaScore += 1;
        } else if (next == -1) {
          deltaDown += 1;
          deltaScore -= 1;
        }
        tx.update(messageRef, {
          'upVotes': FieldValue.increment(deltaUp),
          'downVotes': FieldValue.increment(deltaDown),
          'score': FieldValue.increment(deltaScore),
          'lastVoteAt': now,
        });
        // 3.3 — mise à jour karma de l'auteur (atomique)
        if (deltaScore != 0) {
          final authorUserRef = FirebaseFirestore.instance
              .collection('users')
              .doc(message.uid);
          tx.set(authorUserRef, {'karma': FieldValue.increment(deltaScore)},
              SetOptions(merge: true));
        }
        if (next == 0) {
          if (voteSnap.exists) tx.delete(voteRef);
        } else {
          tx.set(voteRef, {'value': next, 'updatedAt': now});
        }
      });
    } catch (e) {
      _snack('Vote impossible : $e');
      return;
    }
    // 4.1 — notification vote_milestone (best-effort, hors transaction)
    unawaited(() async {
      try {
        final updatedSnap = await FirebaseFirestore.instance
            .collection('forum_chat_messages')
            .doc(message.id)
            .get();
        final newScore =
            (updatedSnap.data()?['score'] as num?)?.toInt() ?? 0;
        const milestones = [10, 25, 50, 100];
        if (milestones.contains(newScore)) {
          await _writeNotification(
            targetUid: message.uid,
            type: 'vote_milestone',
            postId: message.id,
            score: '$newScore',
          );
        }
      } catch (_) {}
    }());
  }

  Future<void> _reactToMessage({
    required _ForumMessage message,
    required String reactionKey,
  }) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour réagir.');
      return;
    }
    if (message.uid == user.uid) {
      _snack('Tu ne peux pas réagir à ton propre message.');
      return;
    }
    final messageRef = FirebaseFirestore.instance
        .collection('forum_chat_messages')
        .doc(message.id);
    final reactionRef = messageRef.collection('reactions').doc(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final messageSnap = await tx.get(messageRef);
        if (!messageSnap.exists) return;
        final reactionSnap = await tx.get(reactionRef);
        final previous = (reactionSnap.data()?['key'] as String?) ?? '';
        final next = previous == reactionKey ? '' : reactionKey;
        final now = Timestamp.now();
        final rawReactions =
            messageSnap.data()?['reactions'] as Map<String, dynamic>? ??
                const <String, dynamic>{};
        final nextReactions = <String, int>{
          'helpful': (rawReactions['helpful'] as num?)?.toInt() ?? 0,
          'clear': (rawReactions['clear'] as num?)?.toInt() ?? 0,
          'insightful': (rawReactions['insightful'] as num?)?.toInt() ?? 0,
        };
        if (previous.isNotEmpty) {
          nextReactions[previous] =
              ((nextReactions[previous] ?? 0) - 1).clamp(0, 999999);
        }
        if (next.isNotEmpty) {
          nextReactions[next] = (nextReactions[next] ?? 0) + 1;
        }
        tx.set(messageRef, {'reactions': nextReactions},
            SetOptions(merge: true));
        if (next.isEmpty) {
          if (reactionSnap.exists) tx.delete(reactionRef);
        } else {
          tx.set(reactionRef, {'key': next, 'updatedAt': now},
              SetOptions(merge: true));
        }
      });
    } catch (e) {
      _snack('Réaction impossible : $e');
    }
  }

  Future<void> _reportMessage(_ForumMessage message) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour signaler un message.');
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Signaler ce message',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 18),
            ),
            const SizedBox(height: 10),
            for (final option in const <MapEntry<String, String>>[
              MapEntry('spam', 'Spam ou hors sujet'),
              MapEntry('abuse', 'Contenu agressif'),
              MapEntry('misleading', 'Contenu trompeur'),
            ])
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: detailsColor2),
                title: Text(option.value,
                    style: const TextStyle(
                        color: textColor, fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(context).pop(option.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await FirebaseFirestore.instance.collection('forum_reports').add({
        'messageId': message.id,
        'messageUid': message.uid,
        'reportedByUid': user.uid,
        'reason': reason,
        'themeId': message.themeId,
        'themeName': message.themeName,
        'createdAt': Timestamp.now(),
      });
      _snack('Signalement envoyé.');
    } catch (e) {
      _snack('Signalement impossible : $e');
    }
  }

  Future<void> _deleteMessage(_ForumMessage message) async {
    final user = _user;
    if (user == null) return;
    final isOwner = user.uid == message.uid;
    if (!isOwner && !_canModerate) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Supprimer le message ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .doc(message.id)
          .delete();
      if (mounted) _snack('Message supprimé.');
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
  }

  Future<void> _togglePinned(_ForumMessage message) async {
    final user = _user;
    if (user == null || !_canModerate) {
      _snack('Action réservée aux modérateurs.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .doc(message.id)
          .set({'isPinned': !message.isPinned}, SetOptions(merge: true));
      _snack(message.isPinned ? 'Message désépinglé.' : 'Message épinglé.');
    } catch (e) {
      _snack('Modération impossible : $e');
    }
  }

  // ── Filtres / tri ────────────────────────────────────────────────────────

  List<_ForumMessage> _applyFilters(
    List<_ForumMessage> messages,
    Set<String> bookmarkedIds,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    return messages.where((m) {
      if (_bookmarksOnly && !bookmarkedIds.contains(m.id)) return false;
      if (_activeTagFilter != null && !m.tags.contains(_activeTagFilter)) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = <String>[
        m.text,
        m.authorName,
        m.themeName,
        m.postTypeLabel,
        ...m.tags,
        for (final a in m.attachments) ...[a.symbol, a.displayName],
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<_ForumMessage> _sortFil(List<_ForumMessage> messages) {
    return [...messages]..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (_sortByTop && a.score != b.score) return b.score.compareTo(a.score);
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
  }

  List<_ForumMessage> _sortHot(List<_ForumMessage> messages) {
    return [...messages]..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return _hotScore(b).compareTo(_hotScore(a));
      });
  }

  // ── Builders de liste ────────────────────────────────────────────────────

  Widget _buildMessageList(
    List<_ForumMessage> messages,
    Set<String> bookmarkedIds,
  ) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Aucun message ne correspond à ce filtre.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SwipeToReplyWrapper(
            messageId: message.id,
            onSwipeRight: () => setState(
              () => _expandedMessageId =
                  _expandedMessageId == message.id ? null : message.id,
            ),
            child: _ForumMessageCard(
              message: message,
              canModerate: _canModerate,
              canDelete: _user != null && (_user.uid == message.uid || _canModerate),
              canReport: _user != null && _user.uid != message.uid,
              isBookmarked: bookmarkedIds.contains(message.id),
              isExpanded: _expandedMessageId == message.id,
              isFollowingTheme: _followedThemeIds.contains(message.themeId),
              isForceExpandedNegative:
                  _forceExpandedNegative.contains(message.id),
              onForceExpandNegative: () => setState(
                () => _forceExpandedNegative.add(message.id),
              ),
              onToggleExpanded: () => setState(
                () => _expandedMessageId =
                    _expandedMessageId == message.id ? null : message.id,
              ),
              onBookmark: () => _toggleBookmark(message),
              onVoteUp: () => _voteMessage(message: message, value: 1),
              onVoteDown: () => _voteMessage(message: message, value: -1),
              onReact: (key) =>
                  _reactToMessage(message: message, reactionKey: key),
              onReport: () => _reportMessage(message),
              onTogglePinned: () => _togglePinned(message),
              onFollowTheme: () =>
                  _toggleFollowTheme(message.themeId, message.themeName),
              onDelete: () => _deleteMessage(message),
              replies: _expandedMessageId == message.id
                  ? _ForumRepliesSection(
                      message: message,
                      currentUser: _user,
                      onSendReply: (text) => _sendReply(message, text),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoadingMore ? null : _loadMore,
          icon: _isLoadingMore
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: detailsColor2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(_isLoadingMore
              ? 'Chargement...'
              : 'Charger 30 posts supplémentaires'),
          style: OutlinedButton.styleFrom(
            foregroundColor: detailsColor2,
            side: BorderSide(color: detailsColor2.withValues(alpha: 0.22)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildSuiviTab(
      List<_ForumMessage> allMessages, Set<String> bookmarkedIds,
      {required bool hasMore}) {
    if (_user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Connecte-toi pour suivre des thèmes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }
    if (_followedThemeIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.explore_outlined,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun thème suivi',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: textColor),
              ),
              const SizedBox(height: 8),
              const Text(
                'Appuie sur ⋮ sur n\'importe quel post du fil, puis "Suivre ce thème" pour personaliser ce fil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    final filtered = _sortFil(_applyFilters(
      allMessages.where((m) => _followedThemeIds.contains(m.themeId)).toList(),
      bookmarkedIds,
    ));
    return Column(
      children: [
        Expanded(child: _buildMessageList(filtered, bookmarkedIds)),
        if (hasMore) _buildLoadMoreButton(),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          surfaceTintColor: backgroundColor,
          elevation: 0,
          title: const Text(
            'Forum boursier',
            style:
                TextStyle(color: textColor, fontWeight: FontWeight.w900),
          ),
          actions: [
            if (_user != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_rounded,
                          color: textColor),
                      onPressed: _openNotificationsSheet,
                    ),
                    if (_unreadNotifCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _unreadNotifCount > 9
                                  ? '9+'
                                  : '$_unreadNotifCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: const _ForumTabStrip(),
            ),
          ),
        ),
        floatingActionButton: _AnimatedComposerFab(
          ctrl: _fabCtrl,
          onTap: _openComposer,
        ),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissKeyboard,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookmarksStream(),
              builder: (context, bookmarkSnapshot) {
                final bookmarkedIds =
                    (bookmarkSnapshot.data?.docs ?? const [])
                        .map((doc) => doc.id)
                        .toSet();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesQuery().snapshots(),
                  builder: (context, snapshot) {
                    final allMessages = snapshot.hasData
                        ? snapshot.data!.docs
                            .map(_ForumMessage.fromDoc)
                            .toList()
                        : <_ForumMessage>[];
                    final hasMore = allMessages.length >= _queryLimit;
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData;

                    return Column(
                      children: [
                        // ── Zone repliable : bannière + recherche + filtres ──
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _filtersCollapsed
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 3.7 — Bannière concours hebdo
                                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: FirebaseFirestore.instance
                                          .collection('forum_weekly_winner')
                                          .doc('current')
                                          .snapshots(),
                                      builder: (context, winnerSnap) {
                                        final data = winnerSnap.data?.data();
                                        if (data == null) return const SizedBox.shrink();
                                        final weekOf = data['weekOf'] as Timestamp?;
                                        if (weekOf == null) return const SizedBox.shrink();
                                        final age = DateTime.now()
                                            .difference(weekOf.toDate())
                                            .inDays;
                                        if (age > 7) return const SizedBox.shrink();
                                        return _WeeklyWinnerBanner(data: data);
                                      },
                                    ),
                                    // Barre de recherche
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                      child: _ForumSearchBar(
                                        controller: _searchController,
                                        bookmarksOnly: _bookmarksOnly,
                                        sortByTop: _sortByTop,
                                        activeTagFilter: _activeTagFilter,
                                        onChanged: (v) =>
                                            setState(() => _searchQuery = v.trim()),
                                        onToggleBookmarks: () => setState(
                                            () => _bookmarksOnly = !_bookmarksOnly),
                                        onToggleSort: () =>
                                            setState(() => _sortByTop = !_sortByTop),
                                        onClearTagFilter: () =>
                                            setState(() => _activeTagFilter = null),
                                      ),
                                    ),
                                    // Filtres tags
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _forumTagOptions.map((tag) {
                                            final selected = _activeTagFilter == tag;
                                            return FilterChip(
                                              label: Text(tag),
                                              selected: selected,
                                              onSelected: (_) => setState(
                                                () => _activeTagFilter =
                                                    selected ? null : tag,
                                              ),
                                              selectedColor:
                                                  detailsColor1.withValues(alpha: 0.16),
                                              backgroundColor: Colors.white,
                                              labelStyle: TextStyle(
                                                color: selected ? detailsColor2 : textColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              side: BorderSide(
                                                color: selected
                                                    ? detailsColor2.withValues(alpha: 0.18)
                                                    : const Color(0xFFE6E8EB),
                                              ),
                                              showCheckmark: false,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                        ),
                        // ── Bouton toggle repli ──
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(
                              () => _filtersCollapsed = !_filtersCollapsed),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFE6E8EB),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Center(
                              child: AnimatedRotation(
                                turns: _filtersCollapsed ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                child: const Icon(
                                  Icons.expand_less_rounded,
                                  size: 20,
                                  color: Colors.black38,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ── Contenu par onglet ──
                        if (isLoading)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: detailsColor1),
                            ),
                          )
                        else if (snapshot.hasError)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Impossible de charger le forum.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: textColor),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: TabBarView(
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                // ── Onglet Fil ──
                                Column(
                                  children: [
                                    Expanded(
                                      child: _buildMessageList(
                                        _sortFil(_applyFilters(
                                            allMessages, bookmarkedIds)),
                                        bookmarkedIds,
                                      ),
                                    ),
                                    if (hasMore) _buildLoadMoreButton(),
                                  ],
                                ),
                                // ── Onglet Suivi ──
                                _buildSuiviTab(allMessages, bookmarkedIds,
                                    hasMore: hasMore),
                                // ── Onglet Top 🔥 ──
                                Column(
                                  children: [
                                    Expanded(
                                      child: _buildMessageList(
                                        _sortHot(_applyFilters(
                                            allMessages, bookmarkedIds)),
                                        bookmarkedIds,
                                      ),
                                    ),
                                    if (hasMore) _buildLoadMoreButton(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Modèles de données ───────────────────────────────────────────────────────

class _ForumThemeLite {
  const _ForumThemeLite({required this.id, required this.name});

  final String id;
  final String name;

  factory _ForumThemeLite.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _ForumThemeLite(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Sans nom',
    );
  }
}

class _ForumTickerAttachment {
  const _ForumTickerAttachment({
    required this.symbol,
    required this.displayName,
    required this.exchange,
    required this.currency,
    required this.quoteType,
  });

  final String symbol;
  final String displayName;
  final String exchange;
  final String currency;
  final String quoteType;

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'displayName': displayName,
        'exchange': exchange,
        'currency': currency,
        'quoteType': quoteType,
      };

  factory _ForumTickerAttachment.fromMap(Map<String, dynamic> data) =>
      _ForumTickerAttachment(
        symbol: (data['symbol'] as String?) ?? '',
        displayName: (data['displayName'] as String?) ?? '',
        exchange: (data['exchange'] as String?) ?? '',
        currency: (data['currency'] as String?) ?? '',
        quoteType: (data['quoteType'] as String?) ?? '',
      );

  factory _ForumTickerAttachment.fromSearchResult(TickerSearchResult result) =>
      _ForumTickerAttachment(
        symbol: result.symbol,
        displayName: result.displayName,
        exchange: result.exchange,
        currency: result.currency,
        quoteType: result.quoteType,
      );
}

class _ForumMessage {
  const _ForumMessage({
    required this.id,
    required this.text,
    required this.uid,
    required this.authorName,
    required this.themeId,
    required this.themeName,
    required this.score,
    required this.upVotes,
    required this.downVotes,
    required this.reactions,
    required this.isPinned,
    required this.postType,
    required this.tags,
    required this.attachments,
    this.chartAnnotationPng,
    this.pitchTitle,
    this.pitchThesis,
    this.pitchCatalysts,
    this.pitchRisks,
    this.portfolioSnapshot,
    // 3.3 — karma snapshot de l'auteur au moment de la publication
    this.authorKarma = 0,
    // 5.2 — badge Vérifié Investisseur
    this.isVerifiedAuthor = false,
    this.authorAvatarId,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String uid;
  final String authorName;
  final String themeId;
  final String themeName;
  final int score;
  final int upVotes;
  final int downVotes;
  final Map<String, int> reactions;
  final bool isPinned;
  final String postType;
  final List<String> tags;
  // 2.2 — multi-ticker (backward compat : `attachment` ancien → liste à 1 élément)
  final List<_ForumTickerAttachment> attachments;
  // 2.1 — annotation exportée en base64 PNG
  final String? chartAnnotationPng;
  // 2.4 — pitch structuré
  final String? pitchTitle;
  final String? pitchThesis;
  final String? pitchCatalysts;
  final String? pitchRisks;
  // 2.5 — snapshot portefeuille
  final Map<String, dynamic>? portfolioSnapshot;
  // 3.3 — karma snapshot de l'auteur
  final int authorKarma;
  // 5.2 — badge Vérifié Investisseur
  final bool isVerifiedAuthor;
  final String? authorAvatarId;
  final Timestamp? createdAt;

  String get postTypeLabel {
    switch (postType) {
      case 'question':
        return 'Question';
      case 'analyse':
        return 'Analyse';
      case 'alerte':
        return 'Alerte';
      case 'pitch':
        return 'Pitch';
      case 'discussion':
      default:
        return 'Discussion';
    }
  }

  factory _ForumMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawReactions = data['reactions'];

    // Backward compat: `attachments` (liste, nouveau) ou `attachment` (map, ancien)
    List<_ForumTickerAttachment> attachments;
    if (data['attachments'] is List) {
      attachments = (data['attachments'] as List)
          .whereType<Map<String, dynamic>>()
          .map(_ForumTickerAttachment.fromMap)
          .toList();
    } else if (data['attachment'] is Map<String, dynamic>) {
      attachments = [
        _ForumTickerAttachment.fromMap(
            data['attachment'] as Map<String, dynamic>)
      ];
    } else {
      attachments = const <_ForumTickerAttachment>[];
    }

    return _ForumMessage(
      id: doc.id,
      text: (data['text'] as String?) ?? '',
      uid: (data['uid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Utilisateur',
      themeId: (data['themeId'] as String?) ?? '',
      themeName: (data['themeName'] as String?) ?? 'Thème',
      score: (data['score'] as num?)?.toInt() ?? 0,
      upVotes: (data['upVotes'] as num?)?.toInt() ?? 0,
      downVotes: (data['downVotes'] as num?)?.toInt() ?? 0,
      reactions: rawReactions is Map<String, dynamic>
          ? rawReactions.map(
              (key, value) =>
                  MapEntry(key, value is num ? value.toInt() : 0),
            )
          : const <String, int>{},
      isPinned: data['isPinned'] as bool? ?? false,
      postType: (data['postType'] as String?) ?? 'discussion',
      tags: (data['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((v) => v.toString())
          .where((v) => v.isNotEmpty)
          .toList(),
      attachments: attachments,
      chartAnnotationPng: data['chartAnnotationPng'] as String?,
      pitchTitle: data['pitchTitle'] as String?,
      pitchThesis: data['pitchThesis'] as String?,
      pitchCatalysts: data['pitchCatalysts'] as String?,
      pitchRisks: data['pitchRisks'] as String?,
      portfolioSnapshot: data['portfolioSnapshot'] as Map<String, dynamic>?,
      authorKarma: (data['authorKarma'] as num?)?.toInt() ?? 0,
      isVerifiedAuthor: data['isVerifiedAuthor'] as bool? ?? false,
      authorAvatarId: data['authorAvatarId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

// ─── Composer (Bottom Sheet) ──────────────────────────────────────────────────

class _ComposerBottomSheet extends StatefulWidget {
  const _ComposerBottomSheet({
    required this.user,
    required this.themesQuery,
  });

  final User? user;
  final Query<Map<String, dynamic>> themesQuery;

  @override
  State<_ComposerBottomSheet> createState() => _ComposerBottomSheetState();
}

class _ComposerBottomSheetState extends State<_ComposerBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // 2.4 — pitch
  final TextEditingController _pitchTitleCtrl = TextEditingController();
  final TextEditingController _pitchThesisCtrl = TextEditingController();
  final TextEditingController _pitchCatalystsCtrl = TextEditingController();
  final TextEditingController _pitchRisksCtrl = TextEditingController();

  _ForumThemeLite? _selectedTheme;
  String _selectedPostType = _forumPostTypes.first;
  final Set<String> _selectedTags = <String>{};
  // 2.2 — multi-ticker (max 3)
  final List<_ForumTickerAttachment> _attachedTickers =
      <_ForumTickerAttachment>[];
  // 2.1 — annotation exportée
  String? _chartAnnotationPng;
  // 2.3 — suggestions du portefeuille
  Future<List<_ForumTickerAttachment>>? _holdingsFuture;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _holdingsFuture = _loadPortfolioHoldings();
    }
    // 4.2 — restaurer le brouillon
    SharedPreferences.getInstance().then((prefs) {
      final draft = prefs.getString('forum_draft') ?? '';
      if (draft.isNotEmpty && mounted) {
        _textController.text = draft;
        _textController.selection = TextSelection.collapsed(
          offset: draft.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _pitchTitleCtrl.dispose();
    _pitchThesisCtrl.dispose();
    _pitchCatalystsCtrl.dispose();
    _pitchRisksCtrl.dispose();
    super.dispose();
  }

  Future<List<_ForumTickerAttachment>> _loadPortfolioHoldings() async {
    final user = widget.user;
    if (user == null) return const [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('games')
          .doc('portofolio')
          .collection('positions')
          .get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return _ForumTickerAttachment(
          symbol: (d['symbol'] as String?) ?? doc.id,
          displayName: (d['displayName'] as String?) ?? doc.id,
          exchange: (d['exchange'] as String?) ?? '',
          currency: (d['currency'] as String?) ?? '',
          quoteType: (d['quoteType'] as String?) ?? '',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createThemeDialog() async {
    final user = widget.user;
    if (user == null) {
      _snack('Connecte-toi pour créer un thème.');
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Nouveau thème',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          maxLength: 40,
          autofocus: true,
          style: const TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Ex: ETF Europe, Macro, Débutants',
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.45)),
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Créer')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ref = await FirebaseFirestore.instance
        .collection('forum_themes')
        .add({
      'name': name,
      'createdAt': Timestamp.now(),
      'createdByUid': widget.user!.uid,
    });
    if (!mounted) return;
    setState(() => _selectedTheme = _ForumThemeLite(id: ref.id, name: name));
    _snack('Thème "$name" créé.');
  }

  Future<void> _pickTickerAttachment() async {
    if (_attachedTickers.length >= 3) {
      _snack('Maximum 3 tickers par post.');
      return;
    }
    final result = await showCupertinoModalBottomSheet<_ForumTickerAttachment>(
      context: context,
      expand: true,
      builder: (_) => const _TickerAttachmentSearchSheet(),
    );
    if (result == null || !mounted) return;
    if (_attachedTickers.any((t) => t.symbol == result.symbol)) {
      _snack('${result.symbol} est déjà attaché.');
      return;
    }
    setState(() => _attachedTickers.add(result));
  }

  Future<void> _openAnnotationEditor() async {
    if (_attachedTickers.isEmpty) return;
    final png = await showCupertinoModalBottomSheet<String>(
      context: context,
      expand: true,
      builder: (_) => _ChartAnnotationEditor(
        attachment: _attachedTickers.first,
      ),
    );
    if (png == null || !mounted) return;
    setState(() => _chartAnnotationPng = png);
    _snack('Annotation enregistrée.');
  }

  Future<void> _sendMessage() async {
    debugPrint('[Forum] _sendMessage called');
    final user = widget.user;
    if (user == null) {
      debugPrint('[Forum] blocked: no user');
      _snack('Connecte-toi pour publier.');
      return;
    }
    if (_selectedTheme == null) {
      debugPrint('[Forum] blocked: no theme');
      _snack('Choisis un thème.');
      return;
    }
    final text = _textController.text.trim();
    if (_sending) {
      debugPrint('[Forum] blocked: already sending');
      return;
    }
    // Autorise la publication sans texte si une annotation ou un ticker est joint
    final hasContent = text.isNotEmpty ||
        _chartAnnotationPng != null ||
        _attachedTickers.isNotEmpty;
    debugPrint('[Forum] hasContent=$hasContent postType=$_selectedPostType text="$text" annotation=${_chartAnnotationPng != null} tickers=${_attachedTickers.length}');
    if (_selectedPostType != 'pitch' && !hasContent) {
      debugPrint('[Forum] blocked: no content');
      _snack('Écris quelque chose ou joins un graphique annoté.');
      return;
    }
    if (_selectedPostType == 'pitch' &&
        _pitchTitleCtrl.text.trim().isEmpty) {
      debugPrint('[Forum] blocked: pitch missing title');
      _snack('Un titre est obligatoire pour un Pitch.');
      return;
    }
    if (_selectedPostType == 'pitch' &&
        _attachedTickers.isEmpty) {
      debugPrint('[Forum] blocked: pitch missing ticker');
      _snack('Attache au moins un ticker pour un Pitch.');
      return;
    }

    setState(() => _sending = true);
    debugPrint('[Forum] sending=true, starting Firestore write...');
    try {
      // 5.3 — anti-spam : max 5 posts / 24h (nécessite un index composite uid+createdAt)
      try {
        final yesterday = Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 24)));
        final recentSnap = await FirebaseFirestore.instance
            .collection('forum_chat_messages')
            .where('uid', isEqualTo: user.uid)
            .where('createdAt', isGreaterThan: yesterday)
            .limit(6)
            .get();
        debugPrint('[Forum] spam check: ${recentSnap.docs.length} posts in last 24h');
        if (recentSnap.docs.length >= 5) {
          _snack('Limite de 5 posts par 24h atteinte. Réessaie demain !');
          if (mounted) setState(() => _sending = false);
          return;
        }
      } catch (e) {
        // Index manquant ou erreur réseau → on ignore et on laisse publier
        debugPrint('[Forum] spam check skipped: $e');
      }

      // 3.3 + 5.2 — lecture du profil une seule fois
      int authorKarma = 0;
      bool isVerifiedAuthor = false;
      String authorName = _authorName(user);
      String? authorAvatarId;
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final d = userSnap.data() ?? {};
        authorKarma = (d['karma'] as num?)?.toInt() ?? 0;
        final level = (d['level'] as num?)?.toInt() ?? 0;
        final achievements =
            (d['achievements_claimed'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
        isVerifiedAuthor =
            level >= 10 || achievements.contains('investor_50k');
        final firestoreName = (d['Name'] as String?)?.trim() ?? '';
        if (firestoreName.isNotEmpty) authorName = firestoreName;
        authorAvatarId = d['avatar_id'] as String?;
      } catch (_) {}

      final now = Timestamp.now();
      final doc = <String, dynamic>{
        'text': text,
        'uid': user.uid,
        'authorName': authorName,
        'authorAvatarId': authorAvatarId,
        'photoURL': user.photoURL,
        'authorKarma': authorKarma,
        'isVerifiedAuthor': isVerifiedAuthor,
        'themeId': _selectedTheme!.id,
        'themeName': _selectedTheme!.name,
        'upVotes': 0,
        'downVotes': 0,
        'score': 0,
        'createdAt': now,
        'lastVoteAt': now,
        'reactions': <String, int>{'helpful': 0, 'clear': 0, 'insightful': 0},
        'isPinned': false,
        'postType': _selectedPostType,
        'tags': _selectedTags.toList(),
        'attachments': _attachedTickers.map((t) => t.toMap()).toList(),
      };
      if (_chartAnnotationPng != null) {
        doc['chartAnnotationPng'] = _chartAnnotationPng!;
      }
      if (_selectedPostType == 'pitch') {
        doc['pitchTitle'] = _pitchTitleCtrl.text.trim();
        doc['pitchThesis'] = _pitchThesisCtrl.text.trim();
        doc['pitchCatalysts'] = _pitchCatalystsCtrl.text.trim();
        doc['pitchRisks'] = _pitchRisksCtrl.text.trim();
      }
      debugPrint('[Forum] doc ready, writing to Firestore: ${doc.keys.toList()}');
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .add(doc);
      debugPrint('[Forum] Firestore write SUCCESS');
      // 4.2 — effacer le brouillon sauvegardé
      unawaited(SharedPreferences.getInstance()
          .then((p) => p.remove('forum_draft')));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('[Forum] ERROR publishing: $e\n$st');
      _snack('Impossible de publier : $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // ── En-tête ──
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [detailsColor1, detailsColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouveau post',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Partage ton analyse, ta question ou ton alerte.',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Sélection thème ──
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: widget.themesQuery.snapshots(),
                      builder: (context, snapshot) {
                        final themes = (snapshot.data?.docs ?? [])
                            .map(_ForumThemeLite.fromDoc)
                            .toList();
                        _ForumThemeLite? resolved = _selectedTheme;
                        final resolvedId = resolved?.id;
                        if (resolvedId != null) {
                          for (final t in themes) {
                            if (t.id == resolvedId) {
                              resolved = t;
                              break;
                            }
                          }
                        }
                        return _WhiteInputBox(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<_ForumThemeLite>(
                              value: resolved,
                              isExpanded: true,
                              hint: const Text('Choisir un thème'),
                              items: themes
                                  .map(
                                    (t) => DropdownMenuItem<_ForumThemeLite>(
                                      value: t,
                                      child: Text(t.name,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (t) =>
                                  setState(() => _selectedTheme = t),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SquareActionButton(
                    icon: Icons.add_rounded,
                    onTap: _createThemeDialog,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Type de post ──
              _WhiteInputBox(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPostType,
                    isExpanded: true,
                    items: _forumPostTypes
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(_postTypeLabel(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedPostType = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Tags ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _forumTagOptions.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      if (_selectedTags.contains(tag)) {
                        _selectedTags.remove(tag);
                      } else if (_selectedTags.length < 4) {
                        _selectedTags.add(tag);
                      }
                    }),
                    selectedColor: detailsColor1.withValues(alpha: 0.16),
                    backgroundColor: const Color(0xFFF7F8FA),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected ? detailsColor2 : textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected
                          ? detailsColor2.withValues(alpha: 0.18)
                          : const Color(0xFFE6E8EB),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // ── 2.4 — champs pitch ──
              if (_selectedPostType == 'pitch') ...[
                _WhiteInputBox(
                  child: TextField(
                    controller: _pitchTitleCtrl,
                    enabled: user != null && !_sending,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Titre du pitch (ex: Long LVMH)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _WhiteInputBox(
                  child: TextField(
                    controller: _pitchThesisCtrl,
                    enabled: user != null && !_sending,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Thèse (pourquoi cette conviction ?)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _WhiteInputBox(
                  child: TextField(
                    controller: _pitchCatalystsCtrl,
                    enabled: user != null && !_sending,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Catalyseurs (résultats, BCE, macro...)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _WhiteInputBox(
                  child: TextField(
                    controller: _pitchRisksCtrl,
                    enabled: user != null && !_sending,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Risques (macro, devise, liquidité...)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // ── 2.3 — suggestions portefeuille ──
              if (user != null)
                FutureBuilder<List<_ForumTickerAttachment>>(
                  future: _holdingsFuture,
                  builder: (context, snap) {
                    final holdings = snap.data ?? const [];
                    if (holdings.isEmpty) return const SizedBox.shrink();
                    final alreadyAttached =
                        _attachedTickers.map((t) => t.symbol).toSet();
                    final available = holdings
                        .where((h) => !alreadyAttached.contains(h.symbol))
                        .toList();
                    if (available.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mes positions',
                          style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: available.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final h = available[i];
                              return ActionChip(
                                label: Text(h.symbol),
                                avatar: const Icon(Icons.add_rounded,
                                    size: 14),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                    color: detailsColor2
                                        .withValues(alpha: 0.18)),
                                labelStyle: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700),
                                onPressed: _attachedTickers.length >= 3
                                    ? null
                                    : () {
                                        if (_attachedTickers.any((t) =>
                                            t.symbol == h.symbol)) {
                                          return;
                                        }
                                        setState(
                                            () => _attachedTickers.add(h));
                                      },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
              // ── 2.2 — multi-ticker ──
              Row(
                children: [
                  if (_attachedTickers.length < 3)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTickerAttachment,
                        icon: const Icon(Icons.show_chart_rounded),
                        label: Text(_attachedTickers.isEmpty
                            ? 'Attacher un ticker'
                            : 'Ajouter un ticker (${_attachedTickers.length}/3)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: detailsColor2,
                          side: BorderSide(
                              color: detailsColor2.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  if (_attachedTickers.isNotEmpty &&
                      _selectedPostType != 'pitch') ...[
                    const SizedBox(width: 10),
                    _SquareActionButton(
                      icon: Icons.draw_rounded,
                      onTap: _openAnnotationEditor,
                    ),
                  ],
                ],
              ),
              if (_attachedTickers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  children: _attachedTickers.map((t) {
                    final idx = _attachedTickers.indexOf(t);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ForumTickerAttachmentPreview(
                        attachment: t,
                        compact: true,
                        onRemove: () =>
                            setState(() => _attachedTickers.removeAt(idx)),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (_chartAnnotationPng != null) ...[
                const SizedBox(height: 8),
                _AnnotationImagePreview(
                  base64Png: _chartAnnotationPng!,
                  onRemove: () =>
                      setState(() => _chartAnnotationPng = null),
                ),
              ],
              const SizedBox(height: 12),
              // ── Texte ──
              _WhiteInputBox(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: user != null && !_sending,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  minLines: 3,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  // 4.2 — auto-save brouillon
                  onChanged: (v) => SharedPreferences.getInstance()
                      .then((p) => p.setString('forum_draft', v)),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: user == null
                        ? 'Connecte-toi pour publier'
                        : 'Analyse, question, idée de trade, contexte marché...',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Envoyer ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: user == null || _sending ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Publication...' : 'Publier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Barre de recherche ───────────────────────────────────────────────────────

class _ForumSearchBar extends StatelessWidget {
  const _ForumSearchBar({
    required this.controller,
    required this.bookmarksOnly,
    required this.sortByTop,
    required this.activeTagFilter,
    required this.onChanged,
    required this.onToggleBookmarks,
    required this.onToggleSort,
    required this.onClearTagFilter,
  });

  final TextEditingController controller;
  final bool bookmarksOnly;
  final bool sortByTop;
  final String? activeTagFilter;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleBookmarks;
  final VoidCallback onToggleSort;
  final VoidCallback onClearTagFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6E8EB)),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Rechercher un message, un tag ou un ticker...',
                icon: Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircleToggleButton(
          active: bookmarksOnly,
          icon: Icons.bookmark_rounded,
          tooltip: 'Favoris',
          onTap: onToggleBookmarks,
        ),
        const SizedBox(width: 8),
        _CircleToggleButton(
          active: sortByTop,
          icon: Icons.local_fire_department_rounded,
          tooltip: 'Tri top / récent',
          onTap: onToggleSort,
        ),
        if (activeTagFilter != null) ...[
          const SizedBox(width: 8),
          _CircleToggleButton(
            active: true,
            icon: Icons.close_rounded,
            tooltip: 'Retirer le filtre tag',
            onTap: onClearTagFilter,
          ),
        ],
      ],
    );
  }
}

// ─── Carte de message ─────────────────────────────────────────────────────────

class _ForumMessageCard extends StatelessWidget {
  const _ForumMessageCard({
    required this.message,
    required this.canModerate,
    required this.canReport,
    required this.canDelete,
    required this.isBookmarked,
    required this.isExpanded,
    required this.isFollowingTheme,
    // 5.1 — collapse posts négatifs
    required this.isForceExpandedNegative,
    required this.onForceExpandNegative,
    required this.onToggleExpanded,
    required this.onBookmark,
    required this.onVoteUp,
    required this.onVoteDown,
    required this.onReact,
    required this.onReport,
    required this.onTogglePinned,
    required this.onFollowTheme,
    required this.onDelete,
    required this.replies,
  });

  final _ForumMessage message;
  final bool canModerate;
  final bool canReport;
  final bool canDelete;
  final bool isBookmarked;
  final bool isExpanded;
  final bool isFollowingTheme;
  final bool isForceExpandedNegative;
  final VoidCallback onForceExpandNegative;
  final VoidCallback onToggleExpanded;
  final VoidCallback onBookmark;
  final VoidCallback onVoteUp;
  final VoidCallback onVoteDown;
  final ValueChanged<String> onReact;
  final VoidCallback onReport;
  final VoidCallback onTogglePinned;
  final VoidCallback onFollowTheme;
  final VoidCallback onDelete;
  final Widget? replies;

  // 5.1 — le post doit-il être replié ?
  bool get _isCollapsed =>
      message.score < -3 && !isForceExpandedNegative;

  @override
  Widget build(BuildContext context) {
    // 5.1 — vue repliée
    if (_isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6E8EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_rounded,
                size: 16, color: Colors.black38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Post masqué (score ${message.score}) — ',
                style: const TextStyle(
                    color: Colors.black45, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: onForceExpandNegative,
              child: const Text(
                'Afficher quand même',
                style: TextStyle(
                  color: detailsColor2,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3.2 — avatar tappable → profil auteur
              GestureDetector(
                onTap: () => showCupertinoModalBottomSheet<void>(
                  context: context,
                  expand: false,
                  builder: (_) => _AuthorProfileSheet(
                    authorUid: message.uid,
                    authorName: message.authorName,
                  ),
                ),
                child: _ForumAvatar(
                  avatarId: message.authorAvatarId,
                  name: message.authorName,
                  size: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            message.authorName,
                            style: const TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        // 5.2 — badge vérifié
                        if (message.isVerifiedAuthor) ...[
                          const SizedBox(width: 4),
                          const _VerifiedBadge(),
                        ],
                        // 3.3 — badge karma
                        if (message.authorKarma > 0) ...[
                          const SizedBox(width: 6),
                          _KarmaBadge(karma: message.authorKarma),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (message.isPinned)
                          const _PostBadge(label: 'Épinglé'),
                        _PostBadge(label: message.postTypeLabel),
                        _PostBadge(
                            label: message.themeName, alternate: true),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onBookmark,
                    tooltip: 'Enregistrer',
                    icon: Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isBookmarked ? detailsColor2 : Colors.black45,
                    ),
                  ),
                  // Menu actions — toujours visible (follow theme + modération)
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    color: Colors.white,
                    onSelected: (value) {
                      if (value == 'pin') onTogglePinned();
                      if (value == 'report') onReport();
                      if (value == 'follow') onFollowTheme();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) {
                      final items = <PopupMenuEntry<String>>[];
                      if (canDelete) {
                        items.add(PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Supprimer',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ));
                      }
                      if (canModerate) {
                        if (items.isNotEmpty) items.add(const PopupMenuDivider());
                        items.add(PopupMenuItem<String>(
                          value: 'pin',
                          child: Text(
                              message.isPinned ? 'Désépingler' : 'Épingler'),
                        ));
                      }
                      if (canReport) {
                        if (items.isNotEmpty) {
                          items.add(const PopupMenuDivider());
                        }
                        items.add(const PopupMenuItem<String>(
                          value: 'report',
                          child: Text('Signaler'),
                        ));
                      }
                      if (items.isNotEmpty) {
                        items.add(const PopupMenuDivider());
                      }
                      items.add(PopupMenuItem<String>(
                        value: 'follow',
                        child: Row(
                          children: [
                            Icon(
                              isFollowingTheme
                                  ? Icons.bookmark_remove_outlined
                                  : Icons.bookmark_add_outlined,
                              color: detailsColor2,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isFollowingTheme
                                    ? 'Ne plus suivre "${message.themeName}"'
                                    : 'Suivre "${message.themeName}"',
                              ),
                            ),
                          ],
                        ),
                      ));
                      return items;
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(message.text,
              style: const TextStyle(color: textColor, height: 1.45)),
          if (message.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: detailsColor1.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          // 2.2 — multi-ticker side-by-side
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MultiTickerRow(attachments: message.attachments),
          ],
          // 2.1 — annotation exportée
          if (message.chartAnnotationPng != null) ...[
            const SizedBox(height: 12),
            _AnnotationImagePreview(base64Png: message.chartAnnotationPng!),
          ],
          // 2.4 — pitch structuré
          if (message.postType == 'pitch') ...[
            const SizedBox(height: 12),
            _PitchCard(message: message),
          ],
          // 2.5 — snapshot portefeuille
          if (message.portfolioSnapshot != null) ...[
            const SizedBox(height: 12),
            _PortfolioSnapshotCard(snapshot: message.portfolioSnapshot!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ForumReactionChip(
                icon: Icons.thumb_up_alt_rounded,
                label: 'Utile',
                count: message.reactions['helpful'] ?? 0,
                onTap: () => onReact('helpful'),
              ),
              _ForumReactionChip(
                icon: Icons.lightbulb_rounded,
                label: 'Clair',
                count: message.reactions['clear'] ?? 0,
                onTap: () => onReact('clear'),
              ),
              _ForumReactionChip(
                icon: Icons.insights_rounded,
                label: 'Analyse',
                count: message.reactions['insightful'] ?? 0,
                onTap: () => onReact('insightful'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniActionButton(
                icon: Icons.arrow_upward_rounded,
                label: '${message.upVotes}',
                onTap: onVoteUp,
              ),
              const SizedBox(width: 8),
              _MiniActionButton(
                icon: Icons.arrow_downward_rounded,
                label: '${message.downVotes}',
                onTap: onVoteDown,
              ),
              const SizedBox(width: 8),
              _MiniActionButton(
                icon: Icons.forum_rounded,
                label: isExpanded ? 'Masquer' : 'Répondre',
                onTap: onToggleExpanded,
              ),
              const Spacer(),
              Text(
                'Score ${message.score}',
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (replies != null) ...[const SizedBox(height: 14), replies!],
        ],
      ),
    );
  }
}

// ─── Section réponses (3.4 votes + 3.5 mentions) ─────────────────────────────

class _ForumRepliesSection extends StatefulWidget {
  const _ForumRepliesSection({
    required this.message,
    required this.currentUser,
    required this.onSendReply,
  });

  final _ForumMessage message;
  final User? currentUser;
  final Future<void> Function(String text) onSendReply;

  @override
  State<_ForumRepliesSection> createState() => _ForumRepliesSectionState();
}

class _ForumRepliesSectionState extends State<_ForumRepliesSection> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  // 3.5 — mentions
  bool _showMentions = false;
  List<String> _mentionCandidates = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 3.4 — vote sur une réponse
  Future<void> _voteReply(
      String replyId, int value, Map<String, dynamic> replyData) async {
    final user = widget.currentUser;
    if (user == null) return;
    final replyUid = (replyData['uid'] as String?) ?? '';
    if (replyUid == user.uid) return;
    final replyRef = FirebaseFirestore.instance
        .collection('forum_chat_messages')
        .doc(widget.message.id)
        .collection('replies')
        .doc(replyId);
    final voteRef = replyRef.collection('votes').doc(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final now = Timestamp.now();
        final voteSnap = await tx.get(voteRef);
        final previous =
            voteSnap.exists ? ((voteSnap.data()?['value'] as int?) ?? 0) : 0;
        final next = previous == value ? 0 : value;
        var deltaUp = 0;
        var deltaDown = 0;
        var deltaScore = 0;
        if (previous == 1) {
          deltaUp -= 1;
          deltaScore -= 1;
        } else if (previous == -1) {
          deltaDown -= 1;
          deltaScore += 1;
        }
        if (next == 1) {
          deltaUp += 1;
          deltaScore += 1;
        } else if (next == -1) {
          deltaDown += 1;
          deltaScore -= 1;
        }
        tx.set(
          replyRef,
          {
            'upVotes': FieldValue.increment(deltaUp),
            'downVotes': FieldValue.increment(deltaDown),
            'score': FieldValue.increment(deltaScore),
            'lastVoteAt': now,
          },
          SetOptions(merge: true),
        );
        if (next == 0) {
          if (voteSnap.exists) tx.delete(voteRef);
        } else {
          tx.set(voteRef, {'value': next, 'updatedAt': now});
        }
      });
    } catch (_) {}
  }

  // 3.5 — détection @mention et insertion
  void _onTextChanged(String text, List<String> participants) {
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx < 0) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final word = beforeCursor.substring(atIdx + 1);
    if (word.contains(' ')) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final query = word.toLowerCase();
    final filtered = participants
        .where((p) => p.toLowerCase().startsWith(query))
        .toList();
    setState(() {
      _showMentions = filtered.isNotEmpty;
      _mentionCandidates = filtered;
    });
  }

  void _insertMention(String name) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset.clamp(0, text.length);
    final beforeCursor = text.substring(0, cursor);
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx < 0) return;
    final after = text.substring(cursor);
    final newText = '${text.substring(0, atIdx)}@$name $after';
    _controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: atIdx + name.length + 2),
    );
    setState(() => _showMentions = false);
  }

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
          const Text('Réponses',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('forum_chat_messages')
                .doc(widget.message.id)
                .collection('replies')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              // 3.4 — tri client-side par score desc
              final sorted = [...docs]..sort((a, b) {
                  final sa =
                      (a.data()['score'] as num?)?.toInt() ?? 0;
                  final sb =
                      (b.data()['score'] as num?)?.toInt() ?? 0;
                  return sb.compareTo(sa);
                });

              // 3.5 — participants (pour @mentions)
              final participants = <String>{widget.message.authorName};
              for (final doc in docs) {
                final name =
                    (doc.data()['authorName'] as String?) ?? '';
                if (name.isNotEmpty) participants.add(name);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sorted.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Aucune réponse pour le moment.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  else
                    for (final doc in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReplyBubble(
                          replyId: doc.id,
                          data: doc.data(),
                          currentUid:
                              widget.currentUser?.uid,
                          onVoteUp: () => _voteReply(
                              doc.id, 1, doc.data()),
                          onVoteDown: () => _voteReply(
                              doc.id, -1, doc.data()),
                        ),
                      ),
                  // 3.5 — suggestions @mention
                  if (_showMentions && _mentionCandidates.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mentionCandidates.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, i) => ActionChip(
                          label: Text('@${_mentionCandidates[i]}'),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color:
                                  detailsColor2.withValues(alpha: 0.2)),
                          labelStyle: const TextStyle(
                              color: detailsColor2,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                          onPressed: () => _insertMention(
                              _mentionCandidates[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _WhiteInputBox(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.currentUser != null && !_sending,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (v) => _onTextChanged(
                          v, participants.toList()),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Répondre… (@pseudo pour mentionner)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: widget.currentUser == null || _sending
                          ? null
                          : () async {
                              final text =
                                  _controller.text.trim();
                              if (text.isEmpty) return;
                              setState(() => _sending = true);
                              await widget.onSendReply(text);
                              if (!mounted) return;
                              _controller.clear();
                              setState(() {
                                _sending = false;
                                _showMentions = false;
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.reply_rounded),
                      label: const Text('Répondre'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Recherche de ticker ──────────────────────────────────────────────────────

class _TickerAttachmentSearchSheet extends StatefulWidget {
  const _TickerAttachmentSearchSheet();

  @override
  State<_TickerAttachmentSearchSheet> createState() =>
      _TickerAttachmentSearchSheetState();
}

class _TickerAttachmentSearchSheetState
    extends State<_TickerAttachmentSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<TickerSearchResult> _results = const <TickerSearchResult>[];
  Timer? _debounce;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = const <TickerSearchResult>[];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await YahooFinanceService.searchSecurities(trimmed,
          quotesCount: 20);
      if (!mounted) return;
      setState(() {
        _results = results
            .where((item) => item.isSearchDisplayableInstrument)
            .take(12)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <TickerSearchResult>[];
        _loading = false;
      });
    }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6E8EB)),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 260),
                      () => _search(value),
                    );
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Rechercher un ticker, ETF ou fonds...',
                    icon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: detailsColor1))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).pop(
                            _ForumTickerAttachment.fromSearchResult(item),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: const Color(0xFFE6E8EB)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [detailsColor1, detailsColor2],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(
                                      Icons.show_chart_rounded,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.symbol,
                                          style: const TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text(item.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                _PostBadge(
                                    label: item.instrumentLabel,
                                    alternate: true),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aperçu ticker ────────────────────────────────────────────────────────────

class _ForumTickerAttachmentPreview extends StatelessWidget {
  const _ForumTickerAttachmentPreview({
    required this.attachment,
    this.compact = false,
    this.onRemove,
  });

  final _ForumTickerAttachment attachment;
  final bool compact;
  final VoidCallback? onRemove;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attachment.symbol,
                        style: const TextStyle(
                            color: textColor, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(attachment.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TickerMetaPill(
                label: attachment.quoteType.trim().isEmpty
                    ? 'Actif'
                    : attachment.quoteType,
              ),
              if (onRemove != null)
                IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TickerMetaPill(
                label: attachment.exchange.trim().isEmpty
                    ? 'Marché inconnu'
                    : attachment.exchange,
              ),
              _TickerMetaPill(
                label: attachment.currency.trim().isEmpty
                    ? 'Devise -'
                    : attachment.currency,
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            _MiniTickerChart(attachment: attachment),
          ],
        ],
      ),
    );
  }
}

// ─── Mini graphique ───────────────────────────────────────────────────────────

class _MiniTickerChart extends StatefulWidget {
  const _MiniTickerChart({required this.attachment});

  final _ForumTickerAttachment attachment;

  @override
  State<_MiniTickerChart> createState() => _MiniTickerChartState();
}

class _MiniTickerChartState extends State<_MiniTickerChart> {
  late final Future<_MiniTickerSnapshot?> _future;

  @override
  void initState() {
    super.initState();
    _future = _MiniTickerSnapshot.load(widget.attachment);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MiniTickerSnapshot?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 132,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
                strokeWidth: 2, color: detailsColor1),
          );
        }
        final payload = snapshot.data;
        if (payload == null) {
          return Container(
            height: 132,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Données de marché indisponibles pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }
        final chartPainter = _MiniChartPainter(
          points: payload.points.map((p) => p.close).toList(),
          color: payload.positive
              ? const Color(0xFF177A53)
              : const Color(0xFF9A2D2D),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            // En mode compact (hauteur ≤ 80px), on affiche seulement la courbe
            final compact = constraints.maxHeight <= 80;
            if (compact) {
              return payload.points.length < 2
                  ? const SizedBox.shrink()
                  : SizedBox.expand(child: CustomPaint(painter: chartPainter));
            }
            return Container(
              height: 132,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(payload.priceLabel,
                                style: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(payload.changeLabel,
                                style: TextStyle(
                                    color: payload.positive
                                        ? const Color(0xFF177A53)
                                        : const Color(0xFF9A2D2D),
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      _TickerMetaPill(label: payload.marketLabel),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: payload.points.length < 2
                        ? const Center(
                            child: Text('Mini-courbe indisponible',
                                style: TextStyle(color: Colors.black54)))
                        : SizedBox.expand(
                            child: CustomPaint(painter: chartPainter),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  const _MiniChartPainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minValue = points.reduce((a, b) => a < b ? a : b);
    final maxValue = points.reduce((a, b) => a > b ? a : b);
    final delta =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final normalized = (points[i] - minValue) / delta;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fillPath, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class _TickerMetaPill extends StatelessWidget {
  const _TickerMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: detailsColor2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(
              color: detailsColor2,
              fontWeight: FontWeight.w800,
              fontSize: 11.5)),
    );
  }
}

class _MiniTickerSnapshot {
  const _MiniTickerSnapshot({
    required this.points,
    required this.priceLabel,
    required this.changeLabel,
    required this.marketLabel,
    required this.positive,
  });

  final List<HistoricalPoint> points;
  final String priceLabel;
  final String changeLabel;
  final String marketLabel;
  final bool positive;

  static Future<_MiniTickerSnapshot?> load(
      _ForumTickerAttachment attachment) async {
    QuoteDetail? quote;
    List<HistoricalPoint> points = const <HistoricalPoint>[];
    try {
      quote = await YahooFinanceService.fetchQuote(attachment.symbol);
    } catch (_) {
      quote = null;
    }
    try {
      points = await YahooFinanceService.fetchHistoricalSeries(
          attachment.symbol, ChartInterval.sevenDays);
    } catch (_) {
      points = const <HistoricalPoint>[];
    }
    final marketPrice = quote?.regularMarketPrice;
    final change = quote?.regularMarketChange;
    final changePercent = quote?.regularMarketChangePercent;
    final positive = points.length >= 2
        ? points.last.close >= points.first.close
        : (change ?? 0) >= 0;
    if (marketPrice == null && points.isEmpty) return null;
    final priceLabel = marketPrice == null
        ? attachment.currency.trim().isEmpty
            ? 'Cours indisponible'
            : 'Cours en ${attachment.currency}'
        : '${marketPrice.toStringAsFixed(marketPrice >= 100 ? 2 : 3)} ${attachment.currency.trim().isEmpty ? '' : attachment.currency}'
            .trim();
    final changeLabel = change == null
        ? 'Variation en direct indisponible'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}${changePercent == null ? '' : ' · ${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%'}';
    final marketLabel =
        (quote?.fullExchangeName ?? quote?.exchange ?? attachment.exchange)
                    .trim()
                    .isEmpty
            ? 'Marché'
            : (quote?.fullExchangeName ?? quote?.exchange ?? attachment.exchange)
                .trim();
    return _MiniTickerSnapshot(
      points: points,
      priceLabel: priceLabel,
      changeLabel: changeLabel,
      marketLabel: marketLabel,
      positive: positive,
    );
  }
}

// ─── Petits widgets utilitaires ───────────────────────────────────────────────

// 3.4 + 3.5 — bulle réponse avec votes et highlight @mentions
class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({
    required this.replyId,
    required this.data,
    required this.currentUid,
    required this.onVoteUp,
    required this.onVoteDown,
  });

  final String replyId;
  final Map<String, dynamic> data;
  final String? currentUid;
  final VoidCallback onVoteUp;
  final VoidCallback onVoteDown;

  @override
  Widget build(BuildContext context) {
    final authorName = (data['authorName'] as String?) ?? 'Utilisateur';
    final avatarId = data['authorAvatarId'] as String?;
    final text = (data['text'] as String?) ?? '';
    final upVotes = (data['upVotes'] as num?)?.toInt() ?? 0;
    final downVotes = (data['downVotes'] as num?)?.toInt() ?? 0;
    final replyUid = (data['uid'] as String?) ?? '';
    final isOwn = currentUid != null && currentUid == replyUid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ForumAvatar(avatarId: avatarId, name: authorName, size: 28),
              const SizedBox(width: 8),
              Text(authorName,
                  style: const TextStyle(
                      color: textColor, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          // 3.5 — highlight @mentions
          _MentionText(text: text),
          const SizedBox(height: 8),
          // 3.4 — boutons de vote sur la réponse
          if (!isOwn)
            Row(
              children: [
                _MiniActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: '$upVotes',
                  onTap: onVoteUp,
                ),
                const SizedBox(width: 6),
                _MiniActionButton(
                  icon: Icons.arrow_downward_rounded,
                  label: '$downVotes',
                  onTap: onVoteDown,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WhiteInputBox extends StatelessWidget {
  const _WhiteInputBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: child,
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  const _SquareActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _CircleToggleButton extends StatelessWidget {
  const _CircleToggleButton({
    required this.active,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                active ? detailsColor2.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? detailsColor2.withValues(alpha: 0.22)
                  : const Color(0xFFE6E8EB),
            ),
          ),
          child: Icon(icon, color: active ? detailsColor2 : textColor),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6E8EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: detailsColor2),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ForumReactionChip extends StatelessWidget {
  const _ForumReactionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count réaction(s)',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6E8EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: detailsColor2),
              const SizedBox(width: 6),
              Text('$label · $count',
                  style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostBadge extends StatelessWidget {
  const _PostBadge({required this.label, this.alternate = false});

  final String label;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: alternate
            ? detailsColor2.withValues(alpha: 0.08)
            : detailsColor1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: alternate ? detailsColor2 : textColor,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

// ─── Nouveaux widgets ─────────────────────────────────────────────────────────

/// TabBar identique au design de _GameHubTabStrip — 3 onglets : Fil · Suivi · Top
class _ForumTabStrip extends StatelessWidget {
  const _ForumTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w900, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13.5),
        tabs: const [
          Tab(text: 'Fil'),
          Tab(text: 'Suivi'),
          Tab(text: 'Top 🔥'),
        ],
      ),
    );
  }
}

/// FAB animé (flottement sinusoïdal) avec icône stylo SVG
class _AnimatedComposerFab extends StatelessWidget {
  const _AnimatedComposerFab({
    required this.ctrl,
    required this.onTap,
  });

  final AnimationController ctrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, child) {
          final dx = math.sin(ctrl.value * math.pi * 2) * 4.0;
          final dy = math.cos(ctrl.value * math.pi * 2) * 6.0;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: detailsColor2.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: SvgPicture.string(_composerFabSvg),
          ),
        ),
      ),
    );
  }
}

/// Swipe-to-reply : glisse vers la droite pour ouvrir les réponses
class _SwipeToReplyWrapper extends StatelessWidget {
  const _SwipeToReplyWrapper({
    required this.messageId,
    required this.child,
    required this.onSwipeRight,
  });

  final String messageId;
  final Widget child;
  final VoidCallback onSwipeRight;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('swipe_$messageId'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipeRight();
        return false; // ne pas supprimer — juste déclencher la réponse
      },
      background: Container(
        decoration: BoxDecoration(
          color: detailsColor1.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 18),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.reply_rounded, color: Colors.white, size: 20),
        ),
      ),
      child: child,
    );
  }
}

// ─── 3.3 — Karma badge ───────────────────────────────────────────────────────

class _KarmaBadge extends StatelessWidget {
  const _KarmaBadge({required this.karma});

  final int karma;

  static _KarmaLevel _level(int k) {
    if (k >= 500) return _KarmaLevel.maitre;
    if (k >= 200) return _KarmaLevel.expert;
    if (k >= 50) return _KarmaLevel.actif;
    return _KarmaLevel.novice;
  }

  @override
  Widget build(BuildContext context) {
    final lvl = _level(karma);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: lvl.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${lvl.emoji} $karma',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: lvl.fg,
        ),
      ),
    );
  }
}

enum _KarmaLevel {
  novice(emoji: '🌱', bg: Color(0xFFECF7EE), fg: Color(0xFF2D7A3A)),
  actif(emoji: '⚡', bg: Color(0xFFE8F0FE), fg: Color(0xFF1A56DB)),
  expert(emoji: '🔥', bg: Color(0xFFFEF3E2), fg: Color(0xFFB45309)),
  maitre(emoji: '👑', bg: Color(0xFFFFF4CC), fg: Color(0xFF92650A));

  const _KarmaLevel({
    required this.emoji,
    required this.bg,
    required this.fg,
  });
  final String emoji;
  final Color bg;
  final Color fg;
}

// ─── 3.5 — Highlight @mentions ───────────────────────────────────────────────

class _MentionText extends StatelessWidget {
  const _MentionText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Découpe le texte autour des @mentions
    final spans = <TextSpan>[];
    final regex = RegExp(r'@(\w+)');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: const TextStyle(color: textColor, height: 1.35),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: detailsColor2,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(color: textColor, height: 1.35),
      ));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

// ─── 3.2 — Profil auteur ─────────────────────────────────────────────────────

class _AuthorProfileSheet extends StatelessWidget {
  const _AuthorProfileSheet({
    required this.authorUid,
    required this.authorName,
  });

  final String authorUid;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: FutureBuilder<_AuthorStats>(
          future: _AuthorStats.load(authorUid),
          builder: (context, snap) {
            final stats = snap.data;
            final loading = snap.connectionState == ConnectionState.waiting;
            return Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),
                // Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [detailsColor1, detailsColor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      _initials(authorName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  authorName,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (stats != null && stats.karma > 0) ...[
                  const SizedBox(height: 6),
                  _KarmaBadge(karma: stats.karma),
                ],
                const SizedBox(height: 16),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: detailsColor1),
                  )
                else if (stats != null) ...[
                  // Stats chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ProfileStatChip(
                          label: 'Posts',
                          value: '${stats.postCount}',
                        ),
                        const SizedBox(width: 12),
                        _ProfileStatChip(
                          label: 'Karma',
                          value: '${stats.karma}',
                        ),
                        const SizedBox(width: 12),
                        _ProfileStatChip(
                          label: 'Niveau',
                          value: '${stats.level}',
                        ),
                      ],
                    ),
                  ),
                  if (stats.topPost != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Meilleur post',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE6E8EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _PostBadge(
                                        label: stats.topPost!['themeName']
                                                as String? ??
                                            'Thème',
                                        alternate: true),
                                    const Spacer(),
                                    Icon(Icons.arrow_upward_rounded,
                                        size: 14,
                                        color: detailsColor2
                                            .withValues(alpha: 0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(stats.topPost!['score'] as num?)?.toInt() ?? 0}',
                                      style: const TextStyle(
                                        color: detailsColor2,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (stats.topPost!['text'] as String?) ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: textColor, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthorStats {
  const _AuthorStats({
    required this.karma,
    required this.level,
    required this.postCount,
    this.topPost,
  });

  final int karma;
  final int level;
  final int postCount;
  final Map<String, dynamic>? topPost;

  static Future<_AuthorStats> load(String uid) async {
    int karma = 0;
    int level = 0;
    int postCount = 0;
    Map<String, dynamic>? topPost;

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      karma = (userSnap.data()?['karma'] as num?)?.toInt() ?? 0;
      level = (userSnap.data()?['level'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final postsSnap = await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .where('uid', isEqualTo: uid)
          .orderBy('score', descending: true)
          .limit(50)
          .get();
      postCount = postsSnap.docs.length;
      if (postsSnap.docs.isNotEmpty) {
        topPost = postsSnap.docs.first.data();
      }
    } catch (_) {}

    return _AuthorStats(
      karma: karma,
      level: level,
      postCount: postCount,
      topPost: topPost,
    );
  }
}

class _ProfileStatChip extends StatelessWidget {
  const _ProfileStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
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

// ─── 3.7 — Bannière concours hebdomadaire ────────────────────────────────────

class _WeeklyWinnerBanner extends StatelessWidget {
  const _WeeklyWinnerBanner({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final authorName = (data['authorName'] as String?) ?? 'Auteur';
    final text = (data['text'] as String?) ?? '';
    final score = (data['score'] as num?)?.toInt() ?? 0;
    final themeName = (data['themeName'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFF9E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D8A0)),
        boxShadow: [
          BoxShadow(
            color: detailsColor1.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: detailsColor2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meilleure analyse de la semaine',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (themeName.isNotEmpty)
                      _PostBadge(label: themeName, alternate: true),
                    const SizedBox(width: 6),
                    _PostBadge(label: '▲ $score'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fonctions utilitaires top-level ─────────────────────────────────────────

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) return '?';
  if (list.length == 1) return list.first.characters.first.toUpperCase();
  return (list.first.characters.first + list.last.characters.first)
      .toUpperCase();
}

String _postTypeLabel(String type) {
  switch (type) {
    case 'question':
      return 'Question';
    case 'analyse':
      return 'Analyse';
    case 'alerte':
      return 'Alerte marché';
    case 'pitch':
      return '🎯 Pitch structuré';
    case 'discussion':
    default:
      return 'Discussion';
  }
}

// ─── 2.2 — Multi-ticker row ───────────────────────────────────────────────────

class _MultiTickerRow extends StatelessWidget {
  const _MultiTickerRow({required this.attachments});

  final List<_ForumTickerAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.length == 1) {
      return _ForumTickerAttachmentPreview(attachment: attachments.first);
    }
    return Row(
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _CompactTickerCard(attachment: attachments[i]),
          ),
        ],
      ],
    );
  }
}

class _CompactTickerCard extends StatelessWidget {
  const _CompactTickerCard({required this.attachment});

  final _ForumTickerAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attachment.symbol,
            style: const TextStyle(
                color: textColor, fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            attachment.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: _MiniTickerChart(attachment: attachment),
          ),
        ],
      ),
    );
  }
}

// ─── 2.1 — Aperçu annotation PNG ─────────────────────────────────────────────

class _AnnotationImagePreview extends StatelessWidget {
  const _AnnotationImagePreview({
    required this.base64Png,
    this.onRemove,
  });

  final String base64Png;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    late final Uint8List bytes;
    try {
      bytes = base64Decode(base64Png);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── 2.4 — Pitch card ────────────────────────────────────────────────────────

class _PitchCard extends StatelessWidget {
  const _PitchCard({required this.message});

  final _ForumMessage message;

  @override
  Widget build(BuildContext context) {
    final hasTicker = message.attachments.isNotEmpty;
    final ticker = hasTicker ? message.attachments.first.symbol : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            detailsColor2.withValues(alpha: 0.06),
            detailsColor1.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: detailsColor2.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: detailsColor2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '🎯 Pitch',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5),
                ),
              ),
              if (ticker != null) ...[
                const SizedBox(width: 8),
                _TickerMetaPill(label: ticker),
              ],
            ],
          ),
          if ((message.pitchTitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message.pitchTitle!,
              style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15),
            ),
          ],
          if ((message.pitchThesis ?? '').isNotEmpty)
            _PitchSection(
                icon: Icons.lightbulb_rounded,
                label: 'Thèse',
                text: message.pitchThesis!),
          if ((message.pitchCatalysts ?? '').isNotEmpty)
            _PitchSection(
                icon: Icons.rocket_launch_rounded,
                label: 'Catalyseurs',
                text: message.pitchCatalysts!),
          if ((message.pitchRisks ?? '').isNotEmpty)
            _PitchSection(
                icon: Icons.warning_amber_rounded,
                label: 'Risques',
                text: message.pitchRisks!),
        ],
      ),
    );
  }
}

class _PitchSection extends StatelessWidget {
  const _PitchSection({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: detailsColor2),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                    color: detailsColor2,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(color: textColor, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── 2.5 — Portfolio snapshot card ───────────────────────────────────────────

class _PortfolioSnapshotCard extends StatelessWidget {
  const _PortfolioSnapshotCard({required this.snapshot});

  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final pnlPct = (snapshot['totalPnlPct'] as num?)?.toDouble() ?? 0;
    final level = (snapshot['level'] as num?)?.toInt() ?? 0;
    final positions = (snapshot['positions'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];
    final pnlPositive = pnlPct >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D8A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: detailsColor2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '📊 Snapshot portefeuille',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pnlPositive
                      ? const Color(0xFFE8F5EC)
                      : const Color(0xFFFFEFEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pnlPositive ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: pnlPositive
                        ? const Color(0xFF13804A)
                        : const Color(0xFFB4533B),
                  ),
                ),
              ),
            ],
          ),
          if (positions.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final pos in positions) ...[
              _SnapshotPositionRow(position: pos),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 4),
          Text(
            'Niveau $level · Performance globale',
            style: const TextStyle(
                color: Colors.black54,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SnapshotPositionRow extends StatelessWidget {
  const _SnapshotPositionRow({required this.position});

  final Map<String, dynamic> position;

  @override
  Widget build(BuildContext context) {
    final symbol = (position['symbol'] as String?) ?? '?';
    final weightPct = (position['weightPct'] as num?)?.toDouble() ?? 0;
    final pnlPct = (position['pnlPct'] as num?)?.toDouble() ?? 0;
    final pnlPositive = pnlPct >= 0;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            symbol,
            style: const TextStyle(
                color: textColor, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (weightPct / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                detailsColor2.withValues(alpha: 0.5),
              ),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${weightPct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(
            '${pnlPositive ? '+' : ''}${pnlPct.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: pnlPositive
                  ? const Color(0xFF13804A)
                  : const Color(0xFFB4533B),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 2.1 — Éditeur d'annotations ─────────────────────────────────────────────

enum _AnnotationTool { pen, hLine, upArrow, downArrow }

class _AnnotationStroke {
  _AnnotationStroke({required this.tool, required this.color});

  final _AnnotationTool tool;
  final Color color;
  final List<Offset> points = [];
}

class _ChartAnnotationEditor extends StatefulWidget {
  const _ChartAnnotationEditor({required this.attachment});

  final _ForumTickerAttachment attachment;

  @override
  State<_ChartAnnotationEditor> createState() =>
      _ChartAnnotationEditorState();
}

class _ChartAnnotationEditorState extends State<_ChartAnnotationEditor> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_AnnotationStroke> _strokes = [];
  _AnnotationTool _tool = _AnnotationTool.pen;
  Color _color = detailsColor2;
  bool _exporting = false;

  // Zoom / pan state
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _baseFocalPoint = Offset.zero;

  static const _tools = [
    (_AnnotationTool.pen, Icons.draw_rounded, 'Libre'),
    (_AnnotationTool.hLine, Icons.horizontal_rule_rounded, 'Support/Rés.'),
    (_AnnotationTool.upArrow, Icons.arrow_upward_rounded, 'Haussier'),
    (_AnnotationTool.downArrow, Icons.arrow_downward_rounded, 'Baissier'),
  ];

  static const _colors = [
    detailsColor2,
    Color(0xFF13804A),
    Color(0xFFB4533B),
    Color(0xFF1565C0),
  ];

  /// Convertit une position écran (espace GestureDetector) → espace canvas.
  Offset _toCanvas(Offset screen) => (screen - _offset) / _scale;

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount >= 2) {
      // Mode navigation (zoom/pan)
      _baseFocalPoint = d.localFocalPoint;
      _baseScale = _scale;
      _baseOffset = _offset;
    } else {
      // Mode dessin (1 doigt)
      final stroke = _AnnotationStroke(tool: _tool, color: _color);
      stroke.points.add(_toCanvas(d.localFocalPoint));
      setState(() => _strokes.add(stroke));
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      setState(() {
        _scale = (_baseScale * d.scale).clamp(1.0, 6.0);
        _offset = _baseOffset + (d.localFocalPoint - _baseFocalPoint);
      });
    } else {
      if (_strokes.isEmpty) return;
      setState(() => _strokes.last.points.add(_toCanvas(d.localFocalPoint)));
    }
  }

  void _resetView() => setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });

  Future<void> _export() async {
    debugPrint('[Forum] _export called');
    setState(() => _exporting = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      debugPrint('[Forum] boundary=$boundary repaintKey=${_repaintKey.currentContext}');
      if (boundary == null) {
        debugPrint('[Forum] ERROR: boundary is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de capturer le graphique. Réessaie.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) {
        debugPrint('[Forum] ERROR: byteData=$byteData mounted=$mounted');
        return;
      }
      final base64Str = base64Encode(byteData.buffer.asUint8List());
      debugPrint('[Forum] export success, base64 length=${base64Str.length}');
      if (mounted) Navigator.of(context).pop(base64Str);
    } catch (e, st) {
      debugPrint('[Forum] export ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export impossible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
              padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Annoter le graphique',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_scale > 1.0)
                    IconButton(
                      onPressed: _resetView,
                      icon: const Icon(Icons.zoom_out_map_rounded, size: 20),
                      tooltip: 'Réinitialiser la vue',
                      color: Colors.black54,
                    ),
                  if (_strokes.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() => _strokes.clear()),
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      tooltip: 'Effacer les annotations',
                      color: Colors.black54,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRect(
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      child: Transform(
                        transform: Matrix4.translationValues(
                                _offset.dx, _offset.dy, 0)
                            ..scaleByDouble(_scale, _scale, 1, 1),
                        child: Stack(
                          children: [
                            _ForumTickerAttachmentPreview(
                                attachment: widget.attachment),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _AnnotationPainter(strokes: _strokes),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Palette outils
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final t in _tools)
                    _AnnotationToolButton(
                      icon: t.$2,
                      label: t.$3,
                      selected: _tool == t.$1,
                      onTap: () => setState(() => _tool = t.$1),
                    ),
                  for (final c in _colors)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: _color == c
                              ? Border.all(color: Colors.black, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _exporting ? null : _export,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_exporting
                      ? 'Export en cours...'
                      : 'Valider l\'annotation'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({required this.strokes});

  final List<_AnnotationStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final pts = stroke.points;
      if (pts.isEmpty) continue;

      switch (stroke.tool) {
        case _AnnotationTool.pen:
          if (pts.length < 2) break;
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (var i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
          canvas.drawPath(path, paint);
        case _AnnotationTool.hLine:
          final y = pts.last.dy;
          canvas.drawLine(
              Offset(0, y), Offset(size.width, y), paint..strokeWidth = 1.8);
        case _AnnotationTool.upArrow:
          final center = pts.last;
          _drawArrow(canvas, center, true, stroke.color);
        case _AnnotationTool.downArrow:
          final center = pts.last;
          _drawArrow(canvas, center, false, stroke.color);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset center, bool up, Color color) {
    final dir = up ? -1.0 : 1.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = color.withValues(alpha: 0.22);
    final tip = Offset(center.dx, center.dy - dir * 22);
    final left = Offset(center.dx - 12, center.dy + dir * 8);
    final right = Offset(center.dx + 12, center.dy + dir * 8);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(center.dx, center.dy + dir * 8),
      Offset(center.dx, center.dy + dir * 26),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class _AnnotationToolButton extends StatelessWidget {
  const _AnnotationToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? detailsColor2.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? detailsColor2.withValues(alpha: 0.30)
                : const Color(0xFFE6E8EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? detailsColor2 : textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? detailsColor2 : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 5.2 — Verified Investor Badge ──────────────────────────────────────────
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Investisseur Vérifié',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 11, color: Colors.white),
            SizedBox(width: 2),
            Text(
              'Vérifié',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 4.1 — Notifications Sheet ───────────────────────────────────────────────
class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.uid});
  final String uid;

  String _label(String type) {
    switch (type) {
      case 'reply':
        return 'a répondu à votre post';
      case 'mention':
        return 'vous a mentionné';
      case 'vote_milestone':
        return 'votre post a atteint un cap de votes';
      default:
        return 'nouvelle notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('forum_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded,
                      size: 20, color: detailsColor2),
                  SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 400,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: col.snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucune notification pour l\'instant.',
                          style:
                              TextStyle(color: Colors.black45, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final isRead = d['read'] as bool? ?? true;
                      final fromName =
                          d['fromName'] as String? ?? 'Quelqu\'un';
                      final type = d['type'] as String? ?? '';
                      final ts = d['createdAt'] as Timestamp?;
                      String ago = '';
                      if (ts != null) {
                        final diff =
                            DateTime.now().difference(ts.toDate());
                        if (diff.inDays >= 1) {
                          ago = 'il y a ${diff.inDays}j';
                        } else if (diff.inHours >= 1) {
                          ago = 'il y a ${diff.inHours}h';
                        } else {
                          ago = 'il y a ${diff.inMinutes}min';
                        }
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isRead
                              ? Colors.grey.shade200
                              : detailsColor2.withValues(alpha: 0.15),
                          child: Text(
                            fromName.isNotEmpty
                                ? fromName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  isRead ? Colors.black45 : detailsColor2,
                            ),
                          ),
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 13, color: textColor),
                            children: [
                              TextSpan(
                                text: fromName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: ' ${_label(type)}'),
                            ],
                          ),
                        ),
                        subtitle: ago.isNotEmpty
                            ? Text(
                                ago,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45),
                              )
                            : null,
                        trailing: isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: detailsColor2,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ── Avatar forum (image si dispo, sinon initiales) ──────────────────────────
class _ForumAvatar extends StatelessWidget {
  const _ForumAvatar({
    required this.avatarId,
    required this.name,
    required this.size,
  });

  final String? avatarId;
  final String name;
  final double size;

  static String? _assetPath(String id) {
    switch (id) {
      case '_easteregg':
        return 'assets/avatars/easteregg.png';
      case '_sydsteregg':
        return 'assets/avatars/sydsteregg.png';
      case '_quintprime':
        return 'assets/avatars/quint_prime.png';
      case '_beyondbig':
        return 'assets/avatars/beyond_big.png';
      case '_groseline':
        return 'assets/avatars/groseline.png';
      case '_gay':
        return 'assets/avatars/gay.png';
      case '_student':
        return 'assets/avatars/avatar_student.png';
      case '_expert':
        return 'assets/avatars/avatar_expert.png';
      case '_bling':
        return 'assets/avatars/avatar_bling.png';
      case '_strong':
        return 'assets/avatars/avatar_strong.png';
      case '_geek':
        return 'assets/avatars/avatar_geek.png';
      case '_skelet':
        return 'assets/avatars/avatar_skelet.png';
      case '_call':
        return 'assets/avatars/avatar_call.png';
      case '_happy':
        return 'assets/avatars/avatar_happy.png';
      case '_wealthy':
        return 'assets/avatars/avatar_wealthy.png';
      case '_rich':
        return 'assets/avatars/avatar_rich.png';
      case '_bandit':
        return 'assets/avatars/avatar_bandit.png';
      default:
        return 'assets/avatars/avatar$id.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final path = avatarId != null ? _assetPath(avatarId!) : null;

    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.33),
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(radius),
        ),
      );
    }
    return _fallback(radius);
  }

  Widget _fallback(double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.33),
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

String _authorName(User user) {
  final displayName = (user.displayName ?? '').trim();
  if (displayName.isNotEmpty) return displayName;
  final email = (user.email ?? '').trim();
  if (email.isNotEmpty) return email.split('@').first;
  return 'Utilisateur';
}
