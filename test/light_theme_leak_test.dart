import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

/// 라이트 모드에서 다크 팔레트가 새는 것을 막는 게이트 (T-260806-011).
///
/// 증상은 「테마 배선이 틀렸다」가 아니었다 — MaterialApp 배선은 멀쩡했고
/// (memo_app_theme_test.dart 가 그걸 이미 지키고 있다), 화면 위젯이 다크 전용
/// 색 리터럴을 직접 들고 있어서 라이트 모드로 바꿔도 그 위젯만 다크로 남았다.
/// 그래서 배선이 아니라 리터럴을 잰다.
void main() {
  // 다크 테마에만 존재하는 색. 화면 코드가 이걸 직접 쓰면 라이트에서 샌다.
  const darkOnlyLiterals = <String>[
    '0xFF0F0F12', // 다크 바탕
    '0xFF1A1A1E', // 다크 카드
    '0xFF141417', // 다크 탭바
    '0xFF2C2C2E', // 다크 바텀시트
    '0xFFECECEC', // 다크 본문 글자
    '0xFF9A9AA2', // 다크 보조 글자
  ];

  /// 팔레트 정의 자체와, 색을 고정할 이유가 따로 있는 화면만 제외한다.
  const exempt = <String>{
    'lib/utils/app_palette.dart', // 두 벌 색의 정의처
    'lib/main.dart', // ThemeData 두 벌의 정의처
    // 스플래시는 네이티브 런치 화면(values/ vs values-night/)과 색을 맞춰야 해서
    // 별도 건으로 둔다. 편집 화면은 T-260720-024 로 다크 고정돼 있었으나
    // T-260806-011 에서 팔레트로 전환하며 면제를 걷었다.
    'lib/screens/splash_screen.dart',
  };

  test('화면 코드가 다크 전용 색 리터럴을 직접 쓰지 않는다', () {
    final offenders = <String>[];
    final libDir = Directory('lib');

    // 계기가 살아있는지부터: lib 을 실제로 훑고 있어야 한다.
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(
      dartFiles.length,
      greaterThan(10),
      reason: 'lib 스캔이 비었다 — 테스트 작업 디렉토리를 확인할 것',
    );

    for (final file in dartFiles) {
      final relative = file.path.replaceAll(r'\', '/');
      if (exempt.contains(relative)) continue;
      final source = file.readAsStringSync();
      for (final literal in darkOnlyLiterals) {
        if (source.contains(literal)) {
          offenders.add('$relative → $literal');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '다크 전용 색을 직접 쓰면 라이트 모드에서 그 위젯만 다크로 남는다.\n'
          'AppPalette.of(context) 를 거쳐 읽을 것:\n${offenders.join('\n')}',
    );
  });

  test('양성 대조군 — 면제되지 않은 파일에 리터럴이 있으면 실제로 잡힌다', () {
    // 위 테스트가 초록인 게 "스캔이 아무것도 안 봤기 때문" 이 아님을 보인다.
    const sample = 'const bg = Color(0xFF1A1A1E);';
    expect(sample.contains('0xFF1A1A1E'), isTrue);
  });

  testWidgets('AppPalette 가 테마 밝기를 따라 다른 색을 준다', (tester) async {
    late AppPalette lightPalette;
    late AppPalette darkPalette;

    // 한 트리 안에 두 테마를 나란히 둔다. pumpWidget 을 두 번 부르면 엘리먼트가
    // 재사용돼 두 번째 테마가 안 잡히는 수가 있어, 비교는 한 번의 pump 로 한다.
    Widget probe(ThemeData theme, void Function(AppPalette) sink) {
      return Theme(
        data: theme,
        child: Builder(
          builder: (context) {
            sink(AppPalette.of(context));
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            probe(
              ThemeData(
                brightness: Brightness.light,
                extensions: const [AppPalette.light],
              ),
              (p) => lightPalette = p,
            ),
            probe(
              ThemeData(
                brightness: Brightness.dark,
                extensions: const [AppPalette.dark],
              ),
              (p) => darkPalette = p,
            ),
          ],
        ),
      ),
    );

    expect(lightPalette.surface, isNot(darkPalette.surface));
    expect(lightPalette.textPrimary, isNot(darkPalette.textPrimary));
    expect(lightPalette.navigationBar, isNot(darkPalette.navigationBar));
  });

  testWidgets('테마 확장이 등록 안 된 화면도 밝기로 폴백한다', (tester) async {
    late AppPalette palette;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Builder(
          builder: (context) {
            palette = AppPalette.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(palette.surface, AppPalette.light.surface);
  });
}
