import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

/// 신고된 증상 그대로: 라이트 모드인데 메모 목록 타일만 다크로 남았다
/// (T-260806-011, 2026-08-06 아니키 스크린샷).
void main() {
  const title = '라이트 모드 타일';

  Future<void> pumpList(WidgetTester tester, Brightness brightness) async {
    final now = DateTime(2026, 8, 6, 9, 40);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(
          id: 'memo-light-1',
          content: '$title\n본문',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: [
            brightness == Brightness.light ? AppPalette.light : AppPalette.dark,
          ],
        ),
        home: const MemoListScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 타일 바탕을 그리는 AnimatedContainer 의 실제 색.
  Color tileColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(title),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color!;
    }
    throw StateError('타일 배경색을 못 읽었다 — 위젯 구조가 바뀌었는지 확인할 것');
  }

  testWidgets('라이트 모드에서 메모 타일 바탕이 밝다', (tester) async {
    await pumpList(tester, Brightness.light);

    expect(find.text(title), findsOneWidget);
    expect(tileColor(tester), AppPalette.light.surface);
  });

  testWidgets('다크 모드에서는 그대로 어둡다 — 대조군', (tester) async {
    // 위 테스트가 "그냥 아무 색이나 통과" 가 아님을 보이는 반대쪽 관측.
    await pumpList(tester, Brightness.dark);

    expect(find.text(title), findsOneWidget);
    expect(tileColor(tester), AppPalette.dark.surface);
  });

  testWidgets('라이트 모드에서 목록 제목 글자가 어둡다', (tester) async {
    await pumpList(tester, Brightness.light);

    final text = tester.widget<Text>(find.text(title));
    expect(text.style?.color, AppPalette.light.textPrimary);
  });
}
