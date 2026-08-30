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
      final coordinator = SemanticSearchCoordinator(
        policy: SemanticEnginePolicy.ondevicePreferred,
        onDeviceEngine: onDevice,
        batchSize: 2,
      );
      final persisted = <List<Memo>>[];
      final initial = [_memo('one'), _memo('two'), _memo('three')];

      final interrupted = await coordinator.search(
        query: '메모',
        memos: initial,
        persist: (memos) async => persisted.add(List<Memo>.of(memos)),
      );

      expect(interrupted.semantic, isFalse);
      // ★T-260806-022: 종전 기대값 = 'GEMINI_OFFLINE'. 온디바이스가 2번째 배치에서
      //   끊긴 뒤 유료 Gemini 까지 시도하고 그것도 실패해서 나온 코드였다.
      //   이제 ondevice_preferred 는 유료로 안 넘어가므로 온디바이스 실패에서 멈춘다.
      //   이 테스트의 본론(배치별 persist·lexical 유지·재개)은 그대로다.
      // ★T-260830-013: 여기 있던 `expect(gemini.documentCalls, 0)` 는 유료 후보가
      //   ★타입 수준에서 사라져(SemanticEnginePolicy 에 gemini 없음) 표현할 대상이
      //   없어졌다. 비용축은 이제 런타임 카운터가 아니라 구조가 지킨다 —
      //   대체 계기 = semantic_ondevice_cost_axis_test.dart.
      expect(interrupted.fallbackCode, 'MINILM_INTERRUPTED');
      expect(interrupted.results, hasLength(3));
      expect(persisted, hasLength(1));
      expect(
        persisted.single.take(2).map((memo) => memo.semanticEmbeddingModel),
        everyElement('minilm-exact-id'),
      );
      expect(persisted.single.last.semanticEmbedding, isNull);

      onDevice.failDocumentCall = null;
      final resumed = await coordinator.search(
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
