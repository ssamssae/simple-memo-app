import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';

import 'support/fake_embedding_engine.dart';

Memo _memo() {
  final now = DateTime.utc(2026, 7, 17);
  return Memo(id: 'memo', content: '찾기 메모', createdAt: now, updatedAt: now);
}

Future<void> _persist(List<Memo> _) async {}

void main() {
  test('default flag is ondevice_preferred and parser accepts all three policies', () {
    expect(
      SemanticEnginePolicy.configured,
      SemanticEnginePolicy.ondevicePreferred,
    );
    expect(
      SemanticEnginePolicy.fromValue('ondevice_preferred'),
      SemanticEnginePolicy.ondevicePreferred,
    );
    expect(
      SemanticEnginePolicy.fromValue('lexical'),
      SemanticEnginePolicy.lexical,
    );
    expect(
      SemanticEnginePolicy.fromValue('unknown'),
      SemanticEnginePolicy.gemini,
    );
  });

  test('gemini policy never probes on-device capability', () async {
    final onDevice = FakeEmbeddingEngine(engineId: 'mini', dimensions: 2);
    final gemini = FakeEmbeddingEngine(
      engineId: 'gemini-embedding-001',
      dimensions: 2,
    );
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.gemini,
      geminiEngineFactory: (_) => gemini,
      onDeviceEngine: onDevice,
    ).search(userId: 'u', query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.semantic, isTrue);
    expect(outcome.engineId, 'gemini-embedding-001');
    expect(onDevice.capabilityCalls, 0);
    expect(gemini.documentCalls, 1);
  });

  test('ondevice_preferred uses ready device engine before Gemini', () async {
    final onDevice = FakeEmbeddingEngine(engineId: 'mini', dimensions: 2);
    final gemini = FakeEmbeddingEngine(
      engineId: 'gemini-embedding-001',
      dimensions: 2,
    );
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.ondevicePreferred,
      geminiEngineFactory: (_) => gemini,
      onDeviceEngine: onDevice,
    ).search(userId: 'u', query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.engineId, 'mini');
    expect(onDevice.documentCalls, 1);
    expect(gemini.documentCalls, 0);
  });

  for (final entry in <String, EmbeddingCapability>{
    'unsupported': const EmbeddingCapability.unsupported(),
    'not-installed': const EmbeddingCapability(supported: true, ready: false),
  }.entries) {
    // ★T-260806-022 로 뒤집힌 계약. 종전 = 「Gemini 로 폴백한다」.
    //   ondevice_preferred 에서 유료 폴백을 걷어냈으므로 이제 lexical 로 강등된다.
    //   사유 = 아니키 비용축. 상세는 semantic_ondevice_cost_axis_test.dart 헤더.
    test('${entry.key} on-device degrades to lexical, never Gemini', () async {
      final onDevice = FakeEmbeddingEngine(
        engineId: 'mini',
        dimensions: 2,
        capabilityValue: entry.value,
      );
      final gemini = FakeEmbeddingEngine(
        engineId: 'gemini-embedding-001',
        dimensions: 2,
      );
      final outcome = await SemanticSearchCoordinator(
        policy: SemanticEnginePolicy.ondevicePreferred,
        geminiEngineFactory: (_) => gemini,
        onDeviceEngine: onDevice,
      ).search(userId: 'u', query: '찾기', memos: [_memo()], persist: _persist);

      expect(outcome.semantic, isFalse);
      expect(outcome.engineId, isNull);
      expect(onDevice.documentCalls, 0);
      expect(gemini.documentCalls, 0, reason: '유료 임베딩이 호출됐다 — 비용축 위반');
    });
  }

  test('on-device failure ends in lexical without touching Gemini', () async {
    final onDevice = FakeEmbeddingEngine(
      engineId: 'mini',
      dimensions: 2,
      failDocumentCall: 1,
      failureCode: 'MINI_FAILED',
    );
    final gemini = FakeEmbeddingEngine(
      engineId: 'gemini-embedding-001',
      dimensions: 2,
      failDocumentCall: 1,
      failureCode: 'GEMINI_FAILED',
    );
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.ondevicePreferred,
      geminiEngineFactory: (_) => gemini,
      onDeviceEngine: onDevice,
    ).search(userId: 'u', query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.semantic, isFalse);
    // 종전 기대값 = 'GEMINI_FAILED' (온디바이스 실패 뒤 유료까지 시도하고 그것도 실패).
    // 이제 유료를 아예 안 타므로 마지막 실패 사유는 온디바이스 것이다.
    expect(outcome.fallbackCode, 'MINI_FAILED');
    expect(outcome.results, hasLength(1));
    expect(gemini.documentCalls, 0, reason: '유료 임베딩이 호출됐다 — 비용축 위반');
  });

  test('lexical policy calls neither embedding engine', () async {
    final onDevice = FakeEmbeddingEngine(engineId: 'mini', dimensions: 2);
    final gemini = FakeEmbeddingEngine(
      engineId: 'gemini-embedding-001',
      dimensions: 2,
    );
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.lexical,
      geminiEngineFactory: (_) => gemini,
      onDeviceEngine: onDevice,
    ).search(userId: 'u', query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.semantic, isFalse);
    expect(onDevice.capabilityCalls, 0);
    expect(gemini.documentCalls, 0);
  });
}
