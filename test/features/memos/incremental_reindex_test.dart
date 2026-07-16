import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';

import 'support/fake_embedding_engine.dart';

Memo _memo(String id) {
  final now = DateTime.utc(2026, 7, 17);
  return Memo(id: id, content: '$id 메모', createdAt: now, updatedAt: now);
}

void main() {
  test(
    'partial reindex persists each batch, stays lexical, then resumes',
    () async {
      final onDevice = FakeEmbeddingEngine(
        engineId: 'minilm-exact-id',
        dimensions: 2,
        failDocumentCall: 2,
        failureCode: 'MINILM_INTERRUPTED',
      );
      final gemini = FakeEmbeddingEngine(
        engineId: 'gemini-embedding-001',
        dimensions: 2,
        failDocumentCall: 1,
        failureCode: 'GEMINI_OFFLINE',
      );
      final coordinator = SemanticSearchCoordinator(
        policy: SemanticEnginePolicy.ondevicePreferred,
        geminiEngineFactory: (_) => gemini,
        onDeviceEngine: onDevice,
        batchSize: 2,
      );
      final persisted = <List<Memo>>[];
      final initial = [_memo('one'), _memo('two'), _memo('three')];

      final interrupted = await coordinator.search(
        userId: 'u',
        query: '메모',
        memos: initial,
        persist: (memos) async => persisted.add(List<Memo>.of(memos)),
      );

      expect(interrupted.semantic, isFalse);
      expect(interrupted.fallbackCode, 'GEMINI_OFFLINE');
      expect(interrupted.results, hasLength(3));
      expect(persisted, hasLength(1));
      expect(
        persisted.single.take(2).map((memo) => memo.semanticEmbeddingModel),
        everyElement('minilm-exact-id'),
      );
      expect(persisted.single.last.semanticEmbedding, isNull);

      onDevice.failDocumentCall = null;
      final resumed = await coordinator.search(
        userId: 'u',
        query: '메모',
        memos: interrupted.memos,
        persist: (memos) async => persisted.add(List<Memo>.of(memos)),
      );

      expect(resumed.semantic, isTrue);
      expect(onDevice.documentInputs.last, ['three 메모']);
      expect(
        resumed.memos.map((memo) => memo.semanticEmbeddingModel),
        everyElement('minilm-exact-id'),
      );
      expect(persisted, hasLength(2));
    },
  );
}
