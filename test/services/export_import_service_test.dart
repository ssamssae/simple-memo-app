import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Memo memo(String id, String content, DateTime updatedAt) => Memo(
        id: id,
        content: content,
        createdAt: updatedAt.subtract(const Duration(minutes: 1)),
        updatedAt: updatedAt,
      );

  group('ExportImportService.mergeSilently', () {
    test('빈 기존 + 가져온 list → 가져온 그대로', () {
      final existing = <Memo>[];
      final incoming = [memo('a', 'hello', DateTime(2026, 1, 1))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.id, 'a');
    });

    test('기존 + 새 id 가져옴 → 둘 다 보존', () {
      final existing = [memo('a', 'hi', DateTime(2026, 1, 1))];
      final incoming = [memo('b', 'new', DateTime(2026, 1, 2))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.map((m) => m.id).toSet(), {'a', 'b'});
    });

    test('같은 id 충돌 시 updatedAt 최신 우선', () {
      final existing = [memo('a', 'old', DateTime(2026, 1, 1))];
      final incoming = [memo('a', 'new', DateTime(2026, 1, 5))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.content, 'new');
    });

    test('같은 id 충돌 시 기존이 더 최신이면 기존 유지', () {
      final existing = [memo('a', 'keep', DateTime(2026, 1, 5))];
      final incoming = [memo('a', 'stale', DateTime(2026, 1, 1))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.content, 'keep');
    });

    test('silent merge 는 기존 메모를 결코 삭제하지 않음 (gold path)', () {
      final existing = [
        memo('a', 'A', DateTime(2026, 1, 1)),
        memo('b', 'B', DateTime(2026, 1, 1)),
        memo('c', 'C', DateTime(2026, 1, 1)),
      ];
      final incoming = [memo('d', 'D', DateTime(2026, 1, 2))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      final ids = merged.map((m) => m.id).toSet();
      expect(ids.containsAll({'a', 'b', 'c'}), isTrue);
      expect(merged.length, 4);
    });
  });

  group('ExportImportService.parseImport', () {
    test('잘못된 JSON → null', () {
      expect(ExportImportService.parseImport('not json {{{'), isNull);
    });

    test('빈 list JSON → 빈 list', () {
      final parsed = ExportImportService.parseImport('[]');
      expect(parsed, isNotNull);
      expect(parsed!.isEmpty, isTrue);
    });

    test('정상 JSON → Memo list', () {
      final source = Memo.encodeList([memo('a', 'hi', DateTime(2026, 1, 1))]);
      final parsed = ExportImportService.parseImport(source);
      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      expect(parsed.first.id, 'a');
    });
  });

  group('ExportImportService.undoImport', () {
    test('스냅샷 없으면 null 반환', () async {
      expect(await ExportImportService.undoImport(), isNull);
    });

    test('스냅샷 있으면 그 list 반환 + 스냅샷 비움', () async {
      final snapshot =
          Memo.encodeList([memo('x', 'snap', DateTime(2026, 1, 1))]);
      await SnapshotStore.save(snapshot);
      final restored = await ExportImportService.undoImport();
      expect(restored, isNotNull);
      expect(restored!.length, 1);
      expect(restored.first.id, 'x');
      expect(await SnapshotStore.hasSnapshot(), isFalse);
    });
  });

  group('ExportImportService — edge cases', () {
    test('동일 updatedAt 충돌 시 기존 우선 (안전 디폴트)', () {
      final t = DateTime(2026, 1, 1);
      final existing = [memo('a', 'existing', t)];
      final incoming = [memo('a', 'incoming', t)];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.first.content, 'existing');
    });

    test('가져온 list 가 중복 id 를 갖고 있으면 마지막 항목 기준', () {
      final existing = <Memo>[];
      final incoming = [
        memo('a', 'first', DateTime(2026, 1, 1)),
        memo('a', 'second', DateTime(2026, 1, 2)),
      ];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.content, 'second');
    });

    test('parseImport: JSON 이긴 한데 메모 객체가 아닌 형태도 비파괴', () {
      final parsed = ExportImportService.parseImport('"just a string"');
      expect(parsed, isNotNull);
      expect(parsed!.isEmpty, isTrue);
    });

    test('parseImport: 일부 필드 누락 메모 — Memo.fromJson default 적용', () {
      final parsed = ExportImportService.parseImport('[{"id":"x"}]');
      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      expect(parsed.first.id, 'x');
      expect(parsed.first.content, '');
    });
  });

  group('ExportImportService.importFromSource', () {
    test('정상 JSON → snapshot 저장 + merge + (count,total) 반환', () async {
      await MemoStorage.saveMemos([memo('a', 'old', DateTime(2026, 1, 1))]);
      final source = Memo.encodeList([memo('b', 'new', DateTime(2026, 1, 2))]);

      final (incoming, total) =
          await ExportImportService.importFromSource(source);
      expect(incoming, 1);
      expect(total, 2);
      expect(await SnapshotStore.hasSnapshot(), isTrue);
      final saved = await MemoStorage.loadMemos();
      expect(saved.map((m) => m.id), containsAll(<String>['a', 'b']));
    });

    test('잘못된 JSON → FormatException, 기존 메모 무변경', () async {
      await MemoStorage.saveMemos([memo('a', 'keep', DateTime(2026, 1, 1))]);
      expect(
        () => ExportImportService.importFromSource('not json'),
        throwsFormatException,
      );
      final saved = await MemoStorage.loadMemos();
      expect(saved.length, 1);
    });

    test('빈 list JSON → (0,0), snapshot 미저장 + 기존 무변경', () async {
      await MemoStorage.saveMemos([memo('a', 'keep', DateTime(2026, 1, 1))]);
      final (incoming, total) =
          await ExportImportService.importFromSource('[]');
      expect(incoming, 0);
      expect(total, 0);
      expect(await SnapshotStore.hasSnapshot(), isFalse);
      final saved = await MemoStorage.loadMemos();
      expect(saved.length, 1);
    });
  });
}
