import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/screens/policy_screen.dart';

void main() {
  testWidgets('PolicyScreen 이 개인정보처리방침 asset 을 렌더한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PolicyScreen(
          title: '개인정보처리방침',
          assetPath: 'docs/legal/privacy-policy.md',
        ),
      ),
    );
    // FutureBuilder(asset 로드) 완료까지 settle
    await tester.pumpAndSettle();

    // AppBar 타이틀
    expect(find.text('개인정보처리방침'), findsWidgets);
    // 문서 본문 상단 섹션이 렌더됐는지(ListView lazy-build 라 상단 요소로 검증)
    expect(find.textContaining('핵심 요약'), findsOneWidget);
    // 로드 실패 메시지가 아니어야 함
    expect(find.text('문서를 불러올 수 없습니다'), findsNothing);
  });

  testWidgets('PolicyScreen 이 이용약관 asset 을 렌더한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PolicyScreen(
          title: '이용약관',
          assetPath: 'docs/legal/terms-of-service.md',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('서비스 내용'), findsOneWidget);
    expect(find.text('문서를 불러올 수 없습니다'), findsNothing);
  });
}
