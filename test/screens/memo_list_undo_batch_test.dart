import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '편집모드 → 전체선택 → 일괄삭제 → "메모 N개를 삭제했습니다" 복수 SnackBar + 실행 취소 시 전부 복원',
    (tester) async {
      final now = DateTime(2026, 5, 29, 1, 50);
      final memo1 = Memo(
        id: 'batch-1',
        content: '배치 첫째\n본문 1',
        createdAt: now,
        updatedAt: now,
      );
      final memo2 = Memo(
        id: 'batch-2',
        content: '배치 둘째\n본문 2',
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([memo1, memo2]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('배치 첫째'), findsOneWidget);
      expect(find.text('배치 둘째'), findsOneWidget);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('전체선택'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('삭제 (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('메모 2개를 삭제했습니다'), findsOneWidget);
      expect(find.text('실행 취소'), findsOneWidget);
      expect(find.text('배치 첫째'), findsNothing);
      expect(find.text('배치 둘째'), findsNothing);

      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(find.text('배치 첫째'), findsOneWidget);
      expect(find.text('배치 둘째'), findsOneWidget);
    },
  );
}
