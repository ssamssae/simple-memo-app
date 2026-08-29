import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_service.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;
  late FakeImageSourcePort port;
  late PassthroughCompressor compressor;
  late AttachmentService service;

  setUp(() async {
    tmp = await installTempStore();
    port = FakeImageSourcePort();
    compressor = PassthroughCompressor();
    service = fakeAttachmentService(port: port, compressor: compressor);
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  test('상수: 10장 · 긴 변 1600 · JPEG 85 · 원본 40MB 상한', () {
    expect(AttachmentService.maxImages, 10);
    expect(AttachmentService.maxLongEdge, 1600);
    expect(AttachmentService.jpegQuality, 85);
    expect(AttachmentService.maxSourceBytes, 40 * 1024 * 1024);
  });

  test('원본이 maxSourceBytes 를 넘으면 AttachFailed, 압축기 미호출·파일 미생성', () async {
    port.galleryBytes = Uint8List(AttachmentService.maxSourceBytes + 1);
    final result = await service.pickFromGallery(0);
    expect(result, isA<AttachFailed>());
    expect(compressor.calls, 0);
    expect(AttachmentStore.instance.root.existsSync(), isFalse);
  });

  test('사진첩: 성공 → 압축(1600/85) 거쳐 저장, 파일명 반환', () async {
    port.galleryBytes = kTinyPng;
    final result = await service.pickFromGallery(0);

    expect(result, isA<AttachOk>());
    final name = (result as AttachOk).fileName;
    expect(await AttachmentStore.instance.exists(name), isTrue);
    expect(compressor.calls, 1);
    expect(compressor.lastMaxLongEdge, 1600);
    expect(compressor.lastQuality, 85);
  });

  test('카메라: 성공 경로 동일', () async {
    port.cameraBytes = kTinyPng;
    expect(await service.takePhoto(3), isA<AttachOk>());
    expect(port.cameraCalls, 1);
  });

  test('피커 null(취소·권한 거부) → AttachCancelled, 파일 미생성', () async {
    expect(await service.pickFromGallery(0), isA<AttachCancelled>());
    expect(await service.takePhoto(0), isA<AttachCancelled>());
    expect(AttachmentStore.instance.root.existsSync(), isFalse);
  });

  test('클립보드 null·빈 바이트 → AttachNoImage', () async {
    expect(await service.pasteFromClipboard(0), isA<AttachNoImage>());
    port.clipboardBytes = Uint8List.fromList(const []);
    expect(await service.pasteFromClipboard(0), isA<AttachNoImage>());
  });

  test('클립보드 성공 → AttachOk', () async {
    port.clipboardBytes = kTinyPng;
    expect(await service.pasteFromClipboard(0), isA<AttachOk>());
  });

  test('현재 10장 이상이면 AttachLimit 이고 피커·클립보드를 열지 않는다', () async {
    port.galleryBytes = kTinyPng;
    port.clipboardBytes = kTinyPng;
    expect(await service.pickFromGallery(10), isA<AttachLimit>());
    expect(await service.takePhoto(11), isA<AttachLimit>());
    expect(await service.pasteFromClipboard(10), isA<AttachLimit>());
    expect(port.galleryCalls, 0);
    expect(port.cameraCalls, 0);
    expect(port.clipboardCalls, 0);
  });

  test('압축 실패 → AttachFailed(원본 폴백 없음), 파일 미생성', () async {
    port.galleryBytes = kTinyPng;
    compressor.shouldThrow = true;
    final result = await service.pickFromGallery(0);
    expect(result, isA<AttachFailed>());
    expect((result as AttachFailed).error, isA<StateError>());
    expect(AttachmentStore.instance.root.existsSync(), isFalse);
  });

  test('deleteFiles 는 스토어 delete 위임', () async {
    port.galleryBytes = kTinyPng;
    final name = ((await service.pickFromGallery(0)) as AttachOk).fileName;
    await service.deleteFiles([name]);
    expect(await AttachmentStore.instance.exists(name), isFalse);
  });

  test('read 가 던지면 AttachFailed, 압축기 미호출·파일 미생성', () async {
    port.throwOnRead = StateError('picker exploded');
    final result = await service.pickFromGallery(0);
    expect(result, isA<AttachFailed>());
    expect(compressor.calls, 0);
    expect(AttachmentStore.instance.root.existsSync(), isFalse);
  });

  test('카메라 권한 거부(PlatformException camera_access_denied) → AttachPermissionDenied', () async {
    port.throwOnRead = PlatformException(code: 'camera_access_denied');
    expect(await service.takePhoto(0), isA<AttachPermissionDenied>());
    expect(compressor.calls, 0);
  });

  test('다른 PlatformException 은 AttachFailed', () async {
    port.throwOnRead = PlatformException(code: 'already_active');
    expect(await service.pickFromGallery(0), isA<AttachFailed>());
  });

  test('피커가 빈 바이트를 주면 취소가 아니라 AttachFailed', () async {
    port.galleryBytes = Uint8List(0);
    expect(await service.pickFromGallery(0), isA<AttachFailed>());
    port.cameraBytes = Uint8List(0);
    expect(await service.takePhoto(0), isA<AttachFailed>());
  });

  test('production(): 스토어 미초기화면 StateError', () {
    AttachmentStore.instance = null;
    expect(AttachmentService.production, throwsStateError);
  });
}
