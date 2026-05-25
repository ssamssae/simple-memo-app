import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SnapshotStore 추가 검증', () {
    test('Memo JSON 문자열을 저장하고 그대로 다시 읽는다', () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      final snapshot = Memo.encodeList([
        Memo(
          id: 'snap-a',
          content: '백업 대상',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      ]);

      await SnapshotStore.save(snapshot);

      expect(await SnapshotStore.hasSnapshot(), isTrue);
      expect(await SnapshotStore.load(), snapshot);
    });

    test('빈 JSON 리스트도 유효한 스냅샷으로 저장한다', () async {
      await SnapshotStore.save(Memo.encodeList([]));

      expect(await SnapshotStore.hasSnapshot(), isTrue);
      expect(await SnapshotStore.load(), '[]');
    });

    test('clear 는 여러 번 호출해도 스냅샷 없는 상태를 유지한다', () async {
      await SnapshotStore.save('temporary');

      await SnapshotStore.clear();
      await SnapshotStore.clear();

      expect(await SnapshotStore.hasSnapshot(), isFalse);
      expect(await SnapshotStore.load(), isNull);
    });
  });
}
