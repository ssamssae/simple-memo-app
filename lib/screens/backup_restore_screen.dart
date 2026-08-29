import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/memo.dart';
import '../services/drive_backup_service.dart';
import '../services/export_import_service.dart';
import '../services/memo_storage.dart';
import '../utils/app_palette.dart';
import '../widgets/version_footer.dart';
import '../l10n/app_strings.dart';


// 백업 & 복원 화면 (1.0.7 ① Drive 백업 1버튼화).
// 기존에 메모 리스트 overflow 메뉴에 흩어져 있던 Drive 백업/가져오기/되돌리기를
// 설정 → "백업 & 복원" 단일 진입점으로 모은 화면.
//
// 백업 대상 = 활성 메모만(deletedAt == null) — 휴지통은 로컬 안전망이라 복원본에
// 섞이면 혼란(본진 결정 #6). DriveBackupService 는 무수정, 호출만 이 화면으로 이동.
//
// Drive 함수는 SettingsScreen 의 openReviewListing 패턴처럼 주입 가능 —
// 위젯 테스트에서 실제 sign-in 없이 mock 주입.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({
    super.key,
    this.uploadBackup,
    this.listBackups,
    this.downloadBackup,
  });

  final Future<DriveBackupResult> Function(List<Memo> memos)? uploadBackup;
  final Future<DriveBackupListResult> Function()? listBackups;
  final Future<String> Function(String fileId)? downloadBackup;

  static const _lastBackupKey = 'memoyo_last_backup_at';

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  List<Memo> _activeMemos = [];
  bool _isLoading = true;
  bool _isBackupRunning = false;
  bool _isRestoreRunning = false;
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
    if (_isBackupRunning) return;
    if (_activeMemos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).noMemosToExport)),
      );
      return;
    }

    setState(() => _isBackupRunning = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).driveBackupStarting),
          duration: Duration(seconds: 30),
        ),
      );

    final upload = widget.uploadBackup ?? DriveBackupService.uploadBackup;
    // 휴지통 제외 — 활성 메모만 백업(본진 결정 #6).
    final result = await upload(_activeMemos);
    if (!mounted) return;
    setState(() => _isBackupRunning = false);

    if (result is DriveBackupSuccess) {
      await _recordBackupTime();
    }
    if (!mounted) return;
    _showBackupResult(result);
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

  void _showBackupResult(DriveBackupResult result) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    switch (result) {
      case DriveBackupSuccess(:final folderUrl):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).driveSaved),
            action: SnackBarAction(
              label: AppStrings.of(context).openMemoyoFolder,
              onPressed: () async {
                final uri = Uri.parse(folderUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ),
        );
      case DriveBackupNetworkError():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).checkInternet)),
        );
      case DriveBackupPermissionDenied():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).drivePermissionNeeded)),
        );
      case DriveBackupQuotaExceeded():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).driveQuotaExceeded)),
        );
      case DriveBackupUnknown(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).driveBackupFailed(message))),
        );
    }
  }

  Future<void> _handleRestore() async {
    if (_isRestoreRunning) return;
    setState(() => _isRestoreRunning = true);
    final list = widget.listBackups ?? DriveBackupService.listBackups;
    final listResult = await list();
    if (!mounted) {
      return;
    }
    switch (listResult) {
      case DriveBackupListFailure(:final error):
        setState(() => _isRestoreRunning = false);
        _showDriveError(error, actionLabel: AppStrings.of(context).driveImportLabel);
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
    try {
      final download =
          widget.downloadBackup ?? DriveBackupService.downloadBackup;
      final source = await download(backup.id);
      final (incoming, total) =
          await ExportImportService.importFromSource(source);
      if (!mounted) return;
      if (incoming == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).noMemosToImport)),
        );
        return;
      }
      // 가져오기로 활성 메모가 바뀜 → 화면 상단 카운트/대상 갱신.
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).importedMemos(incoming, total)),
          action: SnackBarAction(
            label: AppStrings.of(context).undo,
            onPressed: _handleUndoImport,
          ),
        ),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).invalidBackupFile)),
      );
    } catch (e) {
      if (!mounted) return;
      _showDriveError(
        DriveBackupService.mapErrorForTest(e),
        actionLabel: AppStrings.of(context).driveImportLabel,
      );
    }
  }

  Future<void> _handleUndoImport() async {
    final restored = await ExportImportService.undoImport();
    if (restored == null) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).restoredPrevious(restored.length))),
    );
  }

  void _showDriveError(
    DriveBackupResult error, {
    String? actionLabel,
  }) {
    final label = actionLabel ?? AppStrings.of(context).driveBackupLabel;
    final message = switch (error) {
      DriveBackupNetworkError() => AppStrings.of(context).checkInternet,
      DriveBackupPermissionDenied() => AppStrings.of(context).drivePermissionNeeded,
      DriveBackupQuotaExceeded() => AppStrings.of(context).driveQuotaExceeded,
      DriveBackupUnknown(:final message) => AppStrings.of(context).actionFailed(label, message),
      DriveBackupSuccess() => AppStrings.of(context).actionDone(label),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        '${at.year}.${two(at.month)}.${two(at.day)} ${two(at.hour)}:${two(at.minute)}');
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: VersionFooter()),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(AppStrings.of(context).backupRestore, style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 56,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.of(context).backupIntro,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.of(context).backupTarget(_activeMemos.length),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lastBackupLabel(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 1단계(T-260829-022): 백업 JSON 엔 사진 파일명만 실리고 실물은 안 간다.
                  Text(
                    AppStrings.of(context).photosNotInBackup,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _isBackupRunning ? null : _handleBackup,
                    style: FilledButton.styleFrom(
                      // 바탕과 최대 대비를 내는 반전 버튼 — 두 테마에서 방향만 뒤집힌다.
                      backgroundColor: palette.textPrimary,
                      foregroundColor: palette.background,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _isBackupRunning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.background,
                            ),
                          )
                        : const Icon(Icons.backup_outlined),
                    label: Text(_isBackupRunning ? AppStrings.of(context).backingUp : AppStrings.of(context).backupNow),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isRestoreRunning ? null : _handleRestore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.textPrimary),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _isRestoreRunning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.textPrimary,
                            ),
                          )
                        : const Icon(Icons.restore_outlined),
                    label: Text(_isRestoreRunning ? AppStrings.of(context).restoring : AppStrings.of(context).restore),
                  ),
                ],
              ),
      ),
    );
  }
}
