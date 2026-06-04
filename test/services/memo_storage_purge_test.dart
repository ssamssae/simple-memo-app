import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Memo memoDeletedAgo(String id, Duration ago) {
    final t = DateTime(2026, 1, 1, 9);
    return Memo(
      id: id,
      content: '$id 내용',
      createdAt: t,
      updatedAt: t,
      deletedAt: DateTime.now().subtract(ago),
    );
  }

  Memo active(String id) {
    final t = DateTime(2026, 1, 1, 9);
    return Memo(id: id, content: '$id 내용', createdAt: t, updatedAt: t);
  }

  group('MemoStorage.purgeExpiredTrash', () {
    test('30일 경계: 31일 지난 항목 제거, 29일 항목 유지', () async {
      await MemoStorage.saveMemos([
        memoDeletedAgo('old', const Duration(days: 31)),
        memoDeletedAgo('recent', const Duration(days: 29)),
      ]);

      final purged = await MemoStorage.purgeExpiredTrash();

      expect(purged, 1);
      final remaining = await MemoStorage.loadMemos();
      expect(remaining.map((m) => m.id), ['recent']);
    });

    test('활성 메모(deletedAt == null)는 절대 건드리지 않는다', () async {
      await MemoStorage.saveMemos([
        active('keep'),
        memoDeletedAgo('expired', const Duration(days: 40)),
      ]);

      final purged = await MemoStorage.purgeExpiredTrash();

      expect(purged, 1);
      final remaining = await MemoStorage.loadMemos();
      expect(remaining.map((m) => m.id), ['keep']);
      expect(remaining.single.deletedAt, isNull);
    });

    test('아주 오래된 활성 메모도 유지 (생성일 무관, deletedAt 만 본다)', () async {
      // createdAt 이 1년 전이어도 deletedAt 가 null 이면 활성.
      final old = Memo(
        id: 'ancient',
        content: '오래된 활성 메모',
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime(2020, 1, 1),
      );
      await MemoStorage.saveMemos([old]);

      final purged = await MemoStorage.purgeExpiredTrash();

      expect(purged, 0);
      expect((await MemoStorage.loadMemos()).length, 1);
    });

    test('purge 대상 없으면 0 반환', () async {
      await MemoStorage.saveMemos([
        active('a'),
        memoDeletedAgo('b', const Duration(days: 5)),
      ]);

      expect(await MemoStorage.purgeExpiredTrash(), 0);
      expect((await MemoStorage.loadMemos()).length, 2);
    });

    test('빈 저장소 → 0', () async {
      expect(await MemoStorage.purgeExpiredTrash(), 0);
    });

    test('여러 만료 항목 일괄 제거 + 정확한 count', () async {
      await MemoStorage.saveMemos([
        memoDeletedAgo('e1', const Duration(days: 31)),
        memoDeletedAgo('e2', const Duration(days: 60)),
        memoDeletedAgo('e3', const Duration(days: 100)),
        active('keep'),
        memoDeletedAgo('recent', const Duration(days: 1)),
      ]);

      final purged = await MemoStorage.purgeExpiredTrash();

      expect(purged, 3);
      final remaining = await MemoStorage.loadMemos();
      expect(remaining.map((m) => m.id).toSet(), {'keep', 'recent'});
    });
  });
}
