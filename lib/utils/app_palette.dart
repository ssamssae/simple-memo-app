import 'package:flutter/material.dart';

/// 라이트/다크와, 시스템 테마 전용 보라 라이트/보라 다크를 한 곳에 모은다.
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

  /// 명시 「라이트」. 저장값이 없으면 이 톤이 기본이다.
  /// 시작 화면과 같은 크림 바탕, 카드는 연노랑, 글자는 진한색, 액센트는 보라.
  static const AppPalette light = AppPalette(
    background: Color(0xFFFFF8E7),
    surface: Color(0xFFFFEFC2),
    elevatedSurface: Color(0xFFFFFFFF),
    navigationBar: Color(0xFFFFF8E7),
    textPrimary: Color(0xFF191F28),
    textSecondary: Color(0xFF4E5968),
    accent: Color(0xFF7C5CFF),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFE5534B),
  );

  /// 다크 — 명시 「다크」와 「시스템」+기기 다크가 같이 쓴다. 순검정 바탕 + 밝은 회색 카드
  /// (대종님 2026-11-02 「보라를 빼고 검은색과 회색어때」 → 후보 2번, T-261102-001).
  /// 본문·보조 글자만 진한 크림 (대종님 2026-11-09 「진한크림」 C, T-261109-019).
  /// 포인트색은 크림과 같은 계열 호박 골드 (대종님 2026-11-13 「보라색이 좀 언발란스」
  /// → 후보 1번, T-261113-027). 골드 면 위 글자·아이콘은 진한 갈색.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF2C2C2E),
    elevatedSurface: Color(0xFF3A3A3C),
    navigationBar: Color(0xFF1C1C1E),
    textPrimary: Color(0xFFFDE3A0),
    textSecondary: Color(0xFFCDB884),
    accent: Color(0xFFF2B84B),
    onAccent: Color(0xFF1F1606),
    danger: Color(0xFFE5534B),
  );

  /// 시스템 테마이고 기기가 라이트일 때. 명시 「라이트」와 다른 보라 톤.
  static const AppPalette purpleLight = AppPalette(
    background: Color(0xFFF5F2FF),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFFFFFFF),
    navigationBar: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF191F28),
    textSecondary: Color(0xFF5B5670),
    accent: Color(0xFF7C5CFF),
    onAccent: Color(0xFFFFFFFF),
    // 삭제색은 기존 라이트와 같다.
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
