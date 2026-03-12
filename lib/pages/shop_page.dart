import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fintech/core/constants.dart';
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
      'type':
          'avatar', // Prévision pour gérer d'autres types (ex: 'coins') plus tard
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
  };

  // Palette locale (cohérente avec SearchPage)
  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _chipBg = Color(0xFFF0F1F3);
  static const Color _gold = detailsColor1;
  static const Color _wine = detailsColor2;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Boutique',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: .2,
          ),
        ),
        backgroundColor: _bg,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 6,
                width: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    colors: [_gold, _wine],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body:
          user == null
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Center(
                    child: _PremiumStateCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Connexion requise',
                      message:
                          'Veuillez vous connecter pour accéder à la boutique.',
                    ),
                  ),
                ),
              )
              : StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const _ShopLoadingView();
                  }

                  final data =
                      snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final int coins = (data['coins'] as num?)?.toInt() ?? 0;
                  final int gems = (data['gems'] as num?)?.toInt() ?? 0;

                  return StreamBuilder<DocumentSnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('games')
                            .doc('progress')
                            .snapshots(),
                    builder: (context, progressSnap) {
                      final progressData =
                          progressSnap.data?.data() as Map<String, dynamic>? ??
                          {};
                      final List<dynamic> inventory =
                          progressData['inventory'] ?? [];

                      return SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          children: [
                            _buildBalanceCard(gems, coins),
                            const SizedBox(height: 16),
                            const _DailyRewardShopSection(),
                            const SizedBox(height: 18),

                            const _SectionHeader(
                              title: 'Code cadeau',
                              subtitle:
                                  'Entre un code pour débloquer des récompenses.',
                              icon: Icons.card_giftcard_rounded,
                            ),
                            const SizedBox(height: 10),
                            _buildRedeemSection(context, user.uid, inventory),
                            const SizedBox(height: 18),

                            const _SectionHeader(
                              title: 'Avatars',
                              subtitle:
                                  'Collectionne et personnalise ton profil.',
                              icon: Icons.face_retouching_natural_rounded,
                            ),
                            const SizedBox(height: 10),
                            _buildAvatarsSection(
                              context,
                              user.uid,
                              gems,
                              coins,
                              inventory,
                            ),
                            const SizedBox(height: 18),

                            const _SectionHeader(
                              title: 'Ressources',
                              subtitle: 'Convertis tes gemmes en pièces.',
                              icon: Icons.auto_awesome_rounded,
                            ),
                            const SizedBox(height: 10),
                            _buildExchangeSection(context, user.uid, gems),
                            const SizedBox(height: 18),

                            const _SectionHeader(
                              title: 'Boosts',
                              subtitle:
                                  'Accélère ta progression avec des avantages temporaires.',
                              icon: Icons.flash_on_rounded,
                            ),
                            const SizedBox(height: 10),
                            _buildBoostsSection(context, user.uid, gems),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }

  Widget _buildBalanceCard(int gems, int coins) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        gradient: const LinearGradient(
          colors: [_gold, _wine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BalancePill(
              icon: Icons.diamond_rounded,
              iconColor: Colors.cyanAccent,
              label: '$gems',
              suffix: 'Gemmes',
            ),
          ),
          Container(
            width: 1,
            height: 42,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          Expanded(
            child: _BalancePill(
              icon: Icons.monetization_on_rounded,
              iconColor: Colors.amber,
              label: '$coins',
              suffix: 'Pièces',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection(
    BuildContext context,
    String uid,
    List<dynamic> inventory,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [_gold, _wine],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.redeem_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  hintText: 'Entrez un code',
                  border: InputBorder.none,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _GradientButton(
            label: 'Valider',
            loading: _isLoading,
            onTap:
                _isLoading ? null : () => _redeemCode(context, uid, inventory),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemCode(
    BuildContext context,
    String uid,
    List<dynamic> inventory,
  ) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus ? 'Mode Admin ACTIVÉ 🔓' : 'Mode Admin DÉSACTIVÉ 🔒',
              ),
              backgroundColor: newStatus ? Colors.green : Colors.orange,
            ),
          );
          _codeController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous possédez déjà cette récompense !'),
          ),
        );
        _codeController.clear();
        return;
      }

      setState(() => _isLoading = true);

      try {
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid);
        final progressRef = userDocRef.collection('games').doc('progress');

        // Logique d'application de la récompense
        if (type == 'avatar') {
          await progressRef.update({
            'inventory': FieldValue.arrayUnion([itemId]),
          });
        } else if (type == 'coins') {
          final int amount = rewardData['amount'] ?? 0;
          await userDocRef.update({'coins': FieldValue.increment(amount)});
        } else if (type == 'gems') {
          final int amount = rewardData['amount'] ?? 0;
          await userDocRef.update({'gems': FieldValue.increment(amount)});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
          );
          _codeController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur technique : $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Code non trouvé dans la Map
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code invalide ou expiré.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAvatarsSection(
    BuildContext context,
    String uid,
    int currentGems,
    int currentCoins,
    List<dynamic> inventory,
  ) {
    final avatars = [
      {
        'id': '_bling',
        'name': 'Bling Bling',
        'price': 250,
        'currency': 'gems',
        'asset': 'assets/avatars/avatar_bling.png',
      },
      {
        'id': '_strong',
        'name': 'Mr Strong',
        'price': 10000,
        'currency': 'coins',
        'asset': 'assets/avatars/avatar_strong.png',
      },
      {
        'id': '_geek',
        'name': 'Geek',
        'price': 2000,
        'currency': 'coins',
        'asset': 'assets/avatars/avatar_geek.png',
      },
      {
        'id': '_skelet',
        'name': 'Skelet',
        'price': 100,
        'currency': 'gems',
        'asset': 'assets/avatars/avatar_skelet.png',
      },
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
        childAspectRatio: 0.78,
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

        final bool canBuy =
            !isCodeOnly &&
            (isGems ? currentGems >= price : currentCoins >= price);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: owned ? Colors.green.withValues(alpha: 0.45) : _line,
              width: owned ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                GestureDetector(
                  onTap: () => _showAvatarPreview(context, item),
                  child:
                      item.containsKey('asset')
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              item['asset'] as String,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 80,
                                    color: Colors.black54,
                                  ),
                            ),
                          )
                          : Icon(
                            item['icon'] as IconData,
                            size: 80,
                            color: Colors.black87,
                          ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                if (owned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Text(
                      'Possédé',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  )
                else if (isCodeOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _wine.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _wine.withValues(alpha: 0.22)),
                    ),
                    child: const Text(
                      'Code secret',
                      style: TextStyle(
                        color: _wine,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  _GradientButton(
                    label: '$price ${isGems ? '💎' : '🪙'}',
                    onTap:
                        canBuy
                            ? () => _confirmPurchase(
                              context,
                              uid,
                              id,
                              price,
                              currency,
                              item['name'] as String,
                              isAvatar: true,
                            )
                            : null,
                    compact: true,
                    disabledLabel: '$price ${isGems ? '💎' : '🪙'}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExchangeSection(
    BuildContext context,
    String uid,
    int currentGems,
  ) {
    return _ShopRowCard(
      leading: _GradientIconBox(
        icon: Icons.monetization_on_rounded,
        colors: const [Color(0xFFFFD54F), Color(0xFFFF8F00)],
      ),
      title: 'Sac de pièces',
      subtitle: 'Obtenir 500 pièces',
      trailing: _GradientButton(
        label: '10 💎',
        compact: true,
        onTap:
            currentGems >= 10
                ? () =>
                    _buyItem(context, uid, 'coins_pack', 10, isAvatar: false)
                : null,
      ),
    );
  }

  Widget _buildBoostsSection(
    BuildContext context,
    String uid,
    int currentGems,
  ) {
    return _ShopRowCard(
      leading: _GradientIconBox(
        icon: Icons.flash_on_rounded,
        colors: const [Color(0xFF4DD0E1), Color(0xFF006064)],
      ),
      title: '0% de frais (12h)',
      subtitle: 'Aucun frais sur vos ordres',
      trailing: _GradientButton(
        label: '20 💎',
        compact: true,
        onTap:
            currentGems >= 20
                ? () => _confirmPurchase(
                  context,
                  uid,
                  'boost_zero_fees',
                  20,
                  'gems',
                  'Boost 0% Frais',
                  isAvatar: false,
                )
                : null,
      ),
    );
  }

  void _showAvatarPreview(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .10),
                    blurRadius: 26,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item['name'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    width: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [_gold, _wine],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (item.containsKey('asset'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        item['asset'] as String,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      item['icon'] as IconData,
                      size: 150,
                      color: Colors.black87,
                    ),
                  const SizedBox(height: 18),
                  _GradientButton(
                    label: 'Fermer',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _confirmPurchase(
    BuildContext context,
    String uid,
    String itemId,
    int price,
    String currency,
    String itemName, {
    required bool isAvatar,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Confirmer l'achat"),
            content: Text(
              'Voulez-vous acheter "$itemName" pour $price ${currency == 'gems' ? 'Gemmes' : 'Pièces'} ?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _wine,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Acheter'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      _buyItem(
        context,
        uid,
        itemId,
        price,
        isAvatar: isAvatar,
        currency: currency,
      );
    }
  }

  Future<void> _buyItem(
    BuildContext context,
    String uid,
    String itemId,
    int price, {
    required bool isAvatar,
    String currency = 'gems',
  }) async {
    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      final progressRef = userDocRef.collection('games').doc('progress');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnap = await transaction.get(userDocRef);

        // Coins and Gems are now on the user doc
        final int currentGems =
            (userSnap.data()?['gems'] as num?)?.toInt() ?? 0;
        final int currentCoins =
            (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;

        final updates = <String, dynamic>{};

        if (currency == 'gems') {
          if (currentGems < price) throw Exception('Pas assez de gemmes');
          updates['gems'] = currentGems - price;
        } else {
          if (currentCoins < price) throw Exception('Pas assez de pièces');
          updates['coins'] = currentCoins - price;
        }

        if (isAvatar) {
          transaction.update(progressRef, {
            'inventory': FieldValue.arrayUnion([itemId]),
          });
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
          SnackBar(
            content: Text(
              isAvatar
                  ? 'Avatar acheté !'
                  : (itemId == 'boost_zero_fees'
                      ? "Boost ajouté à l'inventaire !"
                      : 'Pièces obtenues !'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur achat: $e');
    }
  }
}

class _DailyRewardShopSection extends StatefulWidget {
  const _DailyRewardShopSection();

  @override
  State<_DailyRewardShopSection> createState() =>
      _DailyRewardShopSectionState();
}

class _DailyRewardShopSectionState extends State<_DailyRewardShopSection> {
  bool _loading = true;
  bool _canClaim = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      final lastRewardTs = data?['last_daily_reward'] as Timestamp?;

      bool claimedToday = false;
      if (lastRewardTs != null) {
        final now = DateTime.now();
        final last = lastRewardTs.toDate();
        if (now.year == last.year &&
            now.month == last.month &&
            now.day == last.day) {
          claimedToday = true;
        }
      }

      if (mounted) {
        setState(() {
          _canClaim = !claimedToday;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_canClaim) return;

    setState(() => _loading = true);

    final random = Random();
    final isCoins = random.nextBool();
    final options = isCoins ? [100, 200, 300] : [2, 4, 6];
    final amount = options[random.nextInt(options.length)];
    final type = isCoins ? 'coins' : 'gems';
    final label = isCoins ? 'Pièces' : 'Gemmes';

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await ref.set({
        type: FieldValue.increment(amount),
        'last_daily_reward': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎁 Récompense récupérée : +$amount $label !"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _canClaim = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de la récupération."),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: _ThemedLoader());
    }

    return GestureDetector(
      onTap: _canClaim ? _claimReward : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6E8EB)),
          gradient: const LinearGradient(
            colors: [detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cadeau du jour',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _canClaim
                        ? 'Touchez pour récupérer votre récompense quotidienne.'
                        : 'Déjà récupéré aujourd’hui. Revenez demain.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _canClaim ? Icons.touch_app_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemedLoader extends StatelessWidget {
  const _ThemedLoader();

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      color: detailsColor2,
      backgroundColor: detailsColor1.withValues(alpha: .20),
      strokeWidth: 3,
    );
  }
}

class _ShopLoadingView extends StatelessWidget {
  const _ShopLoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: List.generate(
          5,
          (index) => Container(
            height: index == 0 ? 128 : 108,
            margin: EdgeInsets.only(bottom: index == 4 ? 0 : 16),
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
          ),
        ),
      ),
    );
  }
}

class _PremiumStateCard extends StatelessWidget {
  const _PremiumStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.compact = false,
    this.disabledLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool compact;
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !loading;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: compact ? 36 : 50,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient:
                enabled
                    ? const LinearGradient(
                      colors: [detailsColor1, detailsColor2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            boxShadow:
                enabled
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child:
                loading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      enabled ? label : (disabledLabel ?? label),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class _ShopRowCard extends StatelessWidget {
  const _ShopRowCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _GradientIconBox extends StatelessWidget {
  const _GradientIconBox({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
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
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.suffix,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 8),
        Text(
          '$label $suffix',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
