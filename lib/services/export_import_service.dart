import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/memo.dart';
import '../features/memos/services/attachment_store.dart';
import '../features/memos/services/memo_backup_archive.dart';
import 'memo_storage.dart';
import 'snapshot_store.dart';

class ExportImportService {
  static bool _restoring = false;

  // 할 일은 이제 메모다(T-261113-024) — todos.json 을 더 넣지 않는다. 완료 표시(doneAt)는
  // 메모 JSON 에 실려 간다. 옛 백업의 todos.json 은 MemoBackupArchive.decode 가 메모로 바꾼다.
  static Future<Uint8List> exportBytes(List<Memo> memos) =>
      MemoBackupArchive.encode(memos, store: AttachmentStore.maybeInstance);

  static String backupFileName() =>
      'memoyo-export-${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.zip';

  static Future<bool> saveBackupFile(List<Memo> memos) async {
    final bytes = await exportBytes(memos);
    final path = await FilePicker.saveFile(
      fileName: backupFileName(),
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: bytes,
    );
    return path != null;
  }

  static Future<T> _restoreLocked<T>(Future<T> Function() action) async {
    if (_restoring) throw StateError('A restore is already in progress');
    _restoring = true;
    try {
      return await action();
    } finally {
      _restoring = false;
    }
  }

  static List<Memo> mergeSilently(List<Memo> existing, List<Memo> incoming) {
    final byId = <String, Memo>{for (final m in existing) m.id: m};
    for (final m in incoming) {
      final prev = byId[m.id];
      if (prev == null || m.updatedAt.isAfter(prev.updatedAt)) {
        byId[m.id] = m;
      }
    }
    return byId.values.toList();
  }

  static List<Memo>? parseImport(String source) {
    try {
      return Memo.decodeList(source);
    } catch (_) {
      return null;
    }
  }

  /// Parses [source], snapshots current memos for undo, and silently merges.
  /// Returns (importedCount, totalCount).
  /// Throws [FormatException] on invalid JSON — caller shows toast.
  static Future<(int, int)> importFromSource(String source) =>
      importBytes(utf8.encode(source));

  static Future<(int, int)> importBytes(
    List<int> bytes, {
    Future<bool> Function(List<Memo>)? saveMemos,
  }) => _restoreLocked(() async {
    // 옛 백업의 할 일(todos.json)은 decode 가 메모로 바꿔 incoming 에 넣는다(T-261113-024).
    final backup = MemoBackupArchive.decode(bytes);
    final incoming = backup.memos;
    if (incoming.isEmpty) {
      // 메모를 쓰지 않았다 — 예전 가져오기의 기록이 이번 「되돌리기」로 쓰이면
      // 지금 메모가 옛 상태로 바뀌고 사진 파일이 지워진다(T-261112-052 검토 I5).
      await SnapshotStore.clear();
      return (0, 0);
    }

    final existing = await MemoStorage.loadMemos(throwOnError: true);
    final merged = mergeSilently(existing, incoming);
    final incomingSet = incoming.toSet();
    if (!merged.any(incomingSet.contains)) {
      await SnapshotStore.clear();
      return (incoming.length, merged.length);
    }
    final oldSnapshot = await SnapshotStore.load();
    final store = AttachmentStore.maybeInstance;
    final created = <String>[];
    final names = <String, String>{};
    var snapshotAttempted = false;
    var saveAttempted = false;
    try {
      final restored = <Memo>[];
      for (final memo in merged) {
        if (!backup.isZip ||
            !incomingSet.contains(memo) ||
            memo.imageFiles.isEmpty) {
          restored.add(memo);
          continue;
        }
        if (store == null) throw BackupPhotoUnavailableException();
        final images = <String>[];
        for (final name in memo.imageFiles) {
          var local = names[name];
          if (local == null) {
            local = await store.save(backup.photos[name]!);
            created.add(local);
            names[name] = local;
          }
          images.add(local);
        }
        restored.add(memo.copyWith(imageFiles: images));
      }
      snapshotAttempted = true;
      await SnapshotStore.save(Memo.encodeList(existing));
      saveAttempted = true;
      if (!await (saveMemos ?? MemoStorage.saveMemos)(restored)) {
        throw StateError('Could not save restored memos');
      }
      return (incoming.length, restored.length);
    } catch (_) {
      final rolledBack =
          !saveAttempted || await MemoStorage.saveMemos(existing);
      if (snapshotAttempted) {
        try {
          if (oldSnapshot == null) {
            await SnapshotStore.clear();
          } else {
            await SnapshotStore.save(oldSnapshot);
          }
        } catch (_) {
          /* The original persistence failure is reported below. */
        }
      }
      // An uncertain rollback must not remove files a persisted memo may use.
      if (rolledBack) await store?.delete(created);
      rethrow;
    }
  });

  /// Returns (importedCount, totalCount) on success; null on user cancel.
  /// Throws [FormatException] on invalid JSON — caller shows toast.
  static Future<(int, int)?> pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.size > MemoBackupArchive.maxBytes) throw BackupSizeException();
    final path = picked.path;
    if (path == null) {
      return picked.bytes == null ? null : importBytes(picked.bytes!);
    }
    final file = File(path);
    if (await file.length() > MemoBackupArchive.maxBytes) {
      throw BackupSizeException();
    }
    return importBytes(await file.readAsBytes());
  }

  static Future<List<Memo>?> undoImport({
    Future<bool> Function(List<Memo>)? saveMemos,
  }) => _restoreLocked(() async {
    final snapshot = await SnapshotStore.load();
    if (snapshot == null) return null;
    final restored = SnapshotStore.decodeMemos(snapshot);
    final current = await MemoStorage.loadMemos(throwOnError: true);
    try {
      if (!await (saveMemos ?? MemoStorage.saveMemos)(restored)) {
        throw StateError('Could not undo import');
      }
      await SnapshotStore.clear();
    } catch (_) {
      await MemoStorage.saveMemos(current);
      try {
        await SnapshotStore.save(snapshot);
      } catch (_) {
        /* Preserve photo files and report the persistence failure. */
      }
      rethrow;
    }
    final keep = restored.expand((m) => m.imageFiles).toSet();
    await AttachmentStore.maybeInstance?.delete(
      current.expand((m) => m.imageFiles).where((name) => !keep.contains(name)),
    );
    return restored;
  });
}
