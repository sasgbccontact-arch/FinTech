import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  // ---------------------------------------------------------------------------
  // CONFIGURATION DES CODES CADEAUX
  // Pour ajouter un code, ajoutez simplement une entrée dans cette map.
  // Clé : Le code (en MAJUSCULES)
  // Valeur : Map contenant l'ID de l'item, son type et le message de succès.
  // ---------------------------------------------------------------------------
  final Map<String, Map<String, dynamic>> _redeemableCodes = {
    'FABFINTECH': {
      'itemId': '_easteregg',
      'type': 'avatar', // Prévision pour gérer d'autres types (ex: 'coins') plus tard
      'successMsg': 'Code valide ! Avatar Easter Egg débloqué ! 🎁',
    },
    'SEXTOYSBOY': {
      'itemId': '_sydsteregg',
      'type': 'avatar',
      'successMsg': 'Code valide ! Avatar Syd débloqué ! 🎁',
    },
    'MONEY': {
      'itemId': 'money_cheat',
      'type': 'coins',
      'amount': 1000000,
      'successMsg': 'Code valide ! +1,000,000 pièces ! 💰',
    },
    'GEMMES': {
      'itemId': 'gems_cheat',
      'type': 'gems',
      'amount': 100000,
      'successMsg': 'Code valide ! +100,000 gemmes ! 💎',
    },
    // Exemple pour ajouter un futur code :
    // 'SUPERPROMO': {
    //   'itemId': '_bling', 
    //   'type': 'avatar',
    //   'successMsg': 'Avatar Bling débloqué !'
    // },
  };

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        title: const Text('Boutique'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: user == null
          ? const Center(child: Text("Veuillez vous connecter."))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final int coins = (data['coins'] as num?)?.toInt() ?? 0;
                final int gems = (data['gems'] as num?)?.toInt() ?? 0;
                
                // Pour l'inventaire et les gemmes, on doit peut-être encore regarder dans learning/progress
                // ou tout migrer. Pour l'instant, je suppose que les gemmes et l'inventaire restent 
                // dans learning/progress sauf indication contraire, mais le prompt parlait surtout des coins.
                // Cependant, pour simplifier l'affichage, je vais récupérer les gemmes/inventaire via un 2ème stream ou supposer migration.
                // Vu la demande "reconnecte les coins", je vais utiliser un StreamBuilder imbriqué pour learning/progress pour le reste.
                
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('games').doc('progress').snapshots(),
                  builder: (context, progressSnap) {
                    final progressData = progressSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final List<dynamic> inventory = progressData['inventory'] ?? [];

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildBalanceCard(gems, coins),
                        const SizedBox(height: 24),
                        
                        // --- SECTION CODE PROMO ---
                        const Text("Code Cadeau", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildRedeemSection(context, user.uid, inventory),
                        const SizedBox(height: 24),
                        // --------------------------

                        const Text("Avatars", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildAvatarsSection(context, user.uid, gems, coins, inventory),
                        const SizedBox(height: 24),
                        const Text("Ressources", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildExchangeSection(context, user.uid, gems),
                        const SizedBox(height: 24),
                        const Text("Boosts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildBoostsSection(context, user.uid, gems),
                      ],
                    );
                  }
                );
              },
            ),
    );
  }

  Widget _buildBalanceCard(int gems, int coins) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.shade500, Colors.deepPurple.shade800]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 32),
              const SizedBox(height: 8),
              Text("$gems Gemmes", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Column(
            children: [
              const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 32),
              const SizedBox(height: 8),
              Text("$coins Pièces", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection(BuildContext context, String uid, List<dynamic> inventory) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: "Entrez un code",
                border: InputBorder.none,
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _redeemCode(context, uid, inventory),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("Valider"),
          )
        ],
      ),
    );
  }

  Future<void> _redeemCode(BuildContext context, String uid, List<dynamic> inventory) async {
    // Normalisation du code entré (majuscules, sans espaces)
    final inputCode = _codeController.text.trim().toUpperCase();
    
    if (inputCode.isEmpty) return;

    // --- GESTION DU CODE ADMIN ---
    if (inputCode == 'ADMIN') {
      setState(() => _isLoading = true);
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final doc = await userRef.get();
        final bool currentAdmin = (doc.data()?['isAdmin'] as bool?) ?? false;
        final bool newStatus = !currentAdmin;

        await userRef.set({'isAdmin': newStatus}, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(newStatus ? "Mode Admin ACTIVÉ 🔓" : "Mode Admin DÉSACTIVÉ 🔒"),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ));
          _codeController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }
    // -----------------------------

    // Vérification si le code existe dans notre configuration
    final rewardData = _redeemableCodes[inputCode];

    if (rewardData != null) {
      final String itemId = rewardData['itemId'];
      final String successMsg = rewardData['successMsg'];
      final String type = rewardData['type'];

      // Vérification spécifique pour les avatars (pour éviter les doublons)
      if (type == 'avatar' && inventory.contains(itemId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vous possédez déjà cette récompense !")));
        _codeController.clear();
        return;
      }

      setState(() => _isLoading = true);

      try {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final progressRef = userDocRef.collection('games').doc('progress');
        
        // Logique d'application de la récompense
        if (type == 'avatar') {
          await progressRef.update({
            'inventory': FieldValue.arrayUnion([itemId])
          });
        } else if (type == 'coins') {
          final int amount = rewardData['amount'] ?? 0;
          await userDocRef.update({
            'coins': FieldValue.increment(amount)
          });
        } else if (type == 'gems') {
          final int amount = rewardData['amount'] ?? 0;
          await userDocRef.update({
            'gems': FieldValue.increment(amount)
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
          ));
          _codeController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur technique : $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Code non trouvé dans la Map
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Code invalide ou expiré."),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildAvatarsSection(BuildContext context, String uid, int currentGems, int currentCoins, List<dynamic> inventory) {
    final avatars = [
      {'id': '_bling', 'name': 'Bling Bling', 'price': 250, 'currency': 'gems', 'asset': 'assets/avatars/avatar_bling.png'},
      {'id': '_strong', 'name': 'Mr Strong', 'price': 10000, 'currency': 'coins', 'asset': 'assets/avatars/avatar_strong.png'},
      {'id': '_geek', 'name': 'Geek', 'price': 2000, 'currency': 'coins', 'asset': 'assets/avatars/avatar_geek.png'},
      {'id': '_skelet', 'name': 'Skelet', 'price': 100, 'currency': 'gems', 'asset': 'assets/avatars/avatar_skelet.png'},
      // Avatar spécial (code only)
    ];

    if (inventory.contains('_easteregg')) {
      avatars.add({
        'id': '_easteregg',
        'name': 'Easter Egg',
        'price': 0,
        'currency': 'code',
        'asset': 'assets/avatars/easteregg.png',
      });
    }

    if (inventory.contains('_sydsteregg')) {
      avatars.add({
        'id': '_sydsteregg',
        'name': 'Syd',
        'price': 0,
        'currency': 'code',
        'asset': 'assets/avatars/sydsteregg.png',
      });
    }

    // Tri : Les avatars possédés s'affichent en premier
    avatars.sort((a, b) {
      final bool ownedA = inventory.contains(a['id']);
      final bool ownedB = inventory.contains(b['id']);
      if (ownedA == ownedB) return 0;
      return ownedA ? -1 : 1;
    });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final item = avatars[index];
        final String id = item['id'] as String;
        final int price = item['price'] as int;
        final String currency = item['currency'] as String? ?? 'gems';
        
        final bool isGems = currency == 'gems';
        final bool isCodeOnly = currency == 'code';
        final bool owned = inventory.contains(id);
        
        final bool canBuy = !isCodeOnly && (isGems ? currentGems >= price : currentCoins >= price);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: owned ? Colors.green.withOpacity(0.5) : Colors.grey.shade200, width: owned ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showAvatarPreview(context, item),
                child: item.containsKey('asset')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(item['asset'] as String, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person, size: 80)),
                      )
                    : Icon(item['icon'] as IconData, size: 80, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              if (owned)
                const Text("Possédé", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
              else if (isCodeOnly)
                const Text("Code Secret", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12))
              else
                ElevatedButton(
                  onPressed: canBuy ? () => _confirmPurchase(context, uid, id, price, currency, item['name'] as String, isAvatar: true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text("$price ${isGems ? '💎' : '🪙'}"),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExchangeSection(BuildContext context, String uid, int currentGems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.monetization_on, color: Colors.white)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sac de pièces", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Obtenir 500 pièces", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: currentGems >= 10 ? () => _buyItem(context, uid, 'coins_pack', 10, isAvatar: false) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("10 💎"),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostsSection(BuildContext context, String uid, int currentGems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.flash_on_rounded, color: Colors.white)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("0% de frais (12h)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Aucun frais sur vos ordres", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: currentGems >= 20 ? () => _confirmPurchase(context, uid, 'boost_zero_fees', 20, 'gems', 'Boost 0% Frais', isAvatar: false) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("20 💎"),
          ),
        ],
      ),
    );
  }

  void _showAvatarPreview(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item['name'] as String,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (item.containsKey('asset'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    item['asset'] as String,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(item['icon'] as IconData, size: 150, color: Colors.black87),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Fermer"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPurchase(BuildContext context, String uid, String itemId, int price, String currency, String itemName, {required bool isAvatar}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer l'achat"),
        content: Text("Voulez-vous acheter \"$itemName\" pour $price ${currency == 'gems' ? 'Gemmes' : 'Pièces'} ?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Acheter"),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      _buyItem(context, uid, itemId, price, isAvatar: isAvatar, currency: currency);
    }
  }

  Future<void> _buyItem(BuildContext context, String uid, String itemId, int price, {required bool isAvatar, String currency = 'gems'}) async {
    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final progressRef = userDocRef.collection('games').doc('progress');
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnap = await transaction.get(userDocRef);
        
        // Coins and Gems are now on the user doc
        final int currentGems = (userSnap.data()?['gems'] as num?)?.toInt() ?? 0;
        final int currentCoins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;

        final updates = <String, dynamic>{};

        if (currency == 'gems') {
          if (currentGems < price) throw Exception("Pas assez de gemmes");
          updates['gems'] = currentGems - price;
        } else {
          if (currentCoins < price) throw Exception("Pas assez de pièces");
          updates['coins'] = currentCoins - price;
        }

        if (isAvatar) {
          transaction.update(progressRef, {'inventory': FieldValue.arrayUnion([itemId])});
        } else if (itemId == 'coins_pack') {
          updates['coins'] = FieldValue.increment(500);
        } else if (itemId == 'boost_zero_fees') {
          updates['boost_zero_fees_count'] = FieldValue.increment(1);
        }

        if (updates.isNotEmpty) {
          transaction.update(userDocRef, updates);
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAvatar ? "Avatar acheté !" : (itemId == 'boost_zero_fees' ? "Boost ajouté à l'inventaire !" : "Pièces obtenues !"))),
        );
      }
    } catch (e) {
      debugPrint("Erreur achat: $e");
    }
  }
}