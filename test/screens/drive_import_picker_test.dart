import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gsiChannel = MethodChannel('plugins.flutter.io/google_sign_in');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(gsiChannel, null);
  });

  testWidgets(
    'overflow → "메모 가져오기" 탭 시 GoogleSignIn 호출 + 거절(null) → 권한 SnackBar',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(gsiChannel, (call) async {
        calls.add(call);
        // init/signInSilently/signIn 등 모두 null 반환 → DriveBackupService
        // 입장에서 사용자 취소(GoogleSignInAccount? = null) → PermissionDenied
        return null;
      });

      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final importItem = find.text('메모 가져오기');
      expect(importItem, findsOneWidget);

      await tester.tap(importItem);
      await tester.pumpAndSettle();

      // signIn 또는 signInSilently 가 최소 1회 이상 호출됐어야 함
      expect(
        calls.any((c) => c.method == 'signIn' || c.method == 'signInSilently'),
        isTrue,
        reason: 'Drive import 진입 시 google_sign_in channel 호출 기대',
      );
      expect(find.text('Drive 권한이 필요해요'), findsOneWidget);
    },
  );
}
