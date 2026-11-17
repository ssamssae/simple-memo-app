import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/memo.dart';
import '../features/memos/services/icloud_memo_backup.dart';
import '../features/memos/services/memo_backup_archive.dart';
import '../services/drive_backup_service.dart';
import '../services/export_import_service.dart';
import '../services/memo_storage.dart';
import '../utils/app_palette.dart';
import '../widgets/toss_surface_card.dart';
import '../widgets/version_footer.dart';
import '../l10n/app_strings.dart';

// 백업 & 복원 화면 (1.0.7 ① Drive 백업 1버튼화).
// 기존에 메모 리스트 overflow 메뉴에 흩어져 있던 Drive 백업/가져오기/되돌리기를
// 설정 → "백업 & 복원" 단일 진입점으로 모은 화면.
//
// 백업 대상 = 활성 메모만(deletedAt == null) — 휴지통은 로컬 안전망이라 복원본에
// 섞이면 혼란(본진 결정 #6). 파일·Drive 백업은 같은 ZIP 형식을 사용한다.
//
// Drive 함수는 SettingsScreen 의 openReviewListing 패턴처럼 주입 가능 —
// 위젯 테스트에서 실제 sign-in 없이 mock 주입.
//
// 배치(T-261116-041, 대종님 11/16 — 한줄일기 #149 방식): 기본 백업은 로그인 없이
// (아이폰 = iCloud, 안드로이드 = 파일)이 맨 위, Google Drive 는 폰을 바꾸거나
// 아이폰 ↔ 안드로이드로 옮길 때 추천하는 칸으로 그 아래. 아이폰의 파일 백업은 맨 아래에 남긴다.
enum _BackupListPhase { loading, ready, failed }

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({
    super.key,
    this.uploadBackup,
    this.listBackups,
    this.downloadBackup,
    this.deleteBackup,
    this.saveBackupFile,
    this.pickBackupFile,
    this.icloud,
    this.platform,
    this.signOutDrive,
  });

  final Future<DriveBackupResult> Function(List<Memo> memos)? uploadBackup;
  final Future<DriveBackupListResult> Function()? listBackups;
  final Future<List<int>> Function(String fileId)? downloadBackup;

  /// Drive 백업 한 건 지우기. 비우면 [DriveBackupService.deleteBackup].
  final Future<void> Function(String fileId)? deleteBackup;
  final Future<bool> Function(List<Memo> memos)? saveBackupFile;
  final Future<(int, int)?> Function()? pickBackupFile;

  /// 시험이 iCloud 통로 대신 넣는다. 비우면 기기 구현.
  final ICloudMemoBackup? icloud;

  /// 시험이 기기 종류 대신 넣는다. 비우면 실제 기기 종류.
  final TargetPlatform? platform;

  /// 「다른 Google 계정 쓰기」. 비우면 [DriveBackupService.signOut].
  final Future<void> Function()? signOutDrive;

  static const _lastBackupKey = 'memoyo_last_backup_at';

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  List<Memo> _activeMemos = [];
  bool _isLoading = true;
  bool _isBackupRunning = false;
  bool _isRestoreRunning = false;
  bool _isFileRunning = false;
  bool _isICloudBackupRunning = false;
  bool _isICloudRestoreRunning = false;
  bool _isICloudDeleteRunning = false;
  bool _isDriveDeleteRunning = false;
  bool get _busy =>
      _isBackupRunning ||
      _isRestoreRunning ||
      _isFileRunning ||
      _isICloudBackupRunning ||
      _isICloudRestoreRunning ||
      _isICloudDeleteRunning ||
      _isDriveDeleteRunning;
  late final ICloudMemoBackup _icloud = widget.icloud ?? ICloudMemoBackup();
  bool get _isIOS =>
      (widget.platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  DateTime? _lastBackupAt;
  static const _listTimeout = Duration(seconds: 15);

  _BackupListPhase _icloudPhase = _BackupListPhase.loading;
  List<ICloudBackupFile> _icloudFiles = const [];
  int _icloudEpoch = 0;
  String? _icloudRestoringName;

  bool _driveListOpen = false;
  _BackupListPhase _drivePhase = _BackupListPhase.loading;
  List<DriveBackupEntry> _driveEntries = const [];
  int _driveEpoch = 0;
  String? _driveRestoringId;

  @override
  void initState() {
    super.initState();
    _load();
    // 아이폰 iCloud 칸이 이 화면에 있다. 열릴 때 목록을 불러 온다.
    // Drive 목록은 로그인 창이 뜰 수 있어 여기서 부르지 않는다.
    if (_isIOS) _loadICloudBackups();
  }

  Future<void> _load() async {
    // 옛 할 일은 loadMemos 가 메모로 옮겨 둔다(T-261113-024) — 완료한 메모도 함께 백업된다.
    final memos = await MemoStorage.loadMemos();
    final prefs = await SharedPreferences.getInstance();
    final lastRaw = prefs.getString(BackupRestoreScreen._lastBackupKey);
    if (!mounted) return;
    setState(() {
      _activeMemos = memos.where((m) => m.deletedAt == null).toList();
      _lastBackupAt = lastRaw == null ? null : DateTime.tryParse(lastRaw);
      _isLoading = false;
    });
  }

  bool get _nothingToBackUp => _activeMemos.isEmpty;

  Future<void> _handleBackup() async {
    if (_busy) return;
    if (_nothingToBackUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).noMemosToExport)),
      );
      return;
    }

    setState(() => _isBackupRunning = true);
    // The user may leave during the upload; the result is still reported.
    final notices = _Notices.of(context);
    notices.messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(notices.strings.driveBackupStarting),
          duration: Duration(seconds: 30),
        ),
      );

    final upload = widget.uploadBackup ?? DriveBackupService.uploadBackup;
    // 휴지통 제외 — 활성 메모만 백업(본진 결정 #6).
    final result = await upload(_activeMemos);
    if (mounted) setState(() => _isBackupRunning = false);

    if (result is DriveBackupSuccess) {
      await _recordBackupTime();
    }
    _showBackupResult(result, notices);
    if (result is DriveBackupSuccess && _driveListOpen) {
      await _loadDriveBackups(showLoading: true);
    }
  }

  Future<void> _recordBackupTime() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      BackupRestoreScreen._lastBackupKey,
      now.toIso8601String(),
    );
    if (!mounted) return;
    setState(() => _lastBackupAt = now);
  }

  void _showBackupResult(DriveBackupResult result, _Notices notices) {
    final strings = notices.strings;
    notices.messenger.hideCurrentSnackBar();
    switch (result) {
      case DriveBackupSuccess(:final folderUrl):
        notices.messenger.showSnackBar(
          SnackBar(
            content: Text(strings.driveSaved),
            // Action snackbars persist by default. Keep time to reach the action
            // for screen readers; otherwise dismiss the success notice normally.
            persist: notices.keepActionNotice,
            duration: const Duration(seconds: 4),
            showCloseIcon: true,
            action: SnackBarAction(
              label: strings.openMemoyoFolder,
              onPressed: () async {
                final uri = Uri.parse(folderUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ),
        );
      case DriveBackupNetworkError():
        notices.show(strings.checkInternet);
      case DriveBackupPermissionDenied():
        notices.show(strings.drivePermissionNeeded);
      case DriveBackupQuotaExceeded():
        notices.show(strings.driveQuotaExceeded);
      case DriveBackupPhotoUnavailable():
        notices.show(strings.backupPhotoUnavailable);
      case DriveBackupTooLarge():
        notices.show(strings.backupTooLarge);
      case DriveBackupUnknown(:final message):
        notices.show(strings.driveBackupFailed(message));
    }
  }

  Future<void> _loadICloudBackups({bool showLoading = false}) async {
    final epoch = ++_icloudEpoch;
    if (showLoading && mounted) {
      setState(() => _icloudPhase = _BackupListPhase.loading);
    }
    try {
      final files = await _icloud.list().timeout(_listTimeout);
      if (!mounted || epoch != _icloudEpoch) return;
      final sorted = [...files]..sort((a, b) => b.name.compareTo(a.name));
      setState(() {
        _icloudFiles = sorted;
        _icloudPhase = _BackupListPhase.ready;
      });
    } catch (_) {
      if (!mounted || epoch != _icloudEpoch) return;
      setState(() => _icloudPhase = _BackupListPhase.failed);
    }
  }

  Future<void> _loadDriveBackups({required bool showLoading}) async {
    final epoch = ++_driveEpoch;
    if (showLoading && mounted) {
      setState(() {
        _driveListOpen = true;
        _drivePhase = _BackupListPhase.loading;
      });
    }
    try {
      final list = widget.listBackups ?? DriveBackupService.listBackups;
      final result = await list().timeout(_listTimeout);
      if (!mounted || epoch != _driveEpoch) return;
      switch (result) {
        case DriveBackupListFailure(:final error):
          setState(() => _drivePhase = _BackupListPhase.failed);
          _showDriveError(
            error,
            _Notices.of(context),
            actionLabel: AppStrings.of(context).driveImportLabel,
          );
        case DriveBackupListSuccess(:final entries):
          setState(() {
            _driveEntries = _newestDriveFirst(entries);
            _drivePhase = _BackupListPhase.ready;
          });
      }
    } catch (_) {
      if (!mounted || epoch != _driveEpoch) return;
      setState(() => _drivePhase = _BackupListPhase.failed);
    }
  }

  Future<void> _openDriveList() async {
    if (_busy) return;
    await _loadDriveBackups(showLoading: true);
  }

  Future<void> _restoreDrive(DriveBackupEntry backup) async {
    if (_busy) return;
    setState(() {
      _isRestoreRunning = true;
      _driveRestoringId = backup.id;
    });
    final notices = _Notices.of(context);
    notices.messenger.hideCurrentSnackBar();
    try {
      await _importBackup(backup);
    } finally {
      if (mounted) {
        setState(() {
          _isRestoreRunning = false;
          _driveRestoringId = null;
        });
      }
    }
  }

  Future<void> _importBackup(DriveBackupEntry backup) async {
    // Downloading can take a while; report even if the user leaves meanwhile.
    final notices = _Notices.of(context);
    try {
      final download =
          widget.downloadBackup ?? DriveBackupService.downloadBackup;
      final source = await download(backup.id);
      final (incoming, total) = await ExportImportService.importBytes(source);
      await _showImported((incoming, total), notices);
    } on FormatException {
      notices.show(notices.strings.invalidBackupFile);
    } catch (e) {
      _showDriveError(
        DriveBackupService.mapErrorForTest(e),
        notices,
        actionLabel: notices.strings.driveImportLabel,
      );
    }
  }

  Future<void> _showImported((int, int)? result, _Notices notices) async {
    if (result == null) return;
    final (incoming, total) = result;
    if (incoming == 0) {
      notices.show(notices.strings.noMemosToImport);
      return;
    }
    if (mounted) await _load();
    notices.messenger.showSnackBar(
      SnackBar(
        content: Text(notices.strings.importedMemos(incoming, total)),
        // Same rule as the Drive success notice: persist only for screen readers.
        persist: notices.keepActionNotice,
        duration: const Duration(seconds: 5),
        showCloseIcon: true,
        action: SnackBarAction(
          label: notices.strings.undo,
          onPressed: () => _handleUndoImport(notices),
        ),
      ),
    );
  }

  Future<void> _handleFileBackup() async {
    if (_busy) return;
    if (_nothingToBackUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).noMemosToExport)),
      );
      return;
    }
    setState(() => _isFileRunning = true);
    final notices = _Notices.of(context);
    notices.messenger.hideCurrentSnackBar();
    try {
      final saved =
          await (widget.saveBackupFile ?? ExportImportService.saveBackupFile)(
            _activeMemos,
          );
      if (saved) {
        await _recordBackupTime();
        notices.show(notices.strings.backupFileSaved);
      }
    } catch (error) {
      _showFileError(error, notices);
    } finally {
      if (mounted) setState(() => _isFileRunning = false);
    }
  }

  Future<void> _handleFileRestore() async {
    if (_busy) return;
    setState(() => _isFileRunning = true);
    final notices = _Notices.of(context);
    notices.messenger.hideCurrentSnackBar();
    try {
      await _showImported(
        await (widget.pickBackupFile ?? ExportImportService.pickAndImport)(),
        notices,
      );
    } catch (error) {
      _showFileError(error, notices);
    } finally {
      if (mounted) setState(() => _isFileRunning = false);
    }
  }

  Future<void> _handleICloudBackup() async {
    if (_busy) return;
    if (_nothingToBackUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).noMemosToExport)),
      );
      return;
    }
    setState(() => _isICloudBackupRunning = true);
    final notices = _Notices.of(context);
    notices.messenger.hideCurrentSnackBar();
    var savedToICloud = false;
    try {
      if (!await _icloud.isAvailable()) {
        notices.show(notices.strings.icloudUnavailable);
        return;
      }
      // 휴지통 제외 — 활성 메모만(Drive·파일 백업과 같은 zip).
      final bytes = await ExportImportService.exportBytes(_activeMemos);
      await _icloud.upload(bytes);
      await _recordBackupTime();
      notices.show(notices.strings.icloudSaved);
      savedToICloud = true;
    } catch (error) {
      notices.show(_icloudErrorMessage(error, notices.strings));
    } finally {
      if (mounted) setState(() => _isICloudBackupRunning = false);
    }
    if (savedToICloud) await _loadICloudBackups(showLoading: true);
  }

  Future<void> _restoreICloud(ICloudBackupFile file) async {
    if (_busy) return;
    setState(() {
      _isICloudRestoreRunning = true;
      _icloudRestoringName = file.name;
    });
    final notices = _Notices.of(context);
    notices.messenger.hideCurrentSnackBar();
    try {
      final bytes = await _icloud.download(file.name);
      // Drive 복원과 같이 지금 메모에 합치고, 알림에서 되돌릴 수 있다.
      await _showImported(
        await ExportImportService.importBytes(bytes),
        notices,
      );
    } catch (error) {
      notices.show(_icloudErrorMessage(error, notices.strings));
    } finally {
      if (mounted) {
        setState(() {
          _isICloudRestoreRunning = false;
          _icloudRestoringName = null;
        });
      }
    }
  }

  Future<void> _deleteICloud(ICloudBackupFile file) async {
    if (_busy) return;
    if (!await _askDeleteBackup()) return;
    if (!mounted) return;
    setState(() => _isICloudDeleteRunning = true);
    final notices = _Notices.of(context);
    try {
      await _icloud.delete(file.name);
      await _loadICloudBackups(showLoading: true);
    } catch (error) {
      notices.show(_icloudErrorMessage(error, notices.strings));
    } finally {
      if (mounted) setState(() => _isICloudDeleteRunning = false);
    }
  }

  Future<void> _deleteDrive(DriveBackupEntry entry) async {
    if (_busy) return;
    if (!await _askDeleteBackup()) return;
    if (!mounted) return;
    setState(() => _isDriveDeleteRunning = true);
    final notices = _Notices.of(context);
    try {
      await (widget.deleteBackup ?? DriveBackupService.deleteBackup)(entry.id);
      await _loadDriveBackups(showLoading: true);
    } catch (error) {
      _showDriveError(
        DriveBackupService.mapErrorForTest(error),
        notices,
        actionLabel: notices.strings.deleteThisBackup,
      );
    } finally {
      if (mounted) setState(() => _isDriveDeleteRunning = false);
    }
  }

  Future<bool> _askDeleteBackup() async {
    final palette = AppPalette.of(context);
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TossSurfaceCard.radius),
        ),
        content: Text(
          strings.deleteBackupConfirm,
          style: TextStyle(color: palette.textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            key: const Key('backup-delete-cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
            child: Text(strings.cancel),
          ),
          TextButton(
            key: const Key('backup-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            child: Text(strings.deleteThisBackup),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _icloudErrorMessage(Object error, AppStrings strings) =>
      switch (error) {
        PlatformException(code: 'unavailable') => strings.icloudUnavailable,
        BackupPhotoUnavailableException() => strings.backupPhotoUnavailable,
        BackupSizeException() => strings.backupTooLarge,
        FormatException() => strings.invalidBackupFile,
        _ => strings.icloudFailed,
      };

  Future<void> _handleSwitchAccount() async {
    if (_busy) return;
    final notices = _Notices.of(context);
    try {
      await (widget.signOutDrive ?? DriveBackupService.signOut)();
      notices.show(notices.strings.googleAccountCleared);
    } catch (error) {
      _showDriveError(
        DriveBackupService.mapErrorForTest(error),
        notices,
        actionLabel: notices.strings.switchGoogleAccount,
      );
    }
  }

  void _showFileError(Object error, _Notices notices) {
    final strings = notices.strings;
    final message = switch (error) {
      BackupPhotoUnavailableException() => strings.backupPhotoUnavailable,
      BackupSizeException() => strings.backupTooLarge,
      FormatException() => strings.invalidBackupFile,
      _ => strings.fileBackupFailed,
    };
    notices.show(message);
  }

  // Runs from the import notice, which can outlive this screen.
  Future<void> _handleUndoImport(_Notices notices) async {
    // Busy flags guard this screen's buttons only. After the screen is gone,
    // ExportImportService's restore lock prevents overlapping restores.
    if (mounted && _busy) return;
    if (mounted) setState(() => _isFileRunning = true);
    try {
      final restored = await ExportImportService.undoImport();
      if (restored == null) return;
      if (mounted) await _load();
      notices.show(notices.strings.restoredPrevious(restored.length));
    } catch (error) {
      _showFileError(error, notices);
    } finally {
      if (mounted) setState(() => _isFileRunning = false);
    }
  }

  void _showDriveError(
    DriveBackupResult error,
    _Notices notices, {
    String? actionLabel,
  }) {
    final strings = notices.strings;
    final label = actionLabel ?? strings.driveBackupLabel;
    final message = switch (error) {
      DriveBackupNetworkError() => strings.checkInternet,
      DriveBackupPermissionDenied() => strings.drivePermissionNeeded,
      DriveBackupQuotaExceeded() => strings.driveQuotaExceeded,
      DriveBackupPhotoUnavailable() => strings.backupPhotoUnavailable,
      DriveBackupTooLarge() => strings.backupTooLarge,
      DriveBackupUnknown(:final message) => strings.actionFailed(
        label,
        message,
      ),
      DriveBackupSuccess() => strings.actionDone(label),
    };
    notices.show(message);
  }

  List<DriveBackupEntry> _newestDriveFirst(List<DriveBackupEntry> entries) {
    final sorted = [...entries];
    if (sorted.every((entry) => entry.modifiedTime != null)) {
      sorted.sort((a, b) => b.modifiedTime!.compareTo(a.modifiedTime!));
    }
    return sorted;
  }

  String _backupLabel(DriveBackupEntry entry) {
    final match = RegExp(
      r'memoyo-export-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})',
    ).firstMatch(entry.name);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)}:${match.group(3)}:${match.group(4)}';
    }
    return entry.name;
  }

  Widget _backupList({
    required AppPalette palette,
    required AppStrings strings,
    required _BackupListPhase phase,
    required int count,
    required VoidCallback onRetry,
    required Key retryKey,
    required List<Widget> rows,
  }) {
    final style = TextStyle(
      color: palette.textSecondary,
      fontSize: 13,
      height: 1.4,
    );
    return switch (phase) {
      _BackupListPhase.loading => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _spinner(palette.accent),
            const SizedBox(width: 8),
            Text(strings.backupListLoading, style: style),
          ],
        ),
      ),
      _BackupListPhase.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.backupListFailed, style: style),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: retryKey,
              onPressed: _busy ? null : onRetry,
              style: TextButton.styleFrom(foregroundColor: palette.accent),
              child: Text(strings.tryAgain),
            ),
          ),
        ],
      ),
      _BackupListPhase.ready when count == 0 => Text(
        strings.noBackupsYet,
        style: style,
      ),
      _BackupListPhase.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    };
  }

  Widget _backupActions({
    required AppPalette palette,
    required AppStrings strings,
    required String label,
    required String? sizeLabel,
    required bool restoring,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
    required Key restoreKey,
    required Key deleteKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sizeLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sizeLabel,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ],
          Row(
            children: [
              TextButton(
                key: restoreKey,
                onPressed: _busy ? null : onRestore,
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(restoring ? strings.restoring : strings.restore),
              ),
              TextButton(
                key: deleteKey,
                onPressed: _busy ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: palette.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(strings.deleteThisBackup),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spinner(Color color) => SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );

  Widget _cardHeader(AppPalette palette, String title, String notice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          notice,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _defaultCard({
    required AppPalette palette,
    required String title,
    required String notice,
    required Widget primary,
    required Widget secondary,
  }) {
    return TossSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(palette, title, notice),
          const SizedBox(height: 16),
          primary,
          const SizedBox(height: 12),
          secondary,
        ],
      ),
    );
  }

  String _lastBackupLabel() {
    final at = _lastBackupAt;
    if (at == null) return AppStrings.of(context).neverBackedUp;
    String two(int n) => n.toString().padLeft(2, '0');
    return AppStrings.of(context).lastBackupAt(
      '${at.year}.${two(at.month)}.${two(at.day)} ${two(at.hour)}:${two(at.minute)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final strings = AppStrings.of(context);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TossSurfaceCard.radius),
    );
    final primaryStyle = FilledButton.styleFrom(
      backgroundColor: palette.accent,
      foregroundColor: palette.onAccent,
      minimumSize: const Size.fromHeight(52),
      shape: buttonShape,
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: palette.accent,
      side: BorderSide(color: palette.accent),
      minimumSize: const Size.fromHeight(52),
      shape: buttonShape,
    );
    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: const SafeArea(child: VersionFooter()),
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppStrings.of(context).backupRestore,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TossSurfaceCard(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 56,
                          color: palette.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.of(context).backupIntro,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.of(context)
                              .backupTarget(_activeMemos.length),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _lastBackupLabel(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.of(context).photosIncludedInBackup,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isIOS)
                    TossSurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _cardHeader(
                            palette,
                            strings.icloudTitle,
                            strings.icloudNotice,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _handleICloudBackup,
                            style: primaryStyle,
                            icon: _isICloudBackupRunning
                                ? _spinner(palette.onAccent)
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(strings.backupToICloud),
                          ),
                          const SizedBox(height: 12),
                          _backupList(
                            palette: palette,
                            strings: strings,
                            phase: _icloudPhase,
                            count: _icloudFiles.length,
                            onRetry: () =>
                                _loadICloudBackups(showLoading: true),
                            retryKey: const Key('icloud-list-retry'),
                            rows: [
                              for (final file in _icloudFiles)
                                _backupActions(
                                  palette: palette,
                                  strings: strings,
                                  label: file.label,
                                  sizeLabel: strings.backupFileSize(file.size),
                                  restoring: _icloudRestoringName == file.name,
                                  onRestore: () => _restoreICloud(file),
                                  onDelete: () => _deleteICloud(file),
                                  restoreKey: Key(
                                    'icloud-restore-${file.name}',
                                  ),
                                  deleteKey: Key('icloud-delete-${file.name}'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    _defaultCard(
                      palette: palette,
                      title: strings.fileBackupTitle,
                      notice: strings.fileBackupNotice,
                      primary: FilledButton.icon(
                        onPressed: _busy ? null : _handleFileBackup,
                        style: primaryStyle,
                        icon: const Icon(Icons.save_alt),
                        label: Text(strings.backupToFile),
                      ),
                      secondary: OutlinedButton.icon(
                        onPressed: _busy ? null : _handleFileRestore,
                        style: outlinedStyle,
                        icon: const Icon(Icons.folder_open),
                        label: Text(strings.restoreFromFile),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      strings.moveDeviceHint,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  TossSurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _cardHeader(
                          palette,
                          strings.moveDeviceTitle,
                          strings.moveDeviceNotice,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _handleBackup,
                          style: outlinedStyle,
                          icon: _isBackupRunning
                              ? _spinner(palette.accent)
                              : const Icon(Icons.backup_outlined),
                          label: Text(
                            _isBackupRunning
                                ? strings.backingUp
                                : strings.backupNow,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _openDriveList,
                          style: outlinedStyle,
                          icon: const Icon(Icons.list_alt),
                          label: Text(strings.showDriveBackupList),
                        ),
                        if (_driveListOpen) ...[
                          const SizedBox(height: 12),
                          _backupList(
                            palette: palette,
                            strings: strings,
                            phase: _drivePhase,
                            count: _driveEntries.length,
                            onRetry: () => _loadDriveBackups(showLoading: true),
                            retryKey: const Key('drive-list-retry'),
                            rows: [
                              for (final entry in _driveEntries)
                                _backupActions(
                                  palette: palette,
                                  strings: strings,
                                  label: _backupLabel(entry),
                                  sizeLabel: entry.size == null
                                      ? null
                                      : strings.backupFileSize(entry.size!),
                                  restoring: _driveRestoringId == entry.id,
                                  onRestore: () => _restoreDrive(entry),
                                  onDelete: () => _deleteDrive(entry),
                                  restoreKey: Key('drive-restore-${entry.id}'),
                                  deleteKey: Key('drive-delete-${entry.id}'),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _busy ? null : _handleSwitchAccount,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                          ),
                          child: Text(strings.switchGoogleAccount),
                        ),
                      ],
                    ),
                  ),
                  // 아이폰도 파일 백업(이미 출시된 기능)을 맨 아래에 남긴다.
                  if (_isIOS)
                    TossSurfaceCard(
                      child: Column(
                        children: [
                          TextButton.icon(
                            onPressed: _busy ? null : _handleFileBackup,
                            style: TextButton.styleFrom(
                              foregroundColor: palette.textPrimary,
                            ),
                            icon: const Icon(Icons.save_alt),
                            label: Text(strings.backupToFile),
                          ),
                          TextButton.icon(
                            onPressed: _busy ? null : _handleFileRestore,
                            style: TextButton.styleFrom(
                              foregroundColor: palette.textPrimary,
                            ),
                            icon: const Icon(Icons.folder_open),
                            label: Text(strings.restoreFromFile),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Where backup and restore results are shown. Captured while the screen is
/// mounted: the app-wide messenger outlives this screen, so an upload, download
/// or undo that finishes after the user leaves is still reported there.
class _Notices {
  _Notices.of(BuildContext context)
    : messenger = ScaffoldMessenger.of(context),
      strings = AppStrings.of(context),
      keepActionNotice = MediaQuery.accessibleNavigationOf(context);

  final ScaffoldMessengerState messenger;
  final AppStrings strings;

  /// Action notices persist by default; keep them only for screen readers.
  final bool keepActionNotice;

  void show(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));
}
