// Memo 모델 단위 테스트.
//
// 실제 앱은 SplashScreen 진입 직후 SharedPreferences 등 플랫폼 채널을 호출하므로
// flutter_test 환경에서 그대로 pumpWidget 하면 MissingPluginException 이 발생한다.
// 따라서 위젯 트리 대신 순수 Dart 로직(Memo 모델 직렬화/copyWith/firstLine)을
// 검증한다. 화면 단위 위젯 테스트는 별도 파일에서 mock plugin 으로 다룰 예정.

import 'package:flutter_test/flutter_test.dart';

import 'package:simple_memo_app/models/memo.dart';

void main() {
  group('Memo.firstLine', () {
    test('첫 비어있지 않은 줄을 trim 해서 반환한다', () {
      final memo = Memo.create(content: '   \n\n  안녕  \n둘째 줄');
      expect(memo.firstLine, '안녕');
    });

    test('내용이 모두 공백이면 "새 메모" 를 반환한다', () {
      final memo = Memo.create(content: '   \n  \n');
      expect(memo.firstLine, '새 메모');
    });
  });

  group('Memo.copyWith', () {
    test('지정한 필드만 변경되고 id/createdAt 은 보존된다', () {
      final original = Memo.create(content: '원본');
      final updatedAt = original.updatedAt.add(const Duration(minutes: 1));

      final updated = original.copyWith(
        content: '수정',
        isFavorite: true,
        updatedAt: updatedAt,
      );

      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(updated.content, '수정');
      expect(updated.isFavorite, true);
      expect(updated.updatedAt, updatedAt);
    });
  });

  group('Memo encode/decode roundtrip', () {
    test('encodeList → decodeList 로 동일 메모를 복원한다', () {
      final memos = [
        Memo.create(content: '첫째'),
        Memo.create(content: '둘째')..isFavorite = true,
      ];

      final encoded = Memo.encodeList(memos);
      final decoded = Memo.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].content, '첫째');
      expect(decoded[1].content, '둘째');
      expect(decoded[1].isFavorite, true);
      expect(decoded[0].id, memos[0].id);
    });

    test('decodeList 는 잘못된 JSON 에 대해 빈 리스트를 반환한다', () {
      expect(Memo.decodeList('{"not":"a list"}'), isEmpty);
    });
  });
}
