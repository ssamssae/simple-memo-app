import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
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
  Offset? _lastTouchPosition;
  bool _isClampingSelection = false;

  static const double _shakeThreshold = 18.0;
  static const Duration _shakeCooldown = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.memo != null;
    _contentController = TextEditingController(
      text: widget.memo?.content ?? '',
    );
    _contentController.addListener(_clampSelectionTrailingNewline);
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 60),
      ).listen(_onAccel);
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _contentController.removeListener(_clampSelectionTrailingNewline);
    _contentController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  // 선택 양 끝이 "라인 끝의 공백/개행" 영역에 걸쳐 있으면 실제 글자 뒤로
  // 하이라이트가 뻗어 보임. 사용자는 마지막 글자에서 멈추기를 원하므로,
  // 공백(space/tab/CR)과 개행(LF)을 선택 양 끝에서 걷어냄. 단 공백은
  // 바로 뒤가 개행/문서끝 일 때만 (= 실제 라인 끝의 잔여 공백일 때만)
  // 잘라서, 문장 중간의 공백은 건드리지 않음.
  void _clampSelectionTrailingNewline() {
    if (_isClampingSelection) return;
    final v = _contentController.value;
    final sel = v.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final text = v.text;
    final len = text.length;

    bool isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0D;

    int trimEnd(int end, int lowerBound) {
      while (end > lowerBound && end > 0) {
        final c = text.codeUnitAt(end - 1);
        if (c == 0x0A) {
          end--;
          continue;
        }
        if (isWs(c)) {
          // 공백은 "선택 끝부터 다음 개행/문서끝까지 모두 공백인 경우"만 잘라냄.
          // (라인 중간의 공백은 건드리지 않음)
          var peek = end;
          var allWsToLineEnd = true;
          while (peek < len) {
            final pc = text.codeUnitAt(peek);
            if (pc == 0x0A) break;
            if (!isWs(pc)) {
              allWsToLineEnd = false;
              break;
            }
            peek++;
          }
          if (allWsToLineEnd) {
            end--;
            continue;
          }
        }
        break;
      }
      return end;
    }

    final base = sel.baseOffset;
    final ext = sel.extentOffset;
    int newBase = base;
    int newExt = ext;
    if (ext > base) {
      newExt = trimEnd(ext, base);
    } else if (base > ext) {
      newBase = trimEnd(base, ext);
    }
    if (newBase == base && newExt == ext) return;
    _isClampingSelection = true;
    _contentController.value = v.copyWith(
      selection: TextSelection(baseOffset: newBase, extentOffset: newExt),
    );
    _isClampingSelection = false;
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
    final showRedoOnly = value.canRedo;
    try {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(showRedoOnly ? '다시실행' : '실행취소'),
          content: const Text('어떤 작업을 할까요?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            if (showRedoOnly)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _undoController.redo();
                },
                child: const Text('다시실행'),
              )
            else if (value.canUndo)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _undoController.undo();
                },
                child: const Text('실행취소'),
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
            child: const Text('계속수정'),
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
    String? label,
    IconData? icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final hasLabel = label != null && label.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: 16, color: color),
            if (hasLabel) ...[
              if (icon != null) const SizedBox(width: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEditing ? '메모수정' : '새메모';
    final appBarTheme = Theme.of(context).appBarTheme;
    final baseTitleStyle = appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appBarTheme.foregroundColor ?? Colors.amber,
            );
    final titleStyle = baseTitleStyle?.copyWith(
      fontSize: 17,
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
                  color: Colors.amber.shade300,
                  onTap: _saveAndPop,
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 6),
                  _pillButton(
                    label: '취소',
                    color: Colors.redAccent.shade100,
                    onTap: _cancelEdit,
                  ),
                ],
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
                      tooltip: '실행취소',
                    ),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: IconButton(
                        icon: const Icon(Icons.redo, size: 20),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        color: value.canRedo
                            ? Colors.amber.shade300
                            : Colors.amber.shade300.withValues(alpha: 0.25),
                        onPressed: value.canRedo ? _undoController.redo : null,
                        tooltip: '다시실행',
                      ),
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 0),
              child: _pillButton(
                label: '저장',
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
                  child: Listener(
                    onPointerDown: (e) => _lastTouchPosition = e.position,
                    onPointerUp: (e) => _lastTouchPosition = e.position,
                    child: TextField(
                    controller: _contentController,
                    undoController: _undoController,
                    cursorColor: Colors.amber,
                    cursorHeight: 18,
                    selectionControls: _largeCupertinoSelectionControls,
                    selectionHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
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
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                      decorationThickness: 0,
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
                      final sel = editableTextState.textEditingValue.selection;
                      final text = editableTextState.textEditingValue.text;
                      items.removeWhere(
                        (item) => item.type == ContextMenuButtonType.selectAll,
                      );
                      final allSelected = sel.isValid &&
                          sel.start == 0 &&
                          sel.end == text.length;
                      if (text.isNotEmpty && !allSelected) {
                        final selectAll = ContextMenuButtonItem(
                          type: ContextMenuButtonType.selectAll,
                          label: 'Select All',
                          onPressed: () {
                            editableTextState
                                .selectAll(SelectionChangedCause.toolbar);
                          },
                        );
                        final pasteIdx = items.indexWhere(
                          (item) => item.type == ContextMenuButtonType.paste,
                        );
                        if (pasteIdx >= 0) {
                          items.insert(pasteIdx, selectAll);
                        } else {
                          items.add(selectAll);
                        }
                      }

                      var anchors = editableTextState.contextMenuAnchors;
                      if (sel.isValid && _lastTouchPosition != null) {
                        anchors = TextSelectionToolbarAnchors(
                          primaryAnchor: _lastTouchPosition!,
                          secondaryAnchor: _lastTouchPosition!,
                        );
                      }

                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: anchors,
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
      ),
    );
  }
}

class _LargeHandlePainter extends CustomPainter {
  const _LargeHandlePainter(this.color, this.radius);
  final Color color;
  final double radius;
  static const double _overlap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const halfStrokeWidth = 1.0;
    final paint = Paint()..color = color;
    final circle = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );
    final line = Rect.fromPoints(
      Offset(radius - halfStrokeWidth, 2 * radius - _overlap),
      Offset(radius + halfStrokeWidth, size.height),
    );
    final path = Path()
      ..addOval(circle)
      ..addRect(line);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LargeHandlePainter oldPainter) =>
      color != oldPainter.color || radius != oldPainter.radius;
}

class _LargeCupertinoSelectionControls extends CupertinoTextSelectionControls {
  static const double _radius = 7.0;
  static const double _overlap = 1.5;

  @override
  Size getHandleSize(double textLineHeight) {
    return Size(
      _radius * 2,
      textLineHeight + _radius * 2 - _overlap,
    );
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final Size desiredSize;
    final Widget handle;
    final Widget customPaint = CustomPaint(
      painter: _LargeHandlePainter(
        CupertinoTheme.of(context).selectionHandleColor,
        _radius,
      ),
    );

    switch (type) {
      case TextSelectionHandleType.left:
        desiredSize = getHandleSize(textLineHeight);
        handle = SizedBox.fromSize(size: desiredSize, child: customPaint);
        return handle;
      case TextSelectionHandleType.right:
        desiredSize = getHandleSize(textLineHeight);
        handle = SizedBox.fromSize(size: desiredSize, child: customPaint);
        return Transform(
          transform: Matrix4.identity()
            ..translate(desiredSize.width / 2, desiredSize.height / 2)
            ..rotateZ(math.pi)
            ..translate(-desiredSize.width / 2, -desiredSize.height / 2),
          child: handle,
        );
      case TextSelectionHandleType.collapsed:
        return SizedBox.fromSize(size: getHandleSize(textLineHeight));
    }
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    final Size handleSize = getHandleSize(textLineHeight);
    switch (type) {
      case TextSelectionHandleType.left:
        return Offset(handleSize.width / 2, handleSize.height);
      case TextSelectionHandleType.right:
        return Offset(
          handleSize.width / 2,
          handleSize.height - 2 * _radius + _overlap,
        );
      case TextSelectionHandleType.collapsed:
        return Offset(
          handleSize.width / 2,
          textLineHeight + (handleSize.height - textLineHeight) / 2,
        );
    }
  }
}

final _largeCupertinoSelectionControls = _LargeCupertinoSelectionControls();
