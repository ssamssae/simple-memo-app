// T-261113-024 — 체크 칸 달린 메모 목록과 완료 탭이 큰 글씨·가로에서 넘치지 않는다.
// 옛 할 일 화면 시험(todo_layout_test, T-261112-052·T-261113-023)과 같은 틀.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/screens/done_memos_screen.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';

final _t = DateTime(2026, 11, 13, 9);

List<Memo> _memos() => [
  Memo(
    id: 'fav',
    content: '자비스 호출 후 어떤키워드 말해야 어떤노드 ' * 4,
    isFavorite: true,
    createdAt: _t,
    updatedAt: _t,
  ),
  Memo(
    id: 'open',
    content: '털미우스 맥미니 아테나 세팅 나머지삭제\n☑ 하나\n☐ 둘',
    createdAt: _t,
    updatedAt: _t,
  ),
  Memo(
    id: 'done1',
    content: '토스페이먼츠 메일보고 천원사주 진행 상황 정리해서 보내기 ' * 3,
    createdAt: _t,
    updatedAt: _t,
    doneAt: DateTime(2025, 12, 31, 23),
  ),
  Memo(
    id: 'done2',
    content: '양재 aT포레',
    createdAt: _t,
    updatedAt: _t,
    doneAt: DateTime(2026, 11, 12),
  ),
];

Future<void> _pumpAt(
  WidgetTester tester,
  Widget home,
  Size size,
  double scale, {
  List<Memo>? memos,
}) async {
  SharedPreferences.setMockInitialValues({
    'memos': Memo.encodeList(memos ?? _memos()),
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: home,
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
    testWidgets('$name 화면·글자 2배 — 메모 목록 체크 칸 넘침 없음', (tester) async {
      await _pumpAt(tester, const MemoListScreen(), size, 2.0);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('memo-done-check-open')),
        findsOneWidget,
      );
      // 체크해서 취소선이 그려진 상태도 넘치지 않는다.
      await tester.tap(find.byKey(const ValueKey('memo-done-check-open')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name 화면·글자 2배 — 완료 탭 넘침 없음', (tester) async {
      await _pumpAt(tester, const DoneMemosScreen(), size, 2.0);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('done-header')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('done-check-done2')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name 화면·글자 2배 — 빈 완료 탭 넘침 없음', (tester) async {
      await _pumpAt(tester, const DoneMemosScreen(), size, 2.0, memos: []);
      expect(find.byKey(const Key('done-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // T-261113-028 — 「편집」 선택 모드(동그라미·전체선택·선택 비우기 (N)).
    for (final lang in ['ko', 'en']) {
      testWidgets('$name 화면·글자 2배 — 완료 탭 선택 모드 넘침 없음 ($lang)', (
        tester,
      ) async {
        SettingsService.instance.languageCode.value = lang;
        addTearDown(() => SettingsService.instance.languageCode.value = 'ko');
        await _pumpAt(tester, const DoneMemosScreen(), size, 2.0);
        await tester.tap(find.byKey(const Key('done-edit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('done-select-done2')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('done-row-done2')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('done-select-all')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('done-clear-selected')),
          findsOneWidget,
        );
      });
    }
  }

  // T-261113-023 과 같은 규칙: 「완료 N개」 머리줄 글자가 줄 위아래 가운데에 온다.
  for (final scale in [1.0, 2.0]) {
    testWidgets('완료 머리줄 글자·완료 비우기가 위아래 가운데 (글자 $scale배)', (tester) async {
      await _pumpAt(
        tester,
        const DoneMemosScreen(),
        const Size(400, 800),
        scale,
      );
      final header = find.byKey(const Key('done-header'));
      final headerCenter = tester.getCenter(header).dy;
      final label = find
          .descendant(of: header, matching: find.byType(Text))
          .first;
      expect(tester.getCenter(label).dy, closeTo(headerCenter, 0.5));
      expect(
        tester.getCenter(find.byKey(const Key('done-clear'))).dy,
        closeTo(headerCenter, 0.5),
      );
    });

    testWidgets('선택 모드 머리줄 글자·선택 비우기도 위아래 가운데 (글자 $scale배)', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const DoneMemosScreen(),
        const Size(400, 800),
        scale,
      );
      await tester.tap(find.byKey(const Key('done-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('done-row-done2')));
      await tester.pump();
      final header = find.byKey(const Key('done-header'));
      final headerCenter = tester.getCenter(header).dy;
      final label = find
          .descendant(of: header, matching: find.byType(Text))
          .first;
      expect(tester.getCenter(label).dy, closeTo(headerCenter, 0.5));
      expect(
        tester.getCenter(find.byKey(const Key('done-clear-selected'))).dy,
        closeTo(headerCenter, 0.5),
      );
    });
  }

  testWidgets('체크 칸 네모는 줄 위아래 가운데, 누르는 범위 44', (tester) async {
    await _pumpAt(tester, const MemoListScreen(), const Size(400, 800), 1.0);
    final check = find.byKey(const ValueKey('memo-done-check-open'));
    expect(tester.getSize(check), const Size(44, 44));
    final title = find.text('털미우스 맥미니 아테나 세팅 나머지삭제');
    expect(
      tester.getCenter(check).dy,
      closeTo(tester.getCenter(title).dy, 0.5),
    );
  });
}
