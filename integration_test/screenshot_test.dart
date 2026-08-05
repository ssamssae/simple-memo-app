// 메모요 Play Store 스크린샷 자동 캡처 하니스 (다크모드 실제 화면).
// flutter drive 로 부팅된 시뮬레이터에서 구동 → 각 화면 실제 렌더를 PNG 로 산출.
// 데모 메모는 SharedPreferences(MemoStorage) 에 시드(목업 합성 X — 실제 앱 화면).
//
// 실행:
//   flutter drive \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/screenshot_test.dart \
//     -d <ios-sim-udid>
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/ads_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/settings_service.dart';

/// 통합테스트 바인딩. main() 이 채우고 captureStoreShot 이 실제 픽셀을 뜬다.
late final IntegrationTestWidgetsFlutterBinding binding;

Future<void> pumpUi(
  WidgetTester tester, [
  Duration wait = const Duration(milliseconds: 700),
]) async {
  await tester.pump();
  await tester.pump(wait);
  await tester.pump();
}

/// 현재 화면을 실제 PNG 로 캡처한다.
///
/// 예전 구현(openExternalCaptureWindow)은 `[store-shot-ready]` 마커만 찍고
/// 기본 12초를 대기했다. 실제 촬영은 그 창 동안 repo 밖에 있는 손이 했고,
/// 그 손에 해당하는 스크립트가 repo 에 없어 재현이 불가능했다 (T-260805-017).
/// 지금은 이 함수가 직접 찍고, 저장 경로는 test_driver/store_screenshots_test.dart
/// 가 정한다. 기제는 한줄일기(store_screenshots_test.dart)에서 이미 검증된 것을
/// 그대로 옮겨온 것이다 — 재발명이 아니다.
Future<void> captureStoreShot(WidgetTester tester, String name) async {
  await pumpUi(tester, const Duration(milliseconds: 400));
  await binding.takeScreenshot(name);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots (dark)', (tester) async {
    // ── 데모 메모 시드 (실제 저장소) ──
    final base = DateTime(2026, 6, 4, 9, 30);
    final demo = <Memo>[
      Memo(
        id: '1',
        content: '장보기\n· 우유 2개\n· 계란 한 판\n· 사과\n· 커피 원두',
        isFavorite: true,
        createdAt: base,
        updatedAt: base,
      ),
      Memo(
        id: '2',
        content: '오늘 회의 정리\n다음 분기 목표 3가지 확정, 담당자 배정',
        createdAt: base.subtract(const Duration(hours: 2)),
        updatedAt: base.subtract(const Duration(hours: 2)),
      ),
      Memo(
        id: '3',
        content: '책에서 본 문장\n"작게 시작해서 매일 한 줄씩."',
        createdAt: base.subtract(const Duration(days: 1)),
        updatedAt: base.subtract(const Duration(days: 1)),
      ),
      Memo(
        id: '4',
        content: '주말 할 일\n자전거 점검, 도서관 책 반납',
        createdAt: base.subtract(const Duration(days: 1, hours: 5)),
        updatedAt: base.subtract(const Duration(days: 1, hours: 5)),
      ),
      Memo(
        id: '5',
        content: '아이디어: 산책 코스 앱',
        createdAt: base.subtract(const Duration(days: 2)),
        updatedAt: base.subtract(const Duration(days: 2)),
      ),
    ];
    await MemoStorage.saveMemos(demo);
    await SettingsService.instance.setLanguageCode('ko');
    await SettingsService.instance.setThemeMode(ThemeMode.dark);
    await SettingsService.instance.setOnboardingCompleted(true);
    // 캡처 중 네이티브 광고 로드가 프레임 정착을 막지 않게 기존 광고 제거
    // 구매자 상태를 사용한다. 설정/페이월에는 평생 광고 제거·감사 쿠폰이 함께 보인다.
    AdsService.instance.removeAds.value = true;

    await tester.pumpWidget(const MemoApp());

    // 스플래시 타이머(750ms) 뒤 fade-out(400ms), HomeShell route fade(500ms) 통과.
    // 타이머 콜백에서 각 애니메이션이 시작되므로 구간별로 펌프해야 한다.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUi(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('메모').last);
    await pumpUi(tester);

    // iOS: GL 표면을 이미지로 전환해야 takeScreenshot 이 실제 픽셀을 돌려준다.
    // 앱이 다 뜬 뒤, 첫 캡처 전에 한 번만 호출한다.
    await binding.convertFlutterSurfaceToImage();
    await pumpUi(tester, const Duration(milliseconds: 500));

    // ① 메인 메모 리스트 (다크)
    await captureStoreShot(tester, '01-main');

    // ② 설정 탭 (광고제거·구매 복원·정책 포함)
    await tester.tap(find.text('설정').last);
    await pumpUi(tester);
    await captureStoreShot(tester, '02-settings');

    // ③ Drive 백업·복원 화면
    await tester.tap(find.text('백업 & 복원'));
    await pumpUi(tester);
    await captureStoreShot(tester, '03-backup');
    await tester.tap(find.byType(BackButton));
    await pumpUi(tester);

    // ★④ '04-premium'(구독 결제화면 ₩1,900) 컷 제거 — T-260805-076.
    //   구독 상품이 폐지됐으므로 이 컷을 스토어에 올리면 ★팔지 않는 물건을 광고하게 된다.
    //   (같은 유형의 결함이 T-260804-084 = 스토어 리스팅이 없어진 AI 요약을 계속 파는 건이다.)
    //   장수가 준 것은 누락이 아니라 의도다 — 캡처 세트는 파는 것만 보여준다.

    // 설정 → 메모 탭 복귀
    await tester.tap(find.text('메모').last);
    await pumpUi(tester);

    // ⑤ 빠른 편집 / 즉시 입력 (바텀바 새메모 → autofocus)
    await tester.tap(find.text('새메모'));
    await pumpUi(tester);
    await tester.enterText(
      find.byType(TextField).first,
      '오후 3시 약속\n카페에서 기획안 리뷰',
    );
    await pumpUi(tester);
    await pumpUi(tester, const Duration(milliseconds: 300));
    await captureStoreShot(tester, '05-edit');

    // 편집 화면을 닫는다.
    // ★프리미엄 권한 주입 제거 — T-260805-076. 종전에는 말로찾기 캡처를 위해
    //   구독 엔티틀먼트를 켰는데, 구독 폐지로 search_screen 의 결제 관문이 사라졌다.
    //   지금 말로찾기를 여는 열쇠는 kSemanticSearchEnabled 하나뿐이라 주입이 무의미하다.
    await tester.tap(find.text('뒤로'));
    await pumpUi(tester);

    // ⑦ 뜻으로 찾기 — 실제 SearchScreen + 테스트 임베딩 전송계층.
    final embeddingClient = MemoyoEmbeddingClient(
      transport: (_, payload) async {
        final texts = (payload['texts'] as List).cast<String>();
        return {
          'model': 'gemini-embedding-001',
          'dimensions': 2,
          'embeddings': texts
              .map(
                (text) =>
                    text.contains('회의') ||
                        text.contains('분기') ||
                        text.contains('프로젝트')
                    ? [1.0, 0.0]
                    : [0.0, 1.0],
              )
              .toList(),
        };
      },
    );
    final searchContext = tester.element(find.byType(Scaffold).last);
    unawaited(
      Navigator.of(searchContext).push<void>(
        MaterialPageRoute(
          builder: (_) => SearchScreen(embeddingClient: embeddingClient),
        ),
      ),
    );
    await pumpUi(tester);
    // SearchScreen 은 unawaited push 라 라우트 정착에 여유를 준다.
    await pumpUi(tester, const Duration(milliseconds: 900));

    // ⑦ 뜻으로 찾기. 이 기능은 가용성 게이트(features/memos/semantic_search_availability)
    // 에 걸려 빌드·설정에 따라 탭 자체가 없을 수 있다. 없으면 이 컷만 건너뛰되
    // ★조용히 넘기지 않는다 — 로그에 남겨 캡처 장수가 준 이유가 드러나게 한다.
    final semanticTab = find.text('뜻으로 찾기');
    if (semanticTab.evaluate().isEmpty) {
      debugPrint(
        '[store-shot-skip] 07-semantic-search — "뜻으로 찾기" 탭이 화면에 없다. '
        '가용성 게이트가 닫혀 있거나 UI 가 바뀌었다. 이 컷은 캡처되지 않았다.',
      );
    } else {
      await tester.tap(semanticTab);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '프로젝트 계획');
      await tester.pump(const Duration(milliseconds: 350));
      await pumpUi(tester);
      await pumpUi(tester, const Duration(milliseconds: 300));
      await captureStoreShot(tester, '07-semantic-search');
    }
  });
}
