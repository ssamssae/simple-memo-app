/// 말로찾기가 쓸 엔진 정책.
///
/// ■`gemini` 가 없어진 이유 — T-260830-013
///   유료 임베딩 엔드포인트를 부르던 항목이었다. 그 백엔드는 만들어진
///   적이 없고(T-260803-038), T-260806-022 이후로는 `SemanticSearchCoordinator` 가
///   policy 가 ★명시적으로 gemini 일 때만 후보에 넣었는데 기본값은
///   `ondevice_preferred` 라 출고 빌드에서 도달할 수 없었다. 즉 선언만 남은 죽은
///   가지였고, 그 선언이 `MEMOYO_API` 를 붙들어 스토어 업로드 관문을 막고 있었다.
///
/// ■미지정 값이 이제 유료가 아니라 무료로 떨어진다
///   종전 fallback 은 `_ => gemini` 였다. 오타 하나가 과금 경로로 떨어지는 모양이라,
///   남은 둘 중 ★공짜인 온디바이스로 내린다. 유료 경로를 되살릴 생각이면 이 기본값이
///   아니라 명시 항목을 새로 만들어라(아니키 2026-08-04 「내 api 로 비용은 못내겠어」).
enum SemanticEnginePolicy {
  ondevicePreferred,
  lexical;

  static const configuredValue = String.fromEnvironment(
    'MEMOYO_SEMANTIC_ENGINE_POLICY',
    defaultValue: 'ondevice_preferred',
  );

  static SemanticEnginePolicy get configured => fromValue(configuredValue);

  static SemanticEnginePolicy fromValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'lexical' => SemanticEnginePolicy.lexical,
      _ => SemanticEnginePolicy.ondevicePreferred,
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
