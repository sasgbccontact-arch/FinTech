import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    final hasName = data != null && (data['Name'] as String?)?.trim().isNotEmpty == true;
    if (snapshot.exists && hasName) {
      return true;
    }
    final name = await _askForDisplayName();
    if (name == null) {
      await FirebaseAuth.instance.signOut();
      return false;
    }
    await docRef.set(
      {
        'Name': name,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
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
          title: const Text('Bienvenue !'),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Votre nom',
                helperText: 'Indiquez comment nous pouvons vous appeler.',
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Déconnexion'),
            ),
            ElevatedButton(
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Connexion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Adresse email',
                          prefixIcon: Icon(Icons.person_outline),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
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
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Se connecter'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
