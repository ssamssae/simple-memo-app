import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('마우스 휠로 긴 메모 편집 화면을 한 화면보다 멀리 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 7, 1, 19, 35);
    final content = List.generate(100, (i) => '긴 메모 줄 $i').join('\n');
    final memo = Memo(
      id: 'long-memo',
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(MaterialApp(home: MemoEditScreen(memo: memo)));
    await tester.pumpAndSettle();

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .reduce(
          (a, b) =>
              a.position.maxScrollExtent >= b.position.maxScrollExtent ? a : b,
        );
    expect(scrollable.position.pixels, 0);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.scrollPhysics, isA<NeverScrollableScrollPhysics>());

    final center = tester.getCenter(find.byType(SingleChildScrollView));
    for (var i = 0; i < 3; i++) {
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          viewId: tester.view.viewId,
          position: center,
          scrollDelta: const Offset(0, 900),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(scrollable.position.pixels, greaterThan(1280));
  });
}
