import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

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

  static Future<String> uploadJsonFileForTest(
    drive.DriveApi api, {
    required String folderId,
    required String filename,
    required List<int> jsonBytes,
  }) async {
    final media = drive.Media(
      Stream<List<int>>.fromIterable([jsonBytes]),
      jsonBytes.length,
      contentType: 'application/json',
    );
    final result = await api.files.create(
      drive.File()
        ..name = filename
        ..parents = [folderId]
        ..mimeType = 'application/json',
      uploadMedia: media,
      $fields: 'id',
    );
    return result.id!;
  }

  static Future<String> ensureMemoyoFolderForTest(drive.DriveApi api) async {
    const folderName = 'Memoyo';
    const folderMime = 'application/vnd.google-apps.folder';
    final query =
        "name = '$folderName' and mimeType = '$folderMime' and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = await api.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = folderMime,
      $fields: 'id',
    );
    return folder.id!;
  }
}
