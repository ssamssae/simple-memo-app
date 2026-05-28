# 5 노드 Flutter SDK 통일 정책 — 1차 brainstorm draft

**Status**: 🟡 draft v2 · 형님 ack + trio-vote 펜딩 — 본 문서는 **결정 아닌 옵션 나열**
**Author**: 🪟 WSL / v1 2026-05-29 KST / v2 2026-05-29 02:18 KST (본진 5 노드 audit + Flutter SDK changelog grep 후 갱신)
**Repo**: ssamssae/simple-memo-app · branch v1 `wsl/5node-sdk-policy-brainstorm-2026-05-29` (머지 #33) / v2 `wsl/5node-sdk-policy-update-2026-05-29`
**Cycle entry**: 1.0.7 사이클 PR #23 (UNDO) main analyze 회귀 사고 후속. `onReorderItem` named arg 가 본진/WSL 게이트는 통과, 노트북 fvm 3.41.9 만 잡음 — SDK 버전 별 API 진화 차이가 root cause (v2 에서 확정).

---

## 0. 본 문서의 의도

5 노드 (🍎 본진 / 🪟 WSL / 🏭 맥미니 / 🖥 데스크탑 / 💻 노트북) 가 동일 Flutter repo (`simple_memo_app` 등) 를 만질 때 SDK 버전 차이가 만드는 false negative 를 어떻게 잡을지 옵션 3 개 비교. v1 = 가장 가벼운 안 채택 + 사고 재발 시 v1.x 강화.

---

## 1. 현 상태 audit (v2 — 본진 5 노드 ssh audit 확정 데이터)

본진 ssh 1회 호출로 수집 (2026-05-29 02:15 KST 추정, 사이클 #5 머지 후속 directive 본문):

| 노드 | Flutter | 채널 | 그룹 | 출처 |
|------|---------|------|------|------|
| 🍎 본진 | **3.44.0** stable | stable | A (new) | 본진 1.0.7 사이클 + audit ssh |
| 🪟 WSL | **3.44.0** stable | stable | A (new) | WSL 사이클 #4 `flutter --version` 본문 |
| 🏭 맥미니 | **3.41.9** stable | stable | B (strict) | 본진 audit ssh |
| 💻 노트북 | **3.41.9** stable (fvm) | stable (fvm) | B (strict) | PR #28 fix + 본진 audit ssh |
| 🖥 데스크탑 | **없음** | — | C (no flutter) | 본진 audit ssh — flutter command 자체 0 |

**그룹 A (new) — 본진 + WSL = 3.44.0**: `onReorderItem` named arg 정상 valid (analyze PASS).
**그룹 B (strict) — 맥미니 + 노트북 = 3.41.9**: `onReorderItem` 미정의 (analyze error 4건 catch).
**그룹 C (no flutter) — 데스크탑**: snap 미설치 또는 fvm `/tmp/8apps-audit/` 캐시 가능성. 8apps-version-footer.md (PR #143) 작성한 노드인데 자기 `~/yakmukja` footer migration 작업 시 어떻게 빌드/analyze 한 건지 별 verify 필요.

## 1.5. Root cause 확정 (v2 — Flutter SDK changelog grep 후)

WSL 사이클 #6 에서 `~/flutter` repo 의 git log + reorderable_list.dart 변경 추적:

```
$ cd ~/flutter
$ git log --oneline -- packages/flutter/lib/src/material/reorderable_list.dart | grep -i onReorderItem
$ git log --oneline --grep onReorderItem
$ git log --oneline -- packages/flutter/lib/src/material/reorderable_list.dart | head
3e6c2071664 Deprecate onReorder callback (#178242)
```

- commit `3e6c2071664 Deprecate onReorder callback (#178242)` 작성자 Navaron Bracke, 2026-01-29.
- 변경 본문: "Deprecates the old `onReorder` callback of ReorderableList / SliverReorderableList / ReorderableListView, in favor of a new callback, `onReorderItem`, that does the index correction". 둘 다 valid, 동시 제공 시 old 우선.
- 첫 포함 stable: `3.42.0-0.0.pre`. → **3.41.9 는 변경 미포함**, `onReorderItem` named arg 자체가 존재하지 않음 → analyzer strict reject.
- **3.42.0+ (3.44.0 포함)**: `onReorderItem` 이 실제 valid API 라서 PASS 가 옳다. analyzer 의 alias / bug / false-accept 가 아니라 진짜 새 API 가 추가된 forward-compatible 진화.

**기존 v1 가설 정정**:
- v1 brainstorm 의 "3.44.0 analyzer 자체의 deprecation alias 또는 false-accept" 가설은 **부분 틀림**.
- 정정: 새 API (`onReorderItem`) 가 3.42.0 부터 진짜 추가됐고, 본진 PR #23 의 코드는 그 새 API 사용. 3.44.0 analyzer PASS 는 정상 거동.
- 본질: **3.41.9 노드 (맥미니/노트북) 가 forward-incompatible** — 3.42.0+ 신규 API 를 못 받음. 본진/WSL 3.44.0 위에서 정상 동작하는 코드가 3.41.9 위에서 깨짐.
- 일반화: deprecation rename / 신규 API 추가가 잦은 Flutter 진화 패턴에서 5 노드 SDK skew (3.41.9 ↔ 3.44.0, 3 minor 차이) 가 false negative 표면을 만든다.

**즉시 fix 옵션** (별 사이클 후보, 본 spec 의 정책 결정과 무관):
- 본진 PR #23 의 `onReorderItem` 을 `onReorder` (deprecated 옛 API) 로 되돌리면 5 노드 다 PASS. 단 3.44.0 위에서 deprecation 경고는 받음 (info-level).
- 또는 5 노드 모두 3.42.0+ 로 업그레이드 (옵션 1 fvm 통일 의 sub-case).

---

## 2. 문제

5 노드 중 SDK 가장 최신 (3.44.0, A 그룹) 노드가 merge-gate.sh PASS 받았다고 구 stable 노드 (3.41.9, B 그룹) 도 PASS 받는 보장 X. PR #23 (UNDO) 가 본진 (A 그룹) 게이트 PASS 후 main 머지 → 노트북 (B 그룹) 자동 analyze 가 회귀 신호 → PR #28 fix → 24h 후속 사이클 비용 발생.

**일반화**: 5 노드 mesh 가동 시 SDK skew (현재 3 minor 차이) 가 forward-incompatible API 사용 시 cascade 회귀. Flutter 진영의 잦은 deprecation rename + 신규 API 도입이 false negative 표면을 만든다.

**v2 audit 후 핵심 통찰**: 5 노드 중 진짜 catch 자원은 그룹 B (맥미니 + 노트북) **2 대뿐**. 본진 / WSL 끼리 cross-check 는 정보 0 (같은 SDK). 데스크탑 = flutter 없어서 audit 자체 불가. 즉 **strict 노드 2 대가 mesh 의 사실상 게이트키퍼**.

---

## 3. 옵션 3 안

### 옵션 1 — fvm 통일

**What**: 5 노드 모두 `fvm` (Flutter Version Manager) 도입 + repo 별 `.fvmrc` 또는 `pubspec.yaml flutter:` 필드 + project-local SDK pin. 게이트도 fvm 활성 SDK 로 실행.

**v2 audit 후 비용 갱신**: 5 노드 중 데스크탑은 flutter 가 0 이라 통일 시 **추가 1 노드 install 비용**. 본진/WSL = 3.44.0 + 노트북 = 이미 fvm 3.41.9 + 맥미니 = stable 3.41.9. 통일 버전을 정하면 본진/WSL 2 대 또는 맥미니/노트북 2 대 가 fvm 추가 + 데스크탑 1 대가 fvm + flutter 신규 install.

**Pros**:
- 5 노드 게이트 결과 deterministic — 같은 SDK = 같은 analyzer 결과
- SDK 업그레이드는 `.fvmrc` 한 줄 커밋 으로 명시적 (드리프트 차단)
- Flutter 진영 표준 패턴, 다른 multi-repo 프로젝트도 동일 패턴

**Cons**:
- 5 노드 모두 fvm install + per-repo bootstrap (`fvm install <ver> && fvm use <ver>`) 한 번 필요 — 첫 설치 시간 + 디스크 ~2GB × N versions
- `merge-gate.sh` 의 `find_flutter` 함수가 fvm 경로 (`fvm flutter`) 우선 픽 — 현재 코드 `command -v fvm` fallback 있음. 동작 검증 필요.
- 데스크탑이 flutter 자체가 없는 상태 — 통일 시 데스크탑 첫 install 비용 추가 (1 노드 onboard).
- WSL 측 Linux flutter 는 `~/flutter/bin` git clone 기반, fvm 통합 시 별 설정 필요 가능성.

**비용**: 5 노드 × 첫 설치 30 분 + 데스크탑 추가 onboard = 약 3 시간 + 학습 곡선 작음 (CLI 2 명령).

**Open**:
- (a) 통일 버전: 3.44.0 latest stable (deprecation 진화 이전 cohort 잃음) 또는 3.41.9 (B 그룹 strict 보존, 본진/WSL downgrade) 또는 3.42.0-3.43.x (compromise)
- (b) `pubspec.yaml flutter:` 필드 vs `.fvmrc` 단독 vs 둘 다
- (c) 데스크탑 = flutter 사용 노드가 아닐 수도 있음 (자기 ~/yakmukja 작업이 어떻게 빌드된 건지 verify 필요) — 데스크탑은 ML/SD/Whisper 워크로드 노드라 SDK 통일에서 빠지는 게 자연스러울 수도

### 옵션 2 — merge-gate.sh 자체 강화 (추가 SDK layer)

**What**: `~/claude-skills/autopilot/merge-gate.sh` 가 PASS 전에 **2번째 SDK** (별 fvm 또는 다른 노드의 SDK) 도 호출해서 cross-check. 한 SDK PASS 만으로는 게이트 통과 X.

**v2 단순 안 (audit 후)**: 본진 게이트가 PASS 전에 **노트북 또는 맥미니 ssh** 호출 1회 추가 — 그 노드의 3.41.9 analyze 결과를 받아 합산. 또는 본진 머신에 fvm 으로 3.41.9 추가 설치 + 게이트가 양 SDK 둘 다 PASS 강제. ssh 안 vs 로컬 fvm 안 두 sub-option.

**Pros**:
- 노드별 SDK 자유 유지 (각자 작업 환경 그대로)
- 게이트 자체가 cross-SDK 보장 → false negative 0
- 노드 추가 시 게이트 스크립트만 갱신, repo 별 설정 변경 X
- v2 단순 안: 본진 + B 그룹 1 노드 만 cross-check → A vs B 차이 항상 catch (현재 forward-incompatible 진화 시나리오 모두 cover)

**Cons**:
- 게이트 실행 시간 증가:
  - ssh 안: ssh round-trip + remote analyze ~30s (네트워크 의존) → 게이트 총 ~40s
  - 로컬 fvm 안: 본진에 추가 SDK install 1회 + analyze 1회 추가 ~10s → 게이트 총 ~20s
- 노드별 SDK 가 게이트 머신에 둘 다 설치돼야 함 (로컬 fvm 안) 또는 ssh 의존 (ssh 안)
- "2 번째 SDK" 가 무엇이냐는 정책 결정 — 매번 다를 수도 있음 (옵션 1 의 결정 회피가 옵션 2 의 결정 부담)
- 보안: 본진 게이트에서 노트북/맥미니 ssh 호출 시 작업 흐름의 외부 노드 의존성 증가 (네트워크 차단 시 게이트 자체 fail) — silent fail 위험

**Open**:
- (a) ssh 안 vs 로컬 fvm 안 — ssh 안이 인프라 변경 작음 / 로컬 fvm 안이 latency 작고 self-contained
- (b) cross-check 대상 — B 그룹 (3.41.9) 1 노드만 vs 항상 가장 strict SDK
- (c) 게이트 시간 증가 허용 한도 (PR 머지 자율성 vs 안전성)
- (d) merge-gate.sh repo (~/claude-skills/autopilot/) 의 변경 — 5 노드 sync 채널이라 변경 영향 큼

### 옵션 3 — 5 노드별 다른 SDK 유지 + cron audit

**What**: 노드별 SDK 자유 유지 + 별 cron / launchd 잡이 매 N 시간마다 main HEAD 위에서 strict 노드만 `flutter analyze` 돌려서 결과 텔레그램. 회귀 신호 시 자동 issue 박기.

**v2 단순 안 (audit 후)**: 5 노드 다 cron audit 할 필요 없음 — A 그룹 (본진/WSL) audit 은 항상 PASS (이미 게이트 PASS 의 same SDK), 데스크탑은 flutter 없음. **B 그룹 (맥미니 + 노트북) 2 대만 cron audit** 으로 정보 100% 유지 + 비용 60% 감소.

**Pros**:
- 게이트 자체 변경 0 — PR 머지 흐름 unchanged
- 노드별 SDK 다양성 그 자체가 false negative 검출 자원 (B 그룹 strict 가 A 그룹 PASS 위 회귀를 catch)
- 5 노드 always-on (2026-05-27 정책) 이라 cron 호스트 풍부
- v2 단순 안: 2 노드만 cron 으로 정보 100% — 인프라 비용 가장 작음

**Cons**:
- 회귀 신호가 머지 **후** 에 나옴 → fix PR 사이클 발생 (현재 PR #28 패턴 그대로)
- B 그룹 노드 cron 동기화 인프라 필요 (이미 mac-report 채널 있어 비용 작음)
- "fix PR 사이클이 본질적으로 나쁜가" 의 가치 판단 — Karpathy 룰2 (simplicity first) 관점 = 사이클 비용이 게이트 강화 비용보다 작으면 OK
- B 그룹 SDK (3.41.9) 가 언젠가 새 stable 로 업그레이드되면 strict 자원 잃음 → 옵션 1/2 재검토 필요

**Open**:
- (a) cron 주기 — 1h / 6h / 24h (PR 머지 빈도 vs 알림 노이즈 trade-off)
- (b) 회귀 신호 시 자동 PR (옵션 1 다른 SDK 로 fix 시도) vs 단순 알림 + 사람 손
- (c) B 그룹 SDK 업그레이드 시 정책 — 두 노드 동시 업그레이드 금지 (skew 자원 유지) vs 자유 업그레이드 (skew 정보 잃지만 fix 자동)
- (d) cron 잡 호스트 — 맥미니 launchd 또는 노트북 systemd-user (둘 다 가능)
- (e) audit 결과 diff 인프라 — agent-inbox JSON drop 활용 가능

---

## 4. 비교 매트릭스 (v2 단순 안 반영)

| 기준 | 옵션 1 fvm 통일 | 옵션 2 v2 게이트 + B 그룹 1 노드 cross-check | 옵션 3 v2 B 그룹 2 노드만 cron |
|------|----------------|-------------------|-------------------|
| 머지 전 false negative 0 | ✅ (단일 SDK) | ✅ (cross-SDK 게이트) | ❌ (머지 후 검출) |
| 5 노드 SDK 자유 | ❌ pin | ✅ 자유 | ✅ 자유 |
| 인프라 첫 비용 | 5 노드 × fvm 설치 + 데스크탑 onboard (~3h) | merge-gate.sh 패치 + ssh 또는 로컬 fvm | cron 잡 B 그룹 2 노드만 배포 (~30분) |
| 매 머지 비용 | 0 (게이트 그대로) | +10~30s (ssh 또는 로컬 fvm) | 0 (게이트 그대로) |
| 회귀 사이클 비용 | 0 | 0 | 발생 (현 패턴, 단 strict 노드 catch 가 빠름) |
| 다중 SDK 호환 가치 | 잃음 | 보존 | 보존 + 활용 |
| B 그룹 SDK 업그레이드 회복력 | n/a | 자동 (cross-check 노드 SDK 그대로) | strict 자원 잃음 (옵션 1/2 escape 필요) |
| 데스크탑 노드 영향 | onboard 필요 | 0 | 0 |

---

## 5. 디폴트 픽 제안 (v2 갱신)

v1 brainstorm 의 디폴트 픽 = 옵션 3. v2 audit 후 옵션 3 v2 단순 안 (B 그룹 2 노드만 cron) 이 더 가벼워져 **추천 강화**.

**v1 = 옵션 3 v2 단순 안 (B 그룹 cron audit)** 추천 이유:
- 인프라 변경 가장 작음 — 게이트 자체 변경 0, A 그룹 / 데스크탑 환경 그대로, B 그룹 2 노드에 cron 잡 추가만
- 5 노드 always-on 정책 (2026-05-27) 위에 launchd (맥미니) + systemd-user (노트북) 1 잡씩 추가가 자연스러움
- 회귀 사이클 비용은 1.0.7 cycle 에서 이미 PR #28 fix 24h 안 소화 — 본질적으로 mesh 시너지의 일부
- 정보 100%: B 그룹 strict 가 잡는 것 = 5 노드 audit 으로 잡는 것 (A 그룹끼리 + 데스크탑 = 정보 0)

**대안 1 — 옵션 2 v2 단순 안 (본진 게이트 + B 그룹 ssh 1회 cross-check)**:
- 머지 전 catch 가 가치 > 게이트 +30s latency 라면 옵션 2 v2 가 더 안전
- 단 ssh 의존 = 네트워크 차단 / 노드 다운 시 게이트 fail (silent fail 위험)
- 회귀 사이클 자체를 0 으로 만드는 가치가 있으면 옵션 2 v2 픽
- 로컬 fvm sub-option (본진에 3.41.9 추가 install) 이 ssh 의존 회피 가능 — 본진 디스크 ~2GB + analyze +10s

**대안 2 — 옵션 1 (fvm 통일)**:
- 형님이 SDK 통일 자체에 가치 (외부 contributor onboard / store 빌드 reproducibility / 다중 SDK 인지 부담 제거) 를 두면 옵션 1 우선
- 단 데스크탑 onboard 비용 + 통일 버전 결정 부담 + 다중 SDK 호환 가치 잃음 trade-off
- v2 audit 가 본질을 surface — 데스크탑은 flutter 사용 노드가 아닐 수도 있어 5 → 4 노드 통일 + 데스크탑 ML-only 분리 안도 가능

**v2 비추**: 옵션 2 v1 (게이트 시간 2배 + 정책 결정 부담) 은 옵션 2 v2 단순 안으로 대체. 옵션 2 v2 vs 옵션 3 v2 둘 다 합리적.

---

## 6. trio-vote 후보 + 형님 ack 대상

본 문서는 **draft** — 다음 단계:

1. 형님 ack — "어느 옵션이 좋아 보이는지" + "회귀 사이클 비용 vs 인프라 비용" trade-off 결정
2. trio-vote / mesh-vote (PM 시각 / 엔지니어 시각 / 비판론자 시각) — 형님 ack 후 옵션 확정
3. spec 별 파일 작성 (`5node-flutter-sdk-policy-v1.md`) + 노드별 분배 + 인프라 PR

---

## 7. 본 draft 의 한계 (v2)

- ~~맥미니/데스크탑 SDK 정보 미수집~~ — **v2 에서 해결**. 본진 ssh audit 1회로 5 노드 전부 확정 (§1 표).
- ~~Flutter 3.44.0 analyzer 의 alias 가설 미검증~~ — **v2 에서 해결**. Flutter SDK changelog grep 으로 commit `3e6c2071664` (2026-01-29, 3.42.0-0.0.pre 첫 stable) 가 진짜 새 API 도입 commit. alias 가 아니라 forward-compatible 진화.
- 옵션 비교가 정성적 — 실제 인프라 비용 (fvm 설치 시간 / 게이트 latency 증가 / cron 운영) 측정치 부재. v1 옵션 확정 후 실측.
- 5 노드 다른 OS (Linux + macOS + WSL) 가 Flutter SDK 호환성 차이를 만들 가능성 별 — 본 문서는 OS 차이는 무시하고 SDK 버전만 다룸.
- **데스크탑 flutter 부재 surface** — 8apps-version-footer.md (PR #143) 작성한 노드인데 자기 `~/yakmukja` footer migration 작업 시 어떻게 빌드/analyze 한 건지 별 verify. snap install / fvm `/tmp/8apps-audit/` 캐시 / 또는 audit 시점에는 flutter 없이 코드만 작성하고 다른 노드에 빌드 위임 했을 가능성. 본진 데스크탑 directive 1회 PROBE 후속.
- 옵션 2 v2 의 ssh 안 vs 로컬 fvm 안 — 본진 디스크 여유 / 네트워크 안정성 / 게이트 latency 허용치 셋 다 측정 필요.
- B 그룹 (맥미니/노트북) 이 동시 새 stable 로 업그레이드되면 strict 자원 잃음 — 옵션 3 v2 가 자연스럽게 옵션 1 또는 옵션 2 로 escape 필요. 시점 = Flutter 3.42.x 가 stable EOL 도달 시 (LTS 정책 별 확인).
