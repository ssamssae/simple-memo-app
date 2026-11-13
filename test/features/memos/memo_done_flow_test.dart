// T-261113-024 — 메모 왼쪽 체크 칸과 완료 탭.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/screens/done_memos_screen.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t = DateTime(2026, 11, 13, 9);

  Memo memo(
    String id,
    String content, {
    bool fav = false,
    DateTime? doneAt,
    DateTime? deletedAt,
  }) => Memo(
    id: id,
    content: content,
    createdAt: t,
    updatedAt: t,
    isFavorite: fav,
    doneAt: doneAt,
    deletedAt: deletedAt,
  );

  void seed(List<Memo> memos) =>
      SharedPreferences.setMockInitialValues({'memos': Memo.encodeList(memos)});

  Future<List<Memo>> stored() => MemoStorage.loadMemos();

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  Finder memoCheck(String id) => find.byKey(ValueKey('memo-done-check-$id'));
  Finder doneCheck(String id) => find.byKey(ValueKey('done-check-$id'));

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDone(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DoneMemosScreen()));
    await tester.pumpAndSettle();
  }

  group('메모 목록 체크 칸', () {
    testWidgets('누르면 바로 체크·취소선·진동, 1초 뒤 접혀 사라지고 doneAt 저장', (tester) async {
      seed([memo('a', '장보기'), memo('b', '운동')]);
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpList(tester);
      expect(
        styleOf(tester, '장보기').decoration,
        isNot(TextDecoration.lineThrough),
      );

      await tester.tap(memoCheck('a'));
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(styleOf(tester, '장보기').decoration, TextDecoration.lineThrough);
      expect(
        find.descendant(of: memoCheck('a'), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('장보기'), findsOneWidget);
      expect((await stored()).first.doneAt, isNull);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('장보기'), findsNothing);
      expect(find.text('운동'), findsOneWidget);
      final saved = await stored();
      expect(saved.map((m) => m.id), ['a', 'b']); // 배열 순서 그대로
      expect(saved.first.doneAt, isNotNull);
      expect(saved.first.updatedAt, t);
    });

    testWidgets('1초 안에 다시 누르면 목록에 남고 저장하지 않는다', (tester) async {
      seed([memo('a', '장보기')]);
      await pumpList(tester);
      await tester.tap(memoCheck('a'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(memoCheck('a'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('장보기'), findsOneWidget);
      expect(
        styleOf(tester, '장보기').decoration,
        isNot(TextDecoration.lineThrough),
      );
      expect((await stored()).single.doneAt, isNull);
    });

    testWidgets('체크 칸은 44×44 이상 · 줄 누르기는 그대로 편집 열기', (tester) async {
      seed([memo('a', '장보기')]);
      await pumpList(tester);
      final size = tester.getSize(memoCheck('a'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('장보기'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoEditScreen), findsOneWidget);
    });

    testWidgets('완료 메모는 즐겨찾기·일반 묶음 모두에서 빠진다', (tester) async {
      seed([
        memo('f1', '즐겨찾기 열린', fav: true),
        memo('f2', '즐겨찾기 끝난', fav: true, doneAt: t),
        memo('n1', '일반 열린'),
        memo('n2', '일반 끝난', doneAt: t),
      ]);
      await pumpList(tester);
      expect(find.text('즐겨찾기 열린'), findsOneWidget);
      expect(find.text('일반 열린'), findsOneWidget);
      expect(find.text('즐겨찾기 끝난'), findsNothing);
      expect(find.text('일반 끝난'), findsNothing);
    });

    testWidgets('모두 완료면 빈 목록 안내', (tester) async {
      seed([memo('a', '끝', doneAt: t)]);
      await pumpList(tester);
      expect(find.text('끝'), findsNothing);
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    });

    testWidgets('편집 모드에서는 체크 칸 대신 선택 표시', (tester) async {
      seed([memo('a', '장보기')]);
      await pumpList(tester);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(memoCheck('a'), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('전체 선택은 보이는 메모만 고른다', (tester) async {
      seed([memo('a', '열린'), memo('b', '끝난', doneAt: t)]);
      await pumpList(tester);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제 (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();
      final saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNotNull);
      expect(saved['b']!.deletedAt, isNull);
    });
  });

  group('완료 탭', () {
    testWidgets('최근 완료가 위 · 완료 N개 · 휴지통 메모 제외 · 체크·취소선', (tester) async {
      seed([
        memo('old', '어제 끝냄', doneAt: DateTime(2026, 11, 12, 20)),
        memo('open', '아직'),
        memo('new', '방금 끝냄', doneAt: DateTime(2026, 11, 13, 21)),
        memo('gone', '지운 것', doneAt: t, deletedAt: t),
      ]);
      await pumpDone(tester);
      expect(find.text('완료'), findsOneWidget);
      expect(find.text('완료 2개'), findsOneWidget);
      expect(find.text('아직'), findsNothing);
      expect(find.text('지운 것'), findsNothing);
      expect(
        tester.getTopLeft(find.text('방금 끝냄')).dy,
        lessThan(tester.getTopLeft(find.text('어제 끝냄')).dy),
      );
      expect(styleOf(tester, '방금 끝냄').decoration, TextDecoration.lineThrough);
      expect(
        find.descendant(
          of: doneCheck('new'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('체크를 풀면 바로 빈 칸, 1초 뒤 접혀 메모 목록으로', (tester) async {
      seed([memo('a', '끝낸 일', doneAt: t), memo('b', '다른 일', doneAt: t)]);
      await pumpDone(tester);
      await tester.tap(doneCheck('a'));
      await tester.pump();
      expect(
        styleOf(tester, '끝낸 일').decoration,
        isNot(TextDecoration.lineThrough),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('끝낸 일'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('끝낸 일'), findsNothing);
      expect(find.text('완료 1개'), findsOneWidget);
      final saved = await stored();
      expect(saved.map((m) => m.id), ['a', 'b']);
      expect(saved[0].doneAt, isNull);
      expect(saved[1].doneAt, t);
    });

    testWidgets('완료 비우기 → 휴지통(완료 표시 유지) → 실행 취소로 돌아옴', (tester) async {
      seed([
        memo('a', '하나', doneAt: t),
        memo('b', '둘', doneAt: t),
        memo('c', '열린'),
      ]);
      await pumpDone(tester);
      await tester.tap(find.byKey(const Key('done-clear')));
      await tester.pumpAndSettle();
      expect(find.text('완료 2개를 휴지통으로 옮겼어요'), findsOneWidget);
      expect(find.byKey(const Key('done-empty')), findsOneWidget);
      var saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNotNull);
      expect(saved['a']!.doneAt, t);
      expect(saved['b']!.deletedAt, isNotNull);
      expect(saved['c']!.deletedAt, isNull);

      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(find.text('하나'), findsOneWidget);
      expect(find.text('둘'), findsOneWidget);
      saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNull);
      expect(saved['b']!.deletedAt, isNull);
    });

    testWidgets('체크를 푸는 중(1초 대기)인 메모는 완료 비우기에서 남긴다', (tester) async {
      seed([memo('a', '하나', doneAt: t), memo('b', '둘', doneAt: t)]);
      await pumpDone(tester);
      await tester.tap(doneCheck('a'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('done-clear')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNull);
      expect(saved['a']!.doneAt, isNull);
      expect(saved['b']!.deletedAt, isNotNull);
    });

    testWidgets('줄을 누르면 편집, 고쳐도 완료 표시는 그대로', (tester) async {
      final doneAt = DateTime(2026, 11, 13, 20);
      seed([memo('a', '끝낸 일', doneAt: doneAt)]);
      await pumpDone(tester);
      await tester.tap(find.text('끝낸 일'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoEditScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), '끝낸 일 고침');
      await tester.tap(find.text('뒤로'));
      await tester.pumpAndSettle();
      final saved = (await stored()).single;
      expect(saved.content, '끝낸 일 고침');
      expect(saved.doneAt, doneAt);
      expect(find.text('끝낸 일 고침'), findsOneWidget);
    });

    testWidgets('영어 로케일 — 한글 0', (tester) async {
      SettingsService.instance.languageCode.value = 'en';
      addTearDown(() => SettingsService.instance.languageCode.value = 'ko');
      seed([memo('a', 'shipped', doneAt: DateTime(2026, 11, 13))]);
      await pumpDone(tester);
      final han = RegExp(r'[가-힣]');
      expect(
        find.byWidgetPredicate((w) => w is Text && han.hasMatch(w.data ?? '')),
        findsNothing,
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Completed 1'), findsOneWidget);
      expect(find.text('Clear completed'), findsOneWidget);
    });

    testWidgets('영어 로케일 빈 완료 탭', (tester) async {
      SettingsService.instance.languageCode.value = 'en';
      addTearDown(() => SettingsService.instance.languageCode.value = 'ko');
      SharedPreferences.setMockInitialValues({});
      await pumpDone(tester);
      expect(find.textContaining('No completed memos yet.'), findsOneWidget);
    });
  });

  // T-261113-028 — 완료 탭 「편집」으로 골라서 비우기.
  group('완료 탭 선택 비우기', () {
    Finder selectMark(String id) => find.byKey(ValueKey('done-select-$id'));
    Finder clearSelected() => find.byKey(const Key('done-clear-selected'));
    VoidCallback? onPressedOf(WidgetTester tester, Finder button) =>
        tester.widget<TextButton>(button).onPressed;

    testWidgets('셋 중 둘 고르기 → 선택 비우기 → 그 둘만 휴지통 · 실행 취소로 돌아옴', (tester) async {
      seed([
        memo('a', '하나', doneAt: t),
        memo('b', '둘', doneAt: t),
        memo('c', '셋', doneAt: t),
        memo('d', '열린'),
      ]);
      await pumpDone(tester);
      expect(clearSelected(), findsNothing);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.text('취소'), findsOneWidget);
      // 체크 칸 대신 선택 동그라미 · 「완료 비우기」 대신 누를 수 없는 「선택 비우기」.
      expect(doneCheck('a'), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
      expect(find.byKey(const Key('done-clear')), findsNothing);
      expect(find.text('선택 비우기'), findsOneWidget);
      expect(onPressedOf(tester, clearSelected()), isNull);

      await tester.tap(find.text('하나'));
      await tester.pump();
      await tester.tap(find.text('셋'));
      await tester.pump();
      expect(find.text('선택 비우기 (2)'), findsOneWidget);
      expect(
        tester.widget<Icon>(selectMark('a')).icon,
        Icons.radio_button_checked,
      );
      expect(
        tester.widget<Icon>(selectMark('b')).icon,
        Icons.radio_button_unchecked,
      );
      expect(find.byIcon(Icons.radio_button_checked), findsNWidgets(2));

      await tester.tap(clearSelected());
      await tester.pumpAndSettle();
      expect(find.text('완료 2개를 휴지통으로 옮겼어요'), findsOneWidget);
      expect(find.text('하나'), findsNothing);
      expect(find.text('셋'), findsNothing);
      expect(find.text('둘'), findsOneWidget);
      expect(find.text('완료 1개'), findsOneWidget);
      // 비우면 선택 모드가 끝난다.
      expect(find.text('편집'), findsOneWidget);
      expect(doneCheck('b'), findsOneWidget);
      var saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNotNull);
      expect(saved['a']!.doneAt, t);
      expect(saved['c']!.deletedAt, isNotNull);
      expect(saved['b']!.deletedAt, isNull);
      expect(saved['d']!.deletedAt, isNull);
      expect(saved.keys, ['a', 'b', 'c', 'd']); // 배열 순서 그대로

      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(find.text('하나'), findsOneWidget);
      expect(find.text('셋'), findsOneWidget);
      expect(find.text('완료 3개'), findsOneWidget);
      saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNull);
      expect(saved['c']!.deletedAt, isNull);
      expect(saved['a']!.doneAt, t);
    });

    testWidgets('선택 모드에서 줄을 누르면 고르기만 — 편집도 체크 풀기도 없다', (tester) async {
      seed([memo('a', '끝낸 일', doneAt: t)]);
      await pumpDone(tester);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('끝낸 일'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoEditScreen), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('끝낸 일'), findsOneWidget);
      expect(styleOf(tester, '끝낸 일').decoration, TextDecoration.lineThrough);
      final saved = (await stored()).single;
      expect(saved.doneAt, t);
      expect(saved.deletedAt, isNull);

      // 다시 누르면 선택이 풀린다.
      await tester.tap(find.text('끝낸 일'));
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('선택 비우기'), findsOneWidget);
    });

    testWidgets('취소를 누르면 고른 것이 풀리고 체크 칸으로 돌아온다', (tester) async {
      seed([memo('a', '하나', doneAt: t), memo('b', '둘', doneAt: t)]);
      await pumpDone(tester);
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('하나'));
      await tester.pump();
      expect(find.text('선택 비우기 (1)'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('편집'), findsOneWidget);
      expect(doneCheck('a'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.byKey(const Key('done-clear')), findsOneWidget);
      expect(clearSelected(), findsNothing);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('선택 비우기'), findsOneWidget);
      expect(onPressedOf(tester, clearSelected()), isNull);
      final saved = await stored();
      expect(saved.every((m) => m.deletedAt == null && m.doneAt == t), isTrue);
    });

    testWidgets('전체선택은 체크를 푸는 중인 메모를 빼고 고른다 · 다시 누르면 선택해제', (tester) async {
      seed([
        memo('a', '하나', doneAt: t),
        memo('b', '둘', doneAt: t),
        memo('c', '셋', doneAt: t),
      ]);
      await pumpDone(tester);
      await tester.tap(doneCheck('a'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('편집'));
      await tester.pump();
      await tester.tap(find.text('전체선택'));
      await tester.pump();
      expect(find.text('선택 비우기 (2)'), findsOneWidget);
      expect(find.text('선택해제'), findsOneWidget);

      await tester.tap(find.text('선택해제'));
      await tester.pump();
      expect(find.text('선택 비우기'), findsOneWidget);
      expect(find.text('전체선택'), findsOneWidget);

      await tester.tap(find.text('전체선택'));
      await tester.pump();
      await tester.tap(clearSelected());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved = {for (final m in await stored()) m.id: m};
      expect(saved['a']!.deletedAt, isNull);
      expect(saved['a']!.doneAt, isNull); // 체크 풀기는 그대로 끝남
      expect(saved['b']!.deletedAt, isNotNull);
      expect(saved['c']!.deletedAt, isNotNull);
      expect(find.byKey(const Key('done-empty')), findsOneWidget);
      // 완료 메모가 없으면 「편집」도 없다.
      expect(find.text('편집'), findsNothing);
    });

    testWidgets('영어 로케일 선택 모드 — 한글 0', (tester) async {
      SettingsService.instance.languageCode.value = 'en';
      addTearDown(() => SettingsService.instance.languageCode.value = 'ko');
      seed([memo('a', 'shipped', doneAt: t), memo('b', 'filed', doneAt: t)]);
      await pumpDone(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Clear selected'), findsOneWidget);
      await tester.tap(find.text('shipped'));
      await tester.pump();
      expect(find.text('Clear selected (1)'), findsOneWidget);
      final han = RegExp(r'[가-힣]');
      expect(
        find.byWidgetPredicate((w) => w is Text && han.hasMatch(w.data ?? '')),
        findsNothing,
      );
      await tester.tap(clearSelected());
      await tester.pumpAndSettle();
      expect(find.text('Moved 1 completed memo to Trash'), findsOneWidget);
      expect(find.text('filed'), findsOneWidget);
    });
  });

  testWidgets('검색은 완료 메모도 찾고 완료 표시·취소선으로 보여 준다', (tester) async {
    seed([memo('a', '우유 사기', doneAt: t), memo('b', '우유 마시기')]);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '우유');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-done-mark')), findsOneWidget);
    TextDecoration? decorationOf(String title) => tester
        .widgetList<RichText>(find.byType(RichText))
        .singleWhere((rt) => rt.text.toPlainText() == title)
        .text
        .style
        ?.decoration;
    expect(decorationOf('우유 사기'), TextDecoration.lineThrough);
    expect(decorationOf('우유 마시기'), isNot(TextDecoration.lineThrough));
  });
}
