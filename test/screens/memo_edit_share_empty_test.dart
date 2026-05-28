import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  testWidgets(
    '빈 메모에서 공유 IconButton 탭 시 SnackBar 안내 + share intent 호출 X',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
        calls.add(call);
        return 'share-target';
      });

      await tester.pumpWidget(const MaterialApp(home: MemoEditScreen()));

      final shareButton = find.byTooltip('공유');
      expect(shareButton, findsOneWidget);

      await tester.tap(shareButton);
      await tester.pump();

      expect(find.text('공유할 내용이 없습니다.'), findsOneWidget);
      expect(calls, isEmpty);
    },
  );
}
