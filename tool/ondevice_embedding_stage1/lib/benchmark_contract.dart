import 'dart:math' as math;

import 'model_specs.dart';

const stage1ResultSchema = 1;

List<String> buildSyntheticMemos() {
  const topics = [
    '장보기',
    '회의',
    '운동',
    '독서',
    '여행',
    '요리',
    '정리',
    '학습',
    '가족',
    '아이디어',
  ];
  const details = [
    '우유와 달걀을 잊지 말기',
    '다음 행동과 담당자를 적기',
    '가볍게 몸을 풀고 기록하기',
    '핵심 문장을 한 줄로 요약하기',
    '시간과 이동 경로를 확인하기',
    '재료의 양과 순서를 남기기',
    '필요한 것과 버릴 것을 나누기',
    '모르는 개념을 예시로 설명하기',
    '함께 할 약속을 달력에 적기',
    '작은 실험으로 먼저 확인하기',
  ];
  return List<String>.generate(100, (index) {
    final topic = topics[index % topics.length];
    final detail = details[(index * 3) % details.length];
    return '${index + 1}번 $topic 메모: $detail. 완료 후 결과를 다시 확인한다.';
  }, growable: false);
}

List<double> l2Normalize(List<double> values) {
  var squared = 0.0;
  for (final value in values) {
    squared += value * value;
  }
  if (squared == 0 || !squared.isFinite) {
    throw const FormatException('Embedding norm must be finite and non-zero');
  }
  final norm = math.sqrt(squared);
  return values.map((value) => value / norm).toList(growable: false);
}

List<double> meanPoolOnnxOutput({
  required List<num> flattened,
  required List<int> shape,
  required List<int> attentionMask,
}) {
  if (shape.length == 2 && shape.first == 1) {
    final dimensions = shape[1];
    if (flattened.length != dimensions) {
      throw const FormatException('Unexpected rank-2 ONNX output size');
    }
    return l2Normalize(
      flattened.map((value) => value.toDouble()).toList(growable: false),
    );
  }
  if (shape.length != 3 || shape.first != 1) {
    throw FormatException('Unsupported ONNX output shape: $shape');
  }
  final sequenceLength = shape[1];
  final dimensions = shape[2];
  if (attentionMask.length != sequenceLength ||
      flattened.length != sequenceLength * dimensions) {
    throw const FormatException('ONNX output and attention mask disagree');
  }
  final pooled = List<double>.filled(dimensions, 0);
  var tokenCount = 0;
  for (var token = 0; token < sequenceLength; token++) {
    if (attentionMask[token] == 0) continue;
    tokenCount++;
    final offset = token * dimensions;
    for (var dimension = 0; dimension < dimensions; dimension++) {
      pooled[dimension] += flattened[offset + dimension].toDouble();
    }
  }
  if (tokenCount == 0) {
    throw const FormatException('Cannot pool an empty attention mask');
  }
  for (var dimension = 0; dimension < dimensions; dimension++) {
    pooled[dimension] /= tokenCount;
  }
  return l2Normalize(pooled);
}

double medianMilliseconds(List<double> samples) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples, 'samples', 'must not be empty');
  }
  final sorted = [...samples]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

class BenchmarkResult {
  const BenchmarkResult({
    required this.spec,
    required this.startedAtUtc,
    required this.completedAtUtc,
    required this.platform,
    required this.coldModelLoadMs,
    required this.coldFirstInferenceMs,
    required this.warmInferenceSamplesMs,
    required this.reindex100Ms,
    required this.dimensions,
  });

  final EngineSpec spec;
  final DateTime startedAtUtc;
  final DateTime completedAtUtc;
  final String platform;
  final double coldModelLoadMs;
  final double coldFirstInferenceMs;
  final List<double> warmInferenceSamplesMs;
  final double reindex100Ms;
  final int dimensions;

  Map<String, Object?> toJson() => {
    'schemaVersion': stage1ResultSchema,
    'task': 'T-260713-55',
    'engine': spec.id,
    'revision': spec.revision,
    'license': spec.license,
    'modelSha256': spec.modelSha256,
    'tokenizerSha256': spec.tokenizerSha256,
    'startedAtUtc': startedAtUtc.toIso8601String(),
    'completedAtUtc': completedAtUtc.toIso8601String(),
    'platform': platform,
    'coldModelLoadMs': coldModelLoadMs,
    'coldFirstInferenceMs': coldFirstInferenceMs,
    'warmInferenceSamplesMs': warmInferenceSamplesMs,
    'warmInferenceMedianMs': medianMilliseconds(warmInferenceSamplesMs),
    'reindex100Ms': reindex100Ms,
    'memoCount': 100,
    'dimensions': dimensions,
    'maxSequenceLength': spec.maxSequenceLength,
  };
}
