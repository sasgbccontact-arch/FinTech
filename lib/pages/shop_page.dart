import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fintech/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _ShopCurrency { gems, coins }

extension _ShopCurrencyX on _ShopCurrency {
  String get emoji => this == _ShopCurrency.gems ? '💎' : '🪙';
}

enum _ShopProductKind {
  bundle,
  consumable,
  cosmetic,
  boost,
  collection,
  currency,
}

extension _ShopProductKindX on _ShopProductKind {
  String get label {
    switch (this) {
      case _ShopProductKind.bundle:
        return 'Bundle';
      case _ShopProductKind.consumable:
        return 'Consommable';
      case _ShopProductKind.cosmetic:
        return 'Cosmétique';
      case _ShopProductKind.boost:
        return 'Boost';
      case _ShopProductKind.collection:
        return 'Collection';
      case _ShopProductKind.currency:
        return 'Ressource';
    }
  }
}

enum _ShopRarity { common, rare, epic, legendary }

extension _ShopRarityX on _ShopRarity {
  String get label {
    switch (this) {
      case _ShopRarity.common:
        return 'Commun';
      case _ShopRarity.rare:
        return 'Rare';
      case _ShopRarity.epic:
        return 'Épique';
      case _ShopRarity.legendary:
        return 'Légendaire';
    }
  }

  Color get color {
    switch (this) {
      case _ShopRarity.common:
        return const Color(0xFF607D8B);
      case _ShopRarity.rare:
        return const Color(0xFF1565C0);
      case _ShopRarity.epic:
        return const Color(0xFF8E24AA);
      case _ShopRarity.legendary:
        return detailsColor1;
    }
  }
}

enum _ShopTabKey { games, cosmetics, boosts }

class _ShopBundleContent {
  const _ShopBundleContent({required this.productId, required this.quantity});

  final String productId;
  final int quantity;
}

class _ShopProduct {
  const _ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.kind,
    required this.rarity,
    required this.gameLabel,
    required this.usage,
    required this.immediateImpact,
    required this.useLocation,
    required this.primaryTab,
    this.assetPath,
    this.icon = Icons.auto_awesome_rounded,
    this.gradient = const [detailsColor1, detailsColor2],
    this.bundle = const <_ShopBundleContent>[],
    this.slotKey,
    this.requiredCompletedScenarios = 0,
    this.requiredMacroStars = 0,
    this.requiresAnyGoldMedal = false,
    this.unlockHint,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final _ShopCurrency currency;
  final _ShopProductKind kind;
  final _ShopRarity rarity;
  final String gameLabel;
  final String usage;
  final String immediateImpact;
  final String useLocation;
  final _ShopTabKey primaryTab;
  final String? assetPath;
  final IconData icon;
  final List<Color> gradient;
  final List<_ShopBundleContent> bundle;
  final String? slotKey;
  final int requiredCompletedScenarios;
  final int requiredMacroStars;
  final bool requiresAnyGoldMedal;
  final String? unlockHint;

  bool get isAvatar => slotKey == 'avatar';

  bool get isUnique =>
      kind == _ShopProductKind.cosmetic ||
      kind == _ShopProductKind.collection ||
      isAvatar;

  bool get isConsumable =>
      kind == _ShopProductKind.consumable || id == 'boost_zero_fees';

  bool get canReceiveDailyOffer =>
      kind != _ShopProductKind.collection && price > 0;
}

class _ShopDailyOffer {
  const _ShopDailyOffer({
    required this.productId,
    required this.discountPercent,
    required this.discountedPrice,
    required this.originalPrice,
    required this.isBestOffer,
  });

  final String productId;
  final int discountPercent;
  final int discountedPrice;
  final int originalPrice;
  final bool isBestOffer;
}

class _ShopQuestState {
  const _ShopQuestState({
    required this.dayKey,
    required this.buyCount,
    required this.equipCount,
    required this.useCount,
    required this.claimed,
  });

  factory _ShopQuestState.empty(String dayKey) {
    return _ShopQuestState(
      dayKey: dayKey,
      buyCount: 0,
      equipCount: 0,
      useCount: 0,
      claimed: false,
    );
  }

  factory _ShopQuestState.fromMap(Map<String, dynamic>? map, String dayKey) {
    if (map == null || (map['dayKey'] as String?) != dayKey) {
      return _ShopQuestState.empty(dayKey);
    }
    return _ShopQuestState(
      dayKey: dayKey,
      buyCount: (map['buyCount'] as num?)?.toInt() ?? 0,
      equipCount: (map['equipCount'] as num?)?.toInt() ?? 0,
      useCount: (map['useCount'] as num?)?.toInt() ?? 0,
      claimed: map['claimed'] == true,
    );
  }

  final String dayKey;
  final int buyCount;
  final int equipCount;
  final int useCount;
  final bool claimed;

  bool get isComplete => buyCount >= 1 && equipCount >= 1 && useCount >= 1;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'dayKey': dayKey,
      'buyCount': buyCount,
      'equipCount': equipCount,
      'useCount': useCount,
      'claimed': claimed,
    };
  }

  _ShopQuestState copyWith({
    int? buyCount,
    int? equipCount,
    int? useCount,
    bool? claimed,
  }) {
    return _ShopQuestState(
      dayKey: dayKey,
      buyCount: buyCount ?? this.buyCount,
      equipCount: equipCount ?? this.equipCount,
      useCount: useCount ?? this.useCount,
      claimed: claimed ?? this.claimed,
    );
  }
}

class _ShopViewData {
  const _ShopViewData({
    required this.coins,
    required this.gems,
    required this.boostZeroFeesCount,
    required this.zeroFeesUntil,
    required this.currentAvatarId,
    required this.avatarInventory,
    required this.consumables,
    required this.activeConsumables,
    required this.ownedCosmetics,
    required this.equippedCosmetics,
    required this.questState,
    required this.completedScenarioCount,
    required this.chapterStars,
    required this.scenarioBestMedals,
  });

  factory _ShopViewData.fromMaps({
    required Map<String, dynamic>? userData,
    required Map<String, dynamic>? progressData,
    required Map<String, dynamic>? shopData,
    required Map<String, dynamic>? campaignData,
    required String dayKey,
  }) {
    final progressInventory = _stringList(progressData?['inventory']);
    return _ShopViewData(
      coins: (userData?['coins'] as num?)?.toInt() ?? 0,
      gems: (userData?['gems'] as num?)?.toInt() ?? 0,
      boostZeroFeesCount:
          (userData?['boost_zero_fees_count'] as num?)?.toInt() ?? 0,
      zeroFeesUntil: userData?['zero_fees_until'] as Timestamp?,
      currentAvatarId: userData?['avatar_id'] as String?,
      avatarInventory: progressInventory.toSet(),
      consumables: _readIntMap(shopData?['consumables']),
      activeConsumables: _readIntMap(shopData?['activeConsumables']),
      ownedCosmetics: _stringList(shopData?['ownedCosmetics']).toSet(),
      equippedCosmetics: _readStringMap(shopData?['equippedCosmetics']),
      questState: _ShopQuestState.fromMap(
        (shopData?['dailyQuest'] as Map?)?.cast<String, dynamic>(),
        dayKey,
      ),
      completedScenarioCount:
          _stringList(progressData?['completed_scenarios']).length,
      chapterStars: _readIntMap(campaignData?['chapterStars']),
      scenarioBestMedals: _readStringMap(campaignData?['scenarioBestMedals']),
    );
  }

  final int coins;
  final int gems;
  final int boostZeroFeesCount;
  final Timestamp? zeroFeesUntil;
  final String? currentAvatarId;
  final Set<String> avatarInventory;
  final Map<String, int> consumables;
  final Map<String, int> activeConsumables;
  final Set<String> ownedCosmetics;
  final Map<String, String> equippedCosmetics;
  final _ShopQuestState questState;
  final int completedScenarioCount;
  final Map<String, int> chapterStars;
  final Map<String, String> scenarioBestMedals;

  bool get hasAnyGoldMedal =>
      scenarioBestMedals.values.any((value) => value.toLowerCase() == 'gold');

  bool get zeroFeesActive =>
      zeroFeesUntil != null && zeroFeesUntil!.toDate().isAfter(DateTime.now());

  int balanceFor(_ShopCurrency currency) {
    return currency == _ShopCurrency.gems ? gems : coins;
  }

  int quantityFor(String productId) {
    if (productId == 'boost_zero_fees') {
      return boostZeroFeesCount;
    }
    return consumables[productId] ?? 0;
  }

  int activeCountFor(String productId) {
    return activeConsumables[productId] ?? 0;
  }

  bool ownsProduct(_ShopProduct product) {
    if (product.isAvatar) {
      return avatarInventory.contains(product.id);
    }
    if (product.kind == _ShopProductKind.cosmetic ||
        product.kind == _ShopProductKind.collection) {
      return ownedCosmetics.contains(product.id);
    }
    return quantityFor(product.id) > 0;
  }

  bool isEquipped(_ShopProduct product) {
    if (product.isAvatar) {
      return currentAvatarId == product.id;
    }
    final slotKey = product.slotKey;
    if (slotKey == null) return false;
    return equippedCosmetics[slotKey] == product.id;
  }

  bool isUnlocked(_ShopProduct product) {
    if (completedScenarioCount < product.requiredCompletedScenarios) {
      return false;
    }
    if (product.requiredMacroStars > 0 &&
        (chapterStars['macro_cycles'] ?? 0) < product.requiredMacroStars) {
      return false;
    }
    if (product.requiresAnyGoldMedal && !hasAnyGoldMedal) {
      return false;
    }
    return true;
  }

  String unlockReason(_ShopProduct product) {
    if (completedScenarioCount < product.requiredCompletedScenarios) {
      return 'Requiert ${product.requiredCompletedScenarios} scénarios validés.';
    }
    if (product.requiredMacroStars > 0 &&
        (chapterStars['macro_cycles'] ?? 0) < product.requiredMacroStars) {
      return 'Requiert ${product.requiredMacroStars} étoiles au chapitre Macro & Cycles.';
    }
    if (product.requiresAnyGoldMedal && !hasAnyGoldMedal) {
      return 'Requiert au moins une médaille Gold en scénario.';
    }
    return product.unlockHint ?? 'Produit verrouillé pour le moment.';
  }
}

const List<_ShopProduct> _shopCatalog = <_ShopProduct>[
  _ShopProduct(
    id: '_bling',
    name: 'Avatar Bling Bling',
    description: 'Un look premium pour afficher votre aisance sur le hub Game.',
    price: 250,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.epic,
    gameLabel: 'Game Hub',
    usage: 'Avatar de profil',
    immediateImpact: 'Débloque un avatar exclusif directement équipable.',
    useLocation: 'À équiper depuis la boutique ou le hub Game.',
    primaryTab: _ShopTabKey.cosmetics,
    assetPath: 'assets/avatars/avatar_bling.png',
    gradient: <Color>[Color(0xFFF8D36F), Color(0xFF7B3F00)],
    slotKey: 'avatar',
  ),
  _ShopProduct(
    id: '_strong',
    name: 'Avatar Mr Strong',
    description:
        'Un profil carré pour les joueurs qui encaissent la volatilité.',
    price: 10000,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.rare,
    gameLabel: 'Game Hub',
    usage: 'Avatar de profil',
    immediateImpact: 'Débloque un avatar à équiper immédiatement.',
    useLocation: 'Visible sur le hub, les duels et les cartes sociales.',
    primaryTab: _ShopTabKey.cosmetics,
    assetPath: 'assets/avatars/avatar_strong.png',
    gradient: <Color>[Color(0xFF546E7A), Color(0xFF263238)],
    slotKey: 'avatar',
  ),
  _ShopProduct(
    id: '_geek',
    name: 'Avatar Geek',
    description: 'Le profil des joueurs analytiques et des perfectionnistes.',
    price: 2000,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.common,
    gameLabel: 'Game Hub',
    usage: 'Avatar de profil',
    immediateImpact: 'Débloque un avatar orienté analyste.',
    useLocation: 'À équiper depuis la boutique ou le hub Game.',
    primaryTab: _ShopTabKey.cosmetics,
    assetPath: 'assets/avatars/avatar_geek.png',
    gradient: <Color>[Color(0xFF80CBC4), Color(0xFF00695C)],
    slotKey: 'avatar',
  ),
  _ShopProduct(
    id: '_skelet',
    name: 'Avatar Skelet',
    description: 'Un style plus rare pour marquer votre profil sur les jeux.',
    price: 100,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.rare,
    gameLabel: 'Game Hub',
    usage: 'Avatar de profil',
    immediateImpact: 'Débloque un avatar collector.',
    useLocation: 'Visible sur le hub, les classements et les duels.',
    primaryTab: _ShopTabKey.cosmetics,
    assetPath: 'assets/avatars/avatar_skelet.png',
    gradient: <Color>[Color(0xFFB39DDB), Color(0xFF4527A0)],
    slotKey: 'avatar',
  ),
  _ShopProduct(
    id: '_javataimertoutelavie',
    name: 'Avatar Java t’aimer toute la vie',
    description:
        'Un avatar secret uniquement déblocable via le code cadeau associé.',
    price: 0,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.legendary,
    gameLabel: 'Game Hub',
    usage: 'Avatar de profil',
    immediateImpact: 'Débloque un avatar secret directement équipable.',
    useLocation: 'Visible sur le hub Game, Home et les cartes sociales.',
    primaryTab: _ShopTabKey.cosmetics,
    assetPath: 'assets/avatars/javataimertoutelavie.png',
    gradient: <Color>[Color(0xFFF9A825), Color(0xFFD84315)],
    slotKey: 'avatar',
  ),
  _ShopProduct(
    id: 'coins_pack',
    name: 'Sac de pièces',
    description: 'Renforce votre trésorerie de jeu avec un apport immédiat.',
    price: 10,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.currency,
    rarity: _ShopRarity.common,
    gameLabel: 'Multi-jeux',
    usage: 'Ressource immédiate',
    immediateImpact: 'Ajoute 500 pièces à votre solde instantanément.',
    useLocation: 'Disponible partout dans le hub Game.',
    primaryTab: _ShopTabKey.boosts,
    icon: Icons.monetization_on_rounded,
    gradient: <Color>[Color(0xFFFFD54F), Color(0xFFFF8F00)],
  ),
  _ShopProduct(
    id: 'boost_zero_fees',
    name: '0% de frais (12h)',
    description: 'Réduit à zéro les frais de trading pendant douze heures.',
    price: 20,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.boost,
    rarity: _ShopRarity.rare,
    gameLabel: 'Trading',
    usage: 'Boost temporaire',
    immediateImpact:
        'Ajoute un ticket de boost activable depuis l’écran de trade.',
    useLocation:
        'À utiliser depuis votre inventaire ou l’écran d’information titre.',
    primaryTab: _ShopTabKey.boosts,
    icon: Icons.flash_on_rounded,
    gradient: <Color>[Color(0xFF4DD0E1), Color(0xFF006064)],
  ),
  _ShopProduct(
    id: 'pack_analyste',
    name: 'Pack Analyste',
    description:
        'Le kit complet pour enchaîner les meilleurs runs Stock Analyst.',
    price: 80,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.bundle,
    rarity: _ShopRarity.epic,
    gameLabel: 'Stock Analyst',
    usage: 'Bundle premium',
    immediateImpact:
        'Ajoute des rerolls, indices et protections à votre inventaire.',
    useLocation: 'À consommer dans Stock Analyst.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.query_stats_rounded,
    gradient: <Color>[Color(0xFF4FC3F7), Color(0xFF1A237E)],
    bundle: <_ShopBundleContent>[
      _ShopBundleContent(productId: 'stock_ticker_reroll', quantity: 2),
      _ShopBundleContent(productId: 'stock_fundamental_hint', quantity: 2),
      _ShopBundleContent(productId: 'stock_streak_guard', quantity: 1),
      _ShopBundleContent(productId: 'stock_jackpot_ticket', quantity: 1),
    ],
  ),
  _ShopProduct(
    id: 'pack_news_runner',
    name: 'Pack News Runner',
    description:
        'Un bundle pour dominer les sessions Actu & Quiz et les runs monde.',
    price: 75,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.bundle,
    rarity: _ShopRarity.epic,
    gameLabel: 'Actu & Quiz',
    usage: 'Bundle premium',
    immediateImpact:
        'Ajoute des tickets d’analyse, rerolls et dossiers premium.',
    useLocation: 'À utiliser dans Actu & Quiz et MapMonde.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.public_rounded,
    gradient: <Color>[Color(0xFF26C6DA), Color(0xFF004D40)],
    bundle: <_ShopBundleContent>[
      _ShopBundleContent(productId: 'news_analyse_ticket', quantity: 1),
      _ShopBundleContent(productId: 'news_deck_reroll', quantity: 2),
      _ShopBundleContent(productId: 'news_second_wind', quantity: 1),
      _ShopBundleContent(productId: 'news_premium_dossier', quantity: 1),
    ],
  ),
  _ShopProduct(
    id: 'pack_scenario',
    name: 'Pack Scénario',
    description:
        'Le bundle tactique pour mieux gérer l’incertitude et le timing.',
    price: 85,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.bundle,
    rarity: _ShopRarity.epic,
    gameLabel: 'Scénarios',
    usage: 'Bundle premium',
    immediateImpact: 'Ajoute des jetons d’info, hedge et réduction de frais.',
    useLocation: 'À utiliser dans les scénarios de marché.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.alt_route_rounded,
    gradient: <Color>[Color(0xFFFFB74D), Color(0xFFE65100)],
    bundle: <_ShopBundleContent>[
      _ShopBundleContent(productId: 'scenario_info_token', quantity: 2),
      _ShopBundleContent(productId: 'scenario_hedge_ticket', quantity: 1),
      _ShopBundleContent(productId: 'scenario_fee_coupon', quantity: 1),
      _ShopBundleContent(productId: 'scenario_expert_pass', quantity: 1),
    ],
  ),
  _ShopProduct(
    id: 'pack_treasurer',
    name: 'Pack Trésorier',
    description:
        'Le bundle de cockpit pour sécuriser et optimiser vos arbitrages.',
    price: 70,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.bundle,
    rarity: _ShopRarity.epic,
    gameLabel: 'Compte à terme',
    usage: 'Bundle premium',
    immediateImpact: 'Ajoute des rerolls, shields et sorties anticipées.',
    useLocation: 'À utiliser dans le cockpit de trésorerie.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.account_balance_rounded,
    gradient: <Color>[Color(0xFF81C784), Color(0xFF1B5E20)],
    bundle: <_ShopBundleContent>[
      _ShopBundleContent(productId: 'treasury_extra_reroll', quantity: 2),
      _ShopBundleContent(productId: 'treasury_liquidity_shield', quantity: 1),
      _ShopBundleContent(productId: 'treasury_forecast_ticket', quantity: 1),
      _ShopBundleContent(productId: 'treasury_free_exit', quantity: 1),
    ],
  ),
  _ShopProduct(
    id: 'stock_ticker_reroll',
    name: 'Reroll de ticker',
    description:
        'Relance un nouveau titre parmi les plus exploitables du moteur fondamental.',
    price: 14,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Stock Analyst',
    usage: '1 relance de titre',
    immediateImpact:
        'Ajoute 1 ticket de relance à votre inventaire Stock Analyst.',
    useLocation: 'À utiliser sur l’onglet Résultat de Stock Analyst.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.change_circle_rounded,
    gradient: <Color>[Color(0xFF64B5F6), Color(0xFF283593)],
  ),
  _ShopProduct(
    id: 'stock_fundamental_hint',
    name: 'Indice fondamental',
    description:
        'Révèle un axe fort ou faible avant de verrouiller votre estimation.',
    price: 1100,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.common,
    gameLabel: 'Stock Analyst',
    usage: 'Indice ciblé',
    immediateImpact: 'Ajoute 1 indice pédagogique sur les sous-scores.',
    useLocation: 'À utiliser dans Stock Analyst avant la révélation.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.lightbulb_rounded,
    gradient: <Color>[Color(0xFFFFF176), Color(0xFFFF8F00)],
  ),
  _ShopProduct(
    id: 'stock_streak_guard',
    name: 'Protection de streak',
    description: 'Protège une série parfaite en cas d’erreur sur un run.',
    price: 18,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Stock Analyst',
    usage: '1 protection',
    immediateImpact:
        'Sécurise une partie de votre progression sur une tentative.',
    useLocation: 'À utiliser juste avant de valider votre guess.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.shield_rounded,
    gradient: <Color>[Color(0xFF80DEEA), Color(0xFF006064)],
  ),
  _ShopProduct(
    id: 'stock_jackpot_ticket',
    name: 'Ticket bonus jackpot',
    description:
        'Double le bonus jackpot si vous terminez dans la fenêtre parfaite.',
    price: 22,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.epic,
    gameLabel: 'Stock Analyst',
    usage: '1 ticket jackpot',
    immediateImpact:
        'Ajoute un multiplicateur de récompense à votre inventaire.',
    useLocation: 'À activer avant la correction finale dans Stock Analyst.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.emoji_events_rounded,
    gradient: <Color>[Color(0xFFFFE082), Color(0xFFEF6C00)],
  ),
  _ShopProduct(
    id: 'news_analyse_ticket',
    name: 'Session Analyse offerte',
    description: 'Débloque une entrée Analyse sans coût supplémentaire.',
    price: 20,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Actu & Quiz',
    usage: '1 entrée premium',
    immediateImpact: 'Ajoute un ticket d’entrée premium au mode Analyse.',
    useLocation: 'À utiliser depuis la sélection de session Actu & Quiz.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.article_rounded,
    gradient: <Color>[Color(0xFF26C6DA), Color(0xFF1565C0)],
  ),
  _ShopProduct(
    id: 'news_deck_reroll',
    name: 'Reroll de deck',
    description:
        'Remplace votre deck du jour par une nouvelle sélection d’articles.',
    price: 900,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.common,
    gameLabel: 'Actu & Quiz',
    usage: '1 nouveau deck',
    immediateImpact: 'Ajoute une relance de deck à votre inventaire news.',
    useLocation: 'À utiliser avant le lancement d’une session Actu & Quiz.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.refresh_rounded,
    gradient: <Color>[Color(0xFF80CBC4), Color(0xFF004D40)],
  ),
  _ShopProduct(
    id: 'news_second_wind',
    name: 'Second souffle',
    description: 'Annule une erreur pendant un run pour préserver votre score.',
    price: 16,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Actu & Quiz',
    usage: '1 filet de sécurité',
    immediateImpact: 'Ajoute une reprise immédiate en cas de mauvais choix.',
    useLocation: 'À activer pendant une session Actu & Quiz.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.replay_circle_filled_rounded,
    gradient: <Color>[Color(0xFF4DB6AC), Color(0xFF00695C)],
  ),
  _ShopProduct(
    id: 'news_premium_dossier',
    name: 'Dossier premium thématique',
    description: 'Ajoute du contexte sur un thème macro avant de commencer.',
    price: 18,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.epic,
    gameLabel: 'Actu & Quiz',
    usage: 'Dossier d’aide',
    immediateImpact: 'Ajoute une fiche macro à votre session du jour.',
    useLocation: 'À utiliser dans Actu & Quiz ou MapMonde.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.menu_book_rounded,
    gradient: <Color>[Color(0xFFB2EBF2), Color(0xFF00838F)],
  ),
  _ShopProduct(
    id: 'scenario_info_token',
    name: 'Jeton d’info',
    description:
        'Révèle une information additionnelle sur un acte de scénario.',
    price: 15,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Scénarios',
    usage: '1 info bonus',
    immediateImpact: 'Ajoute un reveal tactique à votre inventaire.',
    useLocation: 'À utiliser sur un acte de scénario.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.info_outline_rounded,
    gradient: <Color>[Color(0xFFFFCC80), Color(0xFFE65100)],
  ),
  _ShopProduct(
    id: 'scenario_hedge_ticket',
    name: 'Hedge ticket',
    description:
        'Ajoute une couverture ponctuelle sans dégrader votre allocation.',
    price: 17,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Scénarios',
    usage: '1 couverture',
    immediateImpact: 'Ajoute un joker défensif à un run.',
    useLocation: 'À utiliser pendant une décision de réallocation.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.security_rounded,
    gradient: <Color>[Color(0xFFFFB74D), Color(0xFFBF360C)],
  ),
  _ShopProduct(
    id: 'scenario_fee_coupon',
    name: 'Réduction de frais',
    description:
        'Réduit le coût d’un run pour préserver votre performance nette.',
    price: 950,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.common,
    gameLabel: 'Scénarios',
    usage: 'Coupon 1 run',
    immediateImpact: 'Ajoute un coupon de frais réduit à votre inventaire.',
    useLocation: 'À utiliser au briefing d’un scénario.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.sell_rounded,
    gradient: <Color>[Color(0xFFFFE0B2), Color(0xFFE65100)],
  ),
  _ShopProduct(
    id: 'scenario_expert_pass',
    name: 'Pass Mutateur expert',
    description:
        'Ouvre une partie avec mutateur expert sans brûler votre meilleur clear.',
    price: 24,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.epic,
    gameLabel: 'Scénarios',
    usage: '1 run expert',
    immediateImpact: 'Ajoute un accès ponctuel au mutateur expert.',
    useLocation: 'À utiliser dans les scénarios de marché.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.bolt_rounded,
    gradient: <Color>[Color(0xFFFFAB91), Color(0xFFBF360C)],
  ),
  _ShopProduct(
    id: 'treasury_extra_reroll',
    name: 'Reroll supplémentaire',
    description: 'Ajoute une relance d’offres à votre board quotidien.',
    price: 800,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.common,
    gameLabel: 'Compte à terme',
    usage: '1 relance',
    immediateImpact: 'Ajoute une relance de board à votre cockpit.',
    useLocation: 'À utiliser sur le tableau d’offres de trésorerie.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.sync_alt_rounded,
    gradient: <Color>[Color(0xFFA5D6A7), Color(0xFF2E7D32)],
  ),
  _ShopProduct(
    id: 'treasury_liquidity_shield',
    name: 'Bouclier de liquidité',
    description: 'Absorbe un choc de cash sans casser un dépôt flexible.',
    price: 18,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Compte à terme',
    usage: '1 protection',
    immediateImpact: 'Ajoute un filet de sécurité de liquidité.',
    useLocation: 'À utiliser avant la résolution d’un événement de trésorerie.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.health_and_safety_rounded,
    gradient: <Color>[Color(0xFFC5E1A5), Color(0xFF1B5E20)],
  ),
  _ShopProduct(
    id: 'treasury_forecast_ticket',
    name: 'Prévision du régime',
    description: 'Révèle plus tôt le prochain régime de marché de la courbe.',
    price: 14,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.rare,
    gameLabel: 'Compte à terme',
    usage: '1 aperçu',
    immediateImpact: 'Ajoute une prévision exploitable sur le board suivant.',
    useLocation: 'À utiliser dans le cockpit de trésorerie.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.timeline_rounded,
    gradient: <Color>[Color(0xFFB2DFDB), Color(0xFF004D40)],
  ),
  _ShopProduct(
    id: 'treasury_free_exit',
    name: 'Retrait anticipé gratuit',
    description:
        'Permet de casser une position sans pénalité sur un besoin urgent.',
    price: 20,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.consumable,
    rarity: _ShopRarity.epic,
    gameLabel: 'Compte à terme',
    usage: '1 sortie gratuite',
    immediateImpact: 'Ajoute une sortie anticipée gratuite à votre réserve.',
    useLocation: 'À utiliser sur une position de trésorerie active.',
    primaryTab: _ShopTabKey.games,
    icon: Icons.exit_to_app_rounded,
    gradient: <Color>[Color(0xFFDCEDC8), Color(0xFF33691E)],
  ),
  _ShopProduct(
    id: 'frame_oracle',
    name: 'Cadre Oracle',
    description: 'Cadre premium pour mettre en valeur votre profil de joueur.',
    price: 3500,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.rare,
    gameLabel: 'Game Hub',
    usage: 'Cadre de profil',
    immediateImpact: 'Débloque un cadre d’avatar à équiper.',
    useLocation: 'Visible sur le hub Game et les surfaces sociales.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.crop_square_rounded,
    gradient: <Color>[Color(0xFFFFE082), Color(0xFF6D4C41)],
    slotKey: 'frame',
  ),
  _ShopProduct(
    id: 'badge_market_pulse',
    name: 'Badge Market Pulse',
    description: 'Badge animé pour signaler votre activité sur les mini-jeux.',
    price: 30,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.epic,
    gameLabel: 'Game Hub',
    usage: 'Badge animé',
    immediateImpact: 'Débloque un badge dynamique équipable.',
    useLocation: 'Visible sur vos surfaces de jeu et de classement.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.offline_bolt_rounded,
    gradient: <Color>[Color(0xFFCE93D8), Color(0xFF4A148C)],
    slotKey: 'badge',
  ),
  _ShopProduct(
    id: 'skin_glassfolio',
    name: 'Skin Glassfolio',
    description: 'Habillage de cartes plus glossy pour le hub Game.',
    price: 2600,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.rare,
    gameLabel: 'Game Hub',
    usage: 'Skin de cartes',
    immediateImpact:
        'Débloque une nouvelle peau visuelle pour les cartes de jeu.',
    useLocation: 'À équiper dans la boutique pour le hub Game.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.dashboard_customize_rounded,
    gradient: <Color>[Color(0xFF90CAF9), Color(0xFF1A237E)],
    slotKey: 'card_skin',
  ),
  _ShopProduct(
    id: 'theme_opening_bell',
    name: 'Thème Opening Bell',
    description: 'Palette dorée et blanche inspirée des ouvertures de marché.',
    price: 45,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.epic,
    gameLabel: 'Game Hub',
    usage: 'Thème dashboard',
    immediateImpact: 'Débloque un thème visuel pour le hub de jeu.',
    useLocation: 'À équiper depuis l’inventaire cosmétique.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.palette_rounded,
    gradient: <Color>[Color(0xFFFFF59D), Color(0xFF6A1B9A)],
    slotKey: 'theme',
  ),
  _ShopProduct(
    id: 'banner_duel_macro',
    name: 'Bannière Duel Macro',
    description: 'Habillage de bannière pour afficher votre style en duel.',
    price: 4200,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.cosmetic,
    rarity: _ShopRarity.rare,
    gameLabel: 'Duels',
    usage: 'Bannière duel',
    immediateImpact:
        'Débloque une bannière affichable sur vos surfaces sociales.',
    useLocation: 'À équiper depuis votre inventaire boutique.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.flag_rounded,
    gradient: <Color>[Color(0xFFEF9A9A), Color(0xFF880E4F)],
    slotKey: 'banner',
  ),
  _ShopProduct(
    id: 'trophy_macro_cycles',
    name: 'Trophée Macro & Cycles',
    description:
        'Pièce de collection réservée aux joueurs qui ont déjà validé leurs premières simulations.',
    price: 2400,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.collection,
    rarity: _ShopRarity.rare,
    gameLabel: 'Collection',
    usage: 'Vitrine de progression',
    immediateImpact: 'Ajoute un trophée de collection à votre vitrine.',
    useLocation: 'À afficher dans votre inventaire cosmétique.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.workspace_premium_rounded,
    gradient: <Color>[Color(0xFFFFE082), Color(0xFF5D4037)],
    slotKey: 'showcase',
    requiredCompletedScenarios: 3,
    unlockHint: 'Validez 3 scénarios pour l’acheter.',
  ),
  _ShopProduct(
    id: 'seal_gold_run',
    name: 'Sceau Gold',
    description:
        'Un sceau réservé aux joueurs qui ont déjà décroché une médaille Gold.',
    price: 40,
    currency: _ShopCurrency.gems,
    kind: _ShopProductKind.collection,
    rarity: _ShopRarity.legendary,
    gameLabel: 'Collection',
    usage: 'Sceau de prestige',
    immediateImpact: 'Débloque un sceau premium pour votre vitrine.',
    useLocation: 'À équiper dans votre collection de profil.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.verified_rounded,
    gradient: <Color>[Color(0xFFFFD54F), Color(0xFF6A1B9A)],
    slotKey: 'seal',
    requiresAnyGoldMedal: true,
    unlockHint: 'Gagnez une médaille Gold en scénario pour l’acheter.',
  ),
  _ShopProduct(
    id: 'showcase_macro_lab',
    name: 'Vitrine Macro Lab',
    description:
        'Une vitrine de progression réservée aux joueurs avancés du premier chapitre.',
    price: 3800,
    currency: _ShopCurrency.coins,
    kind: _ShopProductKind.collection,
    rarity: _ShopRarity.epic,
    gameLabel: 'Collection',
    usage: 'Vitrine avancée',
    immediateImpact: 'Débloque une vitrine de progression plus ambitieuse.',
    useLocation: 'À afficher depuis l’inventaire cosmétique.',
    primaryTab: _ShopTabKey.cosmetics,
    icon: Icons.auto_graph_rounded,
    gradient: <Color>[Color(0xFFB2DFDB), Color(0xFF00695C)],
    slotKey: 'showcase',
    requiredMacroStars: 9,
    unlockHint: 'Atteignez 9 étoiles sur Macro & Cycles.',
  ),
];

final Map<String, _ShopProduct> _catalogById = <String, _ShopProduct>{
  for (final product in _shopCatalog) product.id: product,
};

const List<String> _featuredBundleIds = <String>[
  'pack_analyste',
  'pack_news_runner',
  'pack_scenario',
  'pack_treasurer',
];

const Map<String, List<String>> _gameProductIds = <String, List<String>>{
  'Stock Analyst': <String>[
    'pack_analyste',
    'stock_ticker_reroll',
    'stock_fundamental_hint',
    'stock_streak_guard',
    'stock_jackpot_ticket',
  ],
  'Actu & Quiz': <String>[
    'pack_news_runner',
    'news_analyse_ticket',
    'news_deck_reroll',
    'news_second_wind',
    'news_premium_dossier',
  ],
  'Scénarios': <String>[
    'pack_scenario',
    'scenario_info_token',
    'scenario_hedge_ticket',
    'scenario_fee_coupon',
    'scenario_expert_pass',
  ],
  'Compte à terme': <String>[
    'pack_treasurer',
    'treasury_extra_reroll',
    'treasury_liquidity_shield',
    'treasury_forecast_ticket',
    'treasury_free_exit',
  ],
};

const List<String> _boostProductIds = <String>[
  'coins_pack',
  'boost_zero_fees',
  'stock_fundamental_hint',
  'news_deck_reroll',
  'scenario_fee_coupon',
  'treasury_extra_reroll',
];

const List<String> _cosmeticProductIds = <String>[
  '_bling',
  '_strong',
  '_geek',
  '_skelet',
  'frame_oracle',
  'badge_market_pulse',
  'skin_glassfolio',
  'theme_opening_bell',
  'banner_duel_macro',
  'trophy_macro_cycles',
  'seal_gold_run',
  'showcase_macro_lab',
];

class ShopPage extends StatefulWidget {
  const ShopPage({
    super.key,
    this.initialTabIndex = 0,
    this.highlightProductIds = const <String>[],
    this.contextMessage,
  });

  final int initialTabIndex;
  final List<String> highlightProductIds;
  final String? contextMessage;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final TextEditingController _codeController = TextEditingController();
  final Set<String> _pendingPurchaseProductIds = <String>{};
  bool _isRedeeming = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  final Map<String, Map<String, dynamic>> _redeemableCodes = {
    'FABFINTECH': {
      'itemId': '_easteregg',
      'type': 'avatar',
      'successMsg': 'Code valide ! Avatar Easter Egg débloqué.',
    },
    'JAVATAIMER': {
      'itemId': '_javataimertoutelavie',
      'type': 'avatar',
      'successMsg': 'Code valide ! SNEE ! SNEE ! SNEE !',
    },
    'SEXTOYSBOY': {
      'itemId': '_sydsteregg',
      'type': 'avatar',
      'successMsg': 'Code valide ! Avatar Syd débloqué.',
    },
    'STARQUINT': {
      'itemId': '_quintprime',
      'type': 'avatar',
      'successMsg': 'Code valide ! Avatar Quint. Prime débloqué.',
    },
    'BEYONDBIG': {
      'itemId': '_beyondbig',
      'type': 'avatar',
      'successMsg': 'Code valide ! C\'est gros !',
    },
    'GAY': {
      'itemId': '_gay',
      'type': 'avatar',
      'successMsg': 'Code valide ! C\'est gay !',
    },
    'GROSELINE': {
      'itemId': '_groseline',
      'type': 'avatar',
      'successMsg': 'Code valide ! Attention à l\'IMC.',
    },
    'MONEY': {
      'itemId': 'money_cheat',
      'type': 'coins',
      'amount': 1000000,
      'successMsg': 'Code valide ! +1,000,000 pièces.',
    },
    'GEMMES': {
      'itemId': 'gems_cheat',
      'type': 'gems',
      'amount': 100000,
      'successMsg': 'Code valide ! +100,000 gemmes.',
    },
  };

  static const Color _bg = backgroundColor;
  static const Color _ink = textColor;
  static const Color _line = Color(0xFFE6E8EB);
  static const Color _chipBg = Color(0xFFF0F1F3);
  static const Color _wine = detailsColor2;
  static const LinearGradient _accentGradient = LinearGradient(
    colors: <Color>[detailsColor1, detailsColor2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _progressRef(String uid) {
    return _userRef(uid).collection('games').doc('progress');
  }

  DocumentReference<Map<String, dynamic>> _shopRef(String uid) {
    return _userRef(uid).collection('games').doc('shop');
  }

  DocumentReference<Map<String, dynamic>> _campaignRef(String uid) {
    return _userRef(uid).collection('games').doc('scenario_campaign');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialTab = widget.initialTabIndex.clamp(0, 4);

    return DefaultTabController(
      length: 5,
      initialIndex: initialTab,
      child: Scaffold(
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
                    gradient: _accentGradient,
                  ),
                ),
              ),
            ),
          ),
        ),
        body:
            user == null
                ? const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 24),
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
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _userRef(user.uid).snapshots(),
                  builder: (context, userSnapshot) {
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: _progressRef(user.uid).snapshots(),
                      builder: (context, progressSnapshot) {
                        return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream: _shopRef(user.uid).snapshots(),
                          builder: (context, shopSnapshot) {
                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: _campaignRef(user.uid).snapshots(),
                              builder: (context, campaignSnapshot) {
                                if (userSnapshot.hasError ||
                                    progressSnapshot.hasError ||
                                    shopSnapshot.hasError ||
                                    campaignSnapshot.hasError) {
                                  return const SafeArea(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: _PremiumStateCard(
                                        icon: Icons.error_outline_rounded,
                                        title: 'Boutique indisponible',
                                        message:
                                            'Impossible de charger la boutique pour le moment.',
                                      ),
                                    ),
                                  );
                                }

                                if (!userSnapshot.hasData ||
                                    !progressSnapshot.hasData ||
                                    !shopSnapshot.hasData ||
                                    !campaignSnapshot.hasData) {
                                  return const _ShopLoadingView();
                                }

                                final dayKey = _shopDayKey(_now);
                                final viewData = _ShopViewData.fromMaps(
                                  userData: userSnapshot.data?.data(),
                                  progressData: progressSnapshot.data?.data(),
                                  shopData: shopSnapshot.data?.data(),
                                  campaignData: campaignSnapshot.data?.data(),
                                  dayKey: dayKey,
                                );
                                final offers = _shopDailyOffersForDay(
                                  uid: user.uid,
                                  dayKey: dayKey,
                                );
                                final highlightedProducts =
                                    widget.highlightProductIds
                                        .map((id) => _catalogById[id])
                                        .whereType<_ShopProduct>()
                                        .toList();

                                return SafeArea(
                                  bottom: false,
                                  child: NestedScrollView(
                                    headerSliverBuilder: (
                                      context,
                                      innerBoxIsScrolled,
                                    ) {
                                      return <Widget>[
                                        SliverToBoxAdapter(
                                          child: Column(
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      8,
                                                      16,
                                                      0,
                                                    ),
                                                child: _buildBalanceCard(
                                                  viewData,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      14,
                                                      16,
                                                      0,
                                                    ),
                                                child: _ShopHeroBanner(
                                                  offerCount: offers.length,
                                                  questState:
                                                      viewData.questState,
                                                  nextRefreshLabel:
                                                      _timeUntilNextResetLabel(
                                                        _now,
                                                      ),
                                                  contextMessage:
                                                      widget.contextMessage,
                                                  highlightedCount:
                                                      highlightedProducts
                                                          .length,
                                                ),
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  16,
                                                  14,
                                                  16,
                                                  10,
                                                ),
                                                child: _ShopTabStrip(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ];
                                    },
                                    body: TabBarView(
                                      children: [
                                        _buildFeaturedTab(
                                          context: context,
                                          uid: user.uid,
                                          viewData: viewData,
                                          offers: offers,
                                          highlightedProducts:
                                              highlightedProducts,
                                        ),
                                        _buildGamesTab(
                                          context: context,
                                          uid: user.uid,
                                          viewData: viewData,
                                          offers: offers,
                                        ),
                                        _buildCosmeticsTab(
                                          context: context,
                                          uid: user.uid,
                                          viewData: viewData,
                                          offers: offers,
                                        ),
                                        _buildBoostsTab(
                                          context: context,
                                          uid: user.uid,
                                          viewData: viewData,
                                          offers: offers,
                                        ),
                                        _buildInventoryTab(
                                          context: context,
                                          uid: user.uid,
                                          viewData: viewData,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildBalanceCard(_ShopViewData viewData) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        gradient: _accentGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BalancePill(
                  icon: Icons.diamond_rounded,
                  iconColor: Colors.cyanAccent,
                  label: '${viewData.gems}',
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
                  label: '${viewData.coins}',
                  suffix: 'Pièces',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TopInfoChip(
                icon: Icons.local_offer_rounded,
                label: 'Offres du jour',
              ),
              _TopInfoChip(
                icon: Icons.inventory_2_rounded,
                label:
                    '${viewData.consumables.values.fold<int>(viewData.boostZeroFeesCount, (total, value) => total + value)} consommables',
              ),
              _TopInfoChip(
                icon: Icons.workspace_premium_rounded,
                label:
                    viewData.questState.isComplete
                        ? 'Quête boutique prête'
                        : 'Quête boutique active',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTab({
    required BuildContext context,
    required String uid,
    required _ShopViewData viewData,
    required List<_ShopDailyOffer> offers,
    required List<_ShopProduct> highlightedProducts,
  }) {
    final featuredProducts =
        _featuredBundleIds
            .map((id) => _catalogById[id])
            .whereType<_ShopProduct>()
            .toList();
    final bestOffer =
        offers
            .where((offer) => offer.isBestOffer)
            .map((offer) => _catalogById[offer.productId])
            .whereType<_ShopProduct>()
            .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (bestOffer != null) ...[
          _DailyOfferHeroCard(
            product: bestOffer,
            offer: offers.firstWhere((item) => item.productId == bestOffer.id),
            nextRefreshLabel: _timeUntilNextResetLabel(_now),
            onTap:
                () => _handleProductTap(
                  context: context,
                  uid: uid,
                  product: bestOffer,
                  viewData: viewData,
                  offers: offers,
                ),
          ),
          const SizedBox(height: 16),
        ],
        if (highlightedProducts.isNotEmpty) ...[
          _SectionHeader(
            title: 'Suggestions du moment',
            subtitle:
                widget.contextMessage ??
                'Sélection contextuelle pour vous aider au bon moment.',
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(height: 10),
          ...highlightedProducts.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShopProductCard(
                product: product,
                viewData: viewData,
                offer: _offerForProduct(product.id, offers),
                onPrimaryAction:
                    () => _handleProductTap(
                      context: context,
                      uid: uid,
                      product: product,
                      viewData: viewData,
                      offers: offers,
                    ),
                onSecondaryAction:
                    _canEquipProduct(product, viewData)
                        ? () => _equipProduct(
                          context: context,
                          uid: uid,
                          product: product,
                        )
                        : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        const _DailyRewardShopSection(),
        const SizedBox(height: 18),
        _ShopQuestCard(
          questState: viewData.questState,
          onClaim:
              viewData.questState.isComplete && !viewData.questState.claimed
                  ? () => _claimShopQuest(context, uid, viewData.questState)
                  : null,
          nextRefreshLabel: _timeUntilNextResetLabel(_now),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Offres du jour',
          subtitle:
              '3 à 5 deals quotidiens avec remise visible et meilleure offre mise en avant.',
          icon: Icons.local_offer_rounded,
        ),
        const SizedBox(height: 10),
        _DailyOffersCarousel(
          offers: offers,
          products: _catalogById,
          onTap:
              (product) => _handleProductTap(
                context: context,
                uid: uid,
                product: product,
                viewData: viewData,
                offers: offers,
              ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Bundles vedette',
          subtitle: 'Des packs complets pour chaque mini-jeu.',
          icon: Icons.inventory_2_rounded,
        ),
        const SizedBox(height: 10),
        ...featuredProducts.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShopProductCard(
              product: product,
              viewData: viewData,
              offer: _offerForProduct(product.id, offers),
              onPrimaryAction:
                  () => _handleProductTap(
                    context: context,
                    uid: uid,
                    product: product,
                    viewData: viewData,
                    offers: offers,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const _SectionHeader(
          title: 'Code cadeau',
          subtitle: 'Entre un code pour débloquer des récompenses cachées.',
          icon: Icons.card_giftcard_rounded,
        ),
        const SizedBox(height: 10),
        _buildRedeemSection(context, uid, viewData.avatarInventory.toList()),
      ],
    );
  }

  Widget _buildGamesTab({
    required BuildContext context,
    required String uid,
    required _ShopViewData viewData,
    required List<_ShopDailyOffer> offers,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children:
          _gameProductIds.entries.expand((entry) {
            final products =
                entry.value
                    .map((id) => _catalogById[id])
                    .whereType<_ShopProduct>()
                    .toList();
            return <Widget>[
              _SectionHeader(
                title: entry.key,
                subtitle: _gameSectionSubtitle(entry.key),
                icon: _gameSectionIcon(entry.key),
              ),
              const SizedBox(height: 10),
              ...products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ShopProductCard(
                    product: product,
                    viewData: viewData,
                    offer: _offerForProduct(product.id, offers),
                    onPrimaryAction:
                        () => _handleProductTap(
                          context: context,
                          uid: uid,
                          product: product,
                          viewData: viewData,
                          offers: offers,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ];
          }).toList(),
    );
  }

  Widget _buildCosmeticsTab({
    required BuildContext context,
    required String uid,
    required _ShopViewData viewData,
    required List<_ShopDailyOffer> offers,
  }) {
    final avatars =
        _cosmeticProductIds
            .map((id) => _catalogById[id])
            .whereType<_ShopProduct>()
            .where((product) => product.isAvatar)
            .where((product) => !viewData.ownsProduct(product))
            .toList();
    final cosmetics =
        _cosmeticProductIds
            .map((id) => _catalogById[id])
            .whereType<_ShopProduct>()
            .where(
              (product) =>
                  !product.isAvatar &&
                  product.kind == _ShopProductKind.cosmetic,
            )
            .toList();
    final collections =
        _cosmeticProductIds
            .map((id) => _catalogById[id])
            .whereType<_ShopProduct>()
            .where((product) => product.kind == _ShopProductKind.collection)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (avatars.isNotEmpty) ...[
          const _SectionHeader(
            title: 'Avatars',
            subtitle:
                'Personnalise ton profil de joueur et équipe ton avatar favori.',
            icon: Icons.face_retouching_natural_rounded,
          ),
          const SizedBox(height: 10),
          ...avatars.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShopProductCard(
                product: product,
                viewData: viewData,
                offer: _offerForProduct(product.id, offers),
                onPrimaryAction:
                    _canEquipProduct(product, viewData)
                        ? () => _equipProduct(
                          context: context,
                          uid: uid,
                          product: product,
                        )
                        : () => _handleProductTap(
                          context: context,
                          uid: uid,
                          product: product,
                          viewData: viewData,
                          offers: offers,
                        ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        const _SectionHeader(
          title: 'Cosmétiques du hub',
          subtitle: 'Cadres, badges, skins et thèmes à équiper.',
          icon: Icons.style_rounded,
        ),
        const SizedBox(height: 10),
        ...cosmetics.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShopProductCard(
              product: product,
              viewData: viewData,
              offer: _offerForProduct(product.id, offers),
              onPrimaryAction:
                  _canEquipProduct(product, viewData)
                      ? () => _equipProduct(
                        context: context,
                        uid: uid,
                        product: product,
                      )
                      : () => _handleProductTap(
                        context: context,
                        uid: uid,
                        product: product,
                        viewData: viewData,
                        offers: offers,
                      ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const _SectionHeader(
          title: 'Collection',
          subtitle:
              'Trophées et vitrines à débloquer par progression et performances.',
          icon: Icons.workspace_premium_rounded,
        ),
        const SizedBox(height: 10),
        ...collections.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShopProductCard(
              product: product,
              viewData: viewData,
              offer: _offerForProduct(product.id, offers),
              onPrimaryAction:
                  _canEquipProduct(product, viewData)
                      ? () => _equipProduct(
                        context: context,
                        uid: uid,
                        product: product,
                      )
                      : () => _handleProductTap(
                        context: context,
                        uid: uid,
                        product: product,
                        viewData: viewData,
                        offers: offers,
                      ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoostsTab({
    required BuildContext context,
    required String uid,
    required _ShopViewData viewData,
    required List<_ShopDailyOffer> offers,
  }) {
    final products =
        _boostProductIds
            .map((id) => _catalogById[id])
            .whereType<_ShopProduct>()
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const _SectionHeader(
          title: 'Boosts & utilitaires',
          subtitle:
              'Des achats en gemmes et en pièces pour fluidifier vos runs et votre trésorerie.',
          icon: Icons.flash_on_rounded,
        ),
        const SizedBox(height: 10),
        ...products.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShopProductCard(
              product: product,
              viewData: viewData,
              offer: _offerForProduct(product.id, offers),
              onPrimaryAction:
                  () => _handleProductTap(
                    context: context,
                    uid: uid,
                    product: product,
                    viewData: viewData,
                    offers: offers,
                  ),
              onSecondaryAction:
                  product.id == 'boost_zero_fees' &&
                          viewData.quantityFor(product.id) > 0
                      ? () => _useConsumable(
                        context: context,
                        uid: uid,
                        product: product,
                        viewData: viewData,
                      )
                      : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab({
    required BuildContext context,
    required String uid,
    required _ShopViewData viewData,
  }) {
    final inventoryProducts =
        _shopCatalog
            .where(
              (product) =>
                  product.isConsumable && viewData.quantityFor(product.id) > 0,
            )
            .toList();
    final activeProducts =
        _shopCatalog
            .where((product) => viewData.activeCountFor(product.id) > 0)
            .toList();
    final ownedCosmetics =
        _shopCatalog
            .where(
              (product) =>
                  (product.kind == _ShopProductKind.cosmetic ||
                      product.kind == _ShopProductKind.collection) &&
                  viewData.ownsProduct(product),
            )
            .toList();
    final ownedAvatars =
        _shopCatalog
            .where(
              (product) => product.isAvatar && viewData.ownsProduct(product),
            )
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _InventoryStatusCard(
          activeCount: activeProducts.fold<int>(
            viewData.zeroFeesActive ? 1 : 0,
            (total, product) => total + viewData.activeCountFor(product.id),
          ),
          zeroFeesActive: viewData.zeroFeesActive,
          zeroFeesLabel:
              viewData.zeroFeesActive && viewData.zeroFeesUntil != null
                  ? 'Actif jusqu’à ${_formatShortTime(viewData.zeroFeesUntil!.toDate())}'
                  : 'Aucun boost de frais actif',
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Consommables',
          subtitle:
              inventoryProducts.isEmpty && viewData.boostZeroFeesCount == 0
                  ? 'Ton inventaire est vide pour le moment.'
                  : 'Chaque item acheté affiche son compteur, son usage et son bouton Utiliser.',
          icon: Icons.inventory_2_rounded,
        ),
        const SizedBox(height: 10),
        if (viewData.boostZeroFeesCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InventoryProductCard(
              product: _catalogById['boost_zero_fees']!,
              quantity: viewData.boostZeroFeesCount,
              activeCount: viewData.zeroFeesActive ? 1 : 0,
              onUse:
                  () => _useConsumable(
                    context: context,
                    uid: uid,
                    product: _catalogById['boost_zero_fees']!,
                    viewData: viewData,
                  ),
            ),
          ),
        if (inventoryProducts.isEmpty && viewData.boostZeroFeesCount == 0)
          const _EmptyInventoryCard(
            title: 'Aucun consommable',
            message:
                'Achetez des tickets, rerolls et boosts dans les onglets Jeux ou Boosts.',
          )
        else
          ...inventoryProducts.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InventoryProductCard(
                product: product,
                quantity: viewData.quantityFor(product.id),
                activeCount: viewData.activeCountFor(product.id),
                onUse:
                    () => _useConsumable(
                      context: context,
                      uid: uid,
                      product: product,
                      viewData: viewData,
                    ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Cosmétiques équipés',
          subtitle:
              'Visualise ce qui est déjà actif sur ton hub et tes surfaces sociales.',
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(height: 10),
        if (ownedCosmetics.where(viewData.isEquipped).isEmpty &&
            ownedAvatars.where(viewData.isEquipped).isEmpty)
          const _EmptyInventoryCard(
            title: 'Rien d’équipé',
            message:
                'Achète ou équipe un avatar, un cadre, un badge ou un thème depuis l’onglet Cosmétiques.',
          )
        else ...[
          ...ownedAvatars
              .where(viewData.isEquipped)
              .map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OwnedCosmeticCard(
                    product: product,
                    isEquipped: true,
                    onEquip: null,
                  ),
                ),
              ),
          ...ownedCosmetics
              .where(viewData.isEquipped)
              .map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OwnedCosmeticCard(
                    product: product,
                    isEquipped: true,
                    onEquip: null,
                  ),
                ),
              ),
        ],
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Possédé',
          subtitle:
              'Tes cosmétiques et pièces de collection prêtes à être équipées.',
          icon: Icons.style_rounded,
        ),
        const SizedBox(height: 10),
        if (ownedCosmetics.isEmpty && ownedAvatars.isEmpty)
          const _EmptyInventoryCard(
            title: 'Aucun cosmétique',
            message: 'Passe à l’onglet Cosmétiques pour enrichir ton profil.',
          )
        else ...[
          ...ownedAvatars.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OwnedCosmeticCard(
                product: product,
                isEquipped: viewData.isEquipped(product),
                onEquip:
                    viewData.isEquipped(product)
                        ? null
                        : () => _equipProduct(
                          context: context,
                          uid: uid,
                          product: product,
                        ),
              ),
            ),
          ),
          ...ownedCosmetics.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OwnedCosmeticCard(
                product: product,
                isEquipped: viewData.isEquipped(product),
                onEquip:
                    viewData.isEquipped(product)
                        ? null
                        : () => _equipProduct(
                          context: context,
                          uid: uid,
                          product: product,
                        ),
              ),
            ),
          ),
        ],
      ],
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
              gradient: _accentGradient,
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
            loading: _isRedeeming,
            onTap:
                _isRedeeming
                    ? null
                    : () => _redeemCode(context, uid, inventory),
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
    final inputCode = _codeController.text.trim().toUpperCase();
    if (inputCode.isEmpty) return;

    if (inputCode == 'ADMIN') {
      setState(() => _isRedeeming = true);
      try {
        final userRef = _userRef(uid);
        final doc = await userRef.get();
        final bool currentAdmin = (doc.data()?['isAdmin'] as bool?) ?? false;
        final bool newStatus = !currentAdmin;
        await userRef.set({'isAdmin': newStatus}, SetOptions(merge: true));
        if (!context.mounted) return;
        _showSnackBar(
          context,
          newStatus ? 'Mode Admin activé.' : 'Mode Admin désactivé.',
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        );
        _codeController.clear();
      } catch (error) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Erreur technique : $error',
            backgroundColor: Colors.red,
          );
        }
      } finally {
        if (mounted) setState(() => _isRedeeming = false);
      }
      return;
    }

    final rewardData = _redeemableCodes[inputCode];
    debugPrint('[Redeem] code="$inputCode" found=${rewardData != null}');
    if (rewardData == null) {
      _showSnackBar(
        context,
        'Code invalide ou expiré.',
        backgroundColor: Colors.red,
      );
      return;
    }

    final itemId = rewardData['itemId'] as String;
    final type = rewardData['type'] as String? ?? 'avatar';
    debugPrint(
      '[Redeem] itemId=$itemId type=$type inventorySize=${inventory.length} alreadyOwned=${inventory.contains(itemId)}',
    );
    if (type == 'avatar' && inventory.contains(itemId)) {
      _showSnackBar(context, 'Vous possédez déjà cette récompense.');
      _codeController.clear();
      return;
    }

    setState(() => _isRedeeming = true);
    try {
      final userDocRef = _userRef(uid);
      final progressRef = _progressRef(uid);
      debugPrint('[Redeem] writing to Firestore path=${progressRef.path}');
      if (type == 'avatar') {
        await progressRef.set({
          'inventory': FieldValue.arrayUnion([itemId]),
        }, SetOptions(merge: true));
        debugPrint('[Redeem] avatar write SUCCESS');
      } else if (type == 'coins') {
        await userDocRef.set({
          'coins': FieldValue.increment((rewardData['amount'] as int?) ?? 0),
        }, SetOptions(merge: true));
      } else if (type == 'gems') {
        await userDocRef.set({
          'gems': FieldValue.increment((rewardData['amount'] as int?) ?? 0),
        }, SetOptions(merge: true));
      }

      debugPrint('[Redeem] context.mounted=${context.mounted}');
      if (!context.mounted) return;
      _showSnackBar(
        context,
        rewardData['successMsg'] as String? ?? 'Code valide.',
        backgroundColor: Colors.green,
      );
      _codeController.clear();
    } catch (error, st) {
      debugPrint('[Redeem] ERROR: $error\n$st');
      if (context.mounted) {
        _showSnackBar(
          context,
          'Erreur technique : $error',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  Future<void> _handleProductTap({
    required BuildContext context,
    required String uid,
    required _ShopProduct product,
    required _ShopViewData viewData,
    required List<_ShopDailyOffer> offers,
  }) async {
    if (_pendingPurchaseProductIds.contains(product.id)) {
      return;
    }
    if (!viewData.isUnlocked(product)) {
      _showSnackBar(context, viewData.unlockReason(product));
      return;
    }
    if (_canEquipProduct(product, viewData)) {
      await _equipProduct(context: context, uid: uid, product: product);
      return;
    }
    if (product.isUnique && viewData.ownsProduct(product)) {
      _showSnackBar(context, '${product.name} est déjà possédé.');
      return;
    }

    final effectivePrice = _effectivePrice(product, offers);
    final offer = _offerForProduct(product.id, offers);
    if (mounted) {
      setState(() {
        _pendingPurchaseProductIds.add(product.id);
      });
    }
    try {
      final confirmed = await _showPurchaseSheet(
        context: context,
        product: product,
        viewData: viewData,
        price: effectivePrice,
        offer: offer,
      );
      if (confirmed != true || !context.mounted) return;
      await _purchaseProduct(
        context: context,
        uid: uid,
        product: product,
        price: effectivePrice,
        viewData: viewData,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingPurchaseProductIds.remove(product.id);
        });
      }
    }
  }

  Future<bool?> _showPurchaseSheet({
    required BuildContext context,
    required _ShopProduct product,
    required _ShopViewData viewData,
    required int price,
    required _ShopDailyOffer? offer,
  }) {
    final currentBalance = viewData.balanceFor(product.currency);
    final nextBalance = currentBalance - price;
    final canAfford = nextBalance >= 0;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PreviewBubble(product: product, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _SmallTag(
                                label: product.rarity.label,
                                color: product.rarity.color,
                              ),
                              _SmallTag(
                                label: product.gameLabel,
                                color: product.gradient.first,
                              ),
                              if (offer != null)
                                _SmallTag(
                                  label: '-${offer.discountPercent}%',
                                  color: Colors.redAccent,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  product.description,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _ConfirmRow(
                  label: 'Solde avant',
                  value: '$currentBalance ${product.currency.emoji}',
                ),
                const SizedBox(height: 8),
                _ConfirmRow(
                  label: 'Prix',
                  value:
                      offer == null
                          ? '$price ${product.currency.emoji}'
                          : '${offer.originalPrice} → $price ${product.currency.emoji}',
                  highlighted: offer != null,
                ),
                const SizedBox(height: 8),
                _ConfirmRow(
                  label: 'Solde après',
                  value: '$nextBalance ${product.currency.emoji}',
                  highlighted: canAfford,
                ),
                const SizedBox(height: 16),
                _ImpactCallout(
                  title: 'Impact immédiat',
                  message: product.immediateImpact,
                ),
                const SizedBox(height: 12),
                _ImpactCallout(
                  title: 'Où l’utiliser',
                  message: product.useLocation,
                ),
                if (product.bundle.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ImpactCallout(
                    title: 'Contenu du bundle',
                    message: product.bundle
                        .map((entry) {
                          final reward = _catalogById[entry.productId];
                          final label = reward?.name ?? entry.productId;
                          return '${entry.quantity}x $label';
                        })
                        .join(' • '),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _wine,
                          side: BorderSide(
                            color: _wine.withValues(alpha: 0.28),
                          ),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GradientButton(
                        label:
                            canAfford
                                ? 'Acheter'
                                : '${price - currentBalance} ${product.currency.emoji} manquants',
                        onTap:
                            canAfford
                                ? () => Navigator.of(context).pop(true)
                                : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _purchaseProduct({
    required BuildContext context,
    required String uid,
    required _ShopProduct product,
    required int price,
    required _ShopViewData viewData,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = _userRef(uid);
        final progressRef = _progressRef(uid);
        final shopRef = _shopRef(uid);

        final userSnap = await transaction.get(userRef);
        final progressSnap = await transaction.get(progressRef);
        final shopSnap = await transaction.get(shopRef);
        final liveViewData = _ShopViewData.fromMaps(
          userData: userSnap.data(),
          progressData: progressSnap.data(),
          shopData: shopSnap.data(),
          campaignData: null,
          dayKey: _shopDayKey(DateTime.now()),
        );

        if (!liveViewData.isUnlocked(product)) {
          throw StateError(liveViewData.unlockReason(product));
        }
        if (product.isUnique && liveViewData.ownsProduct(product)) {
          throw StateError('Produit déjà possédé.');
        }

        final currentBalance = liveViewData.balanceFor(product.currency);
        if (currentBalance < price) {
          throw StateError(
            'Solde insuffisant en ${product.currency == _ShopCurrency.gems ? 'gemmes' : 'pièces'}.',
          );
        }

        if (product.currency == _ShopCurrency.gems) {
          transaction.set(userRef, {
            'gems': FieldValue.increment(-price),
          }, SetOptions(merge: true));
        } else {
          transaction.set(userRef, {
            'coins': FieldValue.increment(-price),
          }, SetOptions(merge: true));
        }

        _grantProductReward(
          transaction: transaction,
          userRef: userRef,
          progressRef: progressRef,
          shopRef: shopRef,
          product: product,
        );

        final updatedQuest = _nextQuestState(
          current: _ShopQuestState.fromMap(
            (shopSnap.data()?['dailyQuest'] as Map?)?.cast<String, dynamic>(),
            _shopDayKey(DateTime.now()),
          ),
          action: _ShopQuestAction.buy,
        );
        transaction.set(shopRef, {
          'dailyQuest': updatedQuest.toMap(),
        }, SetOptions(merge: true));
      });

      if (!context.mounted) return;
      _showSnackBar(
        context,
        _purchaseSuccessLabel(product),
        backgroundColor: Colors.green,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        error is StateError
            ? error.message
            : 'Impossible de finaliser cet achat.',
        backgroundColor: Colors.red,
      );
    }
  }

  void _grantProductReward({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> userRef,
    required DocumentReference<Map<String, dynamic>> progressRef,
    required DocumentReference<Map<String, dynamic>> shopRef,
    required _ShopProduct product,
    int quantity = 1,
  }) {
    if (product.id == 'coins_pack') {
      transaction.set(userRef, {
        'coins': FieldValue.increment(500 * quantity),
      }, SetOptions(merge: true));
      return;
    }
    if (product.id == 'boost_zero_fees') {
      transaction.set(userRef, {
        'boost_zero_fees_count': FieldValue.increment(quantity),
      }, SetOptions(merge: true));
      return;
    }
    if (product.bundle.isNotEmpty) {
      for (final entry in product.bundle) {
        final reward = _catalogById[entry.productId];
        if (reward != null) {
          _grantProductReward(
            transaction: transaction,
            userRef: userRef,
            progressRef: progressRef,
            shopRef: shopRef,
            product: reward,
            quantity: quantity * entry.quantity,
          );
        }
      }
      return;
    }
    if (product.isAvatar) {
      transaction.set(progressRef, {
        'inventory': FieldValue.arrayUnion(
          List<String>.filled(quantity, product.id),
        ),
      }, SetOptions(merge: true));
      return;
    }
    if (product.kind == _ShopProductKind.cosmetic ||
        product.kind == _ShopProductKind.collection) {
      transaction.set(shopRef, {
        'ownedCosmetics': FieldValue.arrayUnion(
          List<String>.filled(quantity, product.id),
        ),
      }, SetOptions(merge: true));
      return;
    }
    if (product.kind == _ShopProductKind.consumable) {
      transaction.set(shopRef, {
        'consumables.${product.id}': FieldValue.increment(quantity),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _equipProduct({
    required BuildContext context,
    required String uid,
    required _ShopProduct product,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = _userRef(uid);
        final progressRef = _progressRef(uid);
        final shopRef = _shopRef(uid);

        final progressSnap = await transaction.get(progressRef);
        final shopSnap = await transaction.get(shopRef);
        final avatarInventory =
            _stringList(progressSnap.data()?['inventory']).toSet();
        final ownedCosmetics =
            _stringList(shopSnap.data()?['ownedCosmetics']).toSet();
        final dayKey = _shopDayKey(DateTime.now());
        final quest = _ShopQuestState.fromMap(
          (shopSnap.data()?['dailyQuest'] as Map?)?.cast<String, dynamic>(),
          dayKey,
        );

        if (product.isAvatar) {
          if (!avatarInventory.contains(product.id)) {
            throw StateError('Avatar non débloqué.');
          }
          transaction.set(userRef, {
            'avatar_id': product.id,
          }, SetOptions(merge: true));
        } else {
          if (!ownedCosmetics.contains(product.id)) {
            throw StateError('Cosmétique non possédé.');
          }
          final slotKey = product.slotKey;
          if (slotKey == null) {
            throw StateError('Ce produit ne peut pas être équipé.');
          }
          transaction.set(shopRef, {
            'equippedCosmetics.$slotKey': product.id,
          }, SetOptions(merge: true));
        }

        transaction.set(shopRef, {
          'dailyQuest':
              _nextQuestState(
                current: quest,
                action: _ShopQuestAction.equip,
              ).toMap(),
        }, SetOptions(merge: true));
      });

      if (!context.mounted) return;
      _showSnackBar(
        context,
        '${product.name} équipé.',
        backgroundColor: Colors.green,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        error is StateError
            ? error.message
            : 'Impossible d’équiper ce produit.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _useConsumable({
    required BuildContext context,
    required String uid,
    required _ShopProduct product,
    required _ShopViewData viewData,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = _userRef(uid);
        final shopRef = _shopRef(uid);
        final userSnap = await transaction.get(userRef);
        final shopSnap = await transaction.get(shopRef);
        final shopData = shopSnap.data() ?? <String, dynamic>{};
        final dayKey = _shopDayKey(DateTime.now());
        final quest = _ShopQuestState.fromMap(
          (shopData['dailyQuest'] as Map?)?.cast<String, dynamic>(),
          dayKey,
        );

        if (product.id == 'boost_zero_fees') {
          final boostCount =
              (userSnap.data()?['boost_zero_fees_count'] as num?)?.toInt() ?? 0;
          if (boostCount <= 0) {
            throw StateError('Aucun boost 0% de frais disponible.');
          }
          final zeroFeesUntil =
              userSnap.data()?['zero_fees_until'] as Timestamp?;
          final isActive =
              zeroFeesUntil != null &&
              zeroFeesUntil.toDate().isAfter(DateTime.now());
          if (isActive) {
            throw StateError('Un boost 0% de frais est déjà actif.');
          }
          transaction.set(userRef, {
            'boost_zero_fees_count': FieldValue.increment(-1),
            'zero_fees_until': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 12)),
            ),
          }, SetOptions(merge: true));
        } else {
          final currentCount =
              (_readIntMap(shopData['consumables'])[product.id] ?? 0);
          if (currentCount <= 0) {
            throw StateError('Aucun ${product.name} disponible.');
          }
          transaction.set(shopRef, {
            'consumables.${product.id}': FieldValue.increment(-1),
            'activeConsumables.${product.id}': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }

        transaction.set(shopRef, {
          'dailyQuest':
              _nextQuestState(
                current: quest,
                action: _ShopQuestAction.use,
              ).toMap(),
        }, SetOptions(merge: true));
      });

      if (!context.mounted) return;
      _showSnackBar(
        context,
        product.id == 'boost_zero_fees'
            ? 'Boost 0% de frais activé pour 12h.'
            : '${product.name} prêt pour votre prochain run.',
        backgroundColor: Colors.green,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        error is StateError
            ? error.message
            : 'Impossible d’utiliser cet objet.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _claimShopQuest(
    BuildContext context,
    String uid,
    _ShopQuestState questState,
  ) async {
    if (!questState.isComplete || questState.claimed) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = _userRef(uid);
        final shopRef = _shopRef(uid);
        final shopSnap = await transaction.get(shopRef);
        final currentQuest = _ShopQuestState.fromMap(
          (shopSnap.data()?['dailyQuest'] as Map?)?.cast<String, dynamic>(),
          _shopDayKey(DateTime.now()),
        );
        if (!currentQuest.isComplete || currentQuest.claimed) {
          throw StateError('Quête boutique non disponible.');
        }
        transaction.set(userRef, {
          'coins': FieldValue.increment(120),
          'gems': FieldValue.increment(2),
        }, SetOptions(merge: true));
        transaction.set(shopRef, {
          'dailyQuest': currentQuest.copyWith(claimed: true).toMap(),
        }, SetOptions(merge: true));
      });

      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Quête boutique validée : +120 pièces et +2 gemmes.',
        backgroundColor: Colors.green,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        error is StateError
            ? error.message
            : 'Impossible de récupérer la récompense.',
        backgroundColor: Colors.red,
      );
    }
  }

  bool _canEquipProduct(_ShopProduct product, _ShopViewData viewData) {
    if (product.isAvatar) {
      return viewData.ownsProduct(product) && !viewData.isEquipped(product);
    }
    return product.slotKey != null &&
        viewData.ownsProduct(product) &&
        !viewData.isEquipped(product);
  }

  _ShopDailyOffer? _offerForProduct(
    String productId,
    List<_ShopDailyOffer> offers,
  ) {
    for (final offer in offers) {
      if (offer.productId == productId) return offer;
    }
    return null;
  }

  int _effectivePrice(_ShopProduct product, List<_ShopDailyOffer> offers) {
    return _offerForProduct(product.id, offers)?.discountedPrice ??
        product.price;
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    Color backgroundColor = _wine,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _purchaseSuccessLabel(_ShopProduct product) {
    if (product.kind == _ShopProductKind.bundle) {
      return '${product.name} ajouté à votre inventaire.';
    }
    if (product.kind == _ShopProductKind.currency) {
      return 'Ressources ajoutées immédiatement.';
    }
    if (product.kind == _ShopProductKind.cosmetic ||
        product.kind == _ShopProductKind.collection) {
      return '${product.name} débloqué.';
    }
    return '${product.name} ajouté à votre inventaire.';
  }
}

enum _ShopQuestAction { buy, equip, use }

_ShopQuestState _nextQuestState({
  required _ShopQuestState current,
  required _ShopQuestAction action,
}) {
  switch (action) {
    case _ShopQuestAction.buy:
      return current.copyWith(buyCount: current.buyCount + 1);
    case _ShopQuestAction.equip:
      return current.copyWith(equipCount: current.equipCount + 1);
    case _ShopQuestAction.use:
      return current.copyWith(useCount: current.useCount + 1);
  }
}

List<_ShopDailyOffer> _shopDailyOffersForDay({
  required String uid,
  required String dayKey,
}) {
  final seed = _stableSeed('$uid::$dayKey::offers');
  final random = Random(seed);
  final candidates =
      _shopCatalog.where((product) => product.canReceiveDailyOffer).toList()
        ..shuffle(random);
  const discounts = <int>[15, 18, 20, 25, 30, 35];
  final selected = candidates.take(4).toList();
  if (selected.isEmpty) return const <_ShopDailyOffer>[];

  final offers = <_ShopDailyOffer>[];
  var bestDiscount = -1;
  var bestIndex = 0;
  for (var index = 0; index < selected.length; index++) {
    final product = selected[index];
    final discount = discounts[(seed + index * 7) % discounts.length];
    final discountedPrice = max(
      1,
      (product.price * (100 - discount) / 100).round(),
    );
    if (discount > bestDiscount) {
      bestDiscount = discount;
      bestIndex = index;
    }
    offers.add(
      _ShopDailyOffer(
        productId: product.id,
        discountPercent: discount,
        discountedPrice: discountedPrice,
        originalPrice: product.price,
        isBestOffer: false,
      ),
    );
  }

  return List<_ShopDailyOffer>.generate(offers.length, (index) {
    final offer = offers[index];
    return _ShopDailyOffer(
      productId: offer.productId,
      discountPercent: offer.discountPercent,
      discountedPrice: offer.discountedPrice,
      originalPrice: offer.originalPrice,
      isBestOffer: index == bestIndex,
    );
  });
}

String _shopDayKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}${local.month.toString().padLeft(2, '0')}${local.day.toString().padLeft(2, '0')}';
}

int _stableSeed(String input) {
  var seed = 0;
  for (final code in input.codeUnits) {
    seed = (seed * 31 + code) & 0x7fffffff;
  }
  return seed;
}

String _timeUntilNextResetLabel(DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final diff = tomorrow.difference(now);
  final hours = diff.inHours;
  final minutes = diff.inMinutes.remainder(60);
  final seconds = diff.inSeconds.remainder(60);
  return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
}

String _formatShortTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const <String>[];
}

Map<String, int> _readIntMap(dynamic value) {
  if (value is Map) {
    return value.map<String, int>((key, dynamic entryValue) {
      return MapEntry(key.toString(), (entryValue as num?)?.toInt() ?? 0);
    });
  }
  return const <String, int>{};
}

Map<String, String> _readStringMap(dynamic value) {
  if (value is Map) {
    return value.map<String, String>((key, dynamic entryValue) {
      return MapEntry(key.toString(), entryValue?.toString() ?? '');
    });
  }
  return const <String, String>{};
}

String _gameSectionSubtitle(String title) {
  switch (title) {
    case 'Stock Analyst':
      return 'Rerolls, indices et protections pour mieux comprendre le score fondamental.';
    case 'Actu & Quiz':
      return 'Tickets premium, rerolls et aides de lecture pour les runs news.';
    case 'Scénarios':
      return 'Jokers d’info, hedge et mutateurs pour mieux piloter vos décisions.';
    case 'Compte à terme':
      return 'Outils de trésorerie pour gérer liquidité, rerolls et protection.';
  }
  return 'Sélection de produits dédiés.';
}

IconData _gameSectionIcon(String title) {
  switch (title) {
    case 'Stock Analyst':
      return Icons.query_stats_rounded;
    case 'Actu & Quiz':
      return Icons.public_rounded;
    case 'Scénarios':
      return Icons.alt_route_rounded;
    case 'Compte à terme':
      return Icons.account_balance_rounded;
  }
  return Icons.extension_rounded;
}

class _ShopHeroBanner extends StatelessWidget {
  const _ShopHeroBanner({
    required this.offerCount,
    required this.questState,
    required this.nextRefreshLabel,
    required this.contextMessage,
    required this.highlightedCount,
  });

  final int offerCount;
  final _ShopQuestState questState;
  final String nextRefreshLabel;
  final String? contextMessage;
  final int highlightedCount;

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
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hub boutique',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            contextMessage ??
                'Offres du jour, bundles par mini-jeu, cosmétiques et inventaire consommable.',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TopInfoChip(
                icon: Icons.schedule_rounded,
                label: 'Reset dans $nextRefreshLabel',
              ),
              _TopInfoChip(
                icon: Icons.local_offer_rounded,
                label: '$offerCount deals actifs',
              ),
              _TopInfoChip(
                icon: Icons.flag_rounded,
                label:
                    questState.isComplete && !questState.claimed
                        ? 'Quête prête'
                        : 'Quête boutique',
              ),
              if (highlightedCount > 0)
                _TopInfoChip(
                  icon: Icons.local_fire_department_rounded,
                  label: '$highlightedCount offre(s) contextuelle(s)',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopTabStrip extends StatelessWidget {
  const _ShopTabStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TabBar(
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[detailsColor1, detailsColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        tabs: const [
          Tab(text: 'Vedette'),
          Tab(text: 'Jeux'),
          Tab(text: 'Cosmétiques'),
          Tab(text: 'Boosts'),
          Tab(text: 'Inventaire'),
        ],
      ),
    );
  }
}

class _DailyOfferHeroCard extends StatelessWidget {
  const _DailyOfferHeroCard({
    required this.product,
    required this.offer,
    required this.nextRefreshLabel,
    required this.onTap,
  });

  final _ShopProduct product;
  final _ShopDailyOffer offer;
  final String nextRefreshLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: product.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: product.gradient.first.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [_HeroPill(label: 'Meilleure offre')],
                  ),
                ),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              product.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroMetric(
                  label: 'Remise',
                  value: '-${offer.discountPercent}%',
                ),
                _HeroMetric(
                  label: 'Prix',
                  value: '${offer.discountedPrice} ${product.currency.emoji}',
                ),
                _HeroMetric(label: 'Reset', value: nextRefreshLabel),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Text(
                  'Ouvrir l’offre',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyOffersCarousel extends StatelessWidget {
  const _DailyOffersCarousel({
    required this.offers,
    required this.products,
    required this.onTap,
  });

  final List<_ShopDailyOffer> offers;
  final Map<String, _ShopProduct> products;
  final ValueChanged<_ShopProduct> onTap;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return const _EmptyInventoryCard(
        title: 'Aucune offre active',
        message: 'Les deals du jour seront bientôt de retour.',
      );
    }

    return SizedBox(
      height: 242,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          final product = products[offer.productId];
          if (product == null) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(
              right: index == offers.length - 1 ? 0 : 10,
            ),
            child: _MiniOfferCard(
              product: product,
              offer: offer,
              onTap: () => onTap(product),
            ),
          );
        },
      ),
    );
  }
}

class _MiniOfferCard extends StatelessWidget {
  const _MiniOfferCard({
    required this.product,
    required this.offer,
    required this.onTap,
  });

  final _ShopProduct product;
  final _ShopDailyOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PreviewBubble(product: product, size: 48),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '-${offer.discountPercent}%',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.gameLabel,
              style: TextStyle(
                color: product.gradient.first,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${offer.originalPrice} ${product.currency.emoji} ',
                    style: const TextStyle(
                      color: Colors.black38,
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: '${offer.discountedPrice} ${product.currency.emoji}',
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.immediateImpact,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopQuestCard extends StatelessWidget {
  const _ShopQuestCard({
    required this.questState,
    required this.onClaim,
    required this.nextRefreshLabel,
  });

  final _ShopQuestState questState;
  final VoidCallback? onClaim;
  final String nextRefreshLabel;

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
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: <Color>[detailsColor1, detailsColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.task_alt_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quêtes boutique',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Acheter, équiper et utiliser pour récupérer une petite récompense.',
                      style: TextStyle(
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
          const SizedBox(height: 16),
          _QuestStepRow(
            done: questState.buyCount >= 1,
            label: 'Acheter 1 produit',
          ),
          const SizedBox(height: 8),
          _QuestStepRow(
            done: questState.equipCount >= 1,
            label: 'Équiper 1 cosmétique',
          ),
          const SizedBox(height: 8),
          _QuestStepRow(
            done: questState.useCount >= 1,
            label: 'Utiliser 1 ticket',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  questState.claimed
                      ? 'Récompense récupérée. Reset dans $nextRefreshLabel'
                      : questState.isComplete
                      ? 'Récompense prête : +120 pièces et +2 gemmes'
                      : 'Continue ta boucle boutique pour valider la quête.',
                  style: TextStyle(
                    color:
                        questState.claimed
                            ? Colors.black45
                            : questState.isComplete
                            ? Colors.green
                            : Colors.black54,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _GradientButton(
                label: questState.claimed ? 'Réclamée' : 'Récupérer',
                compact: true,
                onTap: onClaim,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  const _ShopProductCard({
    required this.product,
    required this.viewData,
    required this.offer,
    required this.onPrimaryAction,
    this.onSecondaryAction,
  });

  final _ShopProduct product;
  final _ShopViewData viewData;
  final _ShopDailyOffer? offer;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final price = offer?.discountedPrice ?? product.price;
    final owned = viewData.ownsProduct(product);
    final equipped = viewData.isEquipped(product);
    final unlocked = viewData.isUnlocked(product);
    final canAfford = viewData.balanceFor(product.currency) >= price;
    final quantity = viewData.quantityFor(product.id);
    final activeCount = viewData.activeCountFor(product.id);
    final primaryLabel =
        !unlocked
            ? 'Verrouillé'
            : equipped
            ? 'Équipé'
            : owned && product.slotKey != null
            ? 'Équiper'
            : '$price ${product.currency.emoji}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              offer != null
                  ? Colors.redAccent.withValues(alpha: 0.18)
                  : const Color(0xFFE6E8EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewBubble(product: product),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallTag(
                          label: product.rarity.label,
                          color: product.rarity.color,
                        ),
                        _SmallTag(
                          label: product.kind.label,
                          color: product.gradient.first,
                        ),
                        _SmallTag(
                          label: product.gameLabel,
                          color: Colors.black54,
                        ),
                        if (offer != null)
                          _SmallTag(
                            label: '-${offer!.discountPercent}%',
                            color: Colors.redAccent,
                          ),
                        if (quantity > 0)
                          _SmallTag(label: 'x$quantity', color: Colors.green),
                        if (activeCount > 0)
                          _SmallTag(
                            label: 'Prêt x$activeCount',
                            color: Colors.orange,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E8EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.immediateImpact,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.useLocation,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    viewData.unlockReason(product),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.usage,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          if (offer != null)
                            TextSpan(
                              text:
                                  '${offer!.originalPrice} ${product.currency.emoji} ',
                              style: const TextStyle(
                                color: Colors.black38,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          TextSpan(
                            text:
                                product.isUnique && owned
                                    ? equipped
                                        ? 'Équipé'
                                        : 'Possédé'
                                    : '$price ${product.currency.emoji}',
                            style: TextStyle(
                              color:
                                  product.isUnique && owned
                                      ? Colors.green
                                      : textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (onSecondaryAction != null) ...[
                SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onSecondaryAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: detailsColor2,
                      side: BorderSide(
                        color: detailsColor2.withValues(alpha: 0.28),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Utiliser',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: _GradientButton(
                  label: primaryLabel,
                  compact: true,
                  onTap:
                      (!unlocked || (product.isUnique && owned && equipped))
                          ? null
                          : (canAfford || (product.isUnique && owned))
                          ? onPrimaryAction
                          : null,
                  disabledLabel:
                      !unlocked
                          ? 'Verrouillé'
                          : (product.isUnique && owned && equipped)
                          ? 'Équipé'
                          : primaryLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({
    required this.product,
    required this.quantity,
    required this.activeCount,
    required this.onUse,
  });

  final _ShopProduct product;
  final int quantity;
  final int activeCount;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewBubble(product: product, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _SmallTag(label: 'x$quantity', color: Colors.green),
                    if (activeCount > 0)
                      _SmallTag(
                        label: 'Prêt x$activeCount',
                        color: Colors.orange,
                      ),
                    _SmallTag(
                      label: product.gameLabel,
                      color: product.gradient.first,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.useLocation,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _GradientButton(
            label: 'Utiliser',
            compact: true,
            onTap: quantity > 0 ? onUse : null,
          ),
        ],
      ),
    );
  }
}

class _OwnedCosmeticCard extends StatelessWidget {
  const _OwnedCosmeticCard({
    required this.product,
    required this.isEquipped,
    required this.onEquip,
  });

  final _ShopProduct product;
  final bool isEquipped;
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _PreviewBubble(product: product, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.useLocation,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _GradientButton(
            label: isEquipped ? 'Équipé' : 'Équiper',
            compact: true,
            onTap: onEquip,
          ),
        ],
      ),
    );
  }
}

class _InventoryStatusCard extends StatelessWidget {
  const _InventoryStatusCard({
    required this.activeCount,
    required this.zeroFeesActive,
    required this.zeroFeesLabel,
  });

  final int activeCount;
  final bool zeroFeesActive;
  final String zeroFeesLabel;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventaire live',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            activeCount > 0
                ? '$activeCount effet(s) actif(s) ou préparé(s) dans votre réserve.'
                : 'Aucun effet actif pour le moment.',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TopInfoChip(icon: Icons.flash_on_rounded, label: zeroFeesLabel),
              _TopInfoChip(
                icon: Icons.track_changes_rounded,
                label:
                    zeroFeesActive
                        ? 'Boost de trading actif'
                        : 'Aucun boost trade',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyInventoryCard extends StatelessWidget {
  const _EmptyInventoryCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: <Color>[detailsColor1, detailsColor2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.inventory_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
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

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.product, this.size = 64});

  final _ShopProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child =
        product.assetPath != null
            ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.24),
              child: Image.asset(
                product.assetPath!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Icon(
                      product.icon,
                      color: Colors.white,
                      size: size * 0.42,
                    ),
              ),
            )
            : Icon(product.icon, color: Colors.white, size: size * 0.42);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(
          colors: product.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: product.gradient.first.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopInfoChip extends StatelessWidget {
  const _TopInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: detailsColor2),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestStepRow extends StatelessWidget {
  const _QuestStepRow({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: done ? Colors.green : Colors.black26,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done ? textColor : Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImpactCallout extends StatelessWidget {
  const _ImpactCallout({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
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
            message,
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

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlighted ? detailsColor2 : textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
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
        claimedToday =
            now.year == last.year &&
            now.month == last.month &&
            now.day == last.day;
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
          content: Text('Récompense récupérée : +$amount $label.'),
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
          content: Text('Erreur lors de la récupération.'),
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
    final enabled = onTap != null && !loading;

    return InkWell(
      onTap:
          enabled
              ? () {
                HapticFeedback.mediumImpact();
                onTap!();
              }
              : null,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: compact ? 40 : 50,
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
                      textAlign: TextAlign.center,
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
