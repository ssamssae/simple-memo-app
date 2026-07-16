import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class XlmRobertaEncoding {
  const XlmRobertaEncoding({
    required this.ids,
    required this.attentionMask,
    required this.typeIds,
  });

  final List<int> ids;
  final List<int> attentionMask;
  final List<int> typeIds;
}

class XlmRobertaSentencePiece {
  XlmRobertaSentencePiece._(this._tokenizer, this.maxLength);

  static const bosId = 0;
  static const padId = 1;
  static const eosId = 2;
  static const unkId = 3;

  final SentencePieceTokenizer _tokenizer;
  final int maxLength;

  static Future<XlmRobertaSentencePiece> fromModelFile(
    String path, {
    required int maxLength,
  }) async {
    if (maxLength < 3) {
      throw ArgumentError.value(maxLength, 'maxLength', 'must be at least 3');
    }
    final tokenizer = await SentencePieceTokenizer.fromModelFile(path);
    tokenizer
      ..enableTruncation(maxLength: maxLength - 2)
      ..noPadding();
    return XlmRobertaSentencePiece._(tokenizer, maxLength);
  }

  XlmRobertaEncoding encode(String text) {
    final normalized = normalizeNmtNfkc(text);
    final sentencePiece = _tokenizer.encode(
      normalized,
      addSpecialTokens: false,
    );
    final contentIds = sentencePiece.ids.map(sentencePieceIdToXlmRobertaId);
    final unpadded = <int>[bosId, ...contentIds, eosId];
    if (unpadded.length > maxLength) {
      throw StateError('SentencePiece truncation exceeded the XLM-R limit');
    }
    final attentionLength = unpadded.length;
    final ids = <int>[
      ...unpadded,
      ...List<int>.filled(maxLength - attentionLength, padId),
    ];
    return XlmRobertaEncoding(
      ids: ids,
      attentionMask: <int>[
        ...List<int>.filled(attentionLength, 1),
        ...List<int>.filled(maxLength - attentionLength, 0),
      ],
      typeIds: List<int>.filled(maxLength, 0),
    );
  }

  static int sentencePieceIdToXlmRobertaId(int id) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'must not be negative');
    }
    return id == 0 ? unkId : id + 1;
  }

  // The pinned XLM-R tokenizers use SentencePiece's nmt_nfkc charsmap. Applying
  // NFKC per scalar preserves decomposed Hangul while handling compatibility
  // characters. The fixed parity corpus guards this adapter against drift.
  static String normalizeNmtNfkc(String text) {
    final withoutControls = text.replaceAll(
      RegExp(r'[\u0001-\u0008\u000B\u000E-\u001F\u007F\u008F\u009F]'),
      '',
    );
    final normalizedSpaces = withoutControls.replaceAll(
      RegExp(
        r'[\u0009\u000A\u000C\u000D\u00A0\u1680\u2000-\u200F'
        r'\u2028\u2029\u202F\u205F\u2581\u3000\uFEFF\uFFFD]',
      ),
      ' ',
    );
    return normalizedSpaces.runes.map((rune) {
      if (rune == 0xFF5E) return String.fromCharCode(rune);
      return unorm.nfkc(String.fromCharCode(rune));
    }).join();
  }
}
