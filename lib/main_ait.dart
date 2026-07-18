// T-260718-058 앱인토스 정식 래퍼 엔트리포인트.
//
// 스파이크(main_ait_spike.dart)의 실증 계약(AitBridge·AitMemoStore·closeView) 위에
// 실제 메모요 UX(목록·편집·검색·휴지통)를 올린 미니앱판. 본편 main.dart 와 완전
// 분리 — 광고·IAP·Drive·시맨틱검색·프리미엄은 import 그래프에서 배제된다
// (웹 미지원 플러그인 컴파일 배제 + 스토어 문구 정합, T-260718-057).
//
// 라이트 모드 고정: 앱인토스 디자인 검수 의무(라이트 대응) — 미니앱판은 라이트
// 단일 테마로 대응한다 (T-260718-052 §2.2).
//
// 빌드: flutter build web --target=lib/main_ait.dart
import 'package:flutter/material.dart';

import 'ait/screens/ait_memo_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AitMemoyoApp());
}

class AitMemoyoApp extends StatelessWidget {
  const AitMemoyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메모요',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4A90D9),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light,
      home: const AitMemoListScreen(),
    );
  }
}
