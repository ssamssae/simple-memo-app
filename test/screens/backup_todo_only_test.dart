import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

// T-261112-052 → T-261113-024: 할 일 탭만 쓰던 사람도 백업·복원이 된다.
// 할 일은 이제 메모로 옮겨져 메모로 백업된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('옛 할 일만 있는 사람 — 백업 화면이 메모로 옮겨 지금 백업에 싣는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([
      Todo.create(title: 'a'),
      Todo.create(
        title: 'b',
      ).copyWith(done: true, doneAt: DateTime(2026, 11, 13)),
    ]);
    List<Memo>? uploaded;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (memos) async {
            uploaded = memos;
            return const DriveBackupSuccess('https://x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();
    expect(uploaded!.map((m) => m.content), ['a', 'b']);
    expect(uploaded![1].doneAt, DateTime(2026, 11, 13));
    expect(find.text('내보낼 메모가 없습니다'), findsNothing);
  });

  testWidgets('할 일만 든 옛 백업을 가져오면 메모 가져오기 안내', (tester) async {
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
    await tester.ensureVisible(find.text('파일에서 복원'));
    await tester.tap(find.text('파일에서 복원'));
    await tester.pumpAndSettle();
    expect(find.text('가져올 메모가 없습니다'), findsNothing);
    expect(
      find.text(AppStrings.fromCode('ko').importedMemos(1, 1)),
      findsOneWidget,
    );
    expect((await MemoStorage.loadMemos()).single.content, 'x');
  });
}
