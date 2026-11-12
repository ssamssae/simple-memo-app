import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_install_grace.dart';

/// 광고 표시 여부의 단일 소스 + AdMob 초기화 + 배너 광고 단위 ID 제공.
///
/// ⚠️ 출시 전 교체 필요 (아니키 AdMob 계정 자산):
///  - ios/Runner/Info.plist 의 GADApplicationIdentifier
///  - android AndroidManifest 의 com.google.android.gms.ads.APPLICATION_ID
///  - 아래 bannerAdUnitId 의 실제 배너 광고 단위 ID
/// 배너 광고 단위는 출시판만 실제 ID 이고, 개발 빌드(디버그·프로필)는 구글 공식 시험 ID 라 시험 광고가 표시된다.
/// iOS 는 출시판이라도 앱스토어에서 받은 설치만 실제 ID 다. TestFlight·개발 서명 설치는 시험 ID 다.
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
  /// iOS 출시판도 설치 출처를 읽은 뒤에 정한다. TestFlight 는 앱스토어와 같은 출시판이라
  /// 빌드 모드로는 가를 수 없다(T-261104-014 B안).
  Future<String> bannerAdUnitId() async => bannerAdUnitIdFor(
    releaseMode: debugReleaseMode ?? kReleaseMode,
    platform: debugPlatform ?? defaultTargetPlatform,
    installerStore: await installerStore,
  );

  /// 메모요 하단 배너 (iOS). [bannerAdUnitIdFor] 가 앱스토어 출시판에서 돌려주는 값이다.
  @visibleForTesting
  static const realIosBannerAdUnitId = 'ca-app-pub-7025432711849670/2649951313';

  /// 메모요 하단 배너 (Android). [bannerAdUnitIdFor] 가 안드로이드 출시판에서 돌려주는 값이다.
  @visibleForTesting
  static const realAndroidBannerAdUnitId =
      'ca-app-pub-7025432711849670/5924152772';

  static const _testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static const _testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// [bannerAdUnitIdFor] 가 시험 ID 가 아닌 실제 배너 단위를 돌려줬는지.
  @visibleForTesting
  static bool isRealBannerAdUnitId(String adUnitId) {
    return adUnitId == realIosBannerAdUnitId ||
        adUnitId == realAndroidBannerAdUnitId;
  }

  Future<String?>? _installerStore;

  /// 설치 출처. iOS 는 앱스토어 설치면 `com.apple`, TestFlight·개발 서명 설치면 `com.apple.testflight` 다
  /// (package_info_plus 가 영수증 경로 `sandboxReceipt` 로 가른다). 읽지 못하면 null 이다.
  @visibleForTesting
  Future<String?> get installerStore =>
      _installerStore ??= _readInstallerStore();

  static Future<String?> _readInstallerStore() async {
    try {
      return (await PackageInfo.fromPlatform()).installerStore;
    } catch (_) {
      return null;
    }
  }

  /// [bannerAdUnitId] 의 순수 함수판 — 빌드 모드·플랫폼·설치 출처 분기를 단위 시험으로 고정한다.
  ///
  /// iOS 는 [installerStore] 가 정확히 `com.apple`(앱스토어 설치)일 때만 실제 배너다.
  /// TestFlight·개발 서명·시뮬레이터·모름(null)은 시험 배너다. 우리 폰과 TestFlight 시험자가 받는
  /// 출시판이 실광고를 부르지 않게 한다. 안드로이드는 내부 테스트와 정식 출시가 같은 앱 묶음이라
  /// 설치 출처로 가를 수 없다. 그래서 안드로이드 출시판은 그대로 실제 배너다.
  @visibleForTesting
  static String bannerAdUnitIdFor({
    required bool releaseMode,
    required TargetPlatform platform,
    required String? installerStore,
  }) {
    final ios = platform == TargetPlatform.iOS;
    final appStoreInstall = !ios || installerStore == 'com.apple';
    if (!releaseMode || !appStoreInstall) {
      return ios
          ? _testIosBannerAdUnitId // 구글 공식 시험 배너 (iOS)
          : _testAndroidBannerAdUnitId; // 구글 공식 시험 배너 (Android)
    }
    return ios
        ? realIosBannerAdUnitId // 메모요 하단 배너 (iOS)
        : realAndroidBannerAdUnitId; // 메모요 하단 배너 (Android)
  }

  /// 실제 광고 단위일 때만 설치 유예를 본다.
  ///
  /// 시험 광고 단위는 처음 본 시각을 읽지도 저장하지도 않고 거짓을 돌려준다.
  /// 판정에 실패하면 참이다. 그때는 광고를 요청하지 않는다.
  Future<bool> shouldSuppressRealAdsForInstallGrace(String adUnitId) {
    final future = _shouldSuppressRealAdsForInstallGrace(adUnitId);
    debugLastGraceDecision = future;
    return future;
  }

  Future<bool> _shouldSuppressRealAdsForInstallGrace(String adUnitId) async {
    if (!isRealBannerAdUnitId(adUnitId)) return false;
    try {
      final now = debugNow?.call() ?? DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final firstSeen = await AdInstallGrace.resolveFirstSeen(
        now: now,
        storedMs: prefs.getInt(AdInstallGrace.storageKey),
        saveMs: (milliseconds) async {
          await prefs.setInt(AdInstallGrace.storageKey, milliseconds);
        },
        readInstallTime: debugReadInstallTime ?? _readInstallTime,
      );
      return AdInstallGrace.inInstallGrace(now: now, firstSeen: firstSeen);
    } catch (_) {
      return true;
    }
  }

  static Future<DateTime?> _readInstallTime() async {
    final info = await PackageInfo.fromPlatform();
    return info.installTime;
  }

  /// 배너 위젯이 광고 객체를 만들 때 쓴다. 시험은 만든 횟수를 센다.
  BannerAd createBannerAd({
    required String adUnitId,
    required BannerAdListener listener,
  }) {
    bannerAdsCreatedForTest++;
    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    );
  }

  /// 시험 대체 로드가 있으면 그걸 부르고, 없으면 [BannerAd.load] 를 부른다.
  Future<void> loadBannerAd(BannerAd ad) {
    final customLoad = debugLoadBanner;
    if (customLoad != null) return customLoad(ad);
    return ad.load();
  }

  @visibleForTesting
  static bool? debugReleaseMode;

  @visibleForTesting
  static TargetPlatform? debugPlatform;

  @visibleForTesting
  static DateTime Function()? debugNow;

  /// null 이면 [PackageInfo.installTime] 을 읽는다. 예외를 던지면 현재 시각을 쓴다.
  @visibleForTesting
  static Future<DateTime?> Function()? debugReadInstallTime;

  /// null 이면 [BannerAd.load] 를 부른다. 시험은 여기서 로드를 대신한다.
  @visibleForTesting
  static Future<void> Function(BannerAd ad)? debugLoadBanner;

  @visibleForTesting
  static int bannerAdsCreatedForTest = 0;

  /// 배너가 유예 판정을 시작했으면 그 Future. 시험이 판정이 끝난 뒤에 광고 객체를 센다.
  @visibleForTesting
  static Future<bool>? debugLastGraceDecision;

  @visibleForTesting
  void debugClearInstallerStoreCache() {
    _installerStore = null;
  }

  @visibleForTesting
  static void debugReset() {
    debugReleaseMode = null;
    debugPlatform = null;
    debugNow = null;
    debugReadInstallTime = null;
    debugLoadBanner = null;
    bannerAdsCreatedForTest = 0;
    debugLastGraceDecision = null;
    instance.debugClearInstallerStoreCache();
  }
}
