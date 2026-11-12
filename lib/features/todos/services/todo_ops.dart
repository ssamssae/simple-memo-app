import '../models/todo.dart';

/// 할 일 목록의 순수 연산. 입력 목록을 바꾸지 않고 새 목록을 돌려준다.
class TodoOps {
  TodoOps._();

  static List<Todo> active(List<Todo> all) =>
      all.where((t) => !t.done).toList();

  static List<Todo> completed(List<Todo> all) {
    final list = all.where((t) => t.done).toList();
    list.sort(
      (a, b) => (b.doneAt ?? b.updatedAt).compareTo(a.doneAt ?? a.updatedAt),
    );
    return list;
  }

  static List<Todo> add(List<Todo> all, Todo todo) => [...all, todo];

  static List<Todo> setDone(
    List<Todo> all,
    String id,
    bool done,
    DateTime now,
  ) {
    return [
      for (final t in all)
        if (t.id != id)
          t
        else if (done)
          t.copyWith(done: true, doneAt: now, updatedAt: now)
        else
          t.copyWith(done: false, clearDoneAt: true, updatedAt: now),
    ];
  }

  static List<Todo> update(
    List<Todo> all,
    String id, {
    required String title,
    required String note,
    required DateTime now,
  }) {
    final trimmed = title.trim();
    return [
      for (final t in all)
        if (t.id == id)
          t.copyWith(
            title: trimmed.isEmpty ? t.title : trimmed,
            note: note,
            updatedAt: now,
          )
        else
          t,
    ];
  }

  static (List<Todo>, int, Todo)? remove(List<Todo> all, String id) {
    final index = all.indexWhere((t) => t.id == id);
    if (index < 0) return null;
    final list = [...all]..removeAt(index);
    return (list, index, all[index]);
  }

  static List<Todo> restore(List<Todo> all, int index, Todo todo) {
    if (all.any((t) => t.id == todo.id)) return all;
    final at = index.clamp(0, all.length);
    return [...all]..insert(at, todo);
  }

  static List<Todo> reorderActive(List<Todo> all, int oldIndex, int newIndex) {
    final act = active(all);
    if (oldIndex < 0 || oldIndex >= act.length) return all;
    var to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    to = to.clamp(0, act.length - 1);
    final moved = act.removeAt(oldIndex);
    act.insert(to, moved);
    return [...act, ...all.where((t) => t.done)];
  }

  static List<Todo> clearCompleted(List<Todo> all) => active(all);

  static List<Todo> merge(List<Todo> existing, List<Todo> incoming) {
    final byId = {for (final t in incoming) t.id: t};
    final result = <Todo>[];
    for (final t in existing) {
      final inc = byId.remove(t.id);
      result.add(inc != null && inc.updatedAt.isAfter(t.updatedAt) ? inc : t);
    }
    for (final t in incoming) {
      if (byId.containsKey(t.id)) result.add(t);
    }
    return result;
  }
}
