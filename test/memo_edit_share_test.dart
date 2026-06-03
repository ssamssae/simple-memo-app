import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  testWidgets('공유 IconButton taps share intent with memo text', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          calls.add(call);
          return 'share-target';
        });

    final memo = Memo.create(content: '제목\n본문 내용');

    await tester.pumpWidget(MaterialApp(home: MemoEditScreen(memo: memo)));

    final shareButton = find.byTooltip('공유');
    expect(shareButton, findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);

    await tester.tap(shareButton);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'share');

    final arguments = calls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments['text'], '제목\n본문 내용');
    expect(arguments['subject'], '제목');
    expect(arguments['originWidth'], greaterThan(0));
    expect(arguments['originHeight'], greaterThan(0));
  });

  testWidgets('공유 채널 실패 시 SnackBar 로 안내한다', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          throw PlatformException(
            code: 'share_failed',
            message: 'iOS share error',
          );
        });

    final memo = Memo.create(content: '공유 실패 테스트');

    await tester.pumpWidget(MaterialApp(home: MemoEditScreen(memo: memo)));

    await tester.tap(find.byTooltip('공유'));
    await tester.pump();

    expect(
      find.textContaining('PlatformException(share_failed'),
      findsOneWidget,
    );
  });
}
