// MiniLM 실기기 스모크 + 크로스플랫폼 parity 하네스 (T-260722-106 / T-260722-107).
//
// 한 파일로 iOS·Android 양쪽에서 같은 픽스처를 돌리고 결과를 stdout 에 JSON 한 줄로 뱉는다.
//
// 실행:
//   flutter test integration_test/mini_lm_parity_test.dart -d <deviceId>
//
// capability 게이트는 호스트 메모리를 쓰는 시뮬레이터/에뮬레이터에서 무효하므로 실기기에서만 의미가 있다.
//
// ── 현재 상태 (정직하게) ────────────────────────────────────────────────
// [x] capability 게이트 + availableBytes 경로 = 실기기 2종 실측 통과 (2026-07-23 00:0x)
//       iPhone 17 / iOS 26.5.2      isSupported=true  availableBytes=84,626,862,080
//       Galaxy S24 / Android 16     isSupported=true  availableBytes=464,623,534,080
// [ ] embed parity (코사인 ≥ 0.9999) = **미수행**. 118MB 모델이 양 기기에 설치돼야 하고
//     MINILM_MODEL_PATH 주입이 필요하다. 아래 embed 블록은 그 전까지 스킵된다.
//     _encodedFixture 는 결정적 더미이며 실토크나이저 출력이 아니다 — parity 판정에 쓰기 전
//     실제 인코딩으로 교체할 것. (양 플랫폼에 동일 입력이 들어가는 것이 parity 의 전제라
//     더미여도 런타임·pooling 동치 비교 자체는 성립하지만, 토크나이저 경로는 검증되지 않는다.)
//
// ⚠️ 실측으로 드러난 계약 불일치 (설계 갭, 본진 판단 대기):
//     iOS   isSupported = physicalMemory >= 3GB      (ios/Runner/MiniLmChannel.swift)
//     Android isSupported = SUPPORTED_ABIS 에 arm64-v8a 포함 (MainActivity.kt:201)
//     → 같은 검사가 아니다. 메모리 2GB arm64 안드로이드 기기는 게이트를 통과한 뒤
//        모델 적재에서 죽는다 — iOS 가 막으려던 바로 그 시나리오가 Android 에선 안 막힌다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 양 플랫폼 공통 픽스처 — 순서·문자열이 바뀌면 parity 비교가 깨진다. 수정 금지.
const parityFixtures = <String>[
  '오늘 회의에서 정한 내용을 정리했다.',
  '내일 아침에 우유와 계란을 사야 한다.',
  'The quick brown fox jumps over the lazy dog.',
  '아이 이름 후보를 사주로 골라봤다.',
  '주말에 부모님 댁에 다녀올 예정이다.',
];

/// PARITY_JSON 접두어로 뱉어야 러너가 로그에서 골라낼 수 있다.
const parityMarker = 'PARITY_JSON:';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('memoyo/minilm');

  testWidgets('MiniLM 실기기 capability + embed parity', (tester) async {
    final report = <String, Object?>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    };

    // ── 1. capability 게이트 (실기기에서만 유효) ──
    bool supported = false;
    try {
      supported = await channel.invokeMethod<bool>('isSupported') ?? false;
      report['isSupported'] = supported;
    } catch (e) {
      report['isSupportedError'] = e.toString();
    }

    // ── 2. 저장공간 조회 (Android StatFs 대응 경로) ──
    try {
      final dir = Directory.systemTemp.path;
      report['availableBytes'] =
          await channel.invokeMethod<int>('availableBytes', {
            'directoryPath': dir,
          });
    } catch (e) {
      report['availableBytesError'] = e.toString();
    }

    // ── 3. embed — 모델이 이미 설치된 기기에서만 성공한다 ──
    // 미설치면 load 단계에서 실패하고 그 사실을 그대로 기록한다(은폐 금지).
    final vectors = <String, List<double>>{};
    try {
      final modelPath = const String.fromEnvironment('MINILM_MODEL_PATH');
      if (modelPath.isEmpty) {
        report['embedSkipped'] = 'MINILM_MODEL_PATH 미지정';
      } else {
        await channel.invokeMethod<void>('load', {'modelPath': modelPath});
        for (var i = 0; i < parityFixtures.length; i++) {
          // 토크나이저 인코딩은 Dart 측 xlm_roberta_sentencepiece 가 담당하지만,
          // parity 목적상 채널 계약(input_ids/attention_mask)만 맞추면 되므로
          // 러너가 주입한 사전 인코딩 픽스처를 쓴다.
          final encoded = _encodedFixture(i);
          final out = await channel.invokeListMethod<num>('embed', encoded);
          vectors['$i'] = out?.map((e) => e.toDouble()).toList() ?? const [];
        }
        report['vectors'] = vectors;
        await channel.invokeMethod<void>('close');
      }
    } catch (e) {
      report['embedError'] = e.toString();
    }

    // ignore: avoid_print — 러너가 이 줄을 파싱한다.
    print('$parityMarker${jsonEncode(report)}');
    expect(report.containsKey('isSupported'), isTrue);
  });
}

/// 사전 인코딩 픽스처. 실제 토크나이저 출력으로 교체 전까지는 결정적 더미를 쓴다.
/// (양 플랫폼에 **동일한 입력**이 들어가는 것이 parity 의 전제다.)
Map<String, Object> _encodedFixture(int index) {
  const maxLen = 16;
  final ids = List<int>.generate(maxLen, (i) => (index * 31 + i * 7) % 250002);
  return {
    'input_ids': ids,
    'attention_mask': List<int>.filled(maxLen, 1),
    'token_type_ids': List<int>.filled(maxLen, 0),
  };
}
