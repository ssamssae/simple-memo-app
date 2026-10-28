import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/memo.dart';
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
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({
    super.key,
    this.uploadBackup,
    this.listBackups,
    this.downloadBackup,
    this.saveBackupFile,
    this.pickBackupFile,
  });

  final Future<DriveBackupResult> Function(List<Memo> memos)? uploadBackup;
  final Future<DriveBackupListResult> Function()? listBackups;
  final Future<List<int>> Function(String fileId)? downloadBackup;
  final Future<bool> Function(List<Memo> memos)? saveBackupFile;
  final Future<(int, int)?> Function()? pickBackupFile;

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
  bool get _busy => _isBackupRunning || _isRestoreRunning || _isFileRunning;
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  Future<void> _handleBackup() async {
    if (_busy) return;
    if (_activeMemos.isEmpty) {
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

  Future<void> _handleRestore() async {
    if (_busy) return;
    setState(() => _isRestoreRunning = true);
    final list = widget.listBackups ?? DriveBackupService.listBackups;
    final listResult = await list();
    if (!mounted) {
      return;
    }
    switch (listResult) {
      case DriveBackupListFailure(:final error):
        setState(() => _isRestoreRunning = false);
        _showDriveError(
          error,
          _Notices.of(context),
          actionLabel: AppStrings.of(context).driveImportLabel,
        );
      case DriveBackupListSuccess(:final entries):
        if (entries.isEmpty) {
          setState(() => _isRestoreRunning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).noBackupFileOnDrive)),
          );
          return;
        }
        final picked = entries.length == 1
            ? entries.single
            : await _pickBackup(entries);
        if (picked == null || !mounted) {
          if (mounted) setState(() => _isRestoreRunning = false);
          return;
        }
        await _importBackup(picked);
        if (mounted) setState(() => _isRestoreRunning = false);
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
    if (_activeMemos.isEmpty) {
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

  Future<DriveBackupEntry?> _pickBackup(List<DriveBackupEntry> entries) async {
    final palette = AppPalette.of(context);
    return showModalBottomSheet<DriveBackupEntry>(
      context: context,
      backgroundColor: palette.elevatedSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                AppStrings.of(context).driveBackupChoose,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (ctx, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: Icon(
                      Icons.description_outlined,
                      color: palette.textPrimary,
                    ),
                    title: Text(
                      _backupLabel(entry),
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () => Navigator.of(ctx).pop(entry),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TossSurfaceCard.radius),
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
                          AppStrings.of(
                            context,
                          ).backupTarget(_activeMemos.length),
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
                  TossSurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _handleBackup,
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: palette.onAccent,
                            minimumSize: const Size.fromHeight(52),
                            shape: buttonShape,
                          ),
                          icon: _isBackupRunning
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.onAccent,
                                  ),
                                )
                              : const Icon(Icons.backup_outlined),
                          label: Text(
                            _isBackupRunning
                                ? AppStrings.of(context).backingUp
                                : AppStrings.of(context).backupNow,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _handleRestore,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.accent,
                            side: BorderSide(color: palette.accent),
                            minimumSize: const Size.fromHeight(52),
                            shape: buttonShape,
                          ),
                          icon: _isRestoreRunning
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.accent,
                                  ),
                                )
                              : const Icon(Icons.restore_outlined),
                          label: Text(
                            _isRestoreRunning
                                ? AppStrings.of(context).restoring
                                : AppStrings.of(context).restore,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TossSurfaceCard(
                    child: Column(
                      children: [
                        TextButton.icon(
                          onPressed: _busy ? null : _handleFileBackup,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                          ),
                          icon: const Icon(Icons.save_alt),
                          label: Text(AppStrings.of(context).backupToFile),
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _handleFileRestore,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                          ),
                          icon: const Icon(Icons.folder_open),
                          label: Text(AppStrings.of(context).restoreFromFile),
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
