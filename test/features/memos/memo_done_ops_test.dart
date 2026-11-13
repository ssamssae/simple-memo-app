import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/memo_done_ops.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  final t = DateTime(2026, 11, 13, 9);

  Memo memo(
    String id, {
    DateTime? doneAt,
    DateTime? deletedAt,
    bool fav = false,
  }) => Memo(
    id: id,
    content: id,
    createdAt: t,
    updatedAt: t,
    isFavorite: fav,
    doneAt: doneAt,
    deletedAt: deletedAt,
  );

  test('isOpen = 휴지통도 완료도 아님', () {
    expect(MemoDoneOps.isOpen(memo('a')), isTrue);
    expect(MemoDoneOps.isOpen(memo('a', doneAt: t)), isFalse);
    expect(MemoDoneOps.isOpen(memo('a', deletedAt: t)), isFalse);
  });

  test('done: 휴지통 제외, 최근 완료가 위, 같은 시각이면 저장 순서', () {
    final all = [
      memo('old', doneAt: DateTime(2026, 11, 1)),
      memo('open'),
      memo('new', doneAt: DateTime(2026, 11, 12)),
      memo('trashed', doneAt: DateTime(2026, 11, 13), deletedAt: t),
      memo('tie1', doneAt: DateTime(2026, 11, 5)),
      memo('tie2', doneAt: DateTime(2026, 11, 5)),
    ];
    expect(MemoDoneOps.done(all).map((m) => m.id), [
      'new',
      'tie1',
      'tie2',
      'old',
    ]);
  });

  test('setDone 은 배열 순서·updatedAt 을 바꾸지 않고, 풀면 같은 자리', () {
    final all = [memo('f', fav: true), memo('a'), memo('b'), memo('c')];
    final done = MemoDoneOps.setDone(all, 'b', DateTime(2026, 11, 13, 22));
    expect(done.map((m) => m.id), ['f', 'a', 'b', 'c']);
    expect(done[2].doneAt, DateTime(2026, 11, 13, 22));
    expect(done[2].updatedAt, t);
    expect(done.where(MemoDoneOps.isOpen).map((m) => m.id), ['f', 'a', 'c']);
    final undone = MemoDoneOps.setDone(done, 'b', null);
    expect(undone.where(MemoDoneOps.isOpen).map((m) => m.id), [
      'f',
      'a',
      'b',
      'c',
    ]);
  });

  test('setDone 은 휴지통 메모를 건드리지 않는다', () {
    final all = [memo('x', deletedAt: t)];
    expect(MemoDoneOps.setDone(all, 'x', t).single.doneAt, isNull);
  });

  test('trashDone 은 고른 완료 메모만 휴지통으로, 완료 표시는 남긴다 · untrash 로 되돌린다', () {
    final now = DateTime(2026, 11, 13, 23);
    final all = [memo('d1', doneAt: t), memo('d2', doneAt: t), memo('open')];
    final trashed = MemoDoneOps.trashDone(all, {'d1', 'open'}, now);
    expect(trashed[0].deletedAt, now);
    expect(trashed[0].doneAt, t);
    expect(trashed[1].deletedAt, isNull); // 고르지 않음
    expect(trashed[2].deletedAt, isNull); // 완료 아님
    final back = MemoDoneOps.untrash(trashed, {'d1'});
    expect(back[0].deletedAt, isNull);
    expect(MemoDoneOps.done(back).map((m) => m.id), ['d1', 'd2']);
  });
}
