import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/ads_service.dart';
import 'services/remove_ads_purchase.dart';

void main() {
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

  runZonedGuarded(() {
    // 수익화 초기화 (배너 광고 / 광고제거 IAP) — 스플래시를 막지 않도록 비동기.
    AdsService.instance.init();
    RemoveAdsPurchase.instance.init();
    runApp(const MemoApp());
  }, (Object error, StackTrace stack) {
    // Zone 에러 핸들링 (runZonedGuarded 내 미처리 비동기 에러)
    debugPrint('[ZoneError] $error');
    debugPrint('[ZoneError] $stack');
  });
}

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메모요',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Obsidian 톤: 다크 무채색 미니멀 + 퍼플 액센트 (#7C5CFF).
        // 대부분의 chrome 은 무채색 회색/흰색, 퍼플은 강조에만 절제 사용.
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
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1A1E),
        ),
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
      ),
      home: const SplashScreen(),
    );
  }
}
