enum SemanticEnginePolicy {
  gemini,
  ondevicePreferred,
  lexical;

  static const configuredValue = String.fromEnvironment(
    'MEMOYO_SEMANTIC_ENGINE_POLICY',
    defaultValue: 'ondevice_preferred',
  );

  static SemanticEnginePolicy get configured => fromValue(configuredValue);

  static SemanticEnginePolicy fromValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'ondevice_preferred' => SemanticEnginePolicy.ondevicePreferred,
      'lexical' => SemanticEnginePolicy.lexical,
      _ => SemanticEnginePolicy.gemini,
    };
  }
}

enum EmbeddingPurpose { query, document }

enum EmbeddingFailureKind {
  unsupported,
  modelMissing,
  insufficientSpace,
  downloadFailed,
  hashMismatch,
  loadFailed,
  outOfMemory,
  invalidResponse,
  unavailable,
}

class EmbeddingFailure implements Exception {
  const EmbeddingFailure(this.kind, this.code, [this.cause]);

  final EmbeddingFailureKind kind;
  final String code;
  final Object? cause;

  @override
  String toString() => 'EmbeddingFailure($kind, $code)';
}

class EmbeddingCapability {
  const EmbeddingCapability({required this.supported, required this.ready});

  const EmbeddingCapability.unsupported() : supported = false, ready = false;

  final bool supported;
  final bool ready;
}

class EmbeddingBatch {
  EmbeddingBatch({
    required this.engineId,
    required this.dimensions,
    required List<List<double>> embeddings,
  }) : embeddings = embeddings
           .map((vector) => List<double>.unmodifiable(vector))
           .toList(growable: false);

  final String engineId;
  final int dimensions;
  final List<List<double>> embeddings;

  void validate({required int expectedCount}) {
    if (engineId.isEmpty ||
        dimensions <= 0 ||
        embeddings.length != expectedCount) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.invalidResponse,
        'MEMOYO_EMBEDDING_RESPONSE_INVALID',
      );
    }
    for (final vector in embeddings) {
      if (vector.length != dimensions ||
          vector.any((value) => !value.isFinite)) {
        throw const EmbeddingFailure(
          EmbeddingFailureKind.invalidResponse,
          'MEMOYO_EMBEDDING_VECTOR_INVALID',
        );
      }
    }
  }
}

abstract interface class EmbeddingEngine {
  String get engineId;

  int get dimensions;

  Future<EmbeddingCapability> capability();

  Future<EmbeddingBatch> embedDocuments(List<String> texts);

  Future<EmbeddingBatch> embedQuery(String text);

  Future<void> close();
}
