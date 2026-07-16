import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_manifest.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_service.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  test(
    'backup/restore preserves engine metadata and re-evaluates stale state',
    () {
      final now = DateTime.utc(2026, 7, 17);
      final base = Memo(
        id: 'memo',
        content: '치과 예약',
        createdAt: now,
        updatedAt: now,
      );
      final indexed = base.copyWith(
        semanticEmbedding: const [1, 0],
        semanticEmbeddingModel: SemanticSearchService.geminiModel,
        semanticEmbeddingSource: SemanticSearchService.embeddingSourceFor(base),
      );

      final restored = Memo.decodeList(Memo.encodeList([indexed])).single;

      expect(
        restored.semanticEmbeddingModel,
        SemanticSearchService.geminiModel,
      );
      expect(
        SemanticSearchService.staleMemos(
          [restored],
          engineId: MiniLmModelManifest.engineId,
          dimensions: MiniLmModelManifest.dimensions,
        ),
        hasLength(1),
      );
    },
  );

  test('pre-semantic JSON remains backwards compatible and safely stale', () {
    final oldJson = jsonEncode([
      {
        'id': 'legacy',
        'content': '오래된 백업',
        'isFavorite': false,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      },
    ]);

    final restored = Memo.decodeList(oldJson).single;

    expect(restored.semanticEmbedding, isNull);
    expect(restored.semanticEmbeddingModel, isNull);
    expect(SemanticSearchService.staleMemos([restored]), hasLength(1));
  });
}
