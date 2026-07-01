import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('마우스 휠로 메모 리스트를 한 화면보다 멀리 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 7, 1, 19, 30);
    final memos = List.generate(
      80,
      (i) => Memo(
        id: 'memo-$i',
        content: '휠스크롤 메모 $i\n본문',
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
    expect(find.text('휠스크롤 메모 0'), findsOneWidget);

    final topRight = tester.getTopRight(find.byType(CustomScrollView));
    final wheelOverDragHandle = topRight.translate(-24, 96);
    for (var i = 0; i < 3; i++) {
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          viewId: tester.view.viewId,
          position: wheelOverDragHandle,
          scrollDelta: const Offset(0, 900),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(scrollable.position.pixels, greaterThan(1280));
    expect(find.text('휠스크롤 메모 0'), findsNothing);
  });
}
