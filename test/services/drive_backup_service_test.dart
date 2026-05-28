import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockDriveApi extends Mock implements drive.DriveApi {}

class _MockFilesResource extends Mock implements drive.FilesResource {}

void main() {
  group('DriveBackupResult', () {
    test('Success holds folderUrl', () {
      const r = DriveBackupSuccess('https://drive.google.com/drive/folders/abc');
      expect(r.folderUrl, 'https://drive.google.com/drive/folders/abc');
    });

    test('NetworkError is distinct from Unknown', () {
      const a = DriveBackupNetworkError();
      const b = DriveBackupUnknown('boom');
      expect(a, isNot(equals(b)));
    });

    test('PermissionDenied / QuotaExceeded / Unknown all subtype DriveBackupResult', () {
      const list = <DriveBackupResult>[
        DriveBackupSuccess('x'),
        DriveBackupNetworkError(),
        DriveBackupPermissionDenied(),
        DriveBackupQuotaExceeded(),
        DriveBackupUnknown('msg'),
      ];
      expect(list.length, 5);
    });
  });

  group('DriveBackupService._obtainAuthClient', () {
    test('signIn 이 null 반환 시 PermissionDenied', () async {
      final gsi = _MockGoogleSignIn();
      when(() => gsi.signIn()).thenAnswer((_) async => null);
      final result = await DriveBackupService.obtainAuthClientForTest(gsi);
      expect(result, isA<DriveBackupPermissionDenied>());
    });
  });

  group('DriveBackupService._ensureMemoyoFolder', () {
    setUpAll(() {
      registerFallbackValue(drive.File());
    });

    test('폴더 없음 → 생성 후 id 반환', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: []));
      when(() => files.create(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => drive.File()..id = 'newFolderId');

      final id = await DriveBackupService.ensureMemoyoFolderForTest(api);
      expect(id, 'newFolderId');
    });

    test('폴더 이미 있음 → 기존 id 반환, create 호출 X', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()..id = 'existingId',
              ]));

      final id = await DriveBackupService.ensureMemoyoFolderForTest(api);
      expect(id, 'existingId');
      verifyNever(() => files.create(any(), $fields: any(named: r'$fields')));
    });
  });

  group('DriveBackupService._uploadJsonFile', () {
    test('multipart media 로 업로드 호출', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      when(() => files.create(
            any(),
            uploadMedia: any(named: 'uploadMedia'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.File()..id = 'uploadedId');

      final id = await DriveBackupService.uploadJsonFileForTest(
        api,
        folderId: 'memoyoFolderId',
        filename: 'memoyo-export-2026-05-19-201700.json',
        jsonBytes: const [123, 125],
      );
      expect(id, 'uploadedId');

      final captured = verify(() => files.create(
            captureAny(),
            uploadMedia: any(named: 'uploadMedia'),
            $fields: any(named: r'$fields'),
          )).captured;
      final meta = captured.first as drive.File;
      expect(meta.name, 'memoyo-export-2026-05-19-201700.json');
      expect(meta.parents, ['memoyoFolderId']);
      expect(meta.mimeType, 'application/json');
    });
  });

  group('DriveBackupService._rotate', () {
    test('8개 → 1개 삭제 → 7개 유지', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      final fileList = drive.FileList(files: [
        for (int i = 0; i < 8; i++) drive.File()..id = 'f$i',
      ]);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => fileList);
      when(() => files.delete(any())).thenAnswer((_) async {});

      await DriveBackupService.rotateForTest(api,
          folderId: 'memoyoId', keep: 7);
      verify(() => files.delete('f0')).called(1);
      verifyNever(() => files.delete('f1'));
    });

    test('10개 → 3개 삭제 → 7개 유지', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      final fileList = drive.FileList(files: [
        for (int i = 0; i < 10; i++) drive.File()..id = 'f$i',
      ]);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => fileList);
      when(() => files.delete(any())).thenAnswer((_) async {});

      await DriveBackupService.rotateForTest(api,
          folderId: 'memoyoId', keep: 7);
      verify(() => files.delete('f0')).called(1);
      verify(() => files.delete('f1')).called(1);
      verify(() => files.delete('f2')).called(1);
      verifyNever(() => files.delete('f3'));
    });

    test('7개 이하 → 삭제 호출 0', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      final fileList = drive.FileList(files: [
        for (int i = 0; i < 5; i++) drive.File()..id = 'f$i',
      ]);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => fileList);

      await DriveBackupService.rotateForTest(api,
          folderId: 'memoyoId', keep: 7);
      verifyNever(() => files.delete(any()));
    });
  });

  group('DriveBackupService.mapError', () {
    test('SocketException → NetworkError', () {
      final r = DriveBackupService.mapErrorForTest(
          const SocketException('no network'));
      expect(r, isA<DriveBackupNetworkError>());
    });

    test('DetailedApiRequestError 403 storageQuotaExceeded → QuotaExceeded',
        () {
      final err = drive.DetailedApiRequestError(403, 'storageQuotaExceeded');
      final r = DriveBackupService.mapErrorForTest(err);
      expect(r, isA<DriveBackupQuotaExceeded>());
    });

    test('DetailedApiRequestError 401 → PermissionDenied', () {
      final err = drive.DetailedApiRequestError(401, 'unauthorized');
      final r = DriveBackupService.mapErrorForTest(err);
      expect(r, isA<DriveBackupPermissionDenied>());
    });

    test('그 외 Exception → Unknown', () {
      final r = DriveBackupService.mapErrorForTest(Exception('something else'));
      expect(r, isA<DriveBackupUnknown>());
    });
  });
}
