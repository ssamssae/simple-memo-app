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

  /// 테스트 전용 스위치 (프로덕션 코드는 절대 바꾸지 않는다). flutter_test 의 FakeAsync 존에서는
  /// FileImage 의 실제 파일 IO 가 완료되지 않아(runAsync 없이는) 테스트가 멈춘다. false 면 디코딩
  /// 대신 파일 경로를 담은 자리표시 상자를 그린다 — 실제 디코딩 경로는 runAsync 테스트 1건이
  /// 별도로 증명한다.
  static bool decodeImages = true;

  File? _resolve() {
    final store = AttachmentStore.maybeInstance;
    if (store == null) return null;
    try {
      final file = store.fileFor(fileName);
      return file.existsSync() ? file : null;
    } on ArgumentError {
      return null;
    } on FileSystemException {
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
            : !decodeImages
            ? ColoredBox(
                key: ValueKey('attachment-file:${file.path}'),
                color: const Color(0x00000000),
              )
            : Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                semanticLabel: AppStrings.of(context).attachedPhoto,
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
