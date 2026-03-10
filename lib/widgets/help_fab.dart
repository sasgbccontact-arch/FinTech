import 'package:flutter/material.dart';

class HelpFab extends StatelessWidget {
  final String helpText;

  const HelpFab({super.key, required this.helpText});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.black,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(
        Icons.question_mark_rounded,
        color: Colors.white,
        size: 20,
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blue),
                    const SizedBox(width: 10),
                    const Text(
                      'Aide',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: Text(
                  helpText,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Compris',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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
