// 메모요 1.0.7 ②④-3 — 휴지통 화면 동작 검증.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/trash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t = DateTime(2026, 6, 4, 10);
  Memo active(String id, String content) =>
      Memo(id: id, content: content, createdAt: t, updatedAt: t);
  Memo trashed(String id, String content, {Duration ago = Duration.zero}) => Memo(
        id: id,
        content: content,
        createdAt: t,
        updatedAt: t,
        deletedAt: DateTime.now().subtract(ago),
      );

  Future<List<Memo>> saved() async => Memo.decodeList(
        (await SharedPreferences.getInstance()).getString('memos')!,
      );

  testWidgets('휴지통 항목만 노출 + "N일 후 영구삭제" 라벨 (활성 제외)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        active('a', '활성 메모'),
        trashed('b', '휴지통 메모'),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    expect(find.text('휴지통 메모'), findsOneWidget);
    expect(find.text('활성 메모'), findsNothing);
    expect(find.textContaining('영구삭제'), findsWidgets);
  });

  testWidgets('빈 상태 — 휴지통 비었을 때 안내 텍스트', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a', '활성만 있음')]),
    });
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('휴지통이 비어있습니다'), findsOneWidget);
  });

  testWidgets('항목 탭 → 복구 → deletedAt 클리어 + 목록서 사라짐', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([trashed('b', '복구 대상')]),
    });
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('복구 대상'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복구'));
    await tester.pumpAndSettle();

    final s = await saved();
    expect(s.single.id, 'b');
    expect(s.single.deletedAt, isNull, reason: '복구 = deletedAt 클리어(활성화)');
    expect(find.text('복구 대상'), findsNothing);
  });

  testWidgets('항목 탭 → 즉시 영구삭제 → 저장소에서 완전 제거', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([trashed('b', '영구삭제 대상')]),
    });
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('영구삭제 대상'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('즉시 영구삭제'));
    await tester.pumpAndSettle();

    expect(await saved(), isEmpty);
  });

  testWidgets('휴지통 비우기 → 휴지통 전체 영구삭제, 활성 메모 무변경', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        active('keep', '활성 메모'),
        trashed('t1', '휴지통 1'),
        trashed('t2', '휴지통 2'),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    // AppBar '비우기' (이 시점엔 다이얼로그 없어 유일)
    await tester.tap(find.widgetWithText(TextButton, '비우기'));
    await tester.pumpAndSettle();
    // 확인 다이얼로그의 '비우기'
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, '비우기'),
    ));
    await tester.pumpAndSettle();

    final s = await saved();
    expect(s.length, 1);
    expect(s.single.id, 'keep');
    expect(s.single.deletedAt, isNull);
    expect(find.textContaining('휴지통이 비어있습니다'), findsOneWidget);
  });
}
