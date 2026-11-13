import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/memo.dart';
import '../../todos/models/todo.dart';
import '../../todos/services/todo_storage.dart';

/// 옛 「할 일」 탭(T-261112-052)의 할 일을 메모로 옮긴다 (T-261113-024).
///
/// 메모와 할 일을 나누지 않기로 했다(대종님 2026-11-13). 할 일 하나 = 메모 하나.
/// - 내용 = 제목, 메모(note)가 있으면 줄을 바꿔 붙인다.
/// - id·만든 시각·고친 시각은 할 일 것을 그대로 쓴다. 같은 할 일은 늘 같은 메모 id 가 되어
///   두 번 옮기거나 옛 백업을 다시 가져와도 겹치지 않는다(id 로 합쳐진다).
/// - 완료한 할 일은 doneAt(없으면 지금)을 달아 완료 탭으로 간다.
/// - `todos` 키는 지우지 않는다(되돌릴 수 있게). 옮긴 뒤 [flagKey] 를 세워 다시 옮기지 않는다.
class TodoMemoMigration {
  TodoMemoMigration._();

  static const flagKey = 'todos_migrated_to_memos_v1';

  /// 할 일 목록을 메모로 바꾼다. [existingIds] 에 이미 있는 id 는 건너뛴다.
  static List<Memo> memosFromTodos(
    List<Todo> todos, {
    Set<String> existingIds = const {},
    required DateTime now,
  }) {
    final seen = {...existingIds};
    return [
      for (final t in todos)
        if (seen.add(t.id))
          Memo(
            id: t.id,
            content: t.note.trim().isEmpty ? t.title : '${t.title}\n${t.note}',
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            doneAt: t.done ? (t.doneAt ?? now) : null,
          ),
    ];
  }

  static Future<int>? _running;

  /// 한 번만 옮긴다. 동시에 불려도(메모 탭·완료 탭이 함께 읽음) 한 번만 돈다.
  /// 옮긴 할 일 수를 돌려준다. 읽지 못하는 값이 있으면 아무것도 쓰지 않고 0
  /// (깃발도 세우지 않아 다음에 다시 시도한다).
  static Future<int> ensureMigrated({required String memosKey}) =>
      _running ??= _run(memosKey).whenComplete(() => _running = null);

  static Future<int> _run(String memosKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flagKey) == true) return 0;
    final rawTodos = prefs.getString(TodoStorage.key);
    if (rawTodos == null || rawTodos.isEmpty) return 0;
    final List<Todo> todos;
    final List<Memo> memos;
    try {
      todos = Todo.decodeList(rawTodos);
      final rawMemos = prefs.getString(memosKey);
      if (rawMemos == null || rawMemos.isEmpty) {
        memos = [];
      } else {
        final decoded = jsonDecode(rawMemos);
        if (decoded is! List ||
            decoded.any((row) => row is! Map<String, dynamic>)) {
          return 0; // 메모 저장값이 깨졌다 — 덮어쓰지 않는다.
        }
        memos = Memo.decodeList(rawMemos);
      }
    } catch (e) {
      debugPrint('[TodoMemoMigration] skip: $e');
      return 0;
    }
    final added = memosFromTodos(
      todos,
      existingIds: {for (final m in memos) m.id},
      now: DateTime.now(),
    );
    if (added.isNotEmpty &&
        !await prefs.setString(
          memosKey,
          Memo.encodeList([...memos, ...added]),
        )) {
      return 0;
    }
    await prefs.setBool(flagKey, true);
    return added.length;
  }
}
