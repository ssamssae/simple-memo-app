import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

/// T-261022-006 r4 — 열어 보기만 한 메모는 고친 것으로 다루지 않는다.
/// 취소 확인창을 띄우지 않고, 수정 시각(검색 순위·백업 병합 기준)을 바꾸지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final strings = AppStrings.fromCode('ko');
  final t = DateTime(2026, 10, 1, 9);

  Memo memo(String content) =>
      Memo(id: 'm1', content: content, createdAt: t, updatedAt: t);

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Memo memo,
    required ValueChanged<Memo> onSave,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => MemoEditScreen(memo: memo, onSave: onSave),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('열어 보기만 한 메모는 취소해도 확인창 없이 닫힌다', (tester) async {
    var saves = 0;
    await pumpEditor(tester, memo: memo('장보기\n우유'), onSave: (_) => saves++);

    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();

    expect(find.text(strings.discardConfirmTitle), findsNothing);
    expect(find.byType(MemoEditScreen), findsNothing);
    expect(saves, 0);
  });

  testWidgets('고친 메모를 취소하면 확인창이 뜨고 계속 수정할 수 있다', (tester) async {
    await pumpEditor(tester, memo: memo('장보기\n우유'), onSave: (_) {});
    await tester.enterText(find.byType(TextField), '장보기\n우유\n계란');

    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(find.text(strings.discardConfirmTitle), findsOneWidget);

    await tester.tap(find.text(strings.keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(MemoEditScreen), findsOneWidget);
  });

  for (final exit in ['뒤로', '저장', '시스템 뒤로']) {
    testWidgets('열어 보기만 한 메모는 「$exit」 경로로 나가도 저장하지 않는다', (tester) async {
      var saves = 0;
      await pumpEditor(tester, memo: memo('장보기\n우유'), onSave: (_) => saves++);

      if (exit == '시스템 뒤로') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(exit == '뒤로' ? strings.back : strings.save));
      }
      await tester.pumpAndSettle();

      expect(find.byType(MemoEditScreen), findsNothing);
      expect(saves, 0);
    });
  }

  testWidgets('고친 뒤 뒤로 가면 새 내용과 새 수정 시각으로 저장한다', (tester) async {
    Memo? saved;
    await pumpEditor(tester, memo: memo('장보기\n우유'), onSave: (m) => saved = m);
    await tester.enterText(find.byType(TextField), '장보기\n우유\n계란');

    await tester.tap(find.text(strings.back));
    await tester.pumpAndSettle();

    expect(saved?.content, '장보기\n우유\n계란');
    expect(saved!.updatedAt.isAfter(t), isTrue);
  });

  testWidgets('메모 목록에서 열어 보기만 하고 돌아오면 저장된 수정 시각이 그대로다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('장보기\n우유')]),
    });
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('장보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoEditScreen), findsOneWidget);
    await tester.tap(find.text(strings.back));
    await tester.pumpAndSettle();

    expect((await MemoStorage.loadMemos()).single.updatedAt, t);
  });
}
