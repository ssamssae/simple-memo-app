import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

import 'support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  Memo memo(String id, {List<String> images = const [], int day = 2}) => Memo(
    id: id,
    content: '본문 $id',
    isFavorite: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, day),
    imageFiles: images,
  );
  Uint8List bundle(
    List<Memo> memos, {
    Map<String, List<int>> photos = const {},
  }) {
    final archive = zip.Archive()
      ..add(zip.ArchiveFile.string('memos.json', Memo.encodeList(memos)));
    for (final entry in photos.entries) {
      archive.add(
        zip.ArchiveFile.noCompress(entry.key, entry.value.length, entry.value),
      );
    }
    return Uint8List.fromList(zip.ZipEncoder().encode(archive));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await installTempStore();
  });
  tearDown(() async {
    AttachmentStore.instance = null;
    await temp.delete(recursive: true);
  });

  test('ZIP은 사진 실물과 메모 메타데이터를 보존하고 공유 사진은 한 번 담는다', () async {
    await seedStoreFile('shared.jpg');
    final original = [
      memo('a', images: ['shared.jpg']),
      memo('b', images: ['shared.jpg']),
    ];
    final bytes = await ExportImportService.exportBytes(original);
    final archive = zip.ZipDecoder().decodeBytes(bytes);
    expect(archive.map((f) => f.name), [
      'memos.json',
      'attachments/shared.jpg',
    ]);
    expect(archive.findFile('attachments/shared.jpg')!.content, kTinyPng);
    final restored = MemoBackupArchive.decode(bytes);
    expect(Memo.encodeList(restored.memos), Memo.encodeList(original));
  });

  test('내보낼 사진이 없으면 글만 성공 처리하지 않고 실패한다', () async {
    expect(
      () => ExportImportService.exportBytes([
        memo('a', images: ['missing.jpg']),
      ]),
      throwsA(isA<BackupPhotoUnavailableException>()),
    );
  });

  test('다른 기기로 복원하면 사진 실물과 순서가 새 파일명으로 연결된다', () async {
    final bytes = bundle(
      [
        memo('a', images: ['first.jpg', 'second.jpg']),
      ],
      photos: {
        'attachments/first.jpg': kTinyPng,
        'attachments/second.jpg': [7, 8, 9],
        'attachments/orphan.jpg': [10],
      },
    );
    expect(await ExportImportService.importBytes(bytes), (1, 1));
    final restored = (await MemoStorage.loadMemos()).single;
    expect(restored.content, '본문 a');
    expect(restored.isFavorite, isTrue);
    expect(restored.imageFiles, hasLength(2));
    expect(
      await AttachmentStore.instance
          .fileFor(restored.imageFiles[0])
          .readAsBytes(),
      kTinyPng,
    );
    expect(
      await AttachmentStore.instance
          .fileFor(restored.imageFiles[1])
          .readAsBytes(),
      [7, 8, 9],
    );
    expect(await AttachmentStore.instance.root.list().length, 2);
  });

  test('동일 이름의 기존 사진을 보존하고 undo 시 가져온 사진만 제거한다', () async {
    await seedStoreFile('same.jpg', Uint8List.fromList([1, 2, 3]));
    final old = memo('a', images: ['same.jpg'], day: 1);
    await MemoStorage.saveMemos([old]);
    final bytes = bundle(
      [
        memo('a', images: ['same.jpg']),
      ],
      photos: {'attachments/same.jpg': kTinyPng},
    );
    await ExportImportService.importBytes(bytes);
    final importedName =
        (await MemoStorage.loadMemos()).single.imageFiles.single;
    expect(importedName, isNot('same.jpg'));
    expect(await AttachmentStore.instance.fileFor('same.jpg').readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(await SnapshotStore.referencedImages(), contains('same.jpg'));
    final restored = await ExportImportService.undoImport();
    expect(restored!.single.imageFiles, ['same.jpg']);
    expect(await AttachmentStore.instance.exists('same.jpg'), isTrue);
    expect(await AttachmentStore.instance.exists(importedName), isFalse);
  });

  test('같은 ZIP 재복원과 오래된 메모는 사진을 추가로 만들지 않는다', () async {
    final bytes = bundle(
      [
        memo('a', images: ['a.jpg']),
      ],
      photos: {'attachments/a.jpg': kTinyPng},
    );
    await ExportImportService.importBytes(bytes);
    final names = (await MemoStorage.loadMemos()).single.imageFiles;
    await ExportImportService.importBytes(bytes);
    await ExportImportService.importBytes(
      bundle(
        [
          memo('a', images: ['old.jpg'], day: 1),
        ],
        photos: {
          'attachments/old.jpg': [9],
        },
      ),
    );
    expect((await MemoStorage.loadMemos()).single.imageFiles, names);
    expect(await AttachmentStore.instance.root.list().length, 1);
  });

  test('누락 사진·경로 이탈·잘못된 manifest는 기존 메모와 snapshot을 변경하지 않는다', () async {
    final original = Memo.encodeList([memo('existing')]);
    await MemoStorage.saveMemos([memo('existing')]);
    await SnapshotStore.save('[]');
    for (final bytes in [
      bundle([
        memo('a', images: ['absent.jpg']),
      ]),
      bundle(
        [memo('a')],
        photos: {
          '../outside.jpg': [1],
        },
      ),
      zip.ZipEncoder().encode(
        zip.Archive()..add(zip.ArchiveFile.string('memos.json', '{}')),
      ),
    ]) {
      await expectLater(
        () => ExportImportService.importBytes(bytes),
        throwsFormatException,
      );
      expect(Memo.encodeList(await MemoStorage.loadMemos()), original);
      expect(await SnapshotStore.load(), '[]');
    }
  });

  test('CRC가 다른 ZIP 사진은 복원하지 않는다', () {
    final bytes = bundle(
      [
        memo('a', images: ['crc.jpg']),
      ],
      photos: {
        'attachments/crc.jpg': [91, 92, 93],
      },
    );
    final directory = zip.ZipDirectory()..read(zip.InputMemoryStream(bytes));
    final offset = directory.fileHeaders.last.localHeaderOffset;
    final view = ByteData.sublistView(bytes);
    final dataOffset =
        offset +
        30 +
        view.getUint16(offset + 26, Endian.little) +
        view.getUint16(offset + 28, Endian.little);
    bytes[dataOffset] ^= 1;
    expect(() => MemoBackupArchive.decode(bytes), throwsFormatException);
  });

  test('사진 없는 기존 JSON과 사진 파일명만 있는 1단계 JSON도 가져온다', () async {
    await seedStoreFile('legacy.jpg');
    final source = Memo.encodeList([
      memo('old', images: ['legacy.jpg']),
    ]);
    expect(await ExportImportService.importFromSource(source), (1, 1));
    expect((await MemoStorage.loadMemos()).single.imageFiles, ['legacy.jpg']);
    expect(MemoBackupArchive.decode(utf8.encode('[]')).memos, isEmpty);
  });

  test('메모 저장 실패 시 새 사진을 제거하고 이전 snapshot을 되돌린다', () async {
    final existing = memo('a', day: 1);
    await MemoStorage.saveMemos([existing]);
    await SnapshotStore.save('[]');
    final before = Memo.encodeList(await MemoStorage.loadMemos());
    await expectLater(
      () => ExportImportService.importBytes(
        bundle(
          [
            memo('b', images: ['new.jpg']),
          ],
          photos: {'attachments/new.jpg': kTinyPng},
        ),
        saveMemos: (_) async => false,
      ),
      throwsStateError,
    );
    expect(Memo.encodeList(await MemoStorage.loadMemos()), before);
    expect(await SnapshotStore.load(), '[]');
    expect(await AttachmentStore.instance.root.list().length, 0);
  });

  test('영구삭제 시에도 snapshot이 참조하는 사진은 undo를 위해 남긴다', () async {
    await seedStoreFile('keep.jpg');
    final original = memo('a', images: ['keep.jpg']);
    await SnapshotStore.save(Memo.encodeList([original]));
    await MemoStorage.saveMemos([
      original.copyWith(deletedAt: DateTime.utc(2026, 1, 3)),
    ]);
    await MemoStorage.emptyTrash();
    expect(await AttachmentStore.instance.exists('keep.jpg'), isTrue);
  });

  test('기존 메모를 읽지 못하면 빈 목록으로 간주해 덮어쓰지 않는다', () async {
    SharedPreferences.setMockInitialValues({'memos': 'broken existing data'});
    await expectLater(
      () => ExportImportService.importBytes(bundle([memo('new')])),
      throwsFormatException,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('memos'), 'broken existing data');
    expect(await SnapshotStore.hasSnapshot(), isFalse);
  });

  test('고아 정리는 undo snapshot 사진을 보존하고 사용하지 않는 사진만 제거한다', () async {
    await seedStoreFile('snapshot.jpg');
    await seedStoreFile('orphan.jpg');
    await SnapshotStore.save(
      Memo.encodeList([
        memo('old', images: ['snapshot.jpg']),
      ]),
    );
    final removed = await AttachmentStore.instance.sweepOrphans(
      await SnapshotStore.referencedImages(),
      minAge: Duration.zero,
    );
    expect(removed, 1);
    expect(await AttachmentStore.instance.exists('snapshot.jpg'), isTrue);
  });

  test('심볼릭 링크와 압축 해제 크기를 속인 ZIP을 거부한다', () {
    final linkArchive = zip.Archive()
      ..add(zip.ArchiveFile.string('memos.json', '[]'))
      ..add(
        zip.ArchiveFile('attachments/link.jpg', 1, [1])
          ..symbolicLink = '../../outside'
          ..mode = 0xa1ff,
      );
    expect(
      () => MemoBackupArchive.decode(zip.ZipEncoder().encode(linkArchive)),
      throwsFormatException,
    );

    final archive = zip.Archive()
      ..add(zip.ArchiveFile.string('memos.json', '[]'))
      ..add(
        zip.ArchiveFile(
          'attachments/large.jpg',
          100000,
          List.filled(100000, 0),
        ),
      );
    final bytes = Uint8List.fromList(zip.ZipEncoder().encode(archive));
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50 &&
          data.getUint32(i + 24, Endian.little) == 100000) {
        data.setUint32(i + 24, 1, Endian.little);
        break;
      }
    }
    expect(() => MemoBackupArchive.decode(bytes), throwsFormatException);
  });

  test('손상된 snapshot은 undo로 현재 메모를 지우거나 사진 정리에 쓰지 않는다', () async {
    await seedStoreFile('keep.jpg');
    final current = memo('a', images: ['keep.jpg']);
    await MemoStorage.saveMemos([current]);
    await SnapshotStore.save('{}');
    await expectLater(ExportImportService.undoImport, throwsFormatException);
    expect((await MemoStorage.loadMemos()).single.id, current.id);
    await MemoStorage.saveMemos([
      current.copyWith(deletedAt: DateTime.utc(2026, 1, 3)),
    ]);
    await MemoStorage.emptyTrash();
    expect(await AttachmentStore.instance.exists('keep.jpg'), isTrue);
  });

  test('undo 저장 실패 시 현재 메모·사진과 복원 snapshot을 보존한다', () async {
    await MemoStorage.saveMemos([memo('old')]);
    await ExportImportService.importBytes(
      bundle(
        [
          memo('new', images: ['new.jpg']),
        ],
        photos: {'attachments/new.jpg': kTinyPng},
      ),
    );
    final current = Memo.encodeList(await MemoStorage.loadMemos());
    final snapshot = await SnapshotStore.load();
    await expectLater(
      () => ExportImportService.undoImport(
        saveMemos: (memos) async {
          await MemoStorage.saveMemos(memos);
          return false;
        },
      ),
      throwsStateError,
    );
    expect(Memo.encodeList(await MemoStorage.loadMemos()), current);
    expect(await SnapshotStore.load(), snapshot);
    expect(await AttachmentStore.instance.root.list().length, 1);
  });

  test('중복된 ZIP 항목은 같은 파일을 두 번 쓰지 않고 거부한다', () {
    final bytes = bundle(
      [memo('a')],
      photos: {
        'attachments/aa.jpg': [1],
        'attachments/bb.jpg': [2],
      },
    );
    final needle = utf8.encode('attachments/bb.jpg');
    final replacement = utf8.encode('attachments/aa.jpg');
    for (var i = 0; i <= bytes.length - needle.length; i++) {
      if (List.generate(needle.length, (j) => bytes[i + j]).join(',') ==
          needle.join(',')) {
        bytes.setRange(i, i + needle.length, replacement);
      }
    }
    expect(() => MemoBackupArchive.decode(bytes), throwsFormatException);
  });
}
