import 'dart:typed_data';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../models/memo.dart';
import '../features/memos/services/memo_backup_archive.dart';
import 'export_import_service.dart';

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

class DriveBackupPhotoUnavailable extends DriveBackupResult {
  const DriveBackupPhotoUnavailable();
}

class DriveBackupTooLarge extends DriveBackupResult {
  const DriveBackupTooLarge();
}

class DriveBackupUnknown extends DriveBackupResult {
  final String message;
  const DriveBackupUnknown(this.message);
}

class DriveBackupEntry {
  final String id;
  final String name;
  final DateTime? modifiedTime;

  const DriveBackupEntry({
    required this.id,
    required this.name,
    this.modifiedTime,
  });
}

sealed class DriveBackupListResult {
  const DriveBackupListResult();
}

class DriveBackupListSuccess extends DriveBackupListResult {
  final List<DriveBackupEntry> entries;
  const DriveBackupListSuccess(this.entries);
}

class DriveBackupListFailure extends DriveBackupListResult {
  final DriveBackupResult error;
  const DriveBackupListFailure(this.error);
}

class DriveBackupDownloadAuthException implements Exception {
  const DriveBackupDownloadAuthException();
}

class DriveBackupService {
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  // Android: google-services.json 부재로 default OAuth client 미해결 → ApiException 10
  // (DEVELOPER_ERROR). Web OAuth client 의 serverClientId 박아 platform-independent
  // sign-in. iOS 는 Info.plist GIDClientID 가 별도로 적용.
  static const _serverClientId =
      '601847949978-8esieuqqqeokdeh1erp6sjjl1m9h4rgn.apps.googleusercontent.com';

  // google_sign_in v7: 생성자 대신 싱글톤 instance + initialize() 1회 호출.
  static final GoogleSignIn _signIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  // v7: 인증(authenticate)과 인가(authorizeScopes)가 분리됨. 사용자가 취소하면
  // GoogleSignInException(canceled)을 던지므로 null 로 변환해 기존 호출부의
  // "null → PermissionDenied" 의미를 그대로 유지한다.
  static Future<GoogleSignInClientAuthorization?> _authorize() async {
    await _ensureInitialized();
    final GoogleSignInAccount account;
    try {
      account = await _signIn.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    return account.authorizationClient.authorizeScopes(_scopes);
  }

  static DriveBackupResult mapErrorForTest(Object e) {
    if (e is BackupPhotoUnavailableException) return const DriveBackupPhotoUnavailable();
    if (e is BackupSizeException) return const DriveBackupTooLarge();
    if (e is SocketException) return const DriveBackupNetworkError();
    if (e is DriveBackupDownloadAuthException) {
      return const DriveBackupPermissionDenied();
    }
    if (e is GoogleSignInException) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return const DriveBackupPermissionDenied();
      }
      return DriveBackupUnknown(e.toString());
    }
    if (e is drive.DetailedApiRequestError) {
      if (e.status == 403 &&
          (e.message?.contains('storageQuotaExceeded') ?? false)) {
        return const DriveBackupQuotaExceeded();
      }
      if (e.status == 401 || e.status == 403) {
        return const DriveBackupPermissionDenied();
      }
    }
    return DriveBackupUnknown(e.toString());
  }

  static Future<DriveBackupListResult> listBackups() async {
    try {
      final authz = await _authorize();
      if (authz == null) {
        return const DriveBackupListFailure(DriveBackupPermissionDenied());
      }

      final api = drive.DriveApi(authz.authClient(scopes: _scopes));
      final folderId = await findMemoyoFolderForTest(api);
      if (folderId == null) {
        return const DriveBackupListSuccess([]);
      }
      final entries = await listBackupsInFolderForTest(api, folderId);
      return DriveBackupListSuccess(entries);
    } catch (e) {
      return DriveBackupListFailure(mapErrorForTest(e));
    }
  }

  static Future<List<DriveBackupEntry>> listBackupsInFolderForTest(
    drive.DriveApi api,
    String folderId,
  ) async {
    final query =
        "'$folderId' in parents and (mimeType = 'application/json' or mimeType = 'application/zip') and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, modifiedTime)',
    );
    final files = list.files ?? [];
    return [
      for (final f in files)
        if (f.id != null)
          DriveBackupEntry(
            id: f.id!,
            name: f.name ?? f.id!,
            modifiedTime: f.modifiedTime,
          ),
    ];
  }

  static Future<Uint8List> downloadBackup(String fileId) async {
    final authz = await _authorize();
    if (authz == null) {
      throw const DriveBackupDownloadAuthException();
    }
    final api = drive.DriveApi(authz.authClient(scopes: _scopes));
    return downloadBackupContentForTest(api, fileId);
  }

  static Future<Uint8List> downloadBackupContentForTest(
    drive.DriveApi api,
    String fileId,
  ) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      if (bytes.length + chunk.length > MemoBackupArchive.maxBytes) throw BackupSizeException();
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Future<DriveBackupResult> uploadBackup(List<Memo> memos) async {
    try {
      final bytes = await ExportImportService.exportBytes(memos);
      final authz = await _authorize();
      if (authz == null) return const DriveBackupPermissionDenied();

      final api = drive.DriveApi(authz.authClient(scopes: _scopes));
      final folderId = await ensureMemoyoFolderForTest(api);

      await uploadBackupFileForTest(
        api,
        folderId: folderId,
        filename: ExportImportService.backupFileName(),
        bytes: bytes,
      );

      await rotateForTest(api, folderId: folderId, keep: 7);

      final folderUrl = 'https://drive.google.com/drive/folders/$folderId';
      return DriveBackupSuccess(folderUrl);
    } catch (e) {
      return mapErrorForTest(e);
    }
  }

  static Future<void> rotateForTest(
    drive.DriveApi api, {
    required String folderId,
    required int keep,
  }) async {
    final query =
        "'$folderId' in parents and (mimeType = 'application/json' or mimeType = 'application/zip') and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'createdTime',
      $fields: 'files(id, name, createdTime)',
    );
    final files = list.files ?? [];
    if (files.length <= keep) return;
    final excess = files.length - keep;
    for (int i = 0; i < excess; i++) {
      await api.files.delete(files[i].id!);
    }
  }

  static Future<String> uploadJsonFileForTest(
    drive.DriveApi api, {
    required String folderId,
    required String filename,
    required List<int> jsonBytes,
  }) async {
    return uploadBackupFileForTest(api, folderId: folderId, filename: filename,
      bytes: jsonBytes, contentType: 'application/json');
  }

  static Future<String> uploadBackupFileForTest(
    drive.DriveApi api, {
    required String folderId,
    required String filename,
    required List<int> bytes,
    String contentType = 'application/zip',
  }) async {
    final media = drive.Media(
      Stream<List<int>>.fromIterable([bytes]),
      bytes.length,
      contentType: contentType,
    );
    final result = await api.files.create(
      drive.File()
        ..name = filename
        ..parents = [folderId]
        ..mimeType = contentType,
      uploadMedia: media,
      $fields: 'id',
    );
    return result.id!;
  }

  static Future<List<Memo>?> downloadLatestForTest(drive.DriveApi api) async {
    final folderId = await ensureMemoyoFolderForTest(api);
    final query =
        "'$folderId' in parents and (mimeType = 'application/json' or mimeType = 'application/zip') and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, createdTime)',
    );
    final files = list.files ?? [];
    if (files.isEmpty) return null;
    final latest = files.first;
    final bytes = await downloadBackupContentForTest(api, latest.id!);
    return MemoBackupArchive.decode(bytes).memos;
  }

  static Future<String> ensureMemoyoFolderForTest(drive.DriveApi api) async {
    final existingId = await findMemoyoFolderForTest(api);
    if (existingId != null) return existingId;

    const folderName = 'Memoyo';
    const folderMime = 'application/vnd.google-apps.folder';
    final folder = await api.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = folderMime,
      $fields: 'id',
    );
    return folder.id!;
  }

  static Future<String?> findMemoyoFolderForTest(drive.DriveApi api) async {
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
    return null;
  }
}
