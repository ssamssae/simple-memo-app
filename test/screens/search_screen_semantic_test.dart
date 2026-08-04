import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/semantic_search_availability.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/gemini_embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/paywall_screen.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';

// ★이 파일의 두 테스트는 말로찾기를 ★UI 세그먼트를 눌러서 검증한다. T-260804-086 으로 그
//   세그먼트를 감췄기 때문에 잠금 상태에서는 누를 대상이 없어 반드시 실패한다.
//   ⇒ 지우지 않고 skip 으로 재운다. 이유는 가역성이다 — 온디바이스가 완성돼
//   kSemanticSearchEnabled 가 true 가 되면 ★이 두 본이 자동으로 깨어난다.
//   지웠다면 되살리는 비용이 「한 줄」이 아니게 되고, 되살릴 때 검증이 비어 있게 된다.
//   (skip 사유: 말로찾기 잠금 중 — kSemanticSearchEnabled 를 켜면 자동 복귀.
//    testWidgets 의 skip 은 bool 만 받아서 사유 문자열을 못 실는다. 그래서 여기 적는다.)
const bool _semanticHidden = !kSemanticSearchEnabled;

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
  }, skip: _semanticHidden);

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
      final coordinator = SemanticSearchCoordinator(
        policy: SemanticEnginePolicy.gemini,
        geminiEngineFactory: (userId) =>
            GeminiEmbeddingEngine(client: client, userId: userId),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            embeddingClient: client,
            semanticCoordinator: coordinator,
          ),
        ),
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
    skip: _semanticHidden,
  );
}
