import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:simple_memo_app/services/drive_backup_service.dart';

void main() {
  group('DriveBackupService.mapError — 추가 status 코드', () {
    test('DetailedApiRequestError 429 rate limit → Unknown (fallback)', () {
      // 429 는 PermissionDenied(401/403) / QuotaExceeded(403+storageQuotaExceeded)
      // 매칭에 안 잡혀 Unknown 으로 떨어지는 게 현재 계약. 후속 작업에서 전용
      // RateLimited 케이스 추가 시 이 테스트가 깨지면 그 시점에 명시적 갱신.
      final err = drive.DetailedApiRequestError(
        429,
        'Rate Limit Exceeded',
      );
      final r = DriveBackupService.mapErrorForTest(err);
      expect(r, isA<DriveBackupUnknown>());
      expect((r as DriveBackupUnknown).message, contains('Rate Limit'));
    });

    test('DetailedApiRequestError 500 server error → Unknown (fallback)', () {
      // 5xx 도 401/403/quota 매칭에 안 잡혀 Unknown 으로 떨어짐. 일시적
      // 서버 오류는 별 분류 없이 사용자에게 generic 한 'Drive 백업 실패' 노출.
      final err = drive.DetailedApiRequestError(
        500,
        'Internal Server Error',
      );
      final r = DriveBackupService.mapErrorForTest(err);
      expect(r, isA<DriveBackupUnknown>());
      expect((r as DriveBackupUnknown).message, contains('500'));
    });

    test('DetailedApiRequestError 403 (storageQuotaExceeded 미포함) → PermissionDenied',
        () {
      // 403 + storageQuotaExceeded 텍스트가 없으면 PermissionDenied 로 떨어짐.
      // PR #14 의 storageQuotaExceeded 분기와 상보 — 403 의 다른 사유 보호.
      final err = drive.DetailedApiRequestError(
        403,
        'insufficientPermissions',
      );
      final r = DriveBackupService.mapErrorForTest(err);
      expect(r, isA<DriveBackupPermissionDenied>());
    });
  });
}
