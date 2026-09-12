import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/memo.dart';

class SnapshotStore {
  static const _key = 'memos_pre_import';

  static Future<void> save(String memosJson) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, memosJson)) {
      throw StateError('Could not save import snapshot');
    }
  }

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<bool> hasSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<Set<String>> referencedImages() async {
    final snapshot = await load();
    if (snapshot == null) return {};
    return decodeMemos(snapshot).expand((memo) => memo.imageFiles).toSet();
  }

  static List<Memo> decodeMemos(String snapshot) {
    final decoded = jsonDecode(snapshot);
    if (decoded is! List ||
        decoded.any((row) => row is! Map<String, dynamic>)) {
      throw const FormatException('Could not read import snapshot');
    }
    return decoded.cast<Map<String, dynamic>>().map(Memo.fromJson).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key)) {
      throw StateError('Could not clear import snapshot');
    }
  }
}
