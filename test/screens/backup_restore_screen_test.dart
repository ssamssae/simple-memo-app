import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

// 1.0.7 ① Drive 백업 1버튼화 — 백업 & 복원 화면.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
