# 메모요 1.1.x 다기기 동기화 — 자율 cron 진행 트래커

- 생성: 2026-05-24 22:32 KST · 🍎 본진 (memoyo-sync-loop 45분 cron 첫 부트스트랩 fire)
- 브랜치: `mac/memoyo-sync-2026-05-17`
- 입력 설계 (전부 read-only, 결정 아님):
  - `docs/research/2026-05-21-memoyo-decision-brief.md` — 통합 결정 브리프 (🔴/🟡/🟢 15개)
  - `docs/research/2026-05-21-memoyo-1.1.x-multidevice-sync-research.md` — 동기화 사전 리서치
  - `docs/research/2026-05-21-memoyo-tombstone-trash-unified-schema.md` — tombstone+휴지통 통합 스키마

## 현재 단계

**Stage 0 — 형님 🔴 BLOCKER 3개 ack 대기 (HOLD)**

decision-brief §1 이 명시: 형님이 실제로 멈춰서 골라야 하는 건 🔴 3개 (D1·D2·D3). 추천대로 자율 진입 = 박제 위반 위험 (특히 D3 가 1.0.7 "백그라운드 sync 금지" 박제 완화 ack 필요). 다음 cron fire 들은 D1/D2/D3 ack 들어올 때까지 **no-op + Telegram 침묵**. 형님 ack 후 Stage 1 진입.

### 형님 결정 대기 중 (🔴 BLOCKER)

- [ ] **D1 Drive 백업 spec 통일** — 추천: ④ (가시 Memoyo + `drive.file` + rotate N=7) + ① 의 복구 리스트 다이얼로그 UX 흡수. 출처 = decision-brief §0/§1.
- [ ] **D2 `purgedAt` 선반영 여부** — 추천: 선반영 (1.0.7-a 휴지통 진입 전 박아두면 1.1.x 가 `merge()` 순수함수 + pull/push 만 얹으면 끝). 출처 = decision-brief D2, tombstone-schema §3/§5.
- [ ] **D3 동기화 트리거** — 추천: 2번 (앱 포그라운드 진입 자동 pull + 변경 자동 push). **단 1.0.7 §2 "백그라운드 sync 금지" 박제 완화 ack 필요** — 박제 못 풀면 1번(수동 버튼)으로 후퇴 (진정한 sync 아님, "백업/복원의 1버튼화"). 출처 = sync-research §5, decision-brief D3.

### 🟡 출시 전 필요 (D3 ack 함께 결정 권장)

- [ ] **D4 백엔드 분기** — 추천: (a) 플랫폼 네이티브 디폴트 (iOS=iCloud, And=Drive, 크로스플랫폼 사용자는 수동 Drive 선택).
- [ ] **D5 충돌 정책** — 추천: 순수 LWW + 시계오차 ±2초 동률 시 보존 우선.
- [ ] **D6 tombstone TTL** — 추천: 90일.
- [ ] **D7 1.0.7 출시 분할** — 추천: a(휴지통+UNDO+공유) → b(Drive). 1.0.7-a 가 sync 의 토대.

### 🟢 추천대로 진행 (별 ack 없이 OK)

- [ ] D8 backup JSON 에 tombstone 포함 / D9 UNDO 5초 / D10 휴지통 진입점 항상노출 / D11 일괄선택 MVP / D12 즐겨찾기 끝복귀 / D13 휴지통 최근삭제위 / D14 Drive 미지원지역 fallback 0 / D15 hard-delete 문구 미세조정.

---

## 단계적 경로 (decision-brief §3, 형님 ack 시 진입 순서)

### Stage 1 — 1.0.7-a + purgedAt 선반영 (D2=선반영 ack 후)

목표: 휴지통 + 5초 UNDO + 단일메모 공유. 코드만 (패키지 추가 X). `Memo` 모델에 `deletedAt` + `purgedAt` 2필드 + 모든 변이가 `updatedAt` bump.

- [ ] `Memo` 모델에 `deletedAt` / `purgedAt` 추가 + `toJson`/`fromJson` 하위호환 (누락 필드 기본값).
- [ ] `MemoStorage` soft-delete 전환: `removeWhere` → `copyWith(deletedAt: now, updatedAt: now)`.
- [ ] `purgeExpiredTrash()` 2단계 sweep: 30일 → tombstone 강등 (content="", `purgedAt=now`, `updatedAt=now`) → TTL 90일 → drop.
- [ ] 휴지통 화면 + 복구/영구삭제 UI (1.0.7-data-safety-ux spec 그대로).
- [ ] 5초 UNDO 스낵바.
- [ ] 단일메모 공유 (share_plus).
- [ ] **TDD**: `merge(local, remote)` 순수함수 단위 테스트 — Memo 모델 의존만, 백엔드 mock 0. 케이스: 같은 id LWW, 다른 id union, tombstone 부활 차단, 30일 만료 강등, TTL 만료 drop, content vs tombstone tie-break.

### Stage 2 — 1.0.7-b Drive 백업 (D1 ④ ack 후)

목표: 가시 "Memoyo" 폴더에 1버튼 백업 + rotate N=7. 인증 = `google_sign_in` + `googleapis` + `extension_google_sign_in_as_googleapis_auth`. 1.0.7 (1) Drive spec 그대로 + ① 의 복구 리스트 다이얼로그 UX.

- [ ] (spec 정본 = `docs/superpowers/specs/2026-05-19-memoyo-drive-export-design.md`, 별 implementation plan = `docs/specs/1.0.7-drive-export-impl-plan.md` 존재 추정 — Stage 1 끝나면 확인 + execute).

### Stage 3 — 1.1.x Drive 동기화 (D1/D3/D4 ack 후)

목표: 1.0.7-b 자산(인증/`Memoyo` 폴더) 재사용. pull → merge() → push 사슬. 트리거 = D3 결정대로 (포그라운드 자동 또는 수동 버튼).

- [ ] 동기화 메타파일 (`Memoyo/.sync-state.json` 또는 `appDataFolder/sync-state.json`) 스키마 확정 — `lastSyncedAt`, `deviceId`, `schemaVersion`.
- [ ] `SyncService.pull()` Drive → 로컬 스냅샷.
- [ ] `SyncService.push()` 로컬 → Drive (merge 결과 통째 업로드).
- [ ] 포그라운드 자동 트리거 (D3=2) 또는 "지금 동기화" 버튼 (D3=1).
- [ ] release note: "아주 오래(>90일) 미사용 기기에서 삭제한 메모가 드물게 다시 나타날 수 있음" (tombstone TTL 한계).

### Stage 4 — iCloud 동기화 후속 (iOS 한정, D4=a 후속)

목표: iOS 사용자 zero-login UX. Flutter 패키지 (`cloud_kit` / `icloud_kv_storage` / `icloud_storage`) 실측 후 채택 vs MethodChannel native CloudKit 비교. 1.1.x 별 minor (1.1.1+).

---

## 진행 규약 (cron 45분 fire 매번 적용)

1. `git pull --ff-only origin main` → 브랜치 rebase 필요 시 rebase.
2. 이 파일 "현재 단계" 마커 읽기.
3. Stage 0 = HOLD → Telegram 침묵 + /clear (다음 fire 까지 대기).
4. Stage 1+ = TDD 순서 (red → green → refactor), 매 sub-bullet 진척 시 `[x]` + KST 일자 + commit sha inline 마킹.
5. 단계 완료 → 다음 Stage 마커로 갱신 + commit.
6. push to `origin mac/memoyo-sync-2026-05-17` (PR 머지는 본진 수동, main 직접 push 금지).
7. 진행 결과 1~2줄 Telegram reply.
8. /clear → 다음 fire 가 fresh 컨텍스트로 이어받음.

## 핸드오프 메모 (다음 fire 가 봐야 할 것)

- 첫 부트스트랩 fire 결과 = 브랜치 + 본 파일 + 형님 Telegram (3 BLOCKER surface) 1통.
- 형님 ack 들어오기 전엔 매 fire 가 본 파일 Stage 0 마커 보고 즉시 /clear (no-op). Telegram spam X (형님 자는 중).
- ack 형태 예시: "D1=④ / D2=선반영 / D3=2 (박제완화 OK)" 또는 부분 ack ("D2 만 OK, D1/D3 더 고민") — 부분 ack 면 가능한 stage 만 진입 (Stage 1 은 D2 만으로도 가능).
