import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AndroidManifest 에 uses-permission 0건 — 사진 첨부는 Photo Picker/ACTION_IMAGE_CAPTURE 로 권한 없이 (T-260829-022)',
    () {
      final xml = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final perms = RegExp(
        r'<uses-permission[^>]*android:name="([^"]+)"',
      ).allMatches(xml).map((m) => m.group(1)).toList();
      expect(
        perms,
        isEmpty,
        reason: '권한을 추가하려면 spec §3.8 과 Play 데이터안전 선언을 먼저 갱신할 것',
      );
    },
  );
}
