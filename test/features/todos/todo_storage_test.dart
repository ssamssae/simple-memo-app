import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('저장 → 불러오기 왕복이 순서·필드를 지킨다', () async {
    SharedPreferences.setMockInitialValues({});
    final t0 = DateTime(2026, 11, 12, 22);
    final a = Todo.create(title: '양재 aT포레 웨딩홀', now: t0);
    final b = Todo.create(title: '토스페이먼츠 메일보고', note: '천원사주 진행', now: t0)
        .copyWith(done: true, doneAt: t0, updatedAt: t0);
    expect(await TodoStorage.save([a, b]), isTrue);
    final load = await TodoStorage.load();
    expect(load.corrupt, isFalse);
    expect(load.todos.map((t) => t.id), [a.id, b.id]);
    expect(load.todos[1].note, '천원사주 진행');
    expect(load.todos[1].hasNote, isTrue);
    expect(load.todos[1].done, isTrue);
    expect(load.todos[1].doneAt, t0);
  });

  test('저장값이 없으면 빈 목록, 깨지지 않음', () async {
    SharedPreferences.setMockInitialValues({});
    final load = await TodoStorage.load();
    expect(load.todos, isEmpty);
    expect(load.corrupt, isFalse);
  });

  test('깨진 저장값은 corrupt 로 알리고 throwOnError 면 던진다', () async {
    SharedPreferences.setMockInitialValues({'todos': '{not json'});
    final load = await TodoStorage.load();
    expect(load.todos, isEmpty);
    expect(load.corrupt, isTrue);
    expect(() => TodoStorage.load(throwOnError: true), throwsFormatException);
  });

  test('필수 필드가 빠진 항목은 FormatException', () {
    expect(() => Todo.fromJson({'id': 'x'}), throwsFormatException);
  });

  test('메모 키(memos)를 건드리지 않는다', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    await TodoStorage.save([Todo.create(title: 'a')]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('memos'), '[]');
  });
}
