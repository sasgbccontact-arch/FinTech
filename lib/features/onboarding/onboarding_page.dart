import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fintech/core/constants.dart';
import 'package:fintech/features/notifications/metals_notification_service.dart';

class FinHubOnboardingPage extends StatefulWidget {
  const FinHubOnboardingPage({super.key, this.allowClose = false});

  final bool allowClose;

  @override
  State<FinHubOnboardingPage> createState() => _FinHubOnboardingPageState();
}

class _FinHubOnboardingPageState extends State<FinHubOnboardingPage> {
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;

  final User? _user = FirebaseAuth.instance.currentUser;

  int _step = 0;
  bool _loading = true;
  bool _saving = false;

  String _experienceLevel = 'debutant';
  String _primaryGoal = 'apprendre';
  String _starterPath = 'learn';
  bool _notificationsEnabled = true;
  final Set<String> _interests = <String>{'actualites', 'actions'};

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    final user = _user;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data != null) {
        _experienceLevel =
            (data['experience_level'] as String?) ?? _experienceLevel;
        _primaryGoal = (data['primary_goal'] as String?) ?? _primaryGoal;
        _starterPath = (data['starter_path'] as String?) ?? _starterPath;
        _notificationsEnabled =
            (data['notifications_enabled'] as bool?) ?? _notificationsEnabled;
        final existingInterests =
            (data['interests'] as List<dynamic>? ?? const <dynamic>[])
                .map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .toSet();
        if (existingInterests.isNotEmpty) {
          _interests
            ..clear()
            ..addAll(existingInterests);
        }
      }
    } catch (e) {
      debugPrint('[Onboarding] Erreur chargement: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _canContinue {
    if (_step == 1) {
      return _interests.isNotEmpty;
    }
    return true;
  }

  Future<void> _next() async {
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    await _save();
  }

  void _previous() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _save() async {
    final user = _user;
    if (user == null || _saving) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'experience_level': _experienceLevel,
        'primary_goal': _primaryGoal,
        'starter_path': _starterPath,
        'interests': _interests.toList(),
        'notifications_enabled': _notificationsEnabled,
        'onboarding_completed_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_notificationsEnabled) {
        await MetalsNotificationService.setEnabled(true);
        await MetalsNotificationService.setBroadcastEnabled(true);
      } else {
        await MetalsNotificationService.setEnabled(false);
        await MetalsNotificationService.setBroadcastEnabled(false);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer l’onboarding.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Ton niveau de départ',
      1 => 'Tes centres d’intérêt',
      _ => 'Ton parcours FinHub',
    };

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Bienvenue sur FinHub',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
        actions: [
          if (widget.allowClose)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _ink),
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(false),
            ),
        ],
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: _gold,
                    strokeWidth: 2.6,
                  ),
                )
                : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(title: title, step: _step),
                      const SizedBox(height: 18),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: SingleChildScrollView(
                                key: ValueKey<int>(_step),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: switch (_step) {
                                    0 => _buildExperienceStep(),
                                    1 => _buildInterestsStep(),
                                    _ => _buildStarterStep(),
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (_step > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : _previous,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _wine,
                                  side: BorderSide(
                                    color: _wine.withValues(alpha: 0.25),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Retour'),
                              ),
                            ),
                          if (_step > 0) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  !_canContinue || _saving ? null : _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child:
                                  _saving
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Text(
                                        _step == 2 ? 'Terminer' : 'Continuer',
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

  Widget _buildExperienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Choisis ton niveau',
          subtitle:
              'On adapte l’accueil et les raccourcis pour éviter l’effet “trop dense”.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ChoiceChip(
                label: 'Débutant',
                description: 'Je découvre les bases.',
                selected: _experienceLevel == 'debutant',
                onTap: () => setState(() => _experienceLevel = 'debutant'),
              ),
              _ChoiceChip(
                label: 'Intermédiaire',
                description: 'Je connais déjà les notions clés.',
                selected: _experienceLevel == 'intermediaire',
                onTap: () => setState(() => _experienceLevel = 'intermediaire'),
              ),
              _ChoiceChip(
                label: 'Avancé',
                description: 'Je veux aller vite sur les outils.',
                selected: _experienceLevel == 'avance',
                onTap: () => setState(() => _experienceLevel = 'avance'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Ton objectif principal',
          subtitle: 'Cela détermine la priorité affichée dans le hub.',
          child: Column(
            children: [
              _PreferenceTile(
                title: 'Apprendre la finance',
                subtitle: 'Leçons, quiz et progression pédagogique.',
                selected: _primaryGoal == 'apprendre',
                onTap: () => setState(() => _primaryGoal = 'apprendre'),
              ),
              _PreferenceTile(
                title: 'Simuler un portefeuille',
                subtitle: 'Passer rapidement à la pratique sans risque.',
                selected: _primaryGoal == 'simuler',
                onTap: () => setState(() => _primaryGoal = 'simuler'),
              ),
              _PreferenceTile(
                title: 'Suivre l’actualité marché',
                subtitle: 'Actus, métaux, agenda et signaux utiles.',
                selected: _primaryGoal == 'suivre',
                onTap: () => setState(() => _primaryGoal = 'suivre'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsStep() {
    const choices = <Map<String, String>>[
      {'id': 'actualites', 'label': 'Actualités'},
      {'id': 'actions', 'label': 'Actions'},
      {'id': 'dividendes', 'label': 'Dividendes'},
      {'id': 'metaux', 'label': 'Métaux'},
      {'id': 'budget', 'label': 'Objectifs'},
      {'id': 'quiz', 'label': 'Quiz & jeux'},
    ];

    return _SectionCard(
      title: 'Ce qui t’intéresse le plus',
      subtitle:
          'Sélectionne au moins un thème pour personnaliser “Aujourd’hui”.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children:
            choices.map((choice) {
              final id = choice['id']!;
              final selected = _interests.contains(id);
              return FilterChip(
                label: Text(choice['label']!),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _interests.add(id);
                    } else {
                      _interests.remove(id);
                    }
                  });
                },
                labelStyle: TextStyle(
                  color: selected ? _wine : _ink,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: _gold.withValues(alpha: 0.16),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? _wine.withValues(alpha: 0.28) : _line,
                ),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
      ),
    );
  }

  Widget _buildStarterStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Ton parcours de départ',
          subtitle:
              'Le bouton principal de “Aujourd’hui” t’enverra ici en priorité.',
          child: Column(
            children: [
              _PreferenceTile(
                title: 'Parcours Apprendre',
                subtitle: 'Démarre par les leçons et les quiz.',
                selected: _starterPath == 'learn',
                onTap: () => setState(() => _starterPath = 'learn'),
              ),
              _PreferenceTile(
                title: 'Parcours Portefeuille',
                subtitle: 'Commence par ta watchlist et la simulation.',
                selected: _starterPath == 'portfolio',
                onTap: () => setState(() => _starterPath = 'portfolio'),
              ),
              _PreferenceTile(
                title: 'Parcours Actu & Quiz',
                subtitle: 'Va directement sur les news et les mini-jeux.',
                selected: _starterPath == 'news',
                onTap: () => setState(() => _starterPath = 'news'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Notifications',
          subtitle:
              'Active les rappels essentiels et les annonces importantes de FinHub.',
          child: SwitchListTile.adaptive(
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _gold,
            activeTrackColor: _gold.withValues(alpha: 0.35),
            title: const Text(
              'Recevoir les notifications utiles',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            subtitle: const Text(
              'Cours des métaux, annonces manuelles et rappels in-app.',
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.step});

  final String title;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [detailsColor1, detailsColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etape ${step + 1}/3',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(3, (index) {
              final active = index <= step;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  decoration: BoxDecoration(
                    color:
                        active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color:
                selected
                    ? detailsColor1.withValues(alpha: 0.14)
                    : const Color(0xFFF8F8FA),
            border: Border.all(
              color:
                  selected
                      ? detailsColor2.withValues(alpha: 0.25)
                      : const Color(0xFFE6E8EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? detailsColor2 : textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient:
              selected
                  ? LinearGradient(
                    colors: [
                      detailsColor1.withValues(alpha: 0.16),
                      detailsColor2.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: selected ? null : const Color(0xFFF8F8FA),
          border: Border.all(
            color:
                selected
                    ? detailsColor2.withValues(alpha: 0.24)
                    : const Color(0xFFE6E8EB),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? detailsColor2 : textColor,
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
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? detailsColor2 : const Color(0xFFB9BCC3),
                  width: 1.5,
                ),
                color: selected ? detailsColor2 : Colors.transparent,
              ),
              child:
                  selected
                      ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
