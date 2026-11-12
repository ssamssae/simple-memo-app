import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/services/export_import_service.dart';

// T-261112-052: 메모 없이 할 일만 쓰는 사람도 백업·복원이 된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('메모가 없어도 할 일이 있으면 지금 백업이 올린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([Todo.create(title: 'a')]);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (_) async {
            calls++;
            return const DriveBackupSuccess('https://x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('내보낼 메모가 없습니다'), findsNothing);
  });

  testWidgets('메모가 없어도 할 일이 있으면 파일로 백업한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([Todo.create(title: 'a')]);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          saveBackupFile: (_) async {
            calls++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('파일로 백업'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('할 일만 든 백업을 가져오면 할 일 안내를 띄운다', (tester) async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    final bytes = await MemoBackupArchive.encode(
      [],
      todosJson: Todo.encodeList([Todo.create(title: 'x')]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          pickBackupFile: () => ExportImportService.importBytes(bytes),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('파일에서 복원'));
    await tester.pumpAndSettle();
    expect(find.text('할 일 1개를 가져왔어요'), findsOneWidget);
    expect(find.text('가져올 메모가 없습니다'), findsNothing);
    expect((await TodoStorage.load()).todos.single.title, 'x');
  });
}
