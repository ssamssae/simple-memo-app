import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/search_service.dart';

/// T-260615-26 메모요 1.0.8 검색 — SearchService 단위 테스트 (spec §5.1 / §6.3).
/// SearchService.search 는 pure 함수: 활성 메모 + 쿼리 → 매칭+랭킹된 메모 리스트.

Memo _memo(
  String content, {
  bool favorite = false,
  DateTime? updatedAt,
}) {
  final t = updatedAt ?? DateTime(2026, 1, 1);
  return Memo(
    id: content.hashCode.toString() + (favorite ? 'F' : ''),
    content: content,
    isFavorite: favorite,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  group('SearchService.search — 매칭', () {
    test('빈 쿼리 → 전체 메모 반환', () {
      final memos = [_memo('a'), _memo('b')];
      expect(SearchService.search(memos, ''), memos);
    });

    test('공백 only 쿼리 → 전체 반환', () {
      final memos = [_memo('a'), _memo('b')];
      expect(SearchService.search(memos, '   '), memos);
    });

    test('제목(첫 줄) 매치 → 정확히 1건', () {
      final memos = [_memo('Karpathy 룰\n본문'), _memo('딴 메모\n내용')];
      final r = SearchService.search(memos, 'Karpathy');
      expect(r.length, 1);
      expect(r.first.firstLine, 'Karpathy 룰');
    });

    test('본문(첫 줄 아님) 매치 → 1건', () {
      final memos = [_memo('제목줄\nKarpathy 가 본문에'), _memo('딴 메모')];
      final r = SearchService.search(memos, 'Karpathy');
      expect(r.length, 1);
    });

    test('제목+본문 동시 매치 → 1건 (중복 X)', () {
      final memos = [_memo('Karpathy 제목\nKarpathy 본문')];
      expect(SearchService.search(memos, 'Karpathy').length, 1);
    });

    test('대소문자 무관', () {
      final memos = [_memo('karpathy 룰')];
      expect(SearchService.search(memos, 'KARPATHY').length, 1);
    });

    test('다중 공백 트림/단일화', () {
      final memos = [_memo('a b 텍스트')];
      expect(SearchService.search(memos, 'a  b').length, 1);
    });

    test('한글 자소 분리 X (명시적 contract): ㄱ 검색 시 가 매치 X', () {
      final memos = [_memo('가나다')];
      expect(SearchService.search(memos, 'ㄱ'), isEmpty);
    });

    test('매치 0건 → 빈 리스트', () {
      final memos = [_memo('hello')];
      expect(SearchService.search(memos, 'zzzz'), isEmpty);
    });
  });

  group('SearchService.search — 랭킹(C: 즐겨찾기 > 제목 > 본문 → updatedAt desc)', () {
    test('spec §6.3: 즐겨찾기+제목 > 즐겨찾기+본문 > 일반+본문', () {
      final a = _memo('x\nKarpathy'); // 일반 + 본문
      final b = _memo('y\nKarpathy', favorite: true); // 즐겨찾기 + 본문
      final c = _memo('Karpathy z', favorite: true); // 즐겨찾기 + 제목
      final r = SearchService.search([a, b, c], 'Karpathy');
      expect(r, [c, b, a]);
    });

    test('비즐겨찾기: 제목 매치가 본문 매치보다 위', () {
      final body = _memo('딴제목\nKarpathy 본문');
      final title = _memo('Karpathy 제목\n내용');
      final r = SearchService.search([body, title], 'Karpathy');
      expect(r, [title, body]);
    });

    test('즐겨찾기가 일반보다 위', () {
      final normal = _memo('Karpathy 제목');
      final fav = _memo('Karpathy 제목', favorite: true);
      final r = SearchService.search([normal, fav], 'Karpathy');
      expect(r.first.isFavorite, true);
    });

    test('동일 랭크 내 updatedAt desc', () {
      final older = _memo('Karpathy A', updatedAt: DateTime(2026, 1, 1));
      final newer = _memo('Karpathy B', updatedAt: DateTime(2026, 6, 1));
      final r = SearchService.search([older, newer], 'Karpathy');
      expect(r, [newer, older]);
    });
  });

  group('SearchService.excerpt — 하이라이트 발췌 (spec §3.5)', () {
    test('중간 매치 → 발췌 + 매치 범위 + 양쪽 말줄임', () {
      // 매치 앞뒤로 30자 넘는 문맥이 있어야 양쪽 말줄임(…)이 붙는다.
      final src =
          '한참 앞에서부터 충분히 긴 문맥을 채워 넣어서 삼십 자가 확실히 넘도록 만든 다음에 '
          'surgical 이라는 단어가 나오고 그 뒤로도 충분히 긴 문맥이 삼십 자를 넘게 계속 이어지도록 채워 둡니다';
      final e = SearchService.excerpt(src, 'surgical');
      expect(e.start, greaterThanOrEqualTo(0));
      expect(e.text.substring(e.start, e.start + e.length).toLowerCase(),
          'surgical');
      expect(e.text.startsWith('…'), isTrue);
      expect(e.text.endsWith('…'), isTrue);
    });

    test('매치 없음 → start -1', () {
      final e = SearchService.excerpt('hello world', 'zzz');
      expect(e.start, -1);
    });

    test('대소문자 무관 매치 + 원본 case 보존', () {
      final e = SearchService.excerpt('Surgical changes', 'surgical');
      expect(e.start, 0);
      expect(e.text.substring(0, 8), 'Surgical');
    });

    test('짧은 텍스트는 말줄임 없음', () {
      final e = SearchService.excerpt('Karpathy', 'Karpathy');
      expect(e.text, 'Karpathy');
      expect(e.start, 0);
    });
  });
}
