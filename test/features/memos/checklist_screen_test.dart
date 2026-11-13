import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/checklist_text.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const open = ChecklistText.unchecked;
  const done = ChecklistText.checked;
  final strings = AppStrings.fromCode('ko');
  final t = DateTime(2026, 11, 10, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.languageCode.value = 'ko';
    MemoListScreenState.markOrphanSweepDoneForTest();
  });

  Memo memo(String content) =>
      Memo(id: 'm1', content: content, createdAt: t, updatedAt: t);

  Future<void> pumpEditor(
    WidgetTester tester, {
    Memo? editing,
    ValueChanged<Memo>? onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MemoEditScreen(memo: editing, onSave: onSave ?? (_) {}),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Future<void> placeCaret(WidgetTester tester, int offset) async {
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.updateEditingValue(
      state.textEditingValue.copyWith(
        selection: TextSelection.collapsed(offset: offset),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterAt(WidgetTester tester, int offset) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await placeCaret(tester, offset);
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    final value = state.textEditingValue;
    final cursor = value.selection.baseOffset;
    final next =
        '${value.text.substring(0, cursor)}\n${value.text.substring(cursor)}';
    state.updateEditingValue(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor + 1),
      ),
    );
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  RenderEditable editableRender(WidgetTester tester) {
    final root = tester.renderObject(find.byType(EditableText));
    RenderEditable? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is RenderEditable) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    visit(root);
    return found!;
  }

  // T-261113-032: 편집 화면 체크리스트 단추는 없앴다(메모 왼쪽 체크 칸과 겹침).
  testWidgets('편집 화면에 체크리스트 단추가 없고 사진 추가 단추만 있다', (tester) async {
    await pumpEditor(tester, editing: memo('milk\neggs'));
    expect(find.byKey(const ValueKey<String>('checklist-button')), findsNothing);
    expect(find.byIcon(Icons.checklist), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
  });

  testWidgets('체크 줄에서 줄바꿈하면 다음 줄이 ☐ 로 시작한다', (tester) async {
    final text = '${open}milk';
    await pumpEditor(tester, editing: memo(text));

    await enterAt(tester, text.length);

    expect(fieldText(tester), '${open}milk\n$open');
  });

  testWidgets('빈 체크 줄에서 줄바꿈하면 표기를 지운다', (tester) async {
    final text = '${open}milk\n$open';
    await pumpEditor(tester, editing: memo(text));

    await enterAt(tester, text.length);

    expect(fieldText(tester), '${open}milk\n');
  });

  testWidgets('칸을 누르면 ☐ 와 ☑ 가 바뀌고 커서와 다른 글자는 그대로다', (tester) async {
    final text = '${open}milk';
    await pumpEditor(tester, editing: memo(text));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await placeCaret(tester, text.length);
    final before = tester
        .state<EditableTextState>(find.byType(EditableText))
        .textEditingValue
        .selection
        .baseOffset;

    await tester.tap(find.byKey(const ValueKey<String>('checklist-mark-0')));
    await tester.pumpAndSettle();

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.textEditingValue.text, '${done}milk');
    expect(state.textEditingValue.text.length, text.length);
    expect(state.textEditingValue.text.substring(1), text.substring(1));
    expect(state.textEditingValue.selection.baseOffset, before);
  });

  testWidgets('칸을 바꾼 뒤 뒤로 가면 그 글이 저장된다', (tester) async {
    Memo? saved;
    await pumpEditor(
      tester,
      editing: memo('${open}milk'),
      onSave: (value) => saved = value,
    );

    await tester.tap(find.byKey(const ValueKey<String>('checklist-mark-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.back));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.content, '${done}milk');
    expect(saved!.id, 'm1');
    final plain = Memo(
      id: 'plain',
      content: 'hello',
      createdAt: t,
      updatedAt: t,
    );
    expect(saved!.toJson().keys, plain.toJson().keys);
  });

  testWidgets('빈 체크 줄을 저장해도 접두 공백이 남고 키는 늘지 않는다', (tester) async {
    Memo? saved;
    await pumpEditor(
      tester,
      editing: memo('$open milk  \n$open'),
      onSave: (value) => saved = value,
    );

    await tester.tap(find.text(strings.back));
    await tester.pumpAndSettle();

    expect(saved!.content, '$open milk\n$open');
    expect(
      saved!.toJson().keys,
      Memo(
        id: 'plain',
        content: 'hello',
        createdAt: t,
        updatedAt: t,
      ).toJson().keys,
    );
  });

  testWidgets('목록은 체크 줄이 있을 때만 완료 수/전체 수를 보여 준다', (tester) async {
    final now = DateTime(2026, 11, 10, 9);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(
          id: 'check',
          content: '$done a\n$open b\n$done c\nplain\n$open d\n$open e',
          createdAt: now,
          updatedAt: now,
        ),
        Memo(
          id: 'plain',
          content: 'ordinary note',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('ordinary note'), findsOneWidget);
    expect(find.textContaining('ordinary'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('ordinary note'),
          matching: find.byType(Row),
        ),
        matching: find.textContaining('/'),
      ),
      findsNothing,
    );
  });

  testWidgets('400x800에서 900x400으로 바꾸면 칸 top이 ☐ 와 같고 누르면 ☑ 가 된다', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final firstLine = 'W' * 180;
    final source = '$firstLine\n${open}milk';
    final offset = firstLine.length + 1;
    await pumpEditor(tester, editing: memo(source));

    final mark = find.byKey(ValueKey<String>('checklist-mark-$offset'));
    final portraitTop = tester.getRect(mark).top;

    await tester.binding.setSurfaceSize(const Size(900, 400));
    await tester.pumpAndSettle();

    final editable = editableRender(tester);
    final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
    final caretTop = editable.localToGlobal(caret.topLeft).dy;
    final markTop = tester.getRect(mark).top;
    expect((caretTop - portraitTop).abs(), greaterThan(0.5));
    expect((markTop - caretTop).abs(), lessThanOrEqualTo(0.5));

    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(fieldText(tester), '$firstLine\n${done}milk');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('시스템 글자 배율을 키우면 칸 top이 ☐ 와 같고 누르면 ☑ 가 된다', (tester) async {
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.binding.setSurfaceSize(null);
    });
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final firstLine = 'W' * 80;
    final source = '$firstLine\n${open}milk';
    final offset = firstLine.length + 1;
    await pumpEditor(tester, editing: memo(source));

    final mark = find.byKey(ValueKey<String>('checklist-mark-$offset'));
    final beforeTop = tester.getRect(mark).top;

    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpAndSettle();

    final editable = editableRender(tester);
    final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
    final caretTop = editable.localToGlobal(caret.topLeft).dy;
    final markTop = tester.getRect(mark).top;
    expect((caretTop - beforeTop).abs(), greaterThan(0.5));
    expect((markTop - caretTop).abs(), lessThanOrEqualTo(0.5));

    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(fieldText(tester), '$firstLine\n${done}milk');
  });
}
