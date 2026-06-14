import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../services/memo_storage.dart';
import '../widgets/version_footer.dart';
import 'memo_edit_screen.dart';
import 'settings_screen.dart';

class MemoListScreen extends StatefulWidget {
  const MemoListScreen({super.key});

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen>
    with WidgetsBindingObserver {
  // [요구사항 1] 단일 리스트로만 관리. 즐겨찾기가 앞, 일반이 뒤 순서 유지.
  List<Memo> _memos = [];
  bool _isLoading = true;
  final ValueNotifier<int> _closeSwipeNotifier = ValueNotifier(0);
  final Set<String> _openSwipeIds = {};
  bool _buttonTapped = false;
  Offset? _pointerDownPos;
  static const _tapTolerance = 15.0;

  // 즐겨찾기 해제 시 원래 자리로 복귀하기 위한 앵커.
  // 값은 "즐겨찾기 직전에 일반 그룹에서 이 메모 바로 앞에 있던 메모의 id"(맨 앞이었으면 null).
  final Map<String, String?> _unfavoriteAnchors = {};

  bool _isEditMode = false;
  final Set<String> _selectedIds = {};

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) _selectedIds.clear();
    });
    _closeAllSwipes();
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모삭제'),
        content: Text('선택한 $count개 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Color(0xFFE5484D)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // hard-delete 대신 soft-delete: 선택된 활성 메모에 deletedAt 마킹(휴지통行).
      // 제자리 마킹이라 UNDO 시 deletedAt 만 지우면 원위치 복귀.
      final now = DateTime.now();
      final deletedIds = _memos
          .where((m) => m.deletedAt == null && _selectedIds.contains(m.id))
          .map((m) => m.id)
          .toList();
      setState(() {
        for (int i = 0; i < _memos.length; i++) {
          if (deletedIds.contains(_memos[i].id)) {
            _memos[i] = _memos[i].copyWith(deletedAt: now);
            _unfavoriteAnchors.remove(_memos[i].id);
          }
        }
        _selectedIds.clear();
        _isEditMode = false;
      });
      await _saveMemos();
      if (!mounted) return;
      _showDeleteUndoSnackBar(deletedIds);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMemos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeSwipeNotifier.dispose();
    super.dispose();
  }

  // 앱이 다시 활성화될 때 휴지통 30일 만료분 purge + 재로드.
  // (앱을 켜둔 채 자정/30일 경계를 넘긴 경우 resume 1회로 정리.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMemos();
    }
  }

  // [요구사항 8] 즐겨찾기=항상 위, 일반=아래. .where()는 원래 순서 유지(stable).
  void _ensureGroupOrder() {
    final favs = _memos.where((m) => m.isFavorite).toList();
    final normals = _memos.where((m) => !m.isFavorite).toList();
    _memos = [...favs, ...normals];
  }

  Future<void> _loadMemos() async {
    try {
      // 휴지통 30일 만료분 자동 영구삭제(cold start/resume). 활성 메모 무영향.
      await MemoStorage.purgeExpiredTrash();
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

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        // 활성 메모만 선택 — 휴지통 항목은 리스트에 안 보이므로 제외.
        ..addAll(_memos.where((m) => m.deletedAt == null).map((m) => m.id));
    });
  }

  Future<void> _onOverflowSelected(String value) async {
    if (value == 'settings') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      // 설정 → 휴지통 복구·영구삭제 / 백업&복원 가져오기로 메모가 바뀌었을 수
      // 있으니 돌아오면 재로드.
      if (mounted) await _loadMemos();
    }
  }

  Future<void> _saveMemos() async {
    await MemoStorage.saveMemos(_memos);
  }

  // soft-delete 복구(UNDO): 해당 id 들의 deletedAt 만 지운다. 제자리 마킹이라
  // _memos 순서가 보존돼 원위치(즐겨찾기/일반 그룹 내 위치)로 그대로 복귀한다.
  Future<void> _restoreFromTrash(List<String> ids) async {
    if (ids.isEmpty || !mounted) return;
    setState(() {
      for (int i = 0; i < _memos.length; i++) {
        if (_memos[i].deletedAt != null && ids.contains(_memos[i].id)) {
          _memos[i] = _memos[i].copyWith(deletedAt: null);
        }
      }
    });
    await _saveMemos();
  }

  void _showDeleteUndoSnackBar(List<String> deletedIds) {
    if (deletedIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deletedIds.length == 1
              ? '메모를 삭제했습니다'
              : '메모 ${deletedIds.length}개를 삭제했습니다',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () async {
            await _restoreFromTrash(deletedIds);
          },
        ),
      ),
    );
  }

  void _closeAllSwipes() {
    _closeSwipeNotifier.value++;
    _openSwipeIds.clear();
  }

  void _onSwipeOpened(String id) {
    _openSwipeIds.add(id);
  }

  void _onSwipeClosed(String id) {
    _openSwipeIds.remove(id);
  }

  bool _hasOtherOpen(String id) {
    return _openSwipeIds.any((x) => x != id);
  }

  void _onButtonTapped() {
    _buttonTapped = true;
  }

  // --- 메모 CRUD (모두 id 기반) ---

  Future<void> _addMemo() async {
    _closeAllSwipes();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          onSave: (newMemo) {
            if (!mounted) return;
            setState(() {
              final firstNormalIndex =
                  _memos.indexWhere((m) => !m.isFavorite);
              if (firstNormalIndex == -1) {
                _memos.add(newMemo);
              } else {
                _memos.insert(firstNormalIndex, newMemo);
              }
            });
            _saveMemos();
          },
        ),
      ),
    );
  }

  Future<void> _editMemo(String memoId) async {
    _closeAllSwipes();
    final index = _memos.indexWhere((m) => m.id == memoId);
    if (index == -1) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          memo: _memos[index],
          onSave: (updatedMemo) {
            if (!mounted) return;
            final currentIndex = _memos.indexWhere((m) => m.id == memoId);
            if (currentIndex == -1) return;
            setState(() {
              _memos[currentIndex] = updatedMemo;
            });
            _saveMemos();
          },
        ),
      ),
    );
  }

  Future<void> _deleteMemo(String memoId) async {
    final index = _memos.indexWhere((m) => m.id == memoId);
    if (index == -1) return;
    final memo = _memos[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모삭제'),
        content: Text('"${memo.firstLine}" 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Color(0xFFE5484D)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        // hard-delete 대신 soft-delete: deletedAt 마킹(휴지통行). async 갭 후라 재조회.
        final i = _memos.indexWhere((m) => m.id == memoId);
        if (i != -1) {
          _memos[i] = _memos[i].copyWith(deletedAt: DateTime.now());
        }
        _unfavoriteAnchors.remove(memoId);
      });
      await _saveMemos();
      if (!mounted) return;
      _showDeleteUndoSnackBar([memoId]);
    }
  }

  // 즐겨찾기 토글. 해제 시 원래 일반 그룹에서의 위치로 복귀.
  void _toggleFavorite(String memoId) {
    final index = _memos.indexWhere((m) => m.id == memoId);
    if (index == -1) return;
    final memo = _memos[index];

    if (!memo.isFavorite) {
      // 즐겨찾기 설정: 일반 그룹에서 직전 메모 id를 앵커로 저장
      final normals = _memos.where((m) => !m.isFavorite).toList();
      final posInNormals = normals.indexWhere((m) => m.id == memoId);
      _unfavoriteAnchors[memoId] =
          posInNormals > 0 ? normals[posInNormals - 1].id : null;

      setState(() {
        _memos[index] = memo.copyWith(isFavorite: true);
        _ensureGroupOrder();
      });
    } else {
      // 즐겨찾기 해제: 일반 그룹 최상단으로 이동
      _unfavoriteAnchors.remove(memoId);
      final updated = memo.copyWith(isFavorite: false);

      setState(() {
        _memos.removeAt(index);

        // 마지막 즐겨찾기 다음(= 일반 그룹 최상단)에 삽입
        int insertAtMemos = _memos.length;
        for (int i = 0; i < _memos.length; i++) {
          if (!_memos[i].isFavorite) {
            insertAtMemos = i;
            break;
          }
        }
        _memos.insert(insertAtMemos, updated);
        _ensureGroupOrder();
      });
    }
    _saveMemos();
  }

  // [요구사항 7] 각 그룹 내부에서만 reorder.
  // _memos에서 해당 그룹의 원본 인덱스를 찾아 직접 조작.
  void _onReorderFav(int oldIndex, int newIndex) {
    _closeAllSwipes();

    // _memos 내 활성(휴지통 제외) 즐겨찾기 항목들의 원본 인덱스 목록.
    // 화면에 표시되는 리스트가 deletedAt == null 만이라 인덱스 정합을 맞춘다.
    final favOriginalIndices = <int>[];
    for (int i = 0; i < _memos.length; i++) {
      if (_memos[i].isFavorite && _memos[i].deletedAt == null) {
        favOriginalIndices.add(i);
      }
    }

    if (oldIndex < 0 ||
        oldIndex >= favOriginalIndices.length ||
        newIndex < 0 ||
        newIndex >= favOriginalIndices.length) {
      return;
    }

    final movedMemo = _memos[favOriginalIndices[oldIndex]];
    setState(() {
      _memos.removeAt(favOriginalIndices[oldIndex]);
      // 삭제 후 인덱스 재계산 (활성 즐겨찾기만)
      final newOriginalIndices = <int>[];
      for (int i = 0; i < _memos.length; i++) {
        if (_memos[i].isFavorite && _memos[i].deletedAt == null) {
          newOriginalIndices.add(i);
        }
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

    // 활성(휴지통 제외) 일반 항목들의 원본 인덱스 목록.
    final normalOriginalIndices = <int>[];
    for (int i = 0; i < _memos.length; i++) {
      if (!_memos[i].isFavorite && _memos[i].deletedAt == null) {
        normalOriginalIndices.add(i);
      }
    }

    if (oldIndex < 0 ||
        oldIndex >= normalOriginalIndices.length ||
        newIndex < 0 ||
        newIndex >= normalOriginalIndices.length) {
      return;
    }

    final movedMemo = _memos[normalOriginalIndices[oldIndex]];
    setState(() {
      _memos.removeAt(normalOriginalIndices[oldIndex]);
      final newOriginalIndices = <int>[];
      for (int i = 0; i < _memos.length; i++) {
        if (!_memos[i].isFavorite && _memos[i].deletedAt == null) {
          newOriginalIndices.add(i);
        }
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
    // [요구사항 3] build 시점에 필터링.
    // 휴지통(deletedAt != null)은 일반 리스트에서 제외 — 활성 메모만 표시.
    final active = _memos.where((m) => m.deletedAt == null).toList();
    final favorites = active.where((m) => m.isFavorite).toList();
    final normals = active.where((m) => !m.isFavorite).toList();

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
        resizeToAvoidBottomInset: false,
        extendBody: true,
        bottomNavigationBar: const SafeArea(child: VersionFooter()),
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 90,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _toggleEditMode,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  child: Text(
                    _isEditMode ? '취소' : '편집',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF5E5CE6),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: const Text(
            '메모요',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          actions: [
            if (_isEditMode) ...[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: active.isEmpty
                      ? null
                      : (_selectedIds.length == active.length
                          ? () => setState(_selectedIds.clear)
                          : _selectAll),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5E5CE6),
                    disabledForegroundColor:
                        const Color(0xFF5E5CE6).withValues(alpha: 0.3),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    (_selectedIds.length == active.length && active.isNotEmpty)
                        ? '선택해제'
                        : '전체선택',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: TextButton(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE5484D),
                    disabledForegroundColor:
                        const Color(0xFFE5484D).withValues(alpha: 0.3),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _selectedIds.isEmpty
                        ? '삭제'
                        : '삭제 (${_selectedIds.length})',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
            if (!_isEditMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF5E5CE6)),
                color: Colors.white,
                onSelected: _onOverflowSelected,
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('설정',
                        style: TextStyle(color: Color(0xFF1C1C1E))),
                  ),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : active.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E5CE6).withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_stories_outlined,
                            size: 44,
                            color: Color(0xFF5E5CE6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '아직 메모가 없어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '아래 + 버튼을 눌러 첫 메모를 남겨보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 96 +
                          MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (favorites.isNotEmpty)
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: favorites.length,
                            // ignore: deprecated_member_use
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
                                onSwipeOpened: _onSwipeOpened,
                                onSwipeClosed: _onSwipeClosed,
                                hasOtherOpen: _hasOtherOpen,
                                closeAllSwipes: _closeAllSwipes,
                                isEditMode: _isEditMode,
                                isSelected: _selectedIds.contains(memo.id),
                                onToggleSelect: () => _toggleSelected(memo.id),
                              );
                            },
                          ),
                        if (normals.isNotEmpty)
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: normals.length,
                            // ignore: deprecated_member_use
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
                                onSwipeOpened: _onSwipeOpened,
                                onSwipeClosed: _onSwipeClosed,
                                hasOtherOpen: _hasOtherOpen,
                                closeAllSwipes: _closeAllSwipes,
                                isEditMode: _isEditMode,
                                isSelected: _selectedIds.contains(memo.id),
                                onToggleSelect: () => _toggleSelected(memo.id),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom,
          ),
          child: FloatingActionButton.large(
            onPressed: _addMemo,
            tooltip: '새 메모',
            backgroundColor: const Color(0xFF5E5CE6),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            child: const Icon(Icons.add, size: 32),
          ),
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
  final void Function(String id) onSwipeOpened;
  final void Function(String id) onSwipeClosed;
  final bool Function(String id) hasOtherOpen;
  final VoidCallback closeAllSwipes;
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  const _MemoSwipeItem({
    super.key,
    required this.memo,
    required this.index,
    required this.closeNotifier,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onButtonTapped,
    required this.onSwipeOpened,
    required this.onSwipeClosed,
    required this.hasOtherOpen,
    required this.closeAllSwipes,
    required this.isEditMode,
    required this.isSelected,
    required this.onToggleSelect,
  });

  @override
  State<_MemoSwipeItem> createState() => _MemoSwipeItemState();
}

class _MemoSwipeItemState extends State<_MemoSwipeItem> {
  double _dragOffset = 0;
  bool _isSnapped = false;
  static const _actionWidth = 68.0;

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
      widget.onSwipeClosed(widget.memo.id);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      if (_isSnapped) {
        final movingBack = (_dragOffset < 0 && details.delta.dx > 0) ||
            (_dragOffset > 0 && details.delta.dx < 0);
        if (movingBack) {
          _isSnapped = false;
        } else {
          return;
        }
      }
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-_actionWidth, _actionWidth);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final wasSnapped = _isSnapped;
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
    if (_isSnapped && !wasSnapped) {
      widget.onSwipeOpened(widget.memo.id);
    } else if (!_isSnapped && wasSnapped) {
      widget.onSwipeClosed(widget.memo.id);
    }
  }

  void _resetSwipe() {
    final wasSnapped = _isSnapped;
    setState(() {
      _dragOffset = 0;
      _isSnapped = false;
    });
    if (wasSnapped) widget.onSwipeClosed(widget.memo.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Stack(
            children: [
              if (_dragOffset > 0)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFF7B500),
                  alignment: Alignment.centerLeft,
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
                        child: Center(
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
              ),
            if (_dragOffset < 0)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFE5484D),
                  alignment: Alignment.centerRight,
                  child: Listener(
                    onPointerDown: (_) => widget.onButtonTapped(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _resetSwipe();
                        widget.onDelete();
                      },
                      child: const SizedBox(
                        width: _actionWidth,
                        child: Center(
                          child: Icon(Icons.delete, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                if (widget.isEditMode) {
                  widget.onToggleSelect();
                  return;
                }
                if (_isSnapped) {
                  _resetSwipe();
                } else if (widget.hasOtherOpen(widget.memo.id)) {
                  widget.closeAllSwipes();
                } else {
                  widget.onTap();
                }
              },
              onHorizontalDragUpdate:
                  widget.isEditMode ? null : _onHorizontalDragUpdate,
              onHorizontalDragEnd:
                  widget.isEditMode ? null : _onHorizontalDragEnd,
              child: AnimatedContainer(
                duration: !_isSnapped && _dragOffset != 0
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_dragOffset, 0, 0),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        if (widget.isEditMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              widget.isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: const Color(0xFF5E5CE6),
                              size: 20,
                            ),
                          ),
                        if (widget.memo.isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () {
                                widget.onButtonTapped();
                                widget.onTap();
                              },
                              child: const Icon(Icons.star,
                                  color: Color(0xFF5E5CE6), size: 18),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.memo.firstLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            strutStyle: const StrutStyle(
                              fontSize: 17,
                              height: 1.0,
                              leading: 0,
                              forceStrutHeight: true,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              letterSpacing: 0.1,
                              height: 1.0,
                              leadingDistribution: TextLeadingDistribution.even,
                            ),
                          ),
                        ),
                        if (!widget.isEditMode)
                          ReorderableDragStartListener(
                            index: widget.index,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Icon(Icons.drag_handle,
                                  color: Color(0xFFC7C7CC), size: 20),
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
        ),
      ),
    );
  }
}
