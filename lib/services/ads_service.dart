import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 광고 표시 여부의 단일 소스 + AdMob 초기화 + 배너 광고 단위 ID 제공.
///
/// ⚠️ 출시 전 교체 필요 (아니키 AdMob 계정 자산):
///  - ios/Runner/Info.plist 의 GADApplicationIdentifier
///  - android AndroidManifest 의 com.google.android.gms.ads.APPLICATION_ID
///  - 아래 bannerAdUnitId 의 실제 배너 광고 단위 ID
/// 배너 광고 단위는 출시판만 실제 ID 이고, 개발 빌드(디버그·프로필)는 구글 공식 시험 ID 라 시험 광고가 표시된다.
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

  /// 배너 광고 단위 ID — 출시판만 메모요 AdMob 실제 광고단위 (게시자 ca-app-pub-7025432711849670).
  ///
  /// 디버그·프로필 빌드는 구글 공식 시험 광고단위를 쓴다. 개발·실기기 시험에서 실광고가 노출·클릭되면
  /// 무효 트래픽으로 게시자 계정이 정지된다(2026-11-04 29일 정지 메일, T-261104-013).
  String get bannerAdUnitId =>
      bannerAdUnitIdFor(releaseMode: kReleaseMode, platform: defaultTargetPlatform);

  /// [bannerAdUnitId] 의 순수 함수판 — 빌드 모드·플랫폼 분기를 단위 시험으로 고정한다.
  @visibleForTesting
  static String bannerAdUnitIdFor({required bool releaseMode, required TargetPlatform platform}) {
    final ios = platform == TargetPlatform.iOS;
    if (!releaseMode) {
      return ios
          ? 'ca-app-pub-3940256099942544/2934735716' // 구글 공식 시험 배너 (iOS)
          : 'ca-app-pub-3940256099942544/6300978111'; // 구글 공식 시험 배너 (Android)
    }
    return ios
        ? 'ca-app-pub-7025432711849670/2649951313' // 메모요 하단 배너 (iOS)
        : 'ca-app-pub-7025432711849670/5924152772'; // 메모요 하단 배너 (Android)
  }
}
