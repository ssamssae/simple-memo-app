import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/screens/todo_list_screen.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';

Future<void> pumpAt(WidgetTester tester, Size size, double scale) async {
  SharedPreferences.setMockInitialValues({});
  await TodoStorage.save([
    Todo.create(title: '자비스 호출 후 어떤키워드 말해야 어떤노드 ' * 4, note: 'n'),
    Todo.create(title: '털미우스 맥미니 아테나 세팅 나머지삭제'),
    Todo.create(
      title: 'done',
    ).copyWith(done: true, doneAt: DateTime(2026, 11, 12)),
  ]);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: const TodoListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, size) in [
    ('세로', const Size(400, 800)),
    ('가로', const Size(900, 400)),
  ]) {
    testWidgets('$name 화면·글자 2배에서 넘침 없음', (tester) async {
      await pumpAt(tester, size, 2.0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('todo-done-header')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
