import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  test('semantic embedding metadata round-trips through memo JSON', () {
    final t = DateTime(2026, 7, 9, 10);
    final memo = Memo(
      id: 'memo-1',
      content: '치과 예약',
      createdAt: t,
      updatedAt: t,
      semanticEmbedding: const [1, 0.5],
      semanticEmbeddingModel: 'gemini-embedding-001',
      semanticEmbeddingSource: 'source-key',
    );

    final decoded = Memo.fromJson(memo.toJson());

    expect(decoded.semanticEmbedding, [1.0, 0.5]);
    expect(decoded.semanticEmbeddingModel, 'gemini-embedding-001');
    expect(decoded.semanticEmbeddingSource, 'source-key');
  });

  test('legacy memo JSON without embedding fields stays readable', () {
    final memo = Memo.fromJson({
      'id': 'legacy',
      'content': '기존 메모',
      'createdAt': '2026-07-09T00:00:00.000',
      'updatedAt': '2026-07-09T00:00:00.000',
    });

    expect(memo.semanticEmbedding, isNull);
    expect(memo.toJson().containsKey('semanticEmbedding'), isFalse);
  });
}
