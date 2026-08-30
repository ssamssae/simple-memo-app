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
  // ★T-260830-013: 종전에 있던 gemini(유료) 본 2개를 걷었다 —
  //   'gemini policy never probes on-device capability' 와 이 매트릭스 곳곳의
  //   gemini FakeEmbeddingEngine 대조군이다. 유료 항목이 enum 에서 사라져
  //   컴파일 자체가 안 되고, 「유료를 안 탄다」는 이제 런타임이 아니라 타입이 보증한다.
  //   구조 회귀축 = semantic_ondevice_cost_axis_test.dart (A) 소스 스캔.
  test('default flag is ondevice_preferred and parser accepts both policies', () {
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
    // 미지정 값은 종전 gemini(유료)에서 온디바이스(공짜)로 내려간다.
    expect(
      SemanticEnginePolicy.fromValue('unknown'),
      SemanticEnginePolicy.ondevicePreferred,
    );
  });

  test('ondevice_preferred uses ready device engine', () async {
    final onDevice = FakeEmbeddingEngine(engineId: 'mini', dimensions: 2);
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.ondevicePreferred,
      onDeviceEngine: onDevice,
    ).search(query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.engineId, 'mini');
    expect(onDevice.documentCalls, 1);
  });

  for (final entry in <String, EmbeddingCapability>{
    'unsupported': const EmbeddingCapability.unsupported(),
    'not-installed': const EmbeddingCapability(supported: true, ready: false),
  }.entries) {
    // ★T-260806-022 로 뒤집힌 계약. 종전 = 「Gemini 로 폴백한다」.
    //   ondevice_preferred 에서 유료 폴백을 걷어냈으므로 이제 lexical 로 강등된다.
    //   사유 = 아니키 비용축. 상세는 semantic_ondevice_cost_axis_test.dart 헤더.
    test('${entry.key} on-device degrades to lexical', () async {
      final onDevice = FakeEmbeddingEngine(
        engineId: 'mini',
        dimensions: 2,
        capabilityValue: entry.value,
      );
      final outcome = await SemanticSearchCoordinator(
        policy: SemanticEnginePolicy.ondevicePreferred,
        onDeviceEngine: onDevice,
      ).search(query: '찾기', memos: [_memo()], persist: _persist);

      expect(outcome.semantic, isFalse);
      expect(outcome.engineId, isNull);
      expect(onDevice.documentCalls, 0);
    });
  }

  test('on-device failure ends in lexical', () async {
    final onDevice = FakeEmbeddingEngine(
      engineId: 'mini',
      dimensions: 2,
      failDocumentCall: 1,
      failureCode: 'MINI_FAILED',
    );
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.ondevicePreferred,
      onDeviceEngine: onDevice,
    ).search(query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.semantic, isFalse);
    // 종전 기대값 = 'GEMINI_FAILED' (온디바이스 실패 뒤 유료까지 시도하고 그것도 실패).
    // 이제 유료를 아예 안 타므로 마지막 실패 사유는 온디바이스 것이다.
    expect(outcome.fallbackCode, 'MINI_FAILED');
    expect(outcome.results, hasLength(1));
  });

  test('lexical policy calls no embedding engine', () async {
    final onDevice = FakeEmbeddingEngine(engineId: 'mini', dimensions: 2);
    final outcome = await SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.lexical,
      onDeviceEngine: onDevice,
    ).search(query: '찾기', memos: [_memo()], persist: _persist);

    expect(outcome.semantic, isFalse);
    expect(onDevice.capabilityCalls, 0);
  });
}
