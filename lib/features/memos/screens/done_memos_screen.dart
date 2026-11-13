import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/memo.dart';
import '../../../screens/memo_edit_screen.dart';
import '../../../services/memo_storage.dart';
import '../../../services/settings_service.dart';
import '../../../utils/app_palette.dart';
import '../../../widgets/toss_surface_card.dart';
import '../services/memo_done_ops.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/collapse_out.dart';
import '../widgets/memo_done_checkbox.dart';

/// 완료 탭 (T-261113-024). 옛 「할 일」 탭 자리.
///
/// 메모 목록에서 체크한 메모를 최근 완료 순으로 보여 준다. 체크를 풀면 1초 뒤 접히며
/// 메모 목록의 원래 자리로 돌아간다. 줄을 누르면 메모 편집. 「완료 비우기」는
/// 휴지통으로 옮긴다(되살릴 수 있다). 새 메모 버튼은 없다.
///
/// 왼쪽 위 「편집」을 누르면 메모 목록 편집 모드와 같은 선택 모드가 된다(T-261113-028).
/// 줄을 눌러 고르고 「선택 비우기 (N)」로 고른 완료 메모만 휴지통으로 옮긴다.
class DoneMemosScreen extends StatefulWidget {
  const DoneMemosScreen({
    super.key,
    this.undoDelay = const Duration(seconds: 1),
    this.onChanged,
  });

  /// 체크를 푼 뒤 줄이 접혀 메모 목록으로 가기까지 기다리는 시간.
  final Duration undoDelay;

  /// 저장한 뒤 부른다. HomeShell 이 메모 목록을 다시 읽게 한다.
  final VoidCallback? onChanged;

  @override
  State<DoneMemosScreen> createState() => DoneMemosScreenState();
}

class DoneMemosScreenState extends State<DoneMemosScreen> {
  List<Memo> _all = const [];
  bool _loading = true;

  /// 체크를 풀고 1초 기다리는 메모 id → 타이머.
  final Map<String, Timer> _undoTimers = {};

  /// 1초가 지나 접히는 중인 메모 id.
  final Set<String> _leavingIds = {};

  /// 「편집」을 눌러 줄을 고르는 중인지 (T-261113-028).
  bool _selecting = false;

  /// 선택 모드에서 고른 메모 id. 쓸 때는 [_selectedClearable] 로 지금 보이는 줄만 센다.
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    for (final timer in _undoTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  /// 탭을 열 때·다른 탭이 저장했을 때 다시 읽는다.
  Future<void> reload() async {
    final memos = await MemoStorage.loadMemos();
    if (!mounted) return;
    setState(() {
      _setAll(memos);
      _loading = false;
    });
  }

  /// setState 안에서 부른다. 완료 메모가 다 사라지면 선택 모드도 끝낸다
  /// (「편집」 버튼이 숨으므로 다음에 완료 메모가 생겨도 선택 모드로 남지 않게).
  void _setAll(List<Memo> memos) {
    _all = memos;
    if (MemoDoneOps.done(memos).isEmpty) {
      _selecting = false;
      _selectedIds.clear();
    }
  }

  /// 저장값을 다시 읽어 [change] 를 적용하고 저장한다. 다른 탭의 저장을 덮지 않는다.
  /// 저장값을 읽지 못하면 아무것도 쓰지 않는다.
  Future<bool> _mutate(List<Memo> Function(List<Memo>) change) async {
    final List<Memo> base;
    try {
      base = await MemoStorage.loadMemos(throwOnError: true);
    } catch (e) {
      debugPrint('[DoneMemosScreen] $e');
      return false;
    }
    final next = change(base);
    if (!await MemoStorage.saveMemos(next)) return false;
    if (mounted) setState(() => _setAll(next));
    widget.onChanged?.call();
    return true;
  }

  bool _isUnchecking(String id) =>
      _undoTimers.containsKey(id) || _leavingIds.contains(id);

  void _toggle(String id) {
    if (_leavingIds.contains(id)) return; // 이미 접히는 중
    final pending = _undoTimers.remove(id);
    if (pending != null) {
      // 1초 안에 다시 누름 — 완료 그대로.
      pending.cancel();
      HapticFeedback.selectionClick();
      setState(() {});
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _undoTimers[id] = Timer(widget.undoDelay, () {
        if (!mounted || _undoTimers.remove(id) == null) return;
        setState(() => _leavingIds.add(id));
      });
    });
  }

  Future<void> _commitUndone(String id) async {
    await _mutate((all) => MemoDoneOps.setDone(all, id, null));
    if (mounted) {
      setState(() {
        _leavingIds.remove(id);
        _selectedIds.remove(id);
      });
    }
  }

  /// 비울 수 있는 완료 메모 id: 보이는 완료 메모 중 체크를 푸는 중이 아닌 것.
  Set<String> _clearableIds() => {
    for (final m in MemoDoneOps.done(_all))
      if (!_isUnchecking(m.id)) m.id,
  };

  /// 고른 것 중 지금 비울 수 있는 것만 (다른 탭 저장·체크 풀기로 빠진 id 는 뺀다).
  Set<String> _selectedClearable() =>
      _clearableIds().intersection(_selectedIds);

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    if (_isUnchecking(id)) return; // 곧 메모 목록으로 돌아가는 줄은 고르지 않는다
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleSelectAll() {
    final clearable = _clearableIds();
    setState(() {
      if (_selectedIds.containsAll(clearable)) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(clearable);
      }
    });
  }

  /// 「완료 비우기」 — 보이는 완료 메모를 휴지통으로. 체크를 푸는 중인 메모는 남긴다.
  Future<void> _clearDone() => _trash(_clearableIds());

  /// 「선택 비우기 (N)」 — 고른 완료 메모만 휴지통으로 옮기고 선택 모드를 끝낸다.
  Future<void> _clearSelected() async {
    if (!await _trash(_selectedClearable())) return;
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  /// [ids] 완료 메모를 휴지통으로(soft delete) 옮기고 실행 취소 알림을 띄운다.
  Future<bool> _trash(Set<String> ids) async {
    if (ids.isEmpty) return false;
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final keepForScreenReader = MediaQuery.accessibleNavigationOf(context);
    final ok = await _mutate(
      (all) => MemoDoneOps.trashDone(all, ids, DateTime.now()),
    );
    if (!ok) return false;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(strings.doneMovedToTrash(ids.length)),
        // 메모 목록 삭제 알림과 같은 닫힘 규칙(action_snackbar_dismiss_test).
        persist: keepForScreenReader,
        duration: const Duration(seconds: 5),
        showCloseIcon: true,
        action: SnackBarAction(
          label: strings.undoSpaced,
          onPressed: () => _mutate((all) => MemoDoneOps.untrash(all, ids)),
        ),
      ),
    );
    return true;
  }

  Future<void> _open(Memo memo) async {
    Future<void>? saving;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          memo: memo,
          // 편집 화면은 저장을 콜백에 맡긴다(메모 목록·검색과 같은 패턴). 완료 표시는 그대로.
          onSave: (updated) => saving = _mutate(
            (all) => [for (final m in all) m.id == updated.id ? updated : m],
          ),
        ),
      ),
    );
    // 저장이 끝난 뒤 다시 읽는다 — 먼저 읽으면 고치기 전 내용이 남는다.
    await saving;
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);
    final done = MemoDoneOps.done(_all);
    final now = DateTime.now();
    final canSelect = done.isNotEmpty;
    final selecting = _selecting && canSelect;
    final clearable = _clearableIds();
    final selected = _selectedClearable();
    final allSelected =
        clearable.isNotEmpty && selected.length == clearable.length;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // 메모 탭과 같은 높이에 큰 제목이 오도록 같은 AppBar 를 둔다.
      // 「편집」·「전체선택」 자리·모양도 메모 목록 편집 모드와 같다.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: canSelect ? 90 : null,
        leading: canSelect
            ? _EditToggle(
                label: selecting ? strings.cancel : strings.edit,
                onTap: _toggleSelecting,
              )
            : null,
        actions: [
          if (selecting)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: TextButton(
                key: const Key('done-select-all'),
                onPressed: clearable.isEmpty ? null : _toggleSelectAll,
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  disabledForegroundColor: palette.accent.withValues(
                    alpha: 0.3,
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  allSelected ? strings.deselectAll : strings.selectAll,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : done.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScreenTitle(strings.doneTab),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 56,
                                color: palette.accent,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                strings.doneEmptyHint,
                                key: const Key('done-empty'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              children: [
                _ScreenTitle(strings.doneTab),
                _DoneHeader(
                  count: done.length,
                  selecting: selecting,
                  selectedCount: selected.length,
                  onClear: _clearDone,
                  onClearSelected: _clearSelected,
                ),
                for (final memo in done)
                  _DoneRow(
                    key: ValueKey('done-row-${memo.id}'),
                    memo: memo,
                    checked: !_isUnchecking(memo.id),
                    leaving: _leavingIds.contains(memo.id),
                    selecting: selecting,
                    selected: selected.contains(memo.id),
                    dateLabel: strings.doneDate(memo.doneAt!, now: now),
                    onToggle: () => _toggle(memo.id),
                    onTap: selecting
                        ? () => _toggleSelected(memo.id)
                        : () => _open(memo),
                    onLeft: () => _commitUndone(memo.id),
                  ),
              ],
            ),
    );
  }
}

/// 왼쪽 위 「편집」/「취소」 글자 버튼. 메모 목록 편집 버튼과 같은 자리·모양.
class _EditToggle extends StatelessWidget {
  const _EditToggle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          child: GestureDetector(
            key: const Key('done-edit'),
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「완료 N개 ··· 완료 비우기」 머리줄. 선택 모드에서는 「선택 비우기 (N)」.
class _DoneHeader extends StatelessWidget {
  const _DoneHeader({
    required this.count,
    required this.selecting,
    required this.selectedCount,
    required this.onClear,
    required this.onClearSelected,
  });

  final int count;
  final bool selecting;
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onClearSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);
    return Padding(
      key: const Key('done-header'),
      // 위아래 여백을 같게 해 글자와 「완료 비우기」가 줄 가운데 오게 한다(T-261113-023 과 같은 규칙).
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.doneCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selecting)
            TextButton(
              key: const Key('done-clear-selected'),
              // 고른 게 없으면 누를 수 없다(메모 목록 「삭제」와 같은 규칙).
              onPressed: selectedCount == 0 ? null : onClearSelected,
              style: TextButton.styleFrom(
                foregroundColor: palette.accent,
                disabledForegroundColor: palette.accent.withValues(alpha: 0.3),
              ),
              child: Text(strings.clearSelected(selectedCount)),
            )
          else
            TextButton(
              key: const Key('done-clear'),
              onPressed: onClear,
              style: TextButton.styleFrom(foregroundColor: palette.accent),
              child: Text(strings.clearDone),
            ),
        ],
      ),
    );
  }
}

/// 완료 메모 한 줄: 체크된 칸 · 흐린 취소선 첫 줄 · 작은 완료 날짜.
/// 선택 모드에서는 체크 칸 대신 메모 목록과 같은 선택 동그라미.
class _DoneRow extends StatelessWidget {
  const _DoneRow({
    super.key,
    required this.memo,
    required this.checked,
    required this.leaving,
    required this.selecting,
    required this.selected,
    required this.dateLabel,
    required this.onToggle,
    required this.onTap,
    required this.onLeft,
  });

  final Memo memo;

  /// 칸 상태. 체크를 푼 뒤 1초 동안은 false(빈 칸·취소선 없음).
  final bool checked;
  final bool leaving;

  /// 선택 모드인지. 그러면 줄 누르기([onTap])는 고르기이고 체크 칸은 숨긴다.
  final bool selecting;
  final bool selected;
  final String dateLabel;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onLeft;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return CollapseOut(
      collapsing: leaving,
      onCollapsed: onLeft,
      child: TossSurfaceCard(
        child: Semantics(
          selected: selecting ? selected : null,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              // 선택 동그라미는 메모 목록 편집 모드와 같은 여백(왼쪽 16).
              padding: EdgeInsets.only(left: selecting ? 16 : 4, right: 14),
              child: SizedBox(
                height: 48,
                // 날짜는 줄 폭의 35% 까지만 — 큰 글씨에서도 제목 자리가 남고 넘치지 않는다.
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      if (selecting)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            key: ValueKey('done-select-${memo.id}'),
                            color: palette.accent,
                            size: 20,
                          ),
                        )
                      else
                        MemoDoneCheckbox(
                          key: ValueKey('done-check-${memo.id}'),
                          checked: checked,
                          onTap: onToggle,
                          semanticLabel: memo.firstLine,
                        ),
                      if (memo.hasImages)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: AttachmentThumbnail(
                            fileName: memo.imageFiles.first,
                          ),
                        ),
                      Expanded(
                        // 메모 목록처럼 글자 크기 설정을 따른다(기본 17).
                        child: ValueListenableBuilder<double>(
                          valueListenable:
                              SettingsService.instance.bodyFontSize,
                          builder: (context, bodyFontSize, _) {
                            final scale =
                                bodyFontSize /
                                SettingsService.defaultBodyFontSize;
                            return Text(
                              memo.firstLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: checked
                                    ? palette.textSecondary
                                    : palette.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 17 * scale,
                                letterSpacing: -0.2,
                                decoration: checked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: palette.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.35,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textScaler: MediaQuery.textScalerOf(
                              context,
                            ).clamp(maxScaleFactor: 1.5),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 본문 상단의 큰 화면 제목 (메모 탭 제목과 같은 모양).
class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: palette.textPrimary,
        ),
      ),
    );
  }
}
