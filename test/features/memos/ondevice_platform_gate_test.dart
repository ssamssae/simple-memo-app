import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stage2 keeps minimum OS and ABI declarations unchanged', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    final android = File('android/app/build.gradle.kts').readAsStringSync();

    expect(podfile, contains("platform :ios, '13.0'"));
    expect(android, contains('minSdk = flutter.minSdkVersion'));
    expect(android, isNot(contains('abiFilters')));
    expect(android, contains('onnxruntime-android:1.23.0'));
  });

  test('native MiniLM path is explicitly arm64 capability-gated', () {
    final activity = File(
      'android/app/src/main/kotlin/com/daejongkang/'
      'simple_memo_app/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('Build.SUPPORTED_ABIS.contains("arm64-v8a")'));
    expect(activity, contains('MethodChannel'));
  });
}
