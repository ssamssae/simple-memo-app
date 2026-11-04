// T-261104-013: 디버그·프로필 빌드는 실광고 단위를 쓰지 않는다.
// 2026-11-04 구글 게시자 계정이 무효 트래픽으로 29일 정지됐다. 개발·실기기 시험이 실광고를 노출·클릭하지 않게 고정한다.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/services/ads_service.dart';

const _publisher = 'ca-app-pub-7025432711849670/';
const _googleTest = 'ca-app-pub-3940256099942544/';

void main() {
  group('bannerAdUnitIdFor', () {
    test('디버그·프로필은 모든 플랫폼에서 구글 공식 시험 배너다', () {
      for (final platform in TargetPlatform.values) {
        final id = AdsService.bannerAdUnitIdFor(releaseMode: false, platform: platform);
        expect(id, startsWith(_googleTest), reason: '$platform');
        expect(id, isNot(contains(_publisher)), reason: '$platform');
      }
      expect(AdsService.bannerAdUnitIdFor(releaseMode: false, platform: TargetPlatform.iOS),
          'ca-app-pub-3940256099942544/2934735716');
      expect(AdsService.bannerAdUnitIdFor(releaseMode: false, platform: TargetPlatform.android),
          'ca-app-pub-3940256099942544/6300978111');
    });

    test('출시판은 메모요 실제 배너다', () {
      expect(AdsService.bannerAdUnitIdFor(releaseMode: true, platform: TargetPlatform.iOS),
          'ca-app-pub-7025432711849670/2649951313');
      expect(AdsService.bannerAdUnitIdFor(releaseMode: true, platform: TargetPlatform.android),
          'ca-app-pub-7025432711849670/5924152772');
    });
  });

  test('시험 실행(디버그 모드)에서 쓰는 배너 ID 는 시험 배너다', () {
    expect(kReleaseMode, isFalse);
    expect(AdsService.instance.bannerAdUnitId, startsWith(_googleTest));
  });
}
