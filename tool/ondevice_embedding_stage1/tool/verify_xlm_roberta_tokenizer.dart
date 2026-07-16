import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:memoyo_embedding_stage1/benchmark_contract.dart';
import 'package:memoyo_embedding_stage1/model_specs.dart';
import 'package:memoyo_embedding_stage1/xlm_roberta_sentencepiece.dart';

const fixtures = <String, List<int>>{
  'query: 장보기 메모를 찾아줘': [
    0,
    41,
    1294,
    12,
    11619,
    61688,
    33004,
    7923,
    688,
    40109,
    134267,
    2,
  ],
  'passage: 우유와 장보기 메모: 두부 1모, 달걀 10개': [
    0,
    46692,
    12,
    23526,
    6943,
    2020,
    11619,
    61688,
    33004,
    7923,
    12,
    11385,
    3614,
    106,
    7923,
    4,
    25718,
    249749,
    209,
    6027,
    2,
  ],
  'ＡＢＣ ① ㎏': [0, 47457, 106, 5279, 2],
  '가나와 가나': [0, 6, 244134, 246073, 244197, 246073, 2020, 6081, 3497, 2],
  '공백\u00a0두개  사이': [0, 9045, 23527, 11385, 6027, 62657, 2],
  '물결～표시': [0, 22114, 25354, 6087, 21244, 2166, 2],
  '제어\u0007문자': [0, 6600, 2211, 8247, 2268, 2],
};

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || !const {'e5', 'minilm'}.contains(arguments[1])) {
    stderr.writeln(
      'Usage: verify_xlm_roberta_tokenizer.dart MODEL_FILE e5|minilm',
    );
    exitCode = 2;
    return;
  }
  final engine = arguments[1];
  final spec = engine == 'e5' ? EngineSpec.e5 : EngineSpec.miniLm;
  final tokenizer = await XlmRobertaSentencePiece.fromModelFile(
    arguments.first,
    maxLength: spec.maxSequenceLength,
  );
  for (final fixture in fixtures.entries) {
    final encoded = tokenizer.encode(fixture.key);
    final actual = encoded.ids
        .takeWhile((id) => id != XlmRobertaSentencePiece.padId)
        .toList(growable: false);
    if (!_equal(actual, fixture.value)) {
      stderr.writeln('Tokenizer parity mismatch for ${fixture.key}');
      stderr.writeln('expected=${fixture.value}');
      stderr.writeln('actual=$actual');
      exitCode = 1;
      return;
    }
  }
  final benchmarkTexts = <(String, EmbeddingPurpose)>[
    ('오늘 해야 할 중요한 일을 찾아줘', EmbeddingPurpose.query),
    ('장보기 메모를 찾아줘', EmbeddingPurpose.query),
    ...buildSyntheticMemos().map((memo) => (memo, EmbeddingPurpose.document)),
  ];
  final corpus = benchmarkTexts
      .map((entry) {
        final text = spec.prepareOnnxText(entry.$1, entry.$2);
        return tokenizer
            .encode(text)
            .ids
            .takeWhile((id) => id != XlmRobertaSentencePiece.padId)
            .join(',');
      })
      .join('\n');
  final actualDigest = sha256.convert(utf8.encode(corpus)).toString();
  final expectedDigest = engine == 'e5'
      ? '29801e0ead5d93b830261fb7af36519c82dee881f3239c6714dc9755f524bbc1'
      : 'eeb7b725f80e2c14abe92dc0df942daf3f14856c53b249108180715efbee5e74';
  if (actualDigest != expectedDigest) {
    stderr.writeln('Tokenizer benchmark-corpus parity mismatch for $engine');
    stderr.writeln('expected=$expectedDigest');
    stderr.writeln('actual=$actualDigest');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Tokenizer parity PASS: ${fixtures.length} fixtures + '
    '${benchmarkTexts.length} benchmark inputs ($engine $actualDigest)',
  );
}

bool _equal(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
