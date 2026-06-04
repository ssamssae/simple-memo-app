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

  /// [Memo.trashRetention](기본 30일) 지난 soft-deleted 메모를 영구 삭제한다.
  /// 활성 메모(deletedAt == null)는 절대 건드리지 않는다.
  /// 변경이 있을 때만 저장하고, 영구삭제된 메모 수를 반환한다.
  /// 호출 위치(다음 PR): cold start(_loadMemos) + app resume.
  static Future<int> purgeExpiredTrash() async {
    final all = await loadMemos();
    final cutoff = DateTime.now().subtract(Memo.trashRetention);
    final survivors = all.where((m) {
      final d = m.deletedAt;
      if (d == null) return true; // 활성 — 유지
      return d.isAfter(cutoff); // 휴지통이지만 보관기간 안 지남 — 유지
    }).toList();
    final purged = all.length - survivors.length;
    if (purged > 0) await saveMemos(survivors);
    return purged;
  }
}
