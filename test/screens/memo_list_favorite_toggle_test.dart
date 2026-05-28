// spec 1.0.7-ga-qa-scenarios.md §1.1 step 3 — 스와이프 즐겨찾기 토글 + 그룹 순서 + 영속

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '스와이프 즐겨찾기 토글 시 메모가 그룹 최상단으로 이동하고 SharedPreferences 에 영속된다',
    (tester) async {
      final now = DateTime(2026, 5, 29, 2, 0);
      final memoA = Memo(
        id: 'fav-a',
        content: '메모 A\n본문',
        createdAt: now,
        updatedAt: now,
      );
      final memoB = Memo(
        id: 'fav-b',
        content: '메모 B\n본문',
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([memoA, memoB]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      // 초기 순서: A → B (둘 다 일반)
      final initialA = tester.getTopLeft(find.text('메모 A')).dy;
      final initialB = tester.getTopLeft(find.text('메모 B')).dy;
      expect(initialA < initialB, isTrue, reason: '초기엔 A 가 B 위에 있다');

      // B 를 오른쪽으로 스와이프 → 즐겨찾기 토글 (star 아이콘 탭)
      await tester.drag(find.text('메모 B'), const Offset(90, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();

      // 토글 후 순서: B (즐겨찾기, 상단) → A (일반)
      final afterA = tester.getTopLeft(find.text('메모 A')).dy;
      final afterB = tester.getTopLeft(find.text('메모 B')).dy;
      expect(
        afterB < afterA,
        isTrue,
        reason: '즐겨찾기 후엔 B 가 A 위로 올라간다',
      );

      // SharedPreferences 에 즐겨찾기 영속
      final prefs = await SharedPreferences.getInstance();
      final saved = Memo.decodeList(prefs.getString('memos') ?? '[]');
      final savedB = saved.firstWhere((m) => m.id == 'fav-b');
      final savedA = saved.firstWhere((m) => m.id == 'fav-a');
      expect(
        savedB.isFavorite,
        isTrue,
        reason: 'B 의 isFavorite=true 가 SharedPreferences 에 박힌다',
      );
      expect(
        savedA.isFavorite,
        isFalse,
        reason: 'A 는 그대로 일반 메모',
      );
    },
  );
}
