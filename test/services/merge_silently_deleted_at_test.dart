import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';

void main() {
  Memo memo(String id, DateTime updatedAt, {DateTime? deletedAt}) => Memo(
        id: id,
        content: '$id 내용',
        createdAt: updatedAt.subtract(const Duration(minutes: 1)),
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );

  group('mergeSilently — deletedAt 보존 (백업/복원 시 휴지통 상태 유지)', () {
    test('incoming 의 deletedAt 가 merge 결과에 보존된다', () {
      final incoming = [
        memo('a', DateTime(2026, 1, 2), deletedAt: DateTime(2026, 1, 3)),
      ];

      final merged = ExportImportService.mergeSilently(const [], incoming);

      expect(merged.single.deletedAt, DateTime(2026, 1, 3));
    });

    test('같은 id 충돌 시 최신(updatedAt) 항목의 deletedAt 채택', () {
      final existing = [memo('a', DateTime(2026, 1, 1))]; // 활성, 오래됨
      final incoming = [
        memo('a', DateTime(2026, 1, 5), deletedAt: DateTime(2026, 1, 6)),
      ];

      final merged = ExportImportService.mergeSilently(existing, incoming);

      expect(merged.single.deletedAt, DateTime(2026, 1, 6));
    });

    test('encodeList → decodeList roundtrip 이 deletedAt 보존', () {
      final list = [
        memo('a', DateTime(2026, 1, 1)),
        memo('b', DateTime(2026, 1, 2), deletedAt: DateTime(2026, 1, 3)),
      ];

      final restored = Memo.decodeList(Memo.encodeList(list));

      expect(restored.firstWhere((m) => m.id == 'a').deletedAt, isNull);
      expect(
        restored.firstWhere((m) => m.id == 'b').deletedAt,
        DateTime(2026, 1, 3),
      );
    });
  });
}
