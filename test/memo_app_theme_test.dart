import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/screens/splash_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.resetForTesting();
  });

  testWidgets('MemoApp 이 설정 서비스의 themeMode 를 MaterialApp 에 연결한다', (
    tester,
  ) async {
    SettingsService.instance.themeMode.value = ThemeMode.light;

    await tester.pumpWidget(const MemoApp());

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme?.colorScheme.brightness, Brightness.light);
    expect(app.darkTheme?.colorScheme.brightness, Brightness.dark);

    await SettingsService.instance.setThemeMode(ThemeMode.dark);
    await tester.pump();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('저장된 테마가 없으면 기기 다크에서도 크림 라이트가 기본이다', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();

    expect(SettingsService.instance.themeMode.value, ThemeMode.light);

    await tester.pumpWidget(const MemoApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme?.brightness, Brightness.light);

    final theme = Theme.of(tester.element(find.byType(SplashScreen)));
    final palette = theme.extension<AppPalette>();
    expect(theme.brightness, Brightness.light);
    expect(palette, isNotNull);
    expect(AppPalette.light.background, const Color(0xFFFFF8E7));
    expect(palette!.background, AppPalette.light.background);
    expect(palette.background, isNot(AppPalette.dark.background));
    expect(palette.surface, AppPalette.light.surface);
    expect(palette.textPrimary, AppPalette.light.textPrimary);
    expect(palette.accent, const Color(0xFF7C5CFF));
    expect(theme.scaffoldBackgroundColor, AppPalette.light.background);
    expect(theme.cardTheme.color, AppPalette.light.surface);

    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(
      contrast(palette.textPrimary, palette.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.textPrimary, palette.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.textSecondary, palette.surface),
      greaterThanOrEqualTo(4.5),
    );
  });
}
