// T-261112-020: 유예 중 배너는 광고 객체를 만들지 않고 자리도 차지하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/ad_install_grace.dart';
import 'package:simple_memo_app/services/ads_service.dart';
import 'package:simple_memo_app/services/premium_service.dart';
import 'package:simple_memo_app/widgets/ad_banner.dart';

const _adsChannel = MethodChannel('plugins.flutter.io/google_mobile_ads');

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
  final calls = <String>[];

  setUp(() {
    calls.clear();
    AdsService.debugReset();
    AdsService.instance.removeAds.value = false;
    PremiumService.instance.resetForTest();
    SharedPreferences.setMockInitialValues({});
    _setPackage(installerStore: 'com.apple');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_adsChannel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    AdsService.debugReset();
    AdsService.instance.removeAds.value = false;
    PremiumService.instance.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_adsChannel, null);
  });

  Future<void> pumpBanner(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AdBanner(),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  void armRealIosRelease(DateTime now) {
    AdsService.debugNow = () => now;
    AdsService.debugReleaseMode = true;
    AdsService.debugPlatform = TargetPlatform.iOS;
    _setPackage(installerStore: 'com.apple');
  }

  testWidgets('유예 중에는 광고 객체를 만들지 않고 자리도 차지하지 않는다', (tester) async {
    final now = DateTime.utc(2026, 11, 12, 12);
    SharedPreferences.setMockInitialValues({
      AdInstallGrace.storageKey: now
          .subtract(const Duration(hours: 71, minutes: 59))
          .millisecondsSinceEpoch,
    });
    armRealIosRelease(now);
    var loadCalled = false;
    AdsService.debugLoadBanner = (_) async => loadCalled = true;

    await pumpBanner(tester);
    await tester.pump();
    final decision = AdsService.debugLastGraceDecision;
    expect(decision, isNotNull);
    expect(await decision, isTrue);
    await tester.pump();

    expect(AdsService.bannerAdsCreatedForTest, 0);
    expect(loadCalled, isFalse);
    expect(calls, isEmpty);
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.getSize(find.byType(AdBanner)).height, 0);
  });

  testWidgets('광고 제거 구매가 먼저라 유예 저장도 광고 요청도 하지 않는다', (tester) async {
    final now = DateTime.utc(2026, 11, 12, 12);
    AdsService.instance.removeAds.value = true;
    armRealIosRelease(now);
    _setPackage(installerStore: 'com.apple', installTime: now);

    await pumpBanner(tester);
    await tester.pump();

    expect(AdsService.debugLastGraceDecision, isNull);
    expect(AdsService.bannerAdsCreatedForTest, 0);
    expect(calls, isEmpty);
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.getSize(find.byType(AdBanner)).height, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AdInstallGrace.storageKey), isNull);
  });
}
