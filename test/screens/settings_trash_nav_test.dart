// 메모요 1.0.7 ②④-3 — 설정 화면에서 휴지통 진입점.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        'close' => null,
        _ => throw PlatformException(
          code: 'UNEXPECTED_MINILM_TEST_CALL',
          message: call.method,
        ),
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  testWidgets('설정 → "휴지통" ListTile 탭 → TrashScreen 진입', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList(<Memo>[]),
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('휴지통'),
      160,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('휴지통'), findsOneWidget, reason: '설정에 휴지통 진입점 노출');
    await tester.tap(find.text('휴지통'));
    await tester.pumpAndSettle();

    // TrashScreen 진입 확인 — 빈 상태 안내는 TrashScreen 고유.
    expect(find.textContaining('휴지통이 비어있습니다'), findsOneWidget);
  });
}
