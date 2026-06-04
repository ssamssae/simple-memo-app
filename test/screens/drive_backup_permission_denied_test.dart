import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

// 1.0.7 ① Drive UI 통합 후: 백업 진입점이 백업&복원 화면의 "지금 백업" 버튼.
// upload 권한 거부 / 진행 안내 미러.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '메모 1개 + "지금 백업" 탭 + upload 권한 거부 → "Drive 권한이 필요해요" SnackBar',
    (tester) async {
      final now = DateTime(2026, 5, 29, 1, 55);
      final memo = Memo(
        id: 'perm-1',
        content: '권한 거부 테스트\n본문',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'memos': Memo.encodeList([memo]),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(
            uploadBackup: (_) async => const DriveBackupPermissionDenied(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backup = find.text('지금 백업');
      expect(backup, findsOneWidget);
      await tester.tap(backup);
      await tester.pumpAndSettle();

      expect(find.text('Drive 권한이 필요해요'), findsOneWidget);
    },
  );

  testWidgets('"지금 백업" 탭 직후 진행 안내를 먼저 보여준다', (tester) async {
    final now = DateTime(2026, 6, 3, 9, 30);
    final memo = Memo(
      id: 'progress-1',
      content: '진행 안내 테스트',
      createdAt: now,
      updatedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo]),
    });

    final gate = Completer<DriveBackupResult>();
    await tester.pumpWidget(
      MaterialApp(
        home: BackupRestoreScreen(
          uploadBackup: (_) => gate.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('지금 백업'));
    await tester.pump();

    expect(find.text('Drive 백업을 시작합니다'), findsOneWidget);

    gate.complete(const DriveBackupPermissionDenied());
    await tester.pumpAndSettle();
  });
}
