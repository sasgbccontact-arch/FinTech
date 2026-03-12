import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/models/chart_models.dart';
import 'package:fintech/services/yahoo_finance_service.dart';

const List<String> _forumPostTypes = <String>[
  'discussion',
  'question',
  'analyse',
  'alerte',
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

class ForumBoursierSheet extends StatefulWidget {
  const ForumBoursierSheet({super.key});

  @override
  State<ForumBoursierSheet> createState() => _ForumBoursierSheetState();
}

class _ForumBoursierSheetState extends State<ForumBoursierSheet> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  _ForumThemeLite? _selectedTheme;
  String _selectedPostType = _forumPostTypes.first;
  final Set<String> _selectedTags = <String>{};
  _ForumTickerAttachment? _attachedTicker;
  String _searchQuery = '';
  String? _activeTagFilter;
  bool _bookmarksOnly = false;
  bool _sortByTop = true;
  bool _sending = false;
  bool _canModerate = false;
  String? _expandedMessageId;

  @override
  void initState() {
    super.initState();
    _loadModeratorStatus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

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
    } catch (_) {
      // best effort
    }
  }

  Query<Map<String, dynamic>> _themesQuery() {
    return FirebaseFirestore.instance
        .collection('forum_themes')
        .orderBy('name');
  }

  Query<Map<String, dynamic>> _messagesQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'forum_chat_messages',
    );
    if (_sortByTop) {
      query = query
          .orderBy('score', descending: true)
          .orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    return query.limit(120);
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _createThemeDialog() async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour créer un thème.');
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    final ref = await FirebaseFirestore.instance.collection('forum_themes').add(
      {'name': name, 'createdAt': Timestamp.now(), 'createdByUid': user.uid},
    );
    if (!mounted) return;
    setState(() {
      _selectedTheme = _ForumThemeLite(id: ref.id, name: name);
    });
    _snack('Thème créé.');
  }

  Future<void> _pickTickerAttachment() async {
    final result = await showCupertinoModalBottomSheet<_ForumTickerAttachment>(
      context: context,
      expand: true,
      builder: (_) => const _TickerAttachmentSearchSheet(),
    );

    if (result == null || !mounted) return;
    setState(() => _attachedTicker = result);
  }

  Future<void> _sendMessage() async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour publier.');
      return;
    }
    if (_selectedTheme == null) {
      _snack('Choisis un thème.');
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('forum_chat_messages').add({
        'text': text,
        'uid': user.uid,
        'authorName': _authorName(user),
        'photoURL': user.photoURL,
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
        'attachment': _attachedTicker?.toMap(),
      });
      _textController.clear();
      if (!mounted) return;
      setState(() {
        _selectedTags.clear();
        _attachedTicker = null;
        _selectedPostType = _forumPostTypes.first;
      });
      _focusNode.requestFocus();
    } catch (e) {
      _snack('Impossible de publier: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendReply(_ForumMessage message, String text) async {
    final user = _user;
    if (user == null) {
      _snack('Connecte-toi pour répondre.');
      return;
    }
    final replyText = text.trim();
    if (replyText.isEmpty) return;

    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('forum_chat_messages')
          .doc(message.id)
          .collection('replies')
          .add({
            'text': replyText,
            'uid': user.uid,
            'authorName': _authorName(user),
            'photoURL': user.photoURL,
            'createdAt': now,
          });
      if (!mounted) return;
      setState(() => _expandedMessageId = message.id);
    } catch (e) {
      _snack('Impossible de répondre: $e');
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
      _snack('Vote impossible: $e');
    }
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
          if (reactionSnap.exists) {
            tx.delete(reactionRef);
          }
        } else {
          tx.set(reactionRef, {
            'key': next,
            'updatedAt': now,
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      _snack('Réaction impossible: $e');
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
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('forum_reports').add({
        'messageId': message.id,
        'messageUid': message.uid,
        'reportedByUid': user.uid,
        'reason': reason,
        'themeId': message.themeId,
        'themeName': message.themeName,
        'createdAt': now,
      });
      _snack('Signalement envoyé.');
    } catch (e) {
      _snack('Signalement impossible: $e');
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
      _snack('Modération impossible: $e');
    }
  }

  String _authorName(User user) {
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Utilisateur';
  }

  List<_ForumMessage> _applyFilters(
    List<_ForumMessage> messages,
    Set<String> bookmarkedIds,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered =
        messages.where((message) {
          if (_bookmarksOnly && !bookmarkedIds.contains(message.id)) {
            return false;
          }
          if (_activeTagFilter != null &&
              !message.tags.contains(_activeTagFilter)) {
            return false;
          }
          if (query.isEmpty) return true;
          final haystack =
              <String>[
                message.text,
                message.authorName,
                message.themeName,
                message.postTypeLabel,
                ...message.tags,
                if (message.attachment != null) ...[
                  message.attachment!.symbol,
                  message.attachment!.displayName,
                ],
              ].join(' ').toLowerCase();
          return haystack.contains(query);
        }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (_sortByTop && a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return filtered;
  }

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
                  Widget messagesSection;

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    messagesSection = const SizedBox(
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator(color: detailsColor1),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    messagesSection = Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger le forum.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textColor),
                      ),
                    );
                  } else {
                    final messages =
                        (snapshot.data?.docs ?? const [])
                            .map(_ForumMessage.fromDoc)
                            .toList();
                    final filtered = _applyFilters(messages, bookmarkedIds);

                    if (filtered.isEmpty) {
                      messagesSection = const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun message ne correspond à ce filtre.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor),
                        ),
                      );
                    } else {
                      messagesSection = Column(
                        children: [
                          for (var index = 0; index < filtered.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == filtered.length - 1 ? 0 : 12,
                              ),
                              child: _ForumMessageCard(
                                message: filtered[index],
                                canModerate: _canModerate,
                                canReport:
                                    _user != null &&
                                    _user.uid != filtered[index].uid,
                                isBookmarked: bookmarkedIds.contains(
                                  filtered[index].id,
                                ),
                                isExpanded:
                                    _expandedMessageId == filtered[index].id,
                                onToggleExpanded:
                                    () => setState(
                                      () =>
                                          _expandedMessageId =
                                              _expandedMessageId ==
                                                      filtered[index].id
                                                  ? null
                                                  : filtered[index].id,
                                    ),
                                onBookmark:
                                    () => _toggleBookmark(filtered[index]),
                                onVoteUp:
                                    () => _voteMessage(
                                      message: filtered[index],
                                      value: 1,
                                    ),
                                onVoteDown:
                                    () => _voteMessage(
                                      message: filtered[index],
                                      value: -1,
                                    ),
                                onReact:
                                    (reactionKey) => _reactToMessage(
                                      message: filtered[index],
                                      reactionKey: reactionKey,
                                    ),
                                onReport: () => _reportMessage(filtered[index]),
                                onTogglePinned:
                                    () => _togglePinned(filtered[index]),
                                replies:
                                    _expandedMessageId == filtered[index].id
                                        ? _ForumRepliesSection(
                                          message: filtered[index],
                                          currentUser: _user,
                                          onSendReply:
                                              (text) => _sendReply(
                                                filtered[index],
                                                text,
                                              ),
                                        )
                                        : null,
                              ),
                            ),
                        ],
                      );
                    }
                  }

                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _ForumComposerCard(
                          textController: _textController,
                          focusNode: _focusNode,
                          sending: _sending,
                          selectedPostType: _selectedPostType,
                          onPostTypeChanged:
                              (value) =>
                                  setState(() => _selectedPostType = value),
                          selectedTags: _selectedTags,
                          onToggleTag: (tag) {
                            setState(() {
                              if (_selectedTags.contains(tag)) {
                                _selectedTags.remove(tag);
                              } else if (_selectedTags.length < 4) {
                                _selectedTags.add(tag);
                              }
                            });
                          },
                          attachment: _attachedTicker,
                          onRemoveAttachment:
                              () => setState(() => _attachedTicker = null),
                          onAttachTicker: _pickTickerAttachment,
                          onCreateTheme: _createThemeDialog,
                          onSend: _sendMessage,
                          user: _user,
                          selectedTheme: _selectedTheme,
                          onThemeChanged:
                              (theme) => setState(() => _selectedTheme = theme),
                          themesQuery: _themesQuery(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _ForumSearchBar(
                          controller: _searchController,
                          bookmarksOnly: _bookmarksOnly,
                          sortByTop: _sortByTop,
                          activeTagFilter: _activeTagFilter,
                          onChanged:
                              (value) =>
                                  setState(() => _searchQuery = value.trim()),
                          onToggleBookmarks:
                              () => setState(
                                () => _bookmarksOnly = !_bookmarksOnly,
                              ),
                          onToggleSort:
                              () => setState(() => _sortByTop = !_sortByTop),
                          onClearTagFilter:
                              () => setState(() => _activeTagFilter = null),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _forumTagOptions.map((tag) {
                                  final selected = _activeTagFilter == tag;
                                  return FilterChip(
                                    label: Text(tag),
                                    selected: selected,
                                    onSelected:
                                        (_) => setState(
                                          () =>
                                              _activeTagFilter =
                                                  selected ? null : tag,
                                        ),
                                    selectedColor: detailsColor1.withValues(
                                      alpha: 0.16,
                                    ),
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color:
                                          selected ? detailsColor2 : textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    side: BorderSide(
                                      color:
                                          selected
                                              ? detailsColor2.withValues(
                                                alpha: 0.18,
                                              )
                                              : const Color(0xFFE6E8EB),
                                    ),
                                    showCheckmark: false,
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: messagesSection,
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
      name:
          (data['name'] as String?)?.trim().isNotEmpty == true
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

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'displayName': displayName,
      'exchange': exchange,
      'currency': currency,
      'quoteType': quoteType,
    };
  }

  factory _ForumTickerAttachment.fromMap(Map<String, dynamic> data) {
    return _ForumTickerAttachment(
      symbol: (data['symbol'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      exchange: (data['exchange'] as String?) ?? '',
      currency: (data['currency'] as String?) ?? '',
      quoteType: (data['quoteType'] as String?) ?? '',
    );
  }

  factory _ForumTickerAttachment.fromSearchResult(TickerSearchResult result) {
    return _ForumTickerAttachment(
      symbol: result.symbol,
      displayName: result.displayName,
      exchange: result.exchange,
      currency: result.currency,
      quoteType: result.quoteType,
    );
  }
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
    required this.attachment,
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
  final _ForumTickerAttachment? attachment;
  final Timestamp? createdAt;

  String get postTypeLabel {
    switch (postType) {
      case 'question':
        return 'Question';
      case 'analyse':
        return 'Analyse';
      case 'alerte':
        return 'Alerte';
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
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(),
      attachment:
          data['attachment'] is Map<String, dynamic>
              ? _ForumTickerAttachment.fromMap(
                data['attachment'] as Map<String, dynamic>,
              )
              : null,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

class _ForumComposerCard extends StatelessWidget {
  const _ForumComposerCard({
    required this.textController,
    required this.focusNode,
    required this.sending,
    required this.selectedPostType,
    required this.onPostTypeChanged,
    required this.selectedTags,
    required this.onToggleTag,
    required this.attachment,
    required this.onRemoveAttachment,
    required this.onAttachTicker,
    required this.onCreateTheme,
    required this.onSend,
    required this.user,
    required this.selectedTheme,
    required this.onThemeChanged,
    required this.themesQuery,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final bool sending;
  final String selectedPostType;
  final ValueChanged<String> onPostTypeChanged;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggleTag;
  final _ForumTickerAttachment? attachment;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onAttachTicker;
  final VoidCallback onCreateTheme;
  final VoidCallback onSend;
  final User? user;
  final _ForumThemeLite? selectedTheme;
  final ValueChanged<_ForumThemeLite?> onThemeChanged;
  final Query<Map<String, dynamic>> themesQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Composer un post',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choisis un type, ajoute des tags utiles et embarque un ticker avec sa mini-courbe.',
            style: TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: themesQuery.snapshots(),
                  builder: (context, snapshot) {
                    final themes =
                        (snapshot.data?.docs ?? const [])
                            .map(_ForumThemeLite.fromDoc)
                            .toList();
                    _ForumThemeLite? resolvedTheme = selectedTheme;
                    final selectedThemeId = resolvedTheme?.id;
                    if (selectedThemeId != null) {
                      for (final theme in themes) {
                        if (theme.id == selectedThemeId) {
                          resolvedTheme = theme;
                          break;
                        }
                      }
                    }
                    return _WhiteInputBox(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_ForumThemeLite>(
                          value: resolvedTheme,
                          isExpanded: true,
                          hint: const Text('Choisir un thème'),
                          items:
                              themes
                                  .map(
                                    (theme) =>
                                        DropdownMenuItem<_ForumThemeLite>(
                                          value: theme,
                                          child: Text(
                                            theme.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                  )
                                  .toList(),
                          onChanged: onThemeChanged,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _SquareActionButton(
                icon: Icons.add_rounded,
                onTap: onCreateTheme,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WhiteInputBox(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPostType,
                isExpanded: true,
                items:
                    _forumPostTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(_postTypeLabel(type)),
                          ),
                        )
                        .toList(),
                onChanged:
                    (value) => value == null ? null : onPostTypeChanged(value),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _forumTagOptions.map((tag) {
                  final selected = selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) => onToggleTag(tag),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAttachTicker,
                  icon: const Icon(Icons.show_chart_rounded),
                  label: Text(
                    attachment == null
                        ? 'Attacher un ticker'
                        : 'Ticker attaché',
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
              ),
            ],
          ),
          if (attachment != null) ...[
            const SizedBox(height: 12),
            _ForumTickerAttachmentPreview(
              attachment: attachment!,
              compact: true,
              onRemove: onRemoveAttachment,
            ),
          ],
          const SizedBox(height: 12),
          _WhiteInputBox(
            child: TextField(
              controller: textController,
              focusNode: focusNode,
              enabled: user != null && !sending,
              onTapOutside:
                  (_) => FocusManager.instance.primaryFocus?.unfocus(),
              minLines: 3,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: user == null || sending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon:
                  sending
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.send_rounded),
              label: Text(sending ? 'Publication...' : 'Publier'),
            ),
          ),
        ],
      ),
    );
  }
}

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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

class _ForumMessageCard extends StatelessWidget {
  const _ForumMessageCard({
    required this.message,
    required this.canModerate,
    required this.canReport,
    required this.isBookmarked,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onBookmark,
    required this.onVoteUp,
    required this.onVoteDown,
    required this.onReact,
    required this.onReport,
    required this.onTogglePinned,
    required this.replies,
  });

  final _ForumMessage message;
  final bool canModerate;
  final bool canReport;
  final bool isBookmarked;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onBookmark;
  final VoidCallback onVoteUp;
  final VoidCallback onVoteDown;
  final ValueChanged<String> onReact;
  final VoidCallback onReport;
  final VoidCallback onTogglePinned;
  final Widget? replies;

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
                child: Center(
                  child: Text(
                    _initials(message.authorName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.authorName,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (message.isPinned)
                          const _PostBadge(label: 'Épinglé'),
                        _PostBadge(label: message.postTypeLabel),
                        _PostBadge(label: message.themeName, alternate: true),
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
                  if (canModerate || canReport)
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      color: Colors.white,
                      onSelected: (value) {
                        if (value == 'pin') onTogglePinned();
                        if (value == 'report') onReport();
                      },
                      itemBuilder: (_) {
                        final items = <PopupMenuEntry<String>>[];
                        if (canModerate) {
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
          if (message.attachment != null) ...[
            const SizedBox(height: 12),
            _ForumTickerAttachmentPreview(attachment: message.attachment!),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              final replies =
                  (snapshot.data?.docs ?? const [])
                      .map((doc) => doc.data())
                      .toList();

              return Column(
                children: [
                  if (replies.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Aucune réponse pour le moment.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    for (final reply in replies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReplyBubble(
                          authorName:
                              (reply['authorName'] as String?) ?? 'Utilisateur',
                          text: (reply['text'] as String?) ?? '',
                        ),
                      ),
                  _WhiteInputBox(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.currentUser != null && !_sending,
                      onTapOutside:
                          (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Répondre à ce message...',
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
                                setState(() => _sending = false);
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
  }
}

class _MiniTickerChart extends StatelessWidget {
  const _MiniTickerChart({required this.attachment});

  final _ForumTickerAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MiniTickerSnapshot?>(
      future: _MiniTickerSnapshot.load(attachment),
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
                          child: CustomPaint(
                            painter: _MiniChartPainter(
                              points:
                                  payload.points
                                      .map((point) => point.close)
                                      .toList(),
                              color:
                                  payload.positive
                                      ? const Color(0xFF177A53)
                                      : const Color(0xFF9A2D2D),
                            ),
                          ),
                        ),
              ),
            ],
          ),
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
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
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
    _ForumTickerAttachment attachment,
  ) async {
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
        ChartInterval.sevenDays,
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

    if (marketPrice == null && points.isEmpty) {
      return null;
    }

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

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({required this.authorName, required this.text});

  final String authorName;
  final String text;

  @override
  Widget build(BuildContext context) {
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
          Text(
            authorName,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: textColor, height: 1.35)),
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
      onTap: onTap,
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
        onTap: onTap,
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
      onTap: onTap,
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
        onTap: onTap,
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
    case 'discussion':
    default:
      return 'Discussion';
  }
}
