import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

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
}
