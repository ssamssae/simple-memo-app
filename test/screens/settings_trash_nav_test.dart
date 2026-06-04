// 메모요 1.0.7 ②④-3 — 설정 화면에서 휴지통 진입점.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('설정 → "휴지통" ListTile 탭 → TrashScreen 진입', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList(<Memo>[]),
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('휴지통'), findsOneWidget, reason: '설정에 휴지통 진입점 노출');

    await tester.tap(find.text('휴지통'));
    await tester.pumpAndSettle();

    // TrashScreen 진입 확인 — 빈 상태 안내는 TrashScreen 고유.
    expect(find.textContaining('휴지통이 비어있습니다'), findsOneWidget);
  });
}
