import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

import '../features/memos/support/attachment_test_support.dart';

class _MockDriveApi extends Mock implements drive.DriveApi {}

class _MockFilesResource extends Mock implements drive.FilesResource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const picker = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temp;
  late Memo original;

  setUpAll(() {
    registerFallbackValue(drive.File());
    registerFallbackValue(drive.DownloadOptions.metadata);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await installTempStore();
    await seedStoreFile('photo.jpg');
    original = Memo.create(content: '사진과 함께 복원할 본문', imageFiles: ['photo.jpg']);
    await MemoStorage.saveMemos([original]);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(picker, null);
    AttachmentStore.instance = null;
    await temp.delete(recursive: true);
  });

  Future<void> assertRestoredPhoto() async {
    final restored = (await MemoStorage.loadMemos()).single;
    expect(restored.id, original.id);
    expect(restored.content, original.content);
    expect(restored.imageFiles.single, isNot('photo.jpg'));
    expect(
      await AttachmentStore.instance
          .fileFor(restored.imageFiles.single)
          .readAsBytes(),
      kTinyPng,
    );
  }

  test('파일 저장·선택 경계를 거쳐 ZIP의 본문과 사진 실물을 복원한다', () async {
    final file = File('${temp.path}/backup.zip');
    messenger.setMockMethodCallHandler(picker, (call) async {
      final args = call.arguments as Map;
      if (call.method == 'save') {
        expect(args['fileName'], endsWith('.zip'));
        expect(args['allowedExtensions'], ['zip']);
        await file.writeAsBytes(args['bytes'] as Uint8List);
        return file.path;
      }
      expect(call.method, 'custom');
      expect(args['allowedExtensions'], ['zip', 'json']);
      return [
        {'path': file.path, 'name': 'backup.zip', 'size': await file.length()},
      ];
    });
    expect(await ExportImportService.saveBackupFile([original]), isTrue);
    expect(
      MemoBackupArchive.decode(await file.readAsBytes()).photos['photo.jpg'],
      kTinyPng,
    );
    await MemoStorage.saveMemos([]);
    await AttachmentStore.instance.delete(['photo.jpg']);
    expect(await ExportImportService.pickAndImport(), (1, 1));
    await assertRestoredPhoto();
  });

  test('파일 선택과 저장 취소는 기존 메모를 변경하지 않는다', () async {
    messenger.setMockMethodCallHandler(picker, (_) async => null);
    expect(await ExportImportService.saveBackupFile([original]), isFalse);
    expect(await ExportImportService.pickAndImport(), isNull);
    expect((await MemoStorage.loadMemos()).single.id, original.id);
    expect(
      await AttachmentStore.instance.fileFor('photo.jpg').readAsBytes(),
      kTinyPng,
    );
  });

  test('Drive ZIP 업로드·분할 다운로드 후 사진 실물을 복원한다', () async {
    final api = _MockDriveApi();
    final files = _MockFilesResource();
    when(() => api.files).thenReturn(files);
    List<int>? uploaded;
    when(
      () => files.create(
        any(),
        uploadMedia: any(named: 'uploadMedia'),
        $fields: any(named: r'$fields'),
      ),
    ).thenAnswer((invocation) async {
      final metadata = invocation.positionalArguments.single as drive.File;
      final media = invocation.namedArguments[#uploadMedia] as drive.Media;
      expect(metadata.name, endsWith('.zip'));
      expect(metadata.mimeType, 'application/zip');
      expect(metadata.parents, ['folder']);
      expect(media.contentType, 'application/zip');
      uploaded = (await media.stream.toList())
          .expand((chunk) => chunk)
          .toList();
      expect(media.length, uploaded!.length);
      return drive.File()..id = 'backup';
    });
    final bytes = await ExportImportService.exportBytes([original]);
    await DriveBackupService.uploadBackupFileForTest(
      api,
      folderId: 'folder',
      filename: ExportImportService.backupFileName(),
      bytes: bytes,
    );
    expect(uploaded, bytes);
    await MemoStorage.saveMemos([]);
    await AttachmentStore.instance.delete(['photo.jpg']);
    when(
      () => files.get('backup', downloadOptions: any(named: 'downloadOptions')),
    ).thenAnswer(
      (_) async => drive.Media(
        Stream.fromIterable([uploaded!.sublist(0, 11), uploaded!.sublist(11)]),
        uploaded!.length,
      ),
    );
    final downloaded = await DriveBackupService.downloadBackupContentForTest(
      api,
      'backup',
    );
    expect(await ExportImportService.importBytes(downloaded), (1, 1));
    await assertRestoredPhoto();
  });

  test('Drive 목록과 7개 보관은 JSON·ZIP을 함께 포함한다', () async {
    final api = _MockDriveApi();
    final files = _MockFilesResource();
    when(() => api.files).thenReturn(files);
    when(
      () => files.list(
        q: any(named: 'q'),
        spaces: any(named: 'spaces'),
        orderBy: any(named: 'orderBy'),
        $fields: any(named: r'$fields'),
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#q] as String;
      expect(query, contains("'folder' in parents"));
      expect(
        query,
        contains(
          "(mimeType = 'application/json' or mimeType = 'application/zip')",
        ),
      );
      final entries = [
        for (var i = 0; i < 8; i++)
          drive.File()
            ..id = '$i'
            ..name = 'backup-$i.${i.isEven ? 'json' : 'zip'}',
      ];
      return drive.FileList(
        files: invocation.namedArguments[#orderBy] == 'createdTime'
            ? entries
            : entries.reversed.toList(),
      );
    });
    when(() => files.delete(any())).thenAnswer((_) async {});
    final listed = await DriveBackupService.listBackupsInFolderForTest(
      api,
      'folder',
    );
    expect(listed.first.name, 'backup-7.zip');
    expect(listed.last.name, 'backup-0.json');
    await DriveBackupService.rotateForTest(api, folderId: 'folder', keep: 7);
    verify(() => files.delete('0')).called(1);
    for (var i = 1; i < 8; i++) {
      verifyNever(() => files.delete('$i'));
    }
  });
}
