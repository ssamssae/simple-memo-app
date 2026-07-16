import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoyo_embedding_stage1/model_specs.dart';

void main() {
  test('committed manifest matches the runtime model contract', () async {
    final decoded =
        jsonDecode(await File('models/model-manifest.json').readAsString())
            as Map<String, dynamic>;
    final artifacts = (decoded['artifacts'] as List)
        .cast<Map<String, dynamic>>();

    expect(artifacts, hasLength(EngineSpec.values.length));
    for (final spec in EngineSpec.values) {
      final artifact = artifacts.singleWhere(
        (entry) => entry['engine'] == spec.id,
      );
      expect(artifact['revision'], spec.revision);
      expect(
        (artifact['modelFile'] as String).split('/').last,
        spec.modelFileName,
      );
      expect(
        (artifact['tokenizerFile'] as String).split('/').last,
        spec.tokenizerFileName,
      );
      expect(artifact['modelSha256'], spec.modelSha256);
      expect(artifact['tokenizerSha256'], spec.tokenizerSha256);
      expect(artifact['license'], spec.license);
      expect(artifact['dimensions'], spec.dimensions);
      expect(artifact['maxSequenceLength'], spec.maxSequenceLength);
      expect(artifact['gated'], spec.requiresGemmaTerms);
    }
  });

  test('engine ids and artifact paths remain isolated', () {
    expect(
      EngineSpec.values.map((spec) => spec.id).toSet(),
      hasLength(EngineSpec.values.length),
    );
    expect(EngineSpec.embeddingGemma.dimensions, 768);
    expect(EngineSpec.e5.dimensions, 384);
    expect(EngineSpec.miniLm.dimensions, 384);
  });
}
