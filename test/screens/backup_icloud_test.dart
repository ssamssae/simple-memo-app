import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/icloud_memo_backup.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

// T-261116-041 — 메모요 백업 기본 = 로그인 없이(대종님 11/16 「1,2,3,4」, 한줄일기 #149 방식).
// 아이폰 = iCloud, 안드로이드 = 파일. Google Drive 는 폰을 바꿀 때 추천하는 칸으로 내린다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Memo memo(String id, String content, {DateTime? deletedAt}) => Memo(
    id: id,
    content: content,
    createdAt: DateTime(2026, 11, 16, 9),
    updatedAt: DateTime(2026, 11, 16, 9),
    deletedAt: deletedAt,
  );

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform? platform,
    ICloudMemoBackup? icloud,
    Future<void> Function()? signOutDrive,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          platform: platform,
          icloud: icloud ?? _FakeICloud(),
          signOutDrive: signOutDrive,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  void expectTopToBottom(WidgetTester tester, List<String> texts) {
    for (var i = 1; i < texts.length; i++) {
      expect(
        top(tester, texts[i]),
        greaterThan(top(tester, texts[i - 1])),
        reason: '${texts[i - 1]} → ${texts[i]}',
      );
    }
  }

  testWidgets('안드로이드는 로그인 없는 파일 백업이 맨 위, 드라이브는 폰 바꿀 때 추천 칸', (tester) async {
    await pump(tester);

    expectTopToBottom(tester, [
      '로그인 없이 파일로 백업',
      '파일로 백업',
      '파일에서 복원',
      _hint,
      '폰을 바꿀 때 추천: Google Drive',
      '지금 백업',
      'Drive 백업 목록 보기',
      '다른 Google 계정 쓰기',
    ]);
    expect(find.text('iCloud에 백업'), findsNothing);
    expect(find.text('iCloud에서 복원'), findsNothing);
  });

  testWidgets('아이폰은 iCloud 가 맨 위, 드라이브가 다음, 파일은 맨 아래', (tester) async {
    await pump(tester, platform: TargetPlatform.iOS);

    expectTopToBottom(tester, [
      'iCloud에 백업 (로그인 없이)',
      'iCloud에 백업',
      '아직 백업이 없어요',
      _hint,
      '폰을 바꿀 때 추천: Google Drive',
      '지금 백업',
      'Drive 백업 목록 보기',
      '다른 Google 계정 쓰기',
      '파일로 백업',
      '파일에서 복원',
    ]);
    expect(find.text('로그인 없이 파일로 백업'), findsNothing);
  });

  testWidgets('iCloud 백업은 휴지통을 뺀 메모를 묶어 올리고 마지막 백업 시각을 남긴다', (tester) async {
    await MemoStorage.saveMemos([
      memo('a', '장보기'),
      memo('b', '지운 메모', deletedAt: DateTime(2026, 11, 16, 10)),
    ]);
    final icloud = _FakeICloud();
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);
    expect(find.text('아직 백업한 적 없어요'), findsOneWidget);

    await tester.tap(find.text('iCloud에 백업'));
    await tester.pumpAndSettle();

    expect(icloud.uploadCount, 1);
    final archive = MemoBackupArchive.decode(icloud.uploaded!);
    expect(archive.memos.map((m) => m.id), ['a']);
    expect(find.text('iCloud에 백업했어요'), findsOneWidget);
    expect(find.text('아직 백업한 적 없어요'), findsNothing);
  });

  testWidgets('iCloud 를 못 쓰면 켜는 방법을 알려 주고 올리지 않는다', (tester) async {
    await MemoStorage.saveMemos([memo('a', '장보기')]);
    final icloud = _FakeICloud(available: false);
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);

    await tester.tap(find.text('iCloud에 백업'));
    await tester.pumpAndSettle();

    expect(find.text(_unavailable), findsOneWidget);
    expect(icloud.uploadCount, 0);
  });

  testWidgets('iCloud 목록은 최신이 위이고 고른 줄을 지금 메모에 합친다', (tester) async {
    await MemoStorage.saveMemos([memo('a', '장보기')]);
    const newer = 'memoyo-export-2026-11-16T19-05-00.zip';
    const older = 'memoyo-export-2026-11-15T09-00-00.zip';
    final icloud = _FakeICloud(
      files: [_file(older, size: 1500), _file(newer, size: 2500000)],
      payloads: {
        newer: await ExportImportService.exportBytes([memo('b', '새 메모')]),
        older: await ExportImportService.exportBytes([memo('z', '옛 메모')]),
      },
    );
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);

    expect(find.text('iCloud 백업 선택'), findsNothing);
    expect(find.text('iCloud에서 복원'), findsNothing);
    expect(find.text('2026-11-16 19:05:00'), findsOneWidget);
    expect(find.text('2.5 MB'), findsOneWidget);
    expect(find.text('2026-11-15 09:00:00'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(
      top(tester, '2026-11-16 19:05:00'),
      lessThan(top(tester, '2026-11-15 09:00:00')),
    );

    await tester.tap(find.byKey(const Key('icloud-restore-$newer')));
    await tester.pumpAndSettle();

    expect(icloud.downloaded, newer);
    final saved = await MemoStorage.loadMemos();
    expect(saved.map((m) => m.id).toSet(), {'a', 'b'});
    expect(find.textContaining('되돌리기'), findsOneWidget);
  });

  testWidgets('iCloud 에 백업이 없으면 목록에 알려 준다', (tester) async {
    await pump(tester, platform: TargetPlatform.iOS);

    expect(find.text('아직 백업이 없어요'), findsOneWidget);
    expect(find.text('iCloud에 메모요 백업이 없어요'), findsNothing);
  });

  testWidgets('iCloud 목록을 못 받으면 다시 시도할 수 있다', (tester) async {
    final icloud = _FakeICloud(listError: PlatformException(code: 'failed'));
    await pump(tester, platform: TargetPlatform.iOS, icloud: icloud);

    expect(find.text('목록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text(_failed), findsNothing);

    icloud.listError = null;
    icloud.files = [_file('memoyo-export-2026-11-16T19-05-00.zip', size: 2000)];
    await tester.tap(find.byKey(const Key('icloud-list-retry')));
    await tester.pumpAndSettle();

    expect(find.text('2026-11-16 19:05:00'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
  });

  testWidgets('다른 Google 계정 쓰기는 Drive 로그인만 지우고 알려 준다', (tester) async {
    var signOuts = 0;
    await pump(tester, signOutDrive: () async => signOuts++);

    await tester.tap(find.text('다른 Google 계정 쓰기'));
    await tester.pumpAndSettle();

    expect(signOuts, 1);
    expect(find.text('다음 Drive 백업·복원 때 Google 계정을 다시 골라요.'), findsOneWidget);
  });
}

const _hint = '폰을 바꾸거나 아이폰 ↔ 안드로이드로 옮길 때는 아래 Google Drive를 추천해요.';

const _unavailable =
    'iCloud를 쓸 수 없어요. 설정에서 Apple 계정에 로그인하고 iCloud Drive를 켠 뒤 다시 시도해 주세요.';

const _failed =
    'iCloud 백업·복원을 끝내지 못했어요. iCloud Drive와 저장 공간을 확인한 뒤 다시 시도해 주세요.';

ICloudBackupFile _file(String name, {int size = 1}) =>
    ICloudBackupFile(name: name, modified: DateTime(2026), size: size);

class _FakeICloud extends ICloudMemoBackup {
  _FakeICloud({
    this.available = true,
    List<ICloudBackupFile> files = const [],
    this.payloads = const {},
    this.listError,
  }) : files = [...files];

  final bool available;
  List<ICloudBackupFile> files;
  final Map<String, Uint8List> payloads;
  Object? listError;
  int uploadCount = 0;
  Uint8List? uploaded;
  String? downloaded;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> upload(Uint8List bytes, {DateTime? now}) async {
    uploadCount += 1;
    uploaded = Uint8List.fromList(bytes);
  }

  @override
  Future<List<ICloudBackupFile>> list() async {
    if (listError != null) throw listError!;
    return files;
  }

  @override
  Future<Uint8List> download(String name) async {
    downloaded = name;
    return payloads[name]!;
  }
}
