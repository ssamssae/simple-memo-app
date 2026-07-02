import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/services/settings_service.dart';

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
}
