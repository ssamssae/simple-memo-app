// 메모요 Play Store 스크린샷 자동 캡처 하니스 (다크모드 실제 화면).
// flutter drive 로 부팅된 시뮬레이터에서 구동 → 각 화면 실제 렌더를 PNG 로 산출.
// 데모 메모는 SharedPreferences(MemoStorage) 에 시드(목업 합성 X — 실제 앱 화면).
//
// 실행:
//   flutter drive \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/screenshot_test.dart \
//     -d <ios-sim-udid>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    await tester.pumpWidget(const MemoApp());
    // iOS 시뮬에서 takeScreenshot 위해 surface→image 전환(1회).
    await binding.convertFlutterSurfaceToImage();

    // 스플래시(750ms) + 전환(500ms) 통과
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    // ① 메인 메모 리스트 (다크)
    await binding.takeScreenshot('01-main');

    // ② 메뉴 (Drive 백업 등) 노출
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-menu');

    // ③ 설정 화면 (정책/평가 포함) — 팝업의 '설정' 탭
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-settings');

    // 설정 → 리스트 복귀 (표준 AppBar back)
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // ④ 빠른 편집 / 즉시 입력 (FAB → 새 메모, autofocus) — 마지막(복귀 불요)
    await tester.tap(find.byTooltip('새 메모'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      '오후 3시 약속\n카페에서 기획안 리뷰',
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-edit');
  });
}
