// 메모요 1.0.7 ②④-3 — _loadMemos 진입 시 30일 만료 휴지통 자동 purge 트리거.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<Memo>> saved() async => Memo.decodeList(
        (await SharedPreferences.getInstance()).getString('memos')!,
      );

  testWidgets('cold start(_loadMemos) 시 31일 지난 휴지통은 purge, 29일·활성은 잔존',
      (tester) async {
    final base = DateTime(2026, 1, 1);
    final expired = Memo(
      id: 'expired',
      content: '31일 전 삭제',
      createdAt: base,
      updatedAt: base,
      deletedAt: DateTime.now().subtract(const Duration(days: 31)),
    );
    final recentTrash = Memo(
      id: 'recent',
      content: '5일 전 삭제',
      createdAt: base,
      updatedAt: base,
      deletedAt: DateTime.now().subtract(const Duration(days: 5)),
    );
    final activeMemo = Memo(
      id: 'active',
      content: '활성 메모',
      createdAt: base,
      updatedAt: base,
    );

    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([expired, recentTrash, activeMemo]),
    });

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    final s = await saved();
    expect(s.map((m) => m.id).toSet(), {'recent', 'active'},
        reason: '31일 지난 expired 만 purge, 29일 미만·활성은 잔존');

    // 활성 메모는 리스트에 표시, 휴지통 항목은 비표시.
    expect(find.text('활성 메모'), findsOneWidget);
    expect(find.text('5일 전 삭제'), findsNothing);
  });
}
