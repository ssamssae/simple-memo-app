// 스토어 스크린샷 드라이버 — integration_test/screenshot_test.dart 가 찍은 픽셀을
// 디스크에 쓴다.
//
// 기제는 한줄일기(hanjul) test_driver/store_screenshots_test.dart 에서 이미
// 검증된 것을 그대로 옮겨온 것이다 (T-260805-017). 재발명이 아니다.
//
// 사용 (scripts/gen-store-screenshots.sh 가 기기별로 오케스트레이션한다):
//   SHOT_DEVICE=iphone-6.9 flutter drive \
//     --driver=test_driver/store_screenshots_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d <simulator-udid>
//
// 산출: build/screenshots/<SHOT_DEVICE>/<name>.png
//   SHOT_DEVICE 가 없으면 build/screenshots/<name>.png (composer 기본 --raw 경로).
//   이 경로는 scripts/compose_store_screenshots.py 의 --raw 계약과 맞춰 둔 것이다.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final device = Platform.environment['SHOT_DEVICE'] ?? '';
  final root = device.isEmpty
      ? 'build/screenshots'
      : 'build/screenshots/$device';

  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final dir = Directory(root);
          dir.createSync(recursive: true);
          final file = File('${dir.path}/$name.png');
          file.writeAsBytesSync(bytes);
          stderr.writeln('wrote ${file.path} (${bytes.length} bytes)');
          return true;
        },
  );
}
