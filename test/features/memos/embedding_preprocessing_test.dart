// T-260830-013 — Gemini(유료 Worker) 전처리 골든은 함께 삭제됐다.
// 그 엔진·클라이언트가 lib/ 에서 철거돼 검증 대상 자체가 없어졌기 때문이다.
// 남은 온디바이스(MiniLM) 전처리 골든이 지금 유일한 임베딩 경로의 계약이다.
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
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
}
