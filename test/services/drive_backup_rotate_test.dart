import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';

import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

class _MockDriveApi extends Mock implements drive.DriveApi {}

class _MockFilesResource extends Mock implements drive.FilesResource {}

void main() {
  setUpAll(() {
    registerFallbackValue(drive.File());
  });

  group('DriveBackupService rotate — 회귀 시나리오', () {
    test(
      '8회 백업 simulation: 각 회차마다 uploadJsonFileForTest → 마지막 rotate(keep=7) → '
      '가장 오래된 1건 삭제 + 가장 새 7건 보존',
      () async {
        // 1~8 회차 변화하는 메모 상태로 8회 업로드 시뮬. 각 회차의 jsonBytes
        // 가 정확히 캡처되고 마지막 rotate 가 회차 1 만 지운다는 시간순 contract.
        final api = _MockDriveApi();
        final files = _MockFilesResource();
        when(() => api.files).thenReturn(files);

        // 폴더는 이미 존재
        when(() => files.list(
              q: any(named: 'q', that: contains('Memoyo')),
              spaces: any(named: 'spaces'),
              $fields: any(named: r'$fields'),
            )).thenAnswer((_) async => drive.FileList(files: [
                  drive.File()..id = 'memoyoFolderId',
                ]));

        // 업로드 응답 — id 와 capturedJson 회차마다 다르게
        final capturedJsons = <String>[];
        final capturedFilenames = <String>[];
        var uploadSeq = 0;
        when(() => files.create(
              any(),
              uploadMedia: any(named: 'uploadMedia'),
              $fields: any(named: r'$fields'),
            )).thenAnswer((invocation) async {
          final file = invocation.positionalArguments[0] as drive.File;
          capturedFilenames.add(file.name ?? '');
          final media = invocation
              .namedArguments[const Symbol('uploadMedia')] as drive.Media;
          final chunks = await media.stream.toList();
          capturedJsons.add(utf8.decode(chunks.expand((c) => c).toList()));
          uploadSeq++;
          return drive.File()..id = 'uploaded-$uploadSeq';
        });

        // === Act 1: 8회 업로드 시뮬 (회차마다 메모 1개씩 누적) ===
        final memos = <Memo>[];
        for (int round = 1; round <= 8; round++) {
          memos.add(Memo.create(content: '회차$round 메모'));
          final filename = 'memoyo-export-2026-05-29T01-${round.toString().padLeft(2, '0')}-00.json';
          final jsonBytes = utf8.encode(Memo.encodeList(memos));
          await DriveBackupService.uploadJsonFileForTest(
            api,
            folderId: 'memoyoFolderId',
            filename: filename,
            jsonBytes: jsonBytes,
          );
        }

        // 회차 8 캡처 검증 — 메모 8개 모두 들어있어야 함
        expect(capturedJsons, hasLength(8));
        final lastDecoded = Memo.decodeList(capturedJsons.last);
        expect(lastDecoded, hasLength(8));
        expect(lastDecoded.last.content, '회차8 메모');

        // === Act 2: rotate 직전 list 응답 — createdTime asc 로 회차 1~8 ===
        final base = DateTime.utc(2026, 5, 29, 1, 0, 0);
        when(() => files.list(
              q: any(named: 'q', that: contains('application/json')),
              spaces: any(named: 'spaces'),
              orderBy: any(named: 'orderBy', that: equals('createdTime')),
              $fields: any(named: r'$fields'),
            )).thenAnswer((_) async => drive.FileList(files: [
                  for (int i = 1; i <= 8; i++)
                    drive.File()
                      ..id = 'uploaded-$i'
                      ..name =
                          'memoyo-export-2026-05-29T01-${i.toString().padLeft(2, '0')}-00.json'
                      ..createdTime = base.add(Duration(minutes: i)),
                ]));
        when(() => files.delete(any())).thenAnswer((_) async {});

        // === Act 3: rotate(keep=7) ===
        await DriveBackupService.rotateForTest(api,
            folderId: 'memoyoFolderId', keep: 7);

        // === Verify: 회차 1 (가장 오래된) 만 삭제, 나머지 7건 보존 ===
        verify(() => files.delete('uploaded-1')).called(1);
        for (int i = 2; i <= 8; i++) {
          verifyNever(() => files.delete('uploaded-$i'));
        }
      },
    );

    test(
      'rotate 는 orderBy "createdTime" ASC 로 list 호출 (oldest-first 삭제 contract)',
      () async {
        // 회전이 newest 먼저 지우면 사용자 데이터 손실. orderBy 가 asc 인지 contract
        // pin — downloadLatestForTest 의 "createdTime desc" 와 정반대 명시.
        final api = _MockDriveApi();
        final files = _MockFilesResource();
        when(() => api.files).thenReturn(files);

        final capturedOrderBy = <String>[];
        when(() => files.list(
              q: any(named: 'q'),
              spaces: any(named: 'spaces'),
              orderBy: any(named: 'orderBy'),
              $fields: any(named: r'$fields'),
            )).thenAnswer((invocation) async {
          capturedOrderBy.add(
              invocation.namedArguments[const Symbol('orderBy')] as String);
          return drive.FileList(files: []);
        });

        await DriveBackupService.rotateForTest(api,
            folderId: 'memoyoId', keep: 7);

        expect(capturedOrderBy, hasLength(1));
        expect(capturedOrderBy.single, 'createdTime');
        expect(capturedOrderBy.single, isNot(contains('desc')),
            reason: 'rotate 는 oldest-first 삭제라 createdTime ASC 필수');
      },
    );

    test('빈 폴더 → rotate 가 list 만 호출하고 delete 호출 0', () async {
      // 신규 사용자 첫 로그인 직후 호출 시 안전성 가드.
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: []));

      await DriveBackupService.rotateForTest(api,
          folderId: 'memoyoId', keep: 7);

      verifyNever(() => files.delete(any()));
    });
  });
}
