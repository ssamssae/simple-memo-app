# 메모요 iOS 온디바이스 MiniLM 런타임 — 설계

- task: T-260722-023 (parent 우산 = T-260713-55 말로검색 온디바이스 임베딩)
- 작성: 2026-07-22, 🪟 라이덴
- 상태: **prep 전용 설계. 코드·빌드 설정 변경 0.** 구현·빌드는 승인 후 별도 leg(맥미니).
- 승인: 아니키 GO 2026-07-22 12:44 KST — "메모요 iOS 15.1 상향 수용 — 온디바이스 iOS leg 준비 진행해"

## 0. 왜 지금 iOS 인가

우산 T-260713-55 의 발원 목표는 "공유 Gemini 무료티어 스케일 한계 해소 = 중앙 API 의존 제거"였다.
현행 실측(2026-07-22 재판정):

- 온디바이스 경로는 **Android arm64 전용**이다. `MethodChannel('memoyo/minilm')` 이
  `android/app/src/main/kotlin/.../MainActivity.kt` 에만 구현돼 있고 `ios/Runner` 에는 MiniLM/ONNX 참조가 0이다.
- 따라서 **iOS 사용자는 전원** `MEMOYO_MINILM_UNSUPPORTED` → `semantic_search_coordinator.dart:62-81` 의
  Gemini 폴백으로 떨어진다. 발원 리스크가 iOS 에서 그대로 살아 있다.
- Gemini 경로 정리(우산 잔여 ②)는 이 leg 에 **엄격 종속**이다. iOS 없이 걷어내면 iOS 의미검색이 lexical 로 강등된다.

### iOS 최소버전 게이트 — 16 이 아니라 15.1

2026-07-16 시점의 "iOS 16 상향 수용"은 **EmbeddingGemma(flutter_gemma wrapper) 전제**였고,
stage1 실측으로 MiniLM+ONNX 가 채택되면서 그 전제는 소멸했다. 실측 결과:

- `microsoft/onnxruntime` 의 `tools/ci_build/github/apple/default_full_apple_framework_build_settings.json`
  에서 `--apple_deploy_target=15.1` (v1.23.0 태그·main 동일). **ONNX Runtime 이 요구하는 iOS 바닥 = 15.1.**
  1.23.0 은 Android 가 이미 쓰는 버전과 같은 계열이다(`android/app/build.gradle.kts:65`
  `com.microsoft.onnxruntime:onnxruntime-android:1.23.0`).
- iOS 13 지원 기종 집합 = iOS 15 지원 기종 집합 = iPhone 6s 이후. 6s/SE1/7 의 최종 OS 가 15.8.x 라
  **13.0 → 15.1 상향으로 잘리는 아이폰 기종은 0** 이다. (16.0 으로 올렸다면 A9/A10 = 6s·6s Plus·SE1·7·7 Plus 가 잘린다.)
- 남는 실질 비용은 iOS 13~14 에 머문 사용자의 OS 업데이트 요구뿐이다(기기 폐기 아님).

## 1. 채널 계약 — 변경 없음 (Dart 측이 SoT)

`lib/features/memos/services/mini_lm_runtime.dart:19` 의 `MethodChannel('memoyo/minilm')` 을 그대로 구현한다.

| method | 인자 | 반환 |
|---|---|---|
| `isSupported` | — | `bool` |
| `availableBytes` | `directoryPath: String` | `int` |
| `load` | `modelPath: String` | `void` |
| `embed` | `inputIds` / `attentionMask` / `tokenTypeIds`: `List<int>` | `List<num>` |
| `close` | — | `void` |

### 에러코드 계약 (반드시 문자열 동일)

`mini_lm_embedding_engine.dart:82-132` 이 `PlatformException.code` 를 문자열로 분기한다.

- `OUT_OF_MEMORY` → `EmbeddingFailureKind.outOfMemory`
- 그 외 전부 → `EmbeddingFailureKind.loadFailed`
- Android 가 내는 코드: `INVALID_ARGUMENT` / `LOAD_FAILED` / `INFERENCE_FAILED` / `CLOSE_FAILED` / `OUT_OF_MEMORY`

**Swift 는 같은 문자열을 그대로 내야 한다.** 다르면 폴백 분기가 어긋나 실패가 오분류된다.

## 2. Swift 구현 계획 (Android 대칭)

- 신규 파일: `ios/Runner/MiniLmChannel.swift`
- `ios/Runner/AppDelegate.swift` 에 채널 등록 1줄
- 의존: `ios/Podfile` 에 `pod 'onnxruntime-objc', '~> 1.23.0'`
- **Dart·pubspec 변경 0.** Android 가 Gradle 의존이듯 iOS 는 CocoaPods 의존이라 Dart 측 계약은 건드리지 않는다.

### 2.1 대응표

| Android (MainActivity.kt) | iOS (MiniLmChannel.swift) |
|---|---|
| `OrtEnvironment` lazy 싱글턴 (:20) | `ORTEnv(loggingLevel:)` 1회 생성 |
| `OrtSession?` (:22) | `ORTSession?` |
| `Executors.newSingleThreadExecutor()` (:21) | `DispatchQueue(label: "memoyo.minilm", qos: .userInitiated)` 직렬 큐 |
| `StatFs(path).availableBytes` (:39) | `FileManager.default.attributesOfFileSystem(forPath:)[.systemFreeSize]` |
| `Build.SUPPORTED_ABIS.contains("arm64-v8a")` (:201) | §3 — ABI 아님, **메모리 게이트** |
| `SessionOptions`: intraOp 2 / interOp 1 / `ALL_OPT` (:86-88) | `ORTSessionOptions`: `setIntraOpNumThreads(2)`, `setGraphOptimizationLevel(.all)` |
| `OnnxTensor.createTensor(env, LongBuffer, shape[1,N])` (:113) | `ORTValue(tensorData:elementType:.int64, shape:[1,N])` |
| 입력명 `input_ids`/`attention_mask`/`token_type_ids` 를 세션 `inputNames` 로 필터 (:111-118) | 동일 — 세션이 요구하는 입력만 채운다 |
| 출력 우선순위 `sentence_embedding` → `last_hidden_state` → `token_embeddings`, 없으면 0번 (:120-127) | 동일 |
| `poolAndNormalize` (:143-188) | §2.2 — **알고리즘 동치 포팅** |
| `OutOfMemoryError` catch → `closeSession()` + `OUT_OF_MEMORY` (:71-73) | iOS 는 OOM 을 앱에서 catch 할 수 없다(jetsam kill) → §3 사전 게이트로 대체 + `didReceiveMemoryWarning` 에서 `close()` |
| `onDestroy` 에서 close + executor shutdown (:203-207) | `applicationWillTerminate` / deinit 에서 동일 |

### 2.2 pooling 동치가 필수다

`poolAndNormalize` 는 (a) rank-2 `[1, D]` 는 그대로, (b) rank-3 `[1, S, D]` 는 attention mask 로
**mean-pool**(mask=0 토큰 제외, 유효 토큰 수로 나눔), 그다음 (c) L2 정규화한다.

이 알고리즘이 플랫폼 간 다르면 **같은 `engineId` 로 저장된 임베딩이 오염된다.**
`semantic_search_service.staleMemos()` 는 `engineId` + `dimensions` 로만 stale 을 판정하므로,
벡터 의미가 달라져도 재색인이 트리거되지 않는다. `engineId` 는 플랫폼 무관하게
`paraphrase_multilingual_minilm_onnx` 로 동일해야 하고, **벡터도 동일해야 한다.**
→ §4.2 parity 검증을 필수 게이트로 둔다.

## 3. capability 게이트 — iOS 는 ABI 가 아니라 메모리로 자른다

Android 는 `arm64-v8a` ABI 로 자르지만, **iOS 15.1+ 기기는 전부 arm64** 라 ABI 게이트가 무의미하다.

문제는 15.1 바닥이 **A9/A10(2GB RAM: iPhone 6s·6s Plus·SE1·7·7 Plus)** 을 포함한다는 점이다.
118.4MB qint8 ONNX 를 2GB 기기에서 로드하면 jetsam kill 위험이 크고,
**iOS 에는 Android 의 `OutOfMemoryError` catch 경로에 해당하는 것이 없다** — 프로세스가 그냥 죽는다.

→ `isSupported()` = `ProcessInfo.processInfo.physicalMemory >= <임계>` (초기 권고 **3GB**, §4.4 에서 확정).
A11(iPhone 8/X) 이상만 통과시키는 선이다.

### 폴백 설계는 무변경이다

임계 미달 기기는 `capability().supported == false` → `MEMOYO_MINILM_UNSUPPORTED` →
`semantic_search_coordinator.dart:62-81` 이 Gemini 후보를 잡는다. **이 경로는 이미 존재하고,
지금 iOS 전체가 그 경로로 돌고 있다.** 이번 leg 이 바꾸는 것은 폴백 대상이
"iOS 전체 → 저사양 iOS 일부" 로 줄어드는 것뿐이다. 사용자 노출 문구도 그대로 쓸 수 있다
(`lib/l10n/app_strings.dart:237-238` "이 기기에서는 Gemini 검색을 사용합니다").

### 앱 번들 증가 — 추정과 실측법

- 모델 123.5MB(`model_qint8_arm64.onnx` 118.4MB + `sentencepiece.bpe.model` 5.1MB)는
  **온디맨드 다운로드**라 앱 번들과 무관하다(`mini_lm_model_manifest.dart:21-28`, huggingface.co).
  manifest 자체만 앱 서명 안에 번들되고 sha256 로 핀된다(`:34-35`, `verifyBundled` `:72-88`).
- 따라서 증가분 = **onnxruntime-objc 프레임워크(arm64 slice)** 뿐이다.
- 실측법: ① `pod install` 후 `du -sh Pods/onnxruntime-c/` ②  Release 아카이브의
  **App Thinning Size Report**(기기별 다운로드/설치 크기) ③ 상향 전/후 IPA 비교.
  셀룰러 다운로드 경고선과 대조해 보고한다.

## 4. 검증 계획

### 4.1 정적·단위
- `test/features/memos/ondevice_platform_gate_test.dart:10` 이 `contains("platform :ios, '13.0'")` 로
  **바닥값을 고정 검증한다.** 이 fixture 가 무단 상향을 막는 가드이므로 상향 시 **반드시 동반 갱신**한다.
- iOS `isSupported()` 메모리 임계 로직은 `RunnerTests` 또는 Dart 측 fake runtime 테스트로 커버.

### 4.2 parity (필수 게이트)
고정 문장 N개에 대해 Android/iOS `embed` 결과 벡터의 코사인 유사도 **≥ 0.9999** 를 확인한다.
불일치 시 §2.2 대로 저장 임베딩이 조용히 오염되므로 통과 전에는 플래그를 올리지 않는다.
stage1 하네스(`tool/ondevice_embedding_stage1`, draft PR#87 브랜치 `spike/T-260713-55-stage1`)에
tokenizer parity 선례가 있으니 재사용을 먼저 검토한다.

### 4.3 시뮬레이터 스모크
iOS 시뮬(arm64)에서 `isSupported → load → embed → close` 1회.
⚠️ 시뮬은 호스트 메모리를 보므로 §3 게이트가 항상 통과한다 — **게이트 검증은 실기기에서만 유효하다.**

### 4.4 실기기 스모크 (맥미니 USB)
- iPhone17: cold/warm 임베딩 지연, RSS, 전체 재색인 완주, 크래시 0
- 저사양 대조군(A10~A11 급)이 있으면 메모리 임계 확정에 사용. 없으면 임계를 보수적으로(4GB) 두고 추후 완화.
- **차단점**: 아니키 물리 연결(iPhone USB + 신뢰) 필요. T-260716-83 과 동일한 차단점이다.

### 4.5 회귀 영향권 (기존 관련 테스트 18종 중)
- `semantic_engine_identity_test` / `semantic_backup_compatibility_test`:
  `engineId`·차원 불변을 확인한다. iOS 추가로 **바뀌면 안 된다.**
- `ondevice_platform_gate_test`: 상향 시 동반 수정 대상(§4.1).
- 나머지(installer / controller / preprocessing / reindex / policy matrix)는 플랫폼 무관 → 무영향 예상.

## 5. 변경 목록 명세 (구현 leg 에서 손댈 곳)

| 파일:라인 | 현재 | 변경 |
|---|---|---|
| `ios/Podfile:2` | `platform :ios, '13.0'` | `'15.1'` + `pod 'onnxruntime-objc'` 추가 |
| `ios/Runner.xcodeproj/project.pbxproj:480` | `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` | `15.1` |
| `ios/Runner.xcodeproj/project.pbxproj:612` | 동일 | `15.1` |
| `ios/Runner.xcodeproj/project.pbxproj:665` | 동일 | `15.1` |
| `test/features/memos/ondevice_platform_gate_test.dart:10` | `contains("platform :ios, '13.0'")` | `'15.1'` |
| `ios/Runner/MiniLmChannel.swift` | 없음 | 신규 |
| `ios/Runner/AppDelegate.swift` | 채널 등록 없음 | 등록 1줄 |

Dart·`pubspec.yaml` 변경 0.
참고: `TARGETED_DEVICE_FAMILY = 1`(아이폰 전용)이지만 아이패드 호환모드로 돌고 애플도 아이패드에서 심사한다
(1.0.13 리젝 2.1(a) = T-260717-055 이력). 15.1 바닥은 iPadOS 15 지원 기종을 그대로 포함하므로 아이패드 컷도 0이다.

## 6. 미결·차단점

1. **실기기 스모크 = 아니키 물리 연결 필요** (iPhone USB + 신뢰). 최대 차단점.
2. **메모리 임계 확정치**(초기 권고 3GB)는 §4.4 실측 후 확정.
3. **기존 저장 임베딩**: `engineId` 동일 + 벡터 동치면 재색인 불필요. parity 실패 시 재색인 전략이 별건으로 필요하다.
4. **Gemini 경로 제거는 이 leg 밖.** iOS 완료 후 별건이며 아니키 게이트다
   (동작 변경 + 재색인 + 구버전 호환. 정리 대상 전수 = 7파일 22지점, 위험 지점은
   `semantic_search_service.dart:9` 의 `static const model = geminiModel` 이 저장 임베딩 기본 `engineId` 라는 점).
5. **배터리 측정 재설계**: stage1 방법론이 무효 처리된 미결 항목(S24 USB충전 왜곡·iPhone 양자화/OS build 혼입).
   우산 종결조건에 포함할지 본진 판정 필요.
