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
            return MaterialApp(
              title: strings.appName,
              locale: Locale(languageCode),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('ko'), Locale('en')],
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      extensions: const [AppPalette.light],
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F8FA),
        foregroundColor: Color(0xFF1F1F25),
        iconTheme: IconThemeData(color: Color(0xFF6E6E76)),
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

  ThemeData _buildDarkTheme() {
    return ThemeData(
      // Obsidian 톤: 다크 무채색 미니멀 + 퍼플 액센트 (#7C5CFF).
      // 대부분의 chrome 은 무채색 회색/흰색, 퍼플은 강조에만 절제 사용.
      extensions: const [AppPalette.dark],
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F12),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F12),
        foregroundColor: Color(0xFFECECEC),
        iconTheme: IconThemeData(color: Color(0xFF9A9AA2)),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF1A1A1E)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF7C5CFF),
        foregroundColor: Color(0xFFECECEC),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF7C5CFF),
        selectionColor: Color(0x597C5CFF),
        selectionHandleColor: Color(0xFF7C5CFF),
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }
}
