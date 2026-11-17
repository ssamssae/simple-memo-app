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

  testWidgets('화면을 열 때는 목록을 부르지 않고, 목록 보기에서 권한 거부를 알려 준다', (tester) async {
    _tallView(tester);
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

    expect(listCalls, 0, reason: '화면을 열 때 Drive 목록·로그인을 부르지 않는다');
    expect(find.text('복원'), findsNothing);
    await tester.tap(find.text('Drive 백업 목록 보기'));
    await tester.pumpAndSettle();

    expect(listCalls, 1, reason: '목록 보기에서 listBackups 1회');
    expect(find.text('목록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('Drive 권한이 필요해요'), findsOneWidget);
    expect(find.text('Drive 백업 선택'), findsNothing);
  });
}

// T-261116-041 — 백업 화면 맨 위에 기본(로그인 없는) 칸이 생겨 Drive 단추가 아래로 내려갔다.
// 목록은 보이는 곳만 그리므로 화면을 키워 모든 단추를 그려 둔다.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
