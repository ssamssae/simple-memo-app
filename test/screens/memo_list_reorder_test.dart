// SDK 정책 v1 (옵션 1 fvm 통일) 확정 전 cross-SDK lint cascade 끊기.
// Flutter 3.44+ onReorderItem API wiring 회귀 방지.
// ignore_for_file: unnecessary_non_null_assertion

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// favorites / normal 양쪽 섹션 모두 ReorderableListView 인스턴스를 갖는다.
  /// 인덱스 순서대로 [favorites, normals] 가 나옴 (build 순서).
  Future<ReorderableListView> pumpAndFindReorderable(
    WidgetTester tester, {
    required int index,
  }) async {
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();
    final widgets = tester
        .widgetList<ReorderableListView>(find.byType(ReorderableListView))
        .toList();
    expect(widgets.length, greaterThan(index));
    return widgets[index];
  }

  testWidgets(
    'favorites reorder — onReorderItem(0,1) → [F1,F2,F3] → [F2,F1,F3] + SharedPreferences 영속',
    (tester) async {
      // 사이클 #3 onReorder → onReorderItem 회귀 사고 재발 방지 안전망.
      // 콜백 named arg 가 'onReorderItem' 이 아니면 컴파일 실패 + 런타임에서
      // 콜백 invoke 시 의도된 reorder 가 안 일어나면 검증 실패.
      final now = DateTime(2026, 5, 29, 2, 0);
      final favs = [
        Memo(
          id: 'fav-1',
          content: 'F1 즐겨찾기 첫째\n본문',
          createdAt: now,
          updatedAt: now,
          isFavorite: true,
        ),
        Memo(
          id: 'fav-2',
          content: 'F2 즐겨찾기 둘째\n본문',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
          isFavorite: true,
        ),
        Memo(
          id: 'fav-3',
          content: 'F3 즐겨찾기 셋째\n본문',
          createdAt: now.add(const Duration(seconds: 2)),
          updatedAt: now.add(const Duration(seconds: 2)),
          isFavorite: true,
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList(favs),
      });

      final reorderable = await pumpAndFindReorderable(tester, index: 0);
      // 콜백 wiring 자체 — 사이클 #3 회귀 직접 방어. ReorderCallback 타입.
      expect(reorderable.onReorderItem, isA<ReorderCallback>());

      // 콜백 직접 invoke — drag gesture 시뮬레이션은 nested-scroll +
      // shrinkWrap 환경에서 flaky 하므로 callback contract 만 검증.
      reorderable.onReorderItem!(0, 1);
      await tester.pumpAndSettle();

      // _onReorderFav 의 알고리즘 (newIndex 보정 X) 결과: [F2, F1, F3]
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('memos');
      expect(saved, isNotNull);
      final restored = Memo.decodeList(saved!);
      expect(restored.map((m) => m.id).toList(),
          equals(['fav-2', 'fav-1', 'fav-3']),
          reason: 'F1 을 인덱스 1 로 이동하면 [F2, F1, F3] 가 SharedPreferences 에 영속');

      // 화면 visible 순서도 동일하게 변경됐는지 — F2 첫 줄이 F1 첫 줄보다 위에 그려짐
      final f2Pos = tester.getTopLeft(find.text('F2 즐겨찾기 둘째'));
      final f1Pos = tester.getTopLeft(find.text('F1 즐겨찾기 첫째'));
      expect(f2Pos.dy, lessThan(f1Pos.dy));
    },
  );

  testWidgets(
    'normal reorder — onReorderItem(2,0) → [N1,N2,N3] → [N3,N1,N2] + SharedPreferences 영속',
    (tester) async {
      final now = DateTime(2026, 5, 29, 2, 5);
      final normals = [
        Memo(
          id: 'n-1',
          content: 'N1 일반 첫째\n본문',
          createdAt: now,
          updatedAt: now,
        ),
        Memo(
          id: 'n-2',
          content: 'N2 일반 둘째\n본문',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
        Memo(
          id: 'n-3',
          content: 'N3 일반 셋째\n본문',
          createdAt: now.add(const Duration(seconds: 2)),
          updatedAt: now.add(const Duration(seconds: 2)),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList(normals),
      });

      // favorites 가 없으므로 ReorderableListView 인스턴스 1개 (normals).
      final reorderable = await pumpAndFindReorderable(tester, index: 0);
      expect(reorderable.onReorderItem, isA<ReorderCallback>());

      reorderable.onReorderItem!(2, 0);
      await tester.pumpAndSettle();

      // _onReorderNormal 의 알고리즘 (newIndex 보정 X) 결과: [N3, N1, N2]
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('memos');
      expect(saved, isNotNull);
      final restored = Memo.decodeList(saved!);
      expect(restored.map((m) => m.id).toList(),
          equals(['n-3', 'n-1', 'n-2']),
          reason: 'N3 을 맨 앞으로 이동하면 [N3, N1, N2] 영속');

      final n3Pos = tester.getTopLeft(find.text('N3 일반 셋째'));
      final n1Pos = tester.getTopLeft(find.text('N1 일반 첫째'));
      expect(n3Pos.dy, lessThan(n1Pos.dy));
    },
  );
}
