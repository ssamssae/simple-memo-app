import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/memo.dart';
import '../services/drive_backup_service.dart';
import '../services/export_import_service.dart';
import '../services/memo_storage.dart';
import '../widgets/version_footer.dart';

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
        const SnackBar(content: Text('내보낼 메모가 없습니다')),
      );
      return;
    }

    setState(() => _isBackupRunning = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Drive 백업을 시작합니다'),
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
            content: const Text('Drive 에 저장됐어요'),
            action: SnackBarAction(
              label: 'Memoyo 폴더 열기',
              onPressed: () async {
                final uri = Uri.parse(folderUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ),
        );
      case DriveBackupNetworkError():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인터넷 연결을 확인해주세요')),
        );
      case DriveBackupPermissionDenied():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive 권한이 필요해요')),
        );
      case DriveBackupQuotaExceeded():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive 용량이 부족해요')),
        );
      case DriveBackupUnknown(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drive 백업 실패: $message')),
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
        _showDriveError(error, actionLabel: 'Drive 가져오기');
      case DriveBackupListSuccess(:final entries):
        if (entries.isEmpty) {
          setState(() => _isRestoreRunning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Drive 에 백업 파일이 없어요')),
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
          const SnackBar(content: Text('가져올 메모가 없습니다')),
        );
        return;
      }
      // 가져오기로 활성 메모가 바뀜 → 화면 상단 카운트/대상 갱신.
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메모 $incoming개 가져왔습니다 (전체 $total개)'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: _handleUndoImport,
          ),
        ),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 메모요 백업 파일이 아닙니다')),
      );
    } catch (e) {
      if (!mounted) return;
      _showDriveError(
        DriveBackupService.mapErrorForTest(e),
        actionLabel: 'Drive 가져오기',
      );
    }
  }

  Future<void> _handleUndoImport() async {
    final restored = await ExportImportService.undoImport();
    if (restored == null) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('이전 메모 ${restored.length}개로 되돌렸습니다')),
    );
  }

  void _showDriveError(
    DriveBackupResult error, {
    String actionLabel = 'Drive 백업',
  }) {
    final message = switch (error) {
      DriveBackupNetworkError() => '인터넷 연결을 확인해주세요',
      DriveBackupPermissionDenied() => 'Drive 권한이 필요해요',
      DriveBackupQuotaExceeded() => 'Drive 용량이 부족해요',
      DriveBackupUnknown(:final message) => '$actionLabel 실패: $message',
      DriveBackupSuccess() => '$actionLabel 완료',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<DriveBackupEntry?> _pickBackup(List<DriveBackupEntry> entries) async {
    return showModalBottomSheet<DriveBackupEntry>(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Drive 백업 선택',
                style: TextStyle(
                  color: Colors.amber,
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
                    leading: const Icon(
                      Icons.description_outlined,
                      color: Colors.amber,
                    ),
                    title: Text(
                      _backupLabel(entry),
                      style: const TextStyle(color: Colors.white),
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
    if (at == null) return '아직 백업한 적 없어요';
    String two(int n) => n.toString().padLeft(2, '0');
    return '마지막 백업: ${at.year}.${two(at.month)}.${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: VersionFooter()),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('백업 & 복원', style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 56,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '메모를 Google Drive 에 안전하게 백업하고,\n'
                    '필요할 때 다시 복원할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '백업 대상: 활성 메모 ${_activeMemos.length}개 (휴지통 제외)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.amber.shade200.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lastBackupLabel(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.amber.shade200.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _isBackupRunning ? null : _handleBackup,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _isBackupRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.backup_outlined),
                    label: Text(_isBackupRunning ? '백업 중…' : '지금 백업'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isRestoreRunning ? null : _handleRestore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _isRestoreRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber,
                            ),
                          )
                        : const Icon(Icons.restore_outlined),
                    label: Text(_isRestoreRunning ? '복원 중…' : '복원'),
                  ),
                ],
              ),
      ),
    );
  }
}
