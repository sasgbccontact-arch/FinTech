import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

const List<String> _convictionSides = <String>['long', 'short'];
const List<String> _convictionStatuses = <String>[
  'open',
  'monitoring',
  'hit_target',
  'invalidated',
  'closed',
];

const List<String> _convictionOutcomes = <String>[
  'pending',
  'win',
  'loss',
  'flat',
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
  late final TabController _tabController;

  // Feed state
  String _searchQuery = '';
  String? _activeTagFilter;
  String? _activeTickerFilter;
  String? _activeThemeFilterId;
  bool _bookmarksOnly = false;
  bool _canModerate = false;
  String? _expandedMessageId;
  String? _highlightedMessageId;
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
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
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
          setState(
            () => _followedThemeIds = snap.docs.map((d) => d.id).toSet(),
          );
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
      final snap =
          await FirebaseFirestore.instance
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
      builder:
          (_) => _NotificationsSheet(
            uid: _user!.uid,
            onOpenPost: (postId) {
              Navigator.of(context).pop();
              _focusPost(postId);
            },
          ),
    );
  }

  void _focusPost(String postId) {
    _searchController.clear();
    setState(() {
      _queryLimit = math.max(_queryLimit, 90);
      _searchQuery = '';
      _activeTagFilter = null;
      _activeTickerFilter = null;
      _activeThemeFilterId = null;
      _bookmarksOnly = false;
      _expandedMessageId = postId;
      _highlightedMessageId = postId;
    });
    _tabController.animateTo(0);
    unawaited(
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!mounted || _highlightedMessageId != postId) return;
        setState(() => _highlightedMessageId = null);
      }),
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
      builder:
          (_) => _ComposerBottomSheet(user: _user, themesQuery: _themesQuery()),
    );
  }

  // ── Hot score ────────────────────────────────────────────────────────────

  double _hotScore(_ForumMessage m) {
    final ageHours =
        m.createdAt != null
            ? DateTime.now()
                    .difference(m.createdAt!.toDate())
                    .inMinutes
                    .toDouble() /
                60.0
            : 0.0;
    return _messageQualityScore(m) / math.pow(ageHours + 2.0, 1.45);
  }

  // ── Firestore queries ────────────────────────────────────────────────────

  Future<void> _loadModeratorStatus() async {
    final user = _user;
    if (user == null) return;
    try {
      final snap =
          await FirebaseFirestore.instance
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
    return FirebaseFirestore.instance
        .collection('forum_chat_messages')
        .orderBy('createdAt', descending: true)
        .limit(_queryLimit);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        final snap =
            await FirebaseFirestore.instance
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
      unawaited(
        _writeNotification(
          targetUid: message.uid,
          type: 'reply',
          postId: message.id,
        ),
      );
      // 4.1 — notif mention → chaque @pseudo dans le texte
      final mentionRegex = RegExp(r'@(\w+)');
      for (final m in mentionRegex.allMatches(replyText)) {
        final mentionedName = m.group(1) ?? '';
        if (mentionedName.isEmpty) continue;
        // Cherche l'uid dans les réponses existantes (best-effort)
        try {
          final snap =
              await FirebaseFirestore.instance
                  .collection('forum_chat_messages')
                  .doc(message.id)
                  .collection('replies')
                  .where('authorName', isEqualTo: mentionedName)
                  .limit(1)
                  .get();
          if (snap.docs.isNotEmpty) {
            final targetUid = (snap.docs.first.data()['uid'] as String?) ?? '';
            if (targetUid.isNotEmpty) {
              unawaited(
                _writeNotification(
                  targetUid: targetUid,
                  type: 'mention',
                  postId: message.id,
                ),
              );
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
        final updatedSnap =
            await FirebaseFirestore.instance
                .collection('forum_chat_messages')
                .doc(message.id)
                .get();
        final newScore = (updatedSnap.data()?['score'] as num?)?.toInt() ?? 0;
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
          nextReactions[previous] = ((nextReactions[previous] ?? 0) - 1).clamp(
            0,
            999999,
          );
        }
        if (next.isNotEmpty) {
          nextReactions[next] = (nextReactions[next] ?? 0) + 1;
        }
        tx.set(messageRef, {
          'reactions': nextReactions,
        }, SetOptions(merge: true));
        if (next.isEmpty) {
          if (reactionSnap.exists) tx.delete(reactionRef);
        } else {
          tx.set(reactionRef, {
            'key': next,
            'updatedAt': now,
          }, SetOptions(merge: true));
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
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Signaler ce message',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in const <MapEntry<String, String>>[
                  MapEntry('spam', 'Spam ou hors sujet'),
                  MapEntry('abuse', 'Contenu agressif'),
                  MapEntry('misleading', 'Contenu trompeur'),
                ])
                  ListTile(
                    leading: const Icon(
                      Icons.flag_rounded,
                      color: detailsColor2,
                    ),
                    title: Text(
                      option.value,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
      builder:
          (ctx) => AlertDialog(
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

  void _selectTickerFeed(String ticker) {
    setState(() {
      _activeTickerFilter =
          _activeTickerFilter == ticker ? null : ticker.toUpperCase();
      _activeThemeFilterId = null;
    });
    _tabController.animateTo(0);
  }

  void _selectThemeFeed(_ForumThemeLite theme) {
    setState(() {
      _activeThemeFilterId = _activeThemeFilterId == theme.id ? null : theme.id;
      _activeTickerFilter = null;
    });
    _tabController.animateTo(0);
  }

  void _clearFeedFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _activeTagFilter = null;
      _activeTickerFilter = null;
      _activeThemeFilterId = null;
      _bookmarksOnly = false;
    });
  }

  Future<void> _openPitchLifecycleEditor(_ForumMessage message) async {
    if (_user == null ||
        _user.uid != message.uid ||
        message.postType != 'pitch') {
      return;
    }
    await showCupertinoModalBottomSheet<void>(
      context: context,
      expand: false,
      builder: (_) => _PitchLifecycleSheet(message: message),
    );
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
      if (_activeTickerFilter != null &&
          !m.attachments.any(
            (attachment) =>
                attachment.symbol.toUpperCase() == _activeTickerFilter,
          )) {
        return false;
      }
      if (_activeThemeFilterId != null && m.themeId != _activeThemeFilterId) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack =
          <String>[
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
      final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
  }

  List<_ForumMessage> _sortTop(List<_ForumMessage> messages) {
    return [...messages]..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final qualityCompare = _messageQualityScore(
        b,
      ).compareTo(_messageQualityScore(a));
      if (qualityCompare != 0) return qualityCompare;
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
            onSwipeRight:
                () => setState(
                  () =>
                      _expandedMessageId =
                          _expandedMessageId == message.id ? null : message.id,
                ),
            child: _ForumMessageCard(
              message: message,
              canModerate: _canModerate,
              canDelete:
                  _user != null && (_user.uid == message.uid || _canModerate),
              canReport: _user != null && _user.uid != message.uid,
              canManagePitch:
                  _user != null &&
                  _user.uid == message.uid &&
                  message.postType == 'pitch',
              isBookmarked: bookmarkedIds.contains(message.id),
              isExpanded: _expandedMessageId == message.id,
              isFollowingTheme: _followedThemeIds.contains(message.themeId),
              isHighlighted: _highlightedMessageId == message.id,
              isForceExpandedNegative: _forceExpandedNegative.contains(
                message.id,
              ),
              onForceExpandNegative:
                  () => setState(() => _forceExpandedNegative.add(message.id)),
              onToggleExpanded:
                  () => setState(
                    () =>
                        _expandedMessageId =
                            _expandedMessageId == message.id
                                ? null
                                : message.id,
                  ),
              onBookmark: () => _toggleBookmark(message),
              onVoteUp: () => _voteMessage(message: message, value: 1),
              onVoteDown: () => _voteMessage(message: message, value: -1),
              onReact:
                  (key) => _reactToMessage(message: message, reactionKey: key),
              onReport: () => _reportMessage(message),
              onTogglePinned: () => _togglePinned(message),
              onFollowTheme:
                  () => _toggleFollowTheme(message.themeId, message.themeName),
              onManagePitch: () => _openPitchLifecycleEditor(message),
              onOpenTickerFeed: _selectTickerFeed,
              onOpenThemeFeed:
                  () => _selectThemeFeed(
                    _ForumThemeLite(
                      id: message.themeId,
                      name: message.themeName,
                    ),
                  ),
              onDelete: () => _deleteMessage(message),
              replies:
                  _expandedMessageId == message.id
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
          icon:
              _isLoadingMore
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: detailsColor2,
                    ),
                  )
                  : const Icon(Icons.expand_more_rounded),
          label: Text(
            _isLoadingMore
                ? 'Chargement...'
                : 'Charger 30 posts supplémentaires',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: detailsColor2,
            side: BorderSide(color: detailsColor2.withValues(alpha: 0.22)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuiviTab(
    List<_ForumMessage> allMessages,
    Set<String> bookmarkedIds, {
    required bool hasMore,
  }) {
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
                child: const Icon(
                  Icons.explore_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun thème suivi',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: textColor,
                ),
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
    final filtered = _sortFil(
      _applyFilters(
        allMessages
            .where((m) => _followedThemeIds.contains(m.themeId))
            .toList(),
        bookmarkedIds,
      ),
    );
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
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Forum boursier',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_rounded,
                      color: textColor,
                    ),
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
                            _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
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
            child: _ForumTabStrip(controller: _tabController),
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
                  final allMessages =
                      snapshot.hasData
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
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _themesQuery().snapshots(),
                        builder: (context, themesSnapshot) {
                          final themes =
                              (themesSnapshot.data?.docs ?? const [])
                                  .map(_ForumThemeLite.fromDoc)
                                  .toList();
                          return _ForumFeedHeader(
                            controller: _searchController,
                            query: _searchQuery,
                            activeTagFilter: _activeTagFilter,
                            activeTickerFilter: _activeTickerFilter,
                            activeThemeFilterId: _activeThemeFilterId,
                            bookmarksOnly: _bookmarksOnly,
                            themes: themes,
                            messages: allMessages,
                            onChanged:
                                (value) =>
                                    setState(() => _searchQuery = value.trim()),
                            onToggleBookmarks:
                                () => setState(
                                  () => _bookmarksOnly = !_bookmarksOnly,
                                ),
                            onSelectTag:
                                (tag) => setState(
                                  () =>
                                      _activeTagFilter =
                                          _activeTagFilter == tag ? null : tag,
                                ),
                            onSelectTicker: _selectTickerFeed,
                            onSelectTheme: _selectThemeFeed,
                            onClearAll: _clearFeedFilters,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // ── Contenu par onglet ──
                      if (isLoading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: detailsColor1,
                            ),
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
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              // ── Onglet Fil ──
                              Column(
                                children: [
                                  Expanded(
                                    child: _buildMessageList(
                                      _sortFil(
                                        _applyFilters(
                                          allMessages,
                                          bookmarkedIds,
                                        ),
                                      ),
                                      bookmarkedIds,
                                    ),
                                  ),
                                  if (hasMore) _buildLoadMoreButton(),
                                ],
                              ),
                              // ── Onglet Suivi ──
                              _buildSuiviTab(
                                allMessages,
                                bookmarkedIds,
                                hasMore: hasMore,
                              ),
                              // ── Onglet Top 🔥 ──
                              Column(
                                children: [
                                  Expanded(
                                    child: _buildMessageList(
                                      _sortTop(
                                        _applyFilters(
                                          allMessages,
                                          bookmarkedIds,
                                        ),
                                      ),
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
    );
  }
}

// ─── Modèles de données ───────────────────────────────────────────────────────

class _ForumThemeLite {
  const _ForumThemeLite({
    required this.id,
    required this.name,
    this.description = '',
    this.relatedTickers = const <String>[],
    this.isCurated = false,
    this.iconKey = '',
  });

  final String id;
  final String name;
  final String description;
  final List<String> relatedTickers;
  final bool isCurated;
  final String iconKey;

  factory _ForumThemeLite.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _ForumThemeLite(
      id: doc.id,
      name:
          (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : 'Sans nom',
      description: (data['description'] as String?)?.trim() ?? '',
      relatedTickers:
          (data['relatedTickers'] as List<dynamic>? ?? const [])
              .map((value) => value.toString().toUpperCase())
              .where((value) => value.isNotEmpty)
              .toList(),
      isCurated: data['isCurated'] as bool? ?? false,
      iconKey: (data['iconKey'] as String?)?.trim() ?? '',
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
    this.authorQualityScore = 0,
    this.authorConvictionScore = 0,
    this.authorReputationScore = 0,
    // 5.2 — badge Vérifié Investisseur
    this.isVerifiedAuthor = false,
    this.convictionSide,
    this.convictionStatus,
    this.convictionOutcome,
    this.convictionHorizon,
    this.convictionEntryPrice,
    this.convictionTargetPrice,
    this.convictionInvalidationPrice,
    this.convictionReturnPct,
    this.convictionOpenedAt,
    this.convictionUpdatedAt,
    this.convictionClosedAt,
    this.convictionNote,
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
  final int authorQualityScore;
  final int authorConvictionScore;
  final int authorReputationScore;
  // 5.2 — badge Vérifié Investisseur
  final bool isVerifiedAuthor;
  final String? convictionSide;
  final String? convictionStatus;
  final String? convictionOutcome;
  final String? convictionHorizon;
  final double? convictionEntryPrice;
  final double? convictionTargetPrice;
  final double? convictionInvalidationPrice;
  final double? convictionReturnPct;
  final Timestamp? convictionOpenedAt;
  final Timestamp? convictionUpdatedAt;
  final Timestamp? convictionClosedAt;
  final String? convictionNote;
  final String? authorAvatarId;
  final Timestamp? createdAt;

  bool get hasStructuredPitch => postType == 'pitch';

  String? get primaryTicker =>
      attachments.isEmpty ? null : attachments.first.symbol.toUpperCase();

  String get convictionStatusLabel =>
      _convictionStatusLabel(convictionStatus ?? 'open');

  String get convictionOutcomeLabel =>
      _convictionOutcomeLabel(convictionOutcome ?? 'pending');

  String get convictionSideLabel =>
      _convictionSideLabel(convictionSide ?? 'long');

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
      attachments =
          (data['attachments'] as List)
              .whereType<Map<String, dynamic>>()
              .map(_ForumTickerAttachment.fromMap)
              .toList();
    } else if (data['attachment'] is Map<String, dynamic>) {
      attachments = [
        _ForumTickerAttachment.fromMap(
          data['attachment'] as Map<String, dynamic>,
        ),
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
      reactions:
          rawReactions is Map<String, dynamic>
              ? rawReactions.map(
                (key, value) => MapEntry(key, value is num ? value.toInt() : 0),
              )
              : const <String, int>{},
      isPinned: data['isPinned'] as bool? ?? false,
      postType: (data['postType'] as String?) ?? 'discussion',
      tags:
          (data['tags'] as List<dynamic>? ?? const <dynamic>[])
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
      authorQualityScore: (data['authorQualityScore'] as num?)?.toInt() ?? 0,
      authorConvictionScore:
          (data['authorConvictionScore'] as num?)?.toInt() ?? 0,
      authorReputationScore:
          (data['authorReputationScore'] as num?)?.toInt() ?? 0,
      isVerifiedAuthor: data['isVerifiedAuthor'] as bool? ?? false,
      convictionSide: data['convictionSide'] as String?,
      convictionStatus: data['convictionStatus'] as String?,
      convictionOutcome: data['convictionOutcome'] as String?,
      convictionHorizon: data['convictionHorizon'] as String?,
      convictionEntryPrice: (data['convictionEntryPrice'] as num?)?.toDouble(),
      convictionTargetPrice:
          (data['convictionTargetPrice'] as num?)?.toDouble(),
      convictionInvalidationPrice:
          (data['convictionInvalidationPrice'] as num?)?.toDouble(),
      convictionReturnPct: (data['convictionReturnPct'] as num?)?.toDouble(),
      convictionOpenedAt: data['convictionOpenedAt'] as Timestamp?,
      convictionUpdatedAt: data['convictionUpdatedAt'] as Timestamp?,
      convictionClosedAt: data['convictionClosedAt'] as Timestamp?,
      convictionNote: data['convictionNote'] as String?,
      authorAvatarId: data['authorAvatarId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

class _ReputationSnapshot {
  const _ReputationSnapshot({
    required this.qualityScore,
    required this.convictionScore,
    required this.reputationScore,
  });

  final int qualityScore;
  final int convictionScore;
  final int reputationScore;
}

String _convictionSideLabel(String side) {
  switch (side) {
    case 'short':
      return 'Short';
    case 'long':
    default:
      return 'Long';
  }
}

String _convictionStatusLabel(String status) {
  switch (status) {
    case 'monitoring':
      return 'Sous surveillance';
    case 'hit_target':
      return 'Objectif touché';
    case 'invalidated':
      return 'Invalidé';
    case 'closed':
      return 'Clôturé';
    case 'open':
    default:
      return 'Ouvert';
  }
}

String _convictionOutcomeLabel(String outcome) {
  switch (outcome) {
    case 'win':
      return 'Gagnant';
    case 'loss':
      return 'Perdant';
    case 'flat':
      return 'Neutre';
    case 'pending':
    default:
      return 'En suivi';
  }
}

Color _convictionStatusColor(String status) {
  switch (status) {
    case 'hit_target':
      return const Color(0xFF13804A);
    case 'invalidated':
      return const Color(0xFFB4533B);
    case 'closed':
      return detailsColor2;
    case 'monitoring':
      return const Color(0xFF175D94);
    case 'open':
    default:
      return textColor;
  }
}

Color _convictionOutcomeColor(String outcome) {
  switch (outcome) {
    case 'win':
      return const Color(0xFF13804A);
    case 'loss':
      return const Color(0xFFB4533B);
    case 'flat':
      return const Color(0xFF7A5F00);
    case 'pending':
    default:
      return detailsColor2;
  }
}

double? _parseOptionalDouble(String raw) {
  if (raw.trim().isEmpty) return null;
  return double.tryParse(raw.replaceAll(',', '.'));
}

int _messageQualityScore(_ForumMessage message) {
  final reactionBoost =
      ((message.reactions['helpful'] ?? 0) * 3) +
      ((message.reactions['clear'] ?? 0) * 3) +
      ((message.reactions['insightful'] ?? 0) * 4);
  final structureBoost =
      (message.attachments.isNotEmpty ? 8 : 0) +
      (message.chartAnnotationPng != null ? 8 : 0) +
      (message.hasStructuredPitch ? 14 : 0) +
      ((message.pitchThesis ?? '').trim().isNotEmpty ? 6 : 0) +
      ((message.pitchCatalysts ?? '').trim().isNotEmpty ? 5 : 0) +
      ((message.pitchRisks ?? '').trim().isNotEmpty ? 5 : 0) +
      (message.convictionTargetPrice != null ? 3 : 0) +
      (message.convictionInvalidationPrice != null ? 3 : 0);
  final resultBoost = switch (message.convictionOutcome) {
    'win' => 14,
    'flat' => 6,
    'loss' => -8,
    _ => 0,
  };
  final rawScore =
      28 + (message.score * 5) + reactionBoost + structureBoost + resultBoost;
  return rawScore.clamp(0, 100).toInt();
}

_ReputationSnapshot _deriveAuthorReputationSnapshot(List<_ForumMessage> posts) {
  if (posts.isEmpty) {
    return const _ReputationSnapshot(
      qualityScore: 0,
      convictionScore: 0,
      reputationScore: 0,
    );
  }
  final qualityAverage =
      posts.fold<int>(0, (total, post) => total + _messageQualityScore(post)) /
      posts.length;
  final pitchPosts = posts.where((post) => post.hasStructuredPitch).toList();
  final settledPitches =
      pitchPosts
          .where(
            (post) =>
                post.convictionStatus == 'closed' &&
                post.convictionOutcome != null &&
                post.convictionOutcome != 'pending',
          )
          .toList();
  final wins =
      settledPitches.where((post) => post.convictionOutcome == 'win').length;
  final avgReturn =
      settledPitches.isEmpty
          ? 0.0
          : settledPitches.fold<double>(
                0,
                (total, post) => total + (post.convictionReturnPct ?? 0),
              ) /
              settledPitches.length;
  final trackingRatio =
      pitchPosts.isEmpty ? 0.0 : settledPitches.length / pitchPosts.length;
  final winRate = settledPitches.isEmpty ? 0.0 : wins / settledPitches.length;
  final convictionScore =
      pitchPosts.isEmpty
          ? qualityAverage * 0.55
          : (28 + (trackingRatio * 28) + (winRate * 30) + (avgReturn * 0.3));
  final reputationScore = ((qualityAverage * 0.62) + (convictionScore * 0.38))
      .clamp(0, 100);
  return _ReputationSnapshot(
    qualityScore: qualityAverage.clamp(0, 100).round(),
    convictionScore: convictionScore.clamp(0, 100).round(),
    reputationScore: reputationScore.round(),
  );
}

List<String> _topTickerCandidates(List<_ForumMessage> messages) {
  final scores = <String, double>{};
  for (final message in messages) {
    for (final attachment in message.attachments) {
      final symbol = attachment.symbol.toUpperCase();
      if (symbol.isEmpty) continue;
      scores.update(
        symbol,
        (value) => value + (_messageQualityScore(message) / 18),
        ifAbsent: () => 1 + (_messageQualityScore(message) / 18),
      );
    }
  }
  final entries =
      scores.entries.toList()
        ..sort((left, right) => right.value.compareTo(left.value));
  return entries.take(8).map((entry) => entry.key).toList();
}

List<_ForumThemeLite> _suggestedThemes(
  List<_ForumThemeLite> themes,
  List<_ForumMessage> messages,
) {
  final curated = themes
      .where((theme) => theme.isCurated)
      .take(6)
      .toList(growable: false);
  if (curated.isNotEmpty) return curated;

  final messageWeights = <String, double>{};
  for (final message in messages) {
    if (message.themeId.isEmpty) continue;
    messageWeights.update(
      message.themeId,
      (value) => value + (_messageQualityScore(message) / 20),
      ifAbsent: () => 1 + (_messageQualityScore(message) / 20),
    );
  }
  final themesById = {for (final theme in themes) theme.id: theme};
  final orderedIds =
      messageWeights.entries.toList()
        ..sort((left, right) => right.value.compareTo(left.value));
  return orderedIds
      .map((entry) => themesById[entry.key])
      .whereType<_ForumThemeLite>()
      .take(6)
      .toList();
}

// ─── Composer (Bottom Sheet) ──────────────────────────────────────────────────

class _ComposerBottomSheet extends StatefulWidget {
  const _ComposerBottomSheet({required this.user, required this.themesQuery});

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
  final TextEditingController _convictionHorizonCtrl = TextEditingController(
    text: '3 mois',
  );
  final TextEditingController _convictionEntryCtrl = TextEditingController();
  final TextEditingController _convictionTargetCtrl = TextEditingController();
  final TextEditingController _convictionInvalidationCtrl =
      TextEditingController();

  _ForumThemeLite? _selectedTheme;
  String _selectedPostType = _forumPostTypes.first;
  String _selectedConvictionSide = _convictionSides.first;
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
    _convictionHorizonCtrl.dispose();
    _convictionEntryCtrl.dispose();
    _convictionTargetCtrl.dispose();
    _convictionInvalidationCtrl.dispose();
    super.dispose();
  }

  Future<List<_ForumTickerAttachment>> _loadPortfolioHoldings() async {
    final user = widget.user;
    if (user == null) return const [];
    try {
      final snap =
          await FirebaseFirestore.instance
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      builder:
          (ctx) => AlertDialog(
            backgroundColor: backgroundColor,
            title: const Text(
              'Nouveau thème',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            ),
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
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Créer'),
              ),
            ],
          ),
    );
    if (name == null || name.isEmpty) return;
    final ref = await FirebaseFirestore.instance.collection('forum_themes').add(
      {
        'name': name,
        'createdAt': Timestamp.now(),
        'createdByUid': widget.user!.uid,
      },
    );
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
    final target =
        _attachedTickers.length == 1
            ? _attachedTickers.first
            : await showCupertinoModalBottomSheet<_ForumTickerAttachment>(
              context: context,
              builder:
                  (_) => _AnnotationTickerPickerSheet(
                    attachments: _attachedTickers,
                  ),
            );
    if (target == null || !mounted) return;
    final png = await showCupertinoModalBottomSheet<String>(
      context: context,
      expand: true,
      builder: (_) => _ChartAnnotationEditor(attachment: target),
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
    final hasContent =
        text.isNotEmpty ||
        _chartAnnotationPng != null ||
        _attachedTickers.isNotEmpty;
    debugPrint(
      '[Forum] hasContent=$hasContent postType=$_selectedPostType text="$text" annotation=${_chartAnnotationPng != null} tickers=${_attachedTickers.length}',
    );
    if (_selectedPostType != 'pitch' && !hasContent) {
      debugPrint('[Forum] blocked: no content');
      _snack('Écris quelque chose ou joins un graphique annoté.');
      return;
    }
    if (_selectedPostType == 'pitch' && _pitchTitleCtrl.text.trim().isEmpty) {
      debugPrint('[Forum] blocked: pitch missing title');
      _snack('Un titre est obligatoire pour un Pitch.');
      return;
    }
    if (_selectedPostType == 'pitch' && _attachedTickers.isEmpty) {
      debugPrint('[Forum] blocked: pitch missing ticker');
      _snack('Attache au moins un ticker pour un Pitch.');
      return;
    }
    final convictionHorizon = _convictionHorizonCtrl.text.trim();
    final convictionEntryPrice = _parseOptionalDouble(
      _convictionEntryCtrl.text.trim(),
    );
    final convictionTargetPrice = _parseOptionalDouble(
      _convictionTargetCtrl.text.trim(),
    );
    final convictionInvalidationPrice = _parseOptionalDouble(
      _convictionInvalidationCtrl.text.trim(),
    );
    if (_selectedPostType == 'pitch' && convictionHorizon.isEmpty) {
      _snack('Définis un horizon de conviction.');
      return;
    }
    if (_selectedPostType == 'pitch' &&
        _convictionEntryCtrl.text.trim().isNotEmpty &&
        convictionEntryPrice == null) {
      _snack('Le prix d’entrée du pitch est invalide.');
      return;
    }
    if (_selectedPostType == 'pitch' &&
        _convictionTargetCtrl.text.trim().isNotEmpty &&
        convictionTargetPrice == null) {
      _snack('Le prix cible du pitch est invalide.');
      return;
    }
    if (_selectedPostType == 'pitch' &&
        _convictionInvalidationCtrl.text.trim().isNotEmpty &&
        convictionInvalidationPrice == null) {
      _snack('Le niveau d’invalidation du pitch est invalide.');
      return;
    }

    setState(() => _sending = true);
    debugPrint('[Forum] sending=true, starting Firestore write...');
    try {
      // 5.3 — anti-spam : max 5 posts / 24h (nécessite un index composite uid+createdAt)
      try {
        final yesterday = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 24)),
        );
        final recentSnap =
            await FirebaseFirestore.instance
                .collection('forum_chat_messages')
                .where('uid', isEqualTo: user.uid)
                .where('createdAt', isGreaterThan: yesterday)
                .limit(6)
                .get();
        debugPrint(
          '[Forum] spam check: ${recentSnap.docs.length} posts in last 24h',
        );
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
      _ReputationSnapshot authorReputation = const _ReputationSnapshot(
        qualityScore: 0,
        convictionScore: 0,
        reputationScore: 0,
      );
      try {
        final userSnap =
            await FirebaseFirestore.instance
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
        isVerifiedAuthor = level >= 10 || achievements.contains('investor_50k');
        final firestoreName = (d['Name'] as String?)?.trim() ?? '';
        if (firestoreName.isNotEmpty) authorName = firestoreName;
        authorAvatarId = d['avatar_id'] as String?;
      } catch (_) {}
      try {
        final previousPostsSnap =
            await FirebaseFirestore.instance
                .collection('forum_chat_messages')
                .where('uid', isEqualTo: user.uid)
                .limit(80)
                .get();
        final previousPosts =
            previousPostsSnap.docs.map(_ForumMessage.fromDoc).toList();
        authorReputation = _deriveAuthorReputationSnapshot(previousPosts);
      } catch (_) {}

      final now = Timestamp.now();
      final doc = <String, dynamic>{
        'text': text,
        'uid': user.uid,
        'authorName': authorName,
        'authorAvatarId': authorAvatarId,
        'photoURL': user.photoURL,
        'authorKarma': authorKarma,
        'authorQualityScore': authorReputation.qualityScore,
        'authorConvictionScore': authorReputation.convictionScore,
        'authorReputationScore': authorReputation.reputationScore,
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
        doc['convictionSide'] = _selectedConvictionSide;
        doc['convictionStatus'] = 'open';
        doc['convictionOutcome'] = 'pending';
        doc['convictionHorizon'] = convictionHorizon;
        doc['convictionOpenedAt'] = now;
        doc['convictionUpdatedAt'] = now;
        if (convictionEntryPrice != null) {
          doc['convictionEntryPrice'] = convictionEntryPrice;
        }
        if (convictionTargetPrice != null) {
          doc['convictionTargetPrice'] = convictionTargetPrice;
        }
        if (convictionInvalidationPrice != null) {
          doc['convictionInvalidationPrice'] = convictionInvalidationPrice;
        }
      }
      debugPrint(
        '[Forum] doc ready, writing to Firestore: ${doc.keys.toList()}',
      );
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .add(doc);
      debugPrint('[Forum] Firestore write SUCCESS');
      // 4.2 — effacer le brouillon sauvegardé
      unawaited(
        SharedPreferences.getInstance().then((p) => p.remove('forum_draft')),
      );
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Partage ton analyse, ta question ou ton alerte.',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
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
                        final themes =
                            (snapshot.data?.docs ?? [])
                                .map(_ForumThemeLite.fromDoc)
                                .toList()
                              ..sort((left, right) {
                                if (left.isCurated != right.isCurated) {
                                  return left.isCurated ? -1 : 1;
                                }
                                return left.name.toLowerCase().compareTo(
                                  right.name.toLowerCase(),
                                );
                              });
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
                              items:
                                  themes
                                      .map(
                                        (t) =>
                                            DropdownMenuItem<_ForumThemeLite>(
                                              value: t,
                                              child: Text(
                                                t.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                      )
                                      .toList(),
                              onChanged:
                                  (t) => setState(() => _selectedTheme = t),
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
                    items:
                        _forumPostTypes
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
                children:
                    _forumTagOptions.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected:
                            (_) => setState(() {
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
                          color:
                              selected
                                  ? detailsColor2.withValues(alpha: 0.18)
                                  : const Color(0xFFE6E8EB),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
              // ── 2.4 — champs pitch ──
              if (_selectedPostType == 'pitch') ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _convictionSides.map((side) {
                        final selected = _selectedConvictionSide == side;
                        return ChoiceChip(
                          label: Text(_convictionSideLabel(side)),
                          selected: selected,
                          onSelected:
                              (_) => setState(
                                () => _selectedConvictionSide = side,
                              ),
                          selectedColor: detailsColor1.withValues(alpha: 0.16),
                          backgroundColor: const Color(0xFFF7F8FA),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: selected ? detailsColor2 : textColor,
                            fontWeight: FontWeight.w800,
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
                const SizedBox(height: 10),
                _WhiteInputBox(
                  child: TextField(
                    controller: _pitchTitleCtrl,
                    enabled: user != null && !_sending,
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Titre du pitch (ex: Long LVMH)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _WhiteInputBox(
                        child: TextField(
                          controller: _convictionHorizonCtrl,
                          enabled: user != null && !_sending,
                          onTapOutside:
                              (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Horizon (ex: 3 mois)',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WhiteInputBox(
                        child: TextField(
                          controller: _convictionEntryCtrl,
                          enabled: user != null && !_sending,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onTapOutside:
                              (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Entrée',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _WhiteInputBox(
                        child: TextField(
                          controller: _convictionTargetCtrl,
                          enabled: user != null && !_sending,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onTapOutside:
                              (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Cible',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WhiteInputBox(
                        child: TextField(
                          controller: _convictionInvalidationCtrl,
                          enabled: user != null && !_sending,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onTapOutside:
                              (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Invalidation',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _WhiteInputBox(
                  child: TextField(
                    controller: _pitchThesisCtrl,
                    enabled: user != null && !_sending,
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                    final available =
                        holdings
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
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: available.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final h = available[i];
                              return ActionChip(
                                label: Text(h.symbol),
                                avatar: const Icon(Icons.add_rounded, size: 14),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: detailsColor2.withValues(alpha: 0.18),
                                ),
                                labelStyle: const TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                onPressed:
                                    _attachedTickers.length >= 3
                                        ? null
                                        : () {
                                          if (_attachedTickers.any(
                                            (t) => t.symbol == h.symbol,
                                          )) {
                                            return;
                                          }
                                          setState(
                                            () => _attachedTickers.add(h),
                                          );
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_attachedTickers.length < 3)
                    OutlinedButton.icon(
                      onPressed: _pickTickerAttachment,
                      icon: const Icon(Icons.show_chart_rounded),
                      label: Text(
                        _attachedTickers.isEmpty
                            ? 'Attacher un ticker'
                            : 'Ajouter un ticker (${_attachedTickers.length}/3)',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: detailsColor2,
                        side: BorderSide(
                          color: detailsColor2.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  if (_attachedTickers.isNotEmpty &&
                      _selectedPostType != 'pitch') ...[
                    if (_attachedTickers.length < 3) const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openAnnotationEditor,
                      icon: const Icon(Icons.draw_rounded),
                      label: Text(
                        _chartAnnotationPng == null
                            ? 'Ouvrir l’atelier d’annotation'
                            : 'Refaire l’annotation',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: detailsColor2.withValues(alpha: 0.22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_attachedTickers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  children:
                      _attachedTickers.map((t) {
                        final idx = _attachedTickers.indexOf(t);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ForumTickerAttachmentPreview(
                            attachment: t,
                            compact: true,
                            onRemove:
                                () => setState(
                                  () => _attachedTickers.removeAt(idx),
                                ),
                          ),
                        );
                      }).toList(),
                ),
              ],
              if (_chartAnnotationPng != null) ...[
                const SizedBox(height: 8),
                _AnnotationImagePreview(
                  base64Png: _chartAnnotationPng!,
                  onTap: _openAnnotationEditor,
                  onRemove: () => setState(() => _chartAnnotationPng = null),
                ),
              ],
              const SizedBox(height: 12),
              // ── Texte ──
              _WhiteInputBox(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: user != null && !_sending,
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  minLines: 3,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  // 4.2 — auto-save brouillon
                  onChanged:
                      (v) => SharedPreferences.getInstance().then(
                        (p) => p.setString('forum_draft', v),
                      ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        user == null
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon:
                      _sending
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
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

class _PitchLifecycleSheet extends StatefulWidget {
  const _PitchLifecycleSheet({required this.message});

  final _ForumMessage message;

  @override
  State<_PitchLifecycleSheet> createState() => _PitchLifecycleSheetState();
}

class _PitchLifecycleSheetState extends State<_PitchLifecycleSheet> {
  late String _status;
  late String _outcome;
  late final TextEditingController _returnCtrl;
  late final TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.message.convictionStatus ?? 'open';
    _outcome = widget.message.convictionOutcome ?? 'pending';
    _returnCtrl = TextEditingController(
      text:
          widget.message.convictionReturnPct == null
              ? ''
              : widget.message.convictionReturnPct!.toStringAsFixed(1),
    );
    _noteCtrl = TextEditingController(
      text: widget.message.convictionNote ?? '',
    );
  }

  @override
  void dispose() {
    _returnCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final returnPct = _parseOptionalDouble(_returnCtrl.text.trim());
    if (_returnCtrl.text.trim().isNotEmpty && returnPct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le rendement du pitch est invalide.')),
      );
      return;
    }
    if (_status == 'closed' && _outcome == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis un résultat final pour clôturer.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final now = Timestamp.now();
    final resolvedOutcome = switch (_status) {
      'hit_target' => 'win',
      'invalidated' => 'loss',
      'closed' => _outcome,
      _ => 'pending',
    };
    try {
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .doc(widget.message.id)
          .set({
            'convictionStatus': _status,
            'convictionOutcome': resolvedOutcome,
            'convictionUpdatedAt': now,
            'convictionClosedAt': _status == 'closed' ? now : null,
            'convictionReturnPct': returnPct,
            'convictionNote': _noteCtrl.text.trim(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour impossible : $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const Text(
                'Suivi de conviction',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.message.pitchTitle?.trim().isNotEmpty == true
                    ? widget.message.pitchTitle!
                    : widget.message.primaryTicker ?? 'Pitch',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _convictionStatuses.map((status) {
                      final active = _status == status;
                      return ChoiceChip(
                        label: Text(_convictionStatusLabel(status)),
                        selected: active,
                        onSelected: (_) => setState(() => _status = status),
                        selectedColor: detailsColor1.withValues(alpha: 0.16),
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: active ? detailsColor2 : textColor,
                          fontWeight: FontWeight.w800,
                        ),
                        side: BorderSide(
                          color:
                              active
                                  ? detailsColor2.withValues(alpha: 0.18)
                                  : const Color(0xFFE6E8EB),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
              if (_status == 'closed')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _convictionOutcomes
                          .where((outcome) => outcome != 'pending')
                          .map((outcome) {
                            final active = _outcome == outcome;
                            return ChoiceChip(
                              label: Text(_convictionOutcomeLabel(outcome)),
                              selected: active,
                              onSelected:
                                  (_) => setState(() => _outcome = outcome),
                              selectedColor: detailsColor1.withValues(
                                alpha: 0.16,
                              ),
                              backgroundColor: Colors.white,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: active ? detailsColor2 : textColor,
                                fontWeight: FontWeight.w800,
                              ),
                              side: BorderSide(
                                color:
                                    active
                                        ? detailsColor2.withValues(alpha: 0.18)
                                        : const Color(0xFFE6E8EB),
                              ),
                            );
                          })
                          .toList(),
                ),
              if (_status == 'closed') const SizedBox(height: 12),
              _WhiteInputBox(
                child: TextField(
                  controller: _returnCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Performance finale (%)',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _WhiteInputBox(
                child: TextField(
                  controller: _noteCtrl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Note de suivi: ce qui a changé, ce qui a cassé, ce qui a confirmé…',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon:
                      _saving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.track_changes_rounded),
                  label: Text(
                    _saving ? 'Mise à jour...' : 'Enregistrer le suivi',
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

// ─── Header compact du feed ──────────────────────────────────────────────────

class _ForumFeedHeader extends StatelessWidget {
  const _ForumFeedHeader({
    required this.controller,
    required this.query,
    required this.activeTagFilter,
    required this.activeTickerFilter,
    required this.activeThemeFilterId,
    required this.bookmarksOnly,
    required this.themes,
    required this.messages,
    required this.onChanged,
    required this.onToggleBookmarks,
    required this.onSelectTag,
    required this.onSelectTicker,
    required this.onSelectTheme,
    required this.onClearAll,
  });

  final TextEditingController controller;
  final String query;
  final String? activeTagFilter;
  final String? activeTickerFilter;
  final String? activeThemeFilterId;
  final bool bookmarksOnly;
  final List<_ForumThemeLite> themes;
  final List<_ForumMessage> messages;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleBookmarks;
  final ValueChanged<String> onSelectTag;
  final ValueChanged<String> onSelectTicker;
  final ValueChanged<_ForumThemeLite> onSelectTheme;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final themeById = {for (final theme in themes) theme.id: theme};
    final selectedTheme =
        activeThemeFilterId == null ? null : themeById[activeThemeFilterId];
    final suggestedThemes = _suggestedThemes(themes, messages);
    final topTickers = _topTickerCandidates(messages);
    final hasAnyFilters =
        query.trim().isNotEmpty ||
        activeTagFilter != null ||
        activeTickerFilter != null ||
        selectedTheme != null ||
        bookmarksOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('forum_weekly_winner')
                  .doc('current')
                  .snapshots(),
          builder: (context, winnerSnap) {
            final data = winnerSnap.data?.data();
            if (data == null) return const SizedBox.shrink();
            final weekOf = data['weekOf'] as Timestamp?;
            if (weekOf == null) return const SizedBox.shrink();
            final age = DateTime.now().difference(weekOf.toDate()).inDays;
            if (age > 7) return const SizedBox.shrink();
            return _WeeklyWinnerBanner(data: data);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE6E8EB)),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Rechercher un post, un thème ou un ticker...',
                      icon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CircleToggleButton(
                active: bookmarksOnly,
                icon: Icons.bookmark_rounded,
                tooltip: 'Favoris uniquement',
                onTap: onToggleBookmarks,
              ),
              if (hasAnyFilters) ...[
                const SizedBox(width: 8),
                _CircleToggleButton(
                  active: true,
                  icon: Icons.close_rounded,
                  tooltip: 'Réinitialiser les filtres',
                  onTap: onClearAll,
                ),
              ],
            ],
          ),
        ),
        if (hasAnyFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (bookmarksOnly) const _FilterStatusPill(label: 'Favoris'),
                if (activeTagFilter != null)
                  _FilterStatusPill(label: '#$activeTagFilter'),
                if (activeTickerFilter != null)
                  _FilterStatusPill(label: activeTickerFilter!),
                if (selectedTheme != null)
                  _FilterStatusPill(label: selectedTheme.name),
                if (query.trim().isNotEmpty)
                  _FilterStatusPill(label: 'Recherche: ${query.trim()}'),
              ],
            ),
          ),
        if (suggestedThemes.isNotEmpty)
          _HorizontalFeedStrip<_ForumThemeLite>(
            title: 'Thèmes à suivre',
            items: suggestedThemes,
            labelBuilder: (theme) => theme.name,
            activeCheck: (theme) => activeThemeFilterId == theme.id,
            onTap: onSelectTheme,
          ),
        if (topTickers.isNotEmpty)
          _HorizontalFeedStrip<String>(
            title: 'Flux ticker',
            items: topTickers,
            labelBuilder: (ticker) => ticker,
            activeCheck: (ticker) => activeTickerFilter == ticker,
            onTap: onSelectTicker,
          ),
        _HorizontalFeedStrip<String>(
          title: 'Tags rapides',
          items: _forumTagOptions,
          labelBuilder: (tag) => '#$tag',
          activeCheck: (tag) => activeTagFilter == tag,
          onTap: onSelectTag,
        ),
      ],
    );
  }
}

class _HorizontalFeedStrip<T> extends StatelessWidget {
  const _HorizontalFeedStrip({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.activeCheck,
    required this.onTap,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final bool Function(T item) activeCheck;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final active = activeCheck(item);
                return ChoiceChip(
                  label: Text(labelBuilder(item)),
                  selected: active,
                  onSelected: (_) => onTap(item),
                  selectedColor: detailsColor1.withValues(alpha: 0.16),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: active ? detailsColor2 : textColor,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color:
                        active
                            ? detailsColor2.withValues(alpha: 0.18)
                            : const Color(0xFFE6E8EB),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterStatusPill extends StatelessWidget {
  const _FilterStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: detailsColor2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: detailsColor2,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
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
    required this.canManagePitch,
    required this.isBookmarked,
    required this.isExpanded,
    required this.isFollowingTheme,
    required this.isHighlighted,
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
    required this.onManagePitch,
    required this.onOpenTickerFeed,
    required this.onOpenThemeFeed,
    required this.onDelete,
    required this.replies,
  });

  final _ForumMessage message;
  final bool canModerate;
  final bool canReport;
  final bool canDelete;
  final bool canManagePitch;
  final bool isBookmarked;
  final bool isExpanded;
  final bool isFollowingTheme;
  final bool isHighlighted;
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
  final VoidCallback onManagePitch;
  final ValueChanged<String> onOpenTickerFeed;
  final VoidCallback onOpenThemeFeed;
  final VoidCallback onDelete;
  final Widget? replies;

  // 5.1 — le post doit-il être replié ?
  bool get _isCollapsed => message.score < -3 && !isForceExpandedNegative;

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
            const Icon(
              Icons.visibility_off_rounded,
              size: 16,
              color: Colors.black38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Post masqué (score ${message.score}) — ',
                style: const TextStyle(color: Colors.black45, fontSize: 13),
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
        border: Border.all(
          color: isHighlighted ? detailsColor2 : const Color(0xFFE6E8EB),
          width: isHighlighted ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? detailsColor2 : Colors.black).withValues(
              alpha: isHighlighted ? 0.12 : 0.04,
            ),
            blurRadius: isHighlighted ? 22 : 16,
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
                onTap:
                    () => showCupertinoModalBottomSheet<void>(
                      context: context,
                      expand: false,
                      builder:
                          (_) => _AuthorProfileSheet(
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
                              fontWeight: FontWeight.w900,
                            ),
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
                        if (message.authorReputationScore > 0) ...[
                          const SizedBox(width: 6),
                          _ForumReputationBadge(
                            score: message.authorReputationScore,
                          ),
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
                        GestureDetector(
                          onTap: onOpenThemeFeed,
                          child: _PostBadge(
                            label: message.themeName,
                            alternate: true,
                          ),
                        ),
                        _ForumQualityBadge(
                          score: _messageQualityScore(message),
                        ),
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
                      if (value == 'manage_pitch') onManagePitch();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) {
                      final items = <PopupMenuEntry<String>>[];
                      if (canManagePitch) {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'manage_pitch',
                            child: Text('Mettre à jour la conviction'),
                          ),
                        );
                      }
                      if (canDelete) {
                        if (items.isNotEmpty) {
                          items.add(const PopupMenuDivider());
                        }
                        items.add(
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (canModerate) {
                        if (items.isNotEmpty) {
                          items.add(const PopupMenuDivider());
                        }
                        items.add(
                          PopupMenuItem<String>(
                            value: 'pin',
                            child: Text(
                              message.isPinned ? 'Désépingler' : 'Épingler',
                            ),
                          ),
                        );
                      }
                      if (canReport) {
                        if (items.isNotEmpty) {
                          items.add(const PopupMenuDivider());
                        }
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: Text('Signaler'),
                          ),
                        );
                      }
                      if (items.isNotEmpty) {
                        items.add(const PopupMenuDivider());
                      }
                      items.add(
                        PopupMenuItem<String>(
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
                        ),
                      );
                      return items;
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message.text,
            style: const TextStyle(color: textColor, height: 1.45),
          ),
          if (message.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  message.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: detailsColor1.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
          // 2.2 — multi-ticker side-by-side
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MultiTickerRow(
              attachments: message.attachments,
              onTap: onOpenTickerFeed,
            ),
          ],
          // 2.1 — annotation exportée
          if (message.chartAnnotationPng != null) ...[
            const SizedBox(height: 12),
            _AnnotationImagePreview(base64Png: message.chartAnnotationPng!),
          ],
          // 2.4 — pitch structuré
          if (message.postType == 'pitch') ...[
            const SizedBox(height: 12),
            _PitchCard(message: message, onOpenTickerFeed: onOpenTickerFeed),
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
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
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
    String replyId,
    int value,
    Map<String, dynamic> replyData,
  ) async {
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
        tx.set(replyRef, {
          'upVotes': FieldValue.increment(deltaUp),
          'downVotes': FieldValue.increment(deltaDown),
          'score': FieldValue.increment(deltaScore),
          'lastVoteAt': now,
        }, SetOptions(merge: true));
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
    final filtered =
        participants.where((p) => p.toLowerCase().startsWith(query)).toList();
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
      selection: TextSelection.collapsed(offset: atIdx + name.length + 2),
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
          const Text(
            'Réponses',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('forum_chat_messages')
                    .doc(widget.message.id)
                    .collection('replies')
                    .orderBy('createdAt')
                    .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              // 3.4 — tri client-side par score desc
              final sorted = [...docs]..sort((a, b) {
                final sa = (a.data()['score'] as num?)?.toInt() ?? 0;
                final sb = (b.data()['score'] as num?)?.toInt() ?? 0;
                return sb.compareTo(sa);
              });

              // 3.5 — participants (pour @mentions)
              final participants = <String>{widget.message.authorName};
              for (final doc in docs) {
                final name = (doc.data()['authorName'] as String?) ?? '';
                if (name.isNotEmpty) participants.add(name);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sorted.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Aucune réponse pour le moment.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    for (final doc in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReplyBubble(
                          replyId: doc.id,
                          data: doc.data(),
                          currentUid: widget.currentUser?.uid,
                          onVoteUp: () => _voteReply(doc.id, 1, doc.data()),
                          onVoteDown: () => _voteReply(doc.id, -1, doc.data()),
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
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder:
                            (context, i) => ActionChip(
                              label: Text('@${_mentionCandidates[i]}'),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: detailsColor2.withValues(alpha: 0.2),
                              ),
                              labelStyle: const TextStyle(
                                color: detailsColor2,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onPressed:
                                  () => _insertMention(_mentionCandidates[i]),
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _WhiteInputBox(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.currentUser != null && !_sending,
                      onTapOutside:
                          (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      minLines: 1,
                      maxLines: 4,
                      onChanged:
                          (v) => _onTextChanged(v, participants.toList()),
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
                      onPressed:
                          widget.currentUser == null || _sending
                              ? null
                              : () async {
                                final text = _controller.text.trim();
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
      final results = await YahooFinanceService.searchSecurities(
        trimmed,
        quotesCount: 20,
      );
      if (!mounted) return;
      setState(() {
        _results =
            results
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6E8EB)),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(color: detailsColor1),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap:
                                () => Navigator.of(context).pop(
                                  _ForumTickerAttachment.fromSearchResult(item),
                                ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE6E8EB),
                                ),
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
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.symbol,
                                          style: const TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _PostBadge(
                                    label: item.instrumentLabel,
                                    alternate: true,
                                  ),
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
    this.onTap,
  });

  final _ForumTickerAttachment attachment;
  final bool compact;
  final VoidCallback? onRemove;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
                    Text(
                      attachment.symbol,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attachment.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TickerMetaPill(
                label:
                    attachment.quoteType.trim().isEmpty
                        ? 'Actif'
                        : attachment.quoteType,
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TickerMetaPill(
                label:
                    attachment.exchange.trim().isEmpty
                        ? 'Marché inconnu'
                        : attachment.exchange,
              ),
              _TickerMetaPill(
                label:
                    attachment.currency.trim().isEmpty
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
    if (onTap == null) {
      return content;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap!(attachment.symbol.toUpperCase()),
      child: content,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: detailsColor1,
            ),
          );
        }
        final payload = snapshot.data;
        if (payload == null) {
          return Container(
            height: 132,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
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
          color:
              payload.positive
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
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
                            Text(
                              payload.priceLabel,
                              style: const TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              payload.changeLabel,
                              style: TextStyle(
                                color:
                                    payload.positive
                                        ? const Color(0xFF177A53)
                                        : const Color(0xFF9A2D2D),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TickerMetaPill(label: payload.marketLabel),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        payload.points.length < 2
                            ? const Center(
                              child: Text(
                                'Mini-courbe indisponible',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
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
    final fillPath =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
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
      child: Text(
        label,
        style: const TextStyle(
          color: detailsColor2,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
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
    _ForumTickerAttachment attachment, {
    ChartInterval interval = ChartInterval.sevenDays,
  }) async {
    QuoteDetail? quote;
    List<HistoricalPoint> points = const <HistoricalPoint>[];
    try {
      quote = await YahooFinanceService.fetchQuote(attachment.symbol);
    } catch (_) {
      quote = null;
    }
    try {
      points = await YahooFinanceService.fetchHistoricalSeries(
        attachment.symbol,
        interval,
      );
    } catch (_) {
      points = const <HistoricalPoint>[];
    }
    final marketPrice = quote?.regularMarketPrice;
    final change = quote?.regularMarketChange;
    final changePercent = quote?.regularMarketChangePercent;
    final positive =
        points.length >= 2
            ? points.last.close >= points.first.close
            : (change ?? 0) >= 0;
    if (marketPrice == null && points.isEmpty) return null;
    final priceLabel =
        marketPrice == null
            ? attachment.currency.trim().isEmpty
                ? 'Cours indisponible'
                : 'Cours en ${attachment.currency}'
            : '${marketPrice.toStringAsFixed(marketPrice >= 100 ? 2 : 3)} ${attachment.currency.trim().isEmpty ? '' : attachment.currency}'
                .trim();
    final changeLabel =
        change == null
            ? 'Variation en direct indisponible'
            : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}${changePercent == null ? '' : ' · ${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%'}';
    final marketLabel =
        (quote?.fullExchangeName ?? quote?.exchange ?? attachment.exchange)
                .trim()
                .isEmpty
            ? 'Marché'
            : (quote?.fullExchangeName ??
                    quote?.exchange ??
                    attachment.exchange)
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
              Text(
                authorName,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
              color:
                  active
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            Text(
              label,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              Text(
                '$label · $count',
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
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
        color:
            alternate
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
  const _ForumTabStrip({required this.controller});

  final TabController controller;

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
        controller: controller,
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
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        tabs: const [Tab(text: 'Fil'), Tab(text: 'Suivi'), Tab(text: 'Top 🔥')],
      ),
    );
  }
}

/// FAB animé (flottement sinusoïdal) avec icône stylo SVG
class _AnimatedComposerFab extends StatelessWidget {
  const _AnimatedComposerFab({required this.ctrl, required this.onTap});

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
          return Transform.translate(offset: Offset(dx, dy), child: child);
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

  const _KarmaLevel({required this.emoji, required this.bg, required this.fg});
  final String emoji;
  final Color bg;
  final Color fg;
}

class _ForumReputationBadge extends StatelessWidget {
  const _ForumReputationBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color =
        score >= 75
            ? const Color(0xFF175D94)
            : score >= 55
            ? detailsColor2
            : const Color(0xFF7A5F00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Rep $score',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ForumQualityBadge extends StatelessWidget {
  const _ForumQualityBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color =
        score >= 78
            ? const Color(0xFF13804A)
            : score >= 55
            ? detailsColor2
            : const Color(0xFF7A5F00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Qualité $score',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
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
        spans.add(
          TextSpan(
            text: text.substring(last, match.start),
            style: const TextStyle(color: textColor, height: 1.35),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: detailsColor2,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(last),
          style: const TextStyle(color: textColor, height: 1.35),
        ),
      );
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
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ProfileStatChip(
                          label: 'Posts',
                          value: '${stats.postCount}',
                        ),
                        _ProfileStatChip(
                          label: 'Niveau',
                          value: '${stats.level}',
                        ),
                        _ProfileStatChip(
                          label: 'Réputation',
                          value: '${stats.reputationScore}',
                        ),
                        _ProfileStatChip(
                          label: 'Qualité',
                          value: '${stats.qualityScore}',
                        ),
                        _ProfileStatChip(
                          label: 'Convictions',
                          value: '${stats.convictionScore}',
                        ),
                        if (stats.closedPitchCount > 0)
                          _ProfileStatChip(
                            label: 'Win rate',
                            value:
                                '${(stats.convictionWinRate * 100).toStringAsFixed(0)}%',
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
                              border: Border.all(
                                color: const Color(0xFFE6E8EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _PostBadge(
                                      label:
                                          stats.topPost!['themeName']
                                              as String? ??
                                          'Thème',
                                      alternate: true,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 14,
                                      color: detailsColor2.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
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
                                    color: textColor,
                                    height: 1.4,
                                  ),
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
    required this.qualityScore,
    required this.convictionScore,
    required this.reputationScore,
    required this.closedPitchCount,
    required this.convictionWinRate,
    this.topPost,
  });

  final int karma;
  final int level;
  final int postCount;
  final int qualityScore;
  final int convictionScore;
  final int reputationScore;
  final int closedPitchCount;
  final double convictionWinRate;
  final Map<String, dynamic>? topPost;

  static Future<_AuthorStats> load(String uid) async {
    int karma = 0;
    int level = 0;
    int postCount = 0;
    int qualityScore = 0;
    int convictionScore = 0;
    int reputationScore = 0;
    int closedPitchCount = 0;
    double convictionWinRate = 0;
    Map<String, dynamic>? topPost;

    try {
      final userSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      karma = (userSnap.data()?['karma'] as num?)?.toInt() ?? 0;
      level = (userSnap.data()?['level'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final postsSnap =
          await FirebaseFirestore.instance
              .collection('forum_chat_messages')
              .where('uid', isEqualTo: uid)
              .limit(80)
              .get();
      final posts = postsSnap.docs.map(_ForumMessage.fromDoc).toList();
      postCount = posts.length;
      if (posts.isNotEmpty) {
        final snapshot = _deriveAuthorReputationSnapshot(posts);
        qualityScore = snapshot.qualityScore;
        convictionScore = snapshot.convictionScore;
        reputationScore = snapshot.reputationScore;

        final settledPitches =
            posts
                .where(
                  (post) =>
                      post.hasStructuredPitch &&
                      post.convictionStatus == 'closed' &&
                      post.convictionOutcome != null &&
                      post.convictionOutcome != 'pending',
                )
                .toList();
        closedPitchCount = settledPitches.length;
        if (settledPitches.isNotEmpty) {
          final wins =
              settledPitches
                  .where((post) => post.convictionOutcome == 'win')
                  .length;
          convictionWinRate = wins / settledPitches.length;
        }

        final topMessage = [...posts]..sort(
          (left, right) =>
              _messageQualityScore(right).compareTo(_messageQualityScore(left)),
        );
        final best = topMessage.first;
        topPost = <String, dynamic>{
          'themeName': best.themeName,
          'score': best.score,
          'text': best.text,
        };
      }
    } catch (_) {}

    return _AuthorStats(
      karma: karma,
      level: level,
      postCount: postCount,
      qualityScore: qualityScore,
      convictionScore: convictionScore,
      reputationScore: reputationScore,
      closedPitchCount: closedPitchCount,
      convictionWinRate: convictionWinRate,
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
  const _MultiTickerRow({required this.attachments, this.onTap});

  final List<_ForumTickerAttachment> attachments;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    if (attachments.length == 1) {
      return _ForumTickerAttachmentPreview(
        attachment: attachments.first,
        onTap: onTap,
      );
    }
    return Row(
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _CompactTickerCard(attachment: attachments[i], onTap: onTap),
          ),
        ],
      ],
    );
  }
}

class _CompactTickerCard extends StatelessWidget {
  const _CompactTickerCard({required this.attachment, this.onTap});

  final _ForumTickerAttachment attachment;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            attachment.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 60, child: _MiniTickerChart(attachment: attachment)),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap!(attachment.symbol.toUpperCase()),
      child: content,
    );
  }
}

// ─── 2.1 — Aperçu annotation PNG ─────────────────────────────────────────────

class _AnnotationImagePreview extends StatelessWidget {
  const _AnnotationImagePreview({
    required this.base64Png,
    this.onTap,
    this.onRemove,
  });

  final String base64Png;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    late final Uint8List bytes;
    try {
      bytes = base64Decode(base64Png);
    } catch (_) {
      return const SizedBox.shrink();
    }
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(bytes, width: double.infinity, fit: BoxFit.fitWidth),
    );
    return Stack(
      children: [
        if (onTap == null)
          preview
        else
          GestureDetector(onTap: onTap, child: preview),
        if (onTap != null)
          Positioned(
            left: 10,
            bottom: 10,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Retoucher',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
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
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnnotationTickerPickerSheet extends StatelessWidget {
  const _AnnotationTickerPickerSheet({required this.attachments});

  final List<_ForumTickerAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        math
            .min(
              MediaQuery.of(context).size.height * 0.72,
              180 + (attachments.length * 112),
            )
            .toDouble();
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: maxHeight,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  'Choisir le ticker à annoter',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'L’annotation sera générée à partir du graphique du ticker sélectionné.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(context).pop(attachment),
                      child: _ForumTickerAttachmentPreview(
                        attachment: attachment,
                        compact: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 2.4 — Pitch card ────────────────────────────────────────────────────────

class _PitchCard extends StatelessWidget {
  const _PitchCard({required this.message, this.onOpenTickerFeed});

  final _ForumMessage message;
  final ValueChanged<String>? onOpenTickerFeed;

  @override
  Widget build(BuildContext context) {
    final hasTicker = message.attachments.isNotEmpty;
    final ticker = hasTicker ? message.attachments.first.symbol : null;
    final statusColor = _convictionStatusColor(
      message.convictionStatus ?? 'open',
    );
    final outcomeColor = _convictionOutcomeColor(
      message.convictionOutcome ?? 'pending',
    );

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: detailsColor2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '🎯 Pitch',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (ticker != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap:
                      onOpenTickerFeed == null
                          ? null
                          : () => onOpenTickerFeed!(ticker.toUpperCase()),
                  child: _TickerMetaPill(label: ticker),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PitchMetricPill(
                label: message.convictionSideLabel,
                color: detailsColor2,
              ),
              _PitchMetricPill(
                label: message.convictionStatusLabel,
                color: statusColor,
              ),
              if ((message.convictionHorizon ?? '').trim().isNotEmpty)
                _PitchMetricPill(
                  label: message.convictionHorizon!,
                  color: const Color(0xFF175D94),
                ),
              _PitchMetricPill(
                label: message.convictionOutcomeLabel,
                color: outcomeColor,
              ),
            ],
          ),
          if ((message.pitchTitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message.pitchTitle!,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
          if (message.convictionEntryPrice != null ||
              message.convictionTargetPrice != null ||
              message.convictionInvalidationPrice != null ||
              message.convictionReturnPct != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (message.convictionEntryPrice != null)
                  _PitchMetricPill(
                    label:
                        'Entrée ${message.convictionEntryPrice!.toStringAsFixed(2)}',
                    color: textColor,
                  ),
                if (message.convictionTargetPrice != null)
                  _PitchMetricPill(
                    label:
                        'Cible ${message.convictionTargetPrice!.toStringAsFixed(2)}',
                    color: const Color(0xFF13804A),
                  ),
                if (message.convictionInvalidationPrice != null)
                  _PitchMetricPill(
                    label:
                        'Invalidation ${message.convictionInvalidationPrice!.toStringAsFixed(2)}',
                    color: const Color(0xFFB4533B),
                  ),
                if (message.convictionReturnPct != null)
                  _PitchMetricPill(
                    label:
                        '${message.convictionReturnPct! >= 0 ? '+' : ''}${message.convictionReturnPct!.toStringAsFixed(1)}%',
                    color:
                        message.convictionReturnPct! >= 0
                            ? const Color(0xFF13804A)
                            : const Color(0xFFB4533B),
                  ),
              ],
            ),
          ],
          if ((message.pitchThesis ?? '').isNotEmpty)
            _PitchSection(
              icon: Icons.lightbulb_rounded,
              label: 'Thèse',
              text: message.pitchThesis!,
            ),
          if ((message.pitchCatalysts ?? '').isNotEmpty)
            _PitchSection(
              icon: Icons.rocket_launch_rounded,
              label: 'Catalyseurs',
              text: message.pitchCatalysts!,
            ),
          if ((message.pitchRisks ?? '').isNotEmpty)
            _PitchSection(
              icon: Icons.warning_amber_rounded,
              label: 'Risques',
              text: message.pitchRisks!,
            ),
          if ((message.convictionNote ?? '').trim().isNotEmpty)
            _PitchSection(
              icon: Icons.track_changes_rounded,
              label: 'Suivi',
              text: message.convictionNote!,
            ),
        ],
      ),
    );
  }
}

class _PitchMetricPill extends StatelessWidget {
  const _PitchMetricPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
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
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: textColor, height: 1.4)),
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
    final positions =
        (snapshot['positions'] as List<dynamic>?)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: detailsColor2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '📊 Snapshot portefeuille',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      pnlPositive
                          ? const Color(0xFFE8F5EC)
                          : const Color(0xFFFFEFEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pnlPositive ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color:
                        pnlPositive
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
              fontWeight: FontWeight.w600,
            ),
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
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
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
              fontSize: 11,
            ),
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
              color:
                  pnlPositive
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

enum _AnnotationTool { trendLine, hLine, zone, pen, upArrow, downArrow }

enum _AnnotationInteractionMode { draw, navigate }

class _AnnotationStroke {
  _AnnotationStroke({required this.tool, required this.color});

  final _AnnotationTool tool;
  final Color color;
  final List<Offset> points = <Offset>[];
}

Rect _annotationPlotRect(Size size) {
  return Rect.fromLTRB(18, 18, size.width - 18, size.height - 28);
}

String _annotationToolLabel(_AnnotationTool tool) {
  switch (tool) {
    case _AnnotationTool.trendLine:
      return 'Tendance';
    case _AnnotationTool.hLine:
      return 'Support';
    case _AnnotationTool.zone:
      return 'Zone';
    case _AnnotationTool.pen:
      return 'Libre';
    case _AnnotationTool.upArrow:
      return 'Flèche haute';
    case _AnnotationTool.downArrow:
      return 'Flèche basse';
  }
}

String _annotationToolHint(_AnnotationTool tool) {
  switch (tool) {
    case _AnnotationTool.trendLine:
      return 'Glisse pour tracer une droite de tendance.';
    case _AnnotationTool.hLine:
      return 'Place une ligne horizontale pour ton niveau clé.';
    case _AnnotationTool.zone:
      return 'Délimite une zone de réaction ou de congestion.';
    case _AnnotationTool.pen:
      return 'Dessine librement pour entourer ou commenter.';
    case _AnnotationTool.upArrow:
      return 'Pose un repère haussier sur la zone visée.';
    case _AnnotationTool.downArrow:
      return 'Pose un repère baissier sur la zone surveillée.';
  }
}

String _formatAnnotationDateLabel(DateTime time, ChartInterval interval) {
  final day = time.day.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  if (interval.isIntraday) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
  if (interval == ChartInterval.fiveYears || interval == ChartInterval.max) {
    return '${time.year}';
  }
  return '$day/$month';
}

String _formatAnnotationPrice(double value) {
  if (value.abs() >= 1000) return value.toStringAsFixed(0);
  if (value.abs() >= 100) return value.toStringAsFixed(2);
  return value.toStringAsFixed(3);
}

class _ChartAnnotationEditor extends StatefulWidget {
  const _ChartAnnotationEditor({required this.attachment});

  final _ForumTickerAttachment attachment;

  @override
  State<_ChartAnnotationEditor> createState() => _ChartAnnotationEditorState();
}

class _ChartAnnotationEditorState extends State<_ChartAnnotationEditor> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_AnnotationStroke> _strokes = <_AnnotationStroke>[];
  final List<_AnnotationStroke> _redoStrokes = <_AnnotationStroke>[];
  late Future<_MiniTickerSnapshot?> _snapshotFuture;
  _AnnotationTool _tool = _AnnotationTool.trendLine;
  _AnnotationInteractionMode _interactionMode = _AnnotationInteractionMode.draw;
  ChartInterval _interval = ChartInterval.oneMonth;
  Color _color = detailsColor2;
  bool _exporting = false;
  int _strokeRevision = 0;

  // Zoom / pan state
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _baseFocalPoint = Offset.zero;

  static const _tools = [
    (_AnnotationTool.trendLine, Icons.show_chart_rounded, 'Tendance'),
    (_AnnotationTool.hLine, Icons.horizontal_rule_rounded, 'Support/Rés.'),
    (_AnnotationTool.zone, Icons.crop_square_rounded, 'Zone'),
    (_AnnotationTool.pen, Icons.draw_rounded, 'Libre'),
    (_AnnotationTool.upArrow, Icons.arrow_upward_rounded, 'Haussier'),
    (_AnnotationTool.downArrow, Icons.arrow_downward_rounded, 'Baissier'),
  ];

  static const _colors = [
    detailsColor2,
    Color(0xFF13804A),
    Color(0xFFB4533B),
    Color(0xFF1565C0),
  ];

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_MiniTickerSnapshot?> _loadSnapshot() {
    return _MiniTickerSnapshot.load(widget.attachment, interval: _interval);
  }

  Offset _toCanvas(Offset screen) => (screen - _offset) / _scale;

  Offset _normalizeCanvasPoint(Offset canvasPoint, Size size) {
    final rect = _annotationPlotRect(size);
    final dx = math.max(
      0.0,
      math.min(1.0, (canvasPoint.dx - rect.left) / rect.width),
    );
    final dy = math.max(
      0.0,
      math.min(1.0, (canvasPoint.dy - rect.top) / rect.height),
    );
    return Offset(dx, dy);
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  void _setInterval(ChartInterval interval) {
    if (_interval == interval) return;
    setState(() {
      _interval = interval;
      _snapshotFuture = _loadSnapshot();
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redoStrokes.add(_strokes.removeLast());
      _strokeRevision++;
    });
  }

  void _redo() {
    if (_redoStrokes.isEmpty) return;
    setState(() {
      _strokes.add(_redoStrokes.removeLast());
      _strokeRevision++;
    });
  }

  void _clearAnnotations() {
    if (_strokes.isEmpty && _redoStrokes.isEmpty) return;
    setState(() {
      _strokes.clear();
      _redoStrokes.clear();
      _strokeRevision++;
    });
  }

  bool _shouldDiscardStroke(_AnnotationStroke stroke) {
    if (stroke.points.isEmpty) return true;
    if (stroke.tool == _AnnotationTool.pen) return stroke.points.length < 2;
    if (stroke.tool == _AnnotationTool.trendLine ||
        stroke.tool == _AnnotationTool.zone) {
      if (stroke.points.length < 2) return true;
      return (stroke.points.first - stroke.points.last).distance < 0.02;
    }
    return false;
  }

  void _onScaleStart(ScaleStartDetails details, Size size) {
    final navigating =
        _interactionMode == _AnnotationInteractionMode.navigate ||
        details.pointerCount >= 2;
    if (navigating) {
      _baseFocalPoint = details.localFocalPoint;
      _baseScale = _scale;
      _baseOffset = _offset;
      return;
    }

    final stroke = _AnnotationStroke(tool: _tool, color: _color);
    stroke.points.add(
      _normalizeCanvasPoint(_toCanvas(details.localFocalPoint), size),
    );
    setState(() {
      _redoStrokes.clear();
      _strokes.add(stroke);
      _strokeRevision++;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final navigating =
        _interactionMode == _AnnotationInteractionMode.navigate ||
        details.pointerCount >= 2;
    if (navigating) {
      setState(() {
        _scale = (_baseScale * details.scale).clamp(1.0, 5.0);
        _offset = _baseOffset + (details.localFocalPoint - _baseFocalPoint);
      });
      return;
    }

    if (_strokes.isEmpty) return;
    final point = _normalizeCanvasPoint(
      _toCanvas(details.localFocalPoint),
      size,
    );
    final stroke = _strokes.last;
    setState(() {
      if (stroke.tool == _AnnotationTool.pen) {
        stroke.points.add(point);
      } else if (stroke.tool == _AnnotationTool.trendLine ||
          stroke.tool == _AnnotationTool.zone) {
        if (stroke.points.length == 1) {
          stroke.points.add(point);
        } else {
          stroke.points[1] = point;
        }
      } else {
        stroke.points
          ..clear()
          ..add(point);
      }
      _strokeRevision++;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_strokes.isEmpty) return;
    final stroke = _strokes.last;
    if (_shouldDiscardStroke(stroke)) {
      setState(() {
        _strokes.removeLast();
        _strokeRevision++;
      });
    }
  }

  Future<void> _export() async {
    debugPrint('[Forum] _export called');
    setState(() => _exporting = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      debugPrint(
        '[Forum] boundary=$boundary repaintKey=${_repaintKey.currentContext}',
      );
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
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export impossible : $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: detailsColor1),
          SizedBox(height: 14),
          Text(
            'Chargement du graphique...',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: Color(0xFFB4533B),
            size: 36,
          ),
          const SizedBox(height: 14),
          const Text(
            'Impossible de charger le graphique pour le moment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Réessaie ou change d’horizon pour relancer la vue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _snapshotFuture = _loadSnapshot()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recharger'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace(_MiniTickerSnapshot payload) {
    return RepaintBoundary(
      key: _repaintKey,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                            Text(
                              widget.attachment.symbol,
                              style: const TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.attachment.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _AnnotationHeaderBadge(
                            label: _interval.shortLabel,
                            icon: Icons.timeline_rounded,
                            color: detailsColor2,
                          ),
                          if (_scale > 1.0) ...[
                            const SizedBox(height: 8),
                            _AnnotationHeaderBadge(
                              label: '${_scale.toStringAsFixed(1)}x',
                              icon: Icons.zoom_in_rounded,
                              color: const Color(0xFF175D94),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AnnotationInfoChip(
                        icon: Icons.show_chart_rounded,
                        label: payload.priceLabel,
                      ),
                      _AnnotationInfoChip(
                        icon:
                            payload.positive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                        label: payload.changeLabel,
                        color:
                            payload.positive
                                ? const Color(0xFF13804A)
                                : const Color(0xFFB4533B),
                      ),
                      _AnnotationInfoChip(
                        icon: Icons.public_rounded,
                        label: payload.marketLabel,
                        color: const Color(0xFF175D94),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: GestureDetector(
                        onScaleStart: (details) => _onScaleStart(details, size),
                        onScaleUpdate:
                            (details) => _onScaleUpdate(details, size),
                        onScaleEnd: _onScaleEnd,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF7FAFD), Color(0xFFFFFFFF)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Transform(
                                transform: Matrix4.translationValues(
                                  _offset.dx,
                                  _offset.dy,
                                  0,
                                )..scaleByDouble(_scale, _scale, 1.0, 1.0),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(
                                      painter: _AnnotationChartPainter(
                                        snapshot: payload,
                                        interval: _interval,
                                      ),
                                    ),
                                    CustomPaint(
                                      painter: _AnnotationPainter(
                                        strokes: _strokes,
                                        revision: _strokeRevision,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 10,
                                left: 10,
                                child: _AnnotationHeaderBadge(
                                  label:
                                      _interactionMode ==
                                              _AnnotationInteractionMode.draw
                                          ? 'Mode dessin'
                                          : 'Mode navigation',
                                  icon:
                                      _interactionMode ==
                                              _AnnotationInteractionMode.draw
                                          ? Icons.edit_rounded
                                          : Icons.pan_tool_alt_rounded,
                                  color:
                                      _interactionMode ==
                                              _AnnotationInteractionMode.draw
                                          ? detailsColor2
                                          : const Color(0xFF175D94),
                                  filled: true,
                                ),
                              ),
                              if (_strokes.isEmpty)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: _AnnotationEmptyStateCard(
                                        title: _annotationToolLabel(_tool),
                                        message: _annotationToolHint(_tool),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MiniTickerSnapshot?>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
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
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Atelier d’annotation',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.attachment.symbol} · ${_annotationToolHint(_tool)}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6E8EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: detailsColor2.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _interactionMode == _AnnotationInteractionMode.draw
                                ? Icons.edit_rounded
                                : Icons.pan_tool_alt_rounded,
                            color: detailsColor2,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _interactionMode == _AnnotationInteractionMode.draw
                                ? '1 doigt pour annoter, 2 doigts pour zoomer. Utilise "Naviguer" si tu veux déplacer la vue au doigt.'
                                : '1 doigt pour déplacer, pince pour zoomer. Reviens en mode dessin dès que la vue est calée.',
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                        payload != null
                            ? _buildWorkspace(payload)
                            : loading
                            ? _buildLoadingState()
                            : _buildErrorState(),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          ChartInterval.values.map((interval) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _AnnotationActionChip(
                                icon: Icons.timeline_rounded,
                                label: interval.shortLabel,
                                selected: _interval == interval,
                                onTap: () => _setInterval(interval),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _AnnotationActionChip(
                          icon: Icons.edit_rounded,
                          label: 'Dessiner',
                          selected:
                              _interactionMode ==
                              _AnnotationInteractionMode.draw,
                          onTap:
                              () => setState(
                                () =>
                                    _interactionMode =
                                        _AnnotationInteractionMode.draw,
                              ),
                        ),
                        const SizedBox(width: 8),
                        _AnnotationActionChip(
                          icon: Icons.pan_tool_alt_rounded,
                          label: 'Naviguer',
                          selected:
                              _interactionMode ==
                              _AnnotationInteractionMode.navigate,
                          onTap:
                              () => setState(
                                () =>
                                    _interactionMode =
                                        _AnnotationInteractionMode.navigate,
                              ),
                        ),
                        const SizedBox(width: 8),
                        _AnnotationActionChip(
                          icon: Icons.undo_rounded,
                          label: 'Annuler',
                          enabled: _strokes.isNotEmpty,
                          onTap: _undo,
                        ),
                        const SizedBox(width: 8),
                        _AnnotationActionChip(
                          icon: Icons.redo_rounded,
                          label: 'Refaire',
                          enabled: _redoStrokes.isNotEmpty,
                          onTap: _redo,
                        ),
                        const SizedBox(width: 8),
                        _AnnotationActionChip(
                          icon: Icons.zoom_out_map_rounded,
                          label: 'Vue',
                          onTap: _resetView,
                        ),
                        const SizedBox(width: 8),
                        _AnnotationActionChip(
                          icon: Icons.layers_clear_rounded,
                          label: 'Effacer',
                          enabled:
                              _strokes.isNotEmpty || _redoStrokes.isNotEmpty,
                          onTap: _clearAnnotations,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          _tools.map((tool) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _AnnotationToolButton(
                                icon: tool.$2,
                                label: tool.$3,
                                selected: _tool == tool.$1,
                                onTap: () => setState(() => _tool = tool.$1),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Couleur',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                              _colors.map((color) {
                                return _AnnotationColorSwatch(
                                  color: color,
                                  selected: _color == color,
                                  onTap: () => setState(() => _color = color),
                                );
                              }).toList(),
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
                      onPressed: _exporting || payload == null ? null : _export,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon:
                          _exporting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check_rounded),
                      label: Text(
                        _exporting
                            ? 'Export en cours...'
                            : 'Valider l’annotation',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({required this.strokes, required this.revision});

  final List<_AnnotationStroke> strokes;
  final int revision;

  Offset _resolvePoint(Offset normalized, Rect rect) {
    return Offset(
      rect.left + (normalized.dx * rect.width),
      rect.top + (normalized.dy * rect.height),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = _annotationPlotRect(size);
    for (final stroke in strokes) {
      final paint =
          Paint()
            ..color = stroke.color
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;

      final pts = stroke.points;
      if (pts.isEmpty) continue;

      switch (stroke.tool) {
        case _AnnotationTool.trendLine:
          if (pts.length < 2) break;
          final start = _resolvePoint(pts.first, plotRect);
          final end = _resolvePoint(pts.last, plotRect);
          canvas.drawLine(start, end, paint);
          canvas.drawCircle(
            start,
            4,
            Paint()..color = stroke.color.withValues(alpha: 0.18),
          );
          canvas.drawCircle(
            end,
            4,
            Paint()..color = stroke.color.withValues(alpha: 0.18),
          );
        case _AnnotationTool.hLine:
          final y = _resolvePoint(pts.last, plotRect).dy;
          canvas.drawLine(
            Offset(plotRect.left, y),
            Offset(plotRect.right, y),
            paint..strokeWidth = 1.9,
          );
        case _AnnotationTool.zone:
          if (pts.length < 2) break;
          final rect = Rect.fromPoints(
            _resolvePoint(pts.first, plotRect),
            _resolvePoint(pts.last, plotRect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(12)),
            Paint()..color = stroke.color.withValues(alpha: 0.12),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(12)),
            paint..strokeWidth = 1.9,
          );
        case _AnnotationTool.pen:
          if (pts.length < 2) break;
          final first = _resolvePoint(pts.first, plotRect);
          final path = Path()..moveTo(first.dx, first.dy);
          for (var i = 1; i < pts.length; i++) {
            final point = _resolvePoint(pts[i], plotRect);
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, paint);
        case _AnnotationTool.upArrow:
          final center = _resolvePoint(pts.last, plotRect);
          _drawArrow(canvas, center, true, stroke.color);
        case _AnnotationTool.downArrow:
          final center = _resolvePoint(pts.last, plotRect);
          _drawArrow(canvas, center, false, stroke.color);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset center, bool up, Color color) {
    final dir = up ? -1.0 : 1.0;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = color.withValues(alpha: 0.22);
    final tip = Offset(center.dx, center.dy - dir * 22);
    final left = Offset(center.dx - 12, center.dy + dir * 8);
    final right = Offset(center.dx + 12, center.dy + dir * 8);
    final path =
        Path()
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
      oldDelegate.revision != revision;
}

class _AnnotationChartPainter extends CustomPainter {
  const _AnnotationChartPainter({
    required this.snapshot,
    required this.interval,
  });

  final _MiniTickerSnapshot snapshot;
  final ChartInterval interval;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = _annotationPlotRect(size);
    final framePaint =
        Paint()
          ..color = const Color(0xFFDDE4EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(plotRect, const Radius.circular(18)),
      framePaint,
    );

    final gridPaint =
        Paint()
          ..color = const Color(0xFFE7EDF3)
          ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = plotRect.top + ((plotRect.height / 3) * i);
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = plotRect.left + ((plotRect.width / 2) * i);
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
    }

    final points = snapshot.points;
    if (points.length < 2) {
      final painter = TextPainter(
        text: const TextSpan(
          text: 'Pas assez de données pour afficher la courbe.',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: plotRect.width - 24);
      painter.paint(
        canvas,
        Offset(
          plotRect.left + ((plotRect.width - painter.width) / 2),
          plotRect.top + ((plotRect.height - painter.height) / 2),
        ),
      );
      return;
    }

    var minValue = points.first.close;
    var maxValue = points.first.close;
    for (final point in points.skip(1)) {
      minValue = math.min(minValue, point.close);
      maxValue = math.max(maxValue, point.close);
    }
    final delta =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;

    Offset pointToOffset(int index) {
      final x =
          plotRect.left + ((index / (points.length - 1)) * plotRect.width);
      final normalized = (points[index].close - minValue) / delta;
      final y = plotRect.bottom - (normalized * plotRect.height);
      return Offset(x, y);
    }

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final point = pointToOffset(i);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }
    final fillPath =
        Path.from(linePath)
          ..lineTo(plotRect.right, plotRect.bottom)
          ..lineTo(plotRect.left, plotRect.bottom)
          ..close();

    final chartColor =
        snapshot.positive ? const Color(0xFF177A53) : const Color(0xFF9A2D2D);
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            chartColor.withValues(alpha: 0.18),
            chartColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(plotRect),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = chartColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    final lastPoint = pointToOffset(points.length - 1);
    canvas.drawCircle(
      lastPoint,
      9,
      Paint()..color = chartColor.withValues(alpha: 0.14),
    );
    canvas.drawCircle(lastPoint, 4.2, Paint()..color = chartColor);

    void paintLabel(
      String text,
      Offset anchor, {
      bool alignRight = false,
      Color color = Colors.black54,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(alignRight ? anchor.dx - painter.width : anchor.dx, anchor.dy),
      );
    }

    paintLabel(
      _formatAnnotationPrice(maxValue),
      Offset(plotRect.right, plotRect.top - 14),
      alignRight: true,
    );
    paintLabel(
      _formatAnnotationPrice(minValue),
      Offset(plotRect.right, plotRect.bottom + 6),
      alignRight: true,
    );
    paintLabel(
      _formatAnnotationDateLabel(points.first.time, interval),
      Offset(plotRect.left, plotRect.bottom + 6),
    );
    paintLabel(
      _formatAnnotationDateLabel(points.last.time, interval),
      Offset(plotRect.right, plotRect.bottom + 6),
      alignRight: true,
    );
  }

  @override
  bool shouldRepaint(covariant _AnnotationChartPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot || oldDelegate.interval != interval;
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color:
              selected ? detailsColor2.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected
                    ? detailsColor2.withValues(alpha: 0.30)
                    : const Color(0xFFE6E8EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? detailsColor2 : textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
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

class _AnnotationActionChip extends StatelessWidget {
  const _AnnotationActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground =
        !enabled
            ? Colors.black38
            : selected
            ? detailsColor2
            : textColor;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected ? detailsColor2.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected
                      ? detailsColor2.withValues(alpha: 0.28)
                      : const Color(0xFFE6E8EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnotationColorSwatch extends StatelessWidget {
  const _AnnotationColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
      ),
    );
  }
}

class _AnnotationHeaderBadge extends StatelessWidget {
  const _AnnotationHeaderBadge({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background =
        filled
            ? Colors.black.withValues(alpha: 0.64)
            : color.withValues(alpha: 0.10);
    final foreground = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationInfoChip extends StatelessWidget {
  const _AnnotationInfoChip({
    required this.icon,
    required this.label,
    this.color = textColor,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationEmptyStateCard extends StatelessWidget {
  const _AnnotationEmptyStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.draw_rounded, color: detailsColor2, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
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
  const _NotificationsSheet({required this.uid, required this.onOpenPost});
  final String uid;
  final ValueChanged<String> onOpenPost;

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
                  Icon(
                    Icons.notifications_rounded,
                    size: 20,
                    color: detailsColor2,
                  ),
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
                          style: TextStyle(color: Colors.black45, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final isRead = d['read'] as bool? ?? true;
                      final fromName = d['fromName'] as String? ?? 'Quelqu\'un';
                      final type = d['type'] as String? ?? '';
                      final postId = (d['postId'] as String?)?.trim() ?? '';
                      final score = (d['score'] as String?)?.trim() ?? '';
                      final ts = d['createdAt'] as Timestamp?;
                      String ago = '';
                      if (ts != null) {
                        final diff = DateTime.now().difference(ts.toDate());
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
                        onTap: postId.isEmpty ? null : () => onOpenPost(postId),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              isRead
                                  ? Colors.grey.shade200
                                  : detailsColor2.withValues(alpha: 0.15),
                          child: Text(
                            fromName.isNotEmpty
                                ? fromName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isRead ? Colors.black45 : detailsColor2,
                            ),
                          ),
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: textColor,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    type == 'vote_milestone'
                                        ? 'Le forum'
                                        : fromName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${_label(type)}${score.isEmpty ? '' : ' ($score)'}',
                              ),
                            ],
                          ),
                        ),
                        subtitle:
                            ago.isNotEmpty
                                ? Text(
                                  ago,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black45,
                                  ),
                                )
                                : null,
                        trailing:
                            isRead
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
