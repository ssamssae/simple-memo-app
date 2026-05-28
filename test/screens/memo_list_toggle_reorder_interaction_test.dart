import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// favorites 가 0건이면 ReorderableListView 인스턴스 1개 (normals)
  /// favorites + normals 둘 다 있으면 2개. index 0 = favorites, 1 = normals.
  ReorderableListView reorderableAt(WidgetTester tester, int index) {
    final widgets = tester
        .widgetList<ReorderableListView>(find.byType(ReorderableListView))
        .toList();
    expect(widgets.length, greaterThan(index));
    return widgets[index];
  }

  testWidgets(
    '토글로 즐겨찾기 추가 후 normal reorder 호출이 즐겨찾기 메모를 안 건드린다',
    (tester) async {
      // 시나리오: [N1, N2, N3] 모두 일반 → N3 즐겨찾기 토글 → 그룹 분리
      // → 일반 그룹 안에서 reorder(1, 0) (N2 ↔ N1) → 즐겨찾기 그룹의 N3 영향 0.
      // 사이클 #6 의 reorder 테스트는 그룹 단일이라 그룹 경계 보호 검증 부족 — 본 테스트가 갭 메꿈.
      final now = DateTime(2026, 5, 29, 2, 30);
      final memos = [
        Memo(
          id: 'n-1',
          content: 'N1 첫째\n본문',
          createdAt: now,
          updatedAt: now,
        ),
        Memo(
          id: 'n-2',
          content: 'N2 둘째\n본문',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
        Memo(
          id: 'n-3',
          content: 'N3 셋째\n본문',
          createdAt: now.add(const Duration(seconds: 2)),
          updatedAt: now.add(const Duration(seconds: 2)),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList(memos),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      // N3 을 오른쪽으로 스와이프 → 즐겨찾기 토글 (star 아이콘 탭)
      await tester.drag(find.text('N3 셋째'), const Offset(90, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();

      // 이제 favorites = [N3], normals = [N1, N2] → ReorderableListView 2개
      final favReorderable = reorderableAt(tester, 0);
      final normalReorderable = reorderableAt(tester, 1);
      expect(favReorderable.itemCount, 1);
      expect(normalReorderable.itemCount, 2);

      // normal reorder(1, 0) → [N3 fav | N2, N1] (N1 과 N2 swap, N3 영향 0)
      normalReorderable.onReorder(1, 0);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final saved = Memo.decodeList(prefs.getString('memos') ?? '[]');
      expect(saved.map((m) => m.id).toList(), equals(['n-3', 'n-2', 'n-1']),
          reason: '즐겨찾기 N3 첫 자리 보존 + normals 그룹 안에서만 N1/N2 swap');
      // 즐겨찾기 상태 보존
      final savedN3 = saved.firstWhere((m) => m.id == 'n-3');
      expect(savedN3.isFavorite, isTrue);
    },
  );

  testWidgets(
    '즐겨찾기 그룹 안 reorder 가 일반 그룹 영향 0',
    (tester) async {
      // 시나리오: [F1, F2, N1] (F1/F2 즐겨찾기, N1 일반) → fav reorder(0, 1) →
      // [F2, F1, N1] (F1 ↔ F2 swap, N1 영향 0).
      final now = DateTime(2026, 5, 29, 2, 35);
      final memos = [
        Memo(
          id: 'f-1',
          content: 'F1 즐겨찾기 첫째\n본문',
          createdAt: now,
          updatedAt: now,
          isFavorite: true,
        ),
        Memo(
          id: 'f-2',
          content: 'F2 즐겨찾기 둘째\n본문',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
          isFavorite: true,
        ),
        Memo(
          id: 'n-1',
          content: 'N1 일반\n본문',
          createdAt: now.add(const Duration(seconds: 2)),
          updatedAt: now.add(const Duration(seconds: 2)),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList(memos),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      final favReorderable = reorderableAt(tester, 0);
      final normalReorderable = reorderableAt(tester, 1);
      expect(favReorderable.itemCount, 2);
      expect(normalReorderable.itemCount, 1);

      // favorites reorder(0, 1) → [F2, F1, N1]
      favReorderable.onReorder(0, 1);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final saved = Memo.decodeList(prefs.getString('memos') ?? '[]');
      expect(saved.map((m) => m.id).toList(), equals(['f-2', 'f-1', 'n-1']),
          reason: '즐겨찾기 그룹 안 F1↔F2 swap + 일반 N1 자리 보존');
      // 일반 그룹 N1 isFavorite 변경 X
      final savedN1 = saved.firstWhere((m) => m.id == 'n-1');
      expect(savedN1.isFavorite, isFalse);
    },
  );
}
