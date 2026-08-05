/// 말로찾기(뜻으로 찾기 = 시맨틱 검색) 노출 스위치 — T-260804-086.
///
/// ■왜 지우지 않고 감추나
///   아니키 결정 2026-08-04 23:33 KST 「말로찾기는 3안으로 가, 온디바이스 될 때까지 그 기능만
///   숨겨」(parent T-260804-082). 기능을 없애는 게 아니라 ★잠그는 것이다. 구독(premium_monthly)
///   폐지로 이 기능의 열쇠가 사라지는데, 그대로 열어 두면 유료 임베딩 API
///   (/api/memoyo/ai/embed, Gemini)가 아니키 비용으로 되살아난다 — 「내 api 로 비용은 못내겠어」와
///   정면으로 어긋난다. 그래서 코드는 전부 보존하고 ★들어가는 길만 막는다.
///
/// ■되살리는 법 = 이 파일의 defaultValue 한 줄
///   온디바이스 MiniLM 이 완성되면 아래 `defaultValue: false` 를 `true` 로 바꾸면 된다.
///   그 한 줄로 ①검색 화면의 모드 세그먼트 노출 ②시맨틱 경로 진입 ③이 기능을 UI 로 몰던
///   기존 테스트 2본(search_screen_semantic_test.dart)의 skip 해제가 ★동시에 풀린다.
///   빌드 시 일회성으로 켜려면 소스를 안 고치고도 된다:
///     flutter test --dart-define=MEMOYO_SEMANTIC_SEARCH=true
///   재개 브랜치 = T-260722-023-ios-ondevice-prep (mini_lm_*.dart 6본이 그쪽에 붙는다).
///
/// ■고치는 사람에게
///   ★이 상수를 읽는 곳을 늘리는 것은 괜찮지만, 같은 판정을 다른 리터럴로 복제하지 마라.
///   두 벌이 되면 한쪽만 켜져서 「세그먼트는 없는데 경로는 살아 있는」 상태가 만들어진다 —
///   그게 정확히 비용이 조용히 되살아나는 모습이다. 판정은 여기 하나뿐이어야 한다.
///   회귀축 = test/features/memos/semantic_search_hidden_test.dart 가 이 계약을 지킨다.
library;

/// 말로찾기 노출 여부. 기본 OFF — 온디바이스 완성까지 잠금(T-260804-086).
const bool kSemanticSearchEnabled = bool.fromEnvironment(
  'MEMOYO_SEMANTIC_SEARCH',
  defaultValue: false,
);

/// 설정 화면의 「기기 내 뜻 검색 모델」 타일을 보일지 — T-260805-145.
///
/// 잠금 중에는 ★설치를 권하지 않는다. 검색 UI 는 위 상수로 가려지는데 이 타일만 게이트 밖이라,
/// 쓸 수 없는 기능을 위해 124MB 를 받으라고 권하는 상태였다.
///
/// ★단, 이미 받은 사람에게는 남긴다. 타일을 통째로 없애면 삭제 버튼이 함께 사라져 124MB 를
/// 회수할 문이 닫힌다 — 잠금이 사용자 손해로 바뀌는 지점이다. 줄이는 방향이 아니라
/// 「없는 기능을 안 판다」 방향이어야 한다.
///
/// 회귀축 = test/features/memos/semantic_search_hidden_test.dart (d)(e).
bool miniLmTileVisible({required bool installed}) =>
    kSemanticSearchEnabled || installed;
