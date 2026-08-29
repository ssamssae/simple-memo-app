import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:gal/gal.dart';
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

/// 사진첩 복수 선택 결과. [fileNames] 는 저장에 성공한 것만(선택 순서 유지).
/// [truncated] = 피커가 남은 장수보다 많이 돌려줘 뒤를 잘랐다 (피커가 limit 을
/// 못 지키는 구형 Android 등). [failed] = 압축·저장 실패로 빠진 장수.
final class AttachOkMany extends AttachResult {
  const AttachOkMany(this.fileNames, {this.truncated = false, this.failed = 0});
  final List<String> fileNames;
  final bool truncated;
  final int failed;
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
  /// 사진첩 복수 선택. 취소면 빈 목록. [limit] = 이번에 고를 수 있는 최대 장수(≥1) —
  /// 피커가 지원하면 OS 가 그 이상 못 고르게 막고 자기 안내를 띄운다
  /// (Android Photo Picker·iOS PHPicker). 아니키 S24 피드백 2026-08-30 01:2x
  /// 「사진첩에서처럼 드래그해서 복수선택이 안됨」.
  Future<List<Uint8List>> pickGallery({required int limit});
  Future<Uint8List?> takePhoto();
  Future<Uint8List?> clipboardImage();
}

class PluginImageSourcePort implements ImageSourcePort {
  PluginImageSourcePort({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<Uint8List>> pickGallery({required int limit}) async {
    final files = await _picker.pickMultiImage(limit: limit);
    return [for (final f in files) await f.readAsBytes()];
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

/// 「갤러리에 저장」 결과. 화면은 이 타입으로만 분기한다.
sealed class SaveToGalleryResult {
  const SaveToGalleryResult();
}

final class SaveOk extends SaveToGalleryResult {
  const SaveOk();
}

/// 사진 보관함 쓰기 권한 거부 (iOS 「사진 추가」 권한 / Android 10 미만 저장소 권한).
final class SaveDenied extends SaveToGalleryResult {
  const SaveDenied();
}

/// 원본 파일 없음(백업 복원 등)·용량 부족·기타 실패.
final class SaveFailed extends SaveToGalleryResult {
  const SaveFailed(this.error);
  final Object error;
}

/// 갤러리 저장 출처. 플러그인(gal) 의존을 여기 가둬 테스트에서 fake 로 바꾼다.
/// 아니키 S24 피드백 2026-08-30 01:2x 「꾹 눌러서 삭제나오는거 좋은데 다시 갤러리
/// 저장하는 버튼도 있으면 좋겠음」.
abstract class GallerySaverPort {
  /// 저장했으면 true, 권한 거부면 false. 그 외 실패는 던진다 — 서비스가 [SaveFailed] 로 바꾼다.
  Future<bool> putImage(String path);
}

class PluginGallerySaver implements GallerySaverPort {
  const PluginGallerySaver();

  @override
  Future<bool> putImage(String path) async {
    // toAlbum: false = iOS 「사진 추가만」 권한(NSPhotoLibraryAddUsageDescription),
    // Android 10+ 는 권한 없이 MediaStore 저장.
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) return false;
    await Gal.putImage(path);
    return true;
  }
}

class AttachmentService {
  AttachmentService({
    required ImageSourcePort source,
    required ImageCompressor compressor,
    required this.store,
    GallerySaverPort saver = const PluginGallerySaver(),
  })  : _source = source,
        _compressor = compressor,
        _saver = saver;

  /// 프로덕션 조립. [AttachmentStore.init] 전이면 StateError — 호출부가 잡아 실패로 표시.
  factory AttachmentService.production() => AttachmentService(
        source: PluginImageSourcePort(),
        compressor: const FlutterImageCompressor(),
        store: AttachmentStore.instance,
      );

  final GallerySaverPort _saver;

  /// 첨부 파일 1장을 기기 갤러리(사진 보관함)에 복사한다. 첨부 자체는 그대로 둔다.
  Future<SaveToGalleryResult> saveToGallery(String fileName) async {
    try {
      final file = store.fileFor(fileName);
      if (!await file.exists()) {
        return SaveFailed(StateError('attachment missing: $fileName'));
      }
      if (!await _saver.putImage(file.path)) return const SaveDenied();
      return const SaveOk();
    } on GalException catch (e, st) {
      if (e.type == GalExceptionType.accessDenied) return const SaveDenied();
      debugPrint('[AttachmentService] saveToGallery: $e\n$st');
      return SaveFailed(e);
    } catch (e, st) {
      debugPrint('[AttachmentService] saveToGallery: $e\n$st');
      return SaveFailed(e);
    }
  }

  static const int maxImages = 10;
  static const int maxLongEdge = 1600;
  static const int jpegQuality = 85;
  // 원본 바이트 상한 — 헤더 크기 읽기·압축은 원본을 네이티브로 복사하므로(약 3배 순간 메모리)
  // 비정상 입력(클립보드 임의 파일 등)을 여기서 자른다. 폰 사진은 보통 15MB 이하.
  static const int maxSourceBytes = 40 * 1024 * 1024;

  final ImageSourcePort _source;
  final ImageCompressor _compressor;
  final AttachmentStore store;

  /// 사진첩에서 여러 장. 남은 장수만큼만 받는다 — 피커가 limit 을 못 지키면 뒤를 자르고
  /// [AttachOkMany.truncated] 로 알린다. 전부 실패면 [AttachFailed], 취소면 [AttachCancelled].
  Future<AttachResult> pickFromGallery(int currentCount) async {
    if (currentCount >= maxImages) return const AttachLimit();
    final remaining = maxImages - currentCount;
    final List<Uint8List> batch;
    try {
      batch = await _source.pickGallery(limit: remaining);
    } on PlatformException catch (e, st) {
      debugPrint('[AttachmentService] pickGallery: $e\n$st');
      return AttachFailed(e);
    } catch (e, st) {
      debugPrint('[AttachmentService] pickGallery: $e\n$st');
      return AttachFailed(e);
    }
    if (batch.isEmpty) return const AttachCancelled();

    final truncated = batch.length > remaining;
    final names = <String>[];
    Object? lastError;
    for (final bytes in batch.take(remaining)) {
      final r = await _ingestBytes(
        bytes,
        onEmpty: AttachFailed(StateError('empty image bytes')),
      );
      switch (r) {
        case AttachOk(:final fileName):
          names.add(fileName);
        case AttachFailed(:final error):
          lastError = error;
        default:
          lastError = StateError('unexpected $r');
      }
    }
    if (names.isEmpty) return AttachFailed(lastError ?? StateError('all failed'));
    return AttachOkMany(
      names,
      truncated: truncated,
      failed: batch.take(remaining).length - names.length,
    );
  }

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
    return _ingestBytes(bytes, onEmpty: onEmpty);
  }

  /// 바이트 1장 → 크기 상한 검사 → 압축 → 저장. [AttachOk] 아니면 [onEmpty]/[AttachFailed].
  Future<AttachResult> _ingestBytes(
    Uint8List bytes, {
    required AttachResult onEmpty,
  }) async {
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
