// 메모요 1.0.7 ②④-2 — 리스트 soft-delete 전환 검증.
// onReorder 콜백 직접 invoke 패턴은 memo_list_reorder_test.dart 와 동일
// (nested-scroll + shrinkWrap 환경에서 drag gesture flaky → callback contract 검증).
// SDK skew(3.41.9 non-null onReorder ↔ 3.44 nullable) 안전망.
// ignore_for_file: unnecessary_non_null_assertion, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Memo active(String id, String content, DateTime t, {bool fav = false}) => Memo(
        id: id,
        content: content,
        createdAt: t,
        updatedAt: t,
        isFavorite: fav,
      );

  Memo trashed(String id, String content, DateTime t, {bool fav = false}) =>
      active(id, content, t, fav: fav).copyWith(deletedAt: t);

  group('리스트 필터 — 휴지통 항목 제외', () {
    testWidgets('deletedAt != null 메모는 일반 리스트에 표시되지 않는다', (tester) async {
      final now = DateTime(2026, 6, 4, 10);
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([
          active('a', '활성 메모', now),
          trashed('b', '휴지통 메모', now),
        ]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('활성 메모'), findsOneWidget);
      expect(find.text('휴지통 메모'), findsNothing);
    });

    testWidgets('모든 메모가 휴지통이면 빈 상태 화면', (tester) async {
      final now = DateTime(2026, 6, 4, 10);
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([trashed('a', '휴지통만', now)]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('휴지통만'), findsNothing);
      expect(find.textContaining('아직 메모가 없어요'), findsOneWidget);
    });
  });

  group('삭제 = soft-delete (durable, hard-delete 아님)', () {
    testWidgets('스와이프 삭제 시 저장소에서 제거되지 않고 deletedAt 마킹된다', (tester) async {
      final now = DateTime(2026, 6, 4, 10);
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([active('a', '삭제될 메모', now)]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      await tester.drag(find.text('삭제될 메모'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      // 화면에서 사라짐
      expect(find.text('삭제될 메모'), findsNothing);

      // 저장소엔 deletedAt 마킹된 채 잔존 (hard-delete 였다면 0개)
      final saved = Memo.decodeList(
        (await SharedPreferences.getInstance()).getString('memos')!,
      );
      expect(saved.length, 1, reason: 'soft-delete — 저장소에서 안 지워짐');
      expect(saved.single.id, 'a');
      expect(saved.single.deletedAt, isNotNull, reason: 'deletedAt 마킹됨 (휴지통行)');
    });

    testWidgets('UNDO(실행 취소) 시 deletedAt 가 지워지고 리스트에 복귀', (tester) async {
      final now = DateTime(2026, 6, 4, 10);
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([active('a', '복구될 메모', now)]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      await tester.drag(find.text('복구될 메모'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(find.text('복구될 메모'), findsOneWidget);
      final saved = Memo.decodeList(
        (await SharedPreferences.getInstance()).getString('memos')!,
      );
      expect(saved.single.deletedAt, isNull, reason: 'UNDO = deletedAt 복구');
    });
  });

  group('reorder 인덱스 정확성 — 휴지통 섞여 있을 때 활성만 이동', () {
    testWidgets('일반 그룹에 휴지통 항목이 끼어 있어도 활성 인덱스로 정확히 reorder', (tester) async {
      // 저장소 순서: n1(활성) · nTrash(휴지통) · n3(활성). 모두 일반 그룹.
      // 화면 표시 = [n1, n3]. nTrash 가 _memos[1] 에 끼어 있어 인덱스 필터가
      // 없으면 reorder(1,0) 이 nTrash 를 건드려 어긋난다 — 필터 정합성 검증.
      final now = DateTime(2026, 6, 4, 10);
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([
          active('n1', 'N1 일반 첫째', now),
          trashed('nTrash', 'NT 휴지통', now.add(const Duration(seconds: 1))),
          active('n3', 'N3 일반 셋째', now.add(const Duration(seconds: 2))),
        ]),
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('NT 휴지통'), findsNothing);
      expect(find.text('N1 일반 첫째'), findsOneWidget);
      expect(find.text('N3 일반 셋째'), findsOneWidget);

      final reorderable = tester
          .widgetList<ReorderableListView>(find.byType(ReorderableListView))
          .first;
      expect(reorderable.onReorder, isA<ReorderCallback>());

      // 화면 active 인덱스 1(=N3) 을 0 으로 이동.
      reorderable.onReorder!(1, 0);
      await tester.pumpAndSettle();

      final saved = Memo.decodeList(
        (await SharedPreferences.getInstance()).getString('memos')!,
      );
      // 활성 표시 순서는 [N3, N1] 로 바뀌고, 휴지통 nTrash 는 보존된다.
      final activeIds =
          saved.where((m) => m.deletedAt == null).map((m) => m.id).toList();
      expect(activeIds, ['n3', 'n1'], reason: '활성만 정확히 reorder (nTrash 미건드림)');
      expect(saved.any((m) => m.id == 'nTrash' && m.deletedAt != null), isTrue,
          reason: '휴지통 항목 보존');

      // 화면에서도 N3 가 N1 보다 위
      expect(
        tester.getTopLeft(find.text('N3 일반 셋째')).dy,
        lessThan(tester.getTopLeft(find.text('N1 일반 첫째')).dy),
      );
    });
  });
}
