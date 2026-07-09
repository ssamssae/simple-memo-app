import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_service.dart';
import 'package:simple_memo_app/models/memo.dart';

Memo memo(
  String id,
  String content, {
  List<double>? embedding,
  DateTime? updatedAt,
  bool favorite = false,
}) {
  final t = updatedAt ?? DateTime(2026, 7, 9, 10);
  return Memo(
    id: id,
    content: content,
    isFavorite: favorite,
    createdAt: t,
    updatedAt: t,
    semanticEmbedding: embedding,
    semanticEmbeddingModel: SemanticSearchService.model,
    semanticEmbeddingSource: 'source:$id',
  );
}

void main() {
  test('cosineSimilarity uses vector direction and handles zero vectors', () {
    expect(
      SemanticSearchService.cosineSimilarity([2, 0], [4, 0]),
      closeTo(1, 1e-9),
    );
    expect(SemanticSearchService.cosineSimilarity([0, 0], [1, 0]), 0);
  });

  test('staleMemos returns missing or stale memo embeddings only', () {
    final freshBase = memo('fresh', '치과 예약');
    final fresh = freshBase.copyWith(
      semanticEmbedding: const [1, 0],
      semanticEmbeddingModel: SemanticSearchService.model,
      semanticEmbeddingSource: SemanticSearchService.embeddingSourceFor(
        freshBase,
      ),
    );
    final stale = memo('stale', '카레 레시피', embedding: const [0, 1]);
    final missing = memo('missing', '병원 메모');

    expect(
      SemanticSearchService.staleMemos([
        fresh,
        stale,
        missing,
      ]).map((m) => m.id),
      ['stale', 'missing'],
    );
  });

  test('semantic search ranks by cosine score then favorite/updatedAt', () {
    final older = memo(
      'older',
      '치과 예약',
      embedding: const [0.9, 0.1],
      updatedAt: DateTime(2026, 1, 1),
    );
    final favorite = memo(
      'favorite',
      '병원 접수',
      embedding: const [0.9, 0.1],
      favorite: true,
      updatedAt: DateTime(2026, 1, 1),
    );
    final unrelated = memo('unrelated', '카레 레시피', embedding: const [0, 1]);

    final results = SemanticSearchService.search(
      [older, favorite, unrelated],
      const [1, 0],
      minScore: 0.2,
    );

    expect(results.map((m) => m.id), ['favorite', 'older']);
  });
}
