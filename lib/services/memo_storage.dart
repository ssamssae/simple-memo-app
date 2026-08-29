import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/memos/services/attachment_store.dart';
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
  /// 호출 위치: cold start(_loadMemos) + app resume.
  static Future<int> purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(Memo.trashRetention);
    return _removeWhere((m) {
      final d = m.deletedAt;
      if (d == null) return false; // 활성 — 유지
      return !d.isAfter(cutoff); // 보관기간 지난 휴지통만 제거
    });
  }

  /// 즉시 영구삭제 (휴지통 항목 개별). 제거된 메모 수 반환.
  static Future<int> deleteForever(Set<String> ids) =>
      _removeWhere((m) => ids.contains(m.id));

  /// 휴지통 비우기. 활성 메모(deletedAt == null)는 무변경. 제거된 메모 수 반환.
  static Future<int> emptyTrash() => _removeWhere((m) => m.deletedAt != null);

  /// 영구삭제 단일 펀넬 — 메모 제거 + 그 메모들의 첨부 파일 삭제 (T-260829-022).
  /// 파일 삭제는 메모 저장이 끝난 뒤에만, 살아남는 메모가 여전히 참조하는 파일은
  /// 지우지 않으며, 스토어가 없으면(테스트·초기화 실패) 건너뛴다.
  static Future<int> _removeWhere(bool Function(Memo) shouldRemove) async {
    final all = await loadMemos();
    final removed = <Memo>[];
    final survivors = <Memo>[];
    for (final m in all) {
      (shouldRemove(m) ? removed : survivors).add(m);
    }
    if (removed.isEmpty) return 0;
    await saveMemos(survivors);
    final store = AttachmentStore.maybeInstance;
    if (store != null) {
      final stillReferenced = survivors.expand((m) => m.imageFiles).toSet();
      final orphaned = removed
          .expand((m) => m.imageFiles)
          .where((name) => !stillReferenced.contains(name));
      await store.delete(orphaned);
    }
    return removed.length;
  }
}
