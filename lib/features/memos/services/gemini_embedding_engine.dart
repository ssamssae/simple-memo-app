import 'embedding_engine.dart';
import 'memoyo_embedding_client.dart';
import 'semantic_search_service.dart';

class GeminiEmbeddingEngine implements EmbeddingEngine {
  GeminiEmbeddingEngine({
    required MemoyoEmbeddingClient client,
    required String userId,
  }) : _client = client,
       _userId = userId;

  final MemoyoEmbeddingClient _client;
  final String _userId;

  @override
  String get engineId => SemanticSearchService.geminiModel;

  // The Worker owns the output dimension. Each response is validated before it
  // reaches the index, so this value is only an engine declaration sentinel.
  @override
  int get dimensions => 0;

  @override
  Future<EmbeddingCapability> capability() async =>
      const EmbeddingCapability(supported: true, ready: true);

  @override
  Future<EmbeddingBatch> embedDocuments(List<String> texts) => _embed(texts);

  @override
  Future<EmbeddingBatch> embedQuery(String text) => _embed([text]);

  Future<EmbeddingBatch> _embed(List<String> texts) async {
    try {
      final result = await _client.embedTexts(userId: _userId, texts: texts);
      final batch = EmbeddingBatch(
        engineId: result.model,
        dimensions: result.dimensions,
        embeddings: result.embeddings,
      );
      batch.validate(expectedCount: texts.length);
      if (batch.engineId != engineId) {
        throw const EmbeddingFailure(
          EmbeddingFailureKind.invalidResponse,
          'MEMOYO_GEMINI_MODEL_MISMATCH',
        );
      }
      return batch;
    } on MemoyoEmbeddingFallbackException catch (error) {
      throw EmbeddingFailure(
        EmbeddingFailureKind.unavailable,
        error.code,
        error,
      );
    } on EmbeddingFailure {
      rethrow;
    } catch (error) {
      throw EmbeddingFailure(
        EmbeddingFailureKind.unavailable,
        'MEMOYO_GEMINI_UNAVAILABLE',
        error,
      );
    }
  }

  @override
  Future<void> close() async {}
}
