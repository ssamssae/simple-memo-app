import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../utils/app_palette.dart';
import '../services/attachment_store.dart';

/// 첨부 사진 정사각 썸네일. 파일이 없거나 스토어가 없으면 깨진 사진 아이콘 —
/// 어떤 경우에도 예외를 올리지 않는다(백업 복원 뒤 파일 부재 시나리오).
class AttachmentThumbnail extends StatelessWidget {
  const AttachmentThumbnail({
    super.key,
    required this.fileName,
    this.size = 36,
    this.radius = 8,
  });

  final String fileName;
  final double size;
  final double radius;

  File? _resolve() {
    final store = AttachmentStore.maybeInstance;
    if (store == null) return null;
    try {
      final file = store.fileFor(fileName);
      return file.existsSync() ? file : null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _resolve();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: file == null
            ? _Placeholder(size: size)
            : Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) => _Placeholder(size: size),
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: palette.textSecondary.withValues(alpha: 0.12),
      child: Icon(
        Icons.broken_image_outlined,
        size: size * 0.5,
        color: palette.textSecondary,
        semanticLabel: AppStrings.of(context).photoMissing,
      ),
    );
  }
}
