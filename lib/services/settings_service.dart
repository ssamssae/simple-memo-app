import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 표시 설정의 단일 소스. 현재는 본문 글자 크기만 관리.
/// AdsService 와 동일한 싱글턴 + ValueNotifier + SharedPreferences 패턴.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _bodyFontSizePrefKey = 'memo_body_font_size';
  static const String _legacyFontScalePrefKey = 'font_scale';

  /// 메모 본문 글자 크기 범위.
  static const double minBodyFontSize = 12;
  static const double maxBodyFontSize = 24;
  static const double defaultBodyFontSize = 18;

  /// 메모 목록·편집 본문 글자 크기. 설정 화면 슬라이더가 갱신, 본문 렌더가 구독.
  final ValueNotifier<double> bodyFontSize = ValueNotifier<double>(
    defaultBodyFontSize,
  );

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_bodyFontSizePrefKey);
    final legacyScale = prefs.getDouble(_legacyFontScalePrefKey);
    final restored = stored ?? defaultBodyFontSize * (legacyScale ?? 1.0);
    bodyFontSize.value = _clampBodyFontSize(restored);
  }

  void previewBodyFontSize(double value) {
    bodyFontSize.value = _clampBodyFontSize(value);
  }

  Future<void> setBodyFontSize(double value) async {
    final clamped = _clampBodyFontSize(value);
    bodyFontSize.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_bodyFontSizePrefKey, clamped);
  }

  double bodyFontScale() => bodyFontSize.value / defaultBodyFontSize;

  double _clampBodyFontSize(double value) =>
      value.clamp(minBodyFontSize, maxBodyFontSize).toDouble();
}
