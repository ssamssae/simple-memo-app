import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS 는 실제 scene delegate 로 UIScene 을 채택한다 — 빈 UISceneConfigurations 우회는 iOS 27 SDK 빌드에서 실행 즉시 충돌 (T-261027-011)',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        RegExp(r'<key>UISceneConfigurations</key>\s*<dict\s*/>').hasMatch(plist),
        isFalse,
        reason: '1.0.21(47) TestFlight 충돌 원인 — _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption',
      );
      expect(plist, contains('<key>UIWindowSceneSessionRoleApplication</key>'));
      expect(
        RegExp(
          r'<key>UISceneDelegateClassName</key>\s*<string>FlutterSceneDelegate</string>',
        ).hasMatch(plist),
        isTrue,
      );
    },
  );

  test('플러그인 등록은 암묵 엔진 콜백에서 한다 — scene 방식에선 didFinishLaunching 때 엔진이 없다', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(delegate, contains('FlutterImplicitEngineDelegate'));
    expect(delegate, contains('func didInitializeImplicitFlutterEngine'));
    expect(delegate, isNot(contains('GeneratedPluginRegistrant.register(with: self)')));
  });
}
