import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_summary_client.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/paywall_screen.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final memo = Memo(
    id: 'summary-memo',
    content: '치과 예약\n오후 3시 방문',
    createdAt: DateTime(2026, 7, 15, 10),
    updatedAt: DateTime(2026, 7, 15, 10),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
  });

  tearDown(() {
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
  });

  testWidgets('미구독자가 AI 요약을 누르면 Worker 호출 없이 페이월을 연다', (tester) async {
    var callCount = 0;
    final client = MemoyoSummaryClient(
      transport: (_, _) async {
        callCount++;
        throw StateError('premium gate must run first');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(memo: memo, summaryClient: client),
      ),
    );
    expect(find.byTooltip('AI 요약'), findsOneWidget);

    await tester.tap(find.byTooltip('AI 요약'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(callCount, 0);
  });

  testWidgets('구독자는 메모를 요약하고 결과와 오늘 남은 횟수를 본다', (tester) async {
    PremiumService.instance.entitlement.value = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlementClient.premiumProductId,
      expiresAt: DateTime(2999),
      source: PremiumEntitlementSource.subscription,
    );
    late Map<String, Object?> seenPayload;
    final client = MemoyoSummaryClient(
      transport: (_, payload) async {
        seenPayload = payload;
        return {
          'model': 'claude-haiku-4-5-20251001',
          'summary': '• 치과 예약\n• 오후 3시 방문',
          'usage': {
            'date': '2026-07-15',
            'used': 1,
            'limit': 30,
            'remaining': 29,
          },
        };
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(
          memo: memo,
          summaryClient: client,
          summaryUserId: () async => 'memoyo-user-1',
        ),
      ),
    );
    await tester.tap(find.byTooltip('AI 요약'));
    await tester.pumpAndSettle();

    expect(seenPayload['userId'], 'memoyo-user-1');
    expect(seenPayload['memoText'], memo.content);
    expect(find.text('AI 요약'), findsWidgets);
    expect(find.text('• 치과 예약\n• 오후 3시 방문'), findsOneWidget);
    expect(find.text('오늘 29회 남음 · 일일 30회'), findsOneWidget);
  });

  testWidgets('서버 일일 한도 응답을 명확한 SnackBar로 안내한다', (tester) async {
    PremiumService.instance.entitlement.value = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlementClient.premiumProductId,
      expiresAt: DateTime(2999),
      source: PremiumEntitlementSource.subscription,
    );
    final client = MemoyoSummaryClient(
      transport: (_, _) async => throw const MemoyoSummaryException(
        statusCode: 429,
        code: 'MEMOYO_SUMMARY_DAILY_LIMIT',
        message: '오늘 AI 요약 30회 한도에 도달했습니다.',
        usage: MemoyoSummaryUsage(
          date: '2026-07-15',
          used: 30,
          limit: 30,
          remaining: 0,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(
          memo: memo,
          summaryClient: client,
          summaryUserId: () async => 'memoyo-user-1',
        ),
      ),
    );
    await tester.tap(find.byTooltip('AI 요약'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 AI 요약 30회 한도에 도달했습니다.'), findsOneWidget);
  });
}
