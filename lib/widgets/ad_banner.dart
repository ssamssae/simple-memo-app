import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';
import '../services/premium_service.dart';

/// 하단 배너 광고. 광고 제거 구매 또는 활성 프리미엄 기간에는 표시하지 않는다.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.removeAds.addListener(_onRemoveAdsChanged);
    PremiumService.instance.entitlement.addListener(_onRemoveAdsChanged);
    if (!_shouldHideAds) _loadAd();
  }

  bool get _shouldHideAds =>
      AdsService.instance.removeAds.value || PremiumService.instance.isPremium;

  void _onRemoveAdsChanged() {
    if (_shouldHideAds) {
      _ad?.dispose();
      _ad = null;
      if (mounted) setState(() => _loaded = false);
    } else if (_ad == null) {
      _loadAd();
    }
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: AdsService.instance.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdsService.instance.removeAds.removeListener(_onRemoveAdsChanged);
    PremiumService.instance.entitlement.removeListener(_onRemoveAdsChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (_shouldHideAds || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      color: const Color(0xFF0F0F12),
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
