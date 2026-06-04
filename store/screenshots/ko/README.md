# 메모요 Play Store 스크린샷 후보 (ko) — 2026-06-04

자동 캡처 + 한글 캡션 합성한 **후보 세트**. (실제 스토어 업로드는 게이트 — 아니키/본진 픽 후)

## 후보 (1080×1920, Play-safe 9:16)
| 파일 | 기능 | 캡션 |
|------|------|------|
| 01_dark_main.png | 다크 메인(메모 리스트) | 어두운 화면, 눈이 편하게 |
| 02_quick_write.png | 즉시 입력(켜자마자 작성) | 켜자마자 바로 한 줄 |
| 03_drive_backup.png | Google Drive 백업 메뉴 | 한 번에 구글 드라이브 백업 |
| 04_settings.png | 설정(약관·정책·평가) | 약관·정책까지 투명하게 |

`raw/` = 캡션 없는 원본 캡처(1206×2622, iPhone 17 시뮬 실제 화면).

## 생성 방법(재현)
1. integration_test 하니스로 부팅된 시뮬에서 실제 화면 캡처(목업 합성 X):
   `flutter drive --driver test_driver/integration_test.dart --target integration_test/screenshot_test.dart -d <sim>`
   → 데모 메모 시드 + 4화면 네비게이션 + takeScreenshot → `build/screenshots/*.png`
2. `python3 scripts/overlay`(PIL)로 1080×1920 Play-safe 캔버스에 한글 캡션 헤더 + 스크린샷 레터박스 합성.

## 주의 / 후속
- ⚠️ 원본(1206×2622)은 비율 1:2.17 로 Play 상한(≤2:1) 초과 → 1080×1920 캔버스 합성으로 해소.
- 캡처는 **iOS 시뮬(iPhone 17)** — 맥미니에 Android 에뮬/AVD 부재. Play(Android) 정석은 Android 에뮬 캡처이나 Flutter UI 콘텐츠는 동일. Android 프레임 정합이 필요하면 별 작업(에뮬 셋업).
- 캡션 카피는 후보 — 톤 대안은 보고 참조.
