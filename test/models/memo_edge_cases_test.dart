import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  Memo memoWithContent(String content) {
    final createdAt = DateTime(2026, 1, 1, 9);
    return Memo(
      id: 'memo-edge',
      content: content,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  group('Memo.firstLine edge cases', () {
    test('탭으로 들여쓴 첫 줄도 trim 해서 반환한다', () {
      final memo = memoWithContent('\t\t탭 들여쓰기\t\n둘째 줄');

      expect(memo.firstLine, '탭 들여쓰기');
    });

    test('이모지가 포함된 첫 줄을 그대로 반환한다', () {
      final memo = memoWithContent('\n  오늘 기분 좋음 🙂🚀  \n다음 줄');

      expect(memo.firstLine, '오늘 기분 좋음 🙂🚀');
    });

    test('매우 긴 첫 줄을 자르지 않는다', () {
      final longLine = '긴 줄 ' * 500;
      final memo = memoWithContent('  $longLine  \n둘째 줄');

      expect(memo.firstLine, longLine.trim());
      expect(memo.firstLine.length, longLine.trim().length);
    });
  });

  group('Memo.copyWith edge cases', () {
    test('content/isFavorite/updatedAt 여러 필드를 한 번에 변경한다', () {
      final createdAt = DateTime(2026, 1, 1, 9);
      final original = Memo(
        id: 'copy-target',
        content: '원본',
        isFavorite: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final updatedAt = createdAt.add(const Duration(hours: 2));

      final updated = original.copyWith(
        content: '수정됨',
        isFavorite: true,
        updatedAt: updatedAt,
      );

      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(updated.content, '수정됨');
      expect(updated.isFavorite, isTrue);
      expect(updated.updatedAt, updatedAt);
    });
  });
}
