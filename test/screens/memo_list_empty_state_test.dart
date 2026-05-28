import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '메모 0건 → empty state 아이콘 + 안내 텍스트 + FAB 가시성',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      // 안내 텍스트
      expect(
        find.text('아직 메모가 없어요.\n아래 + 버튼을 눌러 첫 메모를 남겨보세요.'),
        findsOneWidget,
      );

      // empty 아이콘 (sticky_note_2_outlined, color: amber)
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);

      // 메모 추가 진입점 FAB 가시성 — Scaffold 내 FloatingActionButton 한 개
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // ReorderableListView 는 메모 0건이라 그려지지 X
      expect(find.byType(ReorderableListView), findsNothing);
    },
  );
}
