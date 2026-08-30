import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/app_review_service.dart';
import 'package:simple_memo_app/services/premium_entitlement.dart';
import 'package:simple_memo_app/services/premium_service.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
    SettingsService.instance.resetForTesting();
    SettingsService.instance.onboardingCompleted.value = true;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
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

  // ★계약이 두 번 뒤집힌 자리다. 이력을 남겨 둔다 — 다음 사람이 방향을 헷갈리지 않게.
  //   ① 원래: 「미지원 기기는 Gemini 폴백을 표시한다」 = 타일 ★보인다.
  //      말로찾기가 잠겨 검색 UI 가 없는데 설정만 124MB 다운로드를 권하던 버그를
  //      계약으로 굳혀둔 자리였다.
  //   ② T-260805-145: 잠금과 맞춰 타일 ★없다 로 반전.
  //   ③ T-260806-022(지금): 유료 폴백을 걷어내 말로찾기를 열었다. 기능을 쓸 수 있으니
  //      모델 설치를 권하는 게 맞다 ⇒ 다시 ★보인다.
  //   ①과 ③은 단언이 같지만 이유가 다르다. ①은 「잠긴 걸 판다」(버그),
  //   ③은 「열린 걸 판다」(정상). 되돌릴 때 이유부터 보라.
  //   폴백 소제목 자체를 재는 축은 타일 단위 테스트에 있다
  //   (test/widgets/mini_lm_model_settings_tile_test.dart).
  testWidgets('말로찾기가 열린 기본 플래그에서는 설정에 모델 타일이 있다', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // ★대조군 — 화면이 실제로 떴는지 먼저 증명한다.
    expect(find.text('글자 크기'), findsOneWidget,
        reason: '설정 화면이 안 떴다 — 아래 판정이 무의미해진다');

    expect(find.byKey(const Key('minilm-model-tile')), findsOneWidget,
        reason: '말로찾기를 열었는데 온디바이스 모델을 받을 문이 설정에 없다');
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
      // '메모요 프리미엄' 은 뺐다 — T-260804-090 으로 구독 판매를 접어서 ★비구독자에게는
      // 이 칸이 아예 렌더되지 않는다(이 테스트는 비구독 상태로 돈다). 구독중인 사람에게
      // 뜨는 상태 칸은 아래 별도 테스트가 지킨다.
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

  // ★두 번 뒤집힌 테스트 — ①「구독 진입점이 표시된다」 → ②T-260804-090「상태 칸만 남는다」
  //   → ③T-260805-076「칸 자체가 없다」. 매번 지우는 대신 사실을 갱신해 회귀축을 유지한다.
  //
  //   ★이 본이 실제로 지키는 것은 오표시 방지다. entitlement.active 는 구독뿐 아니라
  //   ★광고제거(remove_ads) 쿠폰으로도 켜진다(PremiumEntitlementSource.removeAdsCoupon).
  //   그래서 「active 면 프리미엄 칸을 그린다」를 남겨 두면, ₩3,300 광고제거를 산 사람이
  //   자기가 사지도 않은 「메모요 프리미엄」 구독자로 표시된다. 아래 단언이 그 길을 막는다.
  testWidgets('엔티틀먼트가 살아 있어도 프리미엄 칸·가격이 뜨지 않는다', (tester) async {
    PremiumService.instance.entitlement.value = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlement.premiumProductId,
      expiresAt: DateTime(2999),
      source: PremiumEntitlementSource.subscription,
    );
    addTearDown(() {
      PremiumService.instance.entitlement.value =
          const PremiumEntitlement.inactive();
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    // 칸이 없다는 단언이므로 스크롤로 화면 전체를 훑은 뒤 판정한다 —
    // ★안 훑고 findsNothing 을 부르면 "아직 안 보이는 것"을 "없는 것"으로 오판한다.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();

    // ★양성 대조군 — 리스트 맨 아래(VersionFooter)가 잡히는지 먼저 본다. 이게 안 잡히면
    //   아래 findsNothing 두 줄은 「없다」가 아니라 「아직 안 그렸다」를 재고 있는 것이고,
    //   그때 이 테스트는 초록인 채로 아무것도 안 지킨다.
    expect(find.textContaining('마이너스베타스튜디오'), findsWidgets,
        reason: '스크롤이 리스트 끝에 도달하지 못했다 — 아래 부재 단언을 믿을 수 없다');

    expect(find.text('메모요 프리미엄'), findsNothing,
        reason: '구독 폐지(T-260805-076) 후에도 프리미엄 칸이 남아 있다 — '
            '광고제거 구매자가 구독자로 오표시된다');
    expect(find.textContaining('월 ₩1,900'), findsNothing,
        reason: '구독 판매 가격이 되살아났다 (T-260805-076 으로 상품 폐지)');
  });
}
