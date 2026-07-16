import 'package:flutter/services.dart';

import 'embedding_engine.dart';
import 'mini_lm_model_installer.dart';
import 'mini_lm_model_manifest.dart';
import 'mini_lm_runtime.dart';
import 'xlm_roberta_sentencepiece.dart';

typedef MiniLmTokenizerLoader = Future<MiniLmTokenizer> Function(String path);

class MiniLmEmbeddingEngine implements EmbeddingEngine {
  MiniLmEmbeddingEngine({
    required MiniLmModelInstaller installer,
    required MiniLmRuntime runtime,
    MiniLmTokenizerLoader? tokenizerLoader,
  }) : _installer = installer,
       _runtime = runtime,
       _tokenizerLoader =
           tokenizerLoader ??
           ((path) => XlmRobertaSentencePiece.fromModelFile(
             path,
             maxLength: MiniLmModelManifest.maxSequenceLength,
           ));

  final MiniLmModelInstaller _installer;
  final MiniLmRuntime _runtime;
  final MiniLmTokenizerLoader _tokenizerLoader;
  MiniLmTokenizer? _tokenizer;
  bool _loaded = false;

  @override
  String get engineId => MiniLmModelManifest.engineId;

  @override
  int get dimensions => MiniLmModelManifest.dimensions;

  static String prepareText(String text, EmbeddingPurpose purpose) => text;

  @override
  Future<EmbeddingCapability> capability() async {
    try {
      final supported = await _runtime.isSupported();
      if (!supported) return const EmbeddingCapability.unsupported();
      return EmbeddingCapability(
        supported: true,
        ready: await _installer.isInstalled(),
      );
    } catch (_) {
      return const EmbeddingCapability.unsupported();
    }
  }

  @override
  Future<EmbeddingBatch> embedDocuments(List<String> texts) =>
      _embed(texts, EmbeddingPurpose.document);

  @override
  Future<EmbeddingBatch> embedQuery(String text) =>
      _embed([text], EmbeddingPurpose.query);

  Future<EmbeddingBatch> _embed(
    List<String> texts,
    EmbeddingPurpose purpose,
  ) async {
    await _ensureLoaded();
    final tokenizer = _tokenizer!;
    final vectors = <List<double>>[];
    try {
      for (final text in texts) {
        final encoding = tokenizer.encode(prepareText(text, purpose));
        vectors.add(await _runtime.embed(encoding));
      }
      final batch = EmbeddingBatch(
        engineId: engineId,
        dimensions: dimensions,
        embeddings: vectors,
      );
      batch.validate(expectedCount: texts.length);
      return batch;
    } on EmbeddingFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw EmbeddingFailure(
        error.code == 'OUT_OF_MEMORY'
            ? EmbeddingFailureKind.outOfMemory
            : EmbeddingFailureKind.loadFailed,
        error.code == 'OUT_OF_MEMORY'
            ? 'MEMOYO_MINILM_OUT_OF_MEMORY'
            : 'MEMOYO_MINILM_INFERENCE_FAILED',
        error,
      );
    } catch (error) {
      throw EmbeddingFailure(
        EmbeddingFailureKind.loadFailed,
        'MEMOYO_MINILM_INFERENCE_FAILED',
        error,
      );
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (!await _runtime.isSupported()) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.unsupported,
        'MEMOYO_MINILM_UNSUPPORTED',
      );
    }
    if (!await _installer.isInstalled()) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.modelMissing,
        'MEMOYO_MINILM_MODEL_MISSING',
      );
    }
    final installed = await _installer.paths();
    try {
      _tokenizer = await _tokenizerLoader(installed.tokenizerPath);
      await _runtime.load(installed.modelPath);
      _loaded = true;
    } on PlatformException catch (error) {
      throw EmbeddingFailure(
        error.code == 'OUT_OF_MEMORY'
            ? EmbeddingFailureKind.outOfMemory
            : EmbeddingFailureKind.loadFailed,
        error.code == 'OUT_OF_MEMORY'
            ? 'MEMOYO_MINILM_OUT_OF_MEMORY'
            : 'MEMOYO_MINILM_LOAD_FAILED',
        error,
      );
    } catch (error) {
      throw EmbeddingFailure(
        EmbeddingFailureKind.loadFailed,
        'MEMOYO_MINILM_LOAD_FAILED',
        error,
      );
    }
  }

  @override
  Future<void> close() async {
    _loaded = false;
    _tokenizer = null;
    await _runtime.close();
  }
}
