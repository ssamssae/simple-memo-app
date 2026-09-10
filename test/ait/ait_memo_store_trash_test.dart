import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/ait/ait_memo_store.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AitMemoStore.lastBackend = 'unknown';
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

  group('AIT 휴지통은 경과일과 무관하게 보존 (자동 purge 없음)', () {
    test('31일·29일 deletedAt 모두 load 후 잔존, 재실행해도 유지', () async {
      await AitMemoStore.saveMemos([
        memoDeletedAgo('old', const Duration(days: 31)),
        memoDeletedAgo('recent', const Duration(days: 29)),
      ]);

      final first = await AitMemoStore.loadMemos();
      expect(first.map((m) => m.id).toSet(), {'old', 'recent'});
      expect(first.every((m) => m.deletedAt != null), isTrue);

      final second = await AitMemoStore.loadMemos();
      expect(second.map((m) => m.id).toSet(), {'old', 'recent'});
    });

    test('활성 메모와 40일 휴지통이 함께 있어도 load 가 둘 다 유지', () async {
      await AitMemoStore.saveMemos([
        active('keep'),
        memoDeletedAgo('expired', const Duration(days: 40)),
      ]);

      final remaining = await AitMemoStore.loadMemos();
      expect(remaining.map((m) => m.id).toSet(), {'keep', 'expired'});
      expect(remaining.firstWhere((m) => m.id == 'keep').deletedAt, isNull);
      expect(remaining.firstWhere((m) => m.id == 'expired').deletedAt, isNotNull);
    });
  });

  group('수동 비우기·영구삭제는 명시 호출만', () {
    test('emptyTrash 호출 전에는 31일 휴지통이 남고, 호출 시에만 제거·활성 유지', () async {
      await AitMemoStore.saveMemos([
        active('keep'),
        memoDeletedAgo('old', const Duration(days: 31)),
        memoDeletedAgo('recent', const Duration(days: 1)),
      ]);

      expect((await AitMemoStore.loadMemos()).length, 3);
      expect(await AitMemoStore.emptyTrash(), 2);
      final remaining = await AitMemoStore.loadMemos();
      expect(remaining.single.id, 'keep');
      expect(remaining.single.deletedAt, isNull);
    });

    test('deleteForever 는 휴지통 id 만 제거하고 활성 id 는 0', () async {
      await AitMemoStore.saveMemos([
        active('live'),
        memoDeletedAgo('old', const Duration(days: 40)),
      ]);

      expect(await AitMemoStore.deleteForever({'live'}), 0);
      expect((await AitMemoStore.loadMemos()).map((m) => m.id).toSet(), {'live', 'old'});
      expect(await AitMemoStore.deleteForever({'old'}), 1);
      final remaining = await AitMemoStore.loadMemos();
      expect(remaining.single.id, 'live');
      expect(remaining.single.deletedAt, isNull);
    });
  });
}
