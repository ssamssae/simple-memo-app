import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'benchmark_contract.dart';
import 'embedding_backend.dart';
import 'model_specs.dart';
import 'xlm_roberta_sentencepiece.dart';

class OnnxEmbeddingBackend implements Stage1EmbeddingBackend {
  OnnxEmbeddingBackend({
    required this.spec,
    required this.modelPath,
    required this.tokenizerPath,
  });

  final EngineSpec spec;
  final String modelPath;
  final String tokenizerPath;
  OrtSession? _session;
  XlmRobertaSentencePiece? _tokenizer;

  @override
  Future<void> load() async {
    final tokenizer = await XlmRobertaSentencePiece.fromModelFile(
      tokenizerPath,
      maxLength: spec.maxSequenceLength,
    );
    _tokenizer = tokenizer;
    _session = await OnnxRuntime().createSession(
      modelPath,
      options: OrtSessionOptions(
        intraOpNumThreads: 2,
        interOpNumThreads: 1,
        providers: const [OrtProvider.CPU],
        useArena: true,
      ),
    );
  }

  @override
  Future<List<double>> embed(
    String text, {
    required EmbeddingPurpose purpose,
  }) async {
    final session = _session;
    final tokenizer = _tokenizer;
    if (session == null || tokenizer == null) {
      throw StateError('ONNX embedding backend is not loaded');
    }

    final preparedText = spec.prepareOnnxText(text, purpose);
    final encoding = tokenizer.encode(preparedText);
    final shape = [1, encoding.ids.length];
    final inputs = <String, OrtValue>{};
    final outputs = <String, OrtValue>{};
    try {
      if (session.inputNames.contains('input_ids')) {
        inputs['input_ids'] = await OrtValue.fromList(
          Int64List.fromList(encoding.ids),
          shape,
        );
      }
      if (session.inputNames.contains('attention_mask')) {
        inputs['attention_mask'] = await OrtValue.fromList(
          Int64List.fromList(encoding.attentionMask),
          shape,
        );
      }
      if (session.inputNames.contains('token_type_ids')) {
        inputs['token_type_ids'] = await OrtValue.fromList(
          Int64List.fromList(encoding.typeIds),
          shape,
        );
      }
      final missing = session.inputNames
          .where((name) => !inputs.containsKey(name))
          .toList(growable: false);
      if (missing.isNotEmpty) {
        throw StateError('Unsupported ONNX inputs: ${missing.join(', ')}');
      }
      outputs.addAll(await session.run(inputs));
      final output = _selectOutput(outputs, session.outputNames);
      final flattened = await output.asFlattenedList();
      if (flattened.any((value) => value is! num)) {
        throw const FormatException('ONNX embedding output must be numeric');
      }
      return meanPoolOnnxOutput(
        flattened: flattened.cast<num>(),
        shape: output.shape,
        attentionMask: encoding.attentionMask,
      );
    } finally {
      for (final value in inputs.values) {
        await value.dispose();
      }
      for (final value in outputs.values) {
        await value.dispose();
      }
    }
  }

  OrtValue _selectOutput(
    Map<String, OrtValue> outputs,
    List<String> outputNames,
  ) {
    for (final name in const [
      'sentence_embedding',
      'last_hidden_state',
      'token_embeddings',
    ]) {
      final output = outputs[name];
      if (output != null) return output;
    }
    for (final name in outputNames) {
      final output = outputs[name];
      if (output != null) return output;
    }
    throw StateError('ONNX session returned no outputs');
  }

  @override
  Future<void> close() async {
    final session = _session;
    _session = null;
    _tokenizer = null;
    await session?.close();
  }
}
