import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/paywall_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'language_code': 'ko'});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  testWidgets('구독 화면에 이용약관과 개인정보처리방침 링크를 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaywallScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '이용약관'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '개인정보처리방침'), findsOneWidget);
  });

  testWidgets('스토어 심사용 미리보기는 월 구독 가격과 활성 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PaywallScreen(storePreviewPrice: '₩1,900')),
    );
    await tester.pumpAndSettle();

    expect(find.text('월 구독 시작 · 월 ₩1,900'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });
}
