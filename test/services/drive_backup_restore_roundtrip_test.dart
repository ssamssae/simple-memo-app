import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

class _MockDriveApi extends Mock implements drive.DriveApi {}

class _MockFilesResource extends Mock implements drive.FilesResource {}

void main() {
  setUpAll(() {
    registerFallbackValue(drive.File());
    registerFallbackValue(drive.DownloadOptions.metadata);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Drive backup ↔ restore round-trip (mocked DriveApi)', () {
    test('3 메모 → 업로드 → 로컬 wipe → 다운로드/복원 → 3 메모 그대로', () async {
      // === Arrange: 3 메모를 MemoStorage 에 저장 ===
      final original = <Memo>[
        Memo.create(content: '첫 메모'),
        Memo.create(content: '둘째\n메모 (멀티라인)'),
        Memo.create(content: '셋째 메모 ★'),
      ];
      await MemoStorage.saveMemos(original);
      expect((await MemoStorage.loadMemos()).length, 3);

      // === Mock DriveApi backend (folder + file resource) ===
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);

      // Memoyo 폴더 조회 — 이미 존재
      when(() => files.list(
            q: any(named: 'q', that: contains('Memoyo')),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()..id = 'memoyoFolderId',
              ]));

      // 업로드 캡처
      String? capturedJson;
      String? capturedFilename;
      when(() => files.create(
            any(),
            uploadMedia: any(named: 'uploadMedia'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((invocation) async {
        final file = invocation.positionalArguments[0] as drive.File;
        capturedFilename = file.name;
        final media =
            invocation.namedArguments[const Symbol('uploadMedia')] as drive.Media;
        final chunks = await media.stream.toList();
        capturedJson = utf8.decode(chunks.expand((c) => c).toList());
        return drive.File()..id = 'uploadedFileId';
      });

      // JSON 파일 리스팅 — rotate + restore 양쪽 다 동일하게 1건 반환
      when(() => files.list(
            q: any(named: 'q', that: contains('application/json')),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()
                  ..id = 'uploadedFileId'
                  ..name = 'memoyo-export-2026-05-29T01-40-00.json'
                  ..createdTime = DateTime.utc(2026, 5, 29, 1, 40, 0),
              ]));

      // === Act 1: 업로드 (uploadJsonFileForTest + rotate) ===
      // 정적 _signIn 우회 — 헬퍼들을 직접 chain.
      final folderId =
          await DriveBackupService.ensureMemoyoFolderForTest(api);
      expect(folderId, 'memoyoFolderId');

      const ts = '2026-05-29T01-40-00';
      final filename = 'memoyo-export-$ts.json';
      final jsonBytes = utf8.encode(Memo.encodeList(original));
      final uploadedId = await DriveBackupService.uploadJsonFileForTest(
        api,
        folderId: folderId,
        filename: filename,
        jsonBytes: jsonBytes,
      );
      expect(uploadedId, 'uploadedFileId');
      expect(capturedJson, isNotNull);
      expect(capturedFilename, filename);

      // rotate 호출 (현재 1개 < 7 이라 삭제 0)
      await DriveBackupService.rotateForTest(api,
          folderId: folderId, keep: 7);
      verifyNever(() => files.delete(any()));

      // === Act 2: 로컬 wipe ===
      await MemoStorage.saveMemos([]);
      expect((await MemoStorage.loadMemos()).isEmpty, isTrue);

      // === Mock 다운로드 (캡처한 JSON 으로 응답) ===
      when(() => files.get(
            any(),
            downloadOptions: any(named: 'downloadOptions'),
          )).thenAnswer((invocation) async {
        final bytes = utf8.encode(capturedJson!);
        return drive.Media(
          Stream<List<int>>.fromIterable([bytes]),
          bytes.length,
        );
      });

      // === Act 3: Drive 다운로드 + 로컬 복원 ===
      final downloaded = await DriveBackupService.downloadLatestForTest(api);
      expect(downloaded, isNotNull);
      expect(downloaded!.length, 3);
      await MemoStorage.saveMemos(downloaded);

      // === Assert: round-trip 무결성 (id / content / isFavorite 동일) ===
      final restored = await MemoStorage.loadMemos();
      expect(restored.length, 3);
      for (int i = 0; i < 3; i++) {
        expect(restored[i].id, original[i].id);
        expect(restored[i].content, original[i].content);
        expect(restored[i].isFavorite, original[i].isFavorite);
        expect(restored[i].createdAt.toIso8601String(),
            original[i].createdAt.toIso8601String());
      }

      // === Verify: 핵심 API 가 정확히 호출됐는지 ===
      verify(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia'),
              $fields: any(named: r'$fields')))
          .called(1);
      verify(() => files.get(
            'uploadedFileId',
            downloadOptions: any(named: 'downloadOptions'),
          )).called(1);
    });

    test('Drive 폴더에 백업 파일 0건 → downloadLatestForTest 가 null 반환', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);

      when(() => files.list(
            q: any(named: 'q', that: contains('Memoyo')),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()..id = 'memoyoFolderId',
              ]));
      when(() => files.list(
            q: any(named: 'q', that: contains('application/json')),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: []));

      final result = await DriveBackupService.downloadLatestForTest(api);
      expect(result, isNull);
    });

    test('JSON 파싱 깨진 백업 → 빈 list 반환 (Memo.decodeList 가드)', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);

      when(() => files.list(
            q: any(named: 'q', that: contains('Memoyo')),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()..id = 'memoyoFolderId',
              ]));
      when(() => files.list(
            q: any(named: 'q', that: contains('application/json')),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()..id = 'corruptId'..name = 'corrupt.json',
              ]));
      when(() => files.get(
            any(),
            downloadOptions: any(named: 'downloadOptions'),
          )).thenAnswer((_) async {
        // valid JSON but not a memo list
        final bytes = utf8.encode('{"not_a_memo_list": true}');
        return drive.Media(
          Stream<List<int>>.fromIterable([bytes]),
          bytes.length,
        );
      });

      final result = await DriveBackupService.downloadLatestForTest(api);
      expect(result, isNotNull);
      expect(result!.isEmpty, isTrue);
    });
  });
}
