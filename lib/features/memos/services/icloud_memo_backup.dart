import 'package:flutter/services.dart';

/// iCloud 에 있는 메모요 백업 파일 하나.
class ICloudBackupFile {
  const ICloudBackupFile({
    required this.name,
    required this.modified,
    required this.size,
  });

  final String name;
  final DateTime modified;
  final int size;

  /// 고르기 창에 보여 줄 날짜와 시각. Drive 백업 고르기와 같은 모양(`2026-11-16 19:05:00`).
  String get label {
    final match = RegExp(
      r'memoyo-export-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})',
    ).firstMatch(name);
    if (match == null) return name;
    return '${match[1]} ${match[2]}:${match[3]}:${match[4]}';
  }
}

/// 파일 백업(`ExportImportService.backupFileName`)과 같은 이름. iCloud 폴더에서도 같은 zip 이다.
String memoyoBackupFileName(DateTime now) =>
    'memoyo-export-${now.toIso8601String().replaceAll(':', '-').split('.').first}.zip';

/// [memoyoBackupFileName] 이 만든 이름인지. iCloud 폴더에서 메모요 백업만 고를 때 쓴다.
bool isMemoyoBackupFileName(String name) =>
    RegExp(r'^memoyo-export-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.zip$')
        .hasMatch(name);

/// 아이폰 기본 백업 — 로그인 없는 iCloud (T-261116-041, 한줄일기 방식).
///
/// 기기에 로그인된 Apple 계정의 iCloud Drive 앱 폴더
/// (컨테이너 iCloud.com.daejongkang.simpleMemoApp 의 Documents)에 백업 zip 을 둔다.
/// 실제 파일 읽기·쓰기는 iOS 쪽 `MemoyoICloudBackup`(AppDelegate.swift)이 한다.
class ICloudMemoBackup {
  ICloudMemoBackup({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('memoyo/icloud_backup');

  final MethodChannel _channel;

  /// iCloud 에 보관하는 백업 개수. 새 백업 뒤 더 오래된 것은 지운다.
  static const keep = 5;

  /// 이 기기가 iCloud 에 로그인돼 있고 iCloud Drive 를 쓸 수 있는지.
  Future<bool> isAvailable() async {
    try {
      final status = await _channel.invokeMapMethod<String, Object?>('status');
      return status?['available'] == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> upload(Uint8List bytes, {DateTime? now}) async {
    await _channel.invokeMethod<void>('save', {
      'name': memoyoBackupFileName(now ?? DateTime.now()),
      'bytes': bytes,
    });
    try {
      await _prune();
    } catch (_) {
      // 새 백업은 이미 저장됐다. 오래된 백업 정리는 다음 백업 때 다시 한다.
    }
  }

  /// 최신 백업부터. 이름에 날짜가 들어 있어 이름순이 곧 시간순이다.
  Future<List<ICloudBackupFile>> list() async {
    final raw = await _channel.invokeListMethod<Object?>('list') ?? const [];
    final files = <ICloudBackupFile>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name'];
      if (name is! String || !isMemoyoBackupFileName(name)) continue;
      final modified = item['modified'];
      final size = item['size'];
      files.add(
        ICloudBackupFile(
          name: name,
          modified: DateTime.fromMillisecondsSinceEpoch(
            modified is int ? modified : 0,
          ),
          size: size is int ? size : 0,
        ),
      );
    }
    files.sort((a, b) => b.name.compareTo(a.name));
    return files;
  }

  Future<Uint8List> download(String name) async {
    final bytes = await _channel.invokeMethod<Uint8List>('read', {
      'name': name,
    });
    if (bytes == null) throw const FormatException('Invalid backup');
    return bytes;
  }

  /// 백업 파일 하나를 지운다. 보관 개수를 넘는 정리는 이 메서드를 쓴다.
  Future<void> delete(String name) async {
    await _channel.invokeMethod<void>('delete', {'name': name});
  }

  Future<void> _prune() async {
    final files = await list();
    for (final old in files.skip(keep)) {
      await delete(old.name);
    }
  }
}
