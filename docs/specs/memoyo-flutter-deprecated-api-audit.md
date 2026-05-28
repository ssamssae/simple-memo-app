# 메모요 main — Flutter deprecated API audit

**Status**: 🟡 draft · 형님 ack 펜딩 (forward migration 정책 결정)
**Author**: 🪟 WSL / 2026-05-29 KST
**Repo**: ssamssae/simple-memo-app · branch `wsl/memoyo-flutter-deprecated-api-audit-2026-05-29`
**Parent**: [[5node-flutter-sdk-policy-brainstorm.md]] v2 (PR #35 머지, commit e4643ae)
**Cycle entry**: PR #28 의 `onReorderItem → onReorder` 변경이 사이클 #6 분석으로 **backward 회귀** (deprecated 옛 API 로 역행) 로 surface. 다른 deprecated API 사용 사례 미리 잡기.

---

## 0. TL;DR

- **메모요 main 코드는 Flutter 3.42~3.44 deprecation 측면에서 매우 깨끗** — `flutter analyze --no-pub` 이 info-level 로 잡는 `deprecated_member_use` 는 **6 건 모두 `onReorder` 단독**. 다른 deprecation 0.
- HIGH risk = `onReorder` 1건만. 미래 Flutter major 에서 제거 시 회귀 risk.
- 후속 fix 정책: 5 노드 SDK 정책 (옵션 1/2/3) 확정 후 forward migration (`onReorder → onReorderItem`) 또는 조건부 dual-callback 패턴 채택.

---

## 1. 방법론

**audit 도구**:
1. `flutter analyze --no-pub` (info-level 포함) — Dart analyzer 가 잡는 모든 `deprecated_member_use` 추출
2. `~/flutter` repo (~/flutter, 3.44.0 stable) 의 `@Deprecated` annotation grep — 3.42~3.44 사이 deprecated 된 API 풀 surface
3. 메모요 `lib/` + `test/` 에 위 API 들 grep cross-check

**환경**:
- WSL Linux Flutter 3.44.0 stable (Dart 3.12.0)
- 메모요 main HEAD = e4643ae (PR #35 머지 직후, 사이클 #6)

---

## 2. analyze info-level 결과 (6/6 onReorder)

```
$ flutter analyze --no-pub
info • 'onReorder' is deprecated and shouldn't be used. Use the onReorderItem
       callback instead. The onReorderItem callback adjusts the newIndex
       parameter for a removed item at the oldIndex. This feature was
       deprecated after v3.41.0-0.0.pre. Try replacing the use of the
       deprecated member with the replacement
  • lib/screens/memo_list_screen.dart:765:29 • deprecated_member_use
  • lib/screens/memo_list_screen.dart:800:29 • deprecated_member_use
  • test/screens/memo_list_reorder_test.dart:61:26 • deprecated_member_use
  • test/screens/memo_list_reorder_test.dart:65:19 • deprecated_member_use
  • test/screens/memo_list_reorder_test.dart:114:26 • deprecated_member_use
  • test/screens/memo_list_reorder_test.dart:116:19 • deprecated_member_use

6 issues found.
```

**관찰**: 메모요 lib + test 코드가 analyze 가 잡는 deprecation 은 `onReorder` 단독. 다른 deprecated API (예: `withOpacity`, `MaterialTextSelectionHandleControls`, `Tooltip.height`, `InputDecoration.maintainHintHeight`) 0 매치.

---

## 3. 영향 매트릭스 (3.42~3.44 deprecated API × 메모요 사용)

`~/flutter` 의 `@Deprecated` annotation grep + 메모요 imports 교차. 메모요 imports = `flutter/material`, `flutter/cupertino`, `flutter/services`, `flutter/gestures`, `flutter/foundation`, `dart:ui`, `shared_preferences`, `google_sign_in`, `googleapis`, `file_picker`, `share_plus`, `extension_google_sign_in_as_googleapis_auth`, `sensors_plus`.

| # | Deprecated API | SDK 도입 시점 (deprecation) | 권장 대체 | 메모요 사용 | risk |
|---|----------------|---------------------------|-----------|------------|------|
| 1 | `ReorderableListView.onReorder` | v3.41.0-0.0.pre (commit 3e6c2071664, 2026-01-29) | `onReorderItem` | **6건** (lib L765/800 + test L61/65/114/116) | **HIGH** — PR #28 fix 가 backward 회귀로 박음 |
| 2 | `Color.withOpacity` | v3.27 (approx) | `Color.withValues(alpha:)` | 0 (이미 migrated, 6 곳 withValues) | n/a |
| 3 | `MaterialTextSelectionHandleControls` | v3.3.0-0.5.pre | `MaterialTextSelectionControls` | 0 | n/a |
| 4 | `CupertinoTextSelectionHandleControls` | v3.3.0-0.5.pre | `CupertinoTextSelectionControls` | 0 (메모요 `_LargeCupertinoSelectionControls extends CupertinoTextSelectionControls` 직접) | n/a |
| 5 | `MaterialTextSelectionControls.buildToolbar` | v3.3.0-0.5.pre | `contextMenuBuilder` | 0 (메모요 override 안 함) | n/a |
| 6 | `InputDecoration.maintainHintHeight` | v3.28.0-2.0.pre | `maintainHintSize` | 0 | n/a |
| 7 | `Tooltip.height` | v3.30.0-0.1.pre | `Tooltip.constraints` | 0 (Tooltip 사용 안 함) | n/a |
| 8 | Switch various params | v3.x | new params | 0 (Switch 사용 안 함) | n/a |
| 9 | RadioListTile various | v3.x | new params | 0 | n/a |
| 10 | ExpansionTile various | v3.x | new params | 0 | n/a |
| 11 | ProgressIndicator various | v3.x | new params | 0 (ProgressIndicator 사용 안 함) | n/a |
| 12 | Carousel various | v3.x | new params | 0 | n/a |
| 13 | CalendarDatePicker | v3.x | new params | 0 | n/a |
| 14 | Curves (specific) | v3.x | replacement | 0 | n/a |
| 15 | Dropdown | v3.x | DropdownMenu | 0 | n/a |
| 16 | ButtonBar / ButtonBarTheme | v3.x | OverflowBar | 0 | n/a |
| 17 | SelectableText (specific params) | v3.x | replacement | 0 | n/a |
| 18 | SliderTheme (specific) | v3.x | new params | 0 | n/a |
| 19 | ThemeData (some params) | v3.x | new params | 0 (default ThemeData) | n/a |

**Net**: HIGH risk 1건 (onReorder). 나머지 18 API 중 메모요 사용 0건. 메모요 코드가 평균 Flutter 앱 대비 깔끔한 편 — Karpathy 룰2 (simplicity first) 적용으로 표준 API 만 쓴 결과로 추정.

---

## 4. HIGH risk #1 — `onReorder` 처리 옵션

PR #28 (commit da81c43) 가 `onReorderItem → onReorder` backward 회귀 박은 이유: **노트북 fvm 3.41.9 (B 그룹) analyze 가 onReorderItem 미정의 reject** → 본진/WSL (A 그룹 3.44.0) 에서 PASS 받은 PR #23 코드를 strict 노드 catch → fix PR. 단 fix 방향이 forward (B 그룹 업그레이드) 가 아닌 backward (deprecated API 회귀).

### 옵션 A — 현재 상태 유지 (`onReorder` 그대로)
- Pros: 5 노드 다 PASS, fix 비용 0
- Cons: 미래 Flutter major (`onReorder` 제거 시점, 추정 4.x~5.x) 에서 회귀 → 그때 다시 migration PR 필요
- 비용: 미래 cost 미상

### 옵션 B — `onReorderItem` 으로 forward migration
- Pros: 표준 권장 API, 미래 회귀 0
- Cons: B 그룹 (맥미니/노트북 = 3.41.9) 가 reject → 본진 게이트 PASS 후 B 그룹 회귀 신호
- 전제: 5 노드 SDK 정책 (parent spec) 확정 + B 그룹 3.42.0+ 업그레이드 완료 후만 안전
- 비용: B 그룹 업그레이드 1회 + 본 migration PR 1회

### 옵션 C — 조건부 dual-callback (둘 다 박기)
- Flutter commit `3e6c2071664` 본문: "I added tests to ensure that the old callback is preferred when both are provided" — 둘 다 박으면 old (`onReorder`) 우선
- Pros: 5 노드 다 PASS (3.41.9 = onReorder 만 보고 onReorderItem param 무시; 3.44.0 = onReorder 우선 사용)
- Cons: 코드 노이즈 증가 (같은 콜백 두 번 박기) + dual-callback 패턴이 모든 widget 에 적용 가능한지 검증 필요 (ReorderableListView 외 일반화 불가능)
- 비용: 코드 중복 + 일반화 한계

### 추천
**옵션 B** (5 노드 SDK 정책 확정 후) → 미래 회귀 risk 0 + 표준 API. B 그룹 SDK 업그레이드 비용은 SDK 정책 spec [[5node-flutter-sdk-policy-brainstorm.md]] 의 옵션 1 (fvm 통일) 또는 옵션 2 v2 (게이트 강화) 와 묶음.

옵션 C 는 reorder 1건만 cover — 일반화 불가능이라 옵션 B 와 묶어 처리.

---

## 5. 후속 사이클 후보

- (a) SDK 정책 confirm 후 옵션 B 진입: 5 노드 SDK 정책 v1 확정 → B 그룹 3.42.0+ 업그레이드 → `onReorder → onReorderItem` migration PR 1회. lib L765/800 + test L61/65/114/116 = 6 라인.
- (b) 같은 cycle 의 별 audit — 다른 메모요 dependency (google_sign_in, googleapis, share_plus, file_picker, sensors_plus) 의 deprecation 점검. pubspec 의존성 22 건 newer version available (1.0.7 사이클 OAuth fix 시점 surface) — 의존성 마이그레이션 별 spec 후보.
- (c) Dart 3.12 → 미래 버전 deprecation — null safety / record / pattern 관련 변경 시 점검 후보. 현재 risk 0.

---

## 6. 본 audit 의 한계

- analyze info-level 만 잡는 deprecation 은 SDK 명시 `@Deprecated` 만. **소스 주석으로만 "deprecated" 표시된 패턴** (예: README, docs/) 은 grep 으로 별도 점검 필요. 본 audit 미실시.
- 메모요 외부 의존성 (Drive 백업의 googleapis, share_plus, file_picker 등) 의 deprecated API 사용 별 점검 필요 (§5 (b)).
- Flutter 3.45+ pre-release / master 의 deprecation 미반영 — 본 audit 는 3.44.0 stable 기준.
- 메모요 `_LargeCupertinoSelectionControls` 의 `buildHandle` 시그너처 (positional `[VoidCallback? onTap]` 포함) 가 미래 SDK 에서 변경될 가능성 — 현재 stable 에서 deprecation 0 이지만 추적 후보.
- 본 audit 작성 시점 (사이클 #7) 에 main 의 head = e4643ae (PR #35 머지 직후). 미래 사이클의 main 진화 시 본 spec 재검토 필요.

---

## 7. 결론

메모요 main 의 deprecated API 사용은 **`onReorder` 1건만 HIGH risk**, 나머지 18 후보 0. PR #28 backward 회귀 후속으로 forward migration 정책 결정 필요 (옵션 B 추천, 5 노드 SDK 정책 확정 후 진입).

본 audit 결과가 보여주는 더 깊은 패턴: 메모요 코드가 표준 Flutter API + 최신 권장 패턴 (`withValues`, `CupertinoTextSelectionControls`) 만 채택 — Karpathy 룰2 (simplicity first) 가 자연스럽게 deprecation 회피로 이어진 사례.

---

## 8. 본 audit 작성 시점 발견 — main HEAD analyze ERROR 2건 (사이클 #5 cascade 재현)

audit 작성 마무리에 본 PR 의 `merge-gate.sh` 호출 결과:

```
🔴 GATE FAIL [simple_memo_app / flutter]
  error • The function can't be unconditionally invoked because it can be 'null'.
         Try adding a null check ('!')
    • test/screens/memo_list_reorder_test.dart:65:7  • unchecked_use_of_nullable_value
    • test/screens/memo_list_reorder_test.dart:116:7 • unchecked_use_of_nullable_value
```

**관찰**: 본 audit PR (docs only, 코드 변경 0) 의 merge-gate 가 본진 위 (3.44.0 WSL) 에서 FAIL. 이유는 본 PR 의 docs 가 아닌 **main HEAD 자체** 의 `test/screens/memo_list_reorder_test.dart` (PR #34, commit a5f91ad 머지) 가 3.44.0 analyze 에서 error 2건 만들기 때문.

원인 분석:
- 3.42.0 commit `3e6c2071664` 가 `onReorder` 를 deprecate 하면서 시그너처를 `ReorderCallback?` (nullable) 로 변경.
- 3.41.9 (B 그룹) 는 변경 미포함 → 시그너처 `ReorderCallback` (non-nullable) → `reorderable.onReorder(0, 1)` 직접 호출 PASS.
- 3.44.0 (A 그룹) 는 변경 포함 → nullable → 직접 호출 시 `unchecked_use_of_nullable_value` ERROR. `!` (bang) 또는 `?` (null-aware) 필요.

PR #34 가 B 그룹 노드 (맥미니 또는 노트북) 에서 만들어졌을 가능성 — 거기는 PASS 받아 main 머지, A 그룹 (본진/WSL) 위에서 깨짐. **사이클 #5 cascade 패턴 재현** — PR #23 ↔ PR #28 사이클의 반대 방향.

### 권장 fix
- `reorderable.onReorder(0, 1)` → `reorderable.onReorder!(0, 1)` (또는 `reorderable.onReorder?.call(0, 1)`) 두 라인 (L65, L116) 만 변경
- 본 audit 와 별 surgical PR 또는 forward migration (`onReorder` → `onReorderItem`) PR 와 묶음 — 후자가 깔끔
- B 그룹 SDK 가 3.42.0+ 로 업그레이드된 후엔 `onReorderItem` migration 이 5 노드 다 PASS

### 의미
본 audit 작성 사이클에 정확히 본 audit 가 surface 한 패턴이 **두 번째 PR (PR #34)** 에서 재현됨 = SDK 정책 v1 확정 + B 그룹 업그레이드 시급성 강화. parent spec [[5node-flutter-sdk-policy-brainstorm.md]] 의 옵션 1 또는 옵션 2 v2 진입 우선순위 상승.

→ 형님 ack 후보: (1) main HEAD fix PR 우선 박기 (별 사이클) (2) 사이클 #6 의 SDK 정책 옵션 v1 확정 시점 가속 (3) B 그룹 SDK 업그레이드 + forward migration 묶음 PR
