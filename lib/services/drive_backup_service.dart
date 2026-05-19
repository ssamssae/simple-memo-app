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
