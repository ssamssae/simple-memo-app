import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class MiniLmArtifact {
  const MiniLmArtifact({
    required this.name,
    required this.repositoryPath,
    required this.size,
    required this.sha256,
    this.downloadUriOverride,
  });

  final String name;
  final String repositoryPath;
  final int size;
  final String sha256;
  final Uri? downloadUriOverride;

  Uri get downloadUri =>
      downloadUriOverride ??
      Uri.https(
        'huggingface.co',
        '/${MiniLmModelManifest.repository}/resolve/'
            '${MiniLmModelManifest.revision}/$repositoryPath',
        const {'download': 'true'},
      );
}

class MiniLmModelManifest {
  const MiniLmModelManifest._();

  static const assetPath = 'assets/models/minilm-model-manifest.json';
  static const assetSha256 =
      'f8b16d8a6ac82bd2654831d72720a185a44b177e9a9df3fa090deb1152ff0c06';
  static const engine = 'paraphrase_multilingual_minilm_onnx';
  static const repository =
      'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2';
  static const revision = 'e8f8c211226b894fcb81acc59f3b34ba3efd5f42';
  static const license = 'Apache-2.0';
  static const dimensions = 384;
  static const maxSequenceLength = 128;
  static const preprocessing = 'xlmr-nmt-nfkc-v1';

  static const model = MiniLmArtifact(
    name: 'model_qint8_arm64.onnx',
    repositoryPath: 'onnx/model_qint8_arm64.onnx',
    size: 118412398,
    sha256: '783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672',
  );
  static const tokenizer = MiniLmArtifact(
    name: 'sentencepiece.bpe.model',
    repositoryPath: 'sentencepiece.bpe.model',
    size: 5069051,
    sha256: 'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865',
  );
  static const artifacts = [model, tokenizer];
  static const totalDownloadBytes = 123481449;

  // This ID deliberately includes every vector-space input. A shorter display
  // label must never be persisted in semanticEmbeddingModel.
  static const engineId =
      'paraphrase_multilingual_minilm_onnx@'
      'e8f8c211226b894fcb81acc59f3b34ba3efd5f42+'
      'model.sha256:'
      '783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672+'
      'tokenizer.sha256:'
      'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865+'
      'preprocess:xlmr-nmt-nfkc-v1+dim:384';

  /// The manifest is bundled inside the signed application and pinned again by
  /// digest in compiled code. Downloaded artifacts are independently checked.
  static Future<void> verifyBundled({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    if (sha256.convert(utf8.encode(source)).toString() != assetSha256) {
      throw const FormatException('MiniLM manifest signature digest mismatch');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('MiniLM manifest must be a JSON object');
    }
    _validateJson(decoded);
  }

  static void _validateJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['trust'] != 'bundled-in-app-signature' ||
        json['engine'] != engine ||
        json['repository'] != repository ||
        json['revision'] != revision ||
        json['license'] != license ||
        json['dimensions'] != dimensions ||
        json['maxSequenceLength'] != maxSequenceLength ||
        json['preprocessing'] != preprocessing) {
      throw const FormatException('MiniLM manifest contract mismatch');
    }
    final rawArtifacts = json['artifacts'];
    if (rawArtifacts is! List || rawArtifacts.length != artifacts.length) {
      throw const FormatException('MiniLM artifact manifest mismatch');
    }
    for (var index = 0; index < artifacts.length; index++) {
      final raw = rawArtifacts[index];
      final expected = artifacts[index];
      if (raw is! Map<String, dynamic> ||
          raw['name'] != expected.name ||
          raw['path'] != expected.repositoryPath ||
          raw['size'] != expected.size ||
          raw['sha256'] != expected.sha256) {
        throw const FormatException('MiniLM artifact pin mismatch');
      }
    }
  }
}
