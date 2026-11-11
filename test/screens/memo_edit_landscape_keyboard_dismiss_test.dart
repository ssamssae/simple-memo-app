import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

/// T-261112-003 — 가로 화면에서 키보드를 닫은 뒤 세 줄 메모의 첫 줄이 위로 가려진 채 남는다.
///
/// 관측(2026-11-11, 갤럭시 S24 가로): 체크리스트 세 줄이 키보드가 열린 동안에는
/// 마지막 두 줄만 보였고, 키보드를 닫아도 첫 줄은 보이는 영역 밖에 남았다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const content = '\u2610 first\n\u2610 second\n\u2610 third';
  final t = DateTime(2026, 11, 11, 23, 45);

  Rect lineRect(EditableTextState state, int start, int end) {
    final editable = state.renderEditable;
    final boxes = editable.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    expect(boxes, isNotEmpty, reason: '줄 $start..$end 의 글자 상자를 못 구했다');
    var rect = boxes.first.toRect();
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    return MatrixUtils.transformRect(editable.getTransformTo(null), rect);
  }

  String geometry(WidgetTester tester, EditableTextState state) {
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    final firstEnd = content.indexOf('\n');
    final first = lineRect(state, 0, firstEnd);
    final position = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .position;
    return 'first=$first viewport=$viewport '
        'scroll=${position.pixels}/${position.maxScrollExtent} '
        'viewportDim=${position.viewportDimension}';
  }

  void expectLineInside(Rect line, Rect viewport, String detail) {
    expect(
      line.top,
      greaterThanOrEqualTo(viewport.top - 0.5),
      reason: '첫 줄이 보이는 영역 위로 나갔다. $detail',
    );
    expect(
      line.bottom,
      lessThanOrEqualTo(viewport.bottom + 0.5),
      reason: '첫 줄이 보이는 영역 아래로 나갔다. $detail',
    );
  }

  testWidgets('가로 900x400에서 키보드를 닫으면 세 줄 메모의 첫 줄이 보이는 영역 안에 있다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(
          memo: Memo(
            id: 'landscape',
            content: content,
            createdAt: t,
            updatedAt: t,
          ),
          onSave: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.updateEditingValue(
      TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      ),
    );
    await tester.pumpAndSettle();

    final openDetail = geometry(tester, state);
    final openViewport = tester.getRect(find.byType(SingleChildScrollView));
    final openFirst = lineRect(state, 0, content.indexOf('\n'));
    expect(
      openFirst.top,
      lessThan(openViewport.top - 0.5),
      reason: '계기 확인 — 키보드가 열린 동안 첫 줄이 이미 보인다. $openDetail',
    );

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    final closedDetail = geometry(tester, state);
    expectLineInside(
      lineRect(state, 0, content.indexOf('\n')),
      tester.getRect(find.byType(SingleChildScrollView)),
      closedDetail,
    );
  });

  testWidgets('긴 메모는 키보드를 닫아도 보던 끝 자리를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);

    final longContent = List.generate(40, (i) => '줄 $i 본문').join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(
          memo: Memo(
            id: 'long-landscape',
            content: longContent,
            createdAt: t,
            updatedAt: t,
          ),
          onSave: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.updateEditingValue(
      TextEditingValue(
        text: longContent,
        selection: TextSelection.collapsed(offset: longContent.length),
      ),
    );
    await tester.pumpAndSettle();

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pumpAndSettle();

    final position = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .position;
    expect(position.maxScrollExtent, greaterThan(56));
    expect(position.pixels, greaterThan(56));

    final editable = state.renderEditable;
    final last = editable.getLocalRectForCaret(
      TextPosition(offset: longContent.length),
    );
    final caret = MatrixUtils.transformRect(
      editable.getTransformTo(null),
      last,
    );
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(caret.top, greaterThanOrEqualTo(viewport.top - 0.5));
    expect(caret.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
  });
}
