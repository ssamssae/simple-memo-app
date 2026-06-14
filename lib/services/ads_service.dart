import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 광고 표시 여부의 단일 소스 + AdMob 초기화 + 배너 광고 단위 ID 제공.
///
/// ⚠️ 출시 전 교체 필요 (아니키 AdMob 계정 자산):
///  - ios/Runner/Info.plist 의 GADApplicationIdentifier
///  - android AndroidManifest 의 com.google.android.gms.ads.APPLICATION_ID
///  - 아래 bannerAdUnitId 의 실제 배너 광고 단위 ID
/// 현재는 구글 공식 테스트 ID 라 개발 빌드에서 테스트 광고가 표시된다.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String _removeAdsPrefKey = 'remove_ads_purchased';

  /// 광고 제거 구매 여부 — true 면 배너를 숨긴다. HomeShell·설정 화면이 구독.
  final ValueNotifier<bool> removeAds = ValueNotifier<bool>(false);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    removeAds.value = prefs.getBool(_removeAdsPrefKey) ?? false;
    await MobileAds.instance.initialize();
  }

  Future<void> setRemoveAds(bool value) async {
    removeAds.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_removeAdsPrefKey, value);
  }

  /// 배너 광고 단위 ID — 현재 구글 공식 테스트 ID (출시 전 실제 ID 로 교체).
  String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // 테스트 배너 (iOS)
    }
    return 'ca-app-pub-3940256099942544/6300978111'; // 테스트 배너 (Android)
  }
}
