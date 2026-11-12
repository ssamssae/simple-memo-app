import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_ops.dart';

Todo t(String title, {DateTime? at}) =>
    Todo.create(title: title, now: at ?? DateTime(2026, 11, 12, 9));

void main() {
  final now = DateTime(2026, 11, 12, 10);

  test('add 는 끝에 붙이고 active 는 저장 순서를 지킨다', () {
    final a = t('a'), b = t('b');
    final all = TodoOps.add(TodoOps.add([], a), b);
    expect(TodoOps.active(all).map((x) => x.title), ['a', 'b']);
  });

  test('setDone 은 done·doneAt·updatedAt 을 바꾸고 되돌리면 doneAt 을 지운다', () {
    final a = t('a');
    var all = TodoOps.setDone([a], a.id, true, now);
    expect(all.single.done, isTrue);
    expect(all.single.doneAt, now);
    expect(all.single.updatedAt, now);
    all = TodoOps.setDone(all, a.id, false, now);
    expect(all.single.done, isFalse);
    expect(all.single.doneAt, isNull);
  });

  test('completed 는 최근 완료가 위', () {
    final a = t('a'), b = t('b');
    var all = TodoOps.setDone([a, b], a.id, true, DateTime(2026, 11, 12, 10));
    all = TodoOps.setDone(all, b.id, true, DateTime(2026, 11, 12, 11));
    expect(TodoOps.completed(all).map((x) => x.title), ['b', 'a']);
  });

  test('restore 는 한 번만 끼우고 위치를 자른다', () {
    final a = t('a'), b = t('b');
    final removed = TodoOps.remove([a, b], a.id)!;
    expect(removed.$2, 0);
    var all = TodoOps.restore(removed.$1, 99, removed.$3);
    expect(all.map((x) => x.title), ['b', 'a']);
    all = TodoOps.restore(all, 0, removed.$3);
    expect(all.where((x) => x.id == a.id).length, 1);
  });

  test('remove 는 없는 id 면 null', () {
    expect(TodoOps.remove([t('a')], 'nope'), isNull);
  });

  test('reorderActive 는 ReorderableListView 규칙(newIndex>oldIndex 면 -1)을 따른다', () {
    final a = t('a'), b = t('b'), c = t('c');
    final all = TodoOps.reorderActive([a, b, c], 0, 3);
    expect(TodoOps.active(all).map((x) => x.title), ['b', 'c', 'a']);
  });

  test('reorderActive 는 완료 항목을 잃지 않는다', () {
    final a = t('a'), b = t('b'), c = t('c');
    var all = TodoOps.setDone([a, b, c], b.id, true, now);
    all = TodoOps.reorderActive(all, 1, 0);
    expect(TodoOps.active(all).map((x) => x.title), ['c', 'a']);
    expect(TodoOps.completed(all).single.title, 'b');
  });

  test('clearCompleted 는 완료만 지운다', () {
    final a = t('a'), b = t('b');
    final all = TodoOps.setDone([a, b], a.id, true, now);
    expect(TodoOps.clearCompleted(all).map((x) => x.title), ['b']);
  });

  test('update 는 제목을 다듬고 공백 제목이면 그대로 둔다', () {
    final a = t('a');
    var all = TodoOps.update([a], a.id, title: '  새 제목 ', note: 'n', now: now);
    expect(all.single.title, '새 제목');
    expect(all.single.note, 'n');
    all = TodoOps.update(all, a.id, title: '   ', note: 'x', now: now);
    expect(all.single.title, '새 제목');
  });

  test('merge 는 id 로 합치고 더 새 updatedAt 이 이긴다, 새 항목은 끝에', () {
    final a = t('a', at: DateTime(2026, 11, 1));
    final aNew = a.copyWith(title: 'a2', updatedAt: DateTime(2026, 11, 2));
    final aOld = a.copyWith(title: 'a0', updatedAt: DateTime(2026, 10, 1));
    final c = t('c');
    expect(TodoOps.merge([a], [aNew, c]).map((x) => x.title), ['a2', 'c']);
    expect(TodoOps.merge([a], [aOld]).single.title, 'a');
  });
}
