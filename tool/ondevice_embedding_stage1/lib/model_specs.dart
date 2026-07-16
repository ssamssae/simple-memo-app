enum Stage1Engine {
  embeddingGemmaSeq512,
  multilingualE5SmallOnnx,
  paraphraseMultilingualMiniLmOnnx,
}

class EngineSpec {
  const EngineSpec({
    required this.engine,
    required this.id,
    required this.modelFileName,
    required this.tokenizerFileName,
    required this.modelSha256,
    required this.tokenizerSha256,
    required this.revision,
    required this.license,
    required this.dimensions,
    required this.maxSequenceLength,
    required this.requiresGemmaTerms,
  });

  final Stage1Engine engine;
  final String id;
  final String modelFileName;
  final String tokenizerFileName;
  final String modelSha256;
  final String tokenizerSha256;
  final String revision;
  final String license;
  final int dimensions;
  final int maxSequenceLength;
  final bool requiresGemmaTerms;

  String prepareOnnxText(String text, EmbeddingPurpose purpose) {
    if (engine != Stage1Engine.multilingualE5SmallOnnx) return text;
    return purpose == EmbeddingPurpose.query
        ? 'query: $text'
        : 'passage: $text';
  }

  static const embeddingGemma = EngineSpec(
    engine: Stage1Engine.embeddingGemmaSeq512,
    id: 'embeddinggemma_seq512',
    modelFileName: 'embeddinggemma-300M_seq512_mixed-precision.tflite',
    tokenizerFileName: 'sentencepiece.model',
    modelSha256:
        'ad09e81557203cb0e177abf9bf8727dfe138a7d394aa0f70f0b2ed16432e121a',
    tokenizerSha256:
        'd6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7',
    revision: '870cbe05ef460385363c6b574c851ae5d8989ce3',
    license: 'Gemma Terms of Use',
    dimensions: 768,
    maxSequenceLength: 512,
    requiresGemmaTerms: true,
  );

  static const e5 = EngineSpec(
    engine: Stage1Engine.multilingualE5SmallOnnx,
    id: 'multilingual_e5_small_onnx',
    modelFileName: 'model.onnx',
    tokenizerFileName: 'sentencepiece.bpe.model',
    modelSha256:
        'ca456c06b3a9505ddfd9131408916dd79290368331e7d76bb621f1cba6bc8665',
    tokenizerSha256:
        'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865',
    revision: '614241f622f53c4eeff9890bdc4f31cfecc418b3',
    license: 'MIT',
    dimensions: 384,
    maxSequenceLength: 512,
    requiresGemmaTerms: false,
  );

  static const miniLm = EngineSpec(
    engine: Stage1Engine.paraphraseMultilingualMiniLmOnnx,
    id: 'paraphrase_multilingual_minilm_onnx',
    modelFileName: 'model_qint8_arm64.onnx',
    tokenizerFileName: 'sentencepiece.bpe.model',
    modelSha256:
        '783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672',
    tokenizerSha256:
        'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865',
    revision: 'e8f8c211226b894fcb81acc59f3b34ba3efd5f42',
    license: 'Apache-2.0',
    dimensions: 384,
    maxSequenceLength: 128,
    requiresGemmaTerms: false,
  );

  static const values = [embeddingGemma, e5, miniLm];

  static EngineSpec byId(String id) {
    return values.firstWhere(
      (spec) => spec.id == id,
      orElse: () => throw FormatException('Unsupported stage1 engine: $id'),
    );
  }
}

enum EmbeddingPurpose { query, document }

class Stage1Config {
  const Stage1Config({required this.spec, required this.gemmaTermsAccepted});

  final EngineSpec spec;
  final bool gemmaTermsAccepted;

  factory Stage1Config.fromJson(Map<String, Object?> json) {
    final engineId = json['engine'];
    if (engineId is! String) {
      throw const FormatException('config.engine must be a string');
    }
    final spec = EngineSpec.byId(engineId);
    final termsAccepted = json['gemmaTermsAccepted'] == true;
    if (spec.requiresGemmaTerms && !termsAccepted) {
      throw const FormatException(
        'EmbeddingGemma requires a prior Gemma terms acceptance attestation',
      );
    }
    return Stage1Config(spec: spec, gemmaTermsAccepted: termsAccepted);
  }
}
