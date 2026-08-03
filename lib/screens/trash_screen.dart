import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/memo.dart';
import '../services/memo_storage.dart';
import '../widgets/version_footer.dart';
import '../l10n/app_strings.dart';


// 휴지통 화면 (1.0.7 ②④-3). 삭제된(soft-delete) 메모를 30일간 보관.
// 저장소는 기존 단일 'memos' blob 그대로 — 활성/휴지통이 한 리스트, deletedAt 으로 구분.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Memo> _trash = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final all = await MemoStorage.loadMemos();
    final trash = all.where((m) => m.deletedAt != null).toList()
      // 최근 삭제가 위 (deletedAt 내림차순).
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    if (!mounted) return;
    setState(() {
      _trash = trash;
      _isLoading = false;
    });
  }

  // 복구: deletedAt 만 지운다 → 다음 일반 리스트 로드 시 그룹 위치로 복귀.
  Future<void> _restore(Memo memo) async {
    final all = await MemoStorage.loadMemos();
    final i = all.indexWhere((m) => m.id == memo.id);
    if (i != -1) {
      all[i] = all[i].copyWith(deletedAt: null);
      await MemoStorage.saveMemos(all);
    }
    await _loadTrash();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).memoRestored)),
    );
  }

  // 즉시 영구삭제: 저장소에서 실제 제거(비가역). action sheet 가 확인 게이트.
  Future<void> _deleteForever(Memo memo) async {
    final all = await MemoStorage.loadMemos();
    all.removeWhere((m) => m.id == memo.id);
    await MemoStorage.saveMemos(all);
    await _loadTrash();
  }

  // 휴지통 비우기: 휴지통 항목 전체 영구삭제. 활성 메모(deletedAt == null)는 무변경.
  Future<void> _emptyTrash() async {
    final all = await MemoStorage.loadMemos();
    all.removeWhere((m) => m.deletedAt != null);
    await MemoStorage.saveMemos(all);
    await _loadTrash();
  }

  String _purgeLabel(Memo m) {
    final days = m.timeUntilPurge.inDays;
    if (days <= 0) return AppStrings.of(context).purgeSoon;
    return AppStrings.of(context).purgeAfterDays(days);
  }

  Future<void> _showItemActions(Memo memo) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(memo.firstLine),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'restore'),
            child: Text(AppStrings.of(context).restoreAction),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text(AppStrings.of(context).purgeNow),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, null),
          child: Text(AppStrings.of(context).cancel),
        ),
      ),
    );
    if (action == 'restore') {
      await _restore(memo);
    } else if (action == 'delete') {
      await _deleteForever(memo);
    }
  }

  Future<void> _confirmEmptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).emptyTrashTitle),
        content: Text(AppStrings.of(context).emptyTrashConfirm(_trash.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(AppStrings.of(context).emptyTrashAction),
          ),
        ],
      ),
    );
    if (confirmed == true) await _emptyTrash();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: VersionFooter()),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(AppStrings.of(context).trash, style: const TextStyle(fontSize: 17)),
        actions: [
          if (_trash.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _confirmEmptyTrash,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(AppStrings.of(context).emptyTrashAction, style: const TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _trash.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 56,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(height: 12),
                        Text(
                          AppStrings.of(context).trashEmptyHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _trash.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 0.5, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final memo = _trash[index];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text(
                          memo.firstLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: Text(
                          _purgeLabel(memo),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.more_horiz,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => _showItemActions(memo),
                      );
                    },
                  ),
      ),
    );
  }
}
