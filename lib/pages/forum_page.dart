import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintech/core/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';



@immutable
class ForumTheme {
  const ForumTheme({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other is ForumTheme && other.id == id);
  }

  @override
  int get hashCode => id.hashCode;

  static ForumTheme fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data['name'] as String?)?.trim();
    return ForumTheme(
      id: doc.id,
      name: (name == null || name.isEmpty) ? 'Sans nom' : name,
    );
  }
}

@immutable
class ForumMessage {
  const ForumMessage({
    required this.id,
    required this.text,
    required this.uid,
    required this.authorName,
    required this.photoURL,
    required this.themeId,
    required this.themeName,
    required this.upVotes,
    required this.downVotes,
    required this.score,
    required this.createdAt,
    required this.lastVoteAt,
  });

  final String id;
  final String text;
  final String uid;
  final String authorName;
  final String? photoURL;

  final String themeId;
  final String themeName;

  final int upVotes;
  final int downVotes;
  final int score;

  final Timestamp? createdAt;
  final Timestamp? lastVoteAt;

  static ForumMessage fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final createdAtRaw = data['createdAt'];
    final lastVoteAtRaw = data['lastVoteAt'];

    final upVotes = (data['upVotes'] as int?) ?? 0;
    final downVotes = (data['downVotes'] as int?) ?? 0;

    String safeName(String? s) {
      final t = (s ?? '').trim();
      return t.isEmpty ? 'Utilisateur' : t;
    }

    String safeTheme(String? s) {
      final t = (s ?? '').trim();
      return t.isEmpty ? 'Thème' : t;
    }

    return ForumMessage(
      id: doc.id,
      text: (data['text'] as String?) ?? '',
      uid: (data['uid'] as String?) ?? '',
      authorName: safeName(data['authorName'] as String?),
      photoURL: (data['photoURL'] as String?),
      themeId: (data['themeId'] as String?) ?? '',
      themeName: safeTheme(data['themeName'] as String?),
      upVotes: upVotes,
      downVotes: downVotes,
      score: (data['score'] as int?) ?? (upVotes - downVotes),
      createdAt: createdAtRaw is Timestamp ? createdAtRaw : null,
      lastVoteAt: lastVoteAtRaw is Timestamp ? lastVoteAtRaw : null,
    );
  }

  static Map<String, dynamic> toCreateMap({
    required User user,
    required String text,
    required ForumTheme theme,
  }) {
    final safeText = text.trim();

    String safeAuthorName() {
      final dn = (user.displayName ?? '').trim();
      if (dn.isNotEmpty) return dn;
      final email = (user.email ?? '').trim();
      if (email.isNotEmpty) return email.split('@').first;
      return 'Utilisateur';
    }

    return <String, dynamic>{
      'text': safeText,
      'uid': user.uid,
      'authorName': safeAuthorName(),
      'photoURL': user.photoURL,
      'themeId': theme.id,
      'themeName': theme.name,
      // agrégats client-driven
      'upVotes': 0,
      'downVotes': 0,
      'score': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastVoteAt': FieldValue.serverTimestamp(), // utile pour cleanup même sans votes
    };
  }
}

/// Forum minimaliste en temps réel sur Firestore.
/// - Thèmes: forum_themes
/// - Messages: forum_chat_messages
/// - Votes: forum_chat_messages/{id}/votes/{uid}
/// - Cleanup client-driven à l’ouverture via forum_meta/housekeeping (lease)
class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  static const String messagesCollection = 'forum_chat_messages';
  static const String themesCollection = 'forum_themes';

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  ForumTheme? _selectedThemeToPost;
  String? _selectedThemeFilterId; // null = all
  bool _sortByTop = false;

  bool _sending = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // --- Cleanup (client-driven) ---
  static const int _downvoteThreshold = 5;
  static const int _inactiveDays = 7;
  static const Duration _cleanupInterval = Duration(hours: 24);
  static const Duration _cleanupLease = Duration(minutes: 10);

  DocumentReference<Map<String, dynamic>> get _housekeepingRef =>
      FirebaseFirestore.instance.collection('forum_meta').doc('housekeeping');

  LinearGradient get _accentGradient => const LinearGradient(
        colors: [detailsColor1, detailsColor2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();

    // Auto-pin vers le bas si l’utilisateur est proche du bas
    _sub = _messagesQuery().snapshots().listen((_) {
      if (!_scrollController.hasClients) return;
      final atBottom = _scrollController.offset <= 120;
      if (atBottom) {
        scheduleMicrotask(() {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        });
      }
    });

    _maybeRunCleanup();

    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null) _maybeRunCleanup();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _themesQuery() {
    return FirebaseFirestore.instance
        .collection(ForumPage.themesCollection)
        .orderBy('name');
  }

  Query<Map<String, dynamic>> _messagesQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection(ForumPage.messagesCollection);

    if (_selectedThemeFilterId != null && _selectedThemeFilterId!.isNotEmpty) {
      q = q.where('themeId', isEqualTo: _selectedThemeFilterId);
    }

    if (_sortByTop) {
      q = q.orderBy('score', descending: true).orderBy('createdAt', descending: true);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }

    return q.limit(200);
  }

  Future<void> _createThemeDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Connecte-toi pour créer un thème.');
      return;
    }

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: const Text('Nouveau thème',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 40,
            style: const TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Nom du thème',
              hintStyle: TextStyle(color: textColor.withOpacity(0.55)),
              filled: true,
              fillColor: Colors.white,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler', style: TextStyle(color: textColor)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: _accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
                child: const Text('Créer', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );

    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    try {
      final ref = await FirebaseFirestore.instance
          .collection(ForumPage.themesCollection)
          .add(<String, dynamic>{
        'name': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': user.uid,
      });

      // 🔥 Important : sélection automatique => l’envoi devient possible direct
      setState(() {
        _selectedThemeToPost = ForumTheme(id: ref.id, name: trimmed);
        _selectedThemeFilterId = ref.id; // bascule l’affichage sur le thème créé
      });

      _snack('Thème \"$trimmed\" créé.');
    } on FirebaseException catch (e) {
      _snack('Erreur création thème: ${e.message ?? e.code}');
    } catch (e) {
      _snack('Erreur création thème: $e');
    }
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Connecte-toi pour envoyer un message.');
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    final theme = _selectedThemeToPost;
    if (theme == null) {
      _snack('Choisis un thème avant de publier.');
      return;
    }

    setState(() => _sending = true);

    try {
      _textController.clear();

      await FirebaseFirestore.instance
          .collection(ForumPage.messagesCollection)
          .add(ForumMessage.toCreateMap(user: user, text: text, theme: theme));

      _focusNode.requestFocus();

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } on FirebaseException catch (e) {
      _textController.text = text;
      _textController.selection =
          TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
      _snack('Impossible d’envoyer: ${e.message ?? e.code}');
    } catch (e) {
      _textController.text = text;
      _textController.selection =
          TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
      _snack('Impossible d’envoyer: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _voteMessage({required ForumMessage msg, required int value}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Connecte-toi pour voter.');
      return;
    }
    if (msg.uid == user.uid) {
      _snack('Tu ne peux pas voter pour ton propre message.');
      return;
    }

    final msgRef = FirebaseFirestore.instance
        .collection(ForumPage.messagesCollection)
        .doc(msg.id);
    final voteRef = msgRef.collection('votes').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final msgSnap = await tx.get(msgRef);
        if (!msgSnap.exists) return;

        final voteSnap = await tx.get(voteRef);
        final previous = voteSnap.exists ? ((voteSnap.data()?['value'] as int?) ?? 0) : 0;
        final next = (previous == value) ? 0 : value;

        int deltaUp = 0, deltaDown = 0, deltaScore = 0;

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

        tx.update(msgRef, <String, dynamic>{
          'upVotes': FieldValue.increment(deltaUp),
          'downVotes': FieldValue.increment(deltaDown),
          'score': FieldValue.increment(deltaScore),
          'lastVoteAt': FieldValue.serverTimestamp(),
        });

        if (next == 0) {
          if (voteSnap.exists) tx.delete(voteRef);
        } else {
          tx.set(
            voteRef,
            <String, dynamic>{
              'value': next,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });
    } on FirebaseException catch (e) {
      _snack('Vote impossible: ${e.message ?? e.code}');
    } catch (e) {
      _snack('Vote impossible: $e');
    }
  }

  Future<void> _maybeRunCleanup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();
    bool acquired = false;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_housekeepingRef);
        final data = snap.data() ?? <String, dynamic>{};

        DateTime? lastCleanupAt;
        DateTime? leaseUntil;

        final lca = data['lastCleanupAt'];
        if (lca is Timestamp) lastCleanupAt = lca.toDate().toUtc();

        final lu = data['leaseUntil'];
        if (lu is Timestamp) leaseUntil = lu.toDate().toUtc();

        final leaseExpired = (leaseUntil == null) || now.isAfter(leaseUntil);
        final due = (lastCleanupAt == null) || now.difference(lastCleanupAt) >= _cleanupInterval;

        if (!due) return;
        if (!leaseExpired) return;

        acquired = true;
        tx.set(
          _housekeepingRef,
          <String, dynamic>{
            'leaseOwnerUid': user.uid,
            'leaseUntil': Timestamp.fromDate(now.add(_cleanupLease)),
            'lastAttemptAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      });

      if (!acquired) return;

      await _runCleanup(now: now);

      await _housekeepingRef.set(
        <String, dynamic>{
          'lastCleanupAt': Timestamp.fromDate(now),
          'leaseOwnerUid': null,
          'leaseUntil': null,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best effort
    }
  }

  Future<void> _runCleanup({required DateTime now}) async {
    final cutoff = Timestamp.fromDate(now.subtract(Duration(days: _inactiveDays)));
    final messagesCol = FirebaseFirestore.instance.collection(ForumPage.messagesCollection);

    final tooDownvotedSnap = await messagesCol
        .where('downVotes', isGreaterThanOrEqualTo: _downvoteThreshold)
        .limit(200)
        .get();

    final inactiveSnap = await messagesCol
        .where('lastVoteAt', isLessThan: cutoff)
        .orderBy('lastVoteAt')
        .limit(200)
        .get();

    final Map<String, DocumentReference<Map<String, dynamic>>> toDelete = {};
    for (final d in tooDownvotedSnap.docs) {
      toDelete[d.id] = d.reference;
    }
    for (final d in inactiveSnap.docs) {
      toDelete[d.id] = d.reference;
    }

    if (toDelete.isEmpty) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int ops = 0;

    Future<void> commitIfNeeded() async {
      if (ops >= 400) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        ops = 0;
      }
    }

    for (final ref in toDelete.values) {
      final votesSnap = await ref.collection('votes').limit(250).get();
      for (final v in votesSnap.docs) {
        batch.delete(v.reference);
        ops += 1;
        await commitIfNeeded();
      }
      batch.delete(ref);
      ops += 1;
      await commitIfNeeded();
    }

    if (ops > 0) await batch.commit();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        elevation: 0,
        title: const Text('Forum',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          _Pill(
            gradient: _accentGradient,
            onTap: () => setState(() => _sortByTop = !_sortByTop),
            child: Row(
              children: [
                Icon(
                  _sortByTop ? Icons.local_fire_department_rounded : Icons.schedule_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _sortByTop ? 'Top' : 'Récent',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String?>(
            tooltip: 'Filtrer par thème',
            icon: const Icon(Icons.filter_list_rounded, color: textColor),
            onSelected: (v) => setState(() => _selectedThemeFilterId = v),
            itemBuilder: (context) {
              return <PopupMenuEntry<String?>>[
                PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Tous les thèmes')),
                      if (_selectedThemeFilterId == null)
                        const Icon(Icons.check_rounded),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String?>(
                  enabled: false,
                  child: SizedBox(
                    width: 280,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _themesQuery().snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Erreur thèmes: ${snap.error}'),
                          );
                        }
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final themes = snap.data!.docs.map(ForumTheme.fromDoc).toList();
                        if (themes.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Aucun thème. Crée-en un !'),
                          );
                        }
                        final height = (themes.length * 48.0).clamp(0.0, 320.0);
                        return SizedBox(
                          height: height,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (final t in themes)
                                ListTile(
                                  dense: true,
                                  title: Text(t.name),
                                  trailing: (_selectedThemeFilterId == t.id)
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () => Navigator.of(context).pop(t.id),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (user == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _InfoCard(
                  gradient: _accentGradient,
                  child: const Text(
                    'Tu peux lire le forum, mais il faut être connecté pour créer un thème, publier et voter.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Impossible de charger le forum.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: textColor),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Aucun message pour le moment.',
                          style: TextStyle(color: textColor)),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msg = ForumMessage.fromDoc(docs[index]);
                      final isMe = user != null && msg.uid == user.uid;

                      return _MessageCard(
                        gradient: _accentGradient,
                        author: msg.authorName,
                        initials: _initials(msg.authorName),
                        theme: msg.themeName,
                        timeLabel: _formatTimestamp(msg.createdAt),
                        text: msg.text,
                        score: msg.score,
                        upVotes: msg.upVotes,
                        downVotes: msg.downVotes,
                        onUp: isMe ? null : () => _voteMessage(msg: msg, value: 1),
                        onDown: isMe ? null : () => _voteMessage(msg: msg, value: -1),
                      );
                    },
                  );
                },
              ),
            ),

            // Sélection du thème + création
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _themesQuery().snapshots(),
                      builder: (context, snapshot) {
                        final themes =
                            snapshot.data?.docs.map(ForumTheme.fromDoc).toList() ??
                                const <ForumTheme>[];

                        ForumTheme? selected;
                        final current = _selectedThemeToPost;
                        if (current != null) {
                          for (final t in themes) {
                            if (t.id == current.id) {
                              selected = t;
                              break;
                            }
                          }
                        }

                        return _InputBox(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ForumTheme>(
                              value: selected,
                              hint: const Text('Choisir un thème…',
                                  style: TextStyle(color: textColor)),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: textColor),
                              items: themes
                                  .map((t) => DropdownMenuItem<ForumTheme>(
                                        value: t,
                                        child: Text(
                                          t.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: textColor),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedThemeToPost = v),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SquareGradientButton(
                    gradient: _accentGradient,
                    icon: Icons.add_rounded,
                    onTap: _createThemeDialog,
                  ),
                ],
              ),
            ),

            // Composer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _InputBox(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: user != null && _selectedThemeToPost != null && !_sending,
                        style: const TextStyle(color: textColor),
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: (user != null && _selectedThemeToPost != null)
                              ? 'Écris un message…'
                              : 'Choisis un thème + connecte-toi…',
                          hintStyle: TextStyle(color: textColor.withOpacity(0.55)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SquareGradientButton(
                    gradient: _accentGradient,
                    icon: _sending ? Icons.hourglass_top_rounded : Icons.send_rounded,
                    onTap: (user != null && _selectedThemeToPost != null && !_sending)
                        ? _sendMessage
                        : null,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.gradient, required this.child, required this.onTap});
  final LinearGradient gradient;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 5),
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.gradient, required this.child});
  final LinearGradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _SquareGradientButton extends StatelessWidget {
  const _SquareGradientButton({
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final LinearGradient gradient;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          width: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.gradient,
    required this.author,
    required this.initials,
    required this.theme,
    required this.timeLabel,
    required this.text,
    required this.score,
    required this.upVotes,
    required this.downVotes,
    required this.onUp,
    required this.onDown,
  });

  final LinearGradient gradient;
  final String author;
  final String initials;
  final String theme;
  final String timeLabel;
  final String text;
  final int score;
  final int upVotes;
  final int downVotes;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: textColor, fontWeight: FontWeight.w900)),
                      if (timeLabel.isNotEmpty)
                        Text(timeLabel,
                            style: TextStyle(
                                color: textColor.withOpacity(0.55), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    theme,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: textColor, height: 1.35)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VoteBtn(gradient: gradient, icon: Icons.arrow_upward_rounded, onTap: onUp),
                  const SizedBox(width: 8),
                  Text('$score',
                      style: const TextStyle(color: textColor, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  _VoteBtn(
                      gradient: gradient, icon: Icons.arrow_downward_rounded, onTap: onDown),
                  const SizedBox(width: 10),
                  Text('↑$upVotes  ↓$downVotes',
                      style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteBtn extends StatelessWidget {
  const _VoteBtn({required this.gradient, required this.icon, required this.onTap});
  final LinearGradient gradient;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}