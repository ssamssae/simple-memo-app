# 메모요 Play Store 스크린샷 후보 (ko) — 2026-06-04

자동 캡처 + 한글 캡션 합성한 **후보 세트**. (실제 스토어 업로드는 게이트 — 아니키/본진 픽 후)

현재 스토어 후보(`01_dark_main`~`04_settings`)는 **Android 에뮬레이터(Pixel 7, API 34, arm64) 정석 캡처** 기준. (이전 iOS 시뮬 캡처는 `raw/ios/` 에 보존.)

## 후보 (1080×1920, Play-safe 9:16)
| 파일 | 기능 | 캡션 |
|------|------|------|
| 01_dark_main.png | 다크 메인(메모 리스트) | 어두운 화면, 눈이 편하게 |
| 02_quick_write.png | 즉시 입력(켜자마자 작성) | 켜자마자 바로 한 줄 |
| 03_drive_backup.png | Google Drive 백업 메뉴 | 한 번에 구글 드라이브 백업 |
| 04_settings.png | 설정(약관·정책·평가) | 약관·정책까지 투명하게 |

## raw 원본
- `raw/android/` = 캡션 없는 Android 원본 캡처(1080×2337, Pixel 7 에뮬 실제 화면) — **현재 후보의 소스**.
- `raw/ios/` = 이전 iOS 시뮬(iPhone 17) 원본 캡처(1206×2622) — 히스토리 보존.

## 생성 방법(재현)
1. Android 에뮬레이터 준비 (맥미니 M1 = arm64):
   ```
   sdkmanager "emulator" "system-images;android-34;google_apis;arm64-v8a"
   avdmanager create avd -n memoyo_pixel7 \
     -k "system-images;android-34;google_apis;arm64-v8a" -d pixel_7
   emulator -avd memoyo_pixel7 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect
   adb shell cmd uimode night yes   # 다크모드
   ```
2. integration_test 하니스로 부팅된 에뮬에서 실제 화면 캡처(목업 합성 X):
   ```
   flutter drive --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart -d emulator-5554
   ```
   → 데모 메모 시드 + 4화면 네비게이션 + takeScreenshot → `build/screenshots/*.png`
3. PIL 합성으로 1080×1920 Play-safe 캔버스에 amber 한글 캡션 헤더 + 스크린샷 레터박스:
   ```
   python3 scripts/compose_store_screenshots.py \
     --raw build/screenshots --out store/screenshots/ko \
     --raw-out store/screenshots/ko/raw/android
   ```

## 주의 / 후속
- ⚠️ 원본 비율(1080×2337 = 1:2.16)은 Play 상한(≤2:1)을 살짝 초과 → 1080×1920 캔버스 합성으로 해소.
- "vdev · 강대종" 푸터는 **앱 화면 자체**에 렌더되는 워터마크 — 합성 스크립트가 별도로 추가하지 않음(이중 방지).
- 캡션 카피는 기본안 확정.
