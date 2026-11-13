// 할 일 탭 시절(1.0.29~1.0.30) 백업의 todos.json 과 메모 완료 표시(doneAt) 백업.
// T-261112-052 에서 생긴 todos.json 은 T-261113-024 부터 새로 쓰지 않고, 가져올 때 메모로 바꾼다.
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

  final t = DateTime(2026, 11, 12, 22);
  final doneAt = DateTime(2026, 11, 13, 7, 30);

  Todo todo(String id, {bool done = false}) => Todo(
    id: id,
    title: 'todo $id',
    note: done ? '' : 'note $id',
    done: done,
    doneAt: done ? doneAt : null,
    createdAt: t,
    updatedAt: t,
  );

  test('새 백업에는 todos.json 이 없다 — 저장된 할 일이 있어도', () async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([todo('a')]);
    final bytes = await ExportImportService.exportBytes([
      Memo.create(content: 'm'),
    ]);
    expect(entryNames(bytes), isNot(contains('todos.json')));
    expect(MemoBackupArchive.decode(bytes).todosJson, isNull);
  });

  test('옛 백업의 todos.json 은 decode 가 메모로 바꿔 메모 뒤에 붙인다', () async {
    final memo = Memo(id: 'm', content: 'memo', createdAt: t, updatedAt: t);
    final bytes = await MemoBackupArchive.encode([
      memo,
    ], todosJson: Todo.encodeList([todo('a'), todo('b', done: true)]));
    final back = MemoBackupArchive.decode(bytes);
    expect(back.memos.map((m) => m.id), ['m', 'a', 'b']);
    expect(back.memos[1].content, 'todo a\nnote a');
    expect(back.memos[1].doneAt, isNull);
    expect(back.memos[2].content, 'todo b');
    expect(back.memos[2].doneAt, doneAt);
  });

  test('할 일만 든 옛 백업을 가져오면 메모로 들어온다', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    final bytes = await MemoBackupArchive.encode(
      [],
      todosJson: Todo.encodeList([todo('a'), todo('b', done: true)]),
    );
    expect(await ExportImportService.importBytes(bytes), (2, 2));
    final memos = await MemoStorage.loadMemos();
    expect(memos.map((m) => m.id), ['a', 'b']);
    expect(memos[1].doneAt, doneAt);
  });

  test('이미 옮긴 할 일이 든 옛 백업을 다시 가져와도 겹치지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    await TodoStorage.save([todo('a'), todo('b', done: true)]);
    expect((await MemoStorage.loadMemos()).length, 2); // 옮기기
    final bytes = await MemoBackupArchive.encode(
      [],
      todosJson: Todo.encodeList([todo('a'), todo('b', done: true)]),
    );
    await ExportImportService.importBytes(bytes);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['a', 'b']);
  });

  test('todos.json 없는 백업을 가져와도 todos 키는 그대로', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    await TodoStorage.save([todo('keep')]);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('todos');
    final old = await MemoBackupArchive.encode([Memo.create(content: 'm')]);
    await ExportImportService.importBytes(old);
    expect(prefs.getString('todos'), raw);
  });

  test('깨진 todos.json 은 아무것도 쓰기 전에 FormatException', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    final bytes = await MemoBackupArchive.encode([
      Memo.create(content: 'm'),
    ], todosJson: '{broken');
    await expectLater(
      ExportImportService.importBytes(bytes),
      throwsFormatException,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('memos'), '[]');
    expect(prefs.getString('todos'), isNull);
  });

  test('메모를 하나도 쓰지 않은 가져오기는 묵은 되돌리기 기록을 지운다', () async {
    final m = Memo.create(content: 'm');
    SharedPreferences.setMockInitialValues({});
    await MemoStorage.saveMemos([m]);
    await SnapshotStore.save('[]'); // 예전 가져오기가 남긴 기록
    final older = m.copyWith(
      updatedAt: m.updatedAt.subtract(const Duration(days: 1)),
    );
    final bytes = await MemoBackupArchive.encode([older]);
    await ExportImportService.importBytes(bytes);
    expect(await SnapshotStore.load(), isNull);
    expect(await ExportImportService.undoImport(), isNull);
    expect((await MemoStorage.loadMemos()).single.id, m.id);
  });

  test('완료 표시는 파일 백업 → 복원 왕복에서 살아남는다', () async {
    final open = Memo(id: 'o', content: 'open', createdAt: t, updatedAt: t);
    final done = Memo(
      id: 'd',
      content: 'done',
      createdAt: t,
      updatedAt: t,
      doneAt: doneAt,
    );
    SharedPreferences.setMockInitialValues({});
    final bytes = await ExportImportService.exportBytes([open, done]);
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    expect(await ExportImportService.importBytes(bytes), (2, 2));
    final restored = {for (final m in await MemoStorage.loadMemos()) m.id: m};
    expect(restored['o']!.doneAt, isNull);
    expect(restored['d']!.doneAt, doneAt);
  });

  test('평문 JSON 가져오기도 완료 표시를 읽는다', () async {
    SharedPreferences.setMockInitialValues({'memos': '[]'});
    final source = Memo.encodeList([
      Memo(
        id: 'd',
        content: 'done',
        createdAt: t,
        updatedAt: t,
        doneAt: doneAt,
      ),
    ]);
    await ExportImportService.importFromSource(source);
    expect((await MemoStorage.loadMemos()).single.doneAt, doneAt);
  });
}
