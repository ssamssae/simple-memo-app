# 메모요 휴지통 30일 spec 보강 — tombstone(sync) 정합 델타

**Status**: 🟡 draft · 형님 ack 대기 (선반영 결정 §4) + 본진 review 펜딩
**Author**: 💻 노트북 / 2026-05-29 KST · branch `notebook/memoyo-trash-30d-tombstone-2026-05-29`
**Repo**: ssamssae/simple-memo-app
**보강 대상**: [[1.0.8-trash-30day.md]] (PR #36, 491L — 휴지통 메커니즘 canonical spec)
**베이스 입력**: [[../research/2026-05-21-memoyo-tombstone-trash-unified-schema.md]] (PR #17 tombstone 통합 스키마 설계)

---

## §0 왜 이 문서인가 (중복 회피 선언)

T-260529-07 디렉티브는 "휴지통 30일 spec 보강 (PR #17 tombstone 노트 베이스)"을 요청. 그런데 **휴지통 메커니즘 자체** (Memo.deletedAt, toJson/fromJson, copyWith, GC 알고리즘, 휴지통 화면 UX, 일반 화면 필터, UNDO 분기, 회귀 안전망, GA QA, 작업 단위 split) 는 [[1.0.8-trash-30day.md]] 가 **이미 구현 가능 깊이로 완비** (491L, 코드 스켈레톤 포함, §9 위임 작업 단위 (1)~(5)까지). 같은 내용을 다시 쓰면 순수 중복.

**실제 미흡 지점**은 하나 — `1.0.8-trash-30day.md` 가 **1.1.x 다기기 sync 와의 정합을 전혀 모름** (`grep tombstone|sync|다기기` = 0건). 그 spec 의 GC §3.2 가 만료 메모를 **레코드 통째 제거**하는데, 이게 PR #17 노트가 경고한 **부활(resurrection) 함정**이다. 본 문서는 그 **단일 갭만** 메우는 델타 — 휴지통 메커니즘은 [[1.0.8-trash-30day.md]] 그대로 두고, **GC/스키마만 sync-forward-compatible 하게 보강**한다.

> 명명 비고: 디렉티브 파일명 `memoyo-1.0.7-trash-30d.md` 는 현행 canonical 스펙명 `1.0.8-trash-30day.md` 과 버전 충돌(휴지통이 1.0.7→1.0.8 carry) + 중복 오인 소지 → 본 보강은 목적이 드러나는 이름으로 분리. 본진 review 시 1.0.8-trash-30day.md 에 흡수할지 동반 유지할지 결정.

---

## §1 문제 — 휴지통 GC 가 미래 sync 를 깨뜨린다

`1.0.8-trash-30day.md` §3.2 GC 알고리즘:

```dart
// 현행 spec — 만료 메모를 survived 에서 제외하고 통째 제거
if (m.deletedAt != null && now.difference(m.deletedAt!).inDays > 30) {
  purged.add(m);          // ← 레코드 자체가 사라짐
} else { survived.add(m); }
await _saveRaw(survived);
```

1.1.x 다기기 sync 의 병합 = 같은 `id` 는 LWW, 다른 `id` 는 **union(합집합)**. union 이 부활을 만든다:

- **30일 auto-purge 부활**: 기기 A 가 만료 메모를 통째 제거 → 기기 B 는 아직 보유 → union 시 "A 에 없고 B 에 있음" → A 에서 **되살아남**.
- **hard-delete 부활**: "즉시 영구삭제 / 휴지통 비우기" 도 흔적 없이 제거 → 동일 부활.

→ 휴지통을 sync 무관하게 먼저 내고 1.1.x 에서 tombstone 을 별 필드로 또 도입하면 **삭제 경로를 두 번 건드림** (중복 작업 + 회귀 위험). PR #17 노트 §8 의 핵심 경고.

---

## §2 델타 — `purgedAt` 2상태 (PR #17 §3 채택)

휴지통 메커니즘에 **필드 1개 + sweep 1줄 변경**만 얹는다.

```dart
class Memo {
  // ... 1.0.8-trash-30day.md §2.1 그대로 (deletedAt 포함) ...
  DateTime? purgedAt; // NEW — tombstone 확정 시각 (content 비워진 시점)
}
```

레코드 3상태:

| 상태 | 조건 | content | 가시성 | sync |
|------|------|---------|--------|------|
| active | `deletedAt == null` | 있음 | 일반 리스트 | 정상 메모 |
| trashed | `deletedAt != null && purgedAt == null` | **보존** | 휴지통 화면 | 메모 + 휴지통 상태 |
| tombstone | `purgedAt != null` | **""** (비움) | 안 보임 | 부활 차단 흔적 |

**GC sweep 변경** (1.0.8-trash-30day.md §3.2 를 2단계로):

```text
sweep(now):
  for m in all:
    if m.purgedAt == null and m.deletedAt != null and m.deletedAt < now - 30d:
        m.purgedAt = now; m.content = ""; m.updatedAt = now   # 제거 아닌 강등
    elif m.purgedAt != null and m.purgedAt < now - TOMBSTONE_TTL:
        drop m                                                  # TTL 후 완전 제거
  save survivors
```

호출 위치(cold start + app resume)는 trash spec §3.1 그대로. **변경의 전부 = "리스트에서 제거" → "tombstone 강등"** 1줄 + TTL 후 제거 분기 1줄.

부수 변경 (모두 trash spec 에 얹는 surgical 델타):
- `loadMemos` 필터: 일반 리스트는 `deletedAt == null` (기존). 휴지통 화면은 `deletedAt != null && purgedAt == null` (tombstone 제외).
- `toJson`: `if (purgedAt != null)` 조건부 키 → active/trashed 메모는 키 없음 (용량 0 증가, 하위호환).
- `fromJson`: 누락 필드 default null (기존 패턴, 구버전 데이터 무손실).
- **모든 변이가 `updatedAt` bump** (휴지통 이동/복구/강등 포함) — 1.1.x LWW 단일 비교축. ← trash spec 가 명시 안 한 부분, 선반영 시 필수.

---

## §3 두 보존기간 분리 (PR #17 §5)

| 기간 | 상수(안) | 목적 | content |
|------|----------|------|---------|
| 휴지통 보존 | 30일 (trash spec 그대로) | 사용자 실수 복구 윈도우 | 보존 |
| tombstone TTL | **90일 제안** | 부활 차단 | 비움 |

- 휴지통 30일 만료 → tombstone 강등(content 비움) → 추가 TTL 만큼 흔적 유지 → TTL 경과 시 완전 제거.
- 잔여 위험: 기기가 TTL(90일)보다 오래 오프라인이면 부활 가능. 메모요는 데이터 양 작아 빈 레코드 누적 부담 ≈ 0 → TTL 넉넉히 잡아도 비용 무시. release note 1줄 권장("아주 오래 미사용한 기기에서 삭제한 메모가 드물게 다시 보일 수 있음").

---

## §4 핵심 형님 결정 — 선반영 vs 미루기 (PR #17 §9-3)

**질문**: 휴지통(1.0.8)을 sync 없이 먼저 내되 `purgedAt` + 단일 `updatedAt` bump 를 **선반영**할까, 아니면 휴지통은 `deletedAt` 만으로 내고 1.1.x sync 때 다시 손댈까?

**노트북 추천: 선반영 (purgedAt + updatedAt bump 을 1.0.8 에 미리 박기).**

근거:
1. **삭제 경로를 두 번 안 건드림** — 1.0.8 휴지통 PR 에서 sweep 1줄 + 필드 1개만 더 얹으면, 1.1.x sync 는 `merge(local,remote)` 순수함수 + pull/push 만 추가하면 됨. 미루면 1.1.x 에서 삭제/UNDO/purge 코드 전체를 재오픈 (회귀 위험 재발).
2. **비용 거의 0** — 메모요는 단일 SharedPreferences blob + 데이터 양 작음. purgedAt 1필드·빈 레코드 누적 부담 무시 가능.
3. **사용자 가시 동작 불변** — tombstone(content="")은 안 보임. 선반영해도 1.0.8 사용자 경험은 trash spec 와 동일.

**미루기(defer) fallback**: 1.1.x 다기기 sync 자체가 형님 결정 미정/먼 미래라면, deletedAt 만으로 내고 sync 진입 시점에 재설계도 가능. 단 위 1번 비용(경로 2회 수정)을 감수.

---

## §5 남은 열린 질문 (형님 ack 좁힘 — PR #17 §9 잔여)

1. tombstone TTL 상수 — 90일? (오프라인 부활 위험 vs 빈 레코드 누적, 메모요는 후자 부담 0)
2. backup/restore JSON 에 tombstone 포함? — **포함 권장** (다른 기기 복구 시도 부활 차단 일관). export 시 tombstone 제외 옵션은 1.0.9 후보.
3. hard-delete("즉시 영구삭제")도 tombstone 강등으로? — 사용자 기대("지금 완전 지웠다")와 어긋남. content 는 즉시 비우되 흔적만 남음 → UI 문구 조정 필요 여부.
4. 충돌 정책 — 순수 LWW + "동률 시 보존 우선"으로 확정? (1.1.x sync spec 소관, 본 보강은 updatedAt bump 만 선반영)

---

## §6 전제 + 한계

- **코딩 진입 2 게이트** (모든 1.0.8 작업 공통, [[memoyo-1.0.8-bundle-comparison.md]] §0): (1) 1.0.7 GA manual QA PASS (PR #29 §7) (2) SDK 정책 v1 확정. 본 보강도 동일 게이트.
- **spec only, 코드 X.** 본 문서는 1.0.8-trash-30day.md 에 얹는 델타 — 구현 노드가 흡수.
- PR #17 노트는 옛 스펙명 `1.0.7-data-safety-ux.md` §2.x 를 참조 — 휴지통 메커니즘이 그 후 `1.0.8-trash-30day.md` (PR #36)로 이관됨. 본 보강은 현행 canonical (1.0.8-trash-30day.md) 기준.
- **미검증**: 30일/TTL GC 의 자동 위젯 테스트가 `FakeAsync`/`Clock` 로 시간 mock 가능한지 (1.0.8-trash-30day.md §8.2 도 미검증으로 남김). 구현 노드가 첫 작업 단위에서 verify 필요 — 3.41.9 노드에서 throwaway probe 가능하나 본 사이클 "코드 X" 가드로 미실행.
- 작성 시점 main HEAD = `9bccb08` (PR #43 머지 직후).

---

## §7 구현 노드 흡수 가이드 (1 노드 위임 시)

1.0.8-trash-30day.md §9 작업 단위 (1)~(5) 에 **본 보강 델타를 (1)(2)에 병합**:
- 작업단위 (1) 모델: `deletedAt` + **`purgedAt` 동시 추가** + 모든 변이 `updatedAt` bump.
- 작업단위 (2) MemoStorage: GC 를 **2단계 sweep**(강등→TTL 제거)으로, loadTrash 는 tombstone 제외 필터.
- (3)(4)(5) 휴지통 UI / soft-delete / 일괄액션 = trash spec 그대로 (델타 없음).
- 회귀 안전망: trash spec §6 + "tombstone 강등 후 일반/휴지통 양쪽 리스트에서 안 보임" 시나리오 1건 추가.
