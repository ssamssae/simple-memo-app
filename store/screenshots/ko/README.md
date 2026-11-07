# 메모요 스토어 스크린샷 — 1.0.25(53), 2026-11-07

현재 세트의 파일·언어·규격·SHA-256 정본은 [`../current-manifest.json`](../current-manifest.json)이다. iOS 12장과 Android 4장을 실제 앱의 시뮬레이터·에뮬레이터 렌더에서 가져왔다. 화면 구성은 목록, 새 메모, 백업, 설정 순서다. `01_dark_main.png`는 업로드 순서를 보존한 기존 파일명이며 현재 화면은 라이트다.

| 업로드 경로 | 등록 언어 | 화면 수 | 규격 |
| --- | --- | --- | --- |
| `fastlane/screenshots/<locale>/iPhone 6.9 Display/` | ko, en-US, ja | 언어당 4장 | 1320×2868 RGB PNG |
| `store/screenshots/ko/` | Play ko-KR | 4장 | 1080×1920 RGB PNG |

파일명은 `01_dark_main.png`, `02_quick_write.png`, `06_drive_backup.png`, `07_settings.png`다. 번호는 기존 업로드 순서를 유지한다. 기존 Play 영어 등록에는 이미지가 없으며 이번 교체는 한국어 휴대전화 슬롯만 대상으로 한다. 현재 ASC에는 iPad 스크린샷이 없다.

## 촬영 내용과 검증

- 소스: `a76567548d8ad1c0ef2b7f27ca3c7d5c4f417dfe`, 출시 버전 `1.0.25+53`.
- iOS: 격리한 iPhone 18 Pro Max / iOS 27.0 시뮬레이터, Flutter 3.47.8.
- Android: 격리한 Pixel 7 / Android 14 에뮬레이터. 디스플레이 1080×1983, dpi 420에서 시스템 내비게이션 영역을 제외한 앱 렌더는 1080×1920이다. 원본을 늘리거나 자르지 않는다.
- 한국어·영어 UI를 사용한다. 일본어 스토어 사진은 지원되는 영어 UI와 일본어 예시 메모를 사용한다.
- 예시 메모 5개와 기존 광고 제거 상태를 로컬 픽스처로 사용한다. 실제 구매·로그인·백업 업로드를 실행하지 않는다. 운영 메모는 읽지 않는다.
- `integration_test/store_current_screenshots_test.dart`는 네이티브 PackageInfo의 버전/빌드와 요청값을 대조한다. 설정의 `뜻 검색`, `뜻으로 찾기`, `Semantic search` 부재를 검사한다. 백업 화면의 실제 버전 표기를 검사한다.
- 육안 검사와 OCR로 삭제된 메뉴 부재, `v1.0.25`, 글자와 화면 배치를 확인했다. 기존 스토어 이미지에서 `뜻 검색`과 `v1.0.22`를 검출하는 양성 대조군도 확인했다.
- RGB 내보내기는 모든 원본 픽셀이 불투명한지 검사한 뒤 알파 채널만 제거한다.
- 근거: `/Users/user/reports/T-261105-008/`의 촬영 로그, `iphone-ocr.json`, `android-ocr.json`, 스토어 전후 스냅샷.

## 재현

촬영은 작업 전용 기기에서 실행한다. 사용자 앱이 설치된 기기에 적용하지 않는다. 스크립트가 끝나면 이 작업이 부팅한 기기만 종료한다.

```sh
# iOS: 자신의 격리 기기 이름을 넣는다. pubspec.yaml 버전을 자동 대조한다.
SHOT_ONLY=iphone-6.9 IPHONE_DEVICE_NAME="<작업 전용 iPhone>" \
  bash scripts/gen-store-screenshots.sh

# Android: 작업 전용 에뮬레이터에서 실행한다. 버전값은 pubspec.yaml과 같아야 한다.
adb -s <작업 전용 serial> shell wm size 1080x1983
adb -s <작업 전용 serial> shell wm density 420
adb -s <작업 전용 serial> shell cmd uimode night no
SHOT_DEVICE=android-phone flutter drive \
  --driver=test_driver/store_screenshots_test.dart \
  --target=integration_test/store_current_screenshots_test.dart \
  -d <작업 전용 serial> --no-dds \
  --dart-define=STORE_CAPTURE_VERSION=1.0.25 \
  --dart-define=STORE_CAPTURE_BUILD=53

# 원본 <locale>__<scene>.png를 업로드 파일명에 대응시켜 RGB PNG로 내보낸다.
xcrun swift scripts/export_store_screenshot_rgb.swift <원본.png> <업로드.png>
```

촬영·내보내기 이후 매니페스트 SHA-256, 슬롯별 개수·규격, 버전 표기와 메뉴를 다시 확인한다. `scripts/compose_store_screenshots.py`, `test/store_capture_test.dart`, 옛 `integration_test/screenshot_test.dart`는 이번 세트의 입력이 아니다. `raw/` 폴더는 과거 이력이며 업로드 소스가 아니다.

## 반영 상태

저장소 갱신과 스토어 공개 반영은 별도다. Play는 미리보기 승인 뒤 기존 한국어 휴대전화 사진 4장을 교체한다. iOS는 기존 요청대로 다음 버전 제출에 함께 반영한다. 이 사진 변경만을 위한 새 앱 버전은 만들지 않는다. 사진을 제출할 때 실제 출시 코드와 다시 대조한다.
