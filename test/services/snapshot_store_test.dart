import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SnapshotStore', () {
    test('초기엔 hasSnapshot=false, load=null', () async {
      expect(await SnapshotStore.hasSnapshot(), isFalse);
      expect(await SnapshotStore.load(), isNull);
    });

    test('save 후 hasSnapshot=true, load=동일 문자열', () async {
      await SnapshotStore.save('[{"id":"a","content":"hi"}]');
      expect(await SnapshotStore.hasSnapshot(), isTrue);
      expect(await SnapshotStore.load(), '[{"id":"a","content":"hi"}]');
    });

    test('clear 후 hasSnapshot=false', () async {
      await SnapshotStore.save('[{"id":"a"}]');
      await SnapshotStore.clear();
      expect(await SnapshotStore.hasSnapshot(), isFalse);
      expect(await SnapshotStore.load(), isNull);
    });

    test('save 중복 호출 시 마지막 값으로 덮어씀', () async {
      await SnapshotStore.save('first');
      await SnapshotStore.save('second');
      expect(await SnapshotStore.load(), 'second');
    });
  });
}
