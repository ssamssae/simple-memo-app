import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gsiChannel = MethodChannel('plugins.flutter.io/google_sign_in');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(gsiChannel, null);
  });

  testWidgets(
    '메모 1개 + ⋮ → "Drive 에 백업" 탭 + signIn null → "Drive 권한이 필요해요" SnackBar',
    (tester) async {
      // PR #28 의 drive_import_picker_test.dart 가 import 측 permission denied
      // 를 커버 — 본 테스트는 upload 측 permission denied 미러. 빈 메모 가드는
      // PR #25 가 별도로 커버.
      final now = DateTime(2026, 5, 29, 1, 55);
      final memo = Memo(
        id: 'perm-1',
        content: '권한 거부 테스트\n본문',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([memo]),
      });

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(gsiChannel, (call) async {
            calls.add(call);
            return null;
          });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('권한 거부 테스트'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final backupItem = find.text('Drive 에 백업');
      expect(backupItem, findsOneWidget);

      await tester.tap(backupItem);
      await tester.pumpAndSettle();

      expect(
        calls.any((c) => c.method == 'signIn' || c.method == 'signInSilently'),
        isTrue,
        reason: 'Drive 백업 진입 시 google_sign_in 채널 호출 기대',
      );
      expect(find.text('Drive 권한이 필요해요'), findsOneWidget);
    },
  );

  testWidgets('Drive 백업 탭 직후 진행 안내를 먼저 보여준다', (tester) async {
    final now = DateTime(2026, 6, 2, 20, 30);
    final memo = Memo(
      id: 'progress-1',
      content: '진행 안내 테스트',
      createdAt: now,
      updatedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo]),
    });

    final gate = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(gsiChannel, (_) => gate.future);

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drive 에 백업'));
    await tester.pump();

    expect(find.text('Drive 백업을 시작합니다'), findsOneWidget);

    gate.complete(null);
    await tester.pumpAndSettle();
  });
}
