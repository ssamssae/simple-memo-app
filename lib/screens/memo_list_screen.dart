import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../features/memos/services/attachment_store.dart';
import '../features/memos/widgets/attachment_thumbnail.dart';
import '../l10n/app_strings.dart';
import '../models/memo.dart';
import '../services/app_review_service.dart';
import '../services/memo_storage.dart';
import '../services/settings_service.dart';
import '../utils/app_palette.dart';
import 'memo_edit_screen.dart';
import 'search_screen.dart';

class MemoListScreen extends StatefulWidget {
  const MemoListScreen({super.key, this.requestReviewPrompt});

  final Future<AppReviewPromptResult> Function()? requestReviewPrompt;

  @override
  State<MemoListScreen> createState() => MemoListScreenState();
}

class MemoListScreenState extends State<MemoListScreen>
    with WidgetsBindingObserver {
  // 고아 첨부 파일 정리는 프로세스당 1회(cold start)만 — resume 때 돌리면
  // 열려 있는 편집 세션의 대기 파일(아직 어느 메모도 참조 안 함)을 지운다.
  static bool _orphanSweepDone = false;

  @visibleForTesting
  static void resetOrphanSweepForTest() => _orphanSweepDone = false;

  @visibleForTesting
  static void markOrphanSweepDoneForTest() => _orphanSweepDone = true;

  // [요구사항 1] 단일 리스트로만 관리. 즐겨찾기가 앞, 일반이 뒤 순서 유지.
  List<Memo> _memos = [];
  bool _isLoading = true;
  final ScrollController _listScrollController = ScrollController();
  final ValueNotifier<int> _closeSwipeNotifier = ValueNotifier(0);
  final AppReviewService _appReviewService = AppReviewService();
  final Set<String> _openSwipeIds = {};
  bool _buttonTapped = false;
  Offset? _pointerDownPos;
  static const _tapTolerance = 15.0;

  // 즐겨찾기 해제 시 원래 자리로 복귀하기 위한 앵커.
  // 값은 "즐겨찾기 직전에 일반 그룹에서 이 메모 바로 앞에 있던 메모의 id"(맨 앞이었으면 null).
  final Map<String, String?> _unfavoriteAnchors = {};

  bool _isEditMode = false;
  final Set<String> _selectedIds = {};

  // 이동(드래그) 중 휠 스크롤 지원용 활성 드래그 포인터 추적.
  // 드래그를 시작한 마우스 포인터의 id·최근 위치를 기억해 뒀다가,
  // 휠로 리스트를 움직인 직후 같은 위치로 delta-0 move 를 주입해
  // SliverReorderableList 가 insert 인덱스를 재계산하게 만든다 (아래 주석 참조).
  int? _dragPointerId;
  Offset? _dragPointerPosition;
  int _dragPointerButtons = kPrimaryButton;
  bool _reorderDragActive = false;

  void _onPointerDownForDragTracking(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    _dragPointerId = event.pointer;
    _dragPointerPosition = event.position;
    _dragPointerButtons = event.buttons;
  }

  void _onPointerMoveForDragTracking(PointerMoveEvent event) {
    if (event.pointer != _dragPointerId) return;
    _dragPointerPosition = event.position;
  }

  void _onPointerEndForDragTracking(PointerEvent event) {
    if (event.pointer != _dragPointerId) return;
    _dragPointerId = null;
    _dragPointerPosition = null;
  }

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
        title: Text(AppStrings.of(context).deleteMemoTitle),
        content: Text(AppStrings.of(context).deleteSelectedConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5534B),
            ),
            child: Text(AppStrings.of(context).delete),
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
    _listScrollController.dispose();
    _closeSwipeNotifier.dispose();
    super.dispose();
  }

  // 이동(reorder) 드래그 중에는 드래그 프록시가 휠 이벤트를 가로채
  // 리스트 Scrollable 의 기본 휠 처리가 못 받는다 (아니키 재보고 2026-07-11,
  // 편집 화면 PR#76 과 동일 패턴). 프록시에서 받은 휠을 리스트 스크롤로 넘긴다.
  void _handleListPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_listScrollController.hasClients) {
      return;
    }
    final position = _listScrollController.position;
    final target = (position.pixels + event.scrollDelta.dy)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) return;
    position.jumpTo(target);
    _syncReorderDragAfterScroll();
  }

  // SliverReorderableList 는 포인터 move·자체 edge auto-scroll 때만 insert
  // 인덱스를 재계산한다. 외부 jumpTo 뒤 포인터가 안 움직인 채 드롭되면
  // stale 인덱스의 아이템이 이미 뷰포트 밖에서 dispose 돼
  // _itemOffsetAt 의 null 크래시가 난다 (Flutter 3.41 reorderable_list.dart:1027).
  // 드래그 포인터 위치 그대로 delta-0 move 를 주입해 재계산 경로를 태운다 —
  // 커서 아래 드롭 슬롯(gap)도 휠 직후 바로 갱신되는 효과.
  void _syncReorderDragAfterScroll() {
    if (!_reorderDragActive) return;
    final pointer = _dragPointerId;
    final position = _dragPointerPosition;
    if (pointer == null || position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_reorderDragActive || _dragPointerId != pointer) return;
      GestureBinding.instance.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: position,
          kind: PointerDeviceKind.mouse,
          buttons: _dragPointerButtons,
        ),
      );
    });
  }

  Widget _dragProxyDecorator(Widget child, int index, Animation<double> a) {
    return Listener(
      onPointerSignal: _handleListPointerSignal,
      onPointerMove: _onPointerMoveForDragTracking,
      child: Material(elevation: 2, child: child),
    );
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
      // 고아 정리는 프로세스당 1회만 시도한다 — 플래그는 이 첫 패스에서 항상 세팅해
      // 이후 resume 으로 미뤄지지 않게 하고, 그 안에서만 참조 목록이 비어 있으면
      // 건너뛴다. loadMemos 는 실패를 빈 목록으로 삼키므로(prefs 일시 오류·JSON
      // 파싱 실패) 빈 목록 = 「메모 0개」와 구분이 안 되고, 그 상태에서 돌리면
      // 1일 넘은 첨부 전부가 지워진다 (Task 3 리뷰 지적).
      final store = AttachmentStore.maybeInstance;
      if (store != null && !_orphanSweepDone) {
        _orphanSweepDone = true;
        if (memos.isNotEmpty) {
          unawaited(store.sweepOrphans(memos.expand((m) => m.imageFiles)));
        }
      }
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

  Future<void> _saveMemos() async {
    await MemoStorage.saveMemos(_memos);
  }

  Future<void> _maybeRequestReviewAfterMemoSaved() async {
    final shouldRequest = await SettingsService.instance
        .recordMemoSavedForReviewPrompt();
    if (!shouldRequest || !mounted) return;
    await (widget.requestReviewPrompt ??
        _appReviewService.requestInAppReview)();
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
              ? AppStrings.of(context).memoDeleted
              : AppStrings.of(context).memosDeleted(deletedIds.length),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppStrings.of(context).undoSpaced,
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

  // --- 바텀바(HomeShell)에서 호출하는 public 진입점 ---

  /// 바텀바 '새메모' 탭 → 새 메모 편집기 열기.
  Future<void> startNewMemo() => _addMemo();

  /// 바텀바 '메모' 탭 복귀 시 재로드 (설정 탭에서 복원·가져오기로 변경됐을 수 있음).
  Future<void> reloadMemos() => _loadMemos();

  // --- 메모 CRUD (모두 id 기반) ---

  Future<void> _openSearch() async {
    _closeAllSwipes();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (!mounted) return;
    await reloadMemos();
  }

  Future<void> _addMemo() async {
    _closeAllSwipes();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          onSave: (newMemo) {
            if (!mounted) return;
            setState(() {
              final firstNormalIndex = _memos.indexWhere((m) => !m.isFavorite);
              if (firstNormalIndex == -1) {
                _memos.add(newMemo);
              } else {
                _memos.insert(firstNormalIndex, newMemo);
              }
            });
            unawaited(
              _saveMemos().then((_) => _maybeRequestReviewAfterMemoSaved()),
            );
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
        title: Text(AppStrings.of(context).deleteMemoTitle),
        content: Text(AppStrings.of(context).deleteMemoConfirm(memo.firstLine)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5534B),
            ),
            child: Text(AppStrings.of(context).delete),
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
      _unfavoriteAnchors[memoId] = posInNormals > 0
          ? normals[posInNormals - 1].id
          : null;

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
    final canEdit = active.isNotEmpty;
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);

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
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leadingWidth: canEdit ? 90 : null,
          leading: canEdit
              ? Padding(
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
                          _isEditMode ? AppStrings.of(context).cancel : AppStrings.of(context).edit,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
          title: Text(strings.appName, style: const TextStyle(fontSize: 17)),
          actions: [
            if (!_isEditMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(Icons.search, color: palette.textSecondary),
                  tooltip: AppStrings.of(context).search,
                  onPressed: _openSearch,
                ),
              ),
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
                    foregroundColor: const Color(0xFF7C5CFF),
                    disabledForegroundColor: const Color(
                      0xFF7C5CFF,
                    ).withValues(alpha: 0.3),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    (_selectedIds.length == active.length && active.isNotEmpty)
                        ? AppStrings.of(context).deselectAll
                        : AppStrings.of(context).selectAll,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: TextButton(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE5534B),
                    disabledForegroundColor: const Color(
                      0xFFE5534B,
                    ).withValues(alpha: 0.3),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _selectedIds.isEmpty ? AppStrings.of(context).delete : AppStrings.of(context).deleteWithCount(_selectedIds.length),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : active.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 56,
                      color: Color(0xFF7C5CFF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.of(context).emptyMemoHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  // 드래그 핸들로 reorder 시 화면 끝에서 자동 스크롤이 먹도록
                  // CustomScrollView + SliverReorderableList 로 구성한다.
                  // (옛 구조: NeverScrollableScrollPhysics 인 ReorderableListView 를
                  //  SingleChildScrollView 안에 중첩 → 드래그 시 항목이 화면 밖으로
                  //  떠도 자동 스크롤 안 됨)
                  child: Listener(
                    onPointerDown: _onPointerDownForDragTracking,
                    onPointerMove: _onPointerMoveForDragTracking,
                    onPointerUp: _onPointerEndForDragTracking,
                    onPointerCancel: _onPointerEndForDragTracking,
                    child: CustomScrollView(
                      controller: _listScrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        const SliverToBoxAdapter(
                          child: Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 0,
                            endIndent: 0,
                          ),
                        ),
                        if (favorites.isNotEmpty)
                          SliverReorderableList(
                            itemCount: favorites.length,
                            // ignore: deprecated_member_use
                            onReorder: _onReorderFav,
                            onReorderStart: (_) => _reorderDragActive = true,
                            onReorderEnd: (_) => _reorderDragActive = false,
                            proxyDecorator: _dragProxyDecorator,
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
                          SliverReorderableList(
                            itemCount: normals.length,
                            // ignore: deprecated_member_use
                            onReorder: _onReorderNormal,
                            onReorderStart: (_) => _reorderDragActive = true,
                            onReorderEnd: (_) => _reorderDragActive = false,
                            proxyDecorator: _dragProxyDecorator,
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
        final movingBack =
            (_dragOffset < 0 && details.delta.dx > 0) ||
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
    final palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            if (_dragOffset > 0)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF7C5CFF),
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
                  color: const Color(0xFFB3261E),
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
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 22,
                          ),
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
              onHorizontalDragUpdate: widget.isEditMode
                  ? null
                  : _onHorizontalDragUpdate,
              onHorizontalDragEnd: widget.isEditMode
                  ? null
                  : _onHorizontalDragEnd,
              child: AnimatedContainer(
                duration: !_isSnapped && _dragOffset != 0
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_dragOffset, 0, 0),
                color: palette.surface,
                child: Padding(
                  padding: const EdgeInsets.only(left: 28, right: 20),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (widget.isEditMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              widget.isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: const Color(0xFF7C5CFF),
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
                              child: const Icon(
                                Icons.star,
                                color: Color(0xFF7C5CFF),
                                size: 18,
                              ),
                            ),
                          ),
                        if (widget.memo.hasImages)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: AttachmentThumbnail(
                              fileName: widget.memo.imageFiles.first,
                            ),
                          ),
                        Expanded(
                          child: ValueListenableBuilder<double>(
                            valueListenable:
                                SettingsService.instance.bodyFontSize,
                            builder: (context, bodyFontSize, _) {
                              final scale =
                                  bodyFontSize /
                                  SettingsService.defaultBodyFontSize;
                              return Text(
                                widget.memo.firstLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                strutStyle: StrutStyle(
                                  fontSize: 17 * scale,
                                  height: 1.0,
                                  leading: 0,
                                  forceStrutHeight: true,
                                ),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17 * scale,
                                  letterSpacing: -0.2,
                                  height: 1.0,
                                  leadingDistribution:
                                      TextLeadingDistribution.even,
                                ),
                              );
                            },
                          ),
                        ),
                        if (!widget.isEditMode)
                          ReorderableDragStartListener(
                            index: widget.index,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Icon(
                                Icons.drag_handle,
                                color: palette.textSecondary,
                                size: 20,
                              ),
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
        const Divider(height: 0.5, thickness: 0.5, indent: 0, endIndent: 0),
      ],
    );
  }
}
