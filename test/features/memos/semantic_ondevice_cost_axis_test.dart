import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/gemini_embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';

/// 말로찾기 온디바이스 전환의 ★비용 축 검증 (T-260806-021).
///
/// 아니키 적색선 = 「내 api 로 비용은 못내겠어」
/// (semantic_search_availability.dart 헤더 T-260804-086 인용).
///
/// 재는 것은 「온디바이스 코드가 있는가」가 아니라 **유료 엔드포인트
/// `/api/memoyo/ai/embed` 로 나가는 호출이 0인가** 이다. 호출 카운터를 세운다.
void main() {
  final t = DateTime(2026, 8, 6, 11);
  List<Memo> memos() => [
    Memo(id: 'a', content: '치과 예약\n스케일링', createdAt: t, updatedAt: t),
    Memo(id: 'b', content: '카레 레시피\n양파', createdAt: t, updatedAt: t),
  ];

  /// 유료 임베딩 호출 카운터. transport 가 곧 과금 경로다.
  late int paidCalls;

  MemoyoEmbeddingClient spyClient() {
    return MemoyoEmbeddingClient(
      transport: (_, payload) async {
        paidCalls++;
        final texts = (payload['texts'] as List).cast<String>();
        return {
          'model': 'gemini-embedding-001',
          'dimensions': 2,
          'embeddings': texts
              .map((x) => x.contains('카레') ? [0.0, 1.0] : [1.0, 0.0])
              .toList(),
        };
      },
    );
  }

  SemanticSearchCoordinator coordinator({EmbeddingEngine? onDevice}) {
    final client = spyClient();
    return SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.ondevicePreferred,
      geminiEngineFactory: (userId) =>
          GeminiEmbeddingEngine(client: client, userId: userId),
      onDeviceEngine: onDevice,
    );
  }

  Future<SemanticSearchOutcome> run(SemanticSearchCoordinator c) async {
    return c.search(
      userId: 'u1',
      query: '병원',
      memos: memos(),
      persist: (_) async {},
    );
  }

  /// 「유료 호출 0」만 재면 검색이 통째로 터져도 통과한다. 강등이 실제로
  /// 일어났는지(=공짜 경로로 답을 돌려주는지)까지 같이 잰다.
  void expectDegradedToLexical(SemanticSearchOutcome outcome, String situation) {
    expect(paidCalls, 0, reason: '$situation 에서 유료 임베딩 호출이 $paidCalls 회 나갔다');
    expect(outcome.semantic, isFalse, reason: '$situation 인데 semantic 로 표시됐다');
    expect(
      outcome.fallbackCode,
      isNotNull,
      reason: '$situation 강등인데 사유 코드가 없다',
    );
  }

  setUp(() => paidCalls = 0);

  test('기본 정책이 ondevice_preferred 다 — 전제 확인', () {
    expect(SemanticEnginePolicy.configuredValue, 'ondevice_preferred');
    expect(SemanticEnginePolicy.configured, SemanticEnginePolicy.ondevicePreferred);
  });

  test('(1) 모델이 준비되면 온디바이스로 뜻 검색을 하고 유료 API 를 안 부른다', () async {
    final outcome = await run(coordinator(onDevice: _FakeOnDevice(ready: true)));
    expect(paidCalls, 0, reason: '온디바이스가 준비됐는데 유료 호출이 나갔다');
    expect(outcome.semantic, isTrue);
    expect(outcome.engineId, 'minilm-fake');
  });

  test('★(2) 모델 미설치면 유료로 안 넘어가고 lexical 로 강등된다', () async {
    final outcome = await run(coordinator(onDevice: _FakeOnDevice(ready: false)));
    expectDegradedToLexical(outcome, '모델 미설치(MEMOYO_MINILM_MODEL_MISSING)');
    expect(outcome.fallbackCode, 'MEMOYO_MINILM_MODEL_MISSING');
  });

  test('★(3) 온디바이스 미지원 기기도 유료 API 를 부르지 않는다', () async {
    final outcome = await run(coordinator(onDevice: null));
    expectDegradedToLexical(outcome, '미지원 기기(MEMOYO_MINILM_UNSUPPORTED)');
    expect(outcome.fallbackCode, 'MEMOYO_MINILM_UNSUPPORTED');
  });

  test('★(4) 온디바이스가 도중에 실패해도 유료 API 로 안 넘어간다', () async {
    final outcome = await run(
      coordinator(onDevice: _FakeOnDevice(ready: true, throwOnEmbed: true)),
    );
    expectDegradedToLexical(outcome, '온디바이스 런타임 실패');
  });

  test('(5) 경계 — policy 를 명시적으로 gemini 로 준 경우엔 종전대로 쓴다', () async {
    // 유료 경로를 「없앤」 게 아니라 「말로찾기 기본 경로에서 뺀」 것이다.
    // 이 본이 없으면 다음 사람이 gemini 지원까지 지워도 아무도 안 잡는다.
    final client = spyClient();
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.gemini,
      geminiEngineFactory: (userId) =>
          GeminiEmbeddingEngine(client: client, userId: userId),
    ).search(
      userId: 'u1',
      query: '병원',
      memos: memos(),
      persist: (_) async {},
    );
    expect(paidCalls, greaterThan(0));
    expect(outcome.semantic, isTrue);
  });
}

class _FakeOnDevice implements EmbeddingEngine {
  _FakeOnDevice({required this.ready, this.throwOnEmbed = false});

  final bool ready;
  final bool throwOnEmbed;

  @override
  String get engineId => 'minilm-fake';

  @override
  int get dimensions => 2;

  @override
  Future<EmbeddingCapability> capability() async =>
      EmbeddingCapability(supported: true, ready: ready);

  @override
  Future<EmbeddingBatch> embedDocuments(List<String> texts) async {
    if (throwOnEmbed) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.unavailable,
        'MEMOYO_MINILM_RUNTIME_FAILED',
      );
    }
    return EmbeddingBatch(
      engineId: engineId,
      dimensions: 2,
      embeddings: texts
          .map((x) => x.contains('카레') ? [0.0, 1.0] : [1.0, 0.0])
          .toList(),
    );
  }

  @override
  Future<EmbeddingBatch> embedQuery(String text) async {
    if (throwOnEmbed) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.unavailable,
        'MEMOYO_MINILM_RUNTIME_FAILED',
      );
    }
    return EmbeddingBatch(
      engineId: engineId,
      dimensions: 2,
      embeddings: const [
        [1.0, 0.0],
      ],
    );
  }

  @override
  Future<void> close() async {}
}
