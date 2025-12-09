import 'package:flutter/material.dart';

/// Affiche une boîte de dialogue pour demander un nom de portefeuille.
Future<String?> showCreatePortfolioDialog(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Créer un portefeuille'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom du portefeuille',
              hintText: 'Ex: Croissance US',
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Indiquez un nom.';
              }
              if (trimmed.length < 2) {
                return 'Nom trop court.';
              }
              if (trimmed.length > 40) {
                return 'Nom trop long (40 caractères max).';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Créer'),
          ),
        ],
      );
    },
  );
}
