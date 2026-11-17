import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/icloud_memo_backup.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

// T-261117-061 — 백업 칸에 목록을 바로 보여 주고, 줄마다 복원·지우기.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const newer = 'memoyo-export-2026-11-16T19-05-00.zip';
  const older = 'memoyo-export-2026-11-15T09-00-00.zip';

  Memo memo(String id) => Memo(
    id: id,
    content: '메모 $id',
    createdAt: DateTime(2026, 11, 16, 9),
    updatedAt: DateTime(2026, 11, 16, 9),
  );

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform? platform,
    ICloudMemoBackup? icloud,
    Future<DriveBackupListResult> Function()? listBackups,
    Future<List<int>> Function(String fileId)? downloadBackup,
    Future<void> Function(String fileId)? deleteBackup,
    Future<DriveBackupResult> Function(List<Memo> memos)? uploadBackup,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          platform: platform,
          icloud: icloud,
          listBackups: listBackups,
          downloadBackup: downloadBackup,
          deleteBackup: deleteBackup,
          uploadBackup: uploadBackup,
        ),
      ),
    );
  }

  testWidgets('iCloud 목록은 최신이 위이고 날짜와 크기를 보여 준다', (tester) async {
    final icloud = _Cloud([_file(older, 1500), _file(newer, 2500000)]);
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);
    await tester.pumpAndSettle();

    expect(icloud.lists, 1);
    expect(
      tester.getTopLeft(find.text('2026-11-16 19:05:00')).dy,
      lessThan(tester.getTopLeft(find.text('2026-11-15 09:00:00')).dy),
    );
    expect(find.text('2.5 MB'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
  });

  testWidgets('iCloud 백업이 없으면 빈 목록 문구를 보여 준다', (tester) async {
    await pump(tester, platform: TargetPlatform.iOS, icloud: _Cloud(const []));
    await tester.pumpAndSettle();

    expect(find.text('아직 백업이 없어요'), findsOneWidget);
  });

  testWidgets('15초 안에 목록이 안 오면 실패와 다시 시도를 보여 준다', (tester) async {
    await pump(tester, platform: TargetPlatform.iOS, icloud: _HangCloud());
    await tester.pump();

    expect(find.text('불러오는 중'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(find.text('목록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('줄 복원은 고르는 창 없이 그 파일로 합치고 되돌리기를 보여 준다', (tester) async {
    await MemoStorage.saveMemos([memo('a')]);
    final bytes = utf8.encode(Memo.encodeList([memo('b')]));
    final gate = Completer<Uint8List>();
    final icloud = _Cloud(
      [_file(older, 2000), _file(newer, 3000)],
      downloadOf: (name) {
        expect(name, older);
        return gate.future;
      },
    );
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('icloud-restore-$older')));
    await tester.pump();

    expect(find.text('iCloud 백업 선택'), findsNothing);
    expect(find.text('복원 중…'), findsOneWidget);
    expect(icloud.downloaded, older);

    gate.complete(Uint8List.fromList(bytes));
    await tester.pumpAndSettle();

    expect((await MemoStorage.loadMemos()).map((m) => m.id).toSet(), {
      'a',
      'b',
    });
    expect(find.textContaining('되돌리기'), findsOneWidget);
  });

  testWidgets('줄 지우기 확인은 그 파일을 지우고 목록을 다시 불러 온다', (tester) async {
    final icloud = _Cloud([_file(newer, 2000), _file(older, 3000)]);
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);
    await tester.pumpAndSettle();
    expect(icloud.lists, 1);

    await tester.tap(find.byKey(const Key('icloud-delete-$older')));
    await tester.pumpAndSettle();
    expect(find.text('이 백업을 지울까요? 지우면 되돌릴 수 없어요.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-delete-confirm')));
    await tester.pumpAndSettle();

    expect(icloud.deleted, [older]);
    expect(icloud.lists, 2);
    expect(find.text('2026-11-15 09:00:00'), findsNothing);
    expect(find.text('2026-11-16 19:05:00'), findsOneWidget);
  });

  testWidgets('줄 지우기 취소는 아무것도 지우지 않는다', (tester) async {
    final icloud = _Cloud([_file(newer, 2000)]);
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('icloud-delete-$newer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-delete-cancel')));
    await tester.pumpAndSettle();

    expect(icloud.deleted, isEmpty);
    expect(icloud.lists, 1);
    expect(find.text('2026-11-16 19:05:00'), findsOneWidget);
    expect(find.text('이 백업을 지울까요? 지우면 되돌릴 수 없어요.'), findsNothing);
  });

  testWidgets('iCloud 백업이 끝나면 목록을 다시 불러 온다', (tester) async {
    await MemoStorage.saveMemos([memo('a')]);
    final icloud = _Cloud(const []);
    icloud.afterUpload = () {
      icloud.files = [_file(newer, 2000)];
    };
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);
    await tester.pumpAndSettle();
    expect(find.text('아직 백업이 없어요'), findsOneWidget);

    await tester.tap(find.text('iCloud에 백업'));
    await tester.pumpAndSettle();

    expect(icloud.uploads, 1);
    expect(icloud.lists, greaterThan(1));
    expect(find.text('2026-11-16 19:05:00'), findsOneWidget);
    expect(find.text('iCloud에 백업했어요'), findsOneWidget);
  });

  testWidgets('안드로이드에서 화면을 열 때 Drive 목록을 부르지 않는다', (tester) async {
    var lists = 0;
    Future<DriveBackupListResult> list() async {
      lists++;
      return const DriveBackupListSuccess([]);
    }

    await pump(tester, listBackups: list);
    await tester.pumpAndSettle();

    expect(lists, 0);
    expect(find.text('Drive 백업 목록 보기'), findsOneWidget);
  });

  testWidgets('아이폰에서 화면을 열 때 Drive 목록을 부르지 않는다', (tester) async {
    var lists = 0;
    Future<DriveBackupListResult> list() async {
      lists++;
      return const DriveBackupListSuccess([]);
    }

    await pump(
      tester,
      platform: TargetPlatform.iOS,
      icloud: _Cloud(const []),
      listBackups: list,
    );
    await tester.pumpAndSettle();

    expect(lists, 0);
    expect(find.text('아직 백업이 없어요'), findsOneWidget);
    expect(find.text('Drive 백업 목록 보기'), findsOneWidget);
  });

  testWidgets('Drive 목록은 최신이 위이고 그 id 로 복원한다', (tester) async {
    await MemoStorage.saveMemos([memo('a')]);
    final bytes = utf8.encode(Memo.encodeList([memo('b')]));
    String? downloaded;
    final entries = [
      DriveBackupEntry(
        id: 'old',
        name: older,
        modifiedTime: DateTime(2026, 11, 15, 9),
        size: 1500,
      ),
      DriveBackupEntry(
        id: 'new',
        name: newer,
        modifiedTime: DateTime(2026, 11, 16, 19, 5),
        size: 2500000,
      ),
    ];
    await pump(
      tester,
      listBackups: () async => DriveBackupListSuccess(entries),
      downloadBackup: (id) async {
        downloaded = id;
        return bytes;
      },
    );
    await tester.pumpAndSettle();
    expect(downloaded, isNull);

    await tester.tap(find.text('Drive 백업 목록 보기'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('2026-11-16 19:05:00')).dy,
      lessThan(tester.getTopLeft(find.text('2026-11-15 09:00:00')).dy),
    );
    expect(find.text('2.5 MB'), findsOneWidget);
    expect(find.text('Drive 백업 선택'), findsNothing);

    await tester.tap(find.byKey(const Key('drive-restore-old')));
    await tester.pumpAndSettle();

    expect(downloaded, 'old');
    expect((await MemoStorage.loadMemos()).map((m) => m.id).toSet(), {
      'a',
      'b',
    });
    expect(find.textContaining('되돌리기'), findsOneWidget);
  });

  testWidgets('Drive 줄 지우기 확인은 그 id 를 지우고 목록을 다시 불러 온다', (tester) async {
    final deleted = <String>[];
    var lists = 0;
    await pump(
      tester,
      listBackups: () async {
        lists++;
        final entries = [
          DriveBackupEntry(
            id: 'keep',
            name: newer,
            modifiedTime: DateTime(2026, 11, 16),
            size: 2000,
          ),
          if (lists == 1)
            DriveBackupEntry(
              id: 'drop',
              name: older,
              modifiedTime: DateTime(2026, 11, 15),
              size: 3000,
            ),
        ];
        return DriveBackupListSuccess(entries);
      },
      deleteBackup: (id) async => deleted.add(id),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drive 백업 목록 보기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('drive-delete-drop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-delete-cancel')));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(lists, 1);

    await tester.tap(find.byKey(const Key('drive-delete-drop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-delete-confirm')));
    await tester.pumpAndSettle();

    expect(deleted, ['drop']);
    expect(lists, 2);
    expect(find.text('2026-11-15 09:00:00'), findsNothing);
  });

  testWidgets('Drive에 백업이 없으면 빈 목록 문구를 보여 준다', (tester) async {
    await pump(
      tester,
      listBackups: () async => const DriveBackupListSuccess([]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drive 백업 목록 보기'));
    await tester.pumpAndSettle();

    expect(find.text('아직 백업이 없어요'), findsOneWidget);
  });

  testWidgets('Drive 목록이 열려 있으면 지금 백업 뒤에 다시 불러 온다', (tester) async {
    await MemoStorage.saveMemos([memo('a')]);
    var lists = 0;
    await pump(
      tester,
      uploadBackup: (_) async =>
          const DriveBackupSuccess('https://drive.google.com/drive/folders/x'),
      listBackups: () async {
        lists++;
        if (lists == 1) return const DriveBackupListSuccess([]);
        return DriveBackupListSuccess([
          DriveBackupEntry(
            id: 'new',
            name: newer,
            modifiedTime: DateTime(2026, 11, 16, 19, 5),
            size: 2000,
          ),
        ]);
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();
    expect(lists, 0, reason: '목록을 열기 전에는 백업 뒤에도 Drive 목록을 부르지 않는다');

    await tester.tap(find.text('Drive 백업 목록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('아직 백업이 없어요'), findsOneWidget);

    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();

    expect(lists, 2);
    expect(find.text('2026-11-16 19:05:00'), findsOneWidget);
  });
}

ICloudBackupFile _file(String name, int size) =>
    ICloudBackupFile(name: name, modified: DateTime(2026), size: size);

class _Cloud extends ICloudMemoBackup {
  _Cloud(List<ICloudBackupFile> files, {this.downloadOf}) : files = [...files];

  List<ICloudBackupFile> files;
  final Future<Uint8List> Function(String name)? downloadOf;
  final deleted = <String>[];
  int lists = 0;
  int uploads = 0;
  String? downloaded;
  void Function()? afterUpload;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> upload(Uint8List bytes, {DateTime? now}) async {
    uploads++;
    afterUpload?.call();
  }

  @override
  Future<List<ICloudBackupFile>> list() async {
    lists++;
    return [...files];
  }

  @override
  Future<void> delete(String name) async {
    deleted.add(name);
    files.removeWhere((file) => file.name == name);
  }

  @override
  Future<Uint8List> download(String name) async {
    downloaded = name;
    final custom = downloadOf;
    if (custom != null) return custom(name);
    return Uint8List.fromList([1]);
  }
}

class _HangCloud extends ICloudMemoBackup {
  @override
  Future<List<ICloudBackupFile>> list() =>
      Completer<List<ICloudBackupFile>>().future;
}
