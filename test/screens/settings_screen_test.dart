import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/app_review_service.dart';

void main() {
  testWidgets('설정 화면의 앱 평가하기 버튼이 리뷰 요청 콜백을 호출한다', (tester) async {
    var requestCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          requestReview: () async {
            requestCount++;
            return AppReviewResult.requested;
          },
        ),
      ),
    );

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('앱 평가하기'), findsOneWidget);

    await tester.tap(find.text('앱 평가하기'));
    await tester.pumpAndSettle();

    expect(requestCount, 1);
  });

  testWidgets('리뷰 요청 fallback 실패 시 조용한 SnackBar를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          requestReview: () async => AppReviewResult.unavailable,
        ),
      ),
    );

    await tester.tap(find.text('앱 평가하기'));
    await tester.pump();

    expect(find.text('스토어를 열 수 없습니다'), findsOneWidget);
  });
}
