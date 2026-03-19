import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class RewardedAdService {
  RewardedAdService._();

  static final RewardedAdService instance = RewardedAdService._();

  RewardedAd? _rewardedAd;
  Completer<bool>? _loadCompleter;

  bool get isReady => _rewardedAd != null;
  bool get isLoading => _loadCompleter != null;

  Future<bool> load() {
    if (!AdConfig.isRewardedDailyBonusEnabled) {
      return Future<bool>.value(false);
    }
    if (_rewardedAd != null) {
      return Future<bool>.value(true);
    }
    final existingCompleter = _loadCompleter;
    if (existingCompleter != null) {
      return existingCompleter.future;
    }

    final completer = Completer<bool>();
    _loadCompleter = completer;

    RewardedAd.load(
      adUnitId: AdConfig.rewardedDailyBonusUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loadCompleter = null;
          completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd load failed: $error');
          _rewardedAd = null;
          _loadCompleter = null;
          completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  Future<bool> show({
    required VoidCallback onRewardEarned,
    required void Function(bool rewardEarned) onClosed,
    required void Function(String message) onFailedToShow,
  }) async {
    if (!AdConfig.isRewardedDailyBonusEnabled) {
      onFailedToShow('Le bonus pub est désactivé sur cette plateforme.');
      return false;
    }

    if (_rewardedAd == null) {
      final loaded = await load();
      if (!loaded) {
        onFailedToShow('La pub de test n’est pas encore prête.');
        return false;
      }
    }

    final ad = _rewardedAd;
    if (ad == null) {
      onFailedToShow('La pub de test est indisponible.');
      return false;
    }

    _rewardedAd = null;
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(load());
        onClosed(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('RewardedAd show failed: $error');
        ad.dispose();
        unawaited(load());
        onFailedToShow(error.message);
        onClosed(false);
      },
    );

    await ad.setImmersiveMode(true);
    await ad.show(
      onUserEarnedReward: (_, __) {
        if (rewardEarned) return;
        rewardEarned = true;
        onRewardEarned();
      },
    );
    return true;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _loadCompleter = null;
  }
}
