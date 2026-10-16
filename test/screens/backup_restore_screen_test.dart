import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

// 1.0.7 ① Drive 백업 1버튼화 — 백업 & 복원 화면.
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

  Memo trashed(String id) {
    final t = DateTime(2026, 6, 1, 12);
    return Memo(
      id: id,
      content: '휴지통 $id',
      createdAt: t,
      updatedAt: t,
      deletedAt: DateTime(2026, 6, 3, 12),
    );
  }

  testWidgets('설정 → "백업 & 복원" ListTile 탭 → BackupRestoreScreen 진입',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList(<Memo>[]),
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('백업 & 복원'),
      160,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('백업 & 복원'), findsOneWidget, reason: '설정에 백업&복원 진입점');
    await tester.tap(find.text('백업 & 복원'));
    await tester.pumpAndSettle();

    // BackupRestoreScreen 고유 버튼.
    expect(find.text('지금 백업'), findsOneWidget);
    expect(find.text('복원'), findsOneWidget);
  });

  testWidgets('"지금 백업" 탭 → uploadBackup 1회 호출 + 성공 SnackBar', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a'), active('b')]),
    });

    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (memos) async {
            calls++;
            return const DriveBackupSuccess(
              'https://drive.google.com/drive/folders/x',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();

    expect(calls, 1, reason: 'uploadBackup 정확히 1회');
    expect(find.text('Drive 에 저장됐어요'), findsOneWidget);
  });

  testWidgets('백업 대상은 활성 메모만 — 휴지통 메모는 제외', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        active('a'),
        trashed('t1'),
        active('b'),
        trashed('t2'),
      ]),
    });

    List<Memo>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (memos) async {
            captured = memos;
            return const DriveBackupSuccess('https://x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 화면 안내에도 활성 2개로 표시.
    expect(find.textContaining('활성 메모 2개'), findsOneWidget);

    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(captured!.every((m) => m.deletedAt == null), isTrue);
    expect(captured!.map((m) => m.id).toSet(), {'a', 'b'});
  });

  testWidgets('백업 완료 알림은 폴더 버튼을 누르지 않아도 자동으로 닫힌다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a')]),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (_) async => const DriveBackupSuccess(
            'https://drive.google.com/drive/folders/x',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();
    expect(find.text('Drive 에 저장됐어요'), findsOneWidget);
    expect(find.text('Memoyo 폴더 열기'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Drive 에 저장됐어요'), findsNothing);
    expect(find.text('Memoyo 폴더 열기'), findsNothing);
  });

  for (final accessibleNavigation in [false, true]) {
    testWidgets('백업 완료 알림을 직접 닫는다 (접근성: $accessibleNavigation)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([active('a')]),
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              accessibleNavigation: accessibleNavigation,
            ),
            child: child!,
          ),
          home: BackupRestoreScreen(
            uploadBackup: (_) async => const DriveBackupSuccess(
              'https://drive.google.com/drive/folders/x',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('지금 백업'));
      await tester.pumpAndSettle();
      if (accessibleNavigation) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('Drive 에 저장됐어요'), findsOneWidget);
      }
      final close = find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.close),
      );
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('Drive 에 저장됐어요'), findsNothing);
    });
  }

  testWidgets('설정으로 돌아온 뒤에도 백업 완료 알림이 자동으로 닫힌다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([active('a')]),
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('설정 화면')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => BackupRestoreScreen(
        uploadBackup: (_) async => const DriveBackupSuccess('https://x'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('설정 화면'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Drive 에 저장됐어요'), findsNothing);
  });

  testWidgets('활성 메모 0개에서 "지금 백업" 탭 → 안내 SnackBar, upload 미호출',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([trashed('t1')]),
    });

    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (_) async {
            calls++;
            return const DriveBackupSuccess('https://x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('지금 백업'));
    await tester.pumpAndSettle();

    expect(find.text('내보낼 메모가 없습니다'), findsOneWidget);
    expect(calls, 0, reason: '활성 0개면 upload 호출 안 함');
  });
}
