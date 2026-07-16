import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/gemini_embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/xlm_roberta_sentencepiece.dart';

void main() {
  test('MiniLM query/document preprocessing golden stays role-neutral', () {
    const text = 'ＡＢＣ\u00a0① 가 ～';
    expect(
      MiniLmEmbeddingEngine.prepareText(text, EmbeddingPurpose.query),
      text,
    );
    expect(
      MiniLmEmbeddingEngine.prepareText(text, EmbeddingPurpose.document),
      text,
    );
    expect(XlmRobertaSentencePiece.normalizeNmtNfkc(text), 'ABC 1 가 ～');
    expect(XlmRobertaSentencePiece.sentencePieceIdToXlmRobertaId(0), 3);
    expect(XlmRobertaSentencePiece.sentencePieceIdToXlmRobertaId(42), 43);
  });

  test(
    'Gemini query/document preprocessing preserves exact Worker text',
    () async {
      final payloads = <List<String>>[];
      final client = MemoyoEmbeddingClient(
        transport: (_, payload) async {
          final texts = (payload['texts'] as List).cast<String>();
          payloads.add(texts);
          return {
            'model': 'gemini-embedding-001',
            'dimensions': 2,
            'embeddings': texts.map((_) => [1.0, 0.0]).toList(),
          };
        },
      );
      final engine = GeminiEmbeddingEngine(client: client, userId: 'test-user');

      await engine.embedQuery(' query 그대로 ');
      await engine.embedDocuments(['문서 그대로', 'second document']);

      expect(payloads, [
        [' query 그대로 '],
        ['문서 그대로', 'second document'],
      ]);
    },
  );
}
