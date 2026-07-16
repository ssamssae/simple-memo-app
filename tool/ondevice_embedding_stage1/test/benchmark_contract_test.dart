import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:memoyo_embedding_stage1/benchmark_contract.dart';
import 'package:memoyo_embedding_stage1/model_specs.dart';

void main() {
  test('benchmark corpus is deterministic, unique, and exactly 100 memos', () {
    final first = buildSyntheticMemos();
    final second = buildSyntheticMemos();

    expect(first, second);
    expect(first, hasLength(100));
    expect(first.toSet(), hasLength(100));
  });

  test('mean pooling ignores padding and L2-normalizes the vector', () {
    final pooled = meanPoolOnnxOutput(
      flattened: const [3, 4, 0, 8, 100, 100],
      shape: const [1, 3, 2],
      attentionMask: const [1, 1, 0],
    );

    final rawX = 1.5;
    final rawY = 6.0;
    final norm = math.sqrt(rawX * rawX + rawY * rawY);
    expect(pooled[0], closeTo(rawX / norm, 1e-12));
    expect(pooled[1], closeTo(rawY / norm, 1e-12));
  });

  test('rank-2 sentence embedding is normalized without token pooling', () {
    expect(
      meanPoolOnnxOutput(
        flattened: const [3, 4],
        shape: const [1, 2],
        attentionMask: const [1],
      ),
      orderedEquals(const [0.6, 0.8]),
    );
  });

  test('E5 prefixes query and document inputs but MiniLM does not', () {
    expect(
      EngineSpec.e5.prepareOnnxText('메모', EmbeddingPurpose.query),
      'query: 메모',
    );
    expect(
      EngineSpec.e5.prepareOnnxText('메모', EmbeddingPurpose.document),
      'passage: 메모',
    );
    expect(
      EngineSpec.miniLm.prepareOnnxText('메모', EmbeddingPurpose.document),
      '메모',
    );
  });

  test('Gemma config fails closed without prior terms attestation', () {
    expect(
      () => Stage1Config.fromJson(const {
        'engine': 'embeddinggemma_seq512',
        'gemmaTermsAccepted': false,
      }),
      throwsFormatException,
    );
    final config = Stage1Config.fromJson(const {
      'engine': 'embeddinggemma_seq512',
      'gemmaTermsAccepted': true,
    });
    expect(config.spec, same(EngineSpec.embeddingGemma));
  });

  test('warm median handles odd and even sample counts', () {
    expect(medianMilliseconds(const [3, 1, 2]), 2);
    expect(medianMilliseconds(const [4, 1, 3, 2]), 2.5);
  });
}
