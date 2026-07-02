import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.resetForTesting();
  });

  test('setBodyFontSize 가 상한/하한을 클램프한다', () async {
    await SettingsService.instance.setBodyFontSize(99); // 위로 초과
    expect(
      SettingsService.instance.bodyFontSize.value,
      SettingsService.maxBodyFontSize,
    );

    await SettingsService.instance.setBodyFontSize(0.0); // 아래로 초과
    expect(
      SettingsService.instance.bodyFontSize.value,
      SettingsService.minBodyFontSize,
    );
  });

  test('setBodyFontSize 가 범위 내 값을 그대로 적용하고 SharedPreferences 에 저장한다', () async {
    await SettingsService.instance.setBodyFontSize(20);
    expect(SettingsService.instance.bodyFontSize.value, 20);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('memo_body_font_size'), 20);
  });

  test('저장된 클램프 값이 SharedPreferences 에 반영된다', () async {
    await SettingsService.instance.setBodyFontSize(99);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble('memo_body_font_size'),
      SettingsService.maxBodyFontSize,
    );
  });

  test('언어 코드는 ko/en 만 허용하고 SharedPreferences 에 저장한다', () async {
    await SettingsService.instance.setLanguageCode('en');
    expect(SettingsService.instance.languageCode.value, 'en');

    await SettingsService.instance.setLanguageCode('fr');
    expect(SettingsService.instance.languageCode.value, 'ko');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'ko');
  });

  test('온보딩 완료 상태를 저장한다', () async {
    await SettingsService.instance.setOnboardingCompleted(true);

    expect(SettingsService.instance.onboardingCompleted.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  test('리뷰 프롬프트는 세 번째 저장 후 1회만 요청된다', () async {
    expect(
      await SettingsService.instance.recordMemoSavedForReviewPrompt(),
      isFalse,
    );
    expect(
      await SettingsService.instance.recordMemoSavedForReviewPrompt(),
      isFalse,
    );
    expect(
      await SettingsService.instance.recordMemoSavedForReviewPrompt(),
      isTrue,
    );
    expect(
      await SettingsService.instance.recordMemoSavedForReviewPrompt(),
      isFalse,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('review_prompt_shown'), isTrue);
    expect(prefs.getInt('memo_save_count_for_review'), 4);
  });

  test('setThemeMode 가 선택값을 SharedPreferences 에 저장한다', () async {
    await SettingsService.instance.setThemeMode(ThemeMode.dark);

    expect(SettingsService.instance.themeMode.value, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('init 이 저장된 테마 선택값을 복원한다', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    SettingsService.instance.resetForTesting();

    await SettingsService.instance.init();

    expect(SettingsService.instance.themeMode.value, ThemeMode.light);
  });

  test('init 이 알 수 없는 테마 선택값은 시스템으로 복원한다', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'unknown'});
    SettingsService.instance.resetForTesting();

    await SettingsService.instance.init();

    expect(SettingsService.instance.themeMode.value, ThemeMode.system);
  });
}
