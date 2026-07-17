import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/onboarding_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';

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
    SettingsService.instance.languageCode.value = 'ko';
    SettingsService.instance.onboardingCompleted.value = false;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  testWidgets('최초 실행 온보딩은 핵심 기능 walkthrough 후 시작 완료를 저장한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('메모요 시작하기'), findsOneWidget);
    expect(find.textContaining('빠르게 메모'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.textContaining('검색'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('백업과 도움말'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
    expect(SettingsService.instance.onboardingCompleted.value, isTrue);
  });

  testWidgets('iPad 시스템 라이트에서 온보딩 설명문이 밝은 배경에 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1640, 2360);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    const background = Color(0xFFF8F8FA);
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.system,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C5CFF),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: background,
          useMaterial3: true,
        ),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const OnboardingScreen(),
      ),
    );

    final bodyFinder = find.textContaining('새메모 탭에서 바로 쓰고 저장하세요');
    final body = tester.widget<Text>(bodyFinder);
    final inheritedStyle = DefaultTextStyle.of(
      tester.element(bodyFinder),
    ).style;
    final foreground = inheritedStyle.merge(body.style).color!;
    final lighter =
        foreground.computeLuminance() > background.computeLuminance()
        ? foreground.computeLuminance()
        : background.computeLuminance();
    final darker = foreground.computeLuminance() > background.computeLuminance()
        ? background.computeLuminance()
        : foreground.computeLuminance();
    final ratio = (lighter + 0.05) / (darker + 0.05);

    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '온보딩 설명문 대비율 ${ratio.toStringAsFixed(2)}:1',
    );
  });
}
