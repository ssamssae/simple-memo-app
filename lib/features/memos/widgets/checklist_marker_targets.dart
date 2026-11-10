import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/checklist_text.dart';

/// Tap targets over the checklist marks. The text field never sees the tap,
/// so the caret stays where it was and no character is deleted.
class ChecklistMarkerTargets extends StatefulWidget {
  const ChecklistMarkerTargets({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.semanticsLabel,
    required this.onToggle,
    this.layoutToken = 0,
  });

  final GlobalKey fieldKey;
  final TextEditingController controller;
  final String semanticsLabel;
  final ValueChanged<int> onToggle;
  final double layoutToken;

  @override
  State<ChecklistMarkerTargets> createState() => _ChecklistMarkerTargetsState();
}

class _Hit {
  const _Hit({required this.offset, required this.rect});

  final int offset;
  final Rect rect;
}

class _ChecklistMarkerTargetsState extends State<ChecklistMarkerTargets> {
  List<_Hit> _hits = const [];
  var _scheduled = false;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    widget.controller.addListener(_onController);
    _schedule();
  }

  @override
  void didUpdateWidget(ChecklistMarkerTargets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
    if (oldWidget.layoutToken != widget.layoutToken ||
        oldWidget.controller.text != widget.controller.text) {
      _text = widget.controller.text;
      _schedule();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    if (widget.controller.text == _text) return;
    _text = widget.controller.text;
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _measure();
    });
  }

  void _measure() {
    final fieldContext = widget.fieldKey.currentContext;
    final overlay = context.findRenderObject();
    if (fieldContext == null || overlay is! RenderBox || !overlay.hasSize) {
      return;
    }
    final render = _findEditable(fieldContext);
    if (render == null || !render.hasSize) return;

    final text = widget.controller.text;
    final hits = <_Hit>[];
    final lines = text.split('\n');
    var offset = 0;
    for (final line in lines) {
      if (ChecklistText.hasPrefix(line)) {
        final rect = _prefixRect(render, overlay, offset);
        if (rect != null && rect.width > 0 && rect.height > 0) {
          hits.add(_Hit(offset: offset, rect: rect));
        }
      }
      offset += line.length + 1;
    }
    if (_same(hits, _hits)) return;
    setState(() => _hits = hits);
  }

  Rect? _prefixRect(RenderEditable render, RenderBox overlay, int offset) {
    final text = widget.controller.text;
    final end = offset + ChecklistText.unchecked.length;
    if (end > text.length) return null;
    final startCaret = render.getLocalRectForCaret(
      TextPosition(offset: offset),
    );
    final endCaret = render.getLocalRectForCaret(TextPosition(offset: end));
    final local = Rect.fromLTRB(
      math.min(startCaret.left, endCaret.left),
      math.min(startCaret.top, endCaret.top),
      math.max(startCaret.right, endCaret.left),
      math.max(startCaret.bottom, endCaret.bottom),
    );
    if (local.width <= 0 || local.height <= 0) return null;
    final topLeft = render.localToGlobal(local.topLeft);
    final bottomRight = render.localToGlobal(local.bottomRight);
    return Rect.fromPoints(
      overlay.globalToLocal(topLeft),
      overlay.globalToLocal(bottomRight),
    );
  }

  RenderEditable? _findEditable(BuildContext context) {
    RenderEditable? found;
    void visit(Element element) {
      if (found != null) return;
      final render = element.renderObject;
      if (render is RenderEditable) {
        found = render;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  bool _same(List<_Hit> a, List<_Hit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].offset != b[i].offset) return false;
      if ((a[i].rect.left - b[i].rect.left).abs() > 0.5) return false;
      if ((a[i].rect.top - b[i].rect.top).abs() > 0.5) return false;
      if ((a[i].rect.width - b[i].rect.width).abs() > 0.5) return false;
      if ((a[i].rect.height - b[i].rect.height).abs() > 0.5) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final hit in _hits)
          Positioned(
            left: hit.rect.left,
            top: hit.rect.top,
            width: hit.rect.width,
            height: hit.rect.height,
            child: Semantics(
              button: true,
              label: widget.semanticsLabel,
              child: GestureDetector(
                key: ValueKey<String>('checklist-mark-${hit.offset}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onToggle(hit.offset),
              ),
            ),
          ),
      ],
    );
  }
}
