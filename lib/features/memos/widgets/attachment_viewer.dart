import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../services/attachment_store.dart';
import 'attachment_thumbnail.dart' show AttachmentThumbnail;

/// 전체화면 사진 뷰어 — 좌우 넘김(PageView) + 핀치 확대(InteractiveViewer) + 삭제.
/// 새 패키지 없음. 삭제는 [onDelete] 콜백으로 호출부(편집 화면)가 처리한다.
class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer({
    super.key,
    required this.fileNames,
    required this.initialIndex,
    this.onDelete,
    this.onSave,
  });

  final List<String> fileNames;
  final int initialIndex;
  final ValueChanged<String>? onDelete;

  /// 「갤러리에 저장」 — 호출부(편집 화면)가 서비스로 처리하고 안내를 띄운다. null 이면 버튼 없음.
  final ValueChanged<String>? onSave;

  static Future<void> show(
    BuildContext context, {
    required List<String> fileNames,
    required int initialIndex,
    ValueChanged<String>? onDelete,
    ValueChanged<String>? onSave,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AttachmentViewer(
          fileNames: fileNames,
          initialIndex: initialIndex,
          onDelete: onDelete,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  late final PageController _controller;
  late final List<String> _names;
  late int _index;

  // 확대 중에는 PageView 가 가로 드래그를 먹지 못하게 잠근다 — 제스처 아레나에서
  // PageView(kTouchSlop) 가 InteractiveViewer 의 팬(kPanSlop) 보다 먼저 이기기 때문.
  final Map<int, TransformationController> _transforms = {};
  bool _zoomed = false;

  TransformationController _transformFor(int page) {
    return _transforms.putIfAbsent(page, () {
      final controller = TransformationController();
      controller.addListener(() {
        if (page != _index) return;
        final zoomed = controller.value.getMaxScaleOnAxis() > 1.01;
        if (zoomed != _zoomed && mounted) setState(() => _zoomed = zoomed);
      });
      return controller;
    });
  }

  void _disposeTransforms() {
    for (final c in _transforms.values) {
      c.dispose();
    }
    _transforms.clear();
    _zoomed = false;
  }

  @override
  void initState() {
    super.initState();
    // 스냅샷 사본 — 라우트가 떠 있는 동안 호출부의 목록 변경은 반영하지 않는다(삭제는 이 화면이 주도).
    _names = List.of(widget.fileNames);
    _index = widget.initialIndex.clamp(0, _names.isEmpty ? 0 : _names.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant AttachmentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 위치에서 initialIndex 만 바뀌어 State 가 재사용되는 경우(initState 는 다시 안 돈다) —
    // 실사용은 항상 새 라우트 push 라 해당 없지만, 방어적으로 새 인덱스를 반영한다.
    if (widget.initialIndex == oldWidget.initialIndex) return;
    final next = widget.initialIndex.clamp(0, _names.isEmpty ? 0 : _names.length - 1);
    if (next == _index) return;
    setState(() {
      _disposeTransforms();
      _index = next;
      _controller.jumpToPage(_index);
    });
  }

  @override
  void dispose() {
    _disposeTransforms();
    _controller.dispose();
    super.dispose();
  }

  File? _fileAt(int i) {
    final store = AttachmentStore.maybeInstance;
    if (store == null) return null;
    try {
      final file = store.fileFor(_names[i]);
      return file.existsSync() ? file : null;
    } on ArgumentError {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _confirmDelete() async {
    if (_names.isEmpty) return;
    final strings = AppStrings.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(strings.deletePhotoConfirmTitle),
        content: Text(strings.deletePhotoConfirmBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deletePhotoConfirmTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = _names[_index];
    widget.onDelete?.call(name);
    if (_names.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _names.removeAt(_index);
      if (_index >= _names.length) _index = _names.length - 1;
      _disposeTransforms();
      _controller.jumpToPage(_index);
    });
  }

  Widget _missingIcon(AppStrings strings) => Icon(
        Icons.broken_image_outlined,
        size: 64,
        color: Colors.white54,
        semanticLabel: strings.photoMissing,
      );

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: strings.photoViewerClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Semantics(
          liveRegion: true,
          child: Text(
            '${_index + 1} / ${_names.length}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.onSave != null && _names.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_alt_outlined),
              tooltip: strings.saveToGallery,
              onPressed: () => widget.onSave?.call(_names[_index]),
            ),
          if (widget.onDelete != null && _names.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: strings.deletePhotoConfirmTitle,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
        itemCount: _names.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = (_transforms[i]?.value.getMaxScaleOnAxis() ?? 1) > 1.01;
        }),
        itemBuilder: (context, i) {
          final file = _fileAt(i);
          return InteractiveViewer(
            transformationController: _transformFor(i),
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: file == null
                  ? _missingIcon(strings)
                  : !AttachmentThumbnail.decodeImages
                      ? ColoredBox(
                          key: ValueKey('attachment-file:${file.path}'),
                          color: const Color(0x00000000),
                          child: const SizedBox.expand(),
                        )
                      : Image.file(
                          file,
                          fit: BoxFit.contain,
                          semanticLabel: strings.attachedPhoto,
                          errorBuilder: (_, _, _) => _missingIcon(strings),
                        ),
            ),
          );
        },
      ),
    );
  }
}
