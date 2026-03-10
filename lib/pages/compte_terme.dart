import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fintech/core/constants.dart';

class TermDepositSection extends StatefulWidget {
  const TermDepositSection({super.key});

  @override
  State<TermDepositSection> createState() => _TermDepositSectionState();
}

class _TermDepositSectionState extends State<TermDepositSection> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  // Configuration des offres de dépôts
  final List<Map<String, dynamic>> _depositOffers = [
    {'days': 3, 'rate': 0.02, 'label': 'Court Terme (3j)', 'color': Colors.blue},
    {'days': 7, 'rate': 0.05, 'label': 'Moyen Terme (1 sem)', 'color': Colors.orange},
    {'days': 14, 'rate': 0.10, 'label': 'Long Terme (2 sem)', 'color': Colors.purple},
  ];

  Future<void> _unlockFeature(int currentGems) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (currentGems < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pas assez de gemmes (100 requises)"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'gems': FieldValue.increment(-100),
        'is_term_deposit_unlocked': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Compte à terme débloqué !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erreur unlock: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkCooldown(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    
    // Admin bypass : on autorise tout de suite si admin
    if (userDoc.data()?['isAdmin'] == true) return true;

    final lastDeposit = userDoc.data()?['last_term_deposit_date'] as Timestamp?;
    
    if (lastDeposit != null) {
      final diff = DateTime.now().difference(lastDeposit.toDate());
      if (diff.inDays < 7) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Cooldown actif : Revenez dans ${7 - diff.inDays} jours."), backgroundColor: Colors.orange),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<double> _calculatePortfolioValue(String uid) async {
    double totalValue = 0;

    // 2. Actions (Positions)
    final positions = await _firestore.collection('users').doc(uid).collection('games').doc('portofolio').collection('positions').get();
    for (var doc in positions.docs) {
      final qty = (doc.data()['quantity'] as num?)?.toInt() ?? 0;
      final avgPrice = (doc.data()['averagePrice'] as num?)?.toDouble() ?? 0.0;
      totalValue += qty * avgPrice;
    }
    return totalValue;
  }

  Future<void> _createDeposit(String type, int amount, int days, double rate) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Vérification solde
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final currentBalance = (userDoc.data()?[type] as num?)?.toInt() ?? 0;

    if (currentBalance < amount) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Solde insuffisant en ${type == 'coins' ? 'Pièces' : 'Gemmes'}"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        
        // Débit
        transaction.update(userRef, {type: FieldValue.increment(-amount)});
        transaction.update(userRef, {'last_term_deposit_date': FieldValue.serverTimestamp()});

        // Création du dépôt
        final depositRef = userRef.collection('term_deposits').doc();
        transaction.set(depositRef, {
          'type': type,
          'amount': amount,
          'rate': rate,
          'duration_days': days,
          'start_date': FieldValue.serverTimestamp(),
          'end_date': DateTime.now().add(Duration(days: days)),
          'status': 'active', // active, claimed
        });
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dépôt créé avec succès !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erreur création dépôt: ");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors du dépôt"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _claimDeposit(String depositId, String type, int initialAmount, double rate) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final reward = (initialAmount * (1 + rate)).floor();

    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final depositRef = userRef.collection('term_deposits').doc(depositId);

        // Crédit gain
        transaction.update(userRef, {type: FieldValue.increment(reward)});
        
        // Suppression ou archivage du dépôt
        transaction.delete(depositRef); 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Récupéré : + ${type == 'coins' ? 'Pièces' : 'Gemmes'}"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erreur claim: ");
    }
  }

  Future<void> _deleteDeposit(String depositId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).collection('term_deposits').doc(depositId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dépôt supprimé (Admin)"), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Erreur delete: $e");
    }
  }

  Future<void> _showCreateDepositModal(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Vérification Cooldown
    if (!await _checkCooldown(user.uid)) return;

    // Récupération infos utilisateur pour déterminer la limite
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final unlockedAvatars = List<String>.from(userData?['unlocked_avatars'] ?? []);
    final bool isAdmin = userData?['isAdmin'] ?? false;
    // '_student' débloqué = Chapitre 1 validé
    final bool isPortfolioUnlocked = isAdmin || unlockedAvatars.contains('_student');

    int maxAmount;
    String helperText;

    if (isPortfolioUnlocked) {
      // Calcul Limite 20%
      final portfolioValue = await _calculatePortfolioValue(user.uid);
      maxAmount = (portfolioValue * 0.20).floor();
      helperText = "Max 20% de la valeur de votre portefeuille de jeu";
    } else {
      // Limite fixe 500
      maxAmount = 500;
      helperText = "Max 500 (Portefeuille non débloqué)";
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CreateDepositSheet(
        offers: _depositOffers,
        maxAmount: maxAmount,
        helperText: helperText,
        onSubmit: _createDeposit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final bool isUnlocked = userData?['is_term_deposit_unlocked'] ?? false;
        final int gems = (userData?['gems'] as num?)?.toInt() ?? 0;
        final bool isAdmin = userData?['isAdmin'] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0xFFE6E8EB)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: .06),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ],
),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
  width: 42,
  height: 42,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: const LinearGradient(
      colors: [detailsColor1, detailsColor2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .10),
        blurRadius: 16,
        offset: const Offset(0, 10),
      ),
    ],
  ),
  child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
),
              title: const Text(
  "Compte à Terme",
  style: TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 16,
    color: textColor,
    letterSpacing: .2,
  ),
),
              subtitle: Text(
  isUnlocked ? "Faites fructifier votre argent" : "Débloquer pour 100 💎",
  style: const TextStyle(
    color: Colors.black54,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  ),
),
              children: [
                if (!isUnlocked)
                  Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F3),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE6E8EB)),
    ),
    child: Column(
      children: [
        const Text(
          "Bloquez vos pièces ou gemmes pendant une durée déterminée pour obtenir un rendement garanti.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 6,
          width: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [detailsColor1, detailsColor2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _isLoading ? null : () => _unlockFeature(gems),
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: _isLoading ? .7 : 1,
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [detailsColor1, detailsColor2],
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
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        "Débloquer (100 Gemmes)",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
)
                else
                  _buildActiveDepositsList(user.uid, isAdmin),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveDepositsList(String uid, bool isAdmin) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').doc(uid).collection('term_deposits').orderBy('end_date').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
  return Center(
    child: CircularProgressIndicator(
      color: detailsColor2,
      backgroundColor: detailsColor1.withValues(alpha: .20),
      strokeWidth: 3,
    ),
  );
}
            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Padding(
  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE6E8EB)),
    ),
    child: Row(
      children: const [
        Icon(Icons.event_busy_rounded, color: Colors.black54),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            "Aucun dépôt actif pour le moment.",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  ),
);
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final id = docs[index].id;
                final type = data['type'] ?? 'coins';
                final amount = (data['amount'] as num).toInt();
                final rate = (data['rate'] as num).toDouble();
                final endDate = (data['end_date'] as Timestamp).toDate();
                final now = DateTime.now();
                final isReady = now.isAfter(endDate);
                final reward = (amount * (1 + rate)).floor();

                final diff = endDate.difference(now);
                final String statusText;
                final Color statusColor;

                if (isReady) {
                  statusText = "Disponible";
                  statusColor = Colors.green;
                } else if (diff.inDays > 0) {
                  statusText = "Dans ${diff.inDays}j";
                  statusColor = Colors.black54;
                } else if (diff.inHours > 0) {
                  statusText = "Dans ${diff.inHours}h";
                  statusColor = Colors.black54;
                } else {
                  statusText = "Dans ${diff.inMinutes}min";
                  statusColor = Colors.black54;
                }

                return ListTile(
                  leading: Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      colors: type == 'coins'
          ? [const Color(0xFFFFD54F), const Color(0xFFFF8F00)]
          : [const Color(0xFF4DD0E1), const Color(0xFF006064)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .10),
        blurRadius: 16,
        offset: const Offset(0, 10),
      ),
    ],
  ),
  child: Icon(
    type == 'coins' ? Icons.monetization_on_rounded : Icons.diamond_rounded,
    color: Colors.white,
    size: 22,
  ),
),
                  title: Text(
                    "$amount ➔ $reward ${type == 'coins' ? 'Pièces' : 'Gemmes'}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Row(
  children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Text(
        "Taux ${(rate * 100).toInt()}%",
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    ),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isReady
            ? Colors.green.withValues(alpha: 0.10)
            : const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReady
              ? Colors.green.withValues(alpha: 0.20)
              : const Color(0xFFE6E8EB),
        ),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: isReady ? Colors.green : statusColor,
        ),
      ),
    ),
  ],
),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isReady)
                        InkWell(
  onTap: () => _claimDeposit(id, type, amount, rate),
  borderRadius: BorderRadius.circular(14),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        colors: [detailsColor1, detailsColor2],
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
    child: const Text(
      "Récupérer",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
)
                      else
                        const Icon(Icons.lock_clock_rounded, color: Colors.black54, size: 20),
                      
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () => _deleteDeposit(id),
                          tooltip: "Supprimer (Admin)",
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCreateDepositModal(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text("Nouveau Dépôt"),
              style: OutlinedButton.styleFrom(
  backgroundColor: const Color(0xFFF0F1F3),
  foregroundColor: detailsColor2,
  side: const BorderSide(color: Color(0xFFE6E8EB)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateDepositSheet extends StatefulWidget {
  final List<Map<String, dynamic>> offers;
  final int maxAmount;
  final String helperText;
  final Function(String type, int amount, int days, double rate) onSubmit;

  const _CreateDepositSheet({required this.offers, required this.maxAmount, required this.helperText, required this.onSubmit});

  @override
  State<_CreateDepositSheet> createState() => _CreateDepositSheetState();
}

class _CreateDepositSheetState extends State<_CreateDepositSheet> {
  String _selectedType = 'coins';
  int _selectedOfferIndex = 0;
  final TextEditingController _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final offer = widget.offers[_selectedOfferIndex];
    final ratePercent = ((offer['rate'] as double) * 100).toInt();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ouvrir un Compte à Terme", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Sélecteur Type
          Row(
            children: [
              Expanded(
                child: _buildTypeSelector('coins', "Pièces", Icons.monetization_on_rounded, Colors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeSelector('gems', "Gemmes", Icons.diamond_rounded, Colors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sélecteur Durée
          const Text("Durée de blocage", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.offers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = widget.offers[index];
                final isSelected = _selectedOfferIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedOfferIndex = index),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? (item['color'] as Color).withOpacity(0.1) : Colors.grey.shade50,
                      border: Border.all(
                        color: isSelected ? (item['color'] as Color) : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("${item['days']} Jours", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("+${(item['rate'] * 100).toInt()}%", 
                          style: TextStyle(
                            color: item['color'], 
                            fontWeight: FontWeight.bold, 
                            fontSize: 18
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Montant
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _selectedType == 'coins' ? "Montant (Max: ${widget.maxAmount})" : "Montant",
              suffixText: _selectedType == 'coins' ? 'Pièces' : 'Gemmes',
              helperText: _selectedType == 'coins' ? widget.helperText : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // Bouton Valider
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final amount = int.tryParse(_amountController.text);
                if (amount == null || amount <= 0) return;

                if (_selectedType == 'coins' && amount > widget.maxAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Le montant dépasse la limite (${widget.maxAmount})"), backgroundColor: Colors.red),
                  );
                  return;
                }

                widget.onSubmit(
                  _selectedType,
                  amount,
                  offer['days'],
                  offer['rate'],
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Bloquer pour ${offer['days']} jours (+${ratePercent}%)"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
