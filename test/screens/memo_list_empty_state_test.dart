import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('메모 0건 → empty state 아이콘 + 안내 텍스트 (FAB 제거, 새메모는 바텀바)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    // 안내 텍스트 — 새메모 진입점이 FAB 에서 바텀바 탭으로 바뀜.
    expect(find.text('아직 메모가 없어요.\n아래 새메모 탭을 눌러 첫 메모를 남겨보세요.'), findsOneWidget);

    // empty 아이콘 (sticky_note_2_outlined, color: amber)
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);

    // FAB 는 제거됨 (새메모는 HomeShell 바텀바 탭으로 이동).
    expect(find.byType(FloatingActionButton), findsNothing);

    // 선택할 메모가 없을 때는 편집 모드 진입점을 숨긴다.
    expect(find.text('편집'), findsNothing);
    expect(find.text('전체선택'), findsNothing);
    expect(find.text('삭제'), findsNothing);

    // ReorderableListView 는 메모 0건이라 그려지지 X
    expect(find.byType(ReorderableListView), findsNothing);
  });
}
