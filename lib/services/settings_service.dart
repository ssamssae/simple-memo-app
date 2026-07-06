import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 표시 설정의 단일 소스. 현재는 본문 글자 크기만 관리.
/// AdsService 와 동일한 싱글턴 + ValueNotifier + SharedPreferences 패턴.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _bodyFontSizePrefKey = 'memo_body_font_size';
  static const String _legacyFontScalePrefKey = 'font_scale';
  static const String _languagePrefKey = 'app_language';
  static const String _onboardingCompletedPrefKey = 'onboarding_completed';
  static const String _reviewPromptShownPrefKey = 'review_prompt_shown';
  static const String _memoSaveCountForReviewPrefKey =
      'memo_save_count_for_review';
  static const int reviewPromptMemoSaveThreshold = 3;

  /// 메모 본문 글자 크기 범위.
  static const double minBodyFontSize = 12;
  static const double maxBodyFontSize = 24;
  static const double defaultBodyFontSize = 18;

  /// 메모 목록·편집 본문 글자 크기. 설정 화면 슬라이더가 갱신, 본문 렌더가 구독.
  final ValueNotifier<double> bodyFontSize = ValueNotifier<double>(
    defaultBodyFontSize,
  );
  final ValueNotifier<String> languageCode = ValueNotifier<String>('ko');
  final ValueNotifier<bool> onboardingCompleted = ValueNotifier<bool>(false);

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> init() async {
    if (_initialized) return;
    final pending = _initFuture;
    if (pending != null) return pending;
    _initFuture = _load();
    return _initFuture!;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_bodyFontSizePrefKey);
    final legacyScale = prefs.getDouble(_legacyFontScalePrefKey);
    final restored = stored ?? defaultBodyFontSize * (legacyScale ?? 1.0);
    bodyFontSize.value = _clampBodyFontSize(restored);
    languageCode.value = _normalizeLanguageCode(
      prefs.getString(_languagePrefKey),
    );
    onboardingCompleted.value =
        prefs.getBool(_onboardingCompletedPrefKey) ?? false;
    _initialized = true;
    _initFuture = null;
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

  Future<void> setLanguageCode(String value) async {
    final normalized = _normalizeLanguageCode(value);
    languageCode.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, normalized);
  }

  Future<void> setOnboardingCompleted(bool value) async {
    onboardingCompleted.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedPrefKey, value);
  }

  Future<bool> recordMemoSavedForReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_memoSaveCountForReviewPrefKey) ?? 0) + 1;
    await prefs.setInt(_memoSaveCountForReviewPrefKey, count);
    final alreadyShown = prefs.getBool(_reviewPromptShownPrefKey) ?? false;
    if (alreadyShown || count < reviewPromptMemoSaveThreshold) {
      return false;
    }
    await prefs.setBool(_reviewPromptShownPrefKey, true);
    return true;
  }

  double bodyFontScale() => bodyFontSize.value / defaultBodyFontSize;

  double _clampBodyFontSize(double value) =>
      value.clamp(minBodyFontSize, maxBodyFontSize).toDouble();

  String _normalizeLanguageCode(String? value) => value == 'en' ? 'en' : 'ko';
}
