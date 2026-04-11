import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memo.dart';
import '../services/memo_storage.dart';
import 'memo_edit_screen.dart';

class MemoListScreen extends StatefulWidget {
  const MemoListScreen({super.key});

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  // [요구사항 1] 단일 리스트로만 관리. 즐겨찾기가 앞, 일반이 뒤 순서 유지.
  List<Memo> _memos = [];
  bool _isLoading = true;
  final ValueNotifier<int> _closeSwipeNotifier = ValueNotifier(0);
  bool _buttonTapped = false;
  Offset? _pointerDownPos;
  static const _tapTolerance = 15.0;

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

  // [요구사항 8] 즐겨찾기=항상 위, 일반=아래. .where()는 원래 순서 유지(stable).
  void _ensureGroupOrder() {
    final favs = _memos.where((m) => m.isFavorite).toList();
    final normals = _memos.where((m) => !m.isFavorite).toList();
    _memos = [...favs, ...normals];
  }

  Future<void> _loadMemos() async {
    try {
      final memos = await MemoStorage.loadMemos();
      if (!mounted) return;
      setState(() {
        _memos = memos;
        _ensureGroupOrder();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[_loadMemos] $e');
      if (!mounted) return;
      setState(() {
        _memos = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMemos() async {
    await MemoStorage.saveMemos(_memos);
  }

  void _closeAllSwipes() {
    _closeSwipeNotifier.value++;
  }

  void _onButtonTapped() {
    _buttonTapped = true;
  }

  // --- 메모 CRUD (모두 id 기반) ---

  Future<void> _addMemo() async {
    _closeAllSwipes();
    final result = await Navigator.push<Memo>(
      context,
      MaterialPageRoute(builder: (_) => const MemoEditScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        // 새 메모는 일반 그룹 맨 위 = 즐겨찾기 뒤 첫 번째
        final firstNormalIndex =
            _memos.indexWhere((m) => !m.isFavorite);
        if (firstNormalIndex == -1) {
          _memos.add(result); // 전부 즐겨찾기면 맨 뒤에
        } else {
          _memos.insert(firstNormalIndex, result);
        }
      });
      await _saveMemos();
    }
  }

  // [요구사항 5] id 기준으로 찾아서 처리
  Future<void> _editMemo(String memoId) async {
    _closeAllSwipes();
    final index = _memos.indexWhere((m) => m.id == memoId);
    if (index == -1) return;

    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(builder: (_) => MemoEditScreen(memo: _memos[index])),
    );
    if (!mounted) return;
    if (result is Memo) {
      setState(() {
        _memos[index] = result;
      });
      await _saveMemos();
    } else if (result is String && result.startsWith('delete:')) {
      setState(() => _memos.removeWhere((m) => m.id == memoId));
      await _saveMemos();
    }
  }

  Future<void> _deleteMemo(String memoId) async {
    final index = _memos.indexWhere((m) => m.id == memoId);
    if (index == -1) return;
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
    if (confirmed == true && mounted) {
      setState(() => _memos.removeWhere((m) => m.id == memoId));
      await _saveMemos();
    }
  }

  // [요구사항 5] copyWith로 isFavorite만 변경, insert/remove 안 함.
  // _ensureGroupOrder()로 그룹 재배치 (stable).
  void _toggleFavorite(String memoId) {
    setState(() {
      _memos = _memos.map((m) {
        if (m.id == memoId) {
          return m.copyWith(isFavorite: !m.isFavorite);
        }
        return m;
      }).toList();
      _ensureGroupOrder();
    });
    _saveMemos();
  }

  // [요구사항 7] 각 그룹 내부에서만 reorder.
  // _memos에서 해당 그룹의 원본 인덱스를 찾아 직접 조작.
  void _onReorderFav(int oldIndex, int newIndex) {
    _closeAllSwipes();
    if (newIndex > oldIndex) newIndex--;

    // _memos 내 즐겨찾기 항목들의 원본 인덱스 목록
    final favOriginalIndices = <int>[];
    for (int i = 0; i < _memos.length; i++) {
      if (_memos[i].isFavorite) favOriginalIndices.add(i);
    }

    if (oldIndex < 0 || oldIndex >= favOriginalIndices.length ||
        newIndex < 0 || newIndex >= favOriginalIndices.length) return;

    final movedMemo = _memos[favOriginalIndices[oldIndex]];
    setState(() {
      _memos.removeAt(favOriginalIndices[oldIndex]);
      // 삭제 후 인덱스 재계산
      final newOriginalIndices = <int>[];
      for (int i = 0; i < _memos.length; i++) {
        if (_memos[i].isFavorite) newOriginalIndices.add(i);
      }
      final insertAt = newIndex < newOriginalIndices.length
          ? newOriginalIndices[newIndex]
          : (_memos.isEmpty
              ? 0
              : (newOriginalIndices.isEmpty
                  ? 0
                  : newOriginalIndices.last + 1));
      _memos.insert(insertAt, movedMemo);
    });
    _saveMemos();
  }

  void _onReorderNormal(int oldIndex, int newIndex) {
    _closeAllSwipes();
    if (newIndex > oldIndex) newIndex--;

    final normalOriginalIndices = <int>[];
    for (int i = 0; i < _memos.length; i++) {
      if (!_memos[i].isFavorite) normalOriginalIndices.add(i);
    }

    if (oldIndex < 0 || oldIndex >= normalOriginalIndices.length ||
        newIndex < 0 || newIndex >= normalOriginalIndices.length) return;

    final movedMemo = _memos[normalOriginalIndices[oldIndex]];
    setState(() {
      _memos.removeAt(normalOriginalIndices[oldIndex]);
      final newOriginalIndices = <int>[];
      for (int i = 0; i < _memos.length; i++) {
        if (!_memos[i].isFavorite) newOriginalIndices.add(i);
      }
      final insertAt = newIndex < newOriginalIndices.length
          ? newOriginalIndices[newIndex]
          : (_memos.isEmpty
              ? 0
              : (newOriginalIndices.isEmpty
                  ? _memos.length
                  : newOriginalIndices.last + 1));
      _memos.insert(insertAt, movedMemo);
    });
    _saveMemos();
  }

  @override
  Widget build(BuildContext context) {
    // [요구사항 3] build 시점에 필터링
    final favorites = _memos.where((m) => m.isFavorite).toList();
    final normals = _memos.where((m) => !m.isFavorite).toList();

    return Listener(
      onPointerDown: (event) {
        _buttonTapped = false;
        _pointerDownPos = event.position;
      },
      onPointerUp: (event) {
        final downPos = _pointerDownPos;
        if (downPos == null) return;
        final distance = (event.position - downPos).distance;
        if (distance < _tapTolerance && !_buttonTapped) {
          Future.delayed(Duration.zero, () {
            if (mounted) _closeAllSwipes();
          });
        }
        _pointerDownPos = null;
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('메모장'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  launchUrl(
                    Uri.parse('https://ssamssae.github.io/daejong-page'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 12, color: Colors.amber.shade300),
                      const SizedBox(width: 4),
                      Text(
                        '응원',
                        style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (favorites.isNotEmpty)
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: favorites.length,
                            onReorder: _onReorderFav,
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                elevation: 2,
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final memo = favorites[index];
                              return _MemoSwipeItem(
                                key: ValueKey(memo.id),
                                memo: memo,
                                index: index,
                                closeNotifier: _closeSwipeNotifier,
                                onTap: () => _editMemo(memo.id),
                                onDelete: () => _deleteMemo(memo.id),
                                onToggleFavorite: () =>
                                    _toggleFavorite(memo.id),
                                onButtonTapped: _onButtonTapped,
                              );
                            },
                          ),
                        if (normals.isNotEmpty)
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: normals.length,
                            onReorder: _onReorderNormal,
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                elevation: 2,
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final memo = normals[index];
                              return _MemoSwipeItem(
                                key: ValueKey(memo.id),
                                memo: memo,
                                index: index,
                                closeNotifier: _closeSwipeNotifier,
                                onTap: () => _editMemo(memo.id),
                                onDelete: () => _deleteMemo(memo.id),
                                onToggleFavorite: () =>
                                    _toggleFavorite(memo.id),
                                onButtonTapped: _onButtonTapped,
                              );
                            },
                          ),
                      ],
                    ),
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

// --- 스와이프 아이템 위젯 (변경 없음) ---

class _MemoSwipeItem extends StatefulWidget {
  final Memo memo;
  final int index;
  final ValueNotifier<int> closeNotifier;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onButtonTapped;

  const _MemoSwipeItem({
    super.key,
    required this.memo,
    required this.index,
    required this.closeNotifier,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onButtonTapped,
  });

  @override
  State<_MemoSwipeItem> createState() => _MemoSwipeItemState();
}

class _MemoSwipeItemState extends State<_MemoSwipeItem> {
  double _dragOffset = 0;
  bool _isSnapped = false;
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
    if (_isSnapped) {
      setState(() {
        _dragOffset = 0;
        _isSnapped = false;
      });
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isSnapped) return;
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-_actionWidth, _actionWidth);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isSnapped) return;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            if (_dragOffset > 0)
              Positioned.fill(
                child: Container(
                  color: Colors.yellow[700],
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16),
                  child: Listener(
                    onPointerDown: (_) => widget.onButtonTapped(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.onToggleFavorite();
                        _resetSwipe();
                      },
                      child: SizedBox(
                        width: _actionWidth,
                        child: Icon(
                          widget.memo.isFavorite
                              ? Icons.star_outline
                              : Icons.star,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_dragOffset < 0)
              Positioned.fill(
                child: Container(
                  color: Colors.orange[800],
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Listener(
                    onPointerDown: (_) => widget.onButtonTapped(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _resetSwipe();
                        widget.onDelete();
                      },
                      child: const SizedBox(
                        width: 80,
                        child: Icon(Icons.delete, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: widget.onTap,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: AnimatedContainer(
                duration: !_isSnapped && _dragOffset != 0
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_dragOffset, 0, 0),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (widget.memo.isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () {
                                widget.onButtonTapped();
                                widget.onToggleFavorite();
                              },
                              child: const Icon(Icons.star, color: Colors.amber, size: 18),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.memo.firstLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: widget.index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 0.5, thickness: 0.5, indent: 16, endIndent: 16),
      ],
    );
  }
}
