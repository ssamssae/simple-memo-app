// T-261112-020: 설치 후 72시간 동안 실제 배너 광고를 요청하지 않는다.
// 71시간 59분은 유예, 72시간 0분은 유예 아님, 시계를 뒤로 돌리면 유예다.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/ad_install_grace.dart';
import 'package:simple_memo_app/services/ads_service.dart';

const _iosReal = 'ca-app-pub-7025432711849670/2649951313';
const _androidReal = 'ca-app-pub-7025432711849670/5924152772';
const _iosTest = 'ca-app-pub-3940256099942544/2934735716';
const _androidTest = 'ca-app-pub-3940256099942544/6300978111';

void _setPackage({String? installerStore, DateTime? installTime}) {
  PackageInfo.setMockInitialValues(
    appName: 'Memoyo',
    packageName: 'com.daejongkang.simpleMemoApp',
    version: '1.0.24',
    buildNumber: '52',
    buildSignature: '',
    installerStore: installerStore,
    installTime: installTime,
  );
  AdsService.instance.debugClearInstallerStoreCache();
}

void main() {
  final first = DateTime.utc(2026, 11, 1);

  setUp(() {
    AdsService.debugReset();
    AdsService.instance.removeAds.value = false;
    SharedPreferences.setMockInitialValues({});
    _setPackage(installerStore: 'com.apple');
  });

  tearDown(AdsService.debugReset);

  group('inInstallGrace', () {
    test('71시간 59분은 유예다', () {
      final now = first.add(const Duration(hours: 71, minutes: 59));
      expect(AdInstallGrace.inInstallGrace(now: now, firstSeen: first), isTrue);
    });

    test('72시간 0분은 유예가 아니다', () {
      final now = first.add(const Duration(hours: 72));
      expect(
        AdInstallGrace.inInstallGrace(now: now, firstSeen: first),
        isFalse,
      );
    });

    test('현재 시각이 처음 본 시각보다 과거면 유예다', () {
      expect(
        AdInstallGrace.inInstallGrace(
          now: first.subtract(const Duration(minutes: 1)),
          firstSeen: first,
        ),
        isTrue,
      );
      // 72시간을 넘긴 과거도 유예다. 차이를 절댓값으로 재면 이 경우가 깨진다.
      expect(
        AdInstallGrace.inInstallGrace(
          now: first.subtract(const Duration(hours: 73)),
          firstSeen: first,
        ),
        isTrue,
      );
    });
  });

  group('resolveFirstSeen', () {
    test('저장값이 있으면 그 값을 쓰고 덮어쓰지 않는다', () async {
      final stored = DateTime.utc(2024, 5, 6, 7, 8, 9);
      var saves = 0;
      var reads = 0;
      final seen = await AdInstallGrace.resolveFirstSeen(
        now: DateTime.utc(2026, 11, 12),
        storedMs: stored.millisecondsSinceEpoch,
        saveMs: (_) async => saves++,
        readInstallTime: () async {
          reads++;
          return DateTime.utc(2020);
        },
      );
      expect(seen.millisecondsSinceEpoch, stored.millisecondsSinceEpoch);
      expect(saves, 0);
      expect(reads, 0);
    });

    test('저장값이 없으면 설치 시각을 골라 저장한다', () async {
      final install = DateTime.utc(2020, 1, 2, 3, 4, 5);
      int? saved;
      final seen = await AdInstallGrace.resolveFirstSeen(
        now: DateTime.utc(2026, 11, 12),
        storedMs: null,
        saveMs: (milliseconds) async => saved = milliseconds,
        readInstallTime: () async => install,
      );
      expect(seen.millisecondsSinceEpoch, install.millisecondsSinceEpoch);
      expect(saved, install.millisecondsSinceEpoch);
    });

    test('설치 시각이 없으면 현재 시각을 저장한다', () async {
      final now = DateTime.utc(2026, 11, 12, 1, 2, 3);
      int? saved;
      final seen = await AdInstallGrace.resolveFirstSeen(
        now: now,
        storedMs: null,
        saveMs: (milliseconds) async => saved = milliseconds,
        readInstallTime: () async => null,
      );
      expect(seen.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(saved, now.millisecondsSinceEpoch);
    });

    test('설치 시각 읽기에 실패하면 현재 시각을 저장한다', () async {
      final now = DateTime.utc(2026, 11, 12, 4, 5, 6);
      int? saved;
      final seen = await AdInstallGrace.resolveFirstSeen(
        now: now,
        storedMs: null,
        saveMs: (milliseconds) async => saved = milliseconds,
        readInstallTime: () async => throw StateError('install time'),
      );
      expect(seen.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(saved, now.millisecondsSinceEpoch);
    });
  });

  group('shouldSuppressRealAdsForInstallGrace', () {
    test('저장값이 있으면 설치 시각이 달라도 그 값을 유지하고 오래된 사용자는 유예가 아니다', () async {
      final stored = DateTime.utc(2024, 1, 2);
      final now = DateTime.utc(2026, 11, 12);
      SharedPreferences.setMockInitialValues({
        AdInstallGrace.storageKey: stored.millisecondsSinceEpoch,
      });
      _setPackage(installerStore: 'com.apple', installTime: now);
      final adUnitId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple',
      );

      AdsService.debugNow = () => now;
      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AdInstallGrace.storageKey),
        stored.millisecondsSinceEpoch,
      );
    });

    test('저장값이 없으면 package_info_plus 설치 시각을 저장하고 다시 쓰지 않는다', () async {
      final install = DateTime.utc(2020, 3, 4);
      final now = DateTime.utc(2026, 11, 12);
      _setPackage(installerStore: 'com.apple', installTime: install);
      final adUnitId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple',
      );
      AdsService.debugNow = () => now;

      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AdInstallGrace.storageKey),
        install.millisecondsSinceEpoch,
      );

      _setPackage(installerStore: 'com.apple', installTime: now);
      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isFalse,
      );
      expect(
        prefs.getInt(AdInstallGrace.storageKey),
        install.millisecondsSinceEpoch,
      );
    });

    test('설치 시각이 없으면 현재 시각을 저장하고 유예다', () async {
      final now = DateTime.utc(2026, 11, 12, 8);
      _setPackage(installerStore: 'com.apple');
      AdsService.debugNow = () => now;
      final adUnitId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple',
      );

      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AdInstallGrace.storageKey),
        now.millisecondsSinceEpoch,
      );
    });

    test('설치 시각 읽기에 실패하면 현재 시각을 저장하고 유예다', () async {
      final now = DateTime.utc(2026, 11, 12, 9);
      AdsService.debugNow = () => now;
      AdsService.debugReadInstallTime = () async => throw StateError('boom');
      final adUnitId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple',
      );

      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AdInstallGrace.storageKey),
        now.millisecondsSinceEpoch,
      );
    });

    test('안드로이드 출시판도 설치 후 71시간 59분이면 유예다', () async {
      final now = DateTime.utc(2026, 11, 12, 10);
      AdsService.debugNow = () => now;
      _setPackage(
        installerStore: 'com.android.vending',
        installTime: now.subtract(const Duration(hours: 71, minutes: 59)),
      );
      final adUnitId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.android,
        installerStore: 'com.android.vending',
      );

      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isTrue,
      );
    });

    test('디버그·TestFlight 는 유예를 보지 않고 처음 본 시각도 쓰지 않는다', () async {
      final now = DateTime.utc(2026, 11, 12);
      AdsService.debugNow = () => now;
      _setPackage(installerStore: 'com.apple', installTime: now);

      final debugId = AdsService.bannerAdUnitIdFor(
        releaseMode: false,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple',
      );
      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(debugId),
        isFalse,
      );

      final testFlightId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple.testflight',
      );
      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          testFlightId,
        ),
        isFalse,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AdInstallGrace.storageKey), isNull);
    });

    test('72시간이 지나면 유예가 아니고 bannerAdUnitIdFor 반환은 지금과 같다', () async {
      final now = first.add(const Duration(hours: 72));
      SharedPreferences.setMockInitialValues({
        AdInstallGrace.storageKey: first.millisecondsSinceEpoch,
      });
      AdsService.debugNow = () => now;
      _setPackage(installerStore: 'com.apple', installTime: DateTime.utc(2020));
      final adUnitId = AdsService.bannerAdUnitIdFor(
        releaseMode: true,
        platform: TargetPlatform.iOS,
        installerStore: 'com.apple',
      );

      expect(
        await AdsService.instance.shouldSuppressRealAdsForInstallGrace(
          adUnitId,
        ),
        isFalse,
      );
      expect(
        AdsService.bannerAdUnitIdFor(
          releaseMode: true,
          platform: TargetPlatform.iOS,
          installerStore: 'com.apple',
        ),
        _iosReal,
      );
      expect(
        AdsService.bannerAdUnitIdFor(
          releaseMode: true,
          platform: TargetPlatform.android,
          installerStore: null,
        ),
        _androidReal,
      );
      expect(
        AdsService.bannerAdUnitIdFor(
          releaseMode: false,
          platform: TargetPlatform.iOS,
          installerStore: 'com.apple',
        ),
        _iosTest,
      );
      expect(
        AdsService.bannerAdUnitIdFor(
          releaseMode: false,
          platform: TargetPlatform.android,
          installerStore: null,
        ),
        _androidTest,
      );
    });
  });
}
