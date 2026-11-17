import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/icloud_memo_backup.dart';

// T-261116-041 — 아이폰 기본 백업 = 로그인 없는 iCloud(대종님 11/16, 한줄일기 방식).
// 앱의 iCloud Drive 폴더에 파일 백업과 같은 이름(memoyo-export-…zip)으로 두고, 최근 5개만 보관한다.
// 이 시험은 기기 쪽 채널(memoyo/icloud_backup)과 주고받는 약속을 지킨다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('memoyo/icloud_backup');
  final calls = <MethodCall>[];
  var files = <Map<String, Object?>>[];
  var available = true;
  String? failOn;

  setUp(() {
    calls.clear();
    files = [];
    available = true;
    failOn = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == failOn) {
            throw PlatformException(code: 'failed');
          }
          final args = call.arguments is Map ? call.arguments as Map : const {};
          switch (call.method) {
            case 'status':
              return {'available': available};
            case 'save':
              files.add({
                'name': args['name'],
                'modified': 0,
                'size': (args['bytes'] as Uint8List).length,
              });
              return null;
            case 'list':
              return files;
            case 'read':
              return Uint8List.fromList([4, 2]);
            case 'delete':
              files.removeWhere((file) => file['name'] == args['name']);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('iCloud 를 쓸 수 있는지 기기에 묻는다', () async {
    expect(await ICloudMemoBackup().isAvailable(), isTrue);

    available = false;

    expect(await ICloudMemoBackup().isAvailable(), isFalse);
  });

  test('기기 확인이 실패하면 iCloud 를 쓸 수 없다고 본다', () async {
    failOn = 'status';

    expect(await ICloudMemoBackup().isAvailable(), isFalse);
  });

  test('백업은 파일 백업과 같은 날짜 이름의 zip 으로 iCloud 폴더에 저장한다', () async {
    await ICloudMemoBackup().upload(
      Uint8List.fromList([1, 2, 3]),
      now: DateTime(2026, 11, 16, 19, 5),
    );

    final save = calls.firstWhere((call) => call.method == 'save');
    final args = save.arguments as Map;
    expect(args['name'], 'memoyo-export-2026-11-16T19-05-00.zip');
    expect(args['bytes'], [1, 2, 3]);
  });

  test('최근 5개만 남기고 오래된 백업은 지운다', () async {
    files = [
      for (var day = 10; day <= 15; day++)
        {
          'name': 'memoyo-export-2026-11-${day}T09-00-00.zip',
          'modified': 0,
          'size': 1,
        },
    ];

    await ICloudMemoBackup().upload(
      Uint8List.fromList([9]),
      now: DateTime(2026, 11, 16, 9),
    );

    final names = files.map((file) => file['name']).toList()..sort();
    expect(names, [
      for (var day = 12; day <= 16; day++)
        'memoyo-export-2026-11-${day}T09-00-00.zip',
    ]);
  });

  test('오래된 백업 지우기가 실패해도 새 백업은 성공으로 본다', () async {
    files = [
      for (var day = 10; day <= 15; day++)
        {
          'name': 'memoyo-export-2026-11-${day}T09-00-00.zip',
          'modified': 0,
          'size': 1,
        },
    ];
    failOn = 'delete';

    await ICloudMemoBackup().upload(
      Uint8List.fromList([9]),
      now: DateTime(2026, 11, 16, 9),
    );

    expect(
      files.map((file) => file['name']),
      contains('memoyo-export-2026-11-16T09-00-00.zip'),
    );
  });

  test('목록은 최신 백업부터, 메모요 백업 이름만 보여 준다', () async {
    files = [
      {
        'name': 'memoyo-export-2026-11-01T09-00-00.zip',
        'modified': 1000,
        'size': 10,
      },
      {'name': 'notes.txt', 'modified': 2000, 'size': 1},
      {
        'name': 'yakmukja-backup-20261116-1905.json',
        'modified': 2500,
        'size': 1,
      },
      {
        'name': 'memoyo-export-2026-11-16T19-05-00.zip',
        'modified': 3000,
        'size': 20,
      },
    ];

    final list = await ICloudMemoBackup().list();

    expect(list.map((file) => file.name), [
      'memoyo-export-2026-11-16T19-05-00.zip',
      'memoyo-export-2026-11-01T09-00-00.zip',
    ]);
    expect(list.first.size, 20);
    expect(list.first.modified, DateTime.fromMillisecondsSinceEpoch(3000));
  });

  test('백업 고르기 창에는 파일 이름 속 날짜와 시각을 보여 준다', () {
    final file = ICloudBackupFile(
      name: 'memoyo-export-2026-11-16T19-05-00.zip',
      modified: DateTime.fromMillisecondsSinceEpoch(0),
      size: 1,
    );

    expect(file.label, '2026-11-16 19:05:00');
  });

  test('delete 는 그 이름으로 기기 delete 채널을 부른다', () async {
    const name = 'memoyo-export-2026-11-16T19-05-00.zip';

    await ICloudMemoBackup().delete(name);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'delete');
    expect((calls.single.arguments as Map)['name'], name);
  });

  test('복원은 고른 백업 파일의 내용을 기기에서 받아 온다', () async {
    final bytes = await ICloudMemoBackup().download(
      'memoyo-export-2026-11-16T19-05-00.zip',
    );

    expect(bytes, [4, 2]);
    final read = calls.firstWhere((call) => call.method == 'read');
    expect(
      (read.arguments as Map)['name'],
      'memoyo-export-2026-11-16T19-05-00.zip',
    );
  });
}
