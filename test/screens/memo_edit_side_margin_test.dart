// T-261116-034: 메모 수정 화면 본문의 좌우 글자 여백이 같아야 한다.
// 대종님 11/16 「좌우 여백이 달라 균형 맞춰줘」 — 한글 줄이 단어 단위로 꺾여 오른쪽 끝이
// 들쭉날쭉했고, 입력 칸이 오른쪽에만 커서 자리(3)를 따로 빼서 오른쪽이 늘 3 더 넓었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';
import 'package:simple_memo_app/widgets/toss_surface_card.dart';

void main() {
  testWidgets('꺾인 줄은 카드 안에서 좌우 글자 여백이 같다', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.languageCode.value = 'ko';
    final now = DateTime(2026, 11, 16, 12);
    // 띄어쓰기가 있는 긴 문단 — 첫 줄은 반드시 꺾인다.
    final body = List.filled(40, '부산 미포장 행낭').join(' ');
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: Memo(id: 'm', content: body, createdAt: now, updatedAt: now),
        onSave: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(TossSurfaceCard).first);
    final editable = tester
        .state<EditableTextState>(find.descendant(
          of: find.byType(TossSurfaceCard).first,
          matching: find.byType(EditableText),
        ))
        .renderEditable;
    expect(editable.textAlign, TextAlign.justify);

    TextBox boxAt(int i) => editable
        .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
        .first;
    final firstTop = boxAt(0).top;
    // 첫 줄이 꺾이는 자리 = 윗변이 처음으로 달라지는 글자. 그 앞 공백(줄 끝에 매달린 칸)은 뺀다.
    var breakAt = 1;
    while ((boxAt(breakAt).top - firstTop).abs() < 1) {
      breakAt++;
    }
    var last = breakAt - 1;
    while (body[last] == ' ') {
      last--;
    }
    final left = boxAt(0).left;
    final right = boxAt(last).right;
    final leftGap = editable.localToGlobal(Offset(left, firstTop)).dx - card.left;
    final rightGap = card.right - editable.localToGlobal(Offset(right, firstTop)).dx;

    expect(leftGap, closeTo(16, 1), reason: 'left=$leftGap right=$rightGap');
    expect(rightGap, closeTo(leftGap, 1), reason: 'left=$leftGap right=$rightGap');
  });
}
