import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/widgets/todo_row.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('제목 한 줄·메모 있으면 문서 표시·칸 누르면 onToggle', (tester) async {
    Todo? toggled;
    final todo = Todo.create(title: '토스페이먼츠 메일보고', note: '천원사주');
    await tester.pumpWidget(
      host(
        TodoRow(todo: todo, checked: false, onToggle: (t) => toggled = t),
      ),
    );
    expect(find.text('토스페이먼츠 메일보고'), findsOneWidget);
    expect(find.byKey(ValueKey('todo-note-${todo.id}')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('todo-check-${todo.id}')));
    expect(toggled?.id, todo.id);
  });

  testWidgets('메모가 없으면 문서 표시가 없다', (tester) async {
    final todo = Todo.create(title: 'a');
    await tester.pumpWidget(
      host(TodoRow(todo: todo, checked: false, onToggle: (_) {})),
    );
    expect(find.byKey(ValueKey('todo-note-${todo.id}')), findsNothing);
  });

  testWidgets('체크 상태면 흰 체크 아이콘이 보이고, 줄바꿈 긴 제목도 한 줄', (tester) async {
    final todo = Todo.create(title: '${'아주 긴 제목 ' * 20}\n둘째 줄');
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: TodoRow(todo: todo, checked: true, onToggle: (_) {}),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    final text = tester.widget<Text>(
      find.byKey(ValueKey('todo-title-${todo.id}')),
    );
    expect(text.maxLines, 1);
    expect(text.data!.contains('\n'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
