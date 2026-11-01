import '../../../models/memo.dart';

/// 즐겨찾기 토글 때 메모 목록 순서를 정한다 (T-261101-034).
///
/// 목록 순서 = 저장된 배열 순서다(수동 순서). 따로 정렬하지 않는다 — 새 메모는 일반 묶음
/// 맨 위에 들어가고, 사용자가 끌어서 옮긴다. 즐겨찾기 묶음은 늘 앞에 온다.
///
/// 즐겨찾기로 올리면 메모가 배열 안에서 즐겨찾기 묶음으로 실제로 옮겨지므로, 원래 자리를
/// 따로 적어 두지 않으면 풀 때 돌아갈 곳이 없다. 그래서 올릴 때 바로 아래 일반 메모 id 를
/// [Memo.favoriteAnchorId] 에 저장하고, 풀 때 그 메모 바로 위로 돌려놓는다.
/// 기록이 없거나(옛 데이터·맨 아래였음) 그 메모가 영구 삭제됐으면, 새 메모가 위에 쌓이는
/// 평소 순서(만든 시각 최신 먼저)에서의 자리로 돌려놓는다.
///
/// 수정 시각(updatedAt)은 바꾸지 않는다 — 검색 순위와 백업 병합 기준이다.
class FavoriteOrder {
  FavoriteOrder._();

  /// [id] 메모의 즐겨찾기를 뒤집은 새 목록. 없는 id 면 [memos] 를 그대로 돌려준다.
  static List<Memo> toggle(List<Memo> memos, String id) {
    final index = memos.indexWhere((m) => m.id == id);
    if (index == -1) return memos;
    return memos[index].isFavorite
        ? _unfavorite(memos, index)
        : _favorite(memos, index);
  }

  static List<Memo> _favorite(List<Memo> memos, int index) {
    String? anchorId;
    for (var i = index + 1; i < memos.length; i++) {
      final below = memos[i];
      // 휴지통 메모는 영구 삭제되기 쉬워 자리로 쓰지 않는다.
      if (!below.isFavorite && below.deletedAt == null) {
        anchorId = below.id;
        break;
      }
    }
    final out = List.of(memos);
    out[index] = memos[index].copyWith(
      isFavorite: true,
      favoriteAnchorId: anchorId,
    );
    // 기존과 같다: 즐겨찾기 묶음 끝으로 간다.
    return _grouped(out);
  }

  static List<Memo> _unfavorite(List<Memo> memos, int index) {
    final memo = memos[index];
    final out = _grouped(List.of(memos)..removeAt(index));
    final at = _anchorIndex(out, memo) ?? _createdAtIndex(out, memo);
    out.insert(at, memo.copyWith(isFavorite: false, favoriteAnchorId: null));
    return out;
  }

  /// 적어 둔 아래 이웃의 위치. 그 이웃도 즐겨찾기로 올라갔으면 그 이웃이 적어 둔 자리를 따른다.
  static int? _anchorIndex(List<Memo> memos, Memo memo) {
    final seen = <String>{memo.id};
    var anchorId = memo.favoriteAnchorId;
    while (anchorId != null && seen.add(anchorId)) {
      final id = anchorId;
      final i = memos.indexWhere((m) => m.id == id);
      if (i == -1) return null; // 영구 삭제됨
      final anchor = memos[i];
      if (!anchor.isFavorite) return i;
      anchorId = anchor.favoriteAnchorId;
    }
    return null;
  }

  /// 만든 시각 최신 먼저인 평소 순서에서의 자리: 나보다 오래된 첫 일반 메모 바로 위.
  static int _createdAtIndex(List<Memo> memos, Memo memo) {
    final i = memos.indexWhere(
      (m) => !m.isFavorite && m.createdAt.isBefore(memo.createdAt),
    );
    return i == -1 ? memos.length : i;
  }

  static List<Memo> _grouped(List<Memo> memos) => [
    ...memos.where((m) => m.isFavorite),
    ...memos.where((m) => !m.isFavorite),
  ];
}
