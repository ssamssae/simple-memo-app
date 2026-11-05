// T-261104-013: 디버그·프로필 빌드는 실광고 단위를 쓰지 않는다.
// 2026-11-04 구글 게시자 계정이 무효 트래픽으로 29일 정지됐다. 개발·실기기 시험이 실광고를 노출·클릭하지 않게 고정한다.
// T-261104-014 B안: iOS 출시판도 앱스토어에서 받은 설치만 실광고 단위다. TestFlight·개발 서명 설치는 시험 단위다.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_memo_app/services/ads_service.dart';

const _publisher = 'ca-app-pub-7025432711849670/';
const _googleTest = 'ca-app-pub-3940256099942544/';
const _iosReal = 'ca-app-pub-7025432711849670/2649951313';
const _iosTest = 'ca-app-pub-3940256099942544/2934735716';
const _androidReal = 'ca-app-pub-7025432711849670/5924152772';
const _androidTest = 'ca-app-pub-3940256099942544/6300978111';

void main() {
  group('bannerAdUnitIdFor', () {
    test('디버그·프로필은 모든 플랫폼·설치 출처에서 구글 공식 시험 배너다', () {
      for (final platform in TargetPlatform.values) {
        for (final store in ['com.apple', 'com.apple.testflight', 'com.android.vending', null]) {
          final id = AdsService.bannerAdUnitIdFor(
              releaseMode: false, platform: platform, installerStore: store);
          expect(id, startsWith(_googleTest), reason: '$platform $store');
          expect(id, isNot(contains(_publisher)), reason: '$platform $store');
        }
      }
      expect(
          AdsService.bannerAdUnitIdFor(
              releaseMode: false, platform: TargetPlatform.iOS, installerStore: 'com.apple'),
          _iosTest);
      expect(
          AdsService.bannerAdUnitIdFor(
              releaseMode: false, platform: TargetPlatform.android, installerStore: null),
          _androidTest);
    });

    test('iOS 출시판은 앱스토어 설치(com.apple)만 메모요 실제 배너다', () {
      expect(
          AdsService.bannerAdUnitIdFor(
              releaseMode: true, platform: TargetPlatform.iOS, installerStore: 'com.apple'),
          _iosReal);
    });

    test('iOS 출시판이라도 TestFlight·개발 서명·시뮬레이터·모름은 시험 배너다', () {
      for (final store in ['com.apple.testflight', 'com.apple.simulator', null, '']) {
        expect(
            AdsService.bannerAdUnitIdFor(
                releaseMode: true, platform: TargetPlatform.iOS, installerStore: store),
            _iosTest,
            reason: '$store');
      }
    });

    test('안드로이드 출시판은 설치 출처와 상관없이 메모요 실제 배너다', () {
      for (final store in ['com.android.vending', null]) {
        expect(
            AdsService.bannerAdUnitIdFor(
                releaseMode: true, platform: TargetPlatform.android, installerStore: store),
            _androidReal,
            reason: '$store');
      }
    });
  });

  group('AdsService.instance', () {
    setUpAll(() {
      PackageInfo.setMockInitialValues(
        appName: 'Memoyo',
        packageName: 'com.daejongkang.simpleMemoApp',
        version: '1.0.24',
        buildNumber: '52',
        buildSignature: '',
        installerStore: 'com.apple.testflight',
      );
    });

    test('설치 출처는 package_info_plus 값을 그대로 읽는다', () async {
      expect(await AdsService.instance.installerStore, 'com.apple.testflight');
    });

    test('시험 실행(디버그 모드)에서 쓰는 배너 ID 는 시험 배너다', () async {
      expect(kReleaseMode, isFalse);
      expect(await AdsService.instance.bannerAdUnitId(), startsWith(_googleTest));
    });
  });
}
