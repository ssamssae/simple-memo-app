import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T-260719-019 재발 방지 fixture (원칙10): l10n 레일 밖 lib/ 코드에
/// 하드코딩 한글 리터럴이 다시 유입되면 이 테스트가 깨진다.
///
/// 제외 목록(사유):
/// - lib/l10n/            : ko 원문의 정본 위치.
/// - lib/ait/, main_ait*  : 앱인토스 미니앱 레인 — 한국 전용 채널로 영어
///                          로케일 표면이 아니며 AppStrings 미사용 (별도 레일).
void main() {
  test('lib/ 하드코딩 한글 리터럴 0건 (l10n·ait 레인 제외)', () {
    final han = RegExp(r'[가-힣]');
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      if (path.startsWith('lib/l10n/') ||
          path.startsWith('lib/ait/') ||
          path == 'lib/main_ait.dart' ||
          path == 'lib/main_ait_spike.dart') {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 주석부 제거(근사): URL 의 // 는 보존, 그 외 // 이후는 주석으로 간주.
        final code = (line.contains('//') && !line.contains('https://'))
            ? line.split('//').first
            : line;
        if (han.hasMatch(code)) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '하드코딩 한글 리터럴 발견 — lib/l10n/app_strings.dart 키로 이관하세요:\n'
          '${offenders.join('\n')}',
    );
  });
}
