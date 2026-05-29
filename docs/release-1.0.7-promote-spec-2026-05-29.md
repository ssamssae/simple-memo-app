# 메모요 1.0.7+27 Play production promote — 회귀 분석 spec

- 작성: 2026-05-29 · 🖥 데스크탑 · 낮 오토파일럿 cycle 4
- 목적: 1.0.7+27 (Play internal testing) → production promote 의 회귀 위험을 사전 audit 해, 형님 ack 시 즉시 promote 가능한 상태로 만든다.
- **범위: 분석(read-only)만. Play Console 액션·promote 자체는 하지 않음.**
- 외부영향: 0

---

## 1. 버전 좌표

| 트랙 | 버전 | 근거 |
|------|------|------|
| production (현행, **확인 필요**) | **1.0.6+24 로 추정** | pubspec 이력상 `1.0.5+23 → 1.0.6+24 → 1.0.7+27`. 1.0.7 직전 정식 버전 = 1.0.6+24 (`018753f` "메모 내보내기 silent fail fix"). |
| internal testing (promote 대상) | **1.0.7+27** | `b31ecef` 에서 `1.0.6+24 → 1.0.7+27` 단일 bump. |

> **⚠️ +25 / +26 은 별도 pubspec commit 이 없음** — 내부 테스트 트랙에 올린 중간 빌드 번호(빌드 업로드마다 build number 증가)로 보이며, 코드 delta 단위가 아님. 따라서 "회귀 audit" 의 의미 있는 코드 비교 단위는 **production(1.0.6+24) → 1.0.7+27** 전체 delta.

> **⚠️ 현 production 버전 = Play Console 직접 확인 필요.** 이 분석은 🖥 데스크탑 노드에서 수행했고 이 노드에는 Play Console 자격증명(service account JSON / fastlane Fastfile)이 없어 read-only 조회도 불가. 본진/맥미니 노드 또는 형님이 Play Console 에서 현 production 버전을 1줄 확인하면 baseline 확정.

---

## 2. 코드 delta (production 1.0.6+24 → 1.0.7+27)

`git diff b31ecef~1..HEAD` 기준 변경 파일:

```
 ios/Runner/Info.plist                   |  14 ++
 lib/models/memo.dart                    |   2 +
 lib/screens/memo_edit_screen.dart       |  34 +-
 lib/screens/memo_list_screen.dart       | 272 +++++-
 lib/screens/splash_screen.dart          |   6 +-
 lib/services/drive_backup_service.dart  | 307 +++  (신규)
 lib/services/export_import_service.dart |  56 +-
 lib/widgets/version_footer.dart         |  27 +   (신규)
 pubspec.yaml                            |   9 +-
```

신규 의존성 (pubspec): `google_sign_in ^6.2.1`, `googleapis ^13.2.0`, `extension_google_sign_in_as_googleapis_auth ^2.0.12`, `url_launcher ^6.3.1` (+ dev: `mocktail ^1.0.4`).

---

## 3. 회귀 가능성 표

| # | 변경 | commit | 카테고리 | 회귀 가능성 | 영향 화면 | 검증 방법 |
|---|------|--------|----------|:-----------:|-----------|-----------|
| 1 | **Drive 1버튼 백업** (Google OAuth + Drive 업로드/7개 회전) | `b31ecef` | feature | **Med** | overflow 메뉴 → "Drive 백업" | OAuth 동의 시트 노출 / SHA-1 = Play App Signing 인증서 매칭 / 실기기 백업 1회 성공 + "Memoyo 폴더 열기" SnackBar |
| 2 | **Drive 가져오기 picker** | `86150bb` | feature | **Med** | overflow → 가져오기 | 파일 선택 → 파싱 → 중복/손상 JSON 분기 처리 (export_import roundtrip 테스트 커버) |
| 3 | **export_import_service 리팩토링** (-56줄, share-sheet 기반 재정리) | (range) | refactor | **Med** | 내보내기/가져오기 | round-trip 무결성 테스트 (`export_import_roundtrip_test.dart` 존재) |
| 4 | **삭제 실행취소 SnackBar** (단일 + 벌크) | `d222509` | feature | Low-Med | 목록 삭제 / 편집모드 벌크삭제 | 삭제 → 실행취소 → 원래 인덱스 재삽입 + 즐겨찾기/일반 그룹 순서 복원 (`memo_list_undo*_test.dart` 다수 커버) |
| 5 | **메모 공유 버튼** | `54f3715` | feature | Low | 편집화면 AppBar 공유 IconButton | share sheet 노출 (`memo_edit_share_test.dart`) |
| 6 | **version footer** (이번 cycle 머지) | `b79bc65` | feature(cosmetic) | Low | 목록 하단 footer | **빌드 시 `--dart-define=APP_VERSION=1.0.7` 주입 필수** (§4-4 참조) |
| 7 | `Memo.title` getter (= firstLine) | (range) | refactor | Low (additive) | — | 기존 동작 변경 0, 신규 getter alias |
| 8 | splash_screen (+6) | (range) | minor | Low | 스플래시 | 시각 확인 |
| 9 | analyze 회귀 fix | `da81c43` | fix | Low | — | `flutter analyze` clean |

가장 주의할 항목 = **#1 Drive 백업의 OAuth/서명 경로**. 나머지는 내부 테스트(=release 서명 빌드)에서 이미 동작 중이면 production 도 동일 서명 컨텍스트라 회귀 가능성 낮음.

---

## 4. promote 전 체크리스트 (형님 ack 후 즉시 실행 가능 상태)

1. **현 production 버전 확인** — Play Console (본진/맥미니 또는 형님). 1.0.6+24 가정 검증.
2. **OAuth SHA-1 매칭** — Google Cloud Console OAuth client 의 등록 SHA-1 = **Play App Signing 인증서** SHA-1 인지 확인. 내부 테스트도 release 빌드(Play App Signing)라 거기서 Drive 로그인 성공 = production 서명 동일 → 동작 예상. 단 명시 확인 1회. (changelog "App signing key SHA-1 교체" 이력 있음)
3. **INTERNET 권한 — 조치 불요(확인 완료)**. main AndroidManifest 엔 권한 선언이 없지만 `google_sign_in_android-6.2.1` 라이브러리 manifest 가 `android.permission.INTERNET` 를 release 빌드에 머지함. (google_sign_in 제거 시에만 재검토)
4. **version footer dart-define** — production AAB 빌드 시 `flutter build appbundle --dart-define=APP_VERSION=1.0.7` 주입. **누락 시 footer 가 `vdev · 강대종` 으로 표시됨.** 현재 fastlane/CI 에 dart-define 주입 설정 없음 → 빌드 명령에 수동 포함 필요 (8apps-version-footer spec §4 빌드스크립트 항목).
5. **Data Safety form** — Drive 백업 = 사용자 데이터(메모)를 Google Drive 로 전송. Play Console Data Safety 섹션이 "데이터 전송/클라우드 백업" 을 반영하는지 확인. 상세 UX/문구 = `docs/specs/1.0.7-data-safety-ux.md` (28KB, 기 작성).
6. **실기기 smoke test** (맥미니 USB 기기, 별 사이클) — Drive 백업 / Drive 가져오기 / 삭제 실행취소 / 공유 4개 happy-path.

---

## 5. 테스트 안전망 현황

- 위젯/단위/통합 테스트 파일 다수 (test/ 하위): Drive backup/restore round-trip, 실패 시나리오(네트워크/권한/용량), rotate 8회 시뮬, reorder 콜백 회귀, 토글↔reorder 상호작용, empty state, export/import roundtrip, undo batch/partial 등.
- 이번 cycle footer 머지 시 **전체 80/80 PASS** 확인됨.
- 단 SDK skew 주의: 데스크탑 3.44.0 PASS ≠ strict 노드. promote 빌드는 맥미니/본진 SDK 로 수행 권장.

---

## 6. 결론

- production → 1.0.7+27 의 코드 delta 는 **Drive 백업/가져오기 + 공유 + 삭제 undo + version footer** 가 핵심이며, 데이터 무결성·OAuth 경로 외에는 회귀 위험 낮음.
- **하드 blocker 없음.** §4 의 6개 항목(특히 #2 OAuth SHA-1, #4 dart-define, #5 Data Safety)만 promote 직전 확인하면 됨.
- promote 액션 자체는 형님 ack 큐(#2) 사안 — 본 spec 은 ack 시 즉시 진행 가능하도록 사전 정지작업까지만.
