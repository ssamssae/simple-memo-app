import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/screens/todo_list_screen.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';

Future<void> open(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: TodoListScreen()));
  await tester.pumpAndSettle();
}

Future<void> seed(List<Todo> todos) async {
  SharedPreferences.setMockInitialValues({});
  await TodoStorage.save(todos);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('빈 목록 안내와 + 버튼', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    expect(find.text('할 일'), findsOneWidget);
    expect(find.textContaining('아직 할 일이 없어요'), findsOneWidget);
    expect(find.byKey(const Key('todo-add')), findsOneWidget);
  });

  testWidgets('+ → 제목 입력 → 엔터로 연속 두 개 추가, 빈 칸 엔터면 닫힘', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    await tester.tap(find.byKey(const Key('todo-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-title-field')),
      '양재 aT포레',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('todo-title-field')), '왕새우치킨');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-title-field')), findsNothing);
    final saved = (await TodoStorage.load()).todos;
    expect(saved.map((t) => t.title), ['양재 aT포레', '왕새우치킨']);
  });

  testWidgets('공백 제목은 저장하지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    await tester.tap(find.byKey(const Key('todo-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('todo-title-field')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await TodoStorage.load()).todos, isEmpty);
  });

  testWidgets('체크하면 1초 동안 그 자리, 그 뒤 완료 구역으로', (tester) async {
    final a = Todo.create(title: 'a');
    await seed([a]);
    await open(tester);
    await tester.tap(find.byKey(ValueKey('todo-check-${a.id}')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('a'), findsOneWidget);
    expect(find.byKey(const Key('todo-done-header')), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing); // 접힌 완료 구역
    expect(find.text('완료 1개'), findsOneWidget);
    expect((await TodoStorage.load()).todos.single.done, isTrue);
  });

  testWidgets('1초 안에 다시 누르면 목록에 남는다', (tester) async {
    final a = Todo.create(title: 'a');
    await seed([a]);
    await open(tester);
    await tester.tap(find.byKey(ValueKey('todo-check-${a.id}')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(ValueKey('todo-check-${a.id}')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.byKey(const Key('todo-done-header')), findsNothing);
    expect((await TodoStorage.load()).todos.single.done, isFalse);
  });

  testWidgets('완료 구역 펼쳐 누르면 되돌림, 완료 비우기', (tester) async {
    final a = Todo.create(
      title: 'a',
    ).copyWith(done: true, doneAt: DateTime(2026, 11, 12));
    final b = Todo.create(
      title: 'b',
    ).copyWith(done: true, doneAt: DateTime(2026, 11, 11));
    await seed([a, b]);
    await open(tester);
    await tester.tap(find.byKey(const Key('todo-done-header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('todo-check-${a.id}')));
    await tester.pumpAndSettle();
    expect(find.text('완료 1개'), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo-clear-done')));
    await tester.pumpAndSettle();
    final saved = (await TodoStorage.load()).todos;
    expect(saved.map((t) => t.title), ['a']);
    expect(saved.single.done, isFalse);
  });

  testWidgets('밀어서 지우고 되돌리기', (tester) async {
    final a = Todo.create(title: 'a'), b = Todo.create(title: 'b');
    await seed([a, b]);
    await open(tester);
    await tester.drag(find.text('a'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect((await TodoStorage.load()).todos.map((t) => t.title), ['b']);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect((await TodoStorage.load()).todos.map((t) => t.title), ['a', 'b']);
  });

  testWidgets('항목 누르면 편집 시트, 저장하면 제목·메모 바뀜', (tester) async {
    final a = Todo.create(title: 'a');
    await seed([a]);
    await open(tester);
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('todo-title-field')), 'a2');
    await tester.enterText(find.byKey(const Key('todo-note-field')), '메모');
    await tester.tap(find.byKey(const Key('todo-edit-save')));
    await tester.pumpAndSettle();
    final saved = (await TodoStorage.load()).todos.single;
    expect(saved.title, 'a2');
    expect(saved.note, '메모');
    expect(find.byKey(ValueKey('todo-note-${a.id}')), findsOneWidget);
  });

  testWidgets('길게 눌러 끌면 순서가 바뀐다', (tester) async {
    final a = Todo.create(title: 'a'), b = Todo.create(title: 'b');
    await seed([a, b]);
    await open(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('a')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect((await TodoStorage.load()).todos.map((t) => t.title), ['b', 'a']);
  });

  testWidgets('되돌리기는 그사이 바뀐 저장값을 덮어쓰지 않는다', (tester) async {
    final a = Todo.create(title: 'a'), b = Todo.create(title: 'b');
    await seed([a, b]);
    await open(tester);
    await tester.drag(find.text('a'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // 설정 탭에서 백업을 복원해 할 일이 늘어난 상황.
    await TodoStorage.save([b, Todo.create(title: 'c')]);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    final titles = (await TodoStorage.load()).todos.map((t) => t.title);
    expect(titles.toSet(), {'a', 'b', 'c'});
    expect(titles.length, 3);
  });

  testWidgets('빠른 입력 시트를 그냥 닫아도 쓴 제목은 저장한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    await tester.tap(find.byKey(const Key('todo-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('todo-title-field')),
      '닫아도 남김',
    );
    await tester.tapAt(const Offset(20, 20)); // 시트 바깥
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-title-field')), findsNothing);
    expect((await TodoStorage.load()).todos.single.title, '닫아도 남김');
  });

  testWidgets('완료 구역 줄을 눌러도 되돌린다', (tester) async {
    final a = Todo.create(
      title: 'a',
    ).copyWith(done: true, doneAt: DateTime(2026, 11, 12));
    await seed([a]);
    await open(tester);
    await tester.tap(find.byKey(const Key('todo-done-header')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect((await TodoStorage.load()).todos.single.done, isFalse);
  });

  testWidgets('깨진 저장값은 덮어쓰지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({'todos': '{broken'});
    await open(tester);
    expect(find.byKey(const Key('todo-load-failed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('todo-title-field')), 'x');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('todos'), '{broken');
  });
}
