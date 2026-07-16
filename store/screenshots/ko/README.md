# 메모요 스토어 스크린샷 (ko) — 2026-07-16

Flutter 3.44.0으로 iPhone 17 Pro Max(iOS 26.4)에서 실제 앱 화면을 캡처한 1.0.13 세트다. 원본은 1320×2868 RGB이며, Play용 이미지는 실제 화면을 1080×1920 캔버스에 비율 유지로 배치했다.

## Play용 1080×1920

| 파일 | 기능 | 캡션 |
| --- | --- | --- |
| `01_dark_main.png` | 다크 메모 목록 | 생각난 순간 바로 기록 |
| `02_quick_write.png` | 새 메모 입력 | 제목 없이 빠르게 쓰기 |
| `03_ai_summary.png` | AI 요약 결과 | 긴 메모도 AI로 한눈에 |
| `04_semantic_search.png` | 뜻으로 찾기 | 기억나는 말로 메모 찾기 |
| `05_premium.png` | 프리미엄 월 구독 | 월 구독으로 AI 기능 열기 |
| `06_drive_backup.png` | Google Drive 백업 | 내 Drive에 간편하게 백업 |
| `07_settings.png` | 구독·복원·정책 | 구독·복원·정책까지 투명하게 |

## 원본

- `raw/ios-current-1.0.13/`: 이번 세트의 캡션 없는 실제 렌더 원본.
- `raw/android/`, `raw/ios/`: 2026-06-04 이전 세트의 이력 보존본이며 이번 제출 소스가 아니다.
- `fastlane/screenshots/ko/iPhone 6.9 Display/`: App Store용 1320×2868 RGB 원본.

## 재현

```sh
flutter drive \
  --driver test_driver/integration_test.dart \
  --target integration_test/screenshot_test.dart \
  -d <ios-sim-udid>

python3 scripts/compose_store_screenshots.py \
  --raw build/screenshots \
  --out store/screenshots/ko \
  --raw-out store/screenshots/ko/raw/ios-current-1.0.13 \
  --ios-out "fastlane/screenshots/ko/iPhone 6.9 Display"
```

하니스는 데모 메모와 프리미엄 테스트 상태를 로컬에만 주입한다. 결제·네트워크 요청 없이 앱의 실제 위젯과 테스트 전송 계층으로 AI 요약·뜻으로 찾기 결과를 렌더한다.
