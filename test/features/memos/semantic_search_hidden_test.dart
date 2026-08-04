// T-260804-086 — 말로찾기가 ★조용히 되살아나면 빨개지는 회귀축.
//
// ■무엇을 지키나
//   아니키 결정 2026-08-04 23:33 「말로찾기는 3안으로 가, 온디바이스 될 때까지 그 기능만 숨겨」.
//   지키려는 것은 UI 취향이 아니라 ★돈이다 — 말로찾기가 열리면 /api/memoyo/ai/embed (Gemini)가
//   아니키 비용으로 다시 돌기 시작한다. 그래서 (a) 문이 안 보이고 (b) 문 뒤로 못 간다를 둘 다 센다.
//
// ■왜 두 본인가 — 하나로는 못 막는다
//   (a)만 있으면 「세그먼트는 감췄는데 다른 진입점에서 임베딩이 도는」 상태를 못 잡는다.
//   (b)만 있으면 「경로는 막혔는데 눌러도 안 되는 죽은 버튼이 남은」 상태를 못 잡는다.
//   실패 모양이 서로 다르므로 둘 다 필요하다.
//
// ■mutation probe (계기가 살아있음의 증명)
//   이 파일의 초록은 스위치를 뒤집었을 때 ★빨개져야만 초록이다. 확인 방법:
//     flutter test --dart-define=MEMOYO_SEMANTIC_SEARCH=true \
//       test/features/memos/semantic_search_hidden_test.dart
//   착수 시 실측으로 RED 를 확인하고 보고에 출력을 첨부했다. 이 파일을 고칠 사람은 같은 절차를
//   다시 밟아라 — 안 밟으면 0회 도는 장식이 된다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/semantic_search_availability.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Memo m(String id, String content) {
    final t = DateTime(2026, 8, 4, 10);
    return Memo(id: id, content: content, createdAt: t, updatedAt: t);
  }

  // 온디바이스 MiniLM 네이티브 채널은 테스트 환경에 없다. 미지원으로 답해 두면 잠금이 풀린
  // 상태(probe)에서 Gemini 경로로 내려가 스파이가 실제로 불린다 — 그래야 probe 가 의미를 갖는다.
  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // ★프리미엄을 ★켠 채로 잰다. 잠금이 「구독이 없어서」가 아니라 「기능을 감췄기 때문」임을
  //   보이기 위해서다. 무료 계정으로 재면 페이월이 막아 준 것인지 스위치가 막은 것인지 안 갈린다.
  setUp(() {
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        'close' => null,
        _ => null,
      };
    });
    PremiumService.instance.entitlement.value = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlementClient.premiumProductId,
      expiresAt: DateTime(2999),
      source: PremiumEntitlementSource.subscription,
    );
    SharedPreferences.setMockInitialValues({
      'premium_user_id': 'memoyo-user-1',
      'memos': Memo.encodeList([
        m('dentist', '치과 예약\n스케일링 전화하기'),
        m('curry', '카레 레시피\n양파 볶기'),
      ]),
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
  });

  testWidgets('(a) 검색 화면에 말로찾기 세그먼트가 렌더되지 않는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    // ★대조군 먼저 — 검색 화면이 실제로 떴는지 증명한다. 화면이 안 떴으면 아래 findsNothing 은
    //   「감췄다」가 아니라 「아무것도 안 그려졌다」의 0건이고, 그건 눈먼 초록이다.
    expect(find.byType(TextField), findsOneWidget,
        reason: '검색 화면이 안 떴다 — 아래 findsNothing 판정이 무의미해진다');

    expect(find.text('뜻으로 찾기'), findsNothing,
        reason: '말로찾기 세그먼트가 되살아났다 (T-260804-086 로 감춘 것)');
    expect(find.byType(SegmentedButton<Object?>), findsNothing,
        reason: '모드 선택기가 되살아났다 — 남는 모드가 하나뿐이라 선택기 자체를 감췄었다');
  });

  testWidgets('(b) 잠금 상태에서 유료 임베딩 클라이언트가 한 번도 호출되지 않는다', (tester) async {
    // 스파이 — 전송계층이 불리면 계수가 올라간다. 실제 네트워크는 타지 않는다.
    var embedCalls = 0;
    final spy = MemoyoEmbeddingClient(
      transport: (_, payload) async {
        embedCalls++;
        final texts = (payload['texts'] as List).cast<String>();
        return {
          'model': 'gemini-embedding-001',
          'dimensions': 2,
          'embeddings': texts.map((_) => [1.0, 0.0]).toList(),
        };
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: SearchScreen(embeddingClient: spy)),
    );
    await tester.pumpAndSettle();

    // ★사람이 하는 짓 그대로 흉내낸다 — 「그 버튼이 있으면 누른다」.
    //   잠금 상태에서는 버튼이 없으니 안 누른다. 잠금이 풀리면 눌러서 임베딩이 돌고
    //   아래 embedCalls==0 이 깨진다 = ★이 축도 mutation probe 에 반응한다.
    //   조건 없이 tap 하면 잠금 상태에서 「대상 없음」으로 죽어서, 잠금이 뚫린 것과
    //   구분이 안 되는 빨강이 나온다. 그래서 존재를 먼저 본다.
    final semanticSegment = find.text('뜻으로 찾기');
    if (semanticSegment.evaluate().isNotEmpty) {
      await tester.tap(semanticSegment);
      await tester.pumpAndSettle();
    }

    // 검색어를 치고 디바운스를 넘긴다. '치과' 는 ★어휘 검색으로도 잡히는 말이어야 한다 —
    // 대조군이 성립해야 embedCalls==0 을 읽을 수 있기 때문이다.
    await tester.enterText(find.byType(TextField), '치과');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // ★대조군 — 어휘 검색은 정상 동작해야 한다. 여기서 결과가 0이면 검색 자체가 죽은 것이고,
    //   그때의 embedCalls==0 은 「막았다」가 아니라 「아무 일도 안 일어났다」다.
    expect(find.textContaining('치과 예약', findRichText: true), findsWidgets,
        reason: '어휘 검색이 죽었다 — embedCalls==0 이 잠금의 증거가 되지 못한다');

    expect(embedCalls, 0,
        reason: '유료 임베딩 API 가 호출됐다 — 말로찾기 잠금이 뚫렸다 (아니키 비용축)');
  });

  test('(c) 스위치는 기본 OFF 다 — 잠금이 기본값이어야 한다', () {
    // dart-define 으로 켠 실행에서는 이 단언이 뒤집히는 것이 정상이다(= mutation probe).
    expect(kSemanticSearchEnabled, isFalse,
        reason: '말로찾기 기본값이 켜졌다 — 온디바이스 완성 전이라면 비용이 되살아난다');
  });
}
