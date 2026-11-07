import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/memos/services/attachment_store.dart';
import 'l10n/app_strings.dart';
import 'screens/splash_screen.dart';
import 'services/ads_service.dart';
import 'services/crash_log.dart';
import 'services/premium_service.dart';
import 'services/remove_ads_purchase.dart';
import 'services/settings_service.dart';
import 'utils/app_palette.dart';
import 'features/memos/semantic_search_availability.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Flutter 프레임워크 에러 핸들링 (위젯 빌드/레이아웃 에러 등)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}');
    debugPrint('[FlutterError] ${details.stack}');
  };

  // 플랫폼 디스패처 에러 핸들링 (네이티브 측 비동기 에러)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PlatformError] $error');
    debugPrint('[PlatformError] $stack');
    return true;
  };

  // T-260730-057: 위 훅들 ★뒤에 체인해 로컬 영속 기록을 붙인다.
  // 종전에는 debugPrint 로만 흘려서 기기를 회수하지 않으면 아무도 읽을 수 없었다.
  // 외부 전송 0 — 기록은 기기 안에만 남는다.
  CrashLog.install();
  // 이전 실행에서 남은 기록을 콘솔로 흘린다. 시작을 막지 않도록 await 하지 않는다.
  unawaited(CrashLog.dumpPrevious());

  runZonedGuarded(
    () async {
      // 수익화 초기화 (배너 광고 / 광고제거 IAP) — 스플래시를 막지 않도록 비동기.
      // ★파는 상품은 광고제거(remove_ads) 단품 하나뿐이다 — 구독(premium_monthly)
      //   초기화는 T-260805-076 으로 제거했다. PremiumService 는 남는데, 그건
      //   광고제거 구매자의 서버 엔티틀먼트를 읽는 쪽이라서다(파는 쪽 아님).
      AdsService.instance.init();
      PremiumService.instance.init();
      RemoveAdsPurchase.instance.init();
      await SettingsService.instance.init();
      // 첨부 사진 디렉토리 (T-260829-022). 실패해도 던지지 않는다 — 사진 기능만 비활성.
      await AttachmentStore.init();
      runApp(const MemoApp());
      // 뜻으로 찾기 오프보딩(T-261103-001): 받아 둔 모델 124MB 를 돌려준다. 시작을 막지 않는다.
      unawaited(offboardSemanticSearchModel());
    },
    (Object error, StackTrace stack) {
      // Zone 에러 핸들링 (runZonedGuarded 내 미처리 비동기 에러)
      debugPrint('[ZoneError] $error');
      debugPrint('[ZoneError] $stack');
      // T-260730-057: 세 번째 훅. zone 은 감싸야 해서 install() 이 못 걸고
      // 여기서 직접 기록한다.
      unawaited(CrashLog.record('zone', error, stack));
    },
  );
}

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.instance.languageCode,
      builder: (context, languageCode, _) {
        final strings = AppStrings.fromCode(languageCode);
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: SettingsService.instance.themeMode,
          builder: (context, themeMode, _) {
            // 시스템 + 기기 라이트만 보라 톤. 다크는 명시·시스템 공통 검정·회색(T-261102-001).
            final bool useSystemPurple = themeMode == ThemeMode.system;
            return MaterialApp(
              title: strings.appName,
              locale: Locale(languageCode),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('ko'), Locale('en')],
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: useSystemPurple
                  ? _buildPurpleLightTheme()
                  : _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    const p = AppPalette.light;
    return ThemeData(
      fontFamily: 'Pretendard',
      extensions: const [p],
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        iconTheme: IconThemeData(color: p.textSecondary),
      ),
      cardTheme: CardThemeData(color: p.surface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withAlpha(0x33),
        selectionHandleColor: p.accent,
      ),
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  /// 다크 — 명시 「다크」와 「시스템」+기기 다크 공통. 순검정 바탕 + 밝은 회색 카드,
  /// 본문 흰 글자 SemiBold (대종님 2026-11-02 후보 2번, T-261102-001).
  ThemeData _buildDarkTheme() {
    const p = AppPalette.dark;
    const divider = Color(0xFF48484A);
    final base = ThemeData(
      fontFamily: 'Pretendard',
      extensions: const [p],
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.dark,
      ).copyWith(outline: divider, outlineVariant: divider),
      dividerColor: divider,
      dividerTheme: const DividerThemeData(color: divider),
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        iconTheme: IconThemeData(color: p.textSecondary),
      ),
      cardTheme: CardThemeData(color: p.surface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withAlpha(0x59),
        selectionHandleColor: p.accent,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    // 메모 본문 TextField 기본 글자 = M3 bodyLarge. 다크에서만 한 단계 굵게
    // (대종님 「흰색이 좀 얇은느낌」).
    final tt = base.textTheme;
    return base.copyWith(
      textTheme: tt.copyWith(
        bodyLarge: tt.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 시스템 + 기기 라이트. 구분선·테두리는 연보라.
  ThemeData _buildPurpleLightTheme() {
    const divider = Color(0xFFE6DFFF);
    return ThemeData(
      fontFamily: 'Pretendard',
      extensions: const [AppPalette.purpleLight],
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFF),
        brightness: Brightness.light,
      ).copyWith(outline: divider, outlineVariant: divider),
      dividerColor: divider,
      dividerTheme: const DividerThemeData(color: divider),
      scaffoldBackgroundColor: const Color(0xFFF5F2FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F2FF),
        foregroundColor: Color(0xFF191F28),
        iconTheme: IconThemeData(color: Color(0xFF5B5670)),
      ),
      cardTheme: const CardThemeData(color: Color(0xFFFFFFFF)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF7C5CFF),
        foregroundColor: Color(0xFFFFFFFF),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF7C5CFF),
        selectionColor: Color(0x337C5CFF),
        selectionHandleColor: Color(0xFF7C5CFF),
      ),
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }
}
