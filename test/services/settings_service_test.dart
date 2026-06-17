import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.bodyFontSize.value =
        SettingsService.defaultBodyFontSize;
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
}
