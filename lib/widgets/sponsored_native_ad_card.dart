import 'package:fintech/core/constants.dart';
import 'package:fintech/services/ads/ad_config.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum SponsoredNativePlacement { today, social }

class SponsoredNativeAdCard extends StatefulWidget {
  const SponsoredNativeAdCard.today({super.key})
    : placement = SponsoredNativePlacement.today;

  const SponsoredNativeAdCard.social({super.key})
    : placement = SponsoredNativePlacement.social;

  final SponsoredNativePlacement placement;

  @override
  State<SponsoredNativeAdCard> createState() => _SponsoredNativeAdCardState();
}

class _SponsoredNativeAdCardState extends State<SponsoredNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _hasFailed = false;

  bool get _isEnabled => AdConfig.isNativeFeedEnabled;

  bool get _isTodayPlacement =>
      widget.placement == SponsoredNativePlacement.today;

  String get _adUnitId {
    return _isTodayPlacement
        ? AdConfig.todayNativeUnitId
        : AdConfig.socialNativeUnitId;
  }

  String get _eyebrow {
    return _isTodayPlacement ? 'Selection sponsorisee' : 'Mise en avant';
  }

  String get _title {
    return _isTodayPlacement
        ? 'Partenaire du moment'
        : 'Contenu sponsorise pour la communaute';
  }

  String get _subtitle {
    return _isTodayPlacement
        ? 'Une recommandation partenaire placee apres le hub, dans un format plus lisible et plus propre pour iOS.'
        : 'Une recommandation sponsorisee placee en fin d onglet social, dans un format plus stable et plus lisible.';
  }

  TemplateType get _templateType => TemplateType.medium;

  static const double _mediumTemplateAspectRatio = 355 / 402;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(covariant SponsoredNativeAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _disposeAd();
      _loadAd();
    }
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  void _disposeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
  }

  void _loadAd() {
    if (!_isEnabled) return;

    _isLoaded = false;
    _hasFailed = false;

    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
            _hasFailed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd load failed (${widget.placement}): $error');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
            _hasFailed = true;
          });
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: _templateType,
        mainBackgroundColor: Colors.white,
        cornerRadius: 18,
        callToActionTextStyle: NativeTemplateTextStyle(
          backgroundColor: detailsColor2,
          textColor: Colors.white,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: textColor,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black.withValues(alpha: 0.62),
          size: 11,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black.withValues(alpha: 0.52),
          size: 10,
        ),
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled || _hasFailed) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(_isTodayPlacement ? 18 : 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 22,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: detailsColor1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _eyebrow,
                  style: const TextStyle(
                    color: detailsColor2,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.north_east_rounded,
                color: Colors.black38,
                size: 18,
              ),
            ],
          ),
          SizedBox(height: _isTodayPlacement ? 10 : 12),
          Text(
            _title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12.8,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: _isTodayPlacement ? 16 : 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final adHeight =
                  constraints.maxWidth / _mediumTemplateAspectRatio;
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: adHeight,
                  width: double.infinity,
                  color: const Color(0xFFF7F8FA),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child:
                        _isLoaded && _nativeAd != null
                            ? AdWidget(ad: _nativeAd!)
                            : const _NativeAdPlaceholder(isLarge: true),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NativeAdPlaceholder extends StatelessWidget {
  const _NativeAdPlaceholder({this.isLarge = false});

  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 164,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF0),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 164,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFECEFF2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 220,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFECEFF2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 118,
                height: 34,
                decoration: BoxDecoration(
                  color: detailsColor2.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF0),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 132,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEFF2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 88,
                    height: 28,
                    decoration: BoxDecoration(
                      color: detailsColor2.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
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
