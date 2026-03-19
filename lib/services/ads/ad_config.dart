import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class AdConfig {
  const AdConfig._();

  static const bool adsEnabled = true;
  static const bool useTestAds = true;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isRewardedDailyBonusEnabled =>
      adsEnabled && isSupportedPlatform;

  static bool get isNativeFeedEnabled => adsEnabled && isSupportedPlatform;

  static bool get isAnyAdEnabled =>
      isRewardedDailyBonusEnabled || isNativeFeedEnabled;

  static String get iosAppId {
    return useTestAds ? _iosSampleAppId : _iosLiveAppId;
  }

  static String get rewardedDailyBonusUnitId {
    return useTestAds ? _iosRewardedTestUnitId : _iosRewardedLiveUnitId;
  }

  static String get todayNativeUnitId {
    return useTestAds ? _iosNativeTestUnitId : _iosTodayNativeLiveUnitId;
  }

  static String get socialNativeUnitId {
    return useTestAds ? _iosNativeTestUnitId : _iosSocialNativeLiveUnitId;
  }

  static const String _iosSampleAppId =
      'ca-app-pub-3940256099942544~1458002511';
  static const String _iosRewardedTestUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _iosNativeTestUnitId =
      'ca-app-pub-3940256099942544/3986624511';

  // Renseigner les IDs AdMob réels ici le jour où la monétisation est activée.
  static const String _iosLiveAppId = '';
  static const String _iosRewardedLiveUnitId = '';
  static const String _iosTodayNativeLiveUnitId = '';
  static const String _iosSocialNativeLiveUnitId = '';
}
