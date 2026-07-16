import 'model_specs.dart';

abstract interface class Stage1EmbeddingBackend {
  Future<void> load();

  Future<List<double>> embed(String text, {required EmbeddingPurpose purpose});

  Future<void> close();
}
