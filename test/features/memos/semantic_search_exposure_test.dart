// T-260806-022 — 말로찾기 노출 계약. (구 semantic_search_hidden_test, T-260804-086)
//
// ■왜 잠금축에서 노출축으로 뒤집혔나
//   잠근 이유는 UI 취향이 아니라 ★돈이었다 — 열면 /api/memoyo/ai/embed (Gemini)가
//   아니키 비용으로 돌기 시작했다(아니키 2026-08-04 「내 api 로 비용은 못내겠어」).
//   T-260806-022 로 그 경로 자체를 없앴다: coordinator 는 policy 가 ★명시적으로 gemini
//   일 때만 gemini 를 후보에 넣고, 기본 정책 ondevice_preferred 에서는 온디바이스가
//   부재·미지원·실패해도 lexical 로 강등된다. 과금 사유가 사라졌으므로 문을 연다.
//
// ■그래서 이제 무엇을 지키나 — 「열렸다」가 아니라 ★「열렸는데 안 물린다」
//   (a) 문이 보인다  (b) ★문으로 들어가도 유료 호출이 0이다  (c) 스위치 기본 ON
//   (d) 설치를 권한다  (e) 이미 받은 사람은 지울 수 있다
//   ★(b) 가 이 파일의 심장이다. 잠금 시절엔 「안 눌러지니 0」이었지만 지금은
//   「눌렀는데도 0」이다 — 아래 setUp 이 온디바이스를 ★미지원으로 못박아 두므로,
//   (b)의 초록은 수리(유료 폴백 제거)가 실제 UI 경로에서 먹는다는 end-to-end 증명이다.
//   (b) 가 빨개지면 그건 노출이 아니라 ★과금이 되살아난 것이다.
//
// ■mutation probe (계기가 살아있음의 증명)
//   이 파일의 초록은 스위치를 뒤집었을 때 ★빨개져야만 초록이다. 확인 방법:
//     flutter test --dart-define=MEMOYO_SEMANTIC_SEARCH=false \
//       test/features/memos/semantic_search_exposure_test.dart
//   비용 축의 계기 생존은 별도다 — coordinator 의 폴백 차단을 원복하면
//   semantic_ondevice_cost_axis_test 와 이 파일 (b) 가 함께 빨개진다.
//   착수 시 실측으로 확인하고 보고에 출력을 첨부했다. 이 파일을 고칠 사람은 같은 절차를
//   다시 밟아라 — 안 밟으면 0회 도는 장식이 된다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/semantic_search_availability.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_controller.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Memo m(String id, String content) {
    final t = DateTime(2026, 8, 4, 10);
    return Memo(id: id, content: content, createdAt: t, updatedAt: t);
  }

  // 온디바이스 MiniLM 네이티브 채널은 테스트 환경에 없다. ★미지원으로 못박아 둔다 —
  // 종전엔 「잠금이 풀리면 Gemini 로 내려가 스파이가 불린다」는 probe 였고, 수리 후에는
  // 「미지원인데도 유료로 안 내려간다」는 (b)의 검증 조건이 된다. 같은 설정이 역할만 바뀌었다.
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

  testWidgets('(a) 검색 화면에 말로찾기 세그먼트가 렌더된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    // ★대조군 먼저 — 검색 화면이 실제로 떴는지 증명한다.
    expect(find.byType(TextField), findsOneWidget,
        reason: '검색 화면이 안 떴다 — 아래 판정이 무의미해진다');

    expect(find.text('뜻으로 찾기'), findsOneWidget,
        reason: '말로찾기 세그먼트가 안 보인다 — 노출 스위치가 안 먹었다 (T-260806-022)');
  });

  testWidgets('★(b) 노출된 뒤에도 유료 임베딩 클라이언트가 한 번도 호출되지 않는다', (tester) async {
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

    // ★사람이 하는 짓 그대로 — 문이 열렸으니 ★실제로 들어간다.
    //   여기가 이 파일의 심장이다. 세그먼트를 눌러 시맨틱 경로로 진입시킨 뒤에도
    //   embedCalls 가 0 이어야 한다. setUp 이 온디바이스를 미지원으로 못박아 뒀으므로
    //   수리 전이라면 여기서 gemini 로 내려가 스파이가 불렸다(2회 실측, T-260806-021).
    //   조건부 tap 을 남겨 둔 이유는 스위치를 끈 실행(mutation probe)에서 「대상 없음」
    //   으로 죽지 않고 (a) 가 먼저 실패를 말하게 하려는 것이다.
    final semanticSegment = find.text('뜻으로 찾기');
    expect(semanticSegment, findsOneWidget,
        reason: '세그먼트가 없다 — (b) 가 「눌러도 0」이 아니라 「못 눌러서 0」이 된다');
    await tester.tap(semanticSegment);
    await tester.pumpAndSettle();

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
        reason: '유료 임베딩 API 가 호출됐다 — 유료 폴백이 되살아났다 (아니키 비용축). '
            'coordinator 가 gemini 를 무조건 후보에 넣고 있지 않은지 볼 것');
  });

  test('(c) 스위치는 기본 ON 이다 — 유료 경로가 없으니 감출 이유가 없다', () {
    // dart-define 으로 끈 실행에서는 이 단언이 뒤집히는 것이 정상이다(= mutation probe).
    expect(kSemanticSearchEnabled, isTrue,
        reason: '말로찾기가 다시 잠겼다 — 되돌린 것이라면 (a)(b)(d) 도 같이 뒤집어야 한다');
  });

  // ■(d)(e) 의 유래 — T-260805-145
  //   (a)(b)(c) 는 ★검색 화면만 셌다. 그런데 잠긴 기능을 파는 표면이 하나 더 있었다:
  //   설정 화면의 「기기 내 뜻 검색 모델 · 약 124MB」 타일이다. 검색 UI 는 플래그로 가려지는데
  //   그 타일만 게이트 밖이라, 출고본에서 ★쓸 수 없는 기능을 위해 124MB 를 받으라고 권했다.
  //   ⇒ 노출(T-260806-022) 뒤에는 방향이 뒤집힌다. 기능을 쓸 수 있으니 ★권하는 게 맞다.
  //   (d) 는 그래서 findsNothing → findsOneWidget 으로 뒤집혔다. (e) 는 그대로다 —
  //   회수 경로는 잠금 여부와 무관하게 항상 있어야 하기 때문이다.

  testWidgets('(d) 노출 뒤에는 설정 화면이 모델 설치를 권한다', (tester) async {
    // 미설치(absent) = 타일이 다운로드를 권하는 상태.
    final manager = _FakeModelManager(MiniLmModelState.absent);
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(miniLmModelManager: manager)),
    );
    await tester.pumpAndSettle();

    // ★대조군 먼저 — 설정 화면이 실제로 떴는지 증명한다.
    expect(find.text('글자 크기'), findsOneWidget,
        reason: '설정 화면이 안 떴다 — 아래 판정이 무의미해진다');

    expect(find.byKey(const Key('minilm-model-tile')), findsOneWidget,
        reason: '말로찾기를 열었는데 모델 설치 문이 없다 — 온디바이스로 쓸 방법이 사라진다');
  });

  testWidgets('(e) 이미 받은 기기에서는 타일이 남아 용량을 지울 수 있다', (tester) async {
    // ★잠금 여부와 무관한 축이다. 타일을 조건부로 만드는 어떤 변경도 ★삭제 버튼까지
    //   같이 없애면 안 된다 — 124MB 를 회수할 문이 닫히면 사용자 손해다.
    final manager = _FakeModelManager(MiniLmModelState.ready);
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(miniLmModelManager: manager)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minilm-model-tile')), findsOneWidget,
        reason: '이미 설치된 모델의 타일까지 감췄다 — 124MB 를 지울 문이 사라진다');
    expect(find.byKey(const Key('minilm-delete-button')), findsOneWidget,
        reason: '삭제 버튼이 없다 — 타일만 남고 회수 경로가 없으면 (e) 의 목적이 무너진다');
  });
}

class _FakeModelManager extends MiniLmModelManager {
  _FakeModelManager(this._state);

  final MiniLmModelState _state;

  @override
  String? get errorCode => null;

  @override
  double get progress => 0;

  @override
  MiniLmModelState get state => _state;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> install() async {}

  @override
  Future<void> delete() async {}
}
