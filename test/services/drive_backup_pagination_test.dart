import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

http.Response _page(List<int> ids, {String? nextPageToken}) => http.Response(
  jsonEncode({
    'files': [
      for (final id in ids)
        {'id': '$id', 'name': 'backup-$id.${id.isEven ? 'zip' : 'json'}'},
    ],
    'nextPageToken': ?nextPageToken,
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('백업 목록은 빈 중간 페이지 뒤의 백업까지 최신순으로 반환한다', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return switch (request.url.queryParameters['pageToken']) {
        null => _page([3, 2], nextPageToken: 'middle'),
        'middle' => _page([], nextPageToken: 'last'),
        'last' => _page([1]),
        _ => throw StateError('Unexpected page'),
      };
    });
    addTearDown(client.close);

    final entries = await DriveBackupService.listBackupsInFolderForTest(
      drive.DriveApi(client),
      'folder',
    );

    expect(entries.map((entry) => entry.id), ['3', '2', '1']);
    expect(entries.map((entry) => entry.name), [
      'backup-3.json',
      'backup-2.zip',
      'backup-1.json',
    ]);
    expect(requests, hasLength(3));
    for (final request in requests) {
      expect(request.queryParameters['orderBy'], 'createdTime desc');
      expect(request.queryParameters['fields'], contains('nextPageToken'));
      expect(request.queryParameters['q'], contains("'folder' in parents"));
    }
  });

  test('모든 페이지를 읽은 뒤 오래된 백업부터 삭제하고 최신 7개를 보존한다', () async {
    final events = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        events.add('delete:${request.url.pathSegments.last}');
        return http.Response('', 204);
      }
      final token = request.url.queryParameters['pageToken'];
      events.add('read:$token');
      expect(request.url.queryParameters['orderBy'], 'createdTime');
      return token == null
          ? _page([1, 2, 3, 4, 5], nextPageToken: 'newer')
          : _page([6, 7, 8, 9, 10]);
    });
    addTearDown(client.close);

    await DriveBackupService.rotateForTest(
      drive.DriveApi(client),
      folderId: 'folder',
      keep: 7,
    );

    expect(events, [
      'read:null',
      'read:newer',
      'delete:1',
      'delete:2',
      'delete:3',
    ]);
  });

  test('다음 페이지를 읽지 못하면 백업을 하나도 삭제하지 않는다', () async {
    final deleted = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.pathSegments.last);
        return http.Response('', 204);
      }
      if (request.url.queryParameters['pageToken'] == null) {
        return _page([1, 2, 3, 4, 5, 6, 7, 8], nextPageToken: 'unavailable');
      }
      return http.Response(
        jsonEncode({
          'error': {'code': 500, 'message': 'Synthetic page failure'},
        }),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);

    await expectLater(
      DriveBackupService.rotateForTest(
        drive.DriveApi(client),
        folderId: 'folder',
        keep: 7,
      ),
      throwsException,
    );
    expect(deleted, isEmpty);
  });
}
