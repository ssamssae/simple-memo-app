import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/app_review_service.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.bodyFontSize.value =
        SettingsService.defaultBodyFontSize;
    SettingsService.instance.languageCode.value = 'ko';
    SettingsService.instance.onboardingCompleted.value = true;
  });

  tearDown(() {
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
}
