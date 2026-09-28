import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

/// T-260803-035 재현 프로브 — "엔터·백스페이스를 번갈아 치면 본문이 계속 밀려 내려간다".
///
/// 아니키 제보 영상(2026-08-03 11:42~11:43, 8초). 프레임 전개로 읽은 실제 증상은
/// **커서는 2번째 줄에 고정인데 그 아래 빈 줄이 쌓여 본문 블록이 화면 밖으로 밀린다** 이다.
/// 즉 스크롤 오프셋이 아니라 텍스트가 늘어나는 모양 ⇒ 편집값 레벨에서 계측할 수 있다.
///
/// 이 파일은 **수리가 아니라 재현**이다. 사이클마다 실제 텍스트 길이를 찍어
/// "한 사이클에 개행이 몇 개 순증하는가" 를 숫자로 남긴다.
///
/// 플랫폼을 iOS 로 고정한다 — 직전 사이클에서 안드로이드 실기(S24)는 순증 0 으로
/// 음성 확정됐고, 영상은 iOS(다이나믹 아일랜드·iOS 한글 키보드)로 판명됐다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 제보 영상의 실제 메모 모양 — 1줄 헤더 + 빈 줄 + 본문 블록.
  const seed = '1149 20 5\n\n부산 0905 서울 1149 미포장 4개 행낭 1개(4개입) 12호차\n'
      '동대구 0953 서울 1149 행낭 1개(6개입) 14호차\n'
      '대전 1036 서울 1149 미포장2개 행낭1(3개) 14호';
  // '1149 20 5' = 9자, 그 뒤 개행 1개 → 빈 줄(=커서가 놓인 자리) 오프셋 10.
  const caretOnBlankLine = 10;

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

  int newlineCount(String s) => '\n'.allMatches(s).length;

  // ── IME 경로 (실기기 소프트 키보드가 타는 길) ──────────────────────────────
  // iOS 키보드는 키 이벤트가 아니라 **완성된 새 값**을 밀어넣는다.
  Future<void> imeInsert(
    WidgetTester tester,
    EditableTextState state,
    String insert,
  ) async {
    final v = state.textEditingValue;
    final caret = v.selection.baseOffset;
    state.updateEditingValue(
      TextEditingValue(
        text: v.text.replaceRange(caret, caret, insert),
        selection: TextSelection.collapsed(offset: caret + insert.length),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> imeBackspace(
    WidgetTester tester,
    EditableTextState state,
  ) async {
    final v = state.textEditingValue;
    final caret = v.selection.baseOffset;
    if (caret <= 0) return;
    state.updateEditingValue(
      TextEditingValue(
        text: v.text.replaceRange(caret - 1, caret, ''),
        selection: TextSelection.collapsed(offset: caret - 1),
      ),
    );
    await tester.pumpAndSettle();
  }

  // flutter_test 는 테스트 본문이 끝나는 시점에 foundation 디버그 변수 원복을
  // 검사하므로 tearDown 이 아니라 **본문 안에서** 되돌려야 한다.
  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('iOS 플랫폼', () {

    testWidgets('★재현 프로브 IME — 엔터·백스페이스 10회 교대', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        final state = await pumpEditor(tester, content: seed);
        await placeCaret(tester, state, caretOnBlankLine);

        final before = state.textEditingValue.text;
        debugPrint('[drift] 시작 개행수=${newlineCount(before)} 길이=${before.length} '
            'caret=${state.textEditingValue.selection.baseOffset}');

        for (var i = 1; i <= 10; i++) {
          await imeInsert(tester, state, '\n');
          final mid = state.textEditingValue;
          await imeBackspace(tester, state);
          final end = state.textEditingValue;
          debugPrint('[drift] 사이클$i 엔터후 개행수=${newlineCount(mid.text)} '
              'caret=${mid.selection.baseOffset} → 백스페이스후 개행수='
              '${newlineCount(end.text)} caret=${end.selection.baseOffset} '
              '길이=${end.text.length}');
        }

        final after = state.textEditingValue.text;
        debugPrint('[drift] 최종 개행수=${newlineCount(after)} 길이=${after.length} '
            '순증=${after.length - before.length}');

        expect(
          after,
          before,
          reason: '엔터·백스페이스 교대 10회는 원문을 그대로 두어야 한다 (순증 0)',
        );
      });
    });

    testWidgets('★재현 프로브 하드웨어키 — 엔터·백스페이스 10회 교대', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        final state = await pumpEditor(tester, content: seed);
        await placeCaret(tester, state, caretOnBlankLine);

        final before = state.textEditingValue.text;
        for (var i = 1; i <= 10; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pumpAndSettle();
          final end = state.textEditingValue;
          debugPrint('[drift-hw] 사이클$i 개행수=${newlineCount(end.text)} '
              'caret=${end.selection.baseOffset} 길이=${end.text.length}');
        }
        final after = state.textEditingValue.text;
        debugPrint('[drift-hw] 순증=${after.length - before.length}');

        expect(after, before, reason: '하드웨어키 경로도 순증 0 이어야 한다');
      });
    });

    // 대조군 — 저장 경로가 빈 줄을 삼키는지 본다. _normalizeContent 가
    // trim() 을 걸므로 "화면엔 쌓였는데 저장하면 사라진다" 라면 증상 해석이 달라진다.
    testWidgets('대조군 — 커서가 문서 끝일 때 교대', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        final state = await pumpEditor(tester, content: seed);
        await placeCaret(tester, state, seed.length);

        final before = state.textEditingValue.text;
        for (var i = 1; i <= 10; i++) {
          await imeInsert(tester, state, '\n');
          await imeBackspace(tester, state);
        }
        final after = state.textEditingValue.text;
        debugPrint('[drift-end] 순증=${after.length - before.length}');
        expect(after, before);
      });
    });
  });

  group('Android 플랫폼 (대조군 — 실기 S24 에서 순증 0 으로 음성 확정된 조건)', () {

    testWidgets('IME — 엔터·백스페이스 10회 교대', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        final state = await pumpEditor(tester, content: seed);
        await placeCaret(tester, state, caretOnBlankLine);

        final before = state.textEditingValue.text;
        for (var i = 1; i <= 10; i++) {
          await imeInsert(tester, state, '\n');
          await imeBackspace(tester, state);
        }
        final after = state.textEditingValue.text;
        debugPrint('[drift-android] 순증=${after.length - before.length}');
        expect(after, before);
      });
    });
  });
}
