import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/models/memo.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  test('save: uuid.jpg 파일명으로 저장되고 바이트가 그대로 남는다', () async {
    final store = AttachmentStore.instance;
    final name = await store.save(kTinyPng);

    expect(name, endsWith('.jpg'));
    expect(name, isNot(contains('/')));
    expect(await store.fileFor(name).readAsBytes(), kTinyPng);
    expect(await store.exists(name), isTrue);
  });

  test('save 는 디렉토리가 없어도 만들어서 저장한다', () async {
    final store = AttachmentStore.instance;
    expect(store.root.existsSync(), isFalse);
    await store.save(kTinyPng);
    expect(store.root.existsSync(), isTrue);
  });

  test('delete: 있는 파일은 지우고 없는 파일은 조용히 무시', () async {
    final store = AttachmentStore.instance;
    final a = await store.save(kTinyPng);
    await store.delete([a, 'ghost.jpg']);
    expect(await store.exists(a), isFalse);
  });

  test('fileFor: 검증 실패 파일명은 ArgumentError (attachments/ 밖 접근 차단)', () {
    final store = AttachmentStore.instance;
    expect(() => store.fileFor('../x.jpg'), throwsArgumentError);
    expect(() => store.fileFor('a/b.jpg'), throwsArgumentError);
  });

  test('sweepOrphans: 참조 안 되는 오래된 파일만 지우고 개수를 돌려준다', () async {
    final store = AttachmentStore.instance;
    final keep = await store.save(kTinyPng);
    final orphan1 = await store.save(kTinyPng);
    final orphan2 = await store.save(kTinyPng);
    final old = DateTime.now().subtract(const Duration(days: 2));
    for (final n in [keep, orphan1, orphan2]) {
      store.fileFor(n).setLastModifiedSync(old);
    }

    final removed = await store.sweepOrphans([keep, 'not-on-disk.jpg']);

    expect(removed, 2);
    expect(await store.exists(keep), isTrue);
    expect(await store.exists(orphan1), isFalse);
    expect(await store.exists(orphan2), isFalse);
  });

  test('sweepOrphans: minAge 보다 최근 파일은 참조가 없어도 남긴다 (편집 세션 대기분 보호)', () async {
    final store = AttachmentStore.instance;
    final fresh = await store.save(kTinyPng); // 방금 생성 = mtime 지금
    final aged = await store.save(kTinyPng);
    store.fileFor(aged).setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 30)));

    final removed = await store.sweepOrphans(const []);

    expect(removed, 1);
    expect(await store.exists(fresh), isTrue);
    expect(await store.exists(aged), isFalse);
  });

  test('sweepOrphans: minAge 를 0 으로 주면 최근 파일도 정리 대상', () async {
    final store = AttachmentStore.instance;
    final fresh = await store.save(kTinyPng);
    expect(await store.sweepOrphans(const [], minAge: Duration.zero), 1);
    expect(await store.exists(fresh), isFalse);
  });

  test('sweepOrphans: 디렉토리 자체가 없으면 0', () async {
    expect(await AttachmentStore.instance.sweepOrphans(const []), 0);
  });

  test('exists: 검증 실패 파일명은 false (던지지 않음)', () async {
    expect(await AttachmentStore.instance.exists('../x.jpg'), isFalse);
    expect(await AttachmentStore.instance.exists('a/b.jpg'), isFalse);
  });

  test('delete: 검증 실패 파일명은 조용히 건너뛴다', () async {
    final store = AttachmentStore.instance;
    final a = await store.save(kTinyPng);
    await store.delete(['../evil.jpg', 'a/b.jpg', a]);
    expect(await store.exists(a), isFalse);
  });

  test('save 가 돌려주는 파일명은 Memo.isValidImageFileName 을 통과한다', () async {
    final name = await AttachmentStore.instance.save(kTinyPng);
    expect(Memo.isValidImageFileName(name), isTrue);
  });

  test('sweepOrphans: 하위 디렉토리는 무시한다', () async {
    final store = AttachmentStore.instance;
    await store.root.create(recursive: true);
    final sub = Directory('${store.root.path}${Platform.pathSeparator}sub')..createSync();
    File('${sub.path}${Platform.pathSeparator}x.jpg').writeAsBytesSync(kTinyPng);
    expect(await store.sweepOrphans(const [], minAge: Duration.zero), 0);
    expect(sub.existsSync(), isTrue);
  });

  test('instance 미설정이면 maybeInstance null, instance 는 StateError', () {
    AttachmentStore.instance = null;
    expect(AttachmentStore.maybeInstance, isNull);
    expect(() => AttachmentStore.instance, throwsStateError);
  });
}
