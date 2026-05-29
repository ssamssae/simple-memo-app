# 메모요 onReorder→onReorderItem — 🪟 WSL 3.41.7 cross-check (2026-05-29)

**Status**: ✅ verify 완료 (docs only, 코드 변경 0) · 단 **A 그룹 검증 아님** (사유 §0)
**Author**: 🪟 WSL / 2026-05-29 KST · branch `wsl/memoyo-onreorder-a-group-verify-2026-05-29`
**Parent**: [[memoyo-onreorder-onreorderitem-migration.md]] (PR #43, 노트북 작성)
**노드 SDK**: Flutter **3.41.7** / Dart 3.11.5 (Windows `/mnt/c/src/flutter`)

---

## 0. ⚠️ 디렉티브 전제 충돌 — WSL 은 A 그룹이 아니다

사이클 #2 디렉티브는 "너 WSL 신버전 flutter = A 그룹(3.44.0)" 전제로 A 그룹 검증 3건을 배정. **실측 결과 충돌**:

- `cat /mnt/c/src/flutter/bin/cache/flutter.version.json` → `flutterVersion: 3.41.7`, `dartSdkVersion: 3.11.5`
- 즉 WSL 은 **3.41.7** — parent spec 의 B 그룹(3.41.9)보다도 **구버전**, A 그룹(3.44.0) 아님.
- `grep -c onReorderItem /mnt/c/src/flutter/.../widgets/reorderable_list.dart` → **0**. 3.41.7 에 `onReorderItem` API **부재**.

→ **A 그룹 검증 3건(§6.1 타입명 / §6.2 nullability / §6.3 실드래그)은 onReorderItem 이 존재해야 가능 → WSL 에서 수행 불가.** parent spec §6/§8 이 명시한 대로 진짜 A 그룹(3.44.0) 노드(spec 기준 🍎 본진)에서 해야 함. 본 문서는 그 대신 **3.41.7 old-API 앵커 cross-check** (eventual A 그룹 데이터와 대조용).

---

## 1. 3.41.7 에서 실측 가능한 것 (old-API 앵커)

| 항목 | 3.41.7 실측 |
|------|-------------|
| `onReorderItem` 존재 | ❌ 없음 (count 0) — 3.42.0+ 신규 확정 |
| `onReorder` nullability | **non-null** `final ReorderCallback onReorder;` (no `?`) — pre-3.42.0 |
| `onReorder` deprecated | ❌ 아님 (3.41.7 는 deprecation 도입 전 3.42.0 이전) |
| `ReorderCallback` typedef | `void Function(int oldIndex, int newIndex)` (reorderable_list.dart:71) |
| 메모요 핸들러 시그니처 | `_onReorderFav(int, int)` L521 / `_onReorderNormal(int, int)` L557 → `void(int,int)` = `ReorderCallback` 호환 |
| onReorder wiring | L765 `onReorder: _onReorderFav` / L800 `onReorder: _onReorderNormal` (spec §2 라인 일치) |
| PR #42 임시방편 현존 | `ignore_for_file: unnecessary_non_null_assertion, deprecated_member_use` + `onReorder!(...)` bang (test 2파일) 잔존 |

**축2(nullability) 교차 확인**: 3.41.7 onReorder 가 non-null 임을 실증 → parent spec §1 "pre-3.42.0 onReorder 는 non-null" 주장 확인. 이 노드에서 test 의 `onReorder!(...)` bang 은 `unnecessary_non_null_assertion` (ignore 로 침묵 중)이 맞다. **단 onReorderItem 자체의 nullability 는 부재로 확인 불가** → §6.2 는 A 그룹 위임 유지.

---

## 2. spec §3.2 정적 확인 — 핸들러는 이미 post-removal 좌표계 (✅ 이 노드에서 확정 가능)

`_onReorderFav`(L521-555) / `_onReorderNormal`(L557-589) 본문 정독 결과:

- 두 핸들러 모두 `if (oldIndex < newIndex) newIndex -= 1` **pre-removal 보정 없음**.
- 흐름: `removeAt(원본 인덱스)` → 그룹 인덱스 **재계산** → 원시 `newIndex` 의 재계산 위치(`newOriginalIndices[newIndex]`)에 `insert`.
- 이는 정확히 **post-removal 좌표계 = onReorderItem 계약**. → parent spec §3.2 / §0 핵심발견 **정적 확인**: migration 은 named param 이름만 교체, 핸들러 본문 변경 0.

이 검증은 SDK 버전 무관(소스 정독)이라 **3.41.7 에서도 100% 유효** — A 그룹 대기 불요.

---

## 3. spec §3.3 (아래방향 off-by-one) — 정적 precondition 확인 + 런타임 deferred

- **precondition 확인 (static)**: 핸들러에 보정이 없고(§2), 3.41.7 `onReorder` 는 프레임워크 관례상 pre-removal "insert-before" newIndex 를 전달 → **현재 wiring 에서 그룹 내 아래방향 실드래그는 구조적으로 한 칸 어긋남**(spec §3.3 trace `[F1,F2,F3]`→`[F2,F3,F1]`)의 precondition 이 3.41.7 에서 성립.
- **런타임 재현 deferred**: 실드래그 통합 테스트는 (a) parent spec L105 가 명시한 nested-scroll+shrinkWrap flaky 위험, (b) 본 사이클 docs-only 지시, (c) WSL 환경상 memoyo `flutter test` 가 plugin symlink(Developer Mode) 로 막힘(§5) — 3가지로 본 노드 런타임 실증 보류. **migration 전/후 실드래그 정상화 최종 확정은 A 그룹(3.44.0) 권장** (spec STEP 3 그대로).

---

## 4. A 그룹(3.44.0) 위임 잔여 (WSL 불가 항목)

| spec §6 | 내용 | WSL 3.41.7 | 위임 |
|---------|------|------------|------|
| 1 | onReorderItem 콜백 타입명 (`ReorderCallback` 유지? 신규 typedef?) | 부재로 불가 | 🍎 본진 3.44.0 |
| 2 | onReorderItem nullability (`!` bang 유지 여부) | 부재로 불가 | 🍎 본진 3.44.0 |
| 3 | 실드래그 migration 전(버그)·후(정상) 재현 | onReorderItem 부재 + 환경 제약 | 🍎 본진 3.44.0 |

---

## 5. 환경 메모 (WSL gate 한계)

- merge-gate.sh / `flutter analyze` 직접 실행은 WSL→Windows cmd.exe UNC cwd 거부로 불가 → rsync→Windows wrapper 사용.
- 메모요는 plugin(googleapis/share_plus/file_picker/sensors_plus) 다수 → rsync temp 빌드가 "requires symlink support / enable Developer Mode" 로 막혀 **3.41.7 analyze baseline 도 미완**. 본 PR 은 docs-only(코드 변경 0)라 analyze 영향 자체 없음 — 실 게이트는 본진/맥미니 위임.

---

## 6. 결론

1. **WSL ≠ A 그룹** (3.41.7) — A 그룹 검증 3건은 본진 3.44.0 으로 재라우팅 필요. (SDK skew cascade 룰 그대로 — 노드 SDK 가정 실측 확인 필수)
2. 3.41.7 에서 확정한 것: onReorderItem 부재 / onReorder non-null·미deprecated / 핸들러 post-removal 좌표계(spec §3.2 ✅) / §3.3 precondition 성립.
3. migration 진짜 fix 진입은 parent spec STEP 1(B 그룹 3.42.0+ 업그레이드) blocker 그대로 — SDK 정책 v1 확정 후.
