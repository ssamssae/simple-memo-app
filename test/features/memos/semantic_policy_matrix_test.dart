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
    test('${entry.key} on-device falls back to Gemini', () async {
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

      expect(outcome.engineId, 'gemini-embedding-001');
      expect(onDevice.documentCalls, 0);
      expect(gemini.documentCalls, 1);
    });
  }

  test('on-device then Gemini failures end in lexical results', () async {
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
    expect(outcome.fallbackCode, 'GEMINI_FAILED');
    expect(outcome.results, hasLength(1));
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
