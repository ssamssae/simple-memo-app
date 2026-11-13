import '../../../models/memo.dart';

/// 메모 체크 칸·완료 탭의 순수 목록 연산 (T-261113-024).
///
/// 저장 배열 순서는 바꾸지 않는다. 완료는 [Memo.doneAt] 표시만 하므로
/// 체크를 풀면 메모 목록의 원래 자리(즐겨찾기·일반 묶음 안)로 돌아간다.
/// 수정 시각(updatedAt)도 바꾸지 않는다 — 즐겨찾기 토글과 같은 규칙(검색 순위·백업 병합 기준).
class MemoDoneOps {
  MemoDoneOps._();

  /// 메모 목록에 보이는 메모: 휴지통도 완료도 아님.
  static bool isOpen(Memo m) => m.deletedAt == null && m.doneAt == null;

  /// 완료 탭에 보이는 메모: 휴지통이 아니고 완료함. 최근 완료가 위, 같으면 저장 순서.
  static List<Memo> done(List<Memo> all) {
    final indexed = <(int, Memo)>[
      for (var i = 0; i < all.length; i++)
        if (all[i].deletedAt == null && all[i].doneAt != null) (i, all[i]),
    ];
    indexed.sort((a, b) {
      final byDone = b.$2.doneAt!.compareTo(a.$2.doneAt!);
      return byDone != 0 ? byDone : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// [id] 메모의 완료 시각을 [doneAt] 으로 바꾼 새 목록. null 이면 체크를 푼다.
  /// 휴지통 메모와 없는 id 는 그대로 둔다.
  static List<Memo> setDone(List<Memo> all, String id, DateTime? doneAt) => [
    for (final m in all)
      if (m.id == id && m.deletedAt == null) m.copyWith(doneAt: doneAt) else m,
  ];

  /// 「완료 비우기」: [ids] 중 완료한 활성 메모를 휴지통으로 옮긴다(soft delete).
  /// 완료 표시는 남긴다 — 휴지통에서 되살리면 완료 탭으로 돌아온다.
  static List<Memo> trashDone(List<Memo> all, Set<String> ids, DateTime now) =>
      [
        for (final m in all)
          if (ids.contains(m.id) && m.deletedAt == null && m.doneAt != null)
            m.copyWith(deletedAt: now)
          else
            m,
      ];

  /// 「완료 비우기」 되돌리기: [ids] 중 아직 휴지통에 있는 메모를 꺼낸다.
  static List<Memo> untrash(List<Memo> all, Set<String> ids) => [
    for (final m in all)
      if (ids.contains(m.id) && m.deletedAt != null)
        m.copyWith(deletedAt: null)
      else
        m,
  ];
}
