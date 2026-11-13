import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// T-261113-033: 처리방침이 없어진 기능을 적고 있으면 안 된다.
// 대종님 2026-11-13 「말로요제미나이 없앴는데 왜있지」「ai기능도 없는데」 — AI 요약(T-260804-062)과
// 말로 검색(Gemini, T-261103-001 오프보딩)이 없어진 뒤에도 7/16 판 문구가 앱 안과 스토어 처리방침
// 주소(fastlane/metadata/privacy_url.txt → 이 파일)에 남아 있었다.
void main() {
  final text = File('docs/legal/privacy-policy.md').readAsStringSync();

  test('없어진 AI·서버 처리업체를 적지 않는다', () {
    for (final word in [
      'Anthropic',
      'Gemini',
      'Cloudflare',
      'Worker',
      'AI 요약',
      '말로 검색',
      '임베딩',
      '일별 AI 사용',
    ]) {
      expect(text.contains(word), isFalse, reason: '처리방침에 「$word」가 남아 있다');
    }
  });

  test('지금 쓰는 처리업체 3곳과 문의처는 적는다', () {
    for (final word in [
      'Google Drive',
      'Google Mobile Ads',
      'Apple App Store / Google Play',
      'minusbetastudio@gmail.com',
    ]) {
      expect(text.contains(word), isTrue, reason: '처리방침에 「$word」가 없다');
    }
  });

  test('스토어 처리방침 주소가 이 파일을 가리킨다', () {
    final url = File('fastlane/metadata/privacy_url.txt').readAsStringSync().trim();
    expect(url.endsWith('/docs/legal/privacy-policy.md'), isTrue, reason: url);
  });
}
