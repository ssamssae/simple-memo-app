import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import 'attachment_store.dart';
import 'image_ingest.dart';

/// 가져오기 결과. 화면은 이 타입으로만 분기한다 — 예외는 서비스 밖으로 나가지 않는다.
sealed class AttachResult {
  const AttachResult();
}

final class AttachOk extends AttachResult {
  const AttachOk(this.fileName);
  final String fileName;
}

/// 피커 취소 (플러그인이 null 반환). 화면은 조용히 넘어간다. 권한 거부는 [AttachPermissionDenied].
final class AttachCancelled extends AttachResult {
  const AttachCancelled();
}

/// 클립보드에 이미지가 없다.
final class AttachNoImage extends AttachResult {
  const AttachNoImage();
}

/// 이미 [AttachmentService.maxImages] 장.
final class AttachLimit extends AttachResult {
  const AttachLimit();
}

/// 카메라 권한 거부 (iOS: image_picker 가 PlatformException camera_access_denied 를 던진다).
/// 화면은 「설정에서 카메라 권한을 허용해 주세요」 안내로 분기한다.
final class AttachPermissionDenied extends AttachResult {
  const AttachPermissionDenied();
}

/// 압축·저장 실패. 원본 폴백 없음(용량 봉투 보호).
final class AttachFailed extends AttachResult {
  const AttachFailed(this.error);
  final Object error;
}

/// 이미지 바이트 출처. 플러그인 의존을 여기 가둬 테스트에서 fake 로 바꾼다.
abstract class ImageSourcePort {
  Future<Uint8List?> pickGallery();
  Future<Uint8List?> takePhoto();
  Future<Uint8List?> clipboardImage();
}

class PluginImageSourcePort implements ImageSourcePort {
  PluginImageSourcePort({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pickGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.readAsBytes();
  }

  @override
  Future<Uint8List?> takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    return file?.readAsBytes();
  }

  @override
  Future<Uint8List?> clipboardImage() async {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  }
}

class AttachmentService {
  AttachmentService({
    required ImageSourcePort source,
    required ImageCompressor compressor,
    required this.store,
  })  : _source = source,
        _compressor = compressor;

  /// 프로덕션 조립. [AttachmentStore.init] 전이면 StateError — 호출부가 잡아 실패로 표시.
  factory AttachmentService.production() => AttachmentService(
        source: PluginImageSourcePort(),
        compressor: const FlutterImageCompressor(),
        store: AttachmentStore.instance,
      );

  static const int maxImages = 10;
  static const int maxLongEdge = 1600;
  static const int jpegQuality = 85;
  // 원본 바이트 상한 — 헤더 크기 읽기·압축은 원본을 네이티브로 복사하므로(약 3배 순간 메모리)
  // 비정상 입력(클립보드 임의 파일 등)을 여기서 자른다. 폰 사진은 보통 15MB 이하.
  static const int maxSourceBytes = 40 * 1024 * 1024;

  final ImageSourcePort _source;
  final ImageCompressor _compressor;
  final AttachmentStore store;

  Future<AttachResult> pickFromGallery(int currentCount) => _ingest(
        currentCount,
        _source.pickGallery,
        onNull: const AttachCancelled(),
        onEmpty: AttachFailed(StateError('empty image bytes')),
      );

  Future<AttachResult> takePhoto(int currentCount) => _ingest(
        currentCount,
        _source.takePhoto,
        onNull: const AttachCancelled(),
        onEmpty: AttachFailed(StateError('empty image bytes')),
      );

  Future<AttachResult> pasteFromClipboard(int currentCount) => _ingest(
        currentCount,
        _source.clipboardImage,
        onNull: const AttachNoImage(),
        onEmpty: const AttachNoImage(),
      );

  Future<void> deleteFiles(Iterable<String> names) => store.delete(names);

  Future<AttachResult> _ingest(
    int currentCount,
    Future<Uint8List?> Function() read, {
    required AttachResult onNull,
    required AttachResult onEmpty,
  }) async {
    if (currentCount >= maxImages) return const AttachLimit();
    final Uint8List? bytes;
    try {
      bytes = await read();
    } on PlatformException catch (e, st) {
      if (e.code == 'camera_access_denied') return const AttachPermissionDenied();
      debugPrint('[AttachmentService] read: $e\n$st');
      return AttachFailed(e);
    } catch (e, st) {
      debugPrint('[AttachmentService] read: $e\n$st');
      return AttachFailed(e);
    }
    if (bytes == null) return onNull;
    if (bytes.isEmpty) return onEmpty;
    if (bytes.length > maxSourceBytes) {
      debugPrint('[AttachmentService] source too large: ${bytes.length}B');
      return AttachFailed(ArgumentError.value(bytes.length, 'bytes', 'exceeds maxSourceBytes'));
    }
    try {
      final jpeg = await _compressor.toJpeg(
        bytes,
        maxLongEdge: maxLongEdge,
        quality: jpegQuality,
      );
      final name = await store.save(jpeg);
      return AttachOk(name);
    } catch (e, st) {
      debugPrint('[AttachmentService] ingest: $e\n$st');
      return AttachFailed(e);
    }
  }
}
