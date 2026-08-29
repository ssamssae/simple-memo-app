import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 원본 (w,h) 를 비율 유지한 채 긴 변이 [maxLongEdge] 이하가 되게 줄인 크기.
/// 크기를 못 읽은 경우(0 이하) 는 (max,max) — 압축기의 하한 의미상 짧은 변이
/// max 로 맞춰져 목표보다 크다 — 상한은 절대값이 아니라 원본 비율에 비례한다(4:3 이면
/// 약 1.8배 픽셀). 실제로는 JPEG·PNG·HEIC 모두 헤더 크기를 읽으므로 거의 도달하지 않는다.
///
/// 전제: [maxLongEdge] >= 1 (호출부는 상수 1600).
(int, int) fitLongEdge(int width, int height, int maxLongEdge) {
  assert(maxLongEdge >= 1);
  if (width <= 0 || height <= 0) return (maxLongEdge, maxLongEdge);
  final long = width > height ? width : height;
  if (long <= maxLongEdge) return (width, height);
  final scale = maxLongEdge / long;
  int fit(int v) => (v * scale).round().clamp(1, maxLongEdge);
  return (fit(width), fit(height));
}

/// 들어온 이미지 바이트(PNG/HEIC/JPEG…)를 축소된 JPEG 바이트로.
abstract class ImageCompressor {
  Future<Uint8List> toJpeg(
    Uint8List source, {
    required int maxLongEdge,
    required int quality,
  });
}

/// flutter_image_compress 구현. EXIF 회전은 굽고(autoCorrectionAngle) 메타데이터는 버린다.
/// CI(리눅스·기기 없음)에서는 실행 불가 — 단위테스트는 fake ImageCompressor 로, 실동작은
/// 실기기 검증(Task 14).
class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor();

  @override
  Future<Uint8List> toJpeg(
    Uint8List source, {
    required int maxLongEdge,
    required int quality,
  }) async {
    final (w, h) = await _sourceSize(source);
    final (targetW, targetH) = fitLongEdge(w, h, maxLongEdge);
    return FlutterImageCompress.compressWithList(
      source,
      minWidth: targetW,
      minHeight: targetH,
      quality: quality,
      rotate: 0,
      autoCorrectionAngle: true,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
  }

  /// 전체 디코딩 없이 헤더에서 크기만 읽는다. 실패하면 (0,0) → fitLongEdge 폴백.
  ///
  /// 반환 크기는 EXIF 회전이 적용된 **표시 기준**이다(ImageDescriptor 가 회전을 반영해 준다).
  /// flutter_image_compress 도 90/270° 소스에서 minWidth/minHeight 를 맞바꾼 뒤 회전하므로
  /// 세 층이 같은 표시 프레임을 보고, 세로 사진도 긴 변이 정확히 maxLongEdge 에 떨어진다.
  Future<(int, int)> _sourceSize(Uint8List source) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(source);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } catch (e, st) {
      debugPrint('[FlutterImageCompressor._sourceSize] $e\n$st');
      return (0, 0);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
