import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/memo.dart';

/// 첨부 사진 파일 저장소 — `<앱문서>/attachments/<uuid>.jpg` 평면 구조.
///
/// 메모 id 하위 폴더를 두지 않는다: 새 메모는 저장 시점에야 id 가 생기므로
/// 편집 중 먼저 파일을 만들 수 있어야 한다. 메모는 파일명만 들고 있다.
class AttachmentStore {
  AttachmentStore({required Directory root}) : _root = root;

  static const _uuid = Uuid();
  static AttachmentStore? _instance;

  /// 프로세스 단일 인스턴스. 초기화 전(테스트·path_provider 실패)엔 null 이며
  /// 호출부는 null 이면 사진 기능만 조용히 비활성화한다(크래시 0).
  static AttachmentStore? get maybeInstance => _instance;

  static AttachmentStore get instance =>
      _instance ?? (throw StateError('AttachmentStore.init() 이 먼저 불려야 한다'));

  @visibleForTesting
  static set instance(AttachmentStore? store) => _instance = store;

  /// 앱 시작 시 1회. 실패해도 던지지 않는다 — 인스턴스가 null 로 남을 뿐.
  static Future<void> init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _instance = AttachmentStore(
        root: Directory('${docs.path}${Platform.pathSeparator}attachments'),
      );
    } catch (e) {
      debugPrint('[AttachmentStore.init] $e');
    }
  }

  final Directory _root;
  Directory get root => _root;

  File fileFor(String name) {
    if (!Memo.isValidImageFileName(name)) {
      throw ArgumentError.value(name, 'name', 'invalid attachment file name');
    }
    return File('${_root.path}${Platform.pathSeparator}$name');
  }

  Future<bool> exists(String name) => fileFor(name).exists();

  /// JPEG 바이트를 새 파일로 저장하고 파일명을 돌려준다.
  Future<String> save(Uint8List jpegBytes) async {
    await _root.create(recursive: true);
    final name = '${_uuid.v4()}.jpg';
    await fileFor(name).writeAsBytes(jpegBytes, flush: true);
    return name;
  }

  /// 없는 파일·검증 실패 파일명은 무시한다.
  Future<void> delete(Iterable<String> names) async {
    for (final name in names) {
      if (!Memo.isValidImageFileName(name)) continue;
      try {
        final file = fileFor(name);
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (e) {
        debugPrint('[AttachmentStore.delete] $name: $e');
      }
    }
  }

  /// `referenced` 에 없고 [minAge] 보다 오래된 파일을 지운다. 두 겹 보호:
  /// (1) cold start 처럼 편집 세션이 없는 시점에만 부를 것, (2) 최근 파일은 편집 중 대기분
  /// (아직 어느 메모도 참조 안 함)일 수 있어 나이로 한 번 더 거른다. 참조가 잠깐 유실된
  /// 경우(구버전 빌드가 images 키를 떨어뜨린 뒤 다시 읽는 등)에도 즉시 삭제로 번지지 않는다.
  Future<int> sweepOrphans(
    Iterable<String> referenced, {
    Duration minAge = const Duration(days: 1),
  }) async {
    if (!await _root.exists()) return 0;
    final keep = referenced.toSet();
    final cutoff = DateTime.now().subtract(minAge);
    var removed = 0;
    await for (final entry in _root.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (keep.contains(name)) continue;
      try {
        if ((await entry.lastModified()).isAfter(cutoff)) continue;
        await entry.delete();
        removed++;
      } on FileSystemException catch (e) {
        debugPrint('[AttachmentStore.sweepOrphans] $name: $e');
      }
    }
    return removed;
  }
}
