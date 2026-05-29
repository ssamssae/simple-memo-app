# 메모요 — `onReorder` → `onReorderItem` migration spec

**Status**: 🟡 draft · 형님 ack 펜딩 (코드 진입은 SDK 정책 v1 확정 + B 그룹 업그레이드 후)
**Author**: 💻 노트북 / 2026-05-29 KST · branch `notebook/memoyo-onreorder-migration-spec-2026-05-29`
**Repo**: ssamssae/simple-memo-app
**Parents**:
- [[memoyo-flutter-deprecated-api-audit.md]] (PR #37, §4 옵션 B 추천)
- [[5node-flutter-sdk-policy-brainstorm.md]] (PR #35, SDK 정책 v1 게이트)
**Cascade history**: PR #23 → #28 → #34 → #39 → #41 (4회 회귀) → PR #42 (commit d44f820, 임시 `! bang + ignore_for_file`). 본 spec = 진짜 fix 의 진입 sequence·영향 범위·cascade 차단 보장 분석.

---

## 0. TL;DR

- 진짜 fix = `onReorder` (deprecated, 3.42.0~) → `onReorderItem` forward migration. 임시방편 PR #42 의 `ignore_for_file` 2개 + `! bang` 을 걷어내는 것이 목표.
- **핵심 발견**: 메모요의 `_onReorderFav` / `_onReorderNormal` 핸들러는 이미 `onReorderItem` 의 **post-removal newIndex 좌표계**로 작성돼 있다 (`if (oldIndex < newIndex) newIndex -= 1` 보정 **없음**). 따라서 migration 은 **핸들러 본문 변경 0** — named param 이름만 바꾸면 된다.
- 부수 효과(추정, 검증 필요): 이 migration 은 현재 `onReorder` wiring 의 **아래방향 드래그 off-by-one 잠재 버그**를 동시에 고친다 (§3).
- 변경 표면 = lib 2줄 + test 6줄 + `ignore_for_file` 2줄 제거. 총 8 라인 수정 + 2 라인 삭제.
- **절대 전제(blocker)**: B 그룹(🏭 맥미니 + 💻 노트북 = Flutter 3.41.9)은 `onReorderItem` 미정의 → migration 단독 머지 시 B 그룹이 깨진다. **SDK 정책 v1 확정 → B 그룹 3.42.0+ 업그레이드 완료 후에만** 진입 가능.
- spec only. 코드 진입은 본진 ack 후.

---

## 1. 근본 원인 재정리 (cascade 가 4번 반복된 이유)

두 축이 겹쳐 cascade 를 만들었다:

1. **deprecation 축** — Flutter commit `3e6c2071664` (2026-01-29, 첫 stable 3.42.0) 가 `ReorderableListView.onReorder` 를 deprecate + `onReorderItem` 신규. 3.44.0(A 그룹) analyze 는 `onReorder` 에 `deprecated_member_use` info 6건.
2. **nullability 축** — 같은 commit 이 `onReorder` 시그너처를 `ReorderCallback` (non-null) → `ReorderCallback?` (nullable) 로 변경.
   - 3.44.0(A): `reorderable.onReorder(0,1)` 직접 호출 = `unchecked_use_of_nullable_value` **ERROR** → `!` bang 필요.
   - 3.41.9(B): `onReorder` 는 여전히 non-null → `!` bang 은 `unnecessary_non_null_assertion` **warning**.

→ 한 SDK 에서 PASS 받은 fix 가 다른 SDK 에서 깨지는 **양방향 ping-pong**. A 그룹이 `!` 박으면 B 가 깨지고, B 가 `!` 떼면 A 가 깨진다. PR #42 가 양쪽 다 통과시키려고 `! bang` + `ignore_for_file: unnecessary_non_null_assertion, deprecated_member_use` 로 **두 경고를 모두 침묵**시킨 임시방편.

`onReorderItem` 으로 옮기면 두 축이 동시에 해소된다: deprecated 아님(축1) + `onReorderItem` 도 nullable 이지만 5 노드가 같은 SDK floor(3.42.0+)면 nullability 처리가 한 가지로 통일(축2).

---

## 2. 변경 표면 (정확히 어느 라인)

`grep -rn onReorder lib/ test/` 결과 기준. `onReorderStart`/`onReorderEnd` 는 무관.

### lib (2줄, named param 이름만)
| 파일:라인 | 현재 | migration 후 |
|-----------|------|--------------|
| `lib/screens/memo_list_screen.dart:765` | `onReorder: _onReorderFav,` | `onReorderItem: _onReorderFav,` |
| `lib/screens/memo_list_screen.dart:800` | `onReorder: _onReorderNormal,` | `onReorderItem: _onReorderNormal,` |

**핸들러 본문 (`_onReorderFav` L521, `_onReorderNormal` L557) 은 변경 0** — 이유는 §3.

### test (6줄 + ignore 2줄 제거)
`test/screens/memo_list_reorder_test.dart`:
- L4 `// ignore_for_file: unnecessary_non_null_assertion, deprecated_member_use` **삭제**
- L66 `expect(reorderable.onReorder, isA<ReorderCallback>())` → `.onReorderItem` (타입명은 §6 검증)
- L70 `reorderable.onReorder!(0, 1)` → `reorderable.onReorderItem!(0, 1)`
- L119 `expect(reorderable.onReorder, ...)` → `.onReorderItem`
- L121 `reorderable.onReorder!(2, 0)` → `reorderable.onReorderItem!(2, 0)`

`test/screens/memo_list_toggle_reorder_interaction_test.dart`:
- L4 `// ignore_for_file: ...` **삭제**
- L72 `normalReorderable.onReorder!(1, 0)` → `.onReorderItem!(1, 0)`
- L126 `favReorderable.onReorder!(0, 1)` → `.onReorderItem!(0, 1)`

**기대값(expected reorder 결과)은 전부 그대로** — `[F2,F1,F3]`, `[N3,N1,N2]`, `[n-3,n-2,n-1]`, `[f-2,f-1,n-1]` 모두 불변. 이것이 cascade 차단 보장의 핵심(§4).

---

## 3. 핵심 발견 — 핸들러가 이미 `onReorderItem` 좌표계다

### 3.1 두 콜백의 newIndex 좌표계 차이

Flutter 3.41.9 소스 `packages/flutter/lib/src/widgets/reorderable_list.dart` L39–58 의 canonical 핸들러:

```dart
// If [oldIndex] is before [newIndex], removing the item at [oldIndex] ...
// account for this when inserting before [newIndex].
void handleReorder(int oldIndex, int newIndex) {
  if (oldIndex < newIndex) {
    newIndex -= 1;          // ← OLD onReorder 는 이 보정이 필수
  }
  final element = backingList.removeAt(oldIndex);
  backingList.insert(newIndex, element);
}
```

- **OLD `onReorder`**: newIndex 를 **제거 전(pre-removal)** 좌표로 보고. 아래방향 이동 시 `if (oldIndex < newIndex) newIndex -= 1` 보정 **필수**.
- **NEW `onReorderItem`** (deprecation 메시지 원문): *"adjusts the newIndex parameter for a removed item at the oldIndex"* = newIndex 가 **제거 후(post-removal)** 좌표로 **이미 보정돼서** 들어온다. 보정 코드 **불필요**.

### 3.2 메모요 핸들러는 보정이 없다

`_onReorderFav`/`_onReorderNormal` 는 `if (oldIndex < newIndex) newIndex -= 1` 보정 없이 `removeAt` → (그룹 인덱스 재계산) → 원시 `newIndex` 위치에 `insert`. 즉 **post-removal 좌표계 = `onReorderItem` 의 계약**으로 작성돼 있다. (PR #40 테스트 주석 `_onReorderFav 의 알고리즘 (newIndex 보정 X)` 도 이 사실을 이미 명시.)

**결론**: param 이름만 `onReorder` → `onReorderItem` 으로 바꾸면 핸들러 본문은 그대로 맞다. migration 이 핸들러 로직을 건드릴 필요가 없다.

### 3.3 부수 효과 — 아래방향 드래그 off-by-one 잠재 버그 (검증 필요)

현재 `onReorder` wiring 에서는 핸들러가 보정을 빼먹었으므로, **실제 드래그로 항목을 아래로 옮기면** 프레임워크가 pre-removal newIndex 를 주는데 보정이 없어 **한 칸 더 내려간다**.

추적 — `[F1,F2,F3]` 전부 즐겨찾기, F1 을 F2 아래로 한 칸 드래그:
- 실제 `onReorder` 드래그가 주는 값: `oldIndex=0, newIndex=2` (pre-removal "insert before 2").
- `_onReorderFav(0, 2)`: `removeAt(0)`→`[F2,F3]`, 재계산 `[0,1]`, `newIndex(2) >= 2` → else 분기 → `last+1 = 2` → `insert(2,F1)` → **`[F2,F3,F1]`** (F1 이 맨 아래로). 기대 `[F2,F1,F3]` 과 불일치.

→ 현재 메모요는 **그룹 내 아래방향 드래그가 한 칸 어긋나는 잠재 버그**가 있을 가능성이 높다. `onReorderItem` 으로 옮기면 프레임워크가 post-removal newIndex(=1)를 주므로 `[F2,F1,F3]` 로 **정상화**된다.

**왜 지금 안 잡혔나**: 기존 회귀 테스트는 `reorderable.onReorder!(0,1)` 처럼 콜백을 **직접 호출**(드래그 시뮬 X — nested-scroll+shrinkWrap 에서 flaky 회피)하며, 직접 호출값 `(0,1)` 자체가 이미 post-removal 의미로 해석돼 있다. 즉 테스트가 무의식적으로 `onReorderItem` 계약을 박아둔 셈이라 실제 드래그의 pre-removal 동작을 못 본다.

**확신도**: SDK 의 문서화된 canonical 계약(§3.1)에 근거한 high-confidence 가설. 단 실기 드래그 동작은 본 노드(3.41.9, `onReorderItem` 부재)에서 직접 재현 불가 → **A 그룹(본진 3.44.0)에서 실드래그 회귀 테스트로 migration 전(버그)·후(정상) 확인 필요**(§5). 만약 프레임워크가 실제로 post-removal newIndex 를 준다면(문서와 모순) migration 은 순수 no-op 이고 여전히 안전.

---

## 4. cascade 차단 보장

migration 후 cascade 가 재발하지 않음을 보장하는 근거 3가지:

1. **deprecation 소멸** — `onReorderItem` 은 deprecated 아님 → A 그룹 `deprecated_member_use` info 6건 → 0. `ignore_for_file: deprecated_member_use` 불요.
2. **nullability 통일** — 5 노드가 동일 SDK floor(3.42.0+)면 `onReorderItem` 의 nullable 처리(`!` 또는 `?.call`)가 한 가지로 통일 → `unnecessary_non_null_assertion` ping-pong 소멸. `ignore_for_file: unnecessary_non_null_assertion` 불요.
3. **기대값 불변** — §2 의 expected reorder 결과 4종이 전부 동일하므로, migration 은 회귀 안전망(PR #34/#40)의 contract 를 깨지 않는다. 테스트는 param 이름·타입 단언만 바뀌고 검증 로직·기대값은 그대로 → **순수 rename 의 안전성**이 테스트로 증명됨.

**증명 게이트**: `~/claude-skills/autopilot/merge-gate.sh ~/simple_memo_app` 를 **5 노드 전부**에서 rc=0 (analyze clean + test PASS) 받아야 머지. 한 노드라도 rc=1 → cascade 미차단 신호 → 머지 중단.

---

## 5. 진입 sequence (gated)

```
[GATE 0] 형님 ack: SDK 정책 v1 확정
         ├─ 옵션 1 (fvm 통일, 전 노드 동일 버전) ── 권장, B 그룹 floor 명확
         └─ 옵션 2 (v2 게이트 강화) ── B 그룹 3.42.0+ 보장 시만 안전
              ↓ (5node-flutter-sdk-policy-brainstorm.md)
[STEP 1] B 그룹(🏭 맥미니 + 💻 노트북) 3.42.0+ 업그레이드
         → 5 노드 전부 `flutter --version` ≥ 3.42.0 확인
         → 업그레이드 직후 5 노드 merge-gate 베이스라인 PASS 확인
              ↓
[STEP 2] migration PR (단일 노드, prefix 브랜치)
         ├─ lib 2줄 rename (§2)
         ├─ test 6줄 rename + ignore_for_file 2줄 제거 (§2)
         └─ 회귀 안전망 contract 그대로 (기대값 불변)
              ↓
[STEP 3] (권장) 실드래그 회귀 테스트 1건 추가 — §3.3 아래방향 버그 전/후 확인
         A 그룹(3.44.0)에서 tester.drag 로 그룹 내 아래방향 이동 → [F2,F1,F3] 검증
              ↓
[STEP 4] 5 노드 merge-gate 5/5 PASS → 본진/맥미니 머지
              ↓
[STEP 5] 안전망 파일 상단 cross-SDK 주석(L1–4) 정리 — 임시방편 흔적 제거
```

- STEP 1 이 없으면 절대 진입 금지(B 그룹 즉시 깨짐). 이것이 본 migration 의 단일 blocker.
- STEP 2~5 는 한 PR 로 묶어도 되고 STEP 3 만 분리해도 됨(코드 변경 본질이 작아 단일 PR 권장).

---

## 6. 검증·열린 질문 (본진 ack 항목)

A 그룹(본진 3.44.0)에서 확인 필요 — 본 노드(3.41.9)는 `onReorderItem` 부재로 직접 검증 불가:

1. **타입명** — `onReorderItem` 의 콜백 타입이 `ReorderCallback`(=`void Function(int,int)`) 그대로인지, 아니면 신규 typedef(`ReorderItemCallback` 등)인지. 테스트 L66/L119 의 `isA<ReorderCallback>()` 단언이 그대로 유효한지 확인 후 필요 시 타입명 교체.
2. **nullability** — `onReorderItem` 도 nullable(`?`)인지 확인 → `!` bang 유지 여부 결정. nullable 이면 직접호출 `onReorderItem!(...)` 유지.
3. **실드래그 동작(§3.3)** — migration 전 A 그룹에서 그룹 내 아래방향 실드래그가 정말 한 칸 어긋나는지 재현 → 후에 정상화되는지 확인. 잠재 버그 가설의 최종 검증.
4. **SDK 정책 선택** — 옵션 1(fvm 통일) vs 옵션 2(게이트 강화). 본 spec 은 옵션 1 권장(B 그룹 floor 가 명확해 STEP 1 이 단순). 최종 결정은 [[5node-flutter-sdk-policy-brainstorm.md]] 소관.

---

## 7. 롤백

- migration PR 단독 revert 로 `onReorder` + `ignore_for_file` 임시방편 상태(PR #42)로 즉시 복귀 가능. 핸들러 본문이 안 바뀌었으므로 데이터/영속 형식 영향 0.
- 단 B 그룹이 이미 3.42.0+ 면 revert 후 `onReorder` 가 다시 deprecated → `ignore_for_file: deprecated_member_use` 만 남겨두면 됨(nullability 는 통일된 SDK 라 문제 없음).

---

## 8. 본 spec 의 한계

- §3.3 실드래그 버그는 canonical 계약 기반 high-confidence **가설** — 3.41.9 노드에서 실증 불가, A 그룹 실드래그 테스트로 최종 확정 필요.
- `onReorderItem` 의 정확한 시그너처·nullability·타입명은 3.44.0 소스 미열람(본 노드 부재). §6 1·2 항으로 본진 위임.
- 외부 의존성(googleapis/share_plus/file_picker/sensors_plus)의 별도 deprecation 은 본 spec 범위 밖 — audit §5(b) 후보로 분리 유지.
- 작성 시점 main HEAD = `d44f820`(PR #42). 이후 main 진화 시 §2 라인 번호 재확인 필요.
