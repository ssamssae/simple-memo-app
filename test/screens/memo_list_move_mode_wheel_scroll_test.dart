import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('메모 이동(드래그) 중에도 마우스 휠로 리스트를 넘겨 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 7, 11, 12, 0);
    final memos = List.generate(
      80,
      (i) => Memo(
        id: 'memo-$i',
        content: '이동모드 휠 메모 $i\n본문',
        createdAt: now.add(Duration(seconds: i)),
        updatedAt: now.add(Duration(seconds: i)),
      ),
    );
    SharedPreferences.setMockInitialValues({'memos': Memo.encodeList(memos)});

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);

    // 첫 메모의 드래그 핸들을 잡아 이동 모드 진입 (마우스 드래그).
    final handleCenter = tester.getCenter(find.byIcon(Icons.drag_handle).first);
    final drag = await tester.startGesture(
      handleCenter,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await drag.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 100));

    // 드래그 프록시(elevation 2 Material)가 떠 있어야 이동 모드가 활성이다.
    final proxyFinder = find.byWidgetPredicate(
      (w) => w is Material && w.elevation == 2,
    );
    expect(proxyFinder, findsOneWidget, reason: '드래그(이동) 모드 진입 실패');

    // 이동 모드 유지 상태에서 커서 위치(들고 있는 메모 위)로 휠 이벤트 발사.
    final wheelPosition = handleCenter.translate(0, 24);
    for (var i = 0; i < 3; i++) {
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          viewId: tester.view.viewId,
          position: wheelPosition,
          scrollDelta: const Offset(0, 900),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 100));

    // 핵심 단언: 이동 중에도 휠로 한 화면 이상 넘어가야 한다.
    expect(
      scrollable.position.pixels,
      greaterThan(1280),
      reason: '이동(드래그) 모드 중 휠 스크롤이 동작하지 않음 — 아니키 재보고 2026-07-11 시나리오',
    );

    await drag.up();
    await tester.pumpAndSettle();
  });
}
