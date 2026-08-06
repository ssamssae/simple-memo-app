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

  Future<void> run(SemanticSearchCoordinator c) async {
    await c.search(
      userId: 'u1',
      query: '병원',
      memos: memos(),
      persist: (_) async {},
    );
  }

  setUp(() => paidCalls = 0);

  test('기본 정책이 ondevice_preferred 다 — 전제 확인', () {
    expect(SemanticEnginePolicy.configuredValue, 'ondevice_preferred');
    expect(SemanticEnginePolicy.configured, SemanticEnginePolicy.ondevicePreferred);
  });

  test('(1) 모델이 준비된 온디바이스 경로는 유료 API 를 부르지 않는다', () async {
    await run(coordinator(onDevice: _FakeOnDevice(ready: true)));
    expect(paidCalls, 0, reason: '온디바이스가 준비됐는데 유료 호출이 나갔다');
  });

  test('★(2) 모델 미설치 폴백이 유료 API 로 샌다 — 이게 막혀야 노출 가능', () async {
    await run(coordinator(onDevice: _FakeOnDevice(ready: false)));
    expect(
      paidCalls,
      0,
      reason:
          '모델 미설치(MEMOYO_MINILM_MODEL_MISSING) 상태에서 유료 임베딩 호출이 '
          '$paidCalls 회 나갔다. coordinator 가 policy 와 무관하게 gemini 엔진을 '
          '후보에 무조건 넣는다(semantic_search_coordinator.dart:81).',
    );
  });

  test('★(3) 온디바이스 엔진 자체가 없는 기기도 유료 API 로 샌다', () async {
    await run(coordinator(onDevice: null));
    expect(
      paidCalls,
      0,
      reason:
          '미지원 기기(MEMOYO_MINILM_UNSUPPORTED)에서 유료 임베딩 호출이 '
          '$paidCalls 회 나갔다.',
    );
  });

  test('★(4) 온디바이스가 도중에 실패해도 유료 API 로 넘어간다', () async {
    await run(coordinator(onDevice: _FakeOnDevice(ready: true, throwOnEmbed: true)));
    expect(
      paidCalls,
      0,
      reason: '온디바이스 실패 시 유료 임베딩 호출이 $paidCalls 회 나갔다.',
    );
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
