import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/home_shell.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/widgets/ad_banner.dart';

// T-261113-024: 할 일 탭 자리에 완료 탭. 메모와 할 일을 나누지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t = DateTime(2026, 11, 13, 9);
  Memo memo(String id, String content) =>
      Memo(id: id, content: content, createdAt: t, updatedAt: t);

  int currentTab(WidgetTester tester) => tester
      .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
      .currentIndex;

  Future<void> openDoneTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openMemoTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('아래 탭 4칸 순서와 완료 탭 전환 — 새 메모·+ 버튼 없음', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();

    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((i) => i.label), ['메모', '새메모', '완료', '설정']);

    await openDoneTab(tester);
    expect(currentTab(tester), 2);
    expect(find.byKey(const Key('done-empty')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(currentTab(tester), 3);
    expect(find.byType(AdBanner), findsOneWidget);
  });

  testWidgets('메모 체크 → 완료 탭에 보임 → 체크 풀기 → 메모 탭 원래 자리', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('a', '첫째 메모'),
        memo('b', '둘째 메모'),
        memo('c', '셋째 메모'),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('memo-done-check-b')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('둘째 메모'), findsNothing);
    expect((await MemoStorage.loadMemos())[1].doneAt, isNotNull);

    await openDoneTab(tester);
    expect(find.text('둘째 메모'), findsOneWidget);
    expect(find.text('완료 1개'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('done-check-b')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('둘째 메모'), findsNothing);
    expect(find.byKey(const Key('done-empty')), findsOneWidget);

    await openMemoTab(tester);
    final ys = [
      for (final title in ['첫째 메모', '둘째 메모', '셋째 메모'])
        tester.getTopLeft(find.text(title)).dy,
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue, reason: '$ys');
    expect((await MemoStorage.loadMemos()).map((m) => m.doneAt), [
      null,
      null,
      null,
    ]);
  });

  testWidgets('1초 안에 완료 탭으로 넘어가도 저장 뒤 완료 탭이 다시 읽는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a', '바로 넘김')]),
    });
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('memo-done-check-a')));
    await tester.pump(const Duration(milliseconds: 200));
    await openDoneTab(tester); // 아직 저장 전 — 빈 완료 탭
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('바로 넘김'), findsOneWidget);
  });
}
