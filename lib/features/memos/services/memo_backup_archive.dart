import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;

import '../../../models/memo.dart';
import 'attachment_store.dart';

class BackupPhotoUnavailableException implements Exception {}

class BackupSizeException implements Exception {}

/// Shared file/Drive format. Decode validates everything before restore writes.
class MemoBackupArchive {
  MemoBackupArchive(this.memos, this.photos, {required this.isZip});

  final List<Memo> memos;
  final Map<String, Uint8List> photos;
  final bool isZip;
  static const maxBytes = 128 * 1024 * 1024;
  static const maxPhotoBytes = 8 * 1024 * 1024;
  static const maxJsonBytes = 16 * 1024 * 1024;
  static const maxEntries = 4096;

  static Future<Uint8List> encode(
    List<Memo> memos, {
    AttachmentStore? store,
  }) async {
    final json = utf8.encode(Memo.encodeList(memos));
    final names = memos.expand((m) => m.imageFiles).toSet();
    if (json.length > maxJsonBytes || names.length + 1 > maxEntries) {
      throw BackupSizeException();
    }
    final archive = zip.Archive()
      ..add(zip.ArchiveFile('memos.json', json.length, json));
    var total = json.length;
    for (final name in names) {
      if (store == null || !Memo.isValidImageFileName(name)) {
        throw BackupPhotoUnavailableException();
      }
      final file = store.fileFor(name);
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw BackupPhotoUnavailableException();
      }
      final size = await file.length();
      if (size > maxPhotoBytes || total + size > maxBytes) {
        throw BackupSizeException();
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw BackupPhotoUnavailableException();
      total += bytes.length;
      if (bytes.length > maxPhotoBytes || total > maxBytes) {
        throw BackupSizeException();
      }
      archive.add(
        zip.ArchiveFile.noCompress('attachments/$name', bytes.length, bytes),
      );
    }
    final result = zip.ZipEncoder().encode(archive);
    if (result.length > maxBytes) throw BackupSizeException();
    return Uint8List.fromList(result);
  }

  static MemoBackupArchive decode(List<int> bytes) {
    if (bytes.length > maxBytes) throw BackupSizeException();
    try {
      if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
        if (bytes.length > maxJsonBytes) throw BackupSizeException();
        return MemoBackupArchive(_memos(utf8.decode(bytes)), {}, isZip: false);
      }
      final directory = zip.ZipDirectory()..read(zip.InputMemoryStream(bytes));
      if (directory.fileHeaders.length > maxEntries) {
        throw BackupSizeException();
      }
      final names = <String>{};
      var total = 0;
      // Check headers before decompressing, including duplicate and symlink entries.
      for (final header in directory.fileHeaders) {
        final name = header.filename;
        final file = header.file;
        final type = (header.externalFileAttributes >> 16) & 0xf000;
        if (!names.add(name) ||
            file == null ||
            name != file.filename ||
            ((header.generalPurposeBitFlag | file.flags) & 1) != 0 ||
            (type != 0 &&
                type != 0x8000 &&
                !(type == 0x4000 && name == 'attachments/')) ||
            (header.compressionMethod != 0 && header.compressionMethod != 8)) {
          throw const FormatException('Unsupported ZIP entry');
        }
        if (name != 'memos.json' &&
            name != 'attachments/' &&
            !(name.startsWith('attachments/') &&
                Memo.isValidImageFileName(name.substring(12)))) {
          throw const FormatException('Invalid backup path');
        }
        final size = header.uncompressedSize;
        total += size;
        if (size < 0 ||
            size > (name == 'memos.json' ? maxJsonBytes : maxPhotoBytes) ||
            total > maxBytes) {
          throw BackupSizeException();
        }
      }
      if (!names.contains('memos.json')) {
        throw const FormatException('Missing memos.json');
      }
      String? json;
      final photos = <String, Uint8List>{};
      for (final header in directory.fileHeaders) {
        final output = _BoundedBytes(header.uncompressedSize);
        final raw = header.file!.getRawContent();
        if (header.compressionMethod == 8) {
          final decoder = ZLibDecoder(raw: true).startChunkedConversion(output);
          decoder.add(raw);
          decoder.close();
        } else {
          output.add(raw);
        }
        final content = output.bytes.takeBytes();
        // archive 4.0.9 does not implement ZipDecoder's verify flag.
        if (content.length != header.uncompressedSize ||
            zip.getCrc32(content) != header.crc32) {
          throw const FormatException('Corrupt backup entry');
        }
        if (header.filename == 'memos.json') {
          json = utf8.decode(content);
        } else if (header.filename != 'attachments/') {
          if (content.isEmpty) throw const FormatException('Empty photo');
          photos[header.filename.substring(12)] = content;
        }
      }
      final memos = _memos(json!, strictImages: true);
      if (memos
          .expand((m) => m.imageFiles)
          .any((name) => !photos.containsKey(name))) {
        throw const FormatException('Missing backup photo');
      }
      return MemoBackupArchive(memos, photos, isZip: true);
    } on BackupSizeException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid Memoyo backup');
    }
  }

  static List<Memo> _memos(String source, {bool strictImages = false}) {
    final decoded = jsonDecode(source);
    if (decoded is! List ||
        decoded.any((row) => row is! Map<String, dynamic>)) {
      throw const FormatException('Invalid memo list');
    }
    if (strictImages) {
      for (final row in decoded.cast<Map<String, dynamic>>()) {
        final images = row['images'];
        if (images != null &&
            (images is! List ||
                images.any(
                  (name) => name is! String || !Memo.isValidImageFileName(name),
                ))) {
          throw const FormatException('Invalid photo references');
        }
      }
    }
    return decoded.cast<Map<String, dynamic>>().map(Memo.fromJson).toList();
  }
}

class _BoundedBytes implements Sink<List<int>> {
  _BoundedBytes(this.limit);
  final int limit;
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> data) {
    if (bytes.length + data.length > limit) {
      throw const FormatException('ZIP size mismatch');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
