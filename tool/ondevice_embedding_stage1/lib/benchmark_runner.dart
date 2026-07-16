import 'dart:io';

import 'benchmark_contract.dart';
import 'embedding_backend.dart';
import 'gemma_backend.dart';
import 'model_specs.dart';
import 'onnx_backend.dart';
import 'stage1_storage.dart';

class BenchmarkExecution {
  const BenchmarkExecution({required this.result, required this.backend});

  final BenchmarkResult result;
  final Stage1EmbeddingBackend backend;
}

class BenchmarkRunner {
  const BenchmarkRunner({required this.storage});

  final Stage1Storage storage;

  Future<BenchmarkExecution> run(Stage1Config config) async {
    final spec = config.spec;
    final startedAt = DateTime.now().toUtc();
    await storage.resetOutputs();
    await storage.writeState('verifying-artifacts', engine: spec.id);
    await storage.appendEvent('verifying-artifacts', engine: spec.id);
    await storage.verifyArtifacts(spec);
    await storage.appendEvent('artifacts-verified', engine: spec.id);

    final backend = _createBackend(spec);
    try {
      await storage.writeState('loading-model', engine: spec.id);
      final loadWatch = Stopwatch()..start();
      await backend.load();
      loadWatch.stop();
      await storage.appendEvent('model-loaded', engine: spec.id);
      await storage.writeState('cold-inference', engine: spec.id);

      final coldWatch = Stopwatch()..start();
      final coldVector = await backend.embed(
        '오늘 해야 할 중요한 일을 찾아줘',
        purpose: EmbeddingPurpose.query,
      );
      coldWatch.stop();
      _validateVector(coldVector, spec);

      await storage.writeState('warm-inference', engine: spec.id);
      final warmSamples = <double>[];
      for (var index = 0; index < 5; index++) {
        final watch = Stopwatch()..start();
        final vector = await backend.embed(
          '장보기 메모를 찾아줘',
          purpose: EmbeddingPurpose.query,
        );
        watch.stop();
        _validateVector(vector, spec);
        warmSamples.add(_milliseconds(watch));
      }

      await storage.writeState('reindexing-100', engine: spec.id);
      await storage.appendEvent('reindexing-100', engine: spec.id);
      final memos = buildSyntheticMemos();
      final reindexWatch = Stopwatch()..start();
      for (final memo in memos) {
        final vector = await backend.embed(
          memo,
          purpose: EmbeddingPurpose.document,
        );
        _validateVector(vector, spec);
      }
      reindexWatch.stop();

      final result = BenchmarkResult(
        spec: spec,
        startedAtUtc: startedAt,
        completedAtUtc: DateTime.now().toUtc(),
        platform:
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        coldModelLoadMs: _milliseconds(loadWatch),
        coldFirstInferenceMs: _milliseconds(coldWatch),
        warmInferenceSamplesMs: warmSamples,
        reindex100Ms: _milliseconds(reindexWatch),
        dimensions: coldVector.length,
      );
      await storage.writeResult(result.toJson());
      await storage.writeState('complete', engine: spec.id);
      await storage.appendEvent('complete', engine: spec.id);
      return BenchmarkExecution(result: result, backend: backend);
    } catch (_) {
      await backend.close();
      rethrow;
    }
  }

  Stage1EmbeddingBackend _createBackend(EngineSpec spec) {
    final modelPath = storage.modelFile(spec).path;
    final tokenizerPath = storage.tokenizerFile(spec).path;
    return switch (spec.engine) {
      Stage1Engine.embeddingGemmaSeq512 => GemmaEmbeddingBackend(
        modelPath: modelPath,
        tokenizerPath: tokenizerPath,
      ),
      _ => OnnxEmbeddingBackend(
        spec: spec,
        modelPath: modelPath,
        tokenizerPath: tokenizerPath,
      ),
    };
  }

  void _validateVector(List<double> vector, EngineSpec spec) {
    if (vector.length != spec.dimensions) {
      throw FormatException(
        '${spec.id} returned ${vector.length}D, expected ${spec.dimensions}D',
      );
    }
    if (vector.any((value) => !value.isFinite)) {
      throw const FormatException('Embedding contains a non-finite value');
    }
  }

  double _milliseconds(Stopwatch watch) {
    return double.parse((watch.elapsedMicroseconds / 1000).toStringAsFixed(3));
  }
}
