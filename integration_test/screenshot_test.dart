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
import 'package:simple_memo_app/screens/paywall_screen.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/ads_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';
import 'package:simple_memo_app/services/settings_service.dart';

const _captureWindowSeconds = int.fromEnvironment(
  'STORE_CAPTURE_SECONDS',
  defaultValue: 12,
);
const _lastCaptureWindowSeconds = int.fromEnvironment(
  'STORE_LAST_CAPTURE_SECONDS',
  defaultValue: _captureWindowSeconds,
);
const _captureTargets = String.fromEnvironment('STORE_CAPTURE_TARGETS');
const _targetCaptureWindowSeconds = int.fromEnvironment(
  'STORE_TARGET_CAPTURE_SECONDS',
  defaultValue: _captureWindowSeconds,
);

Future<void> pumpUi(
  WidgetTester tester, [
  Duration wait = const Duration(milliseconds: 700),
]) async {
  await tester.pump();
  await tester.pump(wait);
  await tester.pump();
}

Future<void> openExternalCaptureWindow(
  WidgetTester tester,
  String name, {
  bool isLast = false,
}) async {
  debugPrint('[store-shot-ready] $name');
  final isTarget = _captureTargets.split(',').contains(name);
  await tester.runAsync(
    () => Future<void>.delayed(
      Duration(
        seconds: isTarget
            ? _targetCaptureWindowSeconds
            : isLast
            ? _lastCaptureWindowSeconds
            : _captureWindowSeconds,
      ),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    // ① 메인 메모 리스트 (다크)
    await openExternalCaptureWindow(tester, '01-main');

    // ② 설정 탭 (프리미엄·구매 복원·정책 포함)
    await tester.tap(find.text('설정').last);
    await pumpUi(tester);
    await openExternalCaptureWindow(tester, '02-settings');

    // ③ Drive 백업·복원 화면
    await tester.tap(find.text('백업 & 복원'));
    await pumpUi(tester);
    await openExternalCaptureWindow(tester, '03-backup');
    await tester.tap(find.byType(BackButton));
    await pumpUi(tester);

    // ④ 프리미엄 구독 화면 — 심사 캡처용 가격만 주입, 결제 호출 없음.
    final settingsContext = tester.element(find.byType(Scaffold).last);
    unawaited(
      Navigator.of(settingsContext).push<void>(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(storePreviewPrice: '₩1,900'),
        ),
      ),
    );
    await pumpUi(tester);
    await openExternalCaptureWindow(tester, '04-premium');

    // 프리미엄 → 설정 → 메모 탭 복귀
    await tester.tap(find.byType(BackButton));
    await pumpUi(tester);
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
    await openExternalCaptureWindow(tester, '05-edit');

    // 편집 화면을 닫고 AI 기능 캡처용 프리미엄 권한을 로컬 테스트 상태로 설정.
    await tester.tap(find.text('뒤로'));
    await pumpUi(tester);
    PremiumService.instance.entitlement.value = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlementClient.premiumProductId,
      expiresAt: DateTime(2999),
      source: PremiumEntitlementSource.subscription,
    );

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
    await tester.tap(find.text('뜻으로 찾기'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '프로젝트 계획');
    await tester.pump(const Duration(milliseconds: 350));
    await pumpUi(tester);
    await pumpUi(tester, const Duration(milliseconds: 300));
    await openExternalCaptureWindow(tester, '07-semantic-search', isLast: true);

    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
  });
}
