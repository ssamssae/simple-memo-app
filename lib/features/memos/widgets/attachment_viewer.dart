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
  });

  final List<String> fileNames;
  final int initialIndex;
  final ValueChanged<String>? onDelete;

  static Future<void> show(
    BuildContext context, {
    required List<String> fileNames,
    required int initialIndex,
    ValueChanged<String>? onDelete,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AttachmentViewer(
          fileNames: fileNames,
          initialIndex: initialIndex,
          onDelete: onDelete,
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

  @override
  void initState() {
    super.initState();
    _names = List.of(widget.fileNames);
    _index = widget.initialIndex.clamp(0, _names.isEmpty ? 0 : _names.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
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
        title: Text(
          '${_index + 1} / ${_names.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: strings.deletePhotoConfirmTitle,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _names.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final file = _fileAt(i);
          return InteractiveViewer(
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
