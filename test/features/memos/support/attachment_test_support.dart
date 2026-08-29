// test/features/memos/support/attachment_test_support.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_memo_app/features/memos/services/attachment_service.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/services/image_ingest.dart';

/// 1×1 투명 PNG (67B). 실제 디코딩 가능한 최소 이미지.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// 임시 디렉토리에 스토어를 만들어 프로세스 단일 인스턴스로 꽂는다.
/// 반환값은 tearDown 에서 `deleteSync(recursive: true)` 할 루트.
Future<Directory> installTempStore() async {
  final dir = await Directory.systemTemp.createTemp('memoyo-attach-');
  AttachmentStore.instance =
      AttachmentStore(root: Directory('${dir.path}${Platform.pathSeparator}attachments'));
  return dir;
}

/// 스토어에 파일을 하나 심고 파일명을 돌려준다 (테스트 fixture 용).
Future<String> seedStoreFile(String name, [Uint8List? bytes]) async {
  final store = AttachmentStore.instance;
  await store.root.create(recursive: true);
  await store.fileFor(name).writeAsBytes(bytes ?? kTinyPng, flush: true);
  return name;
}

/// 피커·클립보드 fake. 필드에 바이트를 넣으면 그걸 돌려주고, null 이면 취소/없음.
class FakeImageSourcePort implements ImageSourcePort {
  Uint8List? galleryBytes;
  Uint8List? cameraBytes;
  Uint8List? clipboardBytes;
  int galleryCalls = 0;
  int cameraCalls = 0;
  int clipboardCalls = 0;

  @override
  Future<Uint8List?> pickGallery() async {
    galleryCalls++;
    return galleryBytes;
  }

  @override
  Future<Uint8List?> takePhoto() async {
    cameraCalls++;
    return cameraBytes;
  }

  @override
  Future<Uint8List?> clipboardImage() async {
    clipboardCalls++;
    return clipboardBytes;
  }
}

/// 압축기 fake — 바이트를 그대로 통과시키거나 [shouldThrow] 면 던진다.
class PassthroughCompressor implements ImageCompressor {
  bool shouldThrow = false;
  int calls = 0;
  int? lastMaxLongEdge;
  int? lastQuality;

  @override
  Future<Uint8List> toJpeg(
    Uint8List source, {
    required int maxLongEdge,
    required int quality,
  }) async {
    calls++;
    lastMaxLongEdge = maxLongEdge;
    lastQuality = quality;
    if (shouldThrow) throw StateError('compress failed');
    return source;
  }
}

/// 실제 파이프라인 + fake 가장자리. `installTempStore()` 뒤에 부를 것.
AttachmentService fakeAttachmentService({
  FakeImageSourcePort? port,
  PassthroughCompressor? compressor,
}) =>
    AttachmentService(
      source: port ?? FakeImageSourcePort(),
      compressor: compressor ?? PassthroughCompressor(),
      store: AttachmentStore.instance,
    );
