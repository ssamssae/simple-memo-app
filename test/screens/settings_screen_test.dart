import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/app_review_service.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Color effectiveTextColor(WidgetTester tester, Finder finder) {
    final text = tester.widget<Text>(finder);
    final inheritedStyle = DefaultTextStyle.of(tester.element(finder)).style;
    return inheritedStyle.merge(text.style).color!;
  }

  double contrastRatio(Color foreground, Color background) {
    final lighter =
        foreground.computeLuminance() > background.computeLuminance()
        ? foreground.computeLuminance()
        : background.computeLuminance();
    final darker = foreground.computeLuminance() > background.computeLuminance()
        ? background.computeLuminance()
        : foreground.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.resetForTesting();
    SettingsService.instance.onboardingCompleted.value = true;
  });

  tearDown(() {
    SettingsService.instance.resetForTesting();
    SettingsService.instance.languageCode.value = 'ko';
    SettingsService.instance.onboardingCompleted.value = true;
  });

  testWidgets('설정 화면 글자 크기 슬라이더가 표시값과 저장값을 갱신한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('글자 크기'), findsOneWidget);
    expect(find.text('18sp'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(20);
    await tester.pump();

    expect(find.text('20sp'), findsOneWidget);

    slider.onChangeEnd?.call(20);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('memo_body_font_size'), 20);
  });

  testWidgets('기본 ondevice 플래그에서 미지원 기기는 Gemini 폴백을 표시한다', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minilm-model-tile')), findsOneWidget);
    expect(find.text('기기 내 뜻 검색 모델'), findsOneWidget);
    expect(find.text('이 기기에서는 Gemini 검색을 사용합니다'), findsOneWidget);
  });

  testWidgets('설정 화면 테마 선택이 표시값과 저장값을 갱신한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('테마'), findsOneWidget);
    expect(find.text('시스템'), findsOneWidget);
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);

    await tester.tap(find.text('라이트'));
    await tester.pumpAndSettle();

    expect(SettingsService.instance.themeMode.value, ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });

  testWidgets('iPad 820x1180 시스템 라이트에서 설정 주요 텍스트가 배경과 충분히 대비된다', (
    tester,
  ) async {
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
        home: const SettingsScreen(embedded: true),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final label in <String>[
      '글자 크기',
      '테마',
      '앱 평가하기',
      '피드백 보내기',
      '메모요 프리미엄',
      '광고 제거',
      '구매 복원',
    ]) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final ratio = contrastRatio(
        effectiveTextColor(tester, finder),
        background,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '$label 대비율 ${ratio.toStringAsFixed(2)}:1',
      );
    }
  });

  testWidgets('설정 화면의 앱 평가하기 버튼이 스토어 리뷰 listing 콜백을 호출한다', (tester) async {
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          openReviewListing: () async {
            openCount++;
            return AppReviewListingResult.opened;
          },
        ),
      ),
    );

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('앱 평가하기'), findsOneWidget);

    await tester.tap(find.text('앱 평가하기'));
    await tester.pumpAndSettle();

    expect(openCount, 1);
  });

  testWidgets('스토어 리뷰 listing 열기 실패 시 조용한 SnackBar를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          openReviewListing: () async => AppReviewListingResult.unavailable,
        ),
      ),
    );

    await tester.tap(find.text('앱 평가하기'));
    await tester.pump();

    expect(find.text('스토어를 열 수 없습니다'), findsOneWidget);
  });

  testWidgets('언어 메뉴에서 English 선택 시 설정 화면 문구가 영어로 바뀌고 저장된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.scrollUntilVisible(
      find.text('언어'),
      160,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('언어'), findsOneWidget);
    await tester.tap(find.text('언어'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Help & FAQ'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');
  });

  testWidgets('설정 화면의 도움말/FAQ 항목이 Help 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.scrollUntilVisible(
      find.text('도움말 / FAQ'),
      160,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('도움말 / FAQ'), findsOneWidget);
    await tester.tap(find.text('도움말 / FAQ'));
    await tester.pumpAndSettle();

    expect(find.text('도움말 / FAQ'), findsWidgets);
    expect(find.textContaining('메모는 어디에 저장되나요'), findsOneWidget);
  });

  testWidgets('설정 화면에 메모요 프리미엄 구독 진입점이 표시된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.scrollUntilVisible(
      find.text('메모요 프리미엄'),
      160,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('메모요 프리미엄'), findsOneWidget);
    expect(find.textContaining('월 ₩1,900'), findsOneWidget);
  });
}
