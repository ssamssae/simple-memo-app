import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/memo.dart';

class MemoEditScreen extends StatefulWidget {
  final Memo? memo;
  final ValueChanged<Memo>? onSave;

  const MemoEditScreen({super.key, this.memo, this.onSave});

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late final TextEditingController _contentController;
  final UndoHistoryController _undoController = UndoHistoryController();
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _shakeDialogOpen = false;
  bool _isEditing = false;
  bool _popHandled = false;

  static const double _shakeThreshold = 18.0;
  static const Duration _shakeCooldown = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.memo != null;
    _contentController = TextEditingController(
      text: widget.memo?.content ?? '',
    );
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 60),
      ).listen(_onAccel);
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _contentController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _onAccel(AccelerometerEvent e) {
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final netForce = (magnitude - 9.8).abs();
    if (netForce < _shakeThreshold) return;
    final now = DateTime.now();
    if (now.difference(_lastShakeAt) < _shakeCooldown) return;
    _lastShakeAt = now;
    _promptUndoRedo();
  }

  Future<void> _promptUndoRedo() async {
    if (!mounted || _shakeDialogOpen) return;
    final value = _undoController.value;
    if (!value.canUndo && !value.canRedo) return;
    _shakeDialogOpen = true;
    try {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('실행 취소'),
          content: const Text('어떤 작업을 할까요?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            if (value.canRedo)
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  _undoController.redo();
                },
                child: const Text('다시 실행'),
              ),
            if (value.canUndo)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _undoController.undo();
                },
                child: const Text('실행 취소'),
              ),
          ],
        ),
      );
    } finally {
      _shakeDialogOpen = false;
    }
  }

  Memo? _buildMemo() {
    final content = _contentController.text.trim();
    if (content.isEmpty) return null;

    if (_isEditing && widget.memo != null) {
      return widget.memo!.copyWith(
        content: content,
        updatedAt: DateTime.now(),
      );
    } else {
      return Memo.create(content: content);
    }
  }

  void _dispatchSave() {
    final memo = _buildMemo();
    if (memo != null) {
      widget.onSave?.call(memo);
    }
  }

  void _saveAndPop() {
    _popHandled = true;
    _dispatchSave();
    Navigator.pop(context);
  }

  void _saveMemo() {
    final memo = _buildMemo();
    if (memo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
      return;
    }
    _popHandled = true;
    widget.onSave?.call(memo);
    Navigator.pop(context);
  }

  Future<void> _cancelEdit() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('취소하시겠습니까?'),
        content: const Text('수정한 내용이 저장되지 않습니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 수정'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _popHandled = true;
    Navigator.pop(context);
  }

  Future<void> _handlePasteWithNewline(EditableTextState editableTextState) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty) {
      final insertText = text.endsWith('\n') ? text : '$text\n';
      final value = _contentController.value;
      final sel = value.selection;
      final start = sel.isValid ? sel.start : value.text.length;
      final end = sel.isValid ? sel.end : value.text.length;
      final newText = value.text.replaceRange(start, end, insertText);
      _contentController.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + insertText.length),
        composing: TextRange.empty,
      );
    }
    editableTextState.hideToolbar();
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEditing ? '메모수정' : '새메모';
    final appBarTheme = Theme.of(context).appBarTheme;
    final titleStyle = appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appBarTheme.foregroundColor ?? Colors.amber,
            );
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        if (_popHandled) return;
        _dispatchSave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leadingWidth: 150,
          title: null,
          flexibleSpace: SafeArea(
            child: IgnorePointer(
              child: Container(
                height: kToolbarHeight,
                alignment: Alignment.center,
                child: Text(titleText, style: titleStyle),
              ),
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pillButton(
                  label: '뒤로',
                  icon: Icons.favorite,
                  color: Colors.amber.shade300,
                  onTap: _saveAndPop,
                ),
                const SizedBox(width: 6),
                _pillButton(
                  label: '취소',
                  icon: Icons.close,
                  color: Colors.redAccent.shade100,
                  onTap: _cancelEdit,
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undoController,
              builder: (context, value, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      color: value.canUndo
                          ? Colors.amber.shade300
                          : Colors.amber.shade300.withValues(alpha: 0.25),
                      onPressed: value.canUndo ? _undoController.undo : null,
                      tooltip: '실행 취소',
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      color: value.canRedo
                          ? Colors.amber.shade300
                          : Colors.amber.shade300.withValues(alpha: 0.25),
                      onPressed: value.canRedo ? _undoController.redo : null,
                      tooltip: '다시 실행',
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: _pillButton(
                label: '저장',
                icon: Icons.favorite,
                color: Colors.amber.shade300,
                onTap: _saveMemo,
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 600) {
              _saveAndPop();
            }
          },
          child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: TextField(
                    controller: _contentController,
                    undoController: _undoController,
                    cursorColor: Colors.amber,
                    cursorHeight: 20,
                    strutStyle: const StrutStyle(
                      fontSize: 18,
                      height: 1.5,
                      leading: 0,
                      forceStrutHeight: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '내용을 입력하세요...',
                      hintStyle: TextStyle(color: Colors.amber.withValues(alpha: 0.4)),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      height: 1.5,
                      leadingDistribution: TextLeadingDistribution.even,
                      letterSpacing: 0.2,
                    ),
                    maxLines: null,
                    autofocus: !_isEditing,
                    contextMenuBuilder: (context, editableTextState) {
                      final items = List<ContextMenuButtonItem>.from(
                        editableTextState.contextMenuButtonItems,
                      );
                      for (var i = 0; i < items.length; i++) {
                        if (items[i].type == ContextMenuButtonType.paste) {
                          items[i] = ContextMenuButtonItem(
                            type: ContextMenuButtonType.paste,
                            onPressed: () =>
                                _handlePasteWithNewline(editableTextState),
                          );
                        }
                      }
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: items,
                      );
                    },
                  ),
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
