# 메모요 — 수동 백업/복원 (자동 동기화 폐기) 설계

- 작성일: 2026-05-18 (KST)
- 작성자: 강대종 + Claude (Mac 본진)
- 상태: 강대종 리뷰 대기
- 영향 앱: simple_memo_app (메모요)
- 기존 버전: 1.0.4+21 (2026-05-12 출시 1.0.3+20 후속)

## 1. 결정 요약

2026-05-12 정식 출시 후 추진하던 자동 동기화 (Firebase Firestore + Auth, LWW + soft-delete; `docs/sync-design.md` / `sync-spec.md` 등) 를 **전면 폐기**한다. 대신 수동 메모 백업/복원 (export/import) 만 구현한다.

자동 동기화를 폐기하는 핵심 이유:

- 메모요는 강대종의 첫 정식 출시 앱이며 **무료 정책을 영구 유지**한다 (광고 0, 인앱결제 0). 수익이 0 인 앱에서 CS 처리 시간은 곧 순수 비용이다.
- 자동 동기화는 본질적으로 "사용자가 만지지 않은 데이터가 변하는" 시나리오를 만든다. 그것이 곧 "내 메모 날아갔어요" 문의의 진원지가 된다.
- Firebase / iCloud / Google Drive 어느 조합도 운영부담 (백엔드 비용·셋업·인증·충돌해결·SDK 업데이트·CS) 에서 자유롭지 않다. 검토 결과 iCloud + Google Drive 양자택일 (C 안) 도 결국 OS 별 분기·1회성 마이그레이션 코드 비용이 누적되어 종합 부담이 비슷했다.

## 2. 비기능 요구사항 (영구 박제)

이 항목들은 향후 누구의 (강대종 본인 외) 제안으로도 깨질 수 없는 디자인 게이트이다.

- **무료앱 영구 유지** — 광고 0, 인앱결제 0
- **CS 부담 최소화 우선** — modal 분기, 자동 데이터 변경, "왜 이래?" 시나리오 모두 회피
- **사용자가 명시적으로 버튼 누른 순간에만 데이터가 이동** — 백그라운드 sync, 자동 백업, 자동 복원 모두 없음
- **기존 메모는 어떤 가져오기/병합 시나리오에서도 사라지지 않음을 코드 레벨에서 보장**

## 3. 기능 명세

### 3.1 메모 내보내기

- 진입점: AppBar 우측 3-dot overflow menu → "메모 내보내기"
- 동작:
  1. 현재 `MemoStorage.loadMemos()` 결과 (`List<Memo>`) 를 `Memo.encodeList()` 로 직렬화
  2. 임시 파일 `${tempDir}/memoyo-export-YYYY-MM-DD-HHMMSS.json` 에 기록
  3. `share_plus` 의 `Share.shareXFiles` 로 시스템 share sheet 호출
- 사용자는 share sheet 에서 자유롭게 저장처 선택 (메일·AirDrop·iCloud Drive·Google Drive·카카오톡 등). 앱은 어느 저장처로 갔는지 추적하지 않는다.

### 3.2 메모 가져오기

- 진입점: AppBar 우측 3-dot overflow menu → "메모 가져오기"
- 동작:
  1. `file_picker` 로 사용자가 JSON 1개 선택
  2. 파일 읽기 → `Memo.decodeList()` 로 파싱
  3. 파싱 실패 시: 토스트 "올바른 메모요 백업 파일이 아닙니다", 기존 메모 변경 0, 종료
  4. 파싱 결과가 빈 list (메모 0개) 일 때: 토스트 "가져올 메모가 없습니다", 스냅샷도 저장하지 않고 종료
  5. **가져오기 직전 스냅샷 저장**: 현재 메모 전체 JSON 문자열을 SharedPreferences 의 `memos_pre_import` 키에 통째로 백업
  6. **silent merge**: 가져온 메모 list 순회, 같은 `id` 가 기존에 있으면 `updatedAt` 최신 우선, 없으면 그냥 추가. 기존 메모는 어떤 경우에도 제거하지 않는다.
  7. `MemoStorage.saveMemos()` 로 합쳐진 결과 저장
  8. SnackBar 표시 — "메모 N개 가져왔습니다 [되돌리기]" (`SnackBarAction`)
- modal·확인 dialog 없음 (사용자가 메뉴 누른 순간이 곧 의사 표시)

silent merge 예시:

- 기존: A(id=1, updatedAt=10), B(id=2, updatedAt=20)
- 가져옴: A'(id=1, updatedAt=15), C(id=3, updatedAt=30)
- 결과: A'(id=1, updatedAt=15, 최신본 이김), B(id=2, updatedAt=20, 그대로), C(id=3, updatedAt=30, 추가)
- 핵심: 기존 list 의 어느 id 도 결과 list 에서 사라지지 않는다

### 3.3 가져오기 되돌리기 (1단계 undo)

- 스냅샷 (`memos_pre_import` 키) 이 존재할 때만 노출:
  - 가져오기 직후 SnackBar 의 `[되돌리기]` action
  - AppBar overflow menu 의 "가져오기 되돌리기" 항목 — 스냅샷 존재 여부에 따라 동적으로 항목 표시/숨김
- 동작:
  1. 사용자가 누르면 확인 dialog "현재 N개 → 이전 M개로 되돌립니다. 계속?"
  2. 확인 시 스냅샷을 `MemoStorage` 에 복원
  3. 스냅샷 비움 (`memos_pre_import` 삭제) — 1회성 undo
- 새 가져오기를 누르면 스냅샷이 새 내용으로 덮어써진다 (이전 스냅샷은 잃는다)
- N단계 히스토리는 지원하지 않는다 (단순함 우선, "실수 1번 만회" 목적엔 1단계로 충분)
- 스냅샷 자동 만료 없음 — 영구 보존, 다음 가져오기/되돌리기 시점에 갱신/소거

### 3.4 편집 모드 — 전체 선택 버튼

- 현 구현: `_isEditMode = true` 시 개별 체크박스 + AppBar 의 "삭제 (N)" 버튼 (memo_list_screen.dart:360-410, _deleteSelected 흐름)
- 추가: AppBar actions 에 "전체 선택" 버튼 (편집 모드일 때만 표시) — 누르면 현재 표시 중인 메모 전체 id 를 `_selectedIds` 에 일괄 추가
- 전체 선택 후 기존 "삭제 (N)" 버튼 흐름 (확인 dialog 1단계 → 일괄 삭제) 재사용
- 별도 "메모 전체 삭제" 메뉴는 추가하지 않는다 (편집 흐름 재사용으로 단일화, CS 표면적 축소)

## 4. 데이터 모델

데이터 구조 변경 없음.

- 기존 `Memo` (id=uuid v4, content, isFavorite, createdAt, updatedAt) — 변경 없음
- 기존 `MemoStorage` (SharedPreferences `memos` 키, `Memo.encodeList` 문자열 통째) — 변경 없음
- 신규 SharedPreferences 키: `memos_pre_import` — 가져오기 직전 스냅샷. 값 포맷은 `memos` 키와 동일 (`Memo.encodeList` 결과).

용량 분석: 메모요 평균 100자 × 1000개 = ~100KB. 스냅샷 1개 추가해도 ~200KB. SharedPreferences native 한도 (Android ~8MB / iOS 더 큼) 대비 무해.

## 5. 의존성 변경

### 5.1 추가

- `share_plus` — 시스템 share sheet 호출
- `file_picker` — JSON 파일 picker

### 5.2 제거

- `firebase_core` ^3.6.0
- `firebase_auth` ^5.3.1
- `cloud_firestore` ^5.4.4

pubspec.yaml 의 sync 관련 코멘트 (38행 "기기간 동기화 (S3 — Firebase Console 셋업 hold 필요, docs/sync-design.md §10)") 도 제거한다.

## 6. 폐기 / 아카이브 대상

### 6.1 폐기 코드 파일

- `lib/services/auth_service.dart`
- `lib/services/sync_service.dart`
- `lib/services/sync_state.dart`
- `lib/widgets/sync_enable_card.dart`
- `lib/widgets/sync_status_dot.dart`

위 파일들을 참조하는 import / 호출 지점도 모두 정리한다 (memo_list_screen, splash_screen 등에서 잔존 여부 확인).

### 6.2 아카이브 대상 문서

다음 문서는 자동 동기화 추진 시기의 산물이다. 본 spec 채택 시 `docs/_archived/sync-2026-05/` 하위로 이동하고 README 한 줄로 "2026-05-18 자동 동기화 폐기 결정 후 아카이브" 표시.

- `docs/sync-design.md`
- `docs/sync-spec.md`
- `docs/sync-privacy-policy-draft.md`
- `docs/sync-test-scenarios.md`

## 7. UI 변경 요약 (memo_list_screen.dart)

AppBar `actions:`

- 비편집 모드: `PopupMenuButton<String>` (3-dot) 추가
  - "메모 내보내기"
  - "메모 가져오기"
  - "가져오기 되돌리기" — `memos_pre_import` 존재 시에만 항목 노출
- 편집 모드: "전체 선택" 버튼 신규 추가 (기존 "삭제 (N)" 버튼 좌측)

AppBar `leading` ("편집/취소" 토글) 은 그대로 둔다.

## 8. 테스트 시나리오

신규 작성:

- export → import 라운드트립: 메모 전체 → JSON → 같은 디바이스에서 다시 import → 합쳐진 결과가 원본과 동치
- silent merge — 같은 id 메모 `updatedAt` 최신 우선
- silent merge — 기존 메모 보존 보장 (golden path: 기존 5개 + 가져온 3개 → 최종 ≥5개)
- 잘못된 JSON 입력 → 토스트 + 기존 메모 변경 0
- 가져오기 직전 스냅샷 저장 → 되돌리기 → 직전 상태 정확히 복원
- 새 가져오기 발생 시 이전 스냅샷이 새 내용으로 덮어써짐
- 편집 모드 "전체 선택" → 기존 일괄 삭제 흐름 통해 메모 0

폐기 처리:

- 기존 sync 관련 테스트 (있다면) 는 아카이브 대상 문서와 함께 제거 또는 `_archived` 로 이동

## 9. 향후 확장 — 명시적으로 안 하는 것

본 spec 채택 후 다음은 영구 또는 무기한 보류:

- 자동 동기화 — 영구 안 함 (§2 비기능 요구사항 박제)
- N단계 import 히스토리 — 안 함 (§3.3)
- 별도 "메모 전체 삭제" 메뉴 — 안 함 (§3.4 편집 흐름 재사용)
- 스냅샷 자동 만료 / TTL — 안 함 (§3.3 영구 보존)
- 백업 파일 암호화 — 현재 안 함. 사용자가 share sheet 에서 어디로 보낼지 본인 책임. 향후 보안 우려가 사용자 채널로 들어오면 그때 재검토.
- 클라우드 자동 백업 (앱이 알아서 매주 GDrive 에 업로드) — 안 함. "자동 데이터 이동" 시나리오를 0 으로 유지.

## 10. 구현 plan

구체적인 step-by-step 구현 plan 은 다음 단계 (superpowers:writing-plans 스킬) 에서 별도 문서로 작성한다.
