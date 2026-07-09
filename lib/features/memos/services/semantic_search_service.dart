import 'dart:math' as math;

import '../../../models/memo.dart';

class SemanticSearchService {
  static const model = 'gemini-embedding-001';
  static const defaultMinScore = 0.2;

  static String embeddingSourceFor(Memo memo) {
    final hash = _fnv1a32(memo.content);
    return '${memo.updatedAt.toUtc().toIso8601String()}:$hash';
  }

  static Iterable<Memo> staleMemos(Iterable<Memo> memos) {
    return memos.where((memo) {
      final embedding = memo.semanticEmbedding;
      if (embedding == null || embedding.isEmpty) return true;
      return memo.semanticEmbeddingModel != model ||
          memo.semanticEmbeddingSource != embeddingSourceFor(memo);
    });
  }

  static List<Memo> search(
    List<Memo> memos,
    List<double> queryEmbedding, {
    double minScore = defaultMinScore,
  }) {
    final scored = <_ScoredMemo>[];
    for (final memo in memos) {
      final embedding = memo.semanticEmbedding;
      if (embedding == null || embedding.length != queryEmbedding.length) {
        continue;
      }
      final score = cosineSimilarity(queryEmbedding, embedding);
      if (score >= minScore) scored.add(_ScoredMemo(memo, score));
    }
    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final favA = a.memo.isFavorite ? 0 : 1;
      final favB = b.memo.isFavorite ? 0 : 1;
      if (favA != favB) return favA - favB;
      return b.memo.updatedAt.compareTo(a.memo.updatedAt);
    });
    return scored.map((entry) => entry.memo).toList();
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  static int _fnv1a32(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

class _ScoredMemo {
  const _ScoredMemo(this.memo, this.score);

  final Memo memo;
  final double score;
}
