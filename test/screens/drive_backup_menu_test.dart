import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/home_shell.dart';

// 바텀바 도입 후: 메모 리스트의 overflow(...) 메뉴는 제거됐고, '설정'은
// 하단 바텀바 탭으로 이동. Drive 백업/가져오기/되돌리기는 여전히 빠른 메뉴가
// 아니라 설정 → "백업 & 복원" 화면 안에 있다.
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
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'simple_memo_app',
      packageName: 'com.daejongkang.simple_memo_app',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  testWidgets(
    '메모 리스트에 overflow 없음 · 설정은 바텀바 탭 · Drive 빠른메뉴 없음',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeShell()));
      await tester.pumpAndSettle();

      // 메모 리스트의 overflow(...) 메뉴는 제거됨.
      expect(find.byIcon(Icons.more_vert), findsNothing);

      // '설정'은 하단 바텀바 탭으로 진입.
      final settingsTab = find.byIcon(Icons.settings_outlined);
      expect(settingsTab, findsOneWidget);
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();

      // 설정 화면 안에 "백업 & 복원"(Drive 통합 진입점) 존재.
      expect(find.text('백업 & 복원'), findsOneWidget);

      // Drive 빠른 메뉴 항목은 어디에도 없다 (설정 → 백업&복원 화면 안에만).
      expect(find.text('Drive 에 백업'), findsNothing);
      expect(find.text('메모 가져오기'), findsNothing);
      expect(find.text('가져오기 되돌리기'), findsNothing);
    },
  );
}
