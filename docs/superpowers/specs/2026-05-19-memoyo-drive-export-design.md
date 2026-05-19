# 메모요 1.0.7 (1) — Drive 1버튼 백업 설계

- 작성일: 2026-05-19 (KST)
- 작성자: 강대종 + Claude (Mac 본진)
- 상태: 강대종 리뷰 대기
- 영향 앱: simple_memo_app (메모요)
- 기존 버전: 1.0.6+24 (2026-05-19 share_plus iOS 26 silent fail fix)
- 메이저 1.0.7 묶음 위치: 4항목 중 (1) — 본 spec 은 (1) 만 다룸. (2) 삭제 UNDO / (3) 메모 공유 / (4) 휴지통 30일 은 별 spec

## 1. 결정 요약

1.0.6+24 까지 메모 내보내기는 시스템 share sheet 자유 선택 흐름이었다 (2026-05-18 spec §3.1 참조). 1.0.7 (1) 은 이 흐름을 폐기하고 **Google Drive 명시 1버튼 백업** 으로 갈아끼운다.

motivation: 사용자가 "내보냈는데 어디 갔지" 못 찾는 시나리오를 0 으로 만든다 ("내 메모 어디 갔어요" CS 문의 0). 메일/카톡/AirDrop 같이 백업 파일이 사라지거나 묻히는 저장처를 의사결정 경로에서 제거하고, 백업이 항상 Drive 안 같은 자리에 박혀있게 만든다.

2026-05-18 spec §2 의 "CS 부담 최소화 우선" 비기능 박제를 강화하는 forcing function 이다.

## 2. 비기능 요구사항 (재확인 + 신규 박제)

2026-05-18 spec §2 의 박제 항목은 그대로 유지:

- 무료앱 영구 유지 (광고 0, 인앱결제 0)
- CS 부담 최소화 우선
- 사용자가 명시적으로 버튼 누른 순간에만 데이터가 이동 (백그라운드 sync / 자동 백업 / 자동 복원 모두 없음)
- 기존 메모는 어떤 가져오기/병합 시나리오에서도 사라지지 않음을 코드 레벨에서 보장

본 spec 신규 박제:

- **백업 저장처는 Drive 단일 경로**. 사용자가 "어디로 보낼지" 선택하지 않는다 (share sheet 분기 없음).
- **백업 파일은 항상 같은 자리** (Drive 루트의 "Memoyo" 폴더) 에 박힌다. 사용자가 "어디 갔지" 헷갈리지 않게 단일 위치 보장.
- **Drive 권한은 최소권한 (`drive.file` scope)** 만 요청. 메모요가 만든 파일/폴더만 접근 가능, 사용자 Drive 전체 접근권 없음.

## 3. 기능 명세

### 3.1 Drive 1버튼 백업 (export)

- 진입점: AppBar 우측 3-dot overflow menu → **"Drive 에 백업"** (2026-05-18 spec 의 "메모 내보내기" 라벨 갈아끼움)
- 동작:
  1. 사용자가 메뉴 누름
  2. (첫 사용 경로) `GoogleSignIn.signIn()` → Google 계정 선택 시트 → `drive.file` scope 권한 동의 → 토큰 캐시. (재사용 경로) 캐시된 토큰 그대로 사용
  3. `AuthClient` 구성 (`extension_google_sign_in_as_googleapis_auth` 의 `authenticatedClient` 사용)
  4. "Memoyo" 폴더 검색 — `DriveApi.files.list(q: "name='Memoyo' and mimeType='application/vnd.google-apps.folder' and trashed=false")`. 결과 없으면 `DriveApi.files.create` 로 폴더 생성 (mimeType=`application/vnd.google-apps.folder`)
  5. `Memo.encodeList(memos)` 로 직렬화 → 임시 파일 `${tempDir}/memoyo-export-YYYY-MM-DD-HHMMSS.json` 작성
  6. `DriveApi.files.create` 멀티파트 업로드 (parents=[Memoyo 폴더 id], name=파일명, mimeType=`application/json`)
  7. **rotate (N=7)**: 업로드 직후 폴더 안 파일 목록 list (`orderBy: 'createdTime'`) → 7개 초과면 초과분 (`count - 7`) 만큼 가장 오래된 것부터 차례로 `DriveApi.files.delete`. 이전 실패로 누적되어 9개 이상이 된 경우도 한 번에 7개로 정리
  8. SnackBar 표시 — "Drive 에 저장됐어요" + 액션 **"Memoyo 폴더 열기"**. 액션 누르면 `url_launcher` 로 `https://drive.google.com/drive/folders/<folderId>` deep link
- modal·확인 dialog 없음 (사용자가 메뉴 누른 순간이 곧 의사 표시)

성공 path 의 사용자 인지 흐름: 한 번 누름 → (첫 사용 시만) 계정 시트 → 짧은 진행 인디케이터 → SnackBar 안내 → 액션 눌러 폴더 즉시 확인. "어디 갔지" 의문이 발생할 수 없는 구조.

### 3.2 가져오기 — 변경 없음

2026-05-18 spec §3.2 그대로. `file_picker` 로 사용자가 JSON 1개 명시 선택 → silent merge + 스냅샷. import 1버튼화 (Drive 자동 pull) 는 본 spec 범위 밖, 별도 항목으로 분리 (§9 참조).

### 3.3 1단계 undo — 변경 없음

2026-05-18 spec §3.3 그대로.

### 3.4 편집 모드 전체 선택 — 변경 없음

2026-05-18 spec §3.4 그대로.

## 4. 데이터 모델

데이터 구조 변경 없음. 신규 SharedPreferences 키 없음. Drive 측 폴더/파일 메타데이터만 신규.

- Drive 루트의 "Memoyo" 폴더 — 메모요가 자동 생성 + 자동 유지. 사용자가 직접 만들 필요 없음.
- 파일 명명: `memoyo-export-YYYY-MM-DD-HHMMSS.json` (시간순 정렬 + 가독성)
- 보존 정책: rotate N=7 (가장 최근 7개 유지, 8번째 업로드 시 가장 오래된 1개 자동 삭제)

## 5. 의존성 변경

### 5.1 추가

- `google_sign_in` ^6.2.x — 계정 선택 / 토큰 발급
- `googleapis` ^13.x — Drive v3 client (`DriveApi`)
- `extension_google_sign_in_as_googleapis_auth` ^2.x — google_sign_in 의 `GoogleSignInAccount` 를 googleapis 호환 `AuthClient` 로 wrap
- `url_launcher` ^6.x — SnackBar 액션의 Drive 폴더 deep link. 현재 메모요 pubspec.yaml 에 미존재 — 본 spec 채택 시 신규 추가

### 5.2 유지

- `share_plus` — 1.0.7 (3) 메모 공유 (단건) 에서 사용 예정이므로 패키지 의존성 유지. 단 export 흐름의 호출 코드는 제거 (§5.3).
- `file_picker` — 2026-05-18 spec §3.2 가져오기에서 사용 중, 그대로.

### 5.3 코드 제거

- `lib/services/export_import_service.dart` 의 `shareExport()` 메서드 — share_plus 호출 흐름. 본 spec 채택 시 retire (메서드 자체 제거 + 호출처 정리)
- `lib/screens/memo_list_screen.dart` 의 `_onOverflowSelected` 에서 `'export'` case 의 share_plus 흐름 호출 → `DriveBackupService.uploadBackup` 호출로 대체

## 6. 아키텍처

신규 서비스 파일 1개:

- `lib/services/drive_backup_service.dart` — 정적 메서드 `Future<DriveBackupResult> uploadBackup(List<Memo> memos)` + sealed class `DriveBackupResult` (success/network/permission/quota/unknown)

호출 사슬:

```
memo_list_screen._onOverflowSelected('drive_backup')
  → DriveBackupService.uploadBackup(memos)
    → GoogleSignIn.signIn() / cached
    → authenticatedClient
    → DriveApi.files.list (Memoyo 검색)
    → DriveApi.files.create (폴더 없으면 생성)
    → temp file write
    → DriveApi.files.create (멀티파트 업로드)
    → DriveApi.files.list (orderBy=createdTime, rotate)
    → DriveApi.files.delete (8개 이상 시 가장 오래된 1개)
  ← DriveBackupResult.success(folderUrl)
  → SnackBar + 액션 "Memoyo 폴더 열기" → url_launcher
```

## 7. UI 변경 요약 (memo_list_screen.dart)

AppBar `actions:` 비편집 모드 `PopupMenuButton<String>`:

- **"Drive 에 백업"** (변경: 기존 "메모 내보내기" → 라벨 + 동작 갈아끼움)
- "메모 가져오기" (그대로)
- "가져오기 되돌리기" (그대로, 스냅샷 존재 시에만)

편집 모드 AppBar actions ("전체 선택" + "삭제 (N)") — 변경 없음.

`leading` 편집/취소 토글 — 변경 없음.

## 8. 에러 처리

`DriveBackupService.uploadBackup` 의 모든 외부 호출은 try/catch 로 감싸진다 (silent fail 0). 발생 가능 케이스 4 + 1:

- `NetworkError` — 인터넷 X / DNS 실패. SnackBar "인터넷 연결을 확인해주세요"
- `PermissionDenied` — 사용자가 OAuth 동의 화면에서 거부 / scope 부족. SnackBar "Drive 권한이 필요해요"
- `QuotaExceeded` — Drive 용량 풀 (15 GB 초과). SnackBar "Drive 용량이 부족해요"
- `Unknown(message)` — 위 분류 외 모든 에러. SnackBar "Drive 백업 실패: $message" (디버깅 단서 노출)
- 토큰 만료 — googleapis 가 자동 갱신 시도, 갱신 실패 시 `GoogleSignIn.signInSilently()` → 사용자에게 재로그인 트리거. 결과적으로 위 4 케이스 중 하나로 떨어짐

성공 시 `DriveBackupResult.success(folderUrl)` 반환, caller (memo_list_screen) 가 SnackBar 표시.

## 9. 향후 확장 — 명시적으로 안 하는 것

본 spec 범위 외:

- **import 1버튼화 (Drive 자동 pull)** — 본 spec 범위 밖. 별 항목으로 분리. motivation 인 "어디 갔지" 문제는 export 쪽에만 있고, import 는 file_picker 가 사용자 명시 선택이라 같은 문제 없음.
- **자동 백업 (앱이 알아서 매주 GDrive 업로드)** — 2026-05-18 spec §9 박제 그대로. "자동 데이터 이동" 시나리오 0 유지.
- **Drive 외 클라우드 (iCloud / Dropbox 등)** — 무지원. 분기 추가 시 CS 부담 증가, motivation 위반.
- **백업 파일 암호화** — 본 spec 범위 밖. 사용자 본인 Drive 안 단일 폴더에 박는 거라 노출 위험 작음. 향후 사용자 채널 우려 들어오면 재검토.
- **Drive 계정 변경 UI** (다른 계정으로 갈아끼움) — 본 spec 범위 밖. 1.0.7 후속 또는 사용자 요청 들어오면 추가.
- **rotate 정책 변경** — N=7 고정. 사용자 설정 X (CS 부담 최소화).

## 10. iOS / Android 셋업 (high-level)

본 spec 단계는 셋업 코스트 있음만 박고, 디테일은 다음 단계 (writing-plans) plan 문서에서.

- **iOS**: Google Cloud Console 에 OAuth client (iOS type) 생성 → REVERSED_CLIENT_ID URL scheme 을 `ios/Runner/Info.plist` 의 `CFBundleURLTypes` 에 추가 → bundle id 매칭 확인
- **Android**: Google Cloud Console OAuth client (Android type) → 메모요 release keystore 의 SHA-1 fingerprint 등록 (debug 도 같이 등록하면 개발 편의)
- 두 OAuth client 의 client_id 는 google_sign_in 이 platform 별로 자동 인식 (별도 dart 코드 박을 필요 없음)

셋업 후 첫 빌드/배포는 mac mini night-builder v2 를 거치며 keystore 8파일 (이미 구비) 그대로 사용.

## 11. 테스트 시나리오

신규 작성:

- `DriveBackupService.uploadBackup` mock test — DriveApi mockable, GoogleSignIn mockable
  - 정상 path: Memoyo 폴더 없음 → 생성 → 파일 업로드 → result.success(folderUrl)
  - 정상 path: Memoyo 폴더 있음 → 폴더 search hit → 파일 업로드 → result.success
  - rotate 경계: 폴더 안 파일 7개 + 새 업로드 → 8개 됨 → 가장 오래된 1개 삭제 → 7개 유지
  - rotate 경계: 폴더 안 파일 8개 (이전 실패로 누적) + 새 업로드 → 9개 → 초과분 2개 (`count - N` = 9 - 7) 삭제 → 7개 유지
- 에러 매핑 단위 테스트 — `SocketException` → NetworkError / OAuth 거부 → PermissionDenied / `403 storageQuotaExceeded` → QuotaExceeded / 그 외 → Unknown
- memo_list_screen 위젯 테스트 — "Drive 에 백업" 메뉴 클릭 시 DriveBackupService 호출 (mock)

manual smoke test (강대종 본인 계정 1회):

- 첫 누름 → OAuth 시트 → 권한 동의 → Memoyo 폴더 자동 생성 확인 (Drive 앱에서 눈으로) → 백업 파일 1개 박힘 확인
- 8번 연속 누름 → 폴더에 7개만 남는지 확인 (rotate 동작)
- SnackBar "Memoyo 폴더 열기" 액션 → Drive 앱에서 폴더 deep link 열림 확인

폐기 처리:

- 2026-05-18 spec §8 의 "export → import 라운드트립" 테스트 — share_plus 흐름 retire 되니까 deprecate (해당 테스트 코드 제거 또는 import 단독 라운드트립으로 축소)

## 12. 구현 plan

구체적인 step-by-step 구현 plan 은 다음 단계 (superpowers:writing-plans 스킬) 에서 별도 문서로 작성.

writing-plans 진입 후 plan 실행 단계에서 loop-fleet (5노드 dynamic fan-out) 가능성을 사전에 surface — 토큰 비용 영향 있으므로 발동 직전 강대종 ack.
