// T-261113-024 — 옛 할 일 탭(todos 키)의 할 일을 처음 한 번 메모로 옮긴다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/todo_memo_migration.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final created = DateTime(2026, 11, 12, 22);
  final edited = DateTime(2026, 11, 12, 23);
  final doneAt = DateTime(2026, 11, 13, 8);

  final active = Todo(
    id: 'todo-active',
    title: '양재 aT포레 웨딩홀',
    note: '주차 확인',
    createdAt: created,
    updatedAt: edited,
  );
  final done = Todo(
    id: 'todo-done',
    title: '토스페이먼츠 메일보고',
    done: true,
    doneAt: doneAt,
    createdAt: created,
    updatedAt: edited,
  );
  final existing = Memo(
    id: 'memo-1',
    content: '원래 있던 메모',
    createdAt: created,
    updatedAt: created,
  );

  Future<void> seed({
    List<Memo>? memos,
    String? rawTodos,
    List<Todo>? todos,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (memos != null) 'memos': Memo.encodeList(memos),
      'todos': ?rawTodos,
    });
    if (todos != null) await TodoStorage.save(todos);
  }

  test('할 일·완료한 할 일이 메모 뒤에 붙고, todos 키는 그대로', () async {
    await seed(memos: [existing], todos: [active, done]);
    final prefs = await SharedPreferences.getInstance();
    final rawTodos = prefs.getString('todos');

    final memos = await MemoStorage.loadMemos();

    expect(memos.map((m) => m.id), ['memo-1', 'todo-active', 'todo-done']);
    final a = memos[1];
    expect(a.content, '양재 aT포레 웨딩홀\n주차 확인');
    expect(a.firstLine, '양재 aT포레 웨딩홀');
    expect(a.createdAt, created);
    expect(a.updatedAt, edited);
    expect(a.doneAt, isNull);
    expect(a.isFavorite, isFalse);
    final d = memos[2];
    expect(d.content, '토스페이먼츠 메일보고');
    expect(d.doneAt, doneAt);
    expect(prefs.getBool(TodoMemoMigration.flagKey), isTrue);
    expect(prefs.getString('todos'), rawTodos);
  });

  test('완료 시각이 없는 완료 할 일은 옮긴 시각으로 완료', () async {
    final before = DateTime.now();
    await seed(
      todos: [
        Todo(
          id: 'x',
          title: 'x',
          done: true,
          createdAt: created,
          updatedAt: created,
        ),
      ],
    );
    final memo = (await MemoStorage.loadMemos()).single;
    expect(memo.doneAt, isNotNull);
    expect(memo.doneAt!.isBefore(before), isFalse);
  });

  test('두 번 읽어도 한 번만 옮긴다', () async {
    await seed(memos: [existing], todos: [active, done]);
    await MemoStorage.loadMemos();
    final second = await MemoStorage.loadMemos();
    expect(second.length, 3);
  });

  test('깃발이 없어져도 같은 id 는 다시 붙이지 않는다', () async {
    await seed(memos: [existing], todos: [active, done]);
    await MemoStorage.loadMemos();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(TodoMemoMigration.flagKey);
    expect((await MemoStorage.loadMemos()).length, 3);
  });

  test('메모 탭·완료 탭이 동시에 읽어도 한 번만 옮긴다', () async {
    await seed(memos: [existing], todos: [active, done]);
    final results = await Future.wait([
      MemoStorage.loadMemos(),
      MemoStorage.loadMemos(),
    ]);
    expect(results.last.length, 3);
    expect((await MemoStorage.loadMemos()).length, 3);
  });

  test('옮긴 뒤 저장값의 할 일이 바뀌어도 다시 옮기지 않는다(깃발)', () async {
    await seed(todos: [active]);
    await MemoStorage.loadMemos();
    await TodoStorage.save([active, done]);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['todo-active']);
  });

  test('깨진 todos 값이면 아무것도 쓰지 않고 깃발도 세우지 않는다', () async {
    await seed(memos: [existing], rawTodos: '{broken');
    final memos = await MemoStorage.loadMemos();
    expect(memos.map((m) => m.id), ['memo-1']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(TodoMemoMigration.flagKey), isNull);
    expect(prefs.getString('todos'), '{broken');
  });

  test('메모 저장값이 깨졌으면 덮어쓰지 않는다', () async {
    SharedPreferences.setMockInitialValues({'memos': '{not a list'});
    await TodoStorage.save([active]);
    expect(await TodoMemoMigration.ensureMigrated(memosKey: 'memos'), 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('memos'), '{not a list');
    expect(prefs.getBool(TodoMemoMigration.flagKey), isNull);
  });

  test('할 일이 없으면(키 없음) 아무것도 쓰지 않는다', () async {
    await seed(memos: [existing]);
    await MemoStorage.loadMemos();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'memos'});
  });

  test('메모가 없는 사람(할 일만 씀)도 옮겨진다', () async {
    await seed(todos: [active]);
    expect((await MemoStorage.loadMemos()).single.id, 'todo-active');
  });
}
