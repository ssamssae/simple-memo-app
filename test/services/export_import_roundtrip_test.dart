import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';

void main() {
  Memo memo({
    required String id,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isFavorite = false,
  }) {
    return Memo(
      id: id,
      content: content,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  group('ExportImportService JSON roundtrip', () {
    test('Memo 리스트 → JSON → Memo 리스트로 모든 주요 필드를 복원한다', () {
      final firstCreatedAt = DateTime.utc(2026, 1, 1, 10);
      final secondCreatedAt = DateTime.utc(2026, 1, 2, 11);
      final source = [
        memo(
          id: 'a',
          content: '첫 메모\n둘째 줄',
          createdAt: firstCreatedAt,
          updatedAt: firstCreatedAt.add(const Duration(minutes: 5)),
        ),
        memo(
          id: 'b',
          content: '즐겨찾기 메모',
          createdAt: secondCreatedAt,
          updatedAt: secondCreatedAt.add(const Duration(days: 1)),
          isFavorite: true,
        ),
      ];

      final json = Memo.encodeList(source);
      final imported = ExportImportService.parseImport(json);

      expect(imported, isNotNull);
      expect(imported, hasLength(2));
      expect(imported![0].id, 'a');
      expect(imported[0].content, '첫 메모\n둘째 줄');
      expect(imported[0].isFavorite, isFalse);
      expect(imported[0].createdAt, firstCreatedAt);
      expect(
        imported[0].updatedAt,
        firstCreatedAt.add(const Duration(minutes: 5)),
      );
      expect(imported[1].id, 'b');
      expect(imported[1].isFavorite, isTrue);
      expect(imported[1].createdAt, secondCreatedAt);
      expect(imported[1].updatedAt, secondCreatedAt.add(const Duration(days: 1)));
    });

    test('빈 리스트 JSON 은 빈 Memo 리스트로 처리한다', () {
      final imported = ExportImportService.parseImport(Memo.encodeList([]));

      expect(imported, isNotNull);
      expect(imported, isEmpty);
    });

    test('깨진 JSON 은 null 로 처리해 caller 가 실패를 구분할 수 있다', () {
      final imported = ExportImportService.parseImport('[{"id": "a"');

      expect(imported, isNull);
    });
  });
}
