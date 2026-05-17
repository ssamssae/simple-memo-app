import 'package:shared_preferences/shared_preferences.dart';

class SnapshotStore {
  static const _key = 'memos_pre_import';

  static Future<void> save(String memosJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, memosJson);
  }

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<bool> hasSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
