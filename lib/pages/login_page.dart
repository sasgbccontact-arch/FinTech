import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fintech/core/constants.dart';

import '../app/app_structure.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Palette (same style as SearchPage)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _muted = Colors.black54;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;
  static const Color _chipBg = Color(0xFFF0F1F3);

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user != null) {
        final allowed = await _ensureUserDocument(user);
        if (!allowed) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Vous devez renseigner un nom pour continuer.';
            });
          }
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppStructure()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyError(e);
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Une erreur inattendue est survenue. Réessayez.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final hasName =
        data != null && (data['Name'] as String?)?.trim().isNotEmpty == true;
    if (snapshot.exists && hasName) {
      return true;
    }
    final name = await _askForDisplayName();
    if (name == null) {
      await FirebaseAuth.instance.signOut();
      return false;
    }
    await docRef.set({
      'Name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  Future<String?> _askForDisplayName() async {
    final controller = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Bienvenue !',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Votre nom',
                helperText: 'Indiquez comment nous pouvons vous appeler.',
                prefixIcon: const Icon(Icons.badge_rounded),
                filled: true,
                fillColor: _chipBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _wine.withValues(alpha: .45)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Indiquez votre nom.';
                }
                if (value.trim().length < 2) {
                  return 'Nom trop court.';
                }
                return null;
              },
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Déconnexion'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _wine,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (dialogFormKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'Identifiants inconnus. Vérifiez votre email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      default:
        return 'Connexion impossible pour le moment (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [_gold, _wine],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Connexion',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Card
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Accédez à votre espace',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Entrez votre email et votre mot de passe.',
                            style: TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Adresse email',
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                              filled: true,
                              fillColor: _chipBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _line),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _wine.withValues(alpha: .45)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Saisissez votre email.';
                              }
                              if (!value.contains('@')) {
                                return 'Email invalide.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              filled: true,
                              fillColor: _chipBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _line),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _wine.withValues(alpha: .45)),
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Saisissez votre mot de passe.';
                              }
                              if (value.length < 6) {
                                return 'Le mot de passe doit contenir au moins 6 caractères.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // Error
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _errorMessage == null
                                ? const SizedBox.shrink()
                                : Container(
                                    key: const ValueKey('error'),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _wine.withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _wine.withValues(alpha: .25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: _wine.withValues(alpha: .95),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: _wine.withValues(alpha: .95),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 16),

                          // Primary CTA
                          InkWell(
                            onTap: _isLoading ? null : _signIn,
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: _isLoading ? .7 : 1,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [_gold, _wine],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: .12),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Se connecter',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            letterSpacing: .2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          Text(
                            'En continuant, vous accédez aux fonctionnalités de l\'application.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
