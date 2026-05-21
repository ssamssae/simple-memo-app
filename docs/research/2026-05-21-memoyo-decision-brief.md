# 메모요 1.0.7 / 1.1.x — 형님 결정 브리프 (1장 통합)

- 작성일: 2026-05-21 (KST) · 작성자: 💻 노트북3060 (autopilot 낮 사이클)
- 상태: **read-only 의사결정 브리프** — 흩어진 설계 3건을 형님이 한 번에 결정하도록 통합. 코드 변경 0.
- 통합 대상:
  - ① `docs/specs/1.0.7-data-safety-ux.md` (🖥 데스크탑) — 1.0.7 4항목(Drive/UNDO/공유/휴지통)
  - ② `docs/research/2026-05-21-memoyo-1.1.x-multidevice-sync-research.md` (💻) — 1.1.x 동기화
  - ③ `docs/research/2026-05-21-memoyo-tombstone-trash-unified-schema.md` (💻) — tombstone↔휴지통 통합
  - (+참고) `docs/superpowers/specs/2026-05-19-memoyo-drive-export-design.md` (🍎 본진) — Drive 1버튼 백업 별 spec

---

## 0. 가장 먼저 — Drive 백업 spec 이 둘인데 서로 충돌함 (BLOCKER)

같은 "1.0.7 Drive 백업" 기능에 **두 개의 설계가 존재하고 서로 다르다.** 1.0.7 진입 전 택1 필수:

| 항목 | ① data-safety-ux.md (🖥) | ④ drive-export-design.md (🍎 본진) |
|------|--------------------------|-------------------------------------|
| 저장 위치 | `appDataFolder` (Drive UI 안 보임) | 가시 "Memoyo" 폴더 (사용자가 봄) |
| OAuth scope | `drive.appdata` | `drive.file` |
| 인증 패키지 | `googleapis_auth` | `extension_google_sign_in_as_googleapis_auth` |
| rotate | 명시 없음 | N=7 자동 |
| import(복구) | 백업 리스트 다이얼로그 | 본 spec 범위 밖(file_picker 유지) |
| 철학 | "사용자 Drive 안 어지럽힘" | "어디 갔는지 항상 보이게(CS 0)" |

→ **두 철학이 정반대**(숨김 vs 가시). 더 최신/구체적이고 본진 작성인 ④ 가 우세해 보이나, ①의 "복구 리스트 UX"는 ④에 없음. **추천: ④(가시 Memoyo + drive.file + rotate) 를 1.0.7(1) 정본으로, ①의 복구 다이얼로그 UX 만 흡수.** 형님 택1 필요.

---

## 1. 결정점 통합 표 (우선순위순)

🔴=블로커(이거 안 정하면 진행 불가) · 🟡=출시 전 필요 · 🟢=저위험·추천대로 가도 됨

| # | 결정점 | 옵션 | 추천 | 우선 | 출처 |
|---|--------|------|------|------|------|
| D1 | **Drive 백업 spec 통일** | ①appData / ④가시Memoyo | ④ + ①복구UX 흡수 | 🔴 | §0 |
| D2 | **purgedAt 선반영 여부** (휴지통 단독 출시에 sync용 tombstone 강등 + 단일 updatedAt bump 미리 넣을지) | 선반영 / 나중에 | **선반영** (1.1.x 때 삭제경로 재작업 회피) | 🔴 | ③ |
| D3 | 동기화 트리거 | 수동버튼 / 포그라운드자동 / 백그라운드 | 포그라운드자동 (단 1.0.7 "백그라운드sync 금지"박제 완화 ack 필요) | 🔴(1.1.x) | ② |
| D4 | 백엔드 분기 | 플랫폼네이티브(iOS=iCloud/And=Drive) / Drive단일 / 사용자선택 | 플랫폼네이티브 | 🟡(1.1.x) | ② |
| D5 | 충돌 정책 | 순수LWW+동률보존 / 강한보존(삭제항상짐) | 순수LWW + 동률 시 보존우선 | 🟡(1.1.x) | ②③ |
| D6 | tombstone TTL | 90일 / 그외 | 90일 | 🟡(1.1.x) | ③ |
| D7 | 1.0.7 출시 분할 | 단일 / a(휴지통+UNDO+공유)→b(Drive) | **a→b 분할** | 🟡 | ① |
| D8 | backup JSON 에 tombstone 포함 | 포함 / 제외 | 포함 | 🟢 | ③ |
| D9 | UNDO 스낵바 윈도우 | 5/7/10초 | 5초 | 🟢 | ① |
| D10 | 휴지통 진입점 | 항상노출 / 비었을때숨김 | 항상노출 | 🟢 | ① |
| D11 | 휴지통 일괄선택 | MVP(단일+전체비우기) / full | MVP | 🟢 | ① |
| D12 | 즐겨찾기 복구 위치 | 끝복귀 / anchor저장 | 끝복귀 | 🟢 | ① |
| D13 | 휴지통 정렬 | 최근삭제위 / 임박위 | 최근삭제위 | 🟢 | ① |
| D14 | Drive 미지원지역 fallback | 0 / share_plus유지 | 0(별사이클) | 🟢 | ① |
| D15 | hard-delete UI 문구 | "완전삭제"유지 / tombstone설명 | 문구 미세조정(흔적만 남고 content 즉시 비움) | 🟢 | ③ |

> 형님이 실제로 멈춰서 골라야 하는 건 🔴 3개(D1·D2·D3) + 🟡 4개(D4·D5·D6·D7). 🟢 8개는 추천대로 가도 무방.

---

## 2. 의존 그래프 — 무엇이 무엇을 막나

```
[D1 Drive spec 통일] ──┬─→ 1.0.7(1) Drive 백업 구현
                        └─→ 1.1.x Drive 동기화 백엔드(같은 인증/위치 재사용)

1.0.7-a(휴지통+UNDO+공유, 코드만·패키지X)
   │  └─ deletedAt 도입
   ↓
[D2 purgedAt 선반영?]
   ├─ YES → 휴지통이 sync-ready (tombstone 강등 + 단일 updatedAt bump 내장)
   │         → 1.1.x 는 merge() 순수함수 + pull/push 만 얹으면 끝
   └─ NO  → 1.1.x 진입 시 삭제경로 전면 재작업(회귀 위험)

tombstone 스키마(③) ── 필요로 함 ──→ 1.1.x 동기화(부활 차단의 전제)

1.1.x 동기화
   ├─ 필요: [D4 백엔드분기] [D5 충돌정책] [D6 TTL]
   └─ [D3 트리거=포그라운드자동] ── 전제 ──→ 1.0.7 "백그라운드sync 금지" 박제 완화 ack
```

핵심 읽기:
- **1.0.7-a(휴지통/UNDO/공유)는 1.1.x 와 무관하게 지금 출시 가능** — 동기화 결정(D3~D6) 대기 안 해도 됨.
- **단 D2(purgedAt 선반영)만은 1.0.7-a 진입 전에 정해야** — 휴지통 코드를 한 번만 짜려면. 추천대로 선반영하면 휴지통이 곧 sync 토대가 됨.
- **D1(Drive spec)은 1.0.7(1)과 1.1.x Drive 동기화 둘 다의 공통 블로커** — 인증·저장위치를 1.1.x 가 재사용하므로 여기서 정한 게 끝까지 감.
- **1.0.7 박제("버튼 누를 때만 데이터 이동")와 1.1.x "동기화"는 정면 충돌** — D3 에서 포그라운드 자동 이상을 고르면 박제를 의도적으로 완화하는 결정이라 형님 명시 ack 필요.

---

## 3. 추천 진행 순서 (한 줄 요약)

1. **형님: D1·D2·D3 먼저 결정** (나머지는 추천대로 가도 됨).
2. **1.0.7-a**: 휴지통 + 5초 UNDO + 단일메모 공유. 코드만(패키지 추가 X). D2=선반영이면 `purgedAt`/단일 `updatedAt` bump 동시 적용 → sync-ready.
3. **1.0.7-b**: Drive 백업 (D1 결정 spec 대로, rotate N=7).
4. **1.1.x**: 동기화 — `merge(local,remote)` 순수함수 + pull/push. Drive 먼저(크로스플랫폼, 1.0.7-b 자산 재사용) → iCloud 후속(iOS 한정, zero-login).

---

## 부록 — 원본 결정점 매핑

- ① data-safety-ux §6 의 7개 → D1·D9·D10·D11·D12·D13·D14, §7 → D7
- ② sync 리서치 §11 의 4개 → D3·D4·D5(+D1 Drive 함의)
- ③ tombstone 스키마 §9 의 5개 → D2·D5·D6·D8·D15
