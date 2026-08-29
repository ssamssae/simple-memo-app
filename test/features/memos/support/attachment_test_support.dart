import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_memo_app/features/memos/services/attachment_store.dart';

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
