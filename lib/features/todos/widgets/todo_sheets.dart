import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../utils/app_palette.dart';

/// + 빠른 입력. 엔터 = [onAdd] 후 칸을 비우고 다음 항목, 빈 제목 엔터 = 닫기.
class TodoQuickAddSheet extends StatefulWidget {
  const TodoQuickAddSheet({super.key, required this.onAdd});

  final void Function(String title, String note) onAdd;

  @override
  State<TodoQuickAddSheet> createState() => _TodoQuickAddSheetState();
}

class _TodoQuickAddSheetState extends State<TodoQuickAddSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    widget.onAdd(title, _note.text);
    _title.clear();
    _note.clear();
    _focus.requestFocus();
  }

  /// 시트를 바깥 누르기·끌어내리기로 닫아도 쓰던 제목은 저장한다.
  void _savePending() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    widget.onAdd(title, _note.text);
    _title.clear();
    _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _savePending();
      },
      child: _quickAddFields(strings),
    );
  }

  Widget _quickAddFields(AppStrings strings) {
    return _SheetFrame(
      children: [
        TextField(
          key: const Key('todo-title-field'),
          controller: _title,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: strings.todoTitleHint,
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        TextField(
          key: const Key('todo-note-field'),
          controller: _note,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: strings.todoNoteHint,
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }
}

/// 항목 편집. 저장 = (제목, 메모) 를 돌려준다. 닫으면 null.
class TodoEditSheet extends StatefulWidget {
  const TodoEditSheet({super.key, required this.title, required this.note});

  final String title;
  final String note;

  @override
  State<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<TodoEditSheet> {
  late final _title = TextEditingController(text: widget.title);
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);
    return _SheetFrame(
      children: [
        TextField(
          key: const Key('todo-title-field'),
          controller: _title,
          decoration: InputDecoration(
            hintText: strings.todoTitleHint,
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        TextField(
          key: const Key('todo-note-field'),
          controller: _note,
          minLines: 2,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: strings.todoNoteHint,
            border: InputBorder.none,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('todo-edit-save'),
            onPressed: () =>
                Navigator.of(context).pop((_title.text, _note.text)),
            child: Text(strings.save, style: TextStyle(color: palette.accent)),
          ),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
