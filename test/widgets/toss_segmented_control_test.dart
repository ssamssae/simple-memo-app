import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/utils/app_palette.dart';
import 'package:simple_memo_app/widgets/toss_segmented_control.dart';

// T-261103-005: 대종님 「시스템 라이트 다크 버튼 모양 토스톤 아닌거같아」.
// 토스 분절 버튼 = 회색 트랙 위에 선택 칸만 떠 있는 손잡이, 테두리·칸 구분선 없음.
void main() {
  Widget host(ThemeMode selected, ValueChanged<ThemeMode> onChanged) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: const [AppPalette.dark],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: TossSegmentedControl<ThemeMode>(
              segments: const [
                TossSegment(ThemeMode.system, '시스템'),
                TossSegment(ThemeMode.light, '라이트'),
                TossSegment(ThemeMode.dark, '다크'),
              ],
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('칸을 누르면 그 값으로 바뀐다', (tester) async {
    ThemeMode? picked;
    await tester.pumpWidget(host(ThemeMode.system, (m) => picked = m));
    await tester.tap(find.text('다크'));
    expect(picked, ThemeMode.dark);
  });

  testWidgets('선택 칸만 굵고 진한 글자, 나머지는 보조색이다', (tester) async {
    await tester.pumpWidget(host(ThemeMode.system, (_) {}));
    final on = tester.widget<Text>(find.text('시스템')).style!;
    final off = tester.widget<Text>(find.text('라이트')).style!;
    expect(on.fontWeight, FontWeight.w700);
    expect(on.color, AppPalette.dark.textPrimary);
    expect(off.fontWeight, FontWeight.w500);
    expect(off.color, AppPalette.dark.textSecondary);
  });

  testWidgets('손잡이는 트랙 위에서 선택 칸 아래로 옮겨 간다', (tester) async {
    await tester.pumpWidget(host(ThemeMode.light, (_) {}));
    await tester.pumpAndSettle();
    final thumb = find.byKey(const Key('toss-segmented-thumb'));
    expect(thumb, findsOneWidget);
    expect(
      tester.getRect(thumb).contains(tester.getCenter(find.text('라이트'))),
      isTrue,
      reason: '손잡이가 선택한 「라이트」 아래에 없다',
    );
    expect(
      tester.getRect(thumb).contains(tester.getCenter(find.text('다크'))),
      isFalse,
    );

    await tester.pumpWidget(host(ThemeMode.dark, (_) {}));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(thumb).contains(tester.getCenter(find.text('다크'))),
      isTrue,
      reason: '선택을 바꿨는데 손잡이가 따라오지 않는다',
    );
  });
}
