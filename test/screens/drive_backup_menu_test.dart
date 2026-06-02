import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'overflow 메뉴에 "Drive 에 백업" 항목이 있고, 메모 0개일 때 탭하면 안내 SnackBar',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      final overflow = find.byIcon(Icons.more_vert);
      expect(overflow, findsOneWidget);
      await tester.tap(overflow);
      await tester.pumpAndSettle();

      final driveItem = find.text('Drive 에 백업');
      expect(driveItem, findsOneWidget);
      expect(find.text('설정'), findsOneWidget);

      await tester.tap(driveItem);
      await tester.pump();

      expect(find.text('내보낼 메모가 없습니다'), findsOneWidget);
    },
  );
}
