import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/features/notifications/metals_notification_service.dart';

class AppSettingsSheet extends StatefulWidget {
  const AppSettingsSheet({
    super.key,
    required this.currentName,
    required this.onOpenNotificationCenter,
    required this.onRelaunchOnboarding,
  });

  final String? currentName;
  final Future<void> Function() onOpenNotificationCenter;
  final Future<void> Function() onRelaunchOnboarding;

  @override
  State<AppSettingsSheet> createState() => _AppSettingsSheetState();
}

class _AppSettingsSheetState extends State<AppSettingsSheet> {
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;

  bool _loading = true;
  bool _metalsEnabled = true;
  bool _broadcastEnabled = true;
  bool _profilePublic = true;
  AuthorizationStatus _authorizationStatus = AuthorizationStatus.notDetermined;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final Future<DocumentSnapshot<Map<String, dynamic>>?> userFuture =
          user == null
              ? Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null)
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
      final results = await Future.wait<dynamic>([
        MetalsNotificationService.isEnabled(),
        MetalsNotificationService.isBroadcastEnabled(),
        MetalsNotificationService.authorizationStatus(),
        userFuture,
      ]);

      if (!mounted) return;
      final userSnapshot =
          results[3] as DocumentSnapshot<Map<String, dynamic>>?;
      final userData = userSnapshot?.data() ?? const <String, dynamic>{};
      setState(() {
        _metalsEnabled = results[0] as bool;
        _broadcastEnabled = results[1] as bool;
        _authorizationStatus = results[2] as AuthorizationStatus;
        _profilePublic = (userData['profile_public'] as bool?) != false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleMetals(bool value) async {
    setState(() => _metalsEnabled = value);
    await MetalsNotificationService.setEnabled(value);
    final status = await MetalsNotificationService.authorizationStatus();
    if (!mounted) return;
    setState(() => _authorizationStatus = status);
  }

  Future<void> _toggleBroadcast(bool value) async {
    setState(() => _broadcastEnabled = value);
    await MetalsNotificationService.setBroadcastEnabled(value);
    final status = await MetalsNotificationService.authorizationStatus();
    if (!mounted) return;
    setState(() => _authorizationStatus = status);
  }

  Future<void> _toggleProfilePublic(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _profilePublic = value);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profile_public': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _profilePublic = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de mettre à jour la visibilité du profil.'),
        ),
      );
    }
  }

  Future<void> _changeName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      final snapshot = await userRef.get();
      final int gems = (snapshot.data()?['gems'] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      if (gems < 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Il vous faut 200 gemmes pour changer de pseudo.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de vérifier vos gemmes.')),
      );
      return;
    }

    final controller = TextEditingController(text: widget.currentName ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Modifier votre pseudo (200 💎)'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nouveau pseudo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Indiquez votre pseudo.';
                if (trimmed.length < 2) return 'Pseudo trop court.';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (result == null || result == widget.currentName) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentGems = (userDoc.data()?['gems'] as num?)?.toInt() ?? 0;
        if (currentGems < 200) {
          throw Exception('not-enough-gems');
        }
        transaction.set(userRef, {
          'Name': result,
          'gems': currentGems - 200,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pseudo modifié avec succès.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('not-enough-gems')
                ? 'Pas assez de gemmes.'
                : 'Erreur lors de la modification du pseudo.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String get _authorizationLabel {
    switch (_authorizationStatus) {
      case AuthorizationStatus.authorized:
        return 'Autorisées';
      case AuthorizationStatus.provisional:
        return 'Provisionnelles';
      case AuthorizationStatus.denied:
        return 'Refusées';
      case AuthorizationStatus.notDetermined:
        return 'À confirmer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child:
              _loading
                  ? const SizedBox(
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                  : ListView(
                    shrinkWrap: true,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [_gold, _wine],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Réglages FinHub',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pseudo, notifications et personnalisation.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Profil',
                        child: Column(
                          children: [
                            _ActionTile(
                              icon: Icons.badge_rounded,
                              title: 'Modifier mon pseudo',
                              subtitle:
                                  'Actuel: ${widget.currentName?.trim().isNotEmpty == true ? widget.currentName : 'Non renseigné'}',
                              onTap: _changeName,
                            ),
                            _ActionTile(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Relancer l’onboarding',
                              subtitle:
                                  'Revoir ton niveau, tes intérêts et ton parcours de départ.',
                              onTap: () async {
                                Navigator.of(context).pop();
                                await widget.onRelaunchOnboarding();
                              },
                            ),
                            SwitchListTile.adaptive(
                              value: _profilePublic,
                              onChanged: _toggleProfilePublic,
                              activeThumbColor: _wine,
                              activeTrackColor: _wine.withValues(alpha: 0.28),
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Profil public',
                                style: TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Visible dans le leaderboard, les badges et le profil public.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Notifications',
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _line),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_active_rounded,
                                    color: _wine,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Statut iOS',
                                      style: TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _authorizationLabel,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              value: _metalsEnabled,
                              onChanged: _toggleMetals,
                              activeThumbColor: _gold,
                              activeTrackColor: _gold.withValues(alpha: 0.35),
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Cours des métaux',
                                style: TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Active la notification quotidienne sur l’or et l’argent.',
                              ),
                            ),
                            SwitchListTile.adaptive(
                              value: _broadcastEnabled,
                              onChanged: _toggleBroadcast,
                              activeThumbColor: _wine,
                              activeTrackColor: _wine.withValues(alpha: 0.28),
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Annonces FinHub',
                                style: TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Reçois les diffusions manuelles envoyées via GitHub Actions.',
                              ),
                            ),
                            const SizedBox(height: 4),
                            _ActionTile(
                              icon: Icons.inbox_rounded,
                              title: 'Centre de notifications',
                              subtitle:
                                  'Retrouver les derniers messages reçus dans l’app.',
                              onTap: () async {
                                Navigator.of(context).pop();
                                await widget.onOpenNotificationCenter();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
