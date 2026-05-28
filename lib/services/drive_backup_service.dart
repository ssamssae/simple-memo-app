import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../models/memo.dart';

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
  // Android: google-services.json 부재로 default OAuth client 미해결 → ApiException 10
  // (DEVELOPER_ERROR). Web OAuth client 의 serverClientId 박아 platform-independent
  // sign-in. iOS 는 Info.plist GIDClientID 가 별도로 적용.
  static final _signIn = GoogleSignIn(
    serverClientId:
        '601847949978-8esieuqqqeokdeh1erp6sjjl1m9h4rgn.apps.googleusercontent.com',
    scopes: _scopes,
  );

  static Future<DriveBackupResult?> obtainAuthClientForTest(
      GoogleSignIn gsi) async {
    final account = await gsi.signIn();
    if (account == null) {
      return const DriveBackupPermissionDenied();
    }
    return null;
  }

  static DriveBackupResult mapErrorForTest(Object e) {
    if (e is SocketException) return const DriveBackupNetworkError();
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

  static Future<DriveBackupResult> uploadBackup(List<Memo> memos) async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return const DriveBackupPermissionDenied();
      final authClient = await _signIn.authenticatedClient();
      if (authClient == null) return const DriveBackupPermissionDenied();

      final api = drive.DriveApi(authClient);
      final folderId = await ensureMemoyoFolderForTest(api);

      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filename = 'memoyo-export-$ts.json';
      final jsonStr = Memo.encodeList(memos);
      final bytes = utf8.encode(jsonStr);

      await uploadJsonFileForTest(
        api,
        folderId: folderId,
        filename: filename,
        jsonBytes: bytes,
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
        "'$folderId' in parents and mimeType = 'application/json' and trashed = false";
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

  static Future<List<Memo>?> downloadLatestForTest(drive.DriveApi api) async {
    final folderId = await ensureMemoyoFolderForTest(api);
    final query =
        "'$folderId' in parents and mimeType = 'application/json' and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, createdTime)',
    );
    final files = list.files ?? [];
    if (files.isEmpty) return null;
    final latest = files.first;
    final media = await api.files.get(
      latest.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    final jsonStr = utf8.decode(bytes);
    return Memo.decodeList(jsonStr);
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
