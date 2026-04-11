import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../services/memo_storage.dart';
import 'memo_edit_screen.dart';

class MemoListScreen extends StatefulWidget {
  const MemoListScreen({super.key});

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  List<Memo> _memos = [];
  bool _isLoading = true;
  final ValueNotifier<int> _closeSwipeNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  @override
  void dispose() {
    _closeSwipeNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadMemos() async {
    final memos = await MemoStorage.loadMemos();
    setState(() {
      _memos = memos;
      _isLoading = false;
    });
  }

  Future<void> _saveMemos() async {
    await MemoStorage.saveMemos(_memos);
  }

  void _closeAllSwipes() {
    _closeSwipeNotifier.value++;
  }

  Future<void> _addMemo() async {
    _closeAllSwipes();
    final result = await Navigator.push<Memo>(
      context,
      MaterialPageRoute(builder: (_) => const MemoEditScreen()),
    );
    if (result != null) {
      setState(() {
        _memos.insert(0, result);
      });
      await _saveMemos();
    }
  }

  Future<void> _editMemo(int index) async {
    final result = await Navigator.push<Memo>(
      context,
      MaterialPageRoute(builder: (_) => MemoEditScreen(memo: _memos[index])),
    );
    if (result != null) {
      setState(() {
        _memos[index] = result;
      });
      await _saveMemos();
    }
  }

  Future<void> _deleteMemo(int index) async {
    final memo = _memos[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 삭제'),
        content: Text('"${memo.firstLine}" 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _memos.removeAt(index));
      await _saveMemos();
    }
  }

  void _toggleFavorite(int index) {
    setState(() {
      _memos[index].isFavorite = !_memos[index].isFavorite;
    });
    _saveMemos();
  }

  void _onReorder(int oldIndex, int newIndex) {
    _closeAllSwipes();
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final memo = _memos.removeAt(oldIndex);
      _memos.insert(newIndex, memo);
    });
    _saveMemos();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _closeAllSwipes(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('메모장'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _memos.isEmpty
                ? const Center(
                    child: Text(
                      '메모가 없습니다.\n새 메모를 추가해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _memos.length,
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final memo = _memos[index];
                      return _MemoSwipeItem(
                        key: Key(memo.id),
                        memo: memo,
                        index: index,
                        closeNotifier: _closeSwipeNotifier,
                        onTap: () => _editMemo(index),
                        onDelete: () => _deleteMemo(index),
                        onToggleFavorite: () => _toggleFavorite(index),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addMemo,
          tooltip: '새 메모',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _MemoSwipeItem extends StatefulWidget {
  final Memo memo;
  final int index;
  final ValueNotifier<int> closeNotifier;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _MemoSwipeItem({
    super.key,
    required this.memo,
    required this.index,
    required this.closeNotifier,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  State<_MemoSwipeItem> createState() => _MemoSwipeItemState();
}

class _MemoSwipeItemState extends State<_MemoSwipeItem> {
  double _dragOffset = 0;
  bool _isSnapped = false;
  bool _isDragging = false;
  static const _actionWidth = 80.0;

  @override
  void initState() {
    super.initState();
    widget.closeNotifier.addListener(_onCloseRequested);
  }

  @override
  void dispose() {
    widget.closeNotifier.removeListener(_onCloseRequested);
    super.dispose();
  }

  void _onCloseRequested() {
    if (_isSnapped && !_isDragging) {
      setState(() {
        _dragOffset = 0;
        _isSnapped = false;
      });
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-_actionWidth, _actionWidth);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    setState(() {
      if (_dragOffset < -_actionWidth * 0.4) {
        _dragOffset = -_actionWidth;
        _isSnapped = true;
      } else if (_dragOffset > _actionWidth * 0.4) {
        _dragOffset = _actionWidth;
        _isSnapped = true;
      } else {
        _dragOffset = 0;
        _isSnapped = false;
      }
    });
  }

  void _resetSwipe() {
    setState(() {
      _dragOffset = 0;
      _isSnapped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 즐겨찾기 버튼 (오른쪽으로 스와이프 시 왼쪽에 노출)
        if (_dragOffset > 0)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow[700],
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: () {
                  widget.onToggleFavorite();
                  _resetSwipe();
                },
                child: Container(
                  width: _actionWidth - 12,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.memo.isFavorite
                            ? Icons.star_outline
                            : Icons.star,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.memo.isFavorite ? '해제' : '즐겨찾기',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // 삭제 버튼 (왼쪽으로 스와이프 시 오른쪽에 노출)
        if (_dragOffset < 0)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[800],
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  _resetSwipe();
                  widget.onDelete();
                },
                child: Container(
                  width: _actionWidth - 12,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 26),
                      SizedBox(height: 2),
                      Text(
                        '삭제',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // 메모 카드
        GestureDetector(
          onTap: _isSnapped ? _resetSwipe : widget.onTap,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: widget.memo.isFavorite
                    ? const Icon(Icons.star, color: Colors.amber, size: 20)
                    : null,
                title: Text(
                  widget.memo.firstLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
