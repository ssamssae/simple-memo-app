import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';

/// 말로찾기 온디바이스 전환의 ★비용 축 검증 (T-260806-021 → T-260830-013 개정).
///
/// 아니키 적색선 = 「내 api 로 비용은 못내겠어」
/// (semantic_search_availability.dart 헤더 T-260804-086 인용).
///
/// ■계기가 바뀐 이유
///   종전에는 유료 클라이언트에 transport 스파이를 꽂아 「호출 카운터가 0인가」를 쟀다.
///   T-260830-013 에서 유료 경로(MemoyoEmbeddingClient · GeminiEmbeddingEngine ·
///   SemanticEnginePolicy.gemini)를 lib/ 에서 철거해 셀 대상 자체가 없어졌다. 그래서
///   축을 런타임 카운터에서 ★두 겹으로 옮긴다:
///     (A) 소스 스캔 — 유료 경로가 lib/ 로 되돌아오면 빨개진다. 카운터보다 강하다.
///         카운터는 「이번 실행에서 안 불렸다」만 말하지만, 스캔은 「부를 수단이 없다」를
///         말한다.
///     (B) 강등 동작 — 온디바이스가 부재·미설치·실패일 때 유료로 안 넘어가고
///         lexical(문자열 검색)로 내려가 ★답은 돌려주는지.
///   (B)만 있으면 검색이 통째로 죽어도 통과하고, (A)만 있으면 배선이 없는데 강등이
///   깨진 상태를 못 잡는다. 둘 다 있어야 한다.
///
/// ■mutation probe (계기가 살아있음의 증명)
///   (A) lib/ 아무 파일에 아래 `forbidden` 의 첫 열쇠(= 주입 선언)를 한 줄 되살리면
///       → 첫 test 가 ★RED 가 되어야 한다. 초록이면 이 스캔은 0회 도는 장식이다.
///       ★여기에 그 선언을 ★온전한 형태로 적지 마라. 스토어 업로드 관문
///       (artifact-endpoint-gate.py)은 lib/ 뿐 아니라 ★test/ 까지 훑어서
///       「주입 엔드포인트가 선언됐다」로 읽는다. 설명하려고 적은 한 줄이 업로드를
///       막는다 — 실측으로 밟았다(T-260830-013).
///   (B) semantic_search_coordinator 의 `if (policy == lexical)` 강등 분기를 지우면
///       → (2)(3)(4)가 ★RED 가 되어야 한다.
///   착수 시 (A)를 실측으로 RED→복원→GREEN 3단 확인했다(보고 첨부). 고치는 사람은 같은
///   절차를 다시 밟아라.
void main() {
  final t = DateTime(2026, 8, 6, 11);
  List<Memo> memos() => [
    Memo(id: 'a', content: '치과 예약\n스케일링', createdAt: t, updatedAt: t),
    Memo(id: 'b', content: '카레 레시피\n양파', createdAt: t, updatedAt: t),
  ];

  SemanticSearchCoordinator coordinator({EmbeddingEngine? onDevice}) {
    return SemanticSearchCoordinator(
      policy: SemanticEnginePolicy.ondevicePreferred,
      onDeviceEngine: onDevice,
    );
  }

  Future<SemanticSearchOutcome> run(SemanticSearchCoordinator c) async {
    return c.search(query: '병원', memos: memos(), persist: (_) async {});
  }

  /// 「유료 경로 없음」만 재면 검색이 통째로 터져도 통과한다. 강등이 실제로
  /// 일어났는지(=공짜 경로로 내려가 사유를 남기는지)까지 같이 잰다.
  ///
  /// ★결과 건수는 여기서 안 잰다. 질의 '병원' 은 픽스처와 어휘가 안 겹쳐 lexical 로
  /// 내려가면 0건이 정상이고, 그걸 「죽었다」로 읽으면 오탐이다. 강등 뒤에도 답이
  /// 돌아오는지는 어휘가 겹치는 질의로 재야 하며 그 축은
  /// semantic_search_exposure_test.dart (b) 가 '치과' 로 맡는다.
  void expectDegradedToLexical(SemanticSearchOutcome outcome, String situation) {
    expect(outcome.semantic, isFalse, reason: '$situation 인데 semantic 로 표시됐다');
    expect(
      outcome.fallbackCode,
      isNotNull,
      reason: '$situation 강등인데 사유 코드가 없다',
    );
  }

  test('★(A) 유료 임베딩 경로가 lib/ 에 되살아나면 빨개진다', () {
    // 되살아나면 안 되는 것들. 쪼개 두지 않는다 — 쪼개면 무엇을 막는 중인지 안 읽힌다.
    const forbidden = <String, String>{
      "fromEnvironment('MEMOYO_API')": '존재하지 않는 백엔드 주소 주입 선언',
      '/api/memoyo/ai/embed': '유료 임베딩 엔드포인트',
      'MemoyoEmbeddingClient': '유료 임베딩 HTTP 클라이언트',
      'GeminiEmbeddingEngine': '유료 임베딩 엔진',
    };

    // ★lib/ 만 센다. test/ 를 포함하면 이 파일 자신의 금지 문자열이 잡혀 항상 RED 다.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final entry in forbidden.entries) {
        if (source.contains(entry.key)) {
          offenders.add('${entity.path}: ${entry.value} (${entry.key})');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '유료 경로가 lib/ 로 되돌아왔다 — 아니키 적색선(「내 api 로 비용은 못내겠어」) 위반.\n'
          '되살리려면 먼저 백엔드를 실제로 세우고 업로드 관문의 KNOWN_ENDPOINT_HOSTS 에 '
          '진짜 host 를 등록하라(T-260830-013).\n${offenders.join('\n')}',
    );
  });

  test('기본 정책이 ondevice_preferred 다 — 전제 확인', () {
    expect(SemanticEnginePolicy.configuredValue, 'ondevice_preferred');
    expect(
      SemanticEnginePolicy.configured,
      SemanticEnginePolicy.ondevicePreferred,
    );
  });

  test('★미지정 정책값은 유료가 아니라 온디바이스로 떨어진다', () {
    // 종전 fallback 은 gemini(유료)였다. 오타 하나가 과금으로 가던 모양이다.
    expect(
      SemanticEnginePolicy.fromValue('오타난값'),
      SemanticEnginePolicy.ondevicePreferred,
    );
    expect(SemanticEnginePolicy.values, hasLength(2), reason: '유료 항목이 다시 생겼다');
  });

  test('(1) 모델이 준비되면 온디바이스로 뜻 검색을 한다', () async {
    final outcome = await run(coordinator(onDevice: _FakeOnDevice(ready: true)));
    expect(outcome.semantic, isTrue);
    expect(outcome.engineId, 'minilm-fake');
  });

  test('★(2) 모델 미설치면 유료로 안 넘어가고 lexical 로 강등된다', () async {
    final outcome = await run(
      coordinator(onDevice: _FakeOnDevice(ready: false)),
    );
    expectDegradedToLexical(outcome, '모델 미설치(MEMOYO_MINILM_MODEL_MISSING)');
    expect(outcome.fallbackCode, 'MEMOYO_MINILM_MODEL_MISSING');
  });

  test('★(3) 온디바이스 미지원 기기도 lexical 로 강등된다', () async {
    final outcome = await run(coordinator(onDevice: null));
    expectDegradedToLexical(outcome, '미지원 기기(MEMOYO_MINILM_UNSUPPORTED)');
    expect(outcome.fallbackCode, 'MEMOYO_MINILM_UNSUPPORTED');
  });

  test('★(4) 온디바이스가 도중에 실패해도 답은 돌려준다', () async {
    final outcome = await run(
      coordinator(onDevice: _FakeOnDevice(ready: true, throwOnEmbed: true)),
    );
    expectDegradedToLexical(outcome, '온디바이스 런타임 실패');
  });
}

class _FakeOnDevice implements EmbeddingEngine {
  _FakeOnDevice({required this.ready, this.throwOnEmbed = false});

  final bool ready;
  final bool throwOnEmbed;

  @override
  String get engineId => 'minilm-fake';

  @override
  int get dimensions => 2;

  @override
  Future<EmbeddingCapability> capability() async =>
      EmbeddingCapability(supported: true, ready: ready);

  @override
  Future<EmbeddingBatch> embedDocuments(List<String> texts) async {
    if (throwOnEmbed) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.unavailable,
        'MEMOYO_MINILM_RUNTIME_FAILED',
      );
    }
    return EmbeddingBatch(
      engineId: engineId,
      dimensions: 2,
      embeddings: texts
          .map((x) => x.contains('카레') ? [0.0, 1.0] : [1.0, 0.0])
          .toList(),
    );
  }

  @override
  Future<EmbeddingBatch> embedQuery(String text) async {
    if (throwOnEmbed) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.unavailable,
        'MEMOYO_MINILM_RUNTIME_FAILED',
      );
    }
    return EmbeddingBatch(
      engineId: engineId,
      dimensions: 2,
      embeddings: const [
        [1.0, 0.0],
      ],
    );
  }

  @override
  Future<void> close() async {}
}
