import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/semantic_search_availability.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/premium_entitlement.dart';
import 'package:simple_memo_app/services/premium_service.dart';

// ★이 파일의 테스트는 말로찾기를 ★UI 세그먼트를 눌러서 검증한다. T-260804-086 으로 그
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

  // ★삭제된 본 = 'semantic mode tap without premium opens paywall' (T-260805-076).
  //   구독 폐지로 PaywallScreen 자체가 사라졌다. 이건 잠자던 테스트를 깨울 때
  //   되살릴 것이 아니다 — 「비구독자는 결제화면으로 간다」는 계약이 이제 존재하지 않는다.
  //   말로찾기 잠금 계약은 test/features/memos/semantic_search_hidden_test.dart 가 지킨다.

  // ★T-260830-013: 엔진을 유료(Gemini/Worker)에서 ★온디바이스 가짜로 갈아끼웠다.
  //   이 본이 재는 것은 「어느 엔진이냐」가 아니라 「세그먼트를 눌러 뜻 검색으로 들어가면
  //   임베딩이 갱신되고 코사인 유사도로 답이 좁혀지는가」다. 유료 경로가 lib/ 에서
  //   철거돼도 그 계약은 그대로 살아 있어야 한다 — 오히려 이제 이게 유일한 경로다.
  testWidgets(
    'semantic mode refreshes embeddings and returns cosine match',
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
        productId: PremiumEntitlement.premiumProductId,
        expiresAt: DateTime(2999),
        source: PremiumEntitlementSource.subscription,
      );
      final coordinator = SemanticSearchCoordinator(
        policy: SemanticEnginePolicy.ondevicePreferred,
        onDeviceEngine: _CosineFakeEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: SearchScreen(semanticCoordinator: coordinator)),
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

/// 2차원 가짜 온디바이스 엔진 — '카레' 계열만 다른 축으로 보낸다.
/// 종전 유료 transport 가 주던 벡터와 같은 모양이라, 이 본이 재던 코사인 판정이
/// 엔진 교체 뒤에도 동일하게 성립한다.
class _CosineFakeEngine implements EmbeddingEngine {
  @override
  String get engineId => 'minilm-fake';

  @override
  int get dimensions => 2;

  @override
  Future<EmbeddingCapability> capability() async =>
      const EmbeddingCapability(supported: true, ready: true);

  List<double> _vector(String text) =>
      text.contains('카레') ? const [0.0, 1.0] : const [1.0, 0.0];

  @override
  Future<EmbeddingBatch> embedDocuments(List<String> texts) async =>
      EmbeddingBatch(
        engineId: engineId,
        dimensions: 2,
        embeddings: texts.map(_vector).toList(),
      );

  @override
  Future<EmbeddingBatch> embedQuery(String text) async => EmbeddingBatch(
    engineId: engineId,
    dimensions: 2,
    embeddings: [_vector(text)],
  );

  @override
  Future<void> close() async {}
}
