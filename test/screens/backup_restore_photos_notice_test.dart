import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/features/memos/services/memo_backup_archive.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

// 2단계(T-260829-024): 사진 포함 안내와 파일 백업·복원 진입점.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        'close' => null,
        _ => throw PlatformException(
          code: 'UNEXPECTED_MINILM_TEST_CALL',
          message: call.method,
        ),
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  Memo active(String id, {bool fav = false}) {
    final t = DateTime(2026, 6, 4, 12);
    return Memo(
      id: id,
      content: '활성 $id',
      createdAt: t,
      updatedAt: t,
      isFavorite: fav,
    );
  }

  testWidgets('백업 화면은 사진 포함과 이전 JSON 복원 가능을 안내한다', (tester) async {
    _tallView(tester);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a'), active('b')]),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (memos) async {
            return const DriveBackupSuccess(
              'https://drive.google.com/drive/folders/x',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('메모와 사진을 함께 백업합니다. 이전 JSON 백업도 복원할 수 있어요.'),
      findsOneWidget,
    );
    expect(
      AppStrings.fromCode('en').photosIncludedInBackup,
      contains('notes and photos'),
    );
  });

  testWidgets('파일 백업은 활성 메모만 전달하고 실행 중 다른 작업을 막는다', (tester) async {
    _tallView(tester);
    final trash = active('trash').copyWith(deletedAt: DateTime(2026, 6, 5));
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a'), trash]),
    });
    final pending = Completer<bool>();
    List<Memo>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          saveBackupFile: (memos) {
            sent = memos;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('파일로 백업'));
    await tester.tap(find.text('파일로 백업'));
    await tester.pump();
    expect(sent!.map((m) => m.id), ['a']);
    expect(_button(tester, '파일에서 복원').onPressed, isNull);
    expect(_button(tester, '지금 백업').onPressed, isNull);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('백업 파일을 저장했어요'), findsOneWidget);
  });

  testWidgets('파일 복원 취소는 오류 없이 끝나고 버튼을 다시 사용할 수 있다', (tester) async {
    _tallView(tester);
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          pickBackupFile: () async {
            calls++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('파일에서 복원'));
    await tester.tap(find.text('파일에서 복원'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(_button(tester, '파일에서 복원').onPressed, isNotNull);
  });

  testWidgets('사진 누락은 백업 성공 대신 설명을 표시한다', (tester) async {
    _tallView(tester);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a')]),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          saveBackupFile: (_) async => throw BackupPhotoUnavailableException(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('파일로 백업'));
    await tester.tap(find.text('파일로 백업'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.fromCode('ko').backupPhotoUnavailable),
      findsOneWidget,
    );
    expect(find.text('백업 파일을 저장했어요'), findsNothing);
  });

  testWidgets('파일 복원 성공 후 되돌리기를 누르면 이전 메모로 돌아간다', (tester) async {
    _tallView(tester);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('before')]),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          pickBackupFile: () => ExportImportService.importFromSource(
            Memo.encodeList([active('after')]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.ensureVisible(find.text('파일에서 복원'));
    await tester.tap(find.text('파일에서 복원'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.fromCode('ko').importedMemos(1, 2)),
      findsOneWidget,
    );
    expect((await MemoStorage.loadMemos()).map((m) => m.id), [
      'before',
      'after',
    ]);
    await tester.tap(find.text(AppStrings.fromCode('ko').undo));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.fromCode('ko').restoredPrevious(1)),
      findsOneWidget,
    );
    expect((await MemoStorage.loadMemos()).single.id, 'before');
  });

  testWidgets('잘못된 파일 복원은 오류 안내 후 다시 시도할 수 있다', (tester) async {
    _tallView(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          pickBackupFile: () async => throw const FormatException('bad backup'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('파일에서 복원'));
    await tester.tap(find.text('파일에서 복원'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.fromCode('ko').invalidBackupFile),
      findsOneWidget,
    );
    expect(_button(tester, '파일에서 복원').onPressed, isNotNull);
  });
}

// T-261116-041 — 백업 화면 맨 위에 기본(로그인 없는) 칸이 생겨 Drive 단추가 아래로 내려갔다.
// 목록은 보이는 곳만 그리므로 화면을 키워 모든 단추를 그려 둔다.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 단추 모양(파일 단추는 이제 안드로이드 기본 칸의 Filled·Outlined)과 상관없이 글자로 단추를 찾는다.
ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          )
          .first,
    );
