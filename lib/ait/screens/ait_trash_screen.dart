// T-260718-058 앱인토스 정식 래퍼 — 휴지통 화면.
//
// 본편 trash_screen 과 같은 계약: soft-deleted(deletedAt != null) 만 표시,
// 복구 = deletedAt 해제, 영구 삭제 = 리스트에서 제거. D-day 표기는
// [Memo.timeUntilPurge] 기준.
import 'package:flutter/material.dart';

import '../../models/memo.dart';
import '../ait_memo_store.dart';

class AitTrashScreen extends StatefulWidget {
  const AitTrashScreen({super.key});

  @override
  State<AitTrashScreen> createState() => _AitTrashScreenState();
}

class _AitTrashScreenState extends State<AitTrashScreen> {
  List<Memo> _all = [];
  bool _loading = true;

  List<Memo> get _trashed {
    final t = _all.where((m) => m.isInTrash).toList();
    t.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return t;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final memos = await AitMemoStore.loadMemos();
    if (!mounted) return;
    setState(() {
      _all = memos;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await AitMemoStore.saveMemos(_all);
    if (mounted) setState(() {});
  }

  Future<void> _restore(Memo memo) async {
    final idx = _all.indexWhere((m) => m.id == memo.id);
    if (idx < 0) return;
    _all[idx] = _all[idx].copyWith(deletedAt: null);
    await _persist();
  }

  Future<void> _deleteForever(Memo memo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영구 삭제할까요?'),
        content: const Text('이 메모는 복구할 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    _all.removeWhere((m) => m.id == memo.id);
    await _persist();
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('휴지통을 비울까요?'),
        content: Text('휴지통의 메모 ${_trashed.length}개를 모두 영구 삭제해요. 복구할 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('모두 삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    _all.removeWhere((m) => m.isInTrash);
    await _persist();
  }

  String _purgeLabel(Memo memo) {
    final days = memo.timeUntilPurge.inDays;
    if (days <= 0) return '곧 자동 삭제';
    return '$days일 후 자동 삭제';
  }

  @override
  Widget build(BuildContext context) {
    final trashed = _trashed;
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통'),
        actions: [
          if (trashed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '휴지통 비우기',
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : trashed.isEmpty
                ? const Center(child: Text('휴지통이 비어 있어요.'))
                : ListView.separated(
                    itemCount: trashed.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final m = trashed[i];
                      return ListTile(
                        title: Text(m.firstLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_purgeLabel(m)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: '복구',
                              onPressed: () => _restore(m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined),
                              tooltip: '영구 삭제',
                              onPressed: () => _deleteForever(m),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
