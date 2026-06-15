import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 표시 설정의 단일 소스. 현재는 본문 글자 크기 배율만 관리.
/// AdsService 와 동일한 싱글턴 + ValueNotifier + SharedPreferences 패턴.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _fontScalePrefKey = 'font_scale';

  /// 본문 글자 크기 배율 범위 (1.0 = 기본).
  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.6;

  /// 메모 목록·편집 본문 글자 크기 배율. 설정 화면 슬라이더가 갱신, 본문 렌더가 구독.
  final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_fontScalePrefKey) ?? 1.0;
    fontScale.value = stored.clamp(minFontScale, maxFontScale);
  }

  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(minFontScale, maxFontScale);
    fontScale.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScalePrefKey, clamped);
  }
}
