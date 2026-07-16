import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';

class FakeEmbeddingEngine implements EmbeddingEngine {
  FakeEmbeddingEngine({
    required this.engineId,
    required this.dimensions,
    this.capabilityValue = const EmbeddingCapability(
      supported: true,
      ready: true,
    ),
    this.failDocumentCall,
    this.failureCode = 'FAKE_EMBED_FAILURE',
  });

  @override
  final String engineId;

  @override
  final int dimensions;

  EmbeddingCapability capabilityValue;
  int? failDocumentCall;
  String failureCode;
  int capabilityCalls = 0;
  int documentCalls = 0;
  int queryCalls = 0;
  int closeCalls = 0;
  final List<List<String>> documentInputs = [];
  final List<String> queryInputs = [];

  @override
  Future<EmbeddingCapability> capability() async {
    capabilityCalls++;
    return capabilityValue;
  }

  @override
  Future<EmbeddingBatch> embedDocuments(List<String> texts) async {
    documentCalls++;
    documentInputs.add(List<String>.of(texts));
    if (documentCalls == failDocumentCall) {
      throw EmbeddingFailure(EmbeddingFailureKind.unavailable, failureCode);
    }
    return EmbeddingBatch(
      engineId: engineId,
      dimensions: dimensions,
      embeddings: texts.map(_vectorFor).toList(growable: false),
    );
  }

  @override
  Future<EmbeddingBatch> embedQuery(String text) async {
    queryCalls++;
    queryInputs.add(text);
    return EmbeddingBatch(
      engineId: engineId,
      dimensions: dimensions,
      embeddings: [_vectorFor(text)],
    );
  }

  List<double> _vectorFor(String text) {
    final values = List<double>.filled(dimensions, 0);
    final index = text.contains('카레') && dimensions > 1 ? 1 : 0;
    values[index] = 1;
    return values;
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
