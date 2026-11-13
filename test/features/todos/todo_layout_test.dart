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

  // T-261113-023: 「완료 N개」 머리줄 글자가 줄 위아래 가운데에 온다(대종님 「완료가 가운데 없네」).
  for (final scale in [1.0, 2.0]) {
    testWidgets('완료 머리줄 글자·완료 비우기가 위아래 가운데 (글자 $scale배)', (
      tester,
    ) async {
      await pumpAt(tester, const Size(400, 800), scale);
      final header = find.byKey(const Key('todo-done-header'));
      await tester.tap(header);
      await tester.pumpAndSettle();
      final headerCenter = tester.getCenter(header).dy;
      final label = find
          .descendant(of: header, matching: find.byType(Text))
          .first;
      expect(tester.getCenter(label).dy, closeTo(headerCenter, 0.5));
      expect(
        tester.getCenter(find.byKey(const Key('todo-clear-done'))).dy,
        closeTo(headerCenter, 0.5),
      );
    });
  }
}
