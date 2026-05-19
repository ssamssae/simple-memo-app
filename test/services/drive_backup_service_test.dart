import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  group('DriveBackupResult', () {
    test('Success holds folderUrl', () {
      const r = DriveBackupSuccess('https://drive.google.com/drive/folders/abc');
      expect(r.folderUrl, 'https://drive.google.com/drive/folders/abc');
    });

    test('NetworkError is distinct from Unknown', () {
      const a = DriveBackupNetworkError();
      const b = DriveBackupUnknown('boom');
      expect(a, isNot(equals(b)));
    });

    test('PermissionDenied / QuotaExceeded / Unknown all subtype DriveBackupResult', () {
      const list = <DriveBackupResult>[
        DriveBackupSuccess('x'),
        DriveBackupNetworkError(),
        DriveBackupPermissionDenied(),
        DriveBackupQuotaExceeded(),
        DriveBackupUnknown('msg'),
      ];
      expect(list.length, 5);
    });
  });

  group('DriveBackupService._obtainAuthClient', () {
    test('signIn 이 null 반환 시 PermissionDenied', () async {
      final gsi = _MockGoogleSignIn();
      when(() => gsi.signIn()).thenAnswer((_) async => null);
      final result = await DriveBackupService.obtainAuthClientForTest(gsi);
      expect(result, isA<DriveBackupPermissionDenied>());
    });
  });
}
