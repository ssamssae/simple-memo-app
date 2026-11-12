import 'package:archive/archive.dart' as zip;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/features/todos/models/todo.dart';
import 'package:simple_memo_app/features/todos/services/todo_storage.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

List<String> entryNames(List<int> bytes) =>
    zip.ZipDecoder().decodeBytes(bytes).files.map((f) => f.name).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('할 일이 있으면 todos.json 이 들어가고 decode 로 되읽힌다', () async {
    final todo = Todo.create(title: '왕새우치킨');
    final bytes = await MemoBackupArchive.encode(
      [Memo.create(content: 'm')],
      todosJson: Todo.encodeList([todo]),
    );
    expect(entryNames(bytes), contains('todos.json'));
    final back = MemoBackupArchive.decode(bytes);
    expect(Todo.decodeList(back.todosJson!).single.id, todo.id);
  });

  test('할 일이 없으면 todos.json 을 넣지 않는다(옛 메모요 호환)', () async {
    SharedPreferences.setMockInitialValues({});
    final bytes = await ExportImportService.exportBytes([
      Memo.create(content: 'm'),
    ]);
    expect(entryNames(bytes), isNot(contains('todos.json')));
    expect(MemoBackupArchive.decode(bytes).todosJson, isNull);
  });

  test('exportBytes 는 저장된 할 일을 넣는다', () async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([Todo.create(title: 'a')]);
    final bytes = await ExportImportService.exportBytes([
      Memo.create(content: 'm'),
    ]);
    expect(MemoBackupArchive.decode(bytes).todosJson, isNotNull);
  });

  test('todos.json 없는 옛 백업을 가져오면 지금 할 일은 그대로', () async {
    final keep = Todo.create(title: 'keep');
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    await TodoStorage.save([keep]);
    final old = await MemoBackupArchive.encode([Memo.create(content: 'm')]);
    await ExportImportService.importBytes(old);
    final load = await TodoStorage.load();
    expect(load.todos.single.id, keep.id);
  });

  test('메모가 0개인 백업이라도 할 일은 합친다', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    final inc = Todo.create(title: 'from backup');
    final bytes = await MemoBackupArchive.encode(
      [],
      todosJson: Todo.encodeList([inc]),
    );
    await ExportImportService.importBytes(bytes);
    expect((await TodoStorage.load()).todos.single.id, inc.id);
  });

  test('할 일을 합칠 때 같은 id 는 더 새 것이 이긴다', () async {
    final a = Todo.create(title: 'old', now: DateTime(2026, 11, 1));
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    await TodoStorage.save([a]);
    final newer = a.copyWith(title: 'new', updatedAt: DateTime(2026, 11, 2));
    final bytes = await MemoBackupArchive.encode(
      [Memo.create(content: 'm')],
      todosJson: Todo.encodeList([newer]),
    );
    await ExportImportService.importBytes(bytes);
    expect((await TodoStorage.load()).todos.single.title, 'new');
  });

  test('메모를 하나도 쓰지 않은 가져오기는 묵은 되돌리기 기록을 지운다', () async {
    final m = Memo.create(content: 'm');
    SharedPreferences.setMockInitialValues({});
    await MemoStorage.saveMemos([m]);
    await SnapshotStore.save('[]'); // 예전 가져오기가 남긴 기록
    final older = m.copyWith(
      updatedAt: m.updatedAt.subtract(const Duration(days: 1)),
    );
    final bytes = await MemoBackupArchive.encode(
      [older],
      todosJson: Todo.encodeList([Todo.create(title: 't')]),
    );
    await ExportImportService.importBytes(bytes);
    expect(await SnapshotStore.load(), isNull);
    expect(await ExportImportService.undoImport(), isNull);
    expect((await MemoStorage.loadMemos()).single.id, m.id);
  });

  test('깨진 todos.json 은 아무것도 쓰기 전에 FormatException', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    final bytes = await MemoBackupArchive.encode(
      [Memo.create(content: 'm')],
      todosJson: '{broken',
    );
    await expectLater(
      ExportImportService.importBytes(bytes),
      throwsFormatException,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('memos'), '[]');
    expect(prefs.getString('todos'), isNull);
  });
}
