import '../models/memo.dart';

/// 메모요 1.0.8 검색 (T-260615-26, spec docs/specs/1.0.8-search.md).
///
/// pure 함수 — 휴지통/영속 layer 인지 X. 호출 컨텍스트가 `memos` 인자로 대상 결정
/// (메모 리스트 = 활성 메모, spec §4.2). 인덱싱 = in-memory linear scan (옵션 A).
///
/// 매칭(§2.3): case-insensitive + 공백 트림/단일화 후 substring.
///   - 한글 자소 분리 X — 'ㄱ' 검색 시 '가' 매치 X (명시적 contract, 1.0.9 후보).
///   - 빈/공백 쿼리 → 입력 메모 그대로 반환.
/// 랭킹(§3.4 옵션 C): 즐겨찾기 > 제목(첫 줄) 매치 > 본문 매치 → updatedAt desc.
class SearchService {
  /// 활성 메모를 query 로 검색·랭킹해 반환.
  static List<Memo> search(List<Memo> memos, String query) {
    final q = _normalize(query);
    if (q.isEmpty) return memos;

    final matched = memos
        .where((m) => _titleHit(m, q) || _bodyHit(m, q))
        .toList();

    matched.sort((a, b) {
      // 1) 즐겨찾기 우선
      final favA = a.isFavorite ? 0 : 1;
      final favB = b.isFavorite ? 0 : 1;
      if (favA != favB) return favA - favB;
      // 2) 제목 매치 우선
      final titleA = _titleHit(a, q) ? 0 : 1;
      final titleB = _titleHit(b, q) ? 0 : 1;
      if (titleA != titleB) return titleA - titleB;
      // 3) updatedAt 내림차순
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return matched;
  }

  /// query 매치 위치 기준 앞뒤 [context]자 발췌 + 매치 범위(하이라이트용, §3.5).
  /// 첫 매치만 발췌. 매치 없으면 start = -1. 잘린 쪽은 '…' 부착.
  /// 매치는 case-insensitive, 발췌 텍스트는 원본 case 보존.
  static SearchExcerpt excerpt(String source, String query, {int context = 30}) {
    final q = _normalize(query);
    if (q.isEmpty) return SearchExcerpt(source, -1, 0);
    final idx = source.toLowerCase().indexOf(q);
    if (idx < 0) return SearchExcerpt(source, -1, 0);

    var startCtx = idx - context;
    var prefix = '';
    if (startCtx > 0) {
      prefix = '…';
    } else {
      startCtx = 0;
    }
    var endCtx = idx + q.length + context;
    var suffix = '';
    if (endCtx < source.length) {
      suffix = '…';
    } else {
      endCtx = source.length;
    }
    final text = '$prefix${source.substring(startCtx, endCtx)}$suffix';
    final matchStart = prefix.length + (idx - startCtx);
    return SearchExcerpt(text, matchStart, q.length);
  }

  static bool _titleHit(Memo m, String normQuery) =>
      _normalize(m.firstLine).contains(normQuery);

  static bool _bodyHit(Memo m, String normQuery) =>
      _normalize(m.content).contains(normQuery);

  // 소문자화 + 트림 + 다중 공백 단일화 (§2.3). 한글 자소 분리는 하지 않음.
  static String _normalize(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// excerpt 결과: 발췌 텍스트 + 매치 시작 index/길이(text 내부 기준). start -1 = 매치 없음.
class SearchExcerpt {
  const SearchExcerpt(this.text, this.start, this.length);
  final String text;
  final int start;
  final int length;
}
