import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

/// 아니키 2차 신고: 라이트 모드인데 편집 화면이 통째로 다크로 남았다
/// (T-260806-011, 2026-08-06 09:40 두 번째 스크린샷).
///
/// 이 화면은 T-260720-024 로 「헤더까지 다크 고정」 돼 있었다. 그건 설계가
/// 아니라, 본문이 다크로 박혀 있고 헤더 컨트롤이 흰색 하드코딩이라 라이트에서
/// 컨트롤이 묻히던 것을 막는 땜빵이었다. 색이 전부 팔레트를 거치게 되면서
/// 그 고정을 걷었고, 이 테스트가 걷힌 상태를 지킨다.
void main() {
  Future<void> pumpEditor(WidgetTester tester, Brightness brightness) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 8, 6, 9, 40);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: [
            brightness == Brightness.light ? AppPalette.light : AppPalette.dark,
          ],
        ),
        home: MemoEditScreen(
          memo: Memo(
            id: 'memo-edit-1',
            content: '편집 화면 본문',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color scaffoldColor(WidgetTester tester) {
    return tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
  }

  Color bodyTextColor(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField)).style!.color!;
  }

  testWidgets('라이트 모드에서 편집 화면 바탕이 밝다', (tester) async {
    await pumpEditor(tester, Brightness.light);

    expect(scaffoldColor(tester), AppPalette.light.background);
    expect(bodyTextColor(tester), AppPalette.light.textPrimary);
  });

  testWidgets('다크 모드에서는 그대로 어둡다 — 대조군', (tester) async {
    await pumpEditor(tester, Brightness.dark);

    expect(scaffoldColor(tester), AppPalette.dark.background);
    expect(bodyTextColor(tester), AppPalette.dark.textPrimary);
  });

  testWidgets('본문 글자와 바탕이 같은 색이 아니다 — 안 보이는 상태 차단', (tester) async {
    // T-260720-024 가 막으려던 실제 증상은 「글자가 바탕에 묻힌다」였다.
    // 색 이름이 아니라 그 조건을 직접 잰다.
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await pumpEditor(tester, brightness);
      expect(
        bodyTextColor(tester),
        isNot(scaffoldColor(tester)),
        reason: '$brightness 에서 본문 글자가 바탕에 묻힌다',
      );
    }
  });
}
