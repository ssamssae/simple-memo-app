import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

// 1.0.7 ① Drive UI 통합 후: 복원(가져오기) 진입점이 백업&복원 화면의 "복원" 버튼.
// 권한 거부 시 안내 SnackBar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    '"복원" 탭 → listBackups 권한 거부 → "Drive 권한이 필요해요" SnackBar',
    (tester) async {
      var listCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(
            listBackups: () async {
              listCalls++;
              return const DriveBackupListFailure(DriveBackupPermissionDenied());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final restore = find.text('복원');
      expect(restore, findsOneWidget);
      await tester.tap(restore);
      await tester.pumpAndSettle();

      expect(listCalls, 1, reason: '복원 진입 시 listBackups 1회 호출 기대');
      expect(find.text('Drive 권한이 필요해요'), findsOneWidget);
    },
  );
}
