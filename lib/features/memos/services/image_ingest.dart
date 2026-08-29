import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 원본 (w,h) 를 비율 유지한 채 긴 변이 [maxLongEdge] 이하가 되게 줄인 크기.
/// 크기를 못 읽은 경우(0 이하) 는 (max,max) — 압축기의 하한 의미상 짧은 변이
/// max 로 맞춰져 목표보다 크지만 유한하게 묶인다.
(int, int) fitLongEdge(int width, int height, int maxLongEdge) {
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
  Future<(int, int)> _sourceSize(Uint8List source) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(source);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } catch (e) {
      debugPrint('[FlutterImageCompressor._sourceSize] $e');
      return (0, 0);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
