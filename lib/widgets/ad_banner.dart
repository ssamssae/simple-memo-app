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

  // ★`|| isPremium` 는 ★기존 구독자 유예(grandfather)다 — 환불 완주 후 제거, T-260804-082 4페이즈.
  //   구독(premium_monthly) 판매는 T-260804-090 으로 끝났지만, 이미 결제한 사람은 아직 환불을
  //   못 받았다(4페이즈는 실인원 조회조차 안 된 상태다). 이 한 항을 지금 걷어내면 ★돈은 냈는데
  //   광고가 되살아난다. 지우는 시점은 볼칸이 환불 실인원을 실측하고 환불이 끝난 뒤다.
  //   ⚠️ 「구독을 없앴으니 이 줄도 죽은 코드」로 보고 정리하지 마라 — 죽은 게 아니라 유예다.
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
