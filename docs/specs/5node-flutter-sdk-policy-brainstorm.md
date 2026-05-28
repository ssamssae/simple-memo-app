# 5 노드 Flutter SDK 통일 정책 — 1차 brainstorm draft

**Status**: 🟡 draft · 형님 ack + trio-vote 펜딩 — 본 문서는 **결정 아닌 옵션 나열**
**Author**: 🪟 WSL / 2026-05-29 KST
**Repo**: ssamssae/simple-memo-app · branch `wsl/5node-sdk-policy-brainstorm-2026-05-29`
**Cycle entry**: 1.0.7 사이클 PR #23 (UNDO) main analyze 회귀 사고 후속. `onReorderItem` 미정의 named arg 가 본진/WSL 게이트는 통과, 노트북 fvm 3.41.9 만 잡음 — SDK 차이로 false negative 통과한 root cause.

---

## 0. 본 문서의 의도

5 노드 (🍎 본진 / 🪟 WSL / 🏭 맥미니 / 🖥 데스크탑 / 💻 노트북) 가 동일 Flutter repo (`simple_memo_app` 등) 를 만질 때 SDK 버전 차이가 만드는 false negative 를 어떻게 잡을지 옵션 3 개 비교. v1 = 가장 가벼운 안 채택 + 사고 재발 시 v1.x 강화.

---

## 1. 현 상태 audit

WSL 본진 보고 + 직전 사이클 surface 종합 (2026-05-29 02:00 KST):

| 노드 | Flutter | Dart | 출처 | 사고 위치 |
|------|---------|------|------|-----------|
| 🍎 본진 | 3.44.0 stable | 3.12.0 | 본진 1.0.7 사이클 보고 (auto-update) | merge-gate PASS rc=0 false negative |
| 🪟 WSL | 3.44.0 stable | 3.12.0 | 사이클 #4 mac-report `flutter --version` 명시 | merge-gate PASS rc=0 false negative |
| 🏭 맥미니 | TBD | TBD | mac-report 1.0.7 OAuth fix 사이클 본문 grep 필요 (또는 directive 발사) | — |
| 🖥 데스크탑 | TBD | TBD | 8apps-version-footer.md (PR #143) 작성한 노드, audit 시점 SDK 미명시 | — |
| 💻 노트북 | **3.41.9** (fvm) | 3.7.x 추정 | PR #28 commit da81c43 의 `fix(memoyo) + test: main analyze 회귀 fix` 사이클에서 잡음 | 진짜 strict — 본진 가설 정정 단서 |

**관찰**:
- 본진/WSL 동일 3.44.0 인데 `onReorderItem` 미정의 named arg 가 analyzer 통과. 즉 SDK 차이가 아니라 **3.44.0 analyzer 자체의 deprecation alias 또는 false-accept**.
- 노트북 fvm 3.41.9 (구 stable) 가 strict — Flutter `onReorder` deprecation 시점 이전 SDK 라 named arg name 변경을 진짜 못 받음.
- 맥미니/데스크탑 SDK 는 mac-report 본문 grep 또는 directive PROBE 로 확인 필요 (본 brainstorm 작성 시점에는 미확정).

**Root cause 재추정 (사이클 #4 mac-report 후속)**:
- 본진 가설 ("본진 3.44 vs 노트북 3.41.9 차이") 는 본진/WSL 양쪽 3.44 동일 사실로 정정됨.
- 새 가설: Flutter 3.44.0 analyzer 가 ReorderableListView 의 deprecation rename (`onReorder` → `onReorderItem`) 을 alias 처리하거나 unknown named arg 를 info-level 로 디그레이드. 노트북 3.41.9 는 deprecation 도입 전 strict.
- 검증 방법: 3.44.0 다른 위젯에 임의 미정의 named arg (`foo: bar`) 를 박고 analyze 가 잡는지 — 이 자체는 별 사이클 후보 (1.0.7 cycle 무관).

---

## 2. 문제

5 노드 중 어느 한 노드 (특히 SDK 가장 최신) 가 merge-gate.sh PASS 받았다고 다른 노드들도 PASS 받는 보장이 없음. PR #23 (UNDO) 가 본진 게이트 PASS 후 main 머지 → 노트북 자동 analyze 가 회귀 신호 → PR #28 fix → 24h 후속 사이클 비용 발생.

**일반화**: 5 노드 mesh 가동 시 각 노드의 SDK 가 다를수록 게이트의 false negative 표면이 커짐. 머지 후 회귀 신호 → fix PR → 머지 사이클 매번 반복.

---

## 3. 옵션 3 안

### 옵션 1 — fvm 통일

**What**: 5 노드 모두 `fvm` (Flutter Version Manager) 도입 + repo 별 `.fvmrc` 또는 `pubspec.yaml flutter:` 필드 + project-local SDK pin. 게이트도 fvm 활성 SDK 로 실행.

**Pros**:
- 5 노드 게이트 결과 deterministic — 같은 SDK = 같은 analyzer 결과
- SDK 업그레이드는 `.fvmrc` 한 줄 커밋 으로 명시적 (드리프트 차단)
- Flutter 진영 표준 패턴, 다른 multi-repo 프로젝트도 동일 패턴

**Cons**:
- 5 노드 모두 fvm install + per-repo bootstrap (`fvm install <ver> && fvm use <ver>`) 한 번 필요 — 첫 설치 시간 + 디스크 ~2GB × N versions
- `merge-gate.sh` 의 `find_flutter` 함수가 fvm 경로 (`fvm flutter`) 우선 픽 — 현재 코드 `command -v fvm` fallback 있음. 동작 검증 필요.
- 노트북은 이미 fvm 3.41.9 — 통일 시 어느 버전으로? `.fvmrc` 한 줄 결정 시 5 노드 통일 직진.
- WSL 측 Linux flutter 는 `~/flutter/bin` git clone 기반, fvm 통합 시 별 설정 필요 가능성.

**비용**: 5 노드 × 첫 설치 30 분 = 약 2.5 시간 + 학습 곡선 작음 (CLI 2 명령).

**Open**:
- (a) 통일 버전: 3.44.0 latest stable 또는 3.41.9 (노트북 strict 보존) 또는 3.40.x LTS-ish
- (b) `pubspec.yaml flutter:` 필드 vs `.fvmrc` 단독 vs 둘 다

### 옵션 2 — merge-gate.sh 자체 강화 (추가 SDK layer)

**What**: `~/claude-skills/autopilot/merge-gate.sh` 가 PASS 전에 **2번째 SDK** (별 fvm 또는 다른 노드의 SDK) 도 호출해서 cross-check. 한 SDK PASS 만으로는 게이트 통과 X.

**Pros**:
- 노드별 SDK 자유 유지 (각자 작업 환경 그대로)
- 게이트 자체가 cross-SDK 보장 → false negative 0
- 노드 추가 시 게이트 스크립트만 갱신, repo 별 설정 변경 X

**Cons**:
- 게이트 실행 시간 2 배 (2 SDK × analyze) — 평균 10s + 10s = 20s
- 노드별 SDK 가 게이트 머신에 둘 다 설치돼야 함 (디스크 ~4GB × N versions)
- "2 번째 SDK" 가 무엇이냐는 정책 결정 — 매번 다를 수도 있음 (옵션 1 의 결정 회피가 옵션 2 의 결정 부담)
- 보안: 다른 노드 SDK 를 자기 머신에서 호출하려면 fvm 또는 별 PATH 분기 — fvm 다시 옵션 1 의 부분 도입

**Open**:
- (a) 2nd SDK 정의 — 가장 strict SDK 1 개 fixed 또는 노드 round-robin
- (b) 게이트 시간 증가 허용 한도 (PR 머지 자율성 vs 안전성)

### 옵션 3 — 5 노드별 다른 SDK 유지 + cron audit

**What**: 노드별 SDK 자유 유지 + 별 cron / launchd 잡이 매 N 시간마다 main HEAD 위에서 5 노드 모두 `flutter analyze` 돌려서 결과 diff. 회귀 신호 시 텔레그램 알림 + 자동 issue 박기.

**Pros**:
- 게이트 자체 변경 0 — PR 머지 흐름 unchanged
- 노드별 SDK 다양성 그 자체가 false negative 검출 자원 (가장 strict 노드가 게이트보다 더 잘 잡을 수 있음)
- 5 노드 always-on (2026-05-27 정책) 이라 cron 호스트 풍부

**Cons**:
- 회귀 신호가 머지 **후** 에 나옴 → fix PR 사이클 발생 (현재 PR #28 패턴 그대로)
- 5 노드 cron 별 동기화 인프라 필요 (이미 mac-report 채널 있어 비용 작음)
- "fix PR 사이클이 본질적으로 나쁜가" 의 가치 판단 — Karpathy 룰2 (simplicity first) 관점 = 사이클 비용이 게이트 강화 비용보다 작으면 OK

**Open**:
- (a) cron 주기 — 1h / 6h / 24h
- (b) 회귀 신호 시 자동 PR (옵션 1 다른 SDK 로 fix 시도) vs 단순 알림 + 사람 손
- (c) 5 노드 audit 결과 diff 인프라 — agent-inbox 활용 가능

---

## 4. 비교 매트릭스

| 기준 | 옵션 1 fvm 통일 | 옵션 2 게이트 강화 | 옵션 3 cron audit |
|------|----------------|-------------------|-------------------|
| 머지 전 false negative 0 | ✅ (단일 SDK) | ✅ (cross-SDK 게이트) | ❌ (머지 후 검출) |
| 5 노드 SDK 자유 | ❌ pin | ✅ 자유 | ✅ 자유 |
| 인프라 첫 비용 | 5 노드 × fvm 설치 | merge-gate 패치 + SDK 추가 | cron 잡 5 노드 배포 |
| 매 머지 비용 | 0 (게이트 그대로) | +10s (게이트 2배) | 0 (게이트 그대로) |
| 회귀 사이클 비용 | 0 | 0 | 발생 (현 패턴) |
| 다중 SDK 호환 가치 | 잃음 | 보존 | 보존 + 활용 |

---

## 5. 디폴트 픽 제안

**v1 = 옵션 3 (cron audit)** 추천 이유:
- 가장 적은 인프라 변경 — 게이트 자체 변경 0, 노드별 환경 그대로
- 5 노드 always-on 정책 (2026-05-27) 위에 cron 1 개 추가가 자연스러움
- 회귀 사이클 비용은 1.0.7 cycle 에서 이미 PR #28 fix 24h 안 소화 — 본질적으로 mesh 시너지의 일부
- v1.x 가 옵션 1 (fvm 통일) 또는 옵션 2 (게이트 강화) 로 escalate — 회귀 빈도가 사이클 비용보다 커지면 그때 강화

**대안**: 옵션 1 만약 형님이 SDK 통일 자체에 가치 (예: 외부 contributor onboard, store 빌드 reproducibility) 를 두면 옵션 1 우선.

**비추**: 옵션 2 — 게이트 시간 2배 + 정책 결정 부담 둘 다, 옵션 1 의 일부 + 옵션 3 의 일부 합쳐 가치 합 < 옵션 1/3 단독.

---

## 6. trio-vote 후보 + 형님 ack 대상

본 문서는 **draft** — 다음 단계:

1. 형님 ack — "어느 옵션이 좋아 보이는지" + "회귀 사이클 비용 vs 인프라 비용" trade-off 결정
2. trio-vote / mesh-vote (PM 시각 / 엔지니어 시각 / 비판론자 시각) — 형님 ack 후 옵션 확정
3. spec 별 파일 작성 (`5node-flutter-sdk-policy-v1.md`) + 노드별 분배 + 인프라 PR

---

## 7. 본 draft 의 한계

- 맥미니/데스크탑 SDK 정보 미수집 — 이 두 노드 verify 한 다음 audit 표 보완 필요. 본진이 mac-report PROBE 또는 directive 1 회 발사 후 갱신.
- `Flutter 3.44.0 analyzer 의 onReorder→onReorderItem alias` 가설 미검증 — 별 사이클의 reproducible test 필요 (1.0.7 무관, 본 brainstorm 후속).
- 옵션 비교가 정성적 — 실제 인프라 비용 (fvm 설치 시간 / 게이트 latency 증가 / cron 운영) 측정치 부재. v1 옵션 확정 후 실측.
- 5 노드 다른 OS (Linux + macOS + WSL) 가 Flutter SDK 호환성 차이를 만들 가능성 별 — 본 문서는 OS 차이는 무시하고 SDK 버전만 다룸.
