import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/services/settings_service.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

/// 다크 = 순검정 바탕 + 밝은 회색 카드 + 진한 크림 SemiBold 본문.
/// 바탕·카드는 T-261102-001 후보 2번. 글자만 T-261109-019 「진한크림」 C.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.resetForTesting();
  });

  test('다크 팔레트는 고른 후보 2번 값이다', () {
    const p = AppPalette.dark;
    expect(p.background, const Color(0xFF000000));
    expect(p.surface, const Color(0xFF2C2C2E));
    expect(p.elevatedSurface, const Color(0xFF3A3A3C));
    expect(p.navigationBar, const Color(0xFF1C1C1E));
    expect(p.textPrimary, const Color(0xFFFDE3A0));
    expect(p.textSecondary, const Color(0xFFCDB884));
  });

  test('다크 본문·보조 글자 대 카드 대비가 4.5:1 이상이다', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    const p = AppPalette.dark;
    expect(contrast(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(p.textSecondary, p.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(p.textPrimary, p.background), greaterThanOrEqualTo(4.5));
  });

  for (final mode in [ThemeMode.dark, ThemeMode.system]) {
    testWidgets('$mode 다크 테마 본문(bodyLarge)은 SemiBold, 라이트는 그대로', (
      tester,
    ) async {
      SettingsService.instance.themeMode.value = mode;
      await tester.pumpWidget(const MemoApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.darkTheme?.textTheme.bodyLarge?.fontWeight, FontWeight.w600);
      expect(
        app.darkTheme?.extension<AppPalette>()?.background,
        const Color(0xFF000000),
      );
      expect(
        app.theme?.textTheme.bodyLarge?.fontWeight,
        isNot(FontWeight.w600),
      );
    });
  }
}
