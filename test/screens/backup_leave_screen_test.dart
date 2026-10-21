import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

/// T-261022-006 r2 — 백업·복원 도중이나 직후에 화면을 나가도 결과를 알리고
/// 되돌리기가 동작해야 한다. 알림은 앱 전체 메신저에 뜨므로 설정 화면에서 보인다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final strings = AppStrings.fromCode('ko');
  final t = DateTime(2026, 10, 22, 9);

  Memo memo(String id) =>
      Memo(id: id, content: '메모 $id', createdAt: t, updatedAt: t);

  Future<NavigatorState> openBackupScreen(
    WidgetTester tester,
    BackupRestoreScreen screen,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('설정 화면')),
    ));
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await tester.pumpAndSettle();
    return navigator.currentState!;
  }

  Future<void> leave(WidgetTester tester, NavigatorState navigator) async {
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('설정 화면'), findsOneWidget);
    expect(find.byType(BackupRestoreScreen), findsNothing);
  }

  testWidgets('백업 중 화면을 나가도 완료 알림이 뜨고 마지막 백업 시각이 남는다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a')]),
    });
    final upload = Completer<DriveBackupResult>();
    final navigator = await openBackupScreen(
      tester,
      BackupRestoreScreen(uploadBackup: (_) => upload.future),
    );

    await tester.tap(find.text(strings.backupNow));
    await tester.pump();
    expect(find.text(strings.driveBackupStarting), findsOneWidget);
    await leave(tester, navigator);

    upload.complete(const DriveBackupSuccess('https://drive.google.com/x'));
    await tester.pumpAndSettle();
    expect(find.text(strings.driveBackupStarting), findsNothing);
    expect(find.text(strings.driveSaved), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('memoyo_last_backup_at'), isNotNull);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text(strings.driveSaved), findsNothing);

    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const BackupRestoreScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text(strings.neverBackedUp), findsNothing);
    expect(find.textContaining(strings.lastBackupAt('')), findsOneWidget);
  });

  testWidgets('백업 중 화면을 나가도 실패 알림이 시작 알림을 바꾼다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a')]),
    });
    final upload = Completer<DriveBackupResult>();
    final navigator = await openBackupScreen(
      tester,
      BackupRestoreScreen(uploadBackup: (_) => upload.future),
    );

    await tester.tap(find.text(strings.backupNow));
    await tester.pump();
    await leave(tester, navigator);

    upload.complete(const DriveBackupNetworkError());
    await tester.pumpAndSettle();
    expect(find.text(strings.driveBackupStarting), findsNothing);
    expect(find.text(strings.checkInternet), findsOneWidget);
  });

  testWidgets('Drive 복원 중 화면을 나가도 결과를 알리고 되돌리기가 동작한다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('before')]),
    });
    final download = Completer<List<int>>();
    final navigator = await openBackupScreen(
      tester,
      BackupRestoreScreen(
        listBackups: () async => const DriveBackupListSuccess([
          DriveBackupEntry(id: 'f1', name: 'memoyo-export-2026-10-21T09-00-00.zip'),
        ]),
        downloadBackup: (_) => download.future,
      ),
    );

    await tester.tap(find.text(strings.restore));
    await tester.pump();
    await leave(tester, navigator);

    download.complete(utf8.encode(Memo.encodeList([memo('after')])));
    await tester.pumpAndSettle();
    expect(find.text(strings.importedMemos(1, 2)), findsOneWidget);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['before', 'after']);

    await tester.tap(find.text(strings.undo));
    await tester.pumpAndSettle();
    expect(find.text(strings.restoredPrevious(1)), findsOneWidget);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['before']);
  });

  testWidgets('복원 직후 화면을 나가서 되돌리기를 눌러도 이전 메모로 돌아간다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('before')]),
    });
    final navigator = await openBackupScreen(
      tester,
      BackupRestoreScreen(
        pickBackupFile: () => ExportImportService.importFromSource(
          Memo.encodeList([memo('after')]),
        ),
      ),
    );

    await tester.ensureVisible(find.text(strings.restoreFromFile));
    await tester.tap(find.text(strings.restoreFromFile));
    await tester.pumpAndSettle();
    expect(find.text(strings.importedMemos(1, 2)), findsOneWidget);
    await leave(tester, navigator);

    await tester.tap(find.text(strings.undo));
    await tester.pumpAndSettle();
    expect(find.text(strings.restoredPrevious(1)), findsOneWidget);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['before']);
  });
}
