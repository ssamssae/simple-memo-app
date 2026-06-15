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
    '새 메모(저장 전)에는 공유 버튼이 숨겨져 share intent 호출 불가',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
        calls.add(call);
        return 'share-target';
      });

      await tester.pumpWidget(const MaterialApp(home: MemoEditScreen()));

      // 새 메모(widget.memo == null)에는 공유할 내용이 없어 공유 버튼을 숨긴다 (아니키 요청, f707129).
      // 버튼이 없으니 빈 메모를 공유할 경로 자체가 차단된다.
      expect(find.byTooltip('공유'), findsNothing);
      expect(calls, isEmpty);
    },
  );
}
