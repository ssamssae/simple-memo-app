// T-260718-058 앱인토스 정식 래퍼 — 메모 목록(홈) 화면.
//
// 본편 memo_list_screen 의 핵심 계약 유지: 활성 메모만 표시, 즐겨찾기 섹션 우선,
// soft-delete(휴지통行) + UNDO 스낵바, cold start 에서 만료 휴지통 purge.
// 광고·리뷰 유도·멀티선택·수동 재정렬은 미니앱 스코프 밖 (T-260718-057 문구 정합).
// 루트 뒤로가기 = 앱인토스 closeView (스파이크 (b) 항 실증 계약 유지).
import 'package:flutter/material.dart';

import '../../models/memo.dart';
import '../ait_bridge.dart';
import '../ait_memo_store.dart';
import 'ait_memo_edit_screen.dart';
import 'ait_search_screen.dart';
import 'ait_trash_screen.dart';

class AitMemoListScreen extends StatefulWidget {
  const AitMemoListScreen({super.key});

  @override
  State<AitMemoListScreen> createState() => _AitMemoListScreenState();
}

class _AitMemoListScreenState extends State<AitMemoListScreen> {
  List<Memo> _memos = [];
  bool _loading = true;

  List<Memo> get _active => _memos.where((m) => !m.isInTrash).toList();

  @override
  void initState() {
    super.initState();
    _load(purge: true);
  }

  Future<void> _load({bool purge = false}) async {
    if (purge) await AitMemoStore.purgeExpiredTrash();
    final memos = await AitMemoStore.loadMemos();
    if (!mounted) return;
    setState(() {
      _memos = memos;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await AitMemoStore.saveMemos(_memos);
    if (mounted) setState(() {});
  }

  Future<void> _openEdit({String? memoId}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AitMemoEditScreen(memoId: memoId)),
    );
    await _load();
  }

  Future<void> _openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AitSearchScreen()),
    );
    await _load();
  }

  Future<void> _openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AitTrashScreen()),
    );
    await _load();
  }

  Future<void> _toggleFavorite(Memo memo) async {
    final idx = _memos.indexWhere((m) => m.id == memo.id);
    if (idx < 0) return;
    _memos[idx] = _memos[idx].copyWith(isFavorite: !memo.isFavorite);
    await _persist();
  }

  Future<void> _moveToTrash(Memo memo) async {
    final idx = _memos.indexWhere((m) => m.id == memo.id);
    if (idx < 0) return;
    _memos[idx] = _memos[idx].copyWith(deletedAt: DateTime.now());
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('휴지통으로 이동했어요.'),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () async {
              final i = _memos.indexWhere((m) => m.id == memo.id);
              if (i < 0) return;
              _memos[i] = _memos[i].copyWith(deletedAt: null);
              await _persist();
            },
          ),
        ),
      );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _memoTile(Memo memo, ColorScheme scheme) {
    final lines = memo.content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final preview = lines.length > 1 ? lines[1].trim() : '';
    return Dismissible(
      key: ValueKey(memo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => _moveToTrash(memo),
      child: ListTile(
        title: Text(memo.firstLine, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          preview.isEmpty ? _dateLabel(memo.updatedAt) : '$preview · ${_dateLabel(memo.updatedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            memo.isFavorite ? Icons.star : Icons.star_border,
            color: memo.isFavorite ? scheme.primary : scheme.outline,
          ),
          tooltip: memo.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
          onPressed: () => _toggleFavorite(memo),
        ),
        onTap: () => _openEdit(memoId: memo.id),
      ),
    );
  }

  Widget _sectionHeader(String label, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _active;
    final favorites = active.where((m) => m.isFavorite).toList();
    final normals = active.where((m) => !m.isFavorite).toList();
    final rows = <Widget>[
      if (favorites.isNotEmpty) _sectionHeader('즐겨찾기', scheme),
      ...favorites.map((m) => _memoTile(m, scheme)),
      if (favorites.isNotEmpty && normals.isNotEmpty) _sectionHeader('메모', scheme),
      ...normals.map((m) => _memoTile(m, scheme)),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AitBridge.closeView();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('메모요'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '검색',
              onPressed: _openSearch,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '휴지통',
              onPressed: _openTrash,
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : active.isEmpty
                  ? const Center(child: Text('아직 메모가 없어요.\n오른쪽 아래 + 로 첫 메모를 남겨보세요.', textAlign: TextAlign.center))
                  : ListView(children: rows),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEdit(),
          tooltip: '새 메모',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
