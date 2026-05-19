import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/memo.dart';
import 'memo_storage.dart';
import 'snapshot_store.dart';

class ExportImportService {
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

  static Future<File> writeExportFile(List<Memo> memos) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '')
        .substring(0, 15);
    final file = File('${dir.path}/memoyo-export-$ts.json');
    await file.writeAsString(Memo.encodeList(memos));
    return file;
  }

  static Future<void> shareExport(
    List<Memo> memos, {
    Rect? sharePositionOrigin,
  }) async {
    final file = await writeExportFile(memos);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: '메모요 백업',
      sharePositionOrigin:
          sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100),
    );
  }

  /// Returns (importedCount, totalCount) on success; null on user cancel.
  /// Throws [FormatException] on invalid JSON — caller shows toast.
  static Future<(int, int)?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;

    final source = await File(path).readAsString();
    final incoming = parseImport(source);
    if (incoming == null) {
      throw const FormatException('not a memoyo backup');
    }
    if (incoming.isEmpty) {
      return (0, 0);
    }

    final existing = await MemoStorage.loadMemos();
    await SnapshotStore.save(Memo.encodeList(existing));
    final merged = mergeSilently(existing, incoming);
    await MemoStorage.saveMemos(merged);
    return (incoming.length, merged.length);
  }

  static Future<List<Memo>?> undoImport() async {
    final snapshot = await SnapshotStore.load();
    if (snapshot == null) return null;
    final restored = Memo.decodeList(snapshot);
    await MemoStorage.saveMemos(restored);
    await SnapshotStore.clear();
    return restored;
  }
}
