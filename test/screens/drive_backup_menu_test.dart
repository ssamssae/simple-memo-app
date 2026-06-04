import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

// 1.0.7 ① Drive UI 통합 후: Drive 백업/가져오기/되돌리기는 overflow 가 아니라
// 설정 → "백업 & 복원" 화면으로 이동. overflow 에는 '설정'만 남는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'overflow 메뉴에 Drive 항목(백업/가져오기/되돌리기)이 없고 "설정"만 남는다',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      final overflow = find.byIcon(Icons.more_vert);
      expect(overflow, findsOneWidget);
      await tester.tap(overflow);
      await tester.pumpAndSettle();

      expect(find.text('설정'), findsOneWidget);
      expect(find.text('Drive 에 백업'), findsNothing);
      expect(find.text('메모 가져오기'), findsNothing);
      expect(find.text('가져오기 되돌리기'), findsNothing);
    },
  );
}
