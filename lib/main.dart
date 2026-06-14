import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE24A3B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF8F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFBF8F2),
          foregroundColor: Color(0xFF2A2622),
          iconTheme: IconThemeData(color: Color(0xFFE24A3B)),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFE24A3B),
          foregroundColor: Colors.white,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: const Color(0xFFE24A3B),
          selectionColor: const Color(0xFFE24A3B).withValues(alpha: 0.25),
          selectionHandleColor: const Color(0xFFE24A3B),
        ),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const SplashScreen(),
    );
  }
}
