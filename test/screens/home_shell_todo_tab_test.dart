import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';
import 'package:simple_memo_app/screens/home_shell.dart';
import 'package:simple_memo_app/widgets/ad_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('아래 탭 4칸 순서와 할 일 탭 전환', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();

    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((i) => i.label), ['메모', '새메모', '할 일', '설정']);
    expect(find.byKey(const Key('todo-add')), findsNothing);

    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-add')), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      3,
    );
    expect(find.byType(AdBanner), findsOneWidget);
  });

  testWidgets('할 일을 지운 뒤 뜨는 알림이 + 버튼을 가리지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([Todo.create(title: 'a'), Todo.create(title: 'b')]);
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.text('a'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // 눈에 보이는 알림 상자(Material). SnackBar 위젯 상자는 바깥 여백까지 가로 전체다.
    final bar = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    final fab = tester.getRect(find.byKey(const Key('todo-add')));
    expect(bar.overlaps(fab), isFalse, reason: 'snackbar $bar fab $fab');
  });
}
