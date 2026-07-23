// 한글 초성 검색 유틸 (T-260723-052, spec docs/specs/memoyo-chosung-search.md).
// 순수함수·의존성 0. SearchService 무료 초성 모드에서만 사용.

// 초성 자모 19자 (Unicode compatibility jamo). 완성 음절 초성 인덱스와 순서 일치.
const String _choseong = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
final Set<String> _choseongSet = _choseong.split('').toSet();

const int _syllableBase = 0xAC00; // '가'
const int _syllableLast = 0xD7A3; // '힣'
const int _choseongBlock = 588; // 중성 21 × 종성 28

/// 쿼리가 '초성 검색'인지 판정.
/// 공백 아닌 모든 문자가 초성 자모 19자이고 초성 자모가 최소 1자 이상이면 true.
/// 완성글자·컴파운드 자모(ㄳ 등)·영문/숫자가 하나라도 섞이면 false.
bool isChosungQuery(String query) {
  var hasJamo = false;
  for (final ch in query.split('')) {
    if (ch == ' ') continue;
    if (!_choseongSet.contains(ch)) return false;
    hasJamo = true;
  }
  return hasJamo;
}

/// 텍스트를 초성 문자열로 변환.
/// 완성 한글 음절 → 초성 자모, 이미 초성 자모/그 외(영문·숫자·기호·공백)는 그대로.
String chosungOf(String text) {
  final buf = StringBuffer();
  for (final ch in text.split('')) {
    final code = ch.codeUnitAt(0);
    if (code >= _syllableBase && code <= _syllableLast) {
      buf.write(_choseong[(code - _syllableBase) ~/ _choseongBlock]);
    } else {
      buf.write(ch);
    }
  }
  return buf.toString();
}
