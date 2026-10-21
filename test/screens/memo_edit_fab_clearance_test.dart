import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

/// T-261022-006 r5 — 「사진 추가」 떠 있는 버튼은 본문 오른쪽 아래를 덮는다.
/// 긴 메모 끝에서 타이핑하면 줄 끝 글자와 커서가 버튼 밑으로 들어가면 안 된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 줄마다 오른쪽 끝까지 차는 긴 메모. 마지막 줄도 화면 폭을 거의 채운다.
  final line = '가나다라마바사아자차카타파하 ' * 3;
  final content = [
    for (var i = 0; i < 40; i++) '$i $line',
    '끝 $line가나다라마바사아',
  ].join('\n');
  final t = DateTime(2026, 10, 22, 9);

  Future<EditableTextState> pumpLongMemo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: Memo(id: 'long', content: content, createdAt: t, updatedAt: t),
        onSave: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<EditableTextState>(find.byType(EditableText));
  }

  Rect lastLineRect(EditableTextState state) {
    final editable = state.renderEditable;
    final text = state.textEditingValue.text;
    final boxes = editable.getBoxesForSelection(TextSelection(
      baseOffset: text.lastIndexOf('\n') + 1,
      extentOffset: text.length,
    ));
    return MatrixUtils.transformRect(
      editable.getTransformTo(null),
      boxes.last.toRect(),
    );
  }

  Rect caretRect(EditableTextState state) {
    final editable = state.renderEditable;
    final offset = state.textEditingValue.selection.extentOffset;
    return MatrixUtils.transformRect(
      editable.getTransformTo(null),
      editable.getLocalRectForCaret(TextPosition(offset: offset)),
    );
  }

  testWidgets(
    '키보드를 올리고 긴 메모 끝에서 타이핑해도 사진 버튼이 커서와 줄 끝을 가리지 않는다',
    (tester) async {
      final state = await pumpLongMemo(tester);
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();

      // 소프트 키보드 입력과 같은 경로: 끝에 글자를 붙인다.
      final typed = '$content자';
      state.updateEditingValue(TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final caret = caretRect(state);
      final lastLine = lastLineRect(state);
      final keyboardTop = tester.view.physicalSize.height - 336;
      expect(fab.bottom, lessThanOrEqualTo(keyboardTop),
          reason: '버튼은 키보드 위에 떠 있다');
      expect(lastLine.right, greaterThan(fab.left),
          reason: '계기 확인 — 마지막 줄이 버튼 쪽까지 차야 가림을 잴 수 있다');
      expect(caret.bottom, lessThanOrEqualTo(fab.top),
          reason: '커서 $caret 가 사진 버튼 $fab 밑에 있다');
      expect(lastLine.overlaps(fab), isFalse,
          reason: '마지막 줄 $lastLine 이 사진 버튼 $fab 에 덮인다');
    },
    variant: const TargetPlatformVariant(
      {TargetPlatform.iOS, TargetPlatform.android},
    ),
  );

  testWidgets('키보드 없이 끝까지 내리면 마지막 줄이 사진 버튼 위로 올라온다',
      (tester) async {
    final state = await pumpLongMemo(tester);
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(lastLineRect(state).overlaps(fab), isFalse);
  });

  testWidgets('짧은 메모는 처음 화면 배치가 그대로다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: Memo(id: 's', content: '장보기\n우유', createdAt: t, updatedAt: t),
        onSave: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, 0);
    // 본문 입력 영역은 여전히 화면 아래까지 차서 빈 곳을 눌러도 커서가 놓인다.
    final field = tester.getRect(find.byType(TextField));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(field.bottom, greaterThanOrEqualTo(fab.bottom));
  });
}
