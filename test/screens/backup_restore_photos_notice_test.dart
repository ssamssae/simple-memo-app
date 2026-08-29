import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

// 1단계(T-260829-022): 백업 화면엔 사진 파일명만 실리고 실물은 안 간다는 안내.
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

  testWidgets('백업 화면에 「사진은 백업에 포함되지 않습니다」 안내', (tester) async {
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

    expect(find.text('사진은 백업에 포함되지 않습니다'), findsOneWidget);
  });
}
