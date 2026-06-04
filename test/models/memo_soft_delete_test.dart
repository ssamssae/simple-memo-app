import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  Memo active(String id) {
    final t = DateTime(2026, 1, 1, 9);
    return Memo(id: id, content: '$id 내용', createdAt: t, updatedAt: t);
  }

  group('Memo.deletedAt — fromJson 마이그레이션', () {
    test('deletedAt 키 없는 1.0.6 이하 JSON → null (활성, 손실 0)', () {
      final memo = Memo.fromJson({
        'id': 'a',
        'content': '옛 메모',
        'isFavorite': false,
        'createdAt': '2026-01-01T09:00:00.000',
        'updatedAt': '2026-01-01T09:00:00.000',
      });

      expect(memo.deletedAt, isNull);
      expect(memo.isInTrash, isFalse);
    });

    test('deletedAt 있는 1.0.7 JSON → 정확 파싱', () {
      final memo = Memo.fromJson({
        'id': 'a',
        'content': '삭제된 메모',
        'createdAt': '2026-01-01T09:00:00.000',
        'updatedAt': '2026-01-01T09:00:00.000',
        'deletedAt': '2026-02-01T12:30:00.000',
      });

      expect(memo.deletedAt, DateTime(2026, 2, 1, 12, 30));
      expect(memo.isInTrash, isTrue);
    });

    test('deletedAt 가 파싱 불가 문자열 → null (활성 취급, 안전)', () {
      final memo = Memo.fromJson({
        'id': 'a',
        'content': '깨진 deletedAt',
        'createdAt': '2026-01-01T09:00:00.000',
        'updatedAt': '2026-01-01T09:00:00.000',
        'deletedAt': 'not-a-date',
      });

      expect(memo.deletedAt, isNull);
    });
  });

  group('Memo.toJson — deletedAt 직렬화', () {
    test('활성 메모는 deletedAt 키를 박지 않는다 (백워드 호환)', () {
      final json = active('a').toJson();

      expect(json.containsKey('deletedAt'), isFalse);
    });

    test('휴지통 메모는 deletedAt 을 ISO8601 로 박는다', () {
      final memo = active('a').copyWith(deletedAt: DateTime(2026, 2, 1, 12, 30));
      final json = memo.toJson();

      expect(json['deletedAt'], '2026-02-01T12:30:00.000');
    });

    test('toJson → fromJson roundtrip 이 deletedAt 을 보존한다', () {
      final original =
          active('a').copyWith(deletedAt: DateTime(2026, 2, 1, 12, 30));
      final restored = Memo.fromJson(original.toJson());

      expect(restored.deletedAt, original.deletedAt);
    });
  });

  group('Memo.copyWith — deletedAt sentinel', () {
    test('deletedAt 인자 미지정 시 기존 null 유지', () {
      final memo = active('a');

      expect(memo.copyWith(content: '수정').deletedAt, isNull);
    });

    test('deletedAt 인자 미지정 시 기존 값 유지 (다른 필드만 변경)', () {
      final trashed =
          active('a').copyWith(deletedAt: DateTime(2026, 2, 1));

      final edited = trashed.copyWith(content: '수정');

      expect(edited.deletedAt, DateTime(2026, 2, 1));
      expect(edited.content, '수정');
    });

    test('deletedAt: 값 지정 → 휴지통 이동(soft-delete)', () {
      final memo = active('a');
      final t = DateTime(2026, 2, 1, 10);

      final deleted = memo.copyWith(deletedAt: t);

      expect(deleted.deletedAt, t);
      expect(deleted.isInTrash, isTrue);
    });

    test('deletedAt: null 명시 → 휴지통에서 복구(UNDO)', () {
      final trashed = active('a').copyWith(deletedAt: DateTime(2026, 2, 1));

      final restored = trashed.copyWith(deletedAt: null);

      expect(restored.deletedAt, isNull);
      expect(restored.isInTrash, isFalse);
    });
  });

  group('Memo.timeUntilPurge', () {
    test('활성 메모는 Duration.zero', () {
      expect(active('a').timeUntilPurge, Duration.zero);
    });

    test('방금 삭제된 메모는 보관기간(30일)에 가깝게 남음', () {
      final justDeleted =
          active('a').copyWith(deletedAt: DateTime.now());

      final remaining = justDeleted.timeUntilPurge;

      expect(remaining.inDays, greaterThanOrEqualTo(29));
      expect(remaining.inDays, lessThanOrEqualTo(30));
    });

    test('보관기간 지난 메모는 음수 Duration (purge 대상)', () {
      final expired = active('a').copyWith(
        deletedAt: DateTime.now().subtract(const Duration(days: 31)),
      );

      expect(expired.timeUntilPurge.isNegative, isTrue);
    });
  });
}
