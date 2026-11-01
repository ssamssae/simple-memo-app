// T-261101-034 ② — 즐겨찾기 토글 순서 규칙.
//
// 목록은 저장된 배열 순서 그대로다(수동 순서). 새 메모는 일반 묶음 맨 위에 들어가므로,
// 손대지 않은 목록은 최신 → 오래된 순이다. 즐겨찾기 묶음은 늘 앞에 온다.

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/favorite_order.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  final now = DateTime(2026, 11, 1, 9);

  Memo m(
    String id, {
    int age = 0,
    bool fav = false,
    String? anchor,
    DateTime? deletedAt,
  }) {
    final at = now.subtract(Duration(minutes: age));
    return Memo(
      id: id,
      content: id,
      isFavorite: fav,
      createdAt: at,
      updatedAt: at,
      deletedAt: deletedAt,
      favoriteAnchorId: anchor,
    );
  }

  List<String> ids(List<Memo> memos) => memos.map((x) => x.id).toList();
  Memo byId(List<Memo> memos, String id) => memos.firstWhere((x) => x.id == id);

  // 메모 목록 화면의 새 메모 넣기와 같다: 일반 묶음 맨 위.
  List<Memo> addNew(List<Memo> memos, Memo memo) {
    final out = List.of(memos);
    final firstNormal = out.indexWhere((x) => !x.isFavorite);
    out.insert(firstNormal == -1 ? out.length : firstNormal, memo);
    return out;
  }

  group('즐겨찾기로 올리기', () {
    test('즐겨찾기 묶음 끝으로 가고, 바로 아래 일반 메모를 자리로 적는다', () {
      final out = FavoriteOrder.toggle([
        m('f', fav: true),
        m('a', age: 1),
        m('b', age: 2),
        m('c', age: 3),
      ], 'b');
      expect(ids(out), ['f', 'b', 'a', 'c']);
      expect(byId(out, 'b').isFavorite, isTrue);
      expect(byId(out, 'b').favoriteAnchorId, 'c');
    });

    test('맨 아래 메모는 아래 이웃이 없어 자리 기록이 없다', () {
      final out = FavoriteOrder.toggle([m('a'), m('b', age: 1)], 'b');
      expect(byId(out, 'b').favoriteAnchorId, isNull);
    });

    test('휴지통 메모는 자리로 쓰지 않는다 — 다음 살아 있는 메모', () {
      final out = FavoriteOrder.toggle([
        m('a'),
        m('t', age: 1, deletedAt: now),
        m('c', age: 2),
      ], 'a');
      expect(byId(out, 'a').favoriteAnchorId, 'c');
    });

    test('수정 시각은 그대로다 — 검색 순위·백업 병합 기준을 건드리지 않는다', () {
      final before = m('a', age: 5);
      final out = FavoriteOrder.toggle([before, m('b', age: 6)], 'a');
      expect(byId(out, 'a').updatedAt, before.updatedAt);
    });

    test('없는 id 는 목록을 그대로 돌려준다', () {
      final list = [m('a'), m('b', age: 1)];
      expect(ids(FavoriteOrder.toggle(list, 'zzz')), ['a', 'b']);
    });
  });

  group('즐겨찾기 풀기', () {
    test('가운데 메모 — 올렸다 풀면 원래 자리', () {
      final list = [m('a'), m('b', age: 1), m('c', age: 2), m('d', age: 3)];
      final fav = FavoriteOrder.toggle(list, 'c');
      expect(ids(fav), ['c', 'a', 'b', 'd']);
      expect(ids(FavoriteOrder.toggle(fav, 'c')), ['a', 'b', 'c', 'd']);
    });

    test('맨 위 메모 — 그사이 새 메모가 생겨도 원래 아래 이웃 바로 위', () {
      final fav = FavoriteOrder.toggle([
        m('a'),
        m('b', age: 1),
        m('c', age: 2),
      ], 'a');
      final withNew = addNew(fav, m('n'));
      expect(ids(withNew), ['a', 'n', 'b', 'c']);
      // 즐겨찾기를 안 했으면 n 이 a 위에 쌓였을 자리다.
      expect(ids(FavoriteOrder.toggle(withNew, 'a')), ['n', 'a', 'b', 'c']);
    });

    test('끌어서 바꾼 순서도 지킨다 — 만든 시각과 다른 순서', () {
      // c 가 가장 오래됐지만 사용자가 맨 위로 끌어 올렸다.
      final list = [m('c', age: 30), m('a'), m('b', age: 10)];
      final fav = FavoriteOrder.toggle(list, 'a');
      expect(ids(FavoriteOrder.toggle(fav, 'a')), ['c', 'a', 'b']);
    });

    test('맨 아래 메모 — 풀면 다시 맨 아래', () {
      final fav = FavoriteOrder.toggle([
        m('a'),
        m('b', age: 1),
        m('c', age: 2),
      ], 'c');
      expect(ids(FavoriteOrder.toggle(fav, 'c')), ['a', 'b', 'c']);
    });

    test('아래 이웃도 즐겨찾기로 올라갔으면 그 이웃이 적어 둔 자리로 — 어느 순서로 풀어도', () {
      final list = [m('a'), m('b', age: 1), m('c', age: 2), m('d', age: 3)];
      final both = FavoriteOrder.toggle(FavoriteOrder.toggle(list, 'b'), 'c');
      expect(ids(both), ['b', 'c', 'a', 'd']);

      final bFirst = FavoriteOrder.toggle(both, 'b');
      expect(ids(bFirst), ['c', 'a', 'b', 'd']);
      expect(ids(FavoriteOrder.toggle(bFirst, 'c')), ['a', 'b', 'c', 'd']);

      final cFirst = FavoriteOrder.toggle(both, 'c');
      expect(ids(cFirst), ['b', 'a', 'c', 'd']);
      expect(ids(FavoriteOrder.toggle(cFirst, 'b')), ['a', 'b', 'c', 'd']);
    });

    test('아래 이웃이 휴지통에 있어도 그 자리 — 화면에 보이는 순서가 원래대로', () {
      final fav = FavoriteOrder.toggle([
        m('a'),
        m('b', age: 1),
        m('c', age: 2),
      ], 'b');
      final trashed = [
        for (final x in fav) x.id == 'c' ? x.copyWith(deletedAt: now) : x,
      ];
      final out = FavoriteOrder.toggle(trashed, 'b');
      expect(ids(out), ['a', 'b', 'c']);
    });

    test('아래 이웃이 영구 삭제됐으면 만든 시각 자리', () {
      final list = [m('a'), m('b', age: 10), m('c', age: 20), m('d', age: 30)];
      final fav = FavoriteOrder.toggle(list, 'b');
      final purged = fav.where((x) => x.id != 'c').toList();
      expect(ids(FavoriteOrder.toggle(purged, 'b')), ['a', 'b', 'd']);
    });

    test('자리 기록이 없는 옛 즐겨찾기는 만든 시각 자리 — 일반 묶음 맨 위가 아니다', () {
      final list = [
        m('f', age: 15, fav: true),
        m('a'),
        m('b', age: 10),
        m('c', age: 20),
      ];
      expect(ids(FavoriteOrder.toggle(list, 'f')), ['a', 'b', 'f', 'c']);
    });

    test('자리 기록이 없고 일반 메모가 모두 더 최신이면 맨 아래', () {
      final list = [m('f', age: 99, fav: true), m('a'), m('b', age: 10)];
      expect(ids(FavoriteOrder.toggle(list, 'f')), ['a', 'b', 'f']);
    });

    test('자리 기록이 자기 자신이거나 서로 가리켜도 멈추고 만든 시각 자리', () {
      final self = [
        m('f', age: 5, fav: true, anchor: 'f'),
        m('a'),
        m('b', age: 10),
      ];
      expect(ids(FavoriteOrder.toggle(self, 'f')), ['a', 'f', 'b']);

      final loop = [
        m('f', age: 5, fav: true, anchor: 'g'),
        m('g', age: 6, fav: true, anchor: 'f'),
        m('a'),
        m('b', age: 10),
      ];
      expect(ids(FavoriteOrder.toggle(loop, 'f')), ['g', 'a', 'f', 'b']);
    });

    test('풀면 자리 기록을 지운다 — 일반 메모 JSON 은 예전 모양 그대로', () {
      final fav = FavoriteOrder.toggle([m('a'), m('b', age: 1)], 'a');
      expect(byId(fav, 'a').favoriteAnchorId, 'b');
      final out = FavoriteOrder.toggle(fav, 'a');
      final a = byId(out, 'a');
      expect(a.isFavorite, isFalse);
      expect(a.favoriteAnchorId, isNull);
      expect(a.toJson().containsKey('favoriteAnchorId'), isFalse);
    });

    test('다른 즐겨찾기의 순서는 그대로다', () {
      final list = [
        m('f1', fav: true),
        m('f2', fav: true),
        m('f3', fav: true, anchor: 'b'),
        m('a'),
        m('b', age: 1),
      ];
      expect(ids(FavoriteOrder.toggle(list, 'f3')), [
        'f1',
        'f2',
        'a',
        'f3',
        'b',
      ]);
    });
  });
}
