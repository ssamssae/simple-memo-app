import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/utils/hangul_chosung.dart';

void main() {
  group('isChosungQuery', () {
    test('전부 초성 자모 → true', () {
      expect(isChosungQuery('ㅁㅁㅇ'), isTrue);
    });
    test('완성글자 포함 → false', () {
      expect(isChosungQuery('메모'), isFalse);
    });
    test('자음+완성글자 혼합 → false', () {
      expect(isChosungQuery('ㅁ모'), isFalse);
    });
    test('영문 → false', () {
      expect(isChosungQuery('abc'), isFalse);
    });
    test('빈 문자열 → false', () {
      expect(isChosungQuery(''), isFalse);
    });
    test('공백만 → false', () {
      expect(isChosungQuery('   '), isFalse);
    });
    test('초성 사이 공백 허용 → true', () {
      expect(isChosungQuery('ㅁ ㅇ'), isTrue);
    });
    test('컴파운드 자모(ㄳ) → false', () {
      expect(isChosungQuery('ㄳ'), isFalse);
    });
  });

  group('chosungOf', () {
    test('메모요 → ㅁㅁㅇ', () {
      expect(chosungOf('메모요'), 'ㅁㅁㅇ');
    });
    test('회의 → ㅎㅇ', () {
      expect(chosungOf('회의'), 'ㅎㅇ');
    });
    test('쌍자음 초성: 까치 → ㄲㅊ', () {
      expect(chosungOf('까치'), 'ㄲㅊ');
    });
    test('비한글은 그대로: hello → hello', () {
      expect(chosungOf('hello'), 'hello');
    });
    test('숫자 혼합: 메모2 → ㅁㅁ2', () {
      expect(chosungOf('메모2'), 'ㅁㅁ2');
    });
    test('공백 보존: 회의 메모 → ㅎㅇ ㅁㅁ', () {
      expect(chosungOf('회의 메모'), 'ㅎㅇ ㅁㅁ');
    });
  });
}
