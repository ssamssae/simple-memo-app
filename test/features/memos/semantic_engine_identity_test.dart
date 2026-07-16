import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_manifest.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_service.dart';
import 'package:simple_memo_app/models/memo.dart';

Memo _memo({
  required String id,
  required String model,
  required List<double> vector,
}) {
  final now = DateTime.utc(2026, 7, 17);
  final base = Memo(id: id, content: id, createdAt: now, updatedAt: now);
  return base.copyWith(
    semanticEmbedding: vector,
    semanticEmbeddingModel: model,
    semanticEmbeddingSource: SemanticSearchService.embeddingSourceFor(base),
  );
}

void main() {
  test('engine ID or dimension mismatch never invokes cosine', () {
    var cosineCalls = 0;
    final results = SemanticSearchService.search(
      [
        _memo(id: 'wrong-engine', model: 'old-engine', vector: const [1, 0]),
        _memo(
          id: 'wrong-dimension',
          model: MiniLmModelManifest.engineId,
          vector: const [1, 0, 0],
        ),
      ],
      const [1, 0],
      engineId: MiniLmModelManifest.engineId,
      dimensions: 2,
      similarity: (a, b) {
        cosineCalls++;
        return 1;
      },
    );

    expect(results, isEmpty);
    expect(cosineCalls, 0);
  });

  test('Gemini ↔ MiniLM switches mark the complete opposite index stale', () {
    final gemini = [
      _memo(
        id: 'a',
        model: SemanticSearchService.geminiModel,
        vector: const [1, 0],
      ),
      _memo(
        id: 'b',
        model: SemanticSearchService.geminiModel,
        vector: const [0, 1],
      ),
    ];
    expect(
      SemanticSearchService.staleMemos(
        gemini,
        engineId: MiniLmModelManifest.engineId,
        dimensions: MiniLmModelManifest.dimensions,
      ),
      hasLength(2),
    );

    final miniLm = gemini
        .map(
          (memo) => memo.copyWith(
            semanticEmbedding: List<double>.filled(
              MiniLmModelManifest.dimensions,
              0,
            )..[0] = 1,
            semanticEmbeddingModel: MiniLmModelManifest.engineId,
          ),
        )
        .toList();
    expect(
      SemanticSearchService.staleMemos(
        miniLm,
        engineId: SemanticSearchService.geminiModel,
        dimensions: 2,
      ),
      hasLength(2),
    );
  });
}
