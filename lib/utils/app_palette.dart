import 'package:flutter/material.dart';

/// 라이트/다크 두 벌의 의미색을 한 곳에 모은다.
///
/// 화면 코드가 `Color(0xFF1A1A1E)` 같은 다크 전용 리터럴을 직접 들고 있으면
/// 라이트 모드로 바꿔도 그 위젯만 다크로 남는다 (T-260806-011: 메모 목록 타일이
/// 흰 배경 위에 검은 카드로 남아 있던 증상). 색은 전부 이 팔레트를 거쳐 읽는다.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.navigationBar,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  /// Scaffold 바탕.
  final Color background;

  /// 카드·목록 타일 바탕.
  final Color surface;

  /// 바텀시트·다이얼로그처럼 바탕보다 한 단 떠 있는 면.
  final Color elevatedSurface;

  /// 하단 탭바 바탕.
  final Color navigationBar;

  /// 본문 글자.
  final Color textPrimary;

  /// 보조 글자·비활성 아이콘.
  final Color textSecondary;

  /// 브랜드 퍼플 액센트.
  final Color accent;

  /// 액센트 면 위에 얹는 글자·아이콘.
  final Color onAccent;

  /// 삭제 등 파괴적 동작.
  final Color danger;

  static const AppPalette light = AppPalette(
    background: Color(0xFFF8F8FA),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFFFFFFF),
    navigationBar: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F1F25),
    textSecondary: Color(0xFF6E6E76),
    accent: Color(0xFF7C5CFF),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFE5534B),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0F0F12),
    surface: Color(0xFF1A1A1E),
    elevatedSurface: Color(0xFF2C2C2E),
    navigationBar: Color(0xFF141417),
    textPrimary: Color(0xFFECECEC),
    textSecondary: Color(0xFF9A9AA2),
    accent: Color(0xFF7C5CFF),
    onAccent: Color(0xFFECECEC),
    danger: Color(0xFFE5534B),
  );

  /// 테마에 등록된 팔레트를 읽는다. 등록 전 화면이 있어도 밝기로 폴백해서
  /// 다크 리터럴이 새지 않게 한다.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? navigationBar,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? danger,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      navigationBar: navigationBar ?? this.navigationBar,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      navigationBar: Color.lerp(navigationBar, other.navigationBar, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
