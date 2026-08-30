/// 말로찾기(뜻으로 찾기 = 시맨틱 검색) 노출 스위치 — T-260804-086.
///
/// ■왜 지우지 않고 감추나
///   아니키 결정 2026-08-04 23:33 KST 「말로찾기는 3안으로 가, 온디바이스 될 때까지 그 기능만
///   숨겨」(parent T-260804-082). 기능을 없애는 게 아니라 ★잠그는 것이다. 구독(premium_monthly)
///   폐지로 이 기능의 열쇠가 사라지는데, 그대로 열어 두면 유료 임베딩 API
///   (유료 임베딩 엔드포인트, Gemini)가 아니키 비용으로 되살아난다 — 「내 api 로 비용은 못내겠어」와
///   정면으로 어긋난다. 그래서 코드는 전부 보존하고 ★들어가는 길만 막는다.
///
/// ■2026-08-06 잠금 해제됨 (T-260806-022) — 잠근 사유가 사라져서다
///   위 잠금 사유는 「유료 임베딩이 아니키 비용으로 되살아난다」였다. 그 경로 자체를
///   없앴다: `semantic_search_coordinator.dart` 가 gemini 를 policy 가 명시적으로
///   gemini 일 때만 후보에 넣는다. 기본 정책 `ondevice_preferred` 에서는 온디바이스가
///   부재·미지원·실패해도 유료로 안 넘어가고 lexical(문자열 검색)로 강등된다.
///   ⇒ 열어도 과금이 0 이므로 감출 이유가 없어졌다.
///
///   ★이 값을 되돌리기 전에 알아야 할 것: 지금 기본 ON 은 「온디바이스가 완성돼서」가
///   아니라 「유료 경로가 없어서」다. 비용 축을 되살리는 변경(coordinator 에 gemini 를
///   무조건 넣는 식)을 하면서 이 스위치를 켠 채로 두면, 잠금이 막던 그 상태가 그대로
///   돌아온다. 비용 축 회귀축 = test/features/memos/semantic_ondevice_cost_axis_test.dart
///
///   일회성으로 끄려면: flutter test --dart-define=MEMOYO_SEMANTIC_SEARCH=false
///
/// ■고치는 사람에게
///   ★이 상수를 읽는 곳을 늘리는 것은 괜찮지만, 같은 판정을 다른 리터럴로 복제하지 마라.
///   두 벌이 되면 한쪽만 켜져서 「세그먼트는 없는데 경로는 살아 있는」 상태가 만들어진다 —
///   그게 정확히 비용이 조용히 되살아나는 모습이다. 판정은 여기 하나뿐이어야 한다.
///   회귀축 = test/features/memos/semantic_search_hidden_test.dart 가 이 계약을 지킨다.
library;

/// 말로찾기 노출 여부. 기본 ON — 유료 폴백 제거로 잠금 사유가 해소됐다(T-260806-022).
const bool kSemanticSearchEnabled = bool.fromEnvironment(
  'MEMOYO_SEMANTIC_SEARCH',
  defaultValue: true,
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
/// 노출(T-260806-022) 이후에는 `kSemanticSearchEnabled` 가 참이라 이 식이 항상 참이다.
/// 식을 단순화하지 마라 — 스위치를 다시 끄는 날 (d)(e) 구분이 되살아나야 한다.
///
/// 회귀축 = test/features/memos/semantic_search_exposure_test.dart (d)(e).
bool miniLmTileVisible({required bool installed}) =>
    kSemanticSearchEnabled || installed;
