# 메모요 — 메모 이미지 첨부 (1단계) 설계

- 작성일: 2026-08-29 (KST)
- 작성자: 강대종 + 🌋 볼칸 (브레인스토밍 T-260829-022, 체크포인트 `claude-coord/brainstorm-resume/T-260829-022.md`)
- 상태: 강대종 리뷰 대기
- 영향 앱: simple_memo_app (메모요)
- 기존 버전: 1.0.18+44 (main `0eb4c3206`)
- 범위: **1단계 = 기기 저장 + 편집·목록·뷰어 UI + 공유 동봉**. 2단계(백업 zip 승격)는 별 티켓·별 spec — 본 spec 은 1단계만 다룬다.

## 1. 결정 요약

메모요 메모에 사진을 붙여 저장한다. 발원 = 아니키 볼칸챗 2026-08-29 12:17 「메모요 메모에 이미지 저장기능 추가하고 싶어」.

브레인스토밍 확정 (출처 = 아니키 발화, 시각 KST):

| 결정 | 내용 | 출처 |
|---|---|---|
| 이미지 출처 | 사진첩 + 카메라 촬영 + 클립보드 붙여넣기 3경로 | 12:36 「C로 가자, 붙여넣기까지」 |
| 메모당 장수 | 여러 장, **상한 10장**. 모델은 처음부터 목록형 | 12:42 「B, 10장까지」 |
| 배치 | 본문 TextField **아래** 가로 스크롤 썸네일 줄. 인라인(리치텍스트)·본문 위 기각 | 12:52 「A, 본문 아래로」 |
| 목록 표시 | 첫 사진 소형 썸네일을 제목 옆에 표시. 행 높이 소폭 증가 감수 | 13:00 「A, 썸네일로」 |
| 백업·공유 | **2단계 분할**. 1단계 = 기기 저장 + 공유 동봉 + 백업은 글만·안내 문구. 2단계 = 백업 zip 묶음 | 13:05 「A, 두 단계로」 |
| 기술 접근 | image_picker + pasteboard + flutter_image_compress + path_provider(기존) | 13:41 「1안 GO」 |

기각 대안과 사유:

- 인라인 삽입(리치에디터 도입): 편집창이 단일 `TextField`(+`UndoHistoryController`, 커스텀 셀렉션, 편집 밀림 프로브 T-260803-035) 라 편집기 교체급 공사 → 기각.
- `file_picker`(기존 의존성)만 사용: 카메라·붙여넣기 불가, 원본 무압축 → 출처 결정과 충돌, 기각.
- 이미지 바이트를 메모 JSON(shared_preferences blob)에 base64 내장: 전체 목록을 매 저장마다 재직렬화하는 구조라 blob 비대화·기동 지연 → 기각. 파일은 파일시스템, 메모엔 파일명만.

## 2. 비기능 요구사항 (박제)

- **기존 메모 무손실**: `images` 키가 없는 1.0.18 이하 JSON 은 그대로 열린다(빈 목록). 역방향(신 JSON → 구 앱)도 미지 키 무시로 열린다.
- **크래시 0**: 파일 소실·권한 거부·클립보드 비어 있음·압축 실패 어느 경우도 예외가 화면까지 올라오지 않는다. 단 조용히 삼키지 않고 결과 타입으로 화면에 전달한다.
- **용량 봉투**: 저장 시 긴 변 1600px·JPEG 품질 85 로 축소. 장당 대략 200~400KB, 메모당 상한 10장 ≈ 4MB.
- **권한 최소**: Android manifest 에 새 `uses-permission` 0건(Photo Picker + `ACTION_IMAGE_CAPTURE` 경로). iOS 는 사진첩·카메라 사용 문구만 추가.
- **문구 전부 `AppStrings`** (ko/en). `test/l10n/no_hardcoded_korean_test.dart` 가드 통과.
- **버전·스토어·아이콘·서명 무변경** (AGENTS.md). 릴리스 bump 는 별 티켓.

## 3. 기능 명세

### 3.1 데이터 모델 — `lib/models/memo.dart`

- 필드 추가: `final List<String> imageFiles` — 파일명만(예 `3f2a…c1.jpg`), 경로 없음. 기본 빈 목록, `List.unmodifiable`.
- `toJson`: `imageFiles` 가 비어 있으면 **키 생략**, 있으면 `'images': [...]` (기존 옵션키 관례 — `deletedAt`·`semanticEmbedding*` 와 동일).
- `fromJson`: `images` 누락·null·비-List·비-String 원소 → 빈 목록 (관대 파싱, `_parseEmbedding` 과 같은 방어 수준).
- `copyWith`: nullable 이 아니라 목록이므로 sentinel 불필요 — `List<String>? imageFiles` 로 받고 null = 유지.
- `Memo.create({content, imageFiles = const []})`.
- 상한 10 은 모델이 아니라 서비스 계층에서 강제한다(모델은 저장된 값을 있는 그대로 싣는다 — 백업 복원 등 외부 유입 값을 자르지 않는다).

### 3.2 파일 저장소 — `lib/features/attachments/`

신규 도메인 디렉토리 (AGENTS.md: 새 기능은 `lib/features/<domain>/` + `README.md` + `AGENTS.md` 동봉).

```
lib/features/attachments/
  README.md · AGENTS.md
  attachment_store.dart      // 파일 디렉토리·읽기·삭제·고아 정리
  attachment_service.dart    // 가져오기 3경로 + 압축 + 결과 타입
  image_ingest.dart          // bytes → 축소 JPEG (compressor 추상화)
  widgets/
    attachment_strip.dart    // 편집 화면 하단 썸네일 줄
    attachment_thumbnail.dart// 36px(목록)·72px(스트립) 공용 썸네일 + 플레이스홀더
    attachment_viewer.dart   // 전체화면 PageView + InteractiveViewer + 삭제
```

- 디렉토리: `<getApplicationDocumentsDirectory()>/attachments/` **평면 구조**. 메모 id 하위 폴더를 두지 않는다 — 새 메모는 저장 시점에야 id 가 발급되므로(`Memo.create`, memo_edit_screen `_buildMemo`) 편집 중 파일을 먼저 만들 수 있어야 한다.
- 파일명: `<uuid v4>.jpg`. 입력 포맷(HEIC·PNG·GIF 등)과 무관하게 저장은 JPEG 단일 — 애니메이션 GIF 는 첫 프레임만 남는다(허용 범위, 스펙 명시).
- `AttachmentStore`:
  - `Future<Directory> dir()` — 없으면 생성.
  - `File fileFor(String name)` / `Future<bool> exists(name)`.
  - `Future<void> delete(Iterable<String> names)` — 없는 파일은 무시.
  - `Future<int> sweepOrphans(Iterable<String> referenced)` — 디렉토리 안 파일 중 `referenced` 에 없는 것 삭제, 삭제 수 반환. **cold start 1회만** 호출(편집 세션이 없는 시점 → 대기 파일과 경합 없음).
  - 테스트 주입용으로 루트 디렉토리를 생성자 인자로 받는다(`path_provider` 는 기본값에서만 호출).

### 3.3 가져오기 파이프라인 — `AttachmentService`

```dart
sealed class AttachResult {}
class AttachOk       extends AttachResult { final String fileName; }
class AttachCancelled extends AttachResult {}   // 피커 취소·권한 거부(피커가 null 반환)
class AttachNoImage  extends AttachResult {}    // 클립보드에 이미지 없음
class AttachLimit    extends AttachResult {}    // 현재 장수 ≥ 10
class AttachFailed   extends AttachResult { final Object error; } // 압축·쓰기 실패
```

- `pickFromGallery(currentCount)` / `takePhoto(currentCount)` — `image_picker` `pickImage(source: gallery|camera)`. `null` = `AttachCancelled`.
- `pasteFromClipboard(currentCount)` — `pasteboard` `Pasteboard.image` → `null`/빈 바이트 = `AttachNoImage`.
- 공통: `currentCount >= 10` 이면 피커를 **열기 전에** `AttachLimit` 반환. bytes → `ImageIngest.toJpeg(bytes)` (긴 변 1600, 품질 85, EXIF 회전 굽기 — `flutter_image_compress` `compressWithList(minWidth/minHeight 1600, quality 85, autoCorrectionAngle: true, format: jpeg)`) → `AttachmentStore` 에 저장 → `AttachOk(fileName)`.
- 압축 실패 = `AttachFailed` 반환, **원본 폴백 없음**(용량 봉투 보호). 화면은 스낵바로 알린다.
- 의존성(피커·클립보드·압축기·스토어)은 전부 생성자 주입 — 위젯 테스트는 fake 로 대체한다.

### 3.4 수명 (편집 세션 ↔ 저장 ↔ 휴지통)

| 시점 | 동작 |
|---|---|
| 편집 중 사진 추가 | 파일은 즉시 저장소에 기록되고 화면 상태 `_pendingAdded` 에 파일명 적재. 메모엔 아직 미반영 |
| 편집 중 기존 사진 삭제 | 화면 상태 `_pendingRemoved` 에 적재. 파일은 아직 유지 |
| 저장(`_saveMemo`·`_saveAndPop`·스와이프 저장) | `copyWith(imageFiles: (기존 − removed) + added)` 순서 보존 → `onSave`. 그 뒤 `_pendingRemoved` 파일 삭제 |
| 취소·뒤로(미저장 경로 `_cancelEdit`) | `_pendingAdded` 파일 삭제. `_pendingRemoved` 는 무시(파일 생존) |
| 휴지통 이동(soft delete) | 파일 유지 — 복원 시 그대로 보임 |
| 영구삭제 3경로: `trash_screen._deleteForever`·`_emptyTrash`·`MemoStorage.purgeExpiredTrash` | 제거되는 메모들의 `imageFiles` 합집합을 `AttachmentStore.delete` |
| cold start(`memo_list_screen` 의 `purgeExpiredTrash` 호출 직후) | `sweepOrphans(전 메모 imageFiles 합집합)` — 저장 실패·크래시로 남은 고아 파일 안전망 |

- **사진만 있는 메모 허용**: `_buildMemo` 의 「본문 비면 null」을 「본문 비고 사진도 없으면 null」로 완화. 제목은 기존 `firstLine` 의 `untitledMemo` 폴백을 그대로 쓴다.
- 편집 밀림 프로브(T-260803-035)·undo 스택은 본문 텍스트 전용이라 사진 추가·삭제는 undo 대상이 아니다(스펙 명시, 후속 검토 여지).

### 3.5 편집 화면 — `lib/screens/memo_edit_screen.dart` (배선만)

- AppBar `actions` 맨 앞(undo 왼쪽)에 `IconButton(Icons.add_photo_alternate_outlined)`, tooltip = `AppStrings.addPhoto`.
- 탭 → `showCupertinoModalPopup` action sheet 3항목: 사진첩 / 카메라 / 붙여넣기 + 취소. 붙여넣기는 **항상 표시**(클립보드를 미리 읽어 활성/비활성을 정하면 iOS 시스템 「붙여넣기 허용?」 프롬프트가 두 번 뜬다).
- 장수 ≥ 10 이면 시트 대신 스낵바 `AppStrings.photoLimitReached`.
- 본문 `TextField` 를 `Column` 으로 감싸고 아래에 `AttachmentStrip`. **사진 0장이면 스트립 위젯 자체를 넣지 않는다** → 기존 레이아웃·탭 포커스·스크롤 동작 무변경.
- 스트립: 가로 스크롤, 72px 정사각 둥근 썸네일, 순서 = `imageFiles` 순서. 탭 = 뷰어, 길게 = 삭제 확인 다이얼로그.
- 뷰어(`AttachmentViewer`): 전체화면 다크 배경, `PageView` 로 좌우 넘김, `InteractiveViewer` 핀치 줌, 상단 닫기·삭제 버튼. 새 패키지 없음(photo_view 미도입).
- 공유(`_shareMemo`): 사진 있으면 `Share.shareXFiles([XFile...], text: content, subject: title, sharePositionOrigin)`, 없으면 기존 `Share.share` 그대로.

### 3.6 목록 화면 — `lib/screens/memo_list_screen.dart` `_MemoSwipeItem`

- Row 에서 별 아이콘 뒤·`Expanded` 제목 앞에 36px 둥근 `AttachmentThumbnail(imageFiles.first)` (`Image.file(cacheWidth: 108)`, 별도 썸네일 파일 없음).
- 파일 없으면(복원 후 등) 깨진 사진 아이콘 플레이스홀더 — 절대 예외 전파 없음(`errorBuilder`).
- 행 높이가 사진 있는 행만 소폭 커진다(Q4 확정 감수). 리오더·스와이프 위젯테스트는 높이 가정을 갱신한다.
- `search_screen.dart`·`trash_screen.dart` 의 행도 같은 위젯을 재사용한다(행 렌더러가 공용이면 자동, 아니면 배선 1곳씩).

### 3.7 백업·복원 (1단계 범위 안에서의 처리)

- export/Drive JSON 에 `images` 파일명 목록은 그대로 실린다(모델 직렬화 결과). 실물 파일은 실리지 않는다.
- `backup_restore_screen.dart` 에 안내 1줄 `AppStrings.photosNotInBackup` = 「사진은 백업에 포함되지 않습니다」.
- 복원·병합(`mergeSilently`) 로직 무변경. 복원 뒤 파일이 없는 항목은 §3.6 플레이스홀더로 보인다.
- 2단계(별 spec)에서 zip 묶음으로 승격 — 본 spec 의 `images` 키·평면 파일명 구조는 2단계가 그대로 재사용할 수 있게 설계했다(파일명만 zip 에 담으면 됨).

### 3.8 플랫폼 설정

- iOS `ios/Runner/Info.plist`: `NSPhotoLibraryUsageDescription` 문구를 「메모에 사진을 첨부하기 위해 사진 보관함 접근이 필요합니다」로 갱신(현행 문구는 내보내기용), `NSCameraUsageDescription` 신설 「메모에 붙일 사진을 촬영하기 위해 카메라 접근이 필요합니다」. iOS 배포 타깃 15.1 유지(image_picker·pasteboard 요건 충족).
- Android: manifest 무변경. `image_picker` 는 Android 13+ Photo Picker, 카메라는 `ACTION_IMAGE_CAPTURE` 인텐트라 `CAMERA` 권한 미선언이 정석(선언하면 오히려 런타임 권한이 필요해진다).
- Play 데이터 안전: 사진은 기기 내 저장만·전송 없음 → 선언 변경 없음. 릴리스 티켓 체크리스트에 「확인만」 항목으로 남긴다(`flutter-ad-stack` 감사 항목과 동일 축).

### 3.9 문구 (AppStrings, ko / en)

`addPhoto` 사진 추가 / Add photo · `fromGallery` 사진첩 / Photo library · `fromCamera` 카메라 / Camera · `pasteImage` 붙여넣기 / Paste · `noImageInClipboard` 클립보드에 사진이 없어요 / No image in clipboard · `photoLimitReached` 사진은 최대 10장까지예요 / Up to 10 photos · `photoAttachFailed` 사진을 추가하지 못했어요 / Couldn't add photo · `deletePhotoConfirmTitle` 사진 삭제 / Delete photo · `deletePhotoConfirmBody` 이 사진을 지울까요? / Delete this photo? · `photosNotInBackup` 사진은 백업에 포함되지 않습니다 / Photos are not included in backups · `photoMissing` 사진 없음 / Photo missing.

## 4. 의존성 (pubspec)

실측 2026-08-29: 볼칸 Flutter 3.41.9 stable, SDK `^3.10.7`.

- `image_picker ^1.2.3` (2026-06-30, Flutter ≥3.38 — 충족)
- `pasteboard ^0.5.0` (iOS/Android/macOS/Win/Linux/Web, `Pasteboard.image`)
- `flutter_image_compress ^2.5.1` (2026-07-25)
- 기존 재사용: `path_provider`, `share_plus`(`shareXFiles`), `uuid`.

## 5. 테스트 계획 (TDD — 테스트 먼저, 구현 뒤)

관례: `flutter_test` 위젯테스트 + `mocktail`, 골든 없음, 한국어 테스트명.

- `test/models/memo_images_test.dart`: 라운드트립 / `images` 누락→빈 목록 / 빈 목록이면 키 생략 / 비정상 값(문자열·숫자 원소) 관대 파싱 / copyWith null=유지.
- `test/features/attachments/attachment_store_test.dart` (임시 디렉토리 주입): 저장·존재·삭제·없는 파일 무시 / `sweepOrphans` 가 참조 파일은 남기고 고아만 지움.
- `test/features/attachments/attachment_service_test.dart` (fake 피커·클립보드·압축기): 상한 10 에서 `AttachLimit` 이고 피커 미호출 / 피커 null → `AttachCancelled` / 클립보드 null → `AttachNoImage` / 압축 throw → `AttachFailed` 이고 파일 미생성 / 성공 시 파일명 반환·파일 존재.
- `test/screens/memo_edit_image_test.dart`: 사진 추가 버튼 존재 / 시트 3항목 / 사진 0장이면 스트립 부재 / 사진만 있고 본문 비어도 저장 호출 / 취소 시 대기 파일 삭제·기존 파일 생존 / 저장 시 removed 파일 삭제.
- `test/screens/memo_list_thumbnail_test.dart`: 사진 있는 행에 썸네일, 없는 행엔 부재 / 파일 소실 시 플레이스홀더·예외 없음.
- 기존 테스트 보정: 목록 리오더·스와이프 높이 가정, `english_locale_smoke_test`, `no_hardcoded_korean_test` 통과.
- 영구삭제 3경로 파일 삭제는 각 경로의 기존 테스트 파일에 케이스 추가(`trash_screen`·`memo_storage`).
- **실기기 검증(단위 통과 뒤, 별도 GO)**: 볼칸 USB `device-run ios` 로 사진첩·카메라·붙여넣기(iOS 시스템 프롬프트 1회) 실동작 + 목록 썸네일 + 공유 시트에 사진 동봉 확인. 물리 기기 = R3.

## 6. 산출·마감 조건

- 브랜치 `macmini/T-260829-022-image-attachments` → PR(no-auto-merge) → 영수증 → 4노드 로스터 `bonjin-merge` 펀넬. 본 spec 문서 PR 이 선행, 구현 PR 은 writing-plans 산출 계획을 따른다.
- `README.md` 기능 목록·`CHANGELOG.md` 항목 추가(구현 PR 에서).
- 2단계 티켓(백업 zip 승격) 은 본 spec 승인 시 `sot-add` 로 발급, 발원 = T-260829-022 Q5.

## 7. 비스코프

- 백업·Drive 에 사진 실물 포함(2단계).
- 인라인(본문 중간) 이미지·리치텍스트.
- 사진 순서 변경·캡션·주석·OCR·뜻검색(semantic) 인덱싱 반영.
- 사진 추가·삭제의 undo.
- iOS `UIPasteControl`(기존 `PasteButton`) 이미지 확장으로 시스템 프롬프트 제거 — 선택 후속.
