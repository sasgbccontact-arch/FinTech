import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Affiche le solde coins/gemmes à partir de `/users/{uid}/learning/progress`.
/// Fallback sur le document user si coins/gems n'existent pas dans progress.
class WalletBalances extends StatelessWidget {
  const WalletBalances({
    super.key,
    required this.auth,
    this.padding = EdgeInsets.zero,
    this.compact = false,
  });

  final FirebaseAuth auth;
  final EdgeInsetsGeometry padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) {
      return const Text('Connecte-toi pour voir ton solde');
    }

    return Padding(
      padding: padding,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() as Map<String, dynamic>?;
          final coins = (userData?['coins'] as num?)?.toInt() ?? 0;
          final gems = (userData?['gems'] as num?)?.toInt() ?? 0;

          return _buildContent(coins, gems);
        },
      ),
    );
  }

  Widget _buildContent(int coins, int gems) {
    final double fontSize = compact ? 12 : 13;
    final double iconSize = compact ? 16 : 18;
    return Row(
      children: [
        _Badge(
          label: 'Coins',
          value: coins,
          color: Colors.amber.shade700,
          icon: Icons.monetization_on_outlined,
          fontSize: fontSize,
          iconSize: iconSize,
        ),
        const SizedBox(width: 8),
        _Badge(
          label: 'Gemmes',
          value: gems,
          color: Colors.indigo.shade600,
          icon: Icons.diamond_outlined,
          fontSize: fontSize,
          iconSize: iconSize,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.fontSize,
    required this.iconSize,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: fontSize,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}
