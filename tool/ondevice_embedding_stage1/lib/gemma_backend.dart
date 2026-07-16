import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';

import 'embedding_backend.dart';
import 'model_specs.dart';

class GemmaEmbeddingBackend implements Stage1EmbeddingBackend {
  GemmaEmbeddingBackend({required this.modelPath, required this.tokenizerPath});

  final String modelPath;
  final String tokenizerPath;
  EmbeddingModel? _model;

  @override
  Future<void> load() async {
    await FlutterGemma.initialize(
      embeddingBackends: const [LiteRtEmbeddingBackend()],
    );
    _model = await FlutterGemmaPlugin.instance.createEmbeddingModel(
      modelPath: modelPath,
      tokenizerPath: tokenizerPath,
    );
  }

  @override
  Future<List<double>> embed(
    String text, {
    required EmbeddingPurpose purpose,
  }) async {
    final model = _model;
    if (model == null) throw StateError('EmbeddingGemma is not loaded');
    return model.generateEmbedding(
      text,
      taskType: purpose == EmbeddingPurpose.query
          ? TaskType.retrievalQuery
          : TaskType.retrievalDocument,
    );
  }

  @override
  Future<void> close() async {
    final model = _model;
    _model = null;
    await model?.close();
  }
}
