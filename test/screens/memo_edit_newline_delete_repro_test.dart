import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

/// T-260729-026 재현 프로브 — "줄바꿈 한번 지우면 두번 연속 안 지워짐".
///
/// 아니키 실기기 영상 제보(2026-07-29 11:49). 이 파일은 **수리가 아니라 재현**이
/// 목적이다. 원인을 먼저 단정하지 말라는 배차 지시에 따라, 가설을 코드로 옮기는
/// 대신 조작을 그대로 흉내내고 관측값을 찍는다.
///
/// 대조군을 같이 둔다 — 일반 글자 연속 삭제가 같은 경로에서 정상이면
/// "백스페이스 자체가 두 번 안 먹는다" 가 아니라 "개행에서만 갈린다" 가 증명된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EditableTextState> pumpEditor(
    WidgetTester tester, {
    required String content,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(memo: Memo.create(content: content), onSave: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    return tester.state<EditableTextState>(find.byType(EditableText));
  }

  /// 커서를 offset 에 접힘 상태로 놓는다 (실기기에서 그 자리를 탭한 것과 같다).
  Future<void> placeCaret(
    WidgetTester tester,
    EditableTextState state,
    int offset,
  ) async {
    state.updateEditingValue(
      state.textEditingValue.copyWith(
        selection: TextSelection.collapsed(offset: offset),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> backspace(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
  }

  testWidgets('★재현 프로브 — 빈 줄에서 백스페이스 2연타', (tester) async {
    // '가' 다음에 빈 줄이 둘. 커서를 두 번째 개행 뒤(=빈 줄)에 놓는다.
    // 인덱스:      0:'가' 1:'\n' 2:'\n' 3:'\n' 4:'나'
    final state = await pumpEditor(tester, content: '가\n\n\n나');
    await placeCaret(tester, state, 3);

    final before = state.textEditingValue;
    await backspace(tester);
    final after1 = state.textEditingValue;
    await backspace(tester);
    final after2 = state.textEditingValue;

    // 관측값을 그대로 남긴다 — 통과/실패보다 이 출력이 산출물이다.
    debugPrint('[repro] before  text=${before.text.replaceAll('\n', r'\n')} '
        'sel=${before.selection.baseOffset},${before.selection.extentOffset}');
    debugPrint('[repro] after#1  text=${after1.text.replaceAll('\n', r'\n')} '
        'sel=${after1.selection.baseOffset},${after1.selection.extentOffset}');
    debugPrint('[repro] after#2  text=${after2.text.replaceAll('\n', r'\n')} '
        'sel=${after2.selection.baseOffset},${after2.selection.extentOffset}');

    // 정상이라면 개행이 하나씩 두 번 지워져 '가\n나' 가 된다.
    expect(after1.text, '가\n\n나', reason: '1타: 개행 1개 삭제');
    expect(after2.text, '가\n나', reason: '2타: 개행 1개 더 삭제 — 여기가 제보 지점');
  });

  testWidgets('대조군 — 일반 글자에서 백스페이스 2연타는 정상', (tester) async {
    final state = await pumpEditor(tester, content: '가나다라');
    await placeCaret(tester, state, 4);

    await backspace(tester);
    expect(state.textEditingValue.text, '가나다');
    await backspace(tester);
    expect(state.textEditingValue.text, '가나');
  });

  testWidgets('대조군 — 빈 줄이 아닌 개행 2연타', (tester) async {
    // 개행 앞뒤에 글자가 있는 경우(빈 줄 아님).
    // 인덱스: 0:'가' 1:'\n' 2:'나' 3:'\n' 4:'다'
    final state = await pumpEditor(tester, content: '가\n나\n다');
    await placeCaret(tester, state, 4);

    await backspace(tester);
    expect(state.textEditingValue.text, '가\n나다');
    // 2타는 커서 앞 글자('나')를 지운다 — 개행이 아니라 글자 차례다.
    await backspace(tester);
    expect(state.textEditingValue.text, '가\n다');
  });

  // ── IME(소프트 키보드) 경로 ────────────────────────────────────────────────
  // 위 프로브는 sendKeyEvent = 하드웨어 키 경로이고 Flutter 자체 DeleteCharacterIntent 를
  // 탄다. 실기기(iOS) 백스페이스는 그 경로가 아니라 엔진이 **완성된 새 값**을 밀어넣는
  // TextInputClient.updateEditingValue 경로다. 제보가 실기기에서 나왔으므로 이쪽을 따로 친다.
  //
  // 여기서 보려는 것은 "삭제가 되나" 가 아니라 **앱이 IME 가 준 값을 되쓰는가** 다.
  // 되쓰면 IME 쪽 캐럿과 앱 캐럿이 어긋나고, 그 다음 타가 엉뚱한 자리를 지우거나
  // 통째로 먹히지 않는다 — 제보 문구("두 번 연속 안 지워짐")와 모양이 같다.
  Future<TextEditingValue> imeBackspace(
    WidgetTester tester,
    EditableTextState state,
  ) async {
    final v = state.textEditingValue;
    final caret = v.selection.baseOffset;
    final sent = TextEditingValue(
      text: v.text.replaceRange(caret - 1, caret, ''),
      selection: TextSelection.collapsed(offset: caret - 1),
    );
    state.updateEditingValue(sent);
    await tester.pumpAndSettle();
    return sent;
  }

  testWidgets('★재현 프로브 IME — 빈 줄에서 백스페이스 2연타 (실기기 경로)', (tester) async {
    final state = await pumpEditor(tester, content: '가\n\n\n나');
    await placeCaret(tester, state, 3);

    final sent1 = await imeBackspace(tester, state);
    final got1 = state.textEditingValue;
    final sent2 = await imeBackspace(tester, state);
    final got2 = state.textEditingValue;

    String f(TextEditingValue x) =>
        '${x.text.replaceAll('\n', r'\n')} sel=${x.selection.baseOffset},${x.selection.extentOffset}';
    debugPrint('[repro-ime] #1 IME가 보낸값=${f(sent1)} | 앱 최종=${f(got1)}');
    debugPrint('[repro-ime] #2 IME가 보낸값=${f(sent2)} | 앱 최종=${f(got2)}');

    // 앱이 IME 값을 그대로 받았는지(되쓰지 않았는지) 가 핵심 관측이다.
    expect(got1.text, sent1.text, reason: '1타: 앱이 텍스트를 되쓰지 않아야 한다');
    expect(got1.selection, sent1.selection, reason: '1타: 앱이 캐럿을 되쓰지 않아야 한다');
    expect(got2.text, sent2.text, reason: '2타: 앱이 텍스트를 되쓰지 않아야 한다');
    expect(got2.selection, sent2.selection, reason: '2타: 앱이 캐럿을 되쓰지 않아야 한다');
    expect(got2.text, '가\n나');
  });

  // ── 선택(비접힘) 경로 ──────────────────────────────────────────────────────
  // 위 두 프로브가 다 통과했으므로 접힘 캐럿 경로에는 결함이 없다. 남은 자리는
  // 앱이 **유일하게 편집값을 되쓰는** _clampSelectionTrailingNewline 이고, 이건
  // 접힘 선택에서 조기 반환하므로 위 프로브들이 구조적으로 못 건드린 영역이다.
  // 실기기에서 빈 줄을 드래그·더블탭으로 잡고 지우는 조작이 여기로 들어온다.
  testWidgets('★선택 경로 — 개행만 선택하면 선택이 통째로 접힌다', (tester) async {
    // 인덱스: 0:'가' 1:'\n' 2:'\n' 3:'\n' 4:'나'
    final state = await pumpEditor(tester, content: '가\n\n\n나');

    // 빈 줄 두 개를 선택 (1..3 = '\n\n')
    state.updateEditingValue(
      state.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 1, extentOffset: 3),
      ),
    );
    await tester.pumpAndSettle();

    final sel = state.textEditingValue.selection;
    debugPrint('[repro-sel] 요청 선택=1..3 → 실제 선택='
        '${sel.baseOffset}..${sel.extentOffset} collapsed=${sel.isCollapsed}');

    // 여기서 접히면 이어지는 삭제가 아무것도 못 지운다.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    debugPrint('[repro-sel] 백스페이스 후 text='
        '${state.textEditingValue.text.replaceAll('\n', r'\n')}');

    expect(
      state.textEditingValue.text,
      '가\n나',
      reason: '선택한 빈 줄 2개가 지워져야 한다',
    );
  });

  testWidgets('★선택 경로 — 문서 끝 빈 줄 선택 후 삭제', (tester) async {
    // 문서 끝이 개행으로 끝나는 형태 (trailing blank line).
    // 인덱스: 0:'가' 1:'\n' 2:'\n'
    final state = await pumpEditor(tester, content: '가\n\n');

    state.updateEditingValue(
      state.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 1, extentOffset: 3),
      ),
    );
    await tester.pumpAndSettle();

    final sel = state.textEditingValue.selection;
    debugPrint('[repro-sel2] 요청 선택=1..3 → 실제 선택='
        '${sel.baseOffset}..${sel.extentOffset} collapsed=${sel.isCollapsed}');

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    debugPrint('[repro-sel2] 백스페이스 후 text='
        '${state.textEditingValue.text.replaceAll('\n', r'\n')}');

    expect(state.textEditingValue.text, '가');
  });
}
