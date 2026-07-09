import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/paywall_screen.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Memo m(String id, String content) {
    final t = DateTime(2026, 7, 9, 10);
    return Memo(id: id, content: content, createdAt: t, updatedAt: t);
  }

  setUp(() {
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
  });

  testWidgets('semantic mode tap without premium opens paywall', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([m('a', '치과 예약')]),
    });

    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('뜻으로 찾기'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets(
    'premium semantic mode refreshes embeddings and returns cosine match',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'premium_user_id': 'memoyo-user-1',
        'memos': Memo.encodeList([
          m('dentist', '치과 예약\n스케일링 전화하기'),
          m('curry', '카레 레시피\n양파 볶기'),
        ]),
      });
      PremiumService.instance.entitlement.value = PremiumEntitlement(
        premium: true,
        productId: PremiumEntitlementClient.premiumProductId,
        expiresAt: DateTime(2999),
        source: PremiumEntitlementSource.subscription,
      );
      final client = MemoyoEmbeddingClient(
        transport: (_, payload) async {
          final texts = (payload['texts'] as List).cast<String>();
          final vectors = texts.map((text) {
            if (text.contains('카레')) return [0.0, 1.0];
            return [1.0, 0.0];
          }).toList();
          return {
            'model': 'gemini-embedding-001',
            'dimensions': 2,
            'embeddings': vectors,
          };
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: SearchScreen(embeddingClient: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('뜻으로 찾기'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '병원');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.textContaining('메모 결과 (1건)'), findsOneWidget);
      expect(find.textContaining('치과 예약', findRichText: true), findsWidgets);
      expect(find.textContaining('카레 레시피', findRichText: true), findsNothing);
    },
  );
}
