import 'package:flutter/services.dart';

import 'xlm_roberta_sentencepiece.dart';

abstract interface class MiniLmRuntime {
  Future<bool> isSupported();

  Future<int> availableBytes(String directoryPath);

  Future<void> load(String modelPath);

  Future<List<double>> embed(XlmRobertaEncoding encoding);

  Future<void> close();
}

class MethodChannelMiniLmRuntime implements MiniLmRuntime {
  MethodChannelMiniLmRuntime({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('memoyo/minilm');

  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  @override
  Future<int> availableBytes(String directoryPath) async =>
      await _channel.invokeMethod<int>('availableBytes', {
        'directoryPath': directoryPath,
      }) ??
      0;

  @override
  Future<void> load(String modelPath) =>
      _channel.invokeMethod<void>('load', {'modelPath': modelPath});

  @override
  Future<List<double>> embed(XlmRobertaEncoding encoding) async {
    final values = await _channel.invokeListMethod<num>('embed', {
      'inputIds': encoding.ids,
      'attentionMask': encoding.attentionMask,
      'tokenTypeIds': encoding.typeIds,
    });
    if (values == null) {
      throw const FormatException('MiniLM runtime returned no vector');
    }
    return values.map((value) => value.toDouble()).toList(growable: false);
  }

  @override
  Future<void> close() => _channel.invokeMethod<void>('close');
}
