// spec 1.0.7-ga-qa-scenarios.md §1.2 — 즐겨찾기+일반 섞인 메모 중 부분 선택 일괄 삭제 + UNDO
// → 즐겨찾기 그룹 순서가 복원되는지 (전체선택 케이스는 memo_list_undo_batch_test 에서 커버)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '편집모드 → 즐겨찾기·일반 섞어 부분 선택 → 삭제 → UNDO → 그룹 순서 복원',
    (tester) async {
      final now = DateTime(2026, 5, 29, 2, 10);
      final fav1 = Memo(
        id: 'fav-1',
        content: '⭐ 즐겨찾기 1\n본문',
        createdAt: now,
        updatedAt: now,
        isFavorite: true,
      );
      final normal1 = Memo(
        id: 'n-1',
        content: '일반 1\n본문',
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );
      final normal2 = Memo(
        id: 'n-2',
        content: '일반 2\n본문',
        createdAt: now.add(const Duration(seconds: 2)),
        updatedAt: now.add(const Duration(seconds: 2)),
      );

      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([fav1, normal1, normal2]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('⭐ 즐겨찾기 1'), findsOneWidget);
      expect(find.text('일반 1'), findsOneWidget);
      expect(find.text('일반 2'), findsOneWidget);

      // 편집모드 진입
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();

      // 즐겨찾기 1 + 일반 2 만 선택 (일반 1 은 제외)
      await tester.tap(find.text('⭐ 즐겨찾기 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반 2'));
      await tester.pumpAndSettle();

      // 삭제 버튼 (선택 카운트 2)
      await tester.tap(find.text('삭제 (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('⭐ 즐겨찾기 1'), findsNothing);
      expect(find.text('일반 2'), findsNothing);
      expect(find.text('일반 1'), findsOneWidget, reason: '미선택 메모는 남음');
      expect(find.text('메모 2개를 삭제했습니다'), findsOneWidget);

      // UNDO 탭 → 두 메모 모두 복원, 그룹 순서 보존 (즐겨찾기 → 일반)
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(find.text('⭐ 즐겨찾기 1'), findsOneWidget);
      expect(find.text('일반 1'), findsOneWidget);
      expect(find.text('일반 2'), findsOneWidget);

      // 그룹 순서: 즐겨찾기 1 최상단, 그 다음 일반 1, 그 다음 일반 2
      final favY = tester.getTopLeft(find.text('⭐ 즐겨찾기 1')).dy;
      final n1Y = tester.getTopLeft(find.text('일반 1')).dy;
      final n2Y = tester.getTopLeft(find.text('일반 2')).dy;
      expect(favY < n1Y, isTrue, reason: '즐겨찾기가 일반 그룹 위');
      expect(n1Y < n2Y, isTrue, reason: '일반 그룹 안에서 1 → 2 순서');
    },
  );
}
