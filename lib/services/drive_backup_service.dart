import 'package:google_sign_in/google_sign_in.dart';

sealed class DriveBackupResult {
  const DriveBackupResult();
}

class DriveBackupSuccess extends DriveBackupResult {
  final String folderUrl;
  const DriveBackupSuccess(this.folderUrl);
}

class DriveBackupNetworkError extends DriveBackupResult {
  const DriveBackupNetworkError();
}

class DriveBackupPermissionDenied extends DriveBackupResult {
  const DriveBackupPermissionDenied();
}

class DriveBackupQuotaExceeded extends DriveBackupResult {
  const DriveBackupQuotaExceeded();
}

class DriveBackupUnknown extends DriveBackupResult {
  final String message;
  const DriveBackupUnknown(this.message);
}

class DriveBackupService {
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  static final _signIn = GoogleSignIn(scopes: _scopes);

  static Future<DriveBackupResult?> obtainAuthClientForTest(
      GoogleSignIn gsi) async {
    final account = await gsi.signIn();
    if (account == null) {
      return const DriveBackupPermissionDenied();
    }
    return null;
  }
}
