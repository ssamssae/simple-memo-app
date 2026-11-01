import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/screens/splash_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

/// 설정 3 × 기기 밝기 2. 시스템만 보라 팔레트, 명시 라이트·다크는 기존 팔레트.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.resetForTesting();
  });

  const cases = <_ThemeCase>[
    _ThemeCase(
      '시스템 + 기기 라이트 → 보라 라이트',
      ThemeMode.system,
      Brightness.light,
      AppPalette.purpleLight,
      Color(0xFFE6DFFF),
    ),
    _ThemeCase(
      '시스템 + 기기 다크 → 보라 다크',
      ThemeMode.system,
      Brightness.dark,
      AppPalette.purpleDark,
      Color(0xFF4A4168),
    ),
    _ThemeCase(
      '라이트 + 기기 라이트 → 기존 라이트',
      ThemeMode.light,
      Brightness.light,
      AppPalette.light,
      null,
    ),
    _ThemeCase(
      '라이트 + 기기 다크 → 기존 라이트',
      ThemeMode.light,
      Brightness.dark,
      AppPalette.light,
      null,
    ),
    _ThemeCase(
      '다크 + 기기 라이트 → 기존 다크',
      ThemeMode.dark,
      Brightness.light,
      AppPalette.dark,
      null,
    ),
    _ThemeCase(
      '다크 + 기기 다크 → 기존 다크',
      ThemeMode.dark,
      Brightness.dark,
      AppPalette.dark,
      null,
    ),
  ];

  for (final item in cases) {
    testWidgets(item.name, (tester) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          item.device;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      SettingsService.instance.themeMode.value = item.mode;

      await tester.pumpWidget(const MemoApp());

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, item.mode);
      if (item.mode == ThemeMode.system) {
        _expectPalette(
          app.theme?.extension<AppPalette>(),
          AppPalette.purpleLight,
        );
        _expectPalette(
          app.darkTheme?.extension<AppPalette>(),
          AppPalette.purpleDark,
        );
      } else {
        _expectPalette(app.theme?.extension<AppPalette>(), AppPalette.light);
        _expectPalette(app.darkTheme?.extension<AppPalette>(), AppPalette.dark);
      }

      final context = tester.element(find.byType(SplashScreen));
      final theme = Theme.of(context);
      _expectPalette(theme.extension<AppPalette>(), item.palette);
      expect(theme.scaffoldBackgroundColor, item.palette.background);
      expect(theme.cardTheme.color, item.palette.surface);
      expect(theme.appBarTheme.backgroundColor, item.palette.background);
      expect(theme.appBarTheme.foregroundColor, item.palette.textPrimary);
      expect(theme.appBarTheme.iconTheme?.color, item.palette.textSecondary);
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        item.palette.accent,
      );
      expect(
        theme.floatingActionButtonTheme.foregroundColor,
        item.palette.onAccent,
      );
      if (item.divider != null) {
        expect(theme.dividerColor, item.divider);
        expect(theme.dividerTheme.color, item.divider);
        expect(theme.colorScheme.outline, item.divider);
        expect(theme.colorScheme.outlineVariant, item.divider);
      }
    });
  }
}

void _expectPalette(AppPalette? actual, AppPalette expected) {
  expect(actual, isNotNull);
  final got = actual!;
  expect(got.background, expected.background);
  expect(got.surface, expected.surface);
  expect(got.elevatedSurface, expected.elevatedSurface);
  expect(got.navigationBar, expected.navigationBar);
  expect(got.textPrimary, expected.textPrimary);
  expect(got.textSecondary, expected.textSecondary);
  expect(got.accent, expected.accent);
  expect(got.onAccent, expected.onAccent);
  expect(got.danger, expected.danger);
}

class _ThemeCase {
  const _ThemeCase(
    this.name,
    this.mode,
    this.device,
    this.palette,
    this.divider,
  );

  final String name;
  final ThemeMode mode;
  final Brightness device;
  final AppPalette palette;
  final Color? divider;
}
