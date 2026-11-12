import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../utils/app_palette.dart';
import '../models/todo.dart';
import '../services/todo_ops.dart';
import '../services/todo_storage.dart';
import '../widgets/todo_row.dart';
import '../widgets/todo_sheets.dart';

/// 할 일 탭(T-261112-052). Things 3 Inbox 처럼 목록 하나.
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({
    super.key,
    this.doneDelay = const Duration(seconds: 1),
  });

  /// 체크 뒤 완료 구역으로 빠지기까지 기다리는 시간.
  final Duration doneDelay;

  @override
  State<TodoListScreen> createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  List<Todo> _all = const [];
  bool _loading = true;
  bool _corrupt = false;
  bool _doneOpen = false;

  /// 체크했지만 아직 목록에 남아 있는 항목(타이머 대기 중).
  final Map<String, Timer> _settling = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    for (final t in _settling.values) {
      t.cancel();
    }
    super.dispose();
  }

  /// 설정 탭에서 복원했을 수 있어 탭을 다시 열 때 부른다.
  Future<void> reload() async {
    final load = await TodoStorage.load();
    if (!mounted) return;
    setState(() {
      _all = load.todos;
      _corrupt = load.corrupt;
      _loading = false;
    });
  }

  Future<void> _apply(List<Todo> next) async {
    setState(() => _all = next);
    if (_corrupt) return; // 깨진 원본을 덮어쓰지 않는다.
    await TodoStorage.save(next);
  }

  List<Todo> get _visibleActive =>
      _all.where((t) => !t.done || _settling.containsKey(t.id)).toList();

  List<Todo> get _completed => TodoOps.completed(
    _all.where((t) => !_settling.containsKey(t.id)).toList(),
  );

  void _toggle(Todo todo) {
    final now = DateTime.now();
    final pending = _settling.remove(todo.id);
    if (pending != null) {
      pending.cancel();
      _apply(TodoOps.setDone(_all, todo.id, false, now));
      return;
    }
    if (todo.done) {
      _apply(TodoOps.setDone(_all, todo.id, false, now));
      return;
    }
    _settling[todo.id] = Timer(widget.doneDelay, () {
      if (!mounted) return;
      setState(() => _settling.remove(todo.id));
    });
    _apply(TodoOps.setDone(_all, todo.id, true, now));
  }

  Future<void> _openQuickAdd() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TodoQuickAddSheet(
        onAdd: (title, note) {
          if (title.trim().isEmpty) return;
          _apply(TodoOps.add(_all, Todo.create(title: title, note: note)));
        },
      ),
    );
  }

  Future<void> _openEdit(Todo todo) async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TodoEditSheet(title: todo.title, note: todo.note),
    );
    if (result == null || !mounted) return;
    await _apply(
      TodoOps.update(
        _all,
        todo.id,
        title: result.$1,
        note: result.$2,
        now: DateTime.now(),
      ),
    );
  }

  void _delete(Todo todo) {
    final removed = TodoOps.remove(_all, todo.id);
    if (removed == null) return;
    _settling.remove(todo.id)?.cancel();
    _apply(removed.$1);
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(strings.todoDeleted),
        action: SnackBarAction(
          label: strings.undo,
          onPressed: () =>
              _apply(TodoOps.restore(_all, removed.$2, removed.$3)),
        ),
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    // 대기 중인 항목이 섞여 있으면 화면 순서와 저장 순서가 어긋나므로 먼저 정리한다.
    if (_settling.isNotEmpty) return;
    _apply(TodoOps.reorderActive(_all, oldIndex, newIndex));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);
    final active = _visibleActive;
    final completed = _completed;
    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: FloatingActionButton(
        key: const Key('todo-add'),
        tooltip: strings.todoAdd,
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        onPressed: _openQuickAdd,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Text(
                        strings.todoTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    if (_corrupt)
                      Padding(
                        key: const Key('todo-load-failed'),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          strings.todoLoadFailed,
                          style: TextStyle(color: palette.danger),
                        ),
                      ),
                    if (active.isEmpty && completed.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                        child: Text(
                          strings.todoEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ),
                  ],
                ),
                itemCount: active.length,
                onReorder: _reorder,
                itemBuilder: (context, i) {
                  final todo = active[i];
                  return Dismissible(
                    key: ValueKey('todo-${todo.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: palette.danger,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(
                        Icons.delete_outline,
                        color: palette.onAccent,
                      ),
                    ),
                    onDismissed: (_) => _delete(todo),
                    child: TodoRow(
                      todo: todo,
                      checked: todo.done,
                      onToggle: _toggle,
                      onTap: () => _openEdit(todo),
                    ),
                  );
                },
                footer: completed.isEmpty
                    ? null
                    : _DoneSection(
                        items: completed,
                        open: _doneOpen,
                        onHeader: () => setState(() => _doneOpen = !_doneOpen),
                        onToggle: _toggle,
                        onClear: () => _apply(TodoOps.clearCompleted(_all)),
                      ),
              ),
      ),
    );
  }
}

class _DoneSection extends StatelessWidget {
  const _DoneSection({
    required this.items,
    required this.open,
    required this.onHeader,
    required this.onToggle,
    required this.onClear,
  });

  final List<Todo> items;
  final bool open;
  final VoidCallback onHeader;
  final ValueChanged<Todo> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('todo-done-header'),
          onTap: onHeader,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  strings.todoDoneSection(items.length),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: palette.textSecondary,
                ),
                const Spacer(),
                if (open)
                  TextButton(
                    key: const Key('todo-clear-done'),
                    onPressed: onClear,
                    child: Text(
                      strings.todoClearDone,
                      style: TextStyle(color: palette.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (open)
          for (final t in items)
            TodoRow(todo: t, checked: true, dimmed: true, onToggle: onToggle),
      ],
    );
  }
}
