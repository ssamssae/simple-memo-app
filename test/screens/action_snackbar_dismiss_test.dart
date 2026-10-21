import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

/// T-261022-006 r1 — 액션이 달린 SnackBar 는 Flutter 3.29 부터 기본으로 닫히지 않는다.
/// 「Drive 에 저장됐어요」(#146)와 같은 규칙을 삭제·복원 알림에도 적용한다:
/// 일반 모드는 시간이 지나면 닫히고, 화면 읽기 사용 중에는 직접 닫을 때까지 남는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final strings = AppStrings.fromCode('ko');
  final t = DateTime(2026, 10, 22, 9);

  Memo memo(String id, String content) =>
      Memo(id: id, content: content, createdAt: t, updatedAt: t);

  Widget app(Widget home, {bool accessibleNavigation = false}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            accessibleNavigation: accessibleNavigation,
          ),
          child: child!,
        ),
        home: home,
      );

  Finder closeIcon() => find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.close),
      );

  Future<void> deleteMemo(WidgetTester tester, String title) async {
    await tester.drag(find.text(title), const Offset(-90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, strings.delete));
    await tester.pumpAndSettle();
  }

  Future<void> restoreFromFile(WidgetTester tester) async {
    await tester.ensureVisible(find.text(strings.restoreFromFile));
    await tester.tap(find.text(strings.restoreFromFile));
    await tester.pumpAndSettle();
  }

  BackupRestoreScreen fileRestoreScreen() => BackupRestoreScreen(
        pickBackupFile: () => ExportImportService.importFromSource(
          Memo.encodeList([memo('after', '가져온 메모')]),
        ),
      );

  testWidgets('메모 삭제 알림은 실행 취소를 누르지 않아도 닫히고 다음 알림이 뜬다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a', '장보기')]),
    });
    await tester.pumpWidget(app(const MemoListScreen()));
    await tester.pumpAndSettle();

    await deleteMemo(tester, '장보기');
    expect(find.text(strings.memoDeleted), findsOneWidget);
    expect(find.text(strings.undoSpaced), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(strings.memoDeleted), findsNothing);

    // 앞 알림이 남아 있으면 뒤 알림은 줄만 서고 화면에 나오지 않는다.
    ScaffoldMessenger.of(tester.element(find.byType(MemoListScreen)))
        .showSnackBar(SnackBar(content: Text(strings.memoRestored)));
    await tester.pumpAndSettle();
    expect(find.text(strings.memoRestored), findsOneWidget);
  });

  testWidgets('화면 읽기 사용 중에는 메모 삭제 알림이 남고 닫기 아이콘으로 닫는다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a', '장보기')]),
    });
    await tester.pumpWidget(
      app(const MemoListScreen(), accessibleNavigation: true),
    );
    await tester.pumpAndSettle();

    await deleteMemo(tester, '장보기');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text(strings.memoDeleted), findsOneWidget);

    expect(closeIcon(), findsOneWidget);
    await tester.tap(closeIcon());
    await tester.pumpAndSettle();
    expect(find.text(strings.memoDeleted), findsNothing);
    // 닫기는 되돌리기가 아니다 — 메모는 휴지통에 남는다.
    final stored = await MemoStorage.loadMemos();
    expect(stored.single.deletedAt, isNotNull);
  });

  testWidgets('복원 완료 알림은 되돌리기를 누르지 않아도 닫힌다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('before', '원래 메모')]),
    });
    await tester.pumpWidget(app(fileRestoreScreen()));
    await tester.pumpAndSettle();

    await restoreFromFile(tester);
    expect(find.text(strings.importedMemos(1, 2)), findsOneWidget);
    expect(find.text(strings.undo), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(strings.importedMemos(1, 2)), findsNothing);
    expect(find.text(strings.undo), findsNothing);
  });

  testWidgets('화면 읽기 사용 중에는 복원 완료 알림이 남고 닫기 아이콘으로 닫는다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('before', '원래 메모')]),
    });
    await tester.pumpWidget(
      app(fileRestoreScreen(), accessibleNavigation: true),
    );
    await tester.pumpAndSettle();

    await restoreFromFile(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text(strings.importedMemos(1, 2)), findsOneWidget);

    expect(closeIcon(), findsOneWidget);
    await tester.tap(closeIcon());
    await tester.pumpAndSettle();
    expect(find.text(strings.importedMemos(1, 2)), findsNothing);
    expect(
      (await MemoStorage.loadMemos()).map((m) => m.id),
      ['before', 'after'],
    );
  });

  // 재발 방지: 새 액션 알림이 닫힘 방식을 정하지 않으면 다시 「안 내려가는 팝업」이 된다.
  test('lib 의 액션 SnackBar 는 모두 persist 를 명시한다', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in RegExp(r'\bSnackBar\(').allMatches(source)) {
        final args = _balancedArguments(source, match.end - 1);
        if (args.contains('SnackBarAction(') && !args.contains('persist:')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          offenders.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '액션 SnackBar 는 Flutter 3.29 부터 기본 persist=true 라 닫히지 않는다. '
          'persist: MediaQuery.accessibleNavigationOf(context) 와 '
          'showCloseIcon: true 를 함께 지정하세요:\n${offenders.join('\n')}',
    );
  });
}

/// [openParen] 위치의 `(` 와 짝이 맞는 `)` 까지의 인자 문자열.
String _balancedArguments(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')' && --depth == 0) {
      return source.substring(openParen, i + 1);
    }
  }
  return source.substring(openParen);
}
