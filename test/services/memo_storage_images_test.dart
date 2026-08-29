import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

import '../features/memos/support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  final now = DateTime(2026, 8, 29, 12);

  Memo memo(String id, {List<String> images = const [], DateTime? deletedAt}) =>
      Memo(id: id, content: id, createdAt: now, updatedAt: now, deletedAt: deletedAt, imageFiles: images);

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  test('purgeExpiredTrash: 만료 메모의 파일만 삭제, 활성·미만료 파일 생존', () async {
    final old = await seedStoreFile('old.jpg');
    final fresh = await seedStoreFile('fresh.jpg');
    final keep = await seedStoreFile('keep.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('expired', images: [old], deletedAt: DateTime.now().subtract(const Duration(days: 31))),
        memo('recent', images: [fresh], deletedAt: DateTime.now().subtract(const Duration(days: 1))),
        memo('active', images: [keep]),
      ]),
    });

    expect(await MemoStorage.purgeExpiredTrash(), 1);

    final store = AttachmentStore.instance;
    expect(await store.exists(old), isFalse);
    expect(await store.exists(fresh), isTrue);
    expect(await store.exists(keep), isTrue);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['recent', 'active']);
  });

  test('deleteForever: 지정 id 메모 제거 + 그 파일 삭제, 나머지 무변경', () async {
    final a = await seedStoreFile('a.jpg');
    final b = await seedStoreFile('b.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('x', images: [a], deletedAt: now),
        memo('y', images: [b], deletedAt: now),
      ]),
    });

    expect(await MemoStorage.deleteForever({'x'}), 1);

    expect(await AttachmentStore.instance.exists(a), isFalse);
    expect(await AttachmentStore.instance.exists(b), isTrue);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['y']);
  });

  test('emptyTrash: 휴지통 전부 제거 + 파일 삭제, 활성 메모·파일 무변경', () async {
    final a = await seedStoreFile('a.jpg');
    final keep = await seedStoreFile('keep.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('trashed', images: [a], deletedAt: now),
        memo('active', images: [keep]),
      ]),
    });

    expect(await MemoStorage.emptyTrash(), 1);

    expect(await AttachmentStore.instance.exists(a), isFalse);
    expect(await AttachmentStore.instance.exists(keep), isTrue);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['active']);
  });

  test('같은 파일을 두 메모가 참조하면 한쪽만 지워질 때 파일은 남는다', () async {
    final shared = await seedStoreFile('shared.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('gone', images: [shared], deletedAt: now),
        memo('stays', images: [shared]),
      ]),
    });
    expect(await MemoStorage.deleteForever({'gone'}), 1);
    expect(await AttachmentStore.instance.exists(shared), isTrue);
  });

  test('아무것도 제거되지 않으면 저장도 파일 삭제도 없다 (0 반환)', () async {
    final a = await seedStoreFile('a.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('x', images: [a])]),
    });
    expect(await MemoStorage.deleteForever({'nope'}), 0);
    expect(await MemoStorage.emptyTrash(), 0);
    expect(await MemoStorage.purgeExpiredTrash(), 0);
    expect(await AttachmentStore.instance.exists(a), isTrue);
  });

  test('스토어 미초기화여도 삭제 경로는 크래시 없이 메모만 지운다', () async {
    AttachmentStore.instance = null;
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('x', images: ['a.jpg'], deletedAt: now)]),
    });
    expect(await MemoStorage.deleteForever({'x'}), 1);
    expect(await MemoStorage.loadMemos(), isEmpty);
  });
}
