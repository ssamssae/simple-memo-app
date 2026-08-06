import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

/// T-260803-035 재현 프로브 — "백스페이스·엔터를 번갈아 치면 본문이 계속 아래로 밀린다".
///
/// 아니키 실기기 영상 제보(2026-08-03 13:2x). **수리가 아니라 재현**이 목적이다.
///
/// ★이 파일은 계기 고장을 두 번 겪고 고친 결과다. 다음 사람이 같은 함정에 빠지지 않도록 남긴다.
///   (1) 첫 판은 `sendKeyEvent(backspace)` 를 썼는데 10회 중 **0회 삭제**됐고(텍스트 289→299)
///       그 상태의 오프셋 증가(+27/사이클)를 하마터면 "드리프트" 로 읽을 뻔했다. 실제로는
///       줄이 10줄 늘어난 정상 반응이었다. ⇒ 삭제가 일어났는지 **매 회 단언**한다.
///   (2) 둘째 판은 오프셋이 완벽히 평평(1108.0 고정)했는데, 이는 필드에 **포커스가 없어서**
///       커서 추적 로직이 아예 안 돈 것이었다. 화면 코드가 `autofocus: !_isEditing` 이라
///       기존 메모 편집에서는 자동 포커스가 안 걸린다(아니키는 탭해서 들어갔다).
///       ⇒ showKeyboard 로 포커스를 주고, **양성 대조군**으로 "커서를 옮기면 오프셋이 실제로
///          움직인다"를 먼저 증명한 뒤에만 드리프트 유무를 판정한다.
///
/// 소프트키보드 경로를 쓰는 이유 = 아니키는 폰 키보드를 썼고, 그 경로에서 엔진이 보내는 것은
/// 키 이벤트가 아니라 갱신된 editing value 다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final longContent = List.generate(60, (i) => '줄 $i').join('\n');

  /// 화면을 띄우고 **포커스까지** 준다. 포커스 없이 잰 오프셋은 증거가 아니다.
  Future<EditableTextState> pumpFocusedEditor(
    WidgetTester tester, {
    required String content,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(memo: Memo.create(content: content), onSave: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(
      state.widget.focusNode.hasFocus,
      isTrue,
      reason: '★계기 고장 — 필드에 포커스가 없다. 커서 추적이 안 돌므로 오프셋 관측이 무의미하다',
    );
    return state;
  }

  double outerOffset(WidgetTester tester) =>
      tester.widget<Scrollable>(find.byType(Scrollable).first)
          .controller!
          .position
          .pixels;

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

  Future<void> imeInsert(
    WidgetTester tester,
    EditableTextState state,
    String s,
  ) async {
    final v = state.textEditingValue;
    final at = v.selection.baseOffset;
    state.updateEditingValue(
      TextEditingValue(
        text: v.text.replaceRange(at, at, s),
        selection: TextSelection.collapsed(offset: at + s.length),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 소프트키보드 백스페이스. ★삭제가 실제로 일어났는지 단언한다 (계기 생존).
  Future<void> imeBackspace(
    WidgetTester tester,
    EditableTextState state,
  ) async {
    final before = state.textEditingValue;
    final at = before.selection.baseOffset;
    expect(at > 0, isTrue, reason: '커서가 맨 앞이라 백스페이스를 잴 수 없다');
    state.updateEditingValue(
      TextEditingValue(
        text: before.text.replaceRange(at - 1, at, ''),
        selection: TextSelection.collapsed(offset: at - 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      state.textEditingValue.text.length,
      before.text.length - 1,
      reason: '★계기 고장 — 백스페이스가 실제로 지우지 않았다. 이 관측값은 증거가 아니다',
    );
  }

  testWidgets('★양성 대조군 — 커서를 옮기면 바깥 오프셋이 실제로 움직인다', (tester) async {
    // 이게 빨개지면 이 하네스는 커서 추적 스크롤을 관측하지 못한다.
    // 그 상태에서 나온 "드리프트 없음" 은 증거가 아니라 계기 고장이다.
    final state = await pumpFocusedEditor(tester, content: longContent);
    await placeCaret(tester, state, state.textEditingValue.text.length);
    final atBottom = outerOffset(tester);
    await placeCaret(tester, state, 0);
    final atTop = outerOffset(tester);
    debugPrint('[T-260803-035][양성대조] 문서끝=$atBottom 문서앞=$atTop');
    expect(
      atTop,
      lessThan(atBottom),
      reason: '커서를 문서 앞으로 옮겼는데 오프셋이 안 움직였다 = 계기가 죽었다',
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('★재현 프로브 [$platform] — 엔터·백스페이스 교호 시 본문이 밀리는가', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;

      final state = await pumpFocusedEditor(tester, content: longContent);
      await placeCaret(tester, state, state.textEditingValue.text.length);

      final startText = state.textEditingValue.text;
      final offsets = <double>[outerOffset(tester)];
      for (var i = 0; i < 10; i++) {
        await imeInsert(tester, state, '\n');
        await imeBackspace(tester, state);
        offsets.add(outerOffset(tester));
      }
      final endText = state.textEditingValue.text;

      // ★프레임워크가 테스트 종료 시 이 변수의 원복을 검사하므로 단언 전에 되돌린다.
      debugDefaultTargetPlatformOverride = null;

      debugPrint('[T-260803-035][$platform] 궤적=$offsets');
      debugPrint('[T-260803-035][$platform] 텍스트 ${startText.length} → ${endText.length}');

      expect(endText, startText, reason: '교호 10회 뒤 본문이 달라졌다');
      expect(
        offsets.last,
        offsets.first,
        reason:
            '본문은 같은데 바깥 스크롤 오프셋이 ${offsets.first} → ${offsets.last} 로 밀렸다 '
            '= 사용자 눈에 "본문이 아래로 밀린다"',
      );
    });
  }

  /// ★문서 **중간** + 키보드 올라온 상태 — 실제 제보 상황에 가장 가까운 배치.
  ///
  /// 위의 프로브들은 커서를 문서 끝에 뒀는데, 거기는 이미 maxScrollExtent 라 밀릴 여지가
  /// 물리적으로 없다(그래서 평평했다 — "드리프트 없음"이 아니라 "잴 수 없는 자리"였다).
  /// 아니키는 메모 중간을 고치고 있었고 폰 키보드가 화면 아래를 덮고 있었다.
  Future<EditableTextState> pumpWithKeyboard(
    WidgetTester tester, {
    required String content,
    required double insetBottom,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: insetBottom)),
          child: MemoEditScreen(
            memo: Memo.create(content: content),
            onSave: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    return tester.state<EditableTextState>(find.byType(EditableText));
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('★재현 프로브 [$platform] — 문서 중간 + 키보드 올라온 상태', (tester) async {
      debugDefaultTargetPlatformOverride = platform;

      final state = await pumpWithKeyboard(
        tester,
        content: longContent,
        insetBottom: 336, // 실기기 소프트키보드 대략치
      );
      // 문서 중간에 커서를 둔다 — 위아래 양쪽으로 밀릴 여지가 있는 자리.
      final mid = state.textEditingValue.text.length ~/ 2;
      await placeCaret(tester, state, mid);

      final startText = state.textEditingValue.text;
      final offsets = <double>[outerOffset(tester)];
      for (var i = 0; i < 10; i++) {
        await imeInsert(tester, state, '\n');
        await imeBackspace(tester, state);
        offsets.add(outerOffset(tester));
      }
      final endText = state.textEditingValue.text;

      debugDefaultTargetPlatformOverride = null;

      debugPrint('[T-260803-035][$platform·중간+키보드] 궤적=$offsets');
      debugPrint(
        '[T-260803-035][$platform·중간+키보드] 텍스트 ${startText.length} → ${endText.length}',
      );

      expect(endText, startText, reason: '교호 10회 뒤 본문이 달라졌다');
      expect(
        offsets.last,
        offsets.first,
        reason:
            '본문은 같은데 오프셋이 ${offsets.first} → ${offsets.last} 로 밀렸다 '
            '= 사용자 눈에 "본문이 아래로 밀린다"',
      );
    });
  }

  /// ★한글 조합(composing) 중 엔터 — 2026-08-03 레그가 "미지수" 로 남긴 마지막 변수.
  ///
  /// 한글은 조합 중 상태(composing range)를 거쳐 확정된다. 위 프로브들은 확정된 값만
  /// 보내므로 조합 경로를 한 번도 안 밟는다. 실기기에서 아니키가 글자를 치던 중
  /// 엔터를 눌렀다면 그 순간 조합이 확정되면서 값이 두 번 갱신된다.
  testWidgets('★재현 프로브 — 한글 조합 중 엔터·백스페이스 교호', (tester) async {
    final state = await pumpWithKeyboard(
      tester,
      content: longContent,
      insetBottom: 336,
    );
    final mid = state.textEditingValue.text.length ~/ 2;
    await placeCaret(tester, state, mid);

    final startText = state.textEditingValue.text;
    final offsets = <double>[outerOffset(tester)];

    for (var i = 0; i < 10; i++) {
      // (1) 조합 시작 — 'ㄱ' 이 composing 상태로 들어간다.
      var v = state.textEditingValue;
      var at = v.selection.baseOffset;
      state.updateEditingValue(
        TextEditingValue(
          text: v.text.replaceRange(at, at, 'ㄱ'),
          selection: TextSelection.collapsed(offset: at + 1),
          composing: TextRange(start: at, end: at + 1),
        ),
      );
      await tester.pumpAndSettle();

      // (2) 조합 확정 + 개행 (엔터가 조합을 끊는 실기기 동작).
      v = state.textEditingValue;
      at = v.selection.baseOffset;
      state.updateEditingValue(
        TextEditingValue(
          text: v.text.replaceRange(at, at, '\n'),
          selection: TextSelection.collapsed(offset: at + 1),
        ),
      );
      await tester.pumpAndSettle();

      // (3) 되돌리기 — 개행과 글자를 백스페이스 2회로 지운다.
      await imeBackspace(tester, state);
      await imeBackspace(tester, state);
      offsets.add(outerOffset(tester));
    }

    debugPrint('[T-260803-035][한글조합] 궤적=$offsets');
    debugPrint(
      '[T-260803-035][한글조합] 텍스트 ${startText.length} → ${state.textEditingValue.text.length}',
    );

    expect(state.textEditingValue.text, startText, reason: '조합 교호 뒤 본문이 달라졌다');
    expect(
      offsets.last,
      offsets.first,
      reason: '조합 경로에서 오프셋이 ${offsets.first} → ${offsets.last} 로 밀렸다',
    );
  });

  testWidgets('대조군 — 일반 글자 입력·삭제 교호에서는 오프셋이 제자리다', (tester) async {
    final state = await pumpFocusedEditor(tester, content: longContent);
    await placeCaret(tester, state, state.textEditingValue.text.length);
    final start = outerOffset(tester);
    for (var i = 0; i < 10; i++) {
      await imeInsert(tester, state, '가');
      await imeBackspace(tester, state);
    }
    debugPrint('[T-260803-035][대조군] $start → ${outerOffset(tester)}');
    expect(outerOffset(tester), start, reason: '대조군까지 밀리면 개행 축이 아니다');
  });
}
