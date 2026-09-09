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

  group('휴지통은 경과일과 무관하게 load/save 로 보존', () {
    test('31일·29일 deletedAt 모두 load 후 잔존 (자동 영구삭제 없음)', () async {
      await MemoStorage.saveMemos([
        memoDeletedAgo('old', const Duration(days: 31)),
        memoDeletedAgo('recent', const Duration(days: 29)),
      ]);

      final remaining = await MemoStorage.loadMemos();
      expect(remaining.map((m) => m.id).toSet(), {'old', 'recent'});
      expect(remaining.every((m) => m.deletedAt != null), isTrue);
    });

    test('활성 메모와 40일 휴지통이 함께 있어도 load 가 둘 다 유지', () async {
      await MemoStorage.saveMemos([
        active('keep'),
        memoDeletedAgo('expired', const Duration(days: 40)),
      ]);

      final remaining = await MemoStorage.loadMemos();
      expect(remaining.map((m) => m.id).toSet(), {'keep', 'expired'});
      expect(remaining.firstWhere((m) => m.id == 'keep').deletedAt, isNull);
      expect(remaining.firstWhere((m) => m.id == 'expired').deletedAt, isNotNull);
    });

    test('아주 오래된 활성 메모도 유지 (생성일 무관, deletedAt 만 본다)', () async {
      final old = Memo(
        id: 'ancient',
        content: '오래된 활성 메모',
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime(2020, 1, 1),
      );
      await MemoStorage.saveMemos([old]);

      expect((await MemoStorage.loadMemos()).length, 1);
    });

    test('100일 지난 deletedAt 도 encode/decode 왕복 보존', () async {
      await MemoStorage.saveMemos([
        memoDeletedAgo('ancient-trash', const Duration(days: 100)),
      ]);

      final remaining = await MemoStorage.loadMemos();
      expect(remaining.single.id, 'ancient-trash');
      expect(remaining.single.deletedAt, isNotNull);
    });

    test('빈 저장소 → 빈 목록', () async {
      expect(await MemoStorage.loadMemos(), isEmpty);
    });

    test('여러 오래된 휴지통 + 활성 + 최근 삭제 모두 load 잔존', () async {
      await MemoStorage.saveMemos([
        memoDeletedAgo('e1', const Duration(days: 31)),
        memoDeletedAgo('e2', const Duration(days: 60)),
        memoDeletedAgo('e3', const Duration(days: 100)),
        active('keep'),
        memoDeletedAgo('recent', const Duration(days: 1)),
      ]);

      final remaining = await MemoStorage.loadMemos();
      expect(remaining.map((m) => m.id).toSet(),
          {'e1', 'e2', 'e3', 'keep', 'recent'});
    });
  });

  group('수동 영구삭제·비우기·복원은 유지', () {
    test('emptyTrash 는 31일 지난 휴지통도 제거하고 활성은 유지', () async {
      await MemoStorage.saveMemos([
        active('keep'),
        memoDeletedAgo('old', const Duration(days: 31)),
        memoDeletedAgo('recent', const Duration(days: 1)),
      ]);

      expect(await MemoStorage.emptyTrash(), 2);
      final remaining = await MemoStorage.loadMemos();
      expect(remaining.single.id, 'keep');
      expect(remaining.single.deletedAt, isNull);
    });

    test('deleteForever 는 지정 id 만 제거', () async {
      await MemoStorage.saveMemos([
        memoDeletedAgo('old', const Duration(days: 40)),
        memoDeletedAgo('keep', const Duration(days: 40)),
      ]);

      expect(await MemoStorage.deleteForever({'old'}), 1);
      final remaining = await MemoStorage.loadMemos();
      expect(remaining.single.id, 'keep');
    });

    test('soft-delete 후 copyWith(deletedAt: null) 복원', () async {
      final now = DateTime.now();
      await MemoStorage.saveMemos([
        active('a').copyWith(deletedAt: now),
      ]);

      final loaded = await MemoStorage.loadMemos();
      await MemoStorage.saveMemos([
        loaded.single.copyWith(deletedAt: null),
      ]);

      final restored = await MemoStorage.loadMemos();
      expect(restored.single.id, 'a');
      expect(restored.single.deletedAt, isNull);
    });
  });
}
