import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('설정에서 이용약관과 개인정보처리방침을 열 수 있다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);

    await tester.tap(find.text('이용약관'));
    await tester.pumpAndSettle();

    expect(find.textContaining('메모요 이용약관'), findsOneWidget);
    expect(find.textContaining('최종 게시 전 운영자의 법무 검토'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('개인정보처리방침'));
    await tester.pumpAndSettle();

    expect(find.textContaining('메모요 개인정보처리방침'), findsOneWidget);
    expect(find.textContaining('로컬 중심 메모 앱'), findsOneWidget);
  });
}
