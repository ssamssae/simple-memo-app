# 메모요 1.0.8 — 묶음 결정 비교 spec

**Status**: 🟡 draft · 형님 ack 대기 (본진 RED 큐 surface 용)
**Author**: 💻 노트북 / 2026-05-29 KST · branch `notebook/memoyo-1.0.8-bundle-decision-2026-05-29`
**Repo**: ssamssae/simple-memo-app
**입력 spec**: [[1.0.8-trash-30day.md]] (PR #36, 491L) · [[1.0.8-search.md]] (PR #38, 359L) · [[1.0.8-drive-di-hooks.md]] (PR #41, 403L) · [[1.0.8-backlog-ideas.md]] (PR #29)
**의도**: 세 1.0.8 후보 spec 이 모두 작성됐으나 ack-pending. 형님이 한 번에 묶음 결정할 수 있도록 옵션 (b)~(e)를 **작업 분량 / cascade 영향 / 사용자 가치 / 1.0.7 GA 충돌** 4축으로 비교 + 노트북 추천 1안. **결정 아닌 비교 — 형님 ack 시 좁힘.**

---

## §0 공통 전제 (모든 옵션 무관, 코딩 진입 2 게이트)

어느 옵션을 고르든 1.0.8 코드 작업은 아래 두 게이트를 **둘 다** 통과해야 진입:

1. **1.0.7 GA manual QA PASS** (PR #29 §7 룰) — 세 spec 전부 명시한 hard 전제. 1.0.7 GA spec ([[1.0.7-ga-qa-scenarios.md]]) 가 형님 manual QA 통과 전 1.0.8 코딩 0.
2. **SDK 정책 v1 확정** ([[memoyo-onreorder-onreorderitem-migration.md]] §5) — 새 코드가 cross-SDK lint cascade 재발 안 하려면 5 노드 SDK floor 통일 선행. RED 큐 (B 그룹 fvm 강제 변경 = 외부영향 비가역).

→ 본 spec 의 묶음 결정은 "**어떤 기능을, 어떤 순서로**"만 정함. "언제 코딩 시작"은 위 2 게이트가 별도로 잠금.

---

## §1 후보 3종 요약

| 후보 | spec | 작업 분량 | 코드 영향 영역 | 데이터 모델 변경 |
|------|------|-----------|----------------|------------------|
| **휴지통 30일** | PR #36 (491L) | **큼** — 데이터 모델 + 영속 필터 + GC 정책 + 휴지통 화면 신설 + Drive 백업 호환 결정 (open Q 5개) | `Memo` 모델 + `MemoStorage` + 신규 휴지통 화면 + overflow 메뉴 | **있음** (`deletedAt: DateTime?`) |
| **검색** | PR #38 (359L) | **작~중** — AppBar 검색 UX + pure `SearchService` 함수 + RichText highlight (list item builder 1곳) | AppBar UX + list item builder + pure 함수 | **없음** |
| **DI 훅** | PR #41 (403L) | **최소(surgical)** — 2 static field + 2 setter + 1 getter, 단일 파일 | `drive_backup_service.dart` **단독** | **없음** |

DI 훅은 사용자向 기능이 아니라 **테스트 인프라** — widget-level full mock 갭(GA QA 6 시나리오)을 자동화 가능케 함.

---

## §2 4축 비교 매트릭스

| 옵션 | 구성 | 작업 분량 | cascade 영향 | 사용자 가치 | 1.0.7 GA 충돌 가능성 |
|------|------|-----------|--------------|-------------|----------------------|
| **(b)** | 휴지통 + 검색 | 중간 (두 기능, 코드 영역 독립) | 0¹ | **높음** — 데이터 손실 갭 + 탐색 갭 두 핵심 동시 메움 | **중** — 휴지통이 삭제 flow/Drive 백업 JSON 과 상호작용 |
| **(c)** | 휴지통 단독 | 중 (단일 기능, 분량 큼) | 0¹ | **최고** — 데이터 손실 방지(노트앱 존립 불안 해소) | **중** — 삭제 flow + 데이터 모델 변경이 1.0.7 UNDO 경로와 상호작용 |
| **(d)** | 검색 단독 | 작 (self-contained) | 0¹ | **중** — dogfood ≈150건, 임계 ~200 아직 미도달. iOS Notes/Keep 디폴트 부재 학습 부담만 | **0** — additive AppBar, 기존 flow 변경 0 |
| **(e)** | 휴지통 + 검색 + DI 훅 | 중~큼 (1.0.8 표면 최대) | 0¹ | **높음** + 회귀 안전망 강화(간접) | **중**, 단 DI 훅이 GA QA 6 시나리오 **자동화로 흡수** → 오히려 GA risk ↓ |

¹ cascade 영향 0 근거: 세 기능 모두 `ReorderableListView`/`onReorder` 무관. cross-SDK lint cascade(PR #23~#42)는 reorder 콜백 nullability/deprecation 축이라 본 기능들과 직교. 단 §0 게이트 2(SDK 정책 v1)는 모든 코드 작업 공통 전제.

### 축별 보충

**작업 분량**: 휴지통 ≫ 검색 ≫ DI. 휴지통은 데이터 모델 마이그레이션(`deletedAt: null` 호환) + GC trigger 정책(cold-start sweep 추천, 백그라운드 isolate 회피) + 신규 화면 + Drive 백업 포함 여부(open Q (a))까지 결정 폭이 가장 넓다. 검색은 scope 최소화 옵션 채택(검색 history 없음 등)으로 self-contained. DI 는 단일 파일 surgical.

**사용자 가치**: 휴지통 > 검색. 휴지통 = 데이터 손실 방지(1.0.7 UNDO 4초 ↔ Drive 백업 사이 장기 갭). 검색 = dogfood 가 임계(~200건) 미도달이라 가치 발현 지연. DI 는 직접 가치 0, 간접(테스트 자동화·미래 회귀 base).

**1.0.7 GA 충돌**: 검색·DI = 0(검색은 additive, DI는 별 파일+GA QA 흡수). 휴지통 = 중(삭제 flow·데이터 모델·Drive 백업 JSON 포맷이 1.0.7 가 막 ship 한 UNDO/백업과 직접 맞물림). → 휴지통이 들어가는 옵션(b/c/e)은 GA 회귀 검증 부담이 더 크고, DI 훅이 그 부담을 widget-level 자동화로 일부 상쇄.

**묶음 시 노드 분담**: 휴지통(데이터+화면)과 검색(AppBar+pure fn)은 코드 영역이 영구 분리 → (b)/(e)에서 2 노드 병렬 가능(merge conflict 0). DI 훅은 `drive_backup_service.dart` 단독이라 셋 다 충돌 0(검색 spec §7·DI spec §3 명시). 검색-in-휴지통 시너지(검색 spec §4 휴지통 전용 검색)는 (b)/(e)에서만 한 번에 처리 → (d)→나중 휴지통 시 검색 rework 발생.

---

## §3 노트북 추천

**추천: (e) — 단 DI 훅을 선행 enabling 트랙으로 두고, 휴지통+검색은 (b) 묶음 2 노드 병렬.**

근거:
1. **DI 훅은 미룰 이유가 없다** — surgical(단일 파일)·충돌 0·사용자向 0·GA QA 6 시나리오 자동화 흡수. 어느 기능을 ship 하든 먼저 박으면 widget-level 회귀 자동화가 **휴지통의 데이터 모델 변경 risk 를 덮어준다**. 거의 순수 이득.
2. **휴지통+검색은 분리보다 묶음이 총비용 낮다** — 코드 영역 독립이라 2 노드 병렬 가능 + 검색-in-휴지통 시너지로 검색 rework 회피. (c)/(d) 분리는 시너지 상실 + 두 번의 GA 사이클.
3. **trade-off 명시**: (e)는 1.0.8 표면이 최대 → GA 사이클이 가장 길다. **데이터 안전 최속 ship 이 우선이면 (c) 휴지통 단독이 보수적 fallback** (검색은 dogfood 200 도달 시 1.0.9). 검색만(d)은 가치-우선순위 역전이라 비추.

---

## §4 본 spec 의 한계

- 작업 분량은 spec 라인 수 + 코드 영향 영역 기반 정성 추정 — 실제 man-hour 미산정.
- "1.0.7 GA 충돌 중/높음"은 삭제 flow·데이터 모델·Drive JSON 상호작용에 대한 정성 판단 — 본진/맥미니 코드 review 로 확정 필요.
- dogfood 메모 건수(≈150)·검색 임계(~200)는 검색 spec §1·limitations 가정 그대로 인용 — 실측 변동 시 (d) 우선순위 재평가.
- 본 비교는 §0 게이트 2건 통과 후의 "무엇/순서"만 다룸 — SDK 정책 v1(RED) 자체는 [[memoyo-onreorder-onreorderitem-migration.md]] + morning-report 소관.
- 작성 시점 main HEAD = `9bccb08` (PR #43 머지 직후).
