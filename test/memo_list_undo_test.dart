import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  testWidgets('삭제한 메모를 스낵바 실행 취소로 복원한다', (tester) async {
    final now = DateTime(2026, 5, 29, 1, 30);
    final memo = Memo(
      id: 'memo-1',
      content: '삭제 테스트\n본문',
      createdAt: now,
      updatedAt: now,
    );

    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo]),
    });

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('삭제 테스트'), findsOneWidget);

    await tester.drag(find.text('삭제 테스트'), const Offset(-90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('메모를 삭제했습니다'), findsOneWidget);
    expect(find.text('실행 취소'), findsOneWidget);
    expect(find.text('삭제 테스트'), findsNothing);

    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();

    expect(find.text('삭제 테스트'), findsOneWidget);
  });
}
