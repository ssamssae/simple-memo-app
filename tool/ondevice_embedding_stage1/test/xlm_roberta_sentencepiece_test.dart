import 'package:flutter_test/flutter_test.dart';
import 'package:memoyo_embedding_stage1/xlm_roberta_sentencepiece.dart';

void main() {
  test('maps raw SentencePiece ids into XLM-R vocabulary ids', () {
    expect(XlmRobertaSentencePiece.sentencePieceIdToXlmRobertaId(0), 3);
    expect(XlmRobertaSentencePiece.sentencePieceIdToXlmRobertaId(3), 4);
    expect(
      XlmRobertaSentencePiece.sentencePieceIdToXlmRobertaId(134266),
      134267,
    );
    expect(
      () => XlmRobertaSentencePiece.sentencePieceIdToXlmRobertaId(-1),
      throwsArgumentError,
    );
  });

  test('normalizes compatibility characters without composing Hangul jamo', () {
    expect(XlmRobertaSentencePiece.normalizeNmtNfkc('ＡＢＣ ① ㎏'), 'ABC 1 kg');
    expect(XlmRobertaSentencePiece.normalizeNmtNfkc('가'), '가');
    expect(XlmRobertaSentencePiece.normalizeNmtNfkc('～'), '～');
  });

  test('applies the pinned nmt_nfkc control and whitespace rules', () {
    expect(
      XlmRobertaSentencePiece.normalizeNmtNfkc('공백\u00a0두개\u0007문자'),
      '공백 두개문자',
    );
  });
}
