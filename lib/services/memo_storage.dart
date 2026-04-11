import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memo.dart';

class MemoStorage {
  static const _key = 'memos';

  static Future<List<Memo>> loadMemos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null || data.isEmpty) return [];
      return Memo.decodeList(data);
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveMemos(List<Memo> memos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, Memo.encodeList(memos));
    } catch (e) {
      // 저장 실패 시 크래시 방지 — 다음 저장 시 재시도됨
      debugPrint('[MemoStorage.saveMemos] $e');
    }
  }
}
