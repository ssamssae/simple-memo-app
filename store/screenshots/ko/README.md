# 메모요 스토어 스크린샷 (ko) — 2026-08-05

Flutter 3.41.9로 iPhone 17 Pro Max(iOS 26.4) 시뮬레이터에서 실제 앱 화면을 캡처한 1.0.18 세트다. 원본은 1320×2868 RGB이며, Play용 이미지는 실제 화면을 1080×1920 캔버스에 비율 유지로 배치했다.

## Play용 1080×1920

| 파일 | 기능 | 캡션 | raw |
| --- | --- | --- | --- |
| `01_dark_main.png` | 다크 메모 목록 | 생각난 순간 바로 기록 | `01-main.png` |
| `02_quick_write.png` | 새 메모 입력 | 제목 없이 빠르게 쓰기 | `05-edit.png` |
| `06_drive_backup.png` | Google Drive 백업 | 내 Drive에 간편하게 백업 | `03-backup.png` |
| `07_settings.png` | 광고 제거·복원·정책 | 광고 제거·복원·정책까지 투명하게 | `02-settings.png` |

★번호 구멍(03·04·05 결번)은 결함이 아니다. 출고본에 없는 기능의 컷 3장(AI 요약 · 뜻으로 찾기 · 프리미엄 월 구독)을 T-260805-082 로 매니페스트에서 뺀 자국이고, 남은 4장을 재번호하지 않는 이유는 이름순 정렬이 이미 노출 순서라서다. 매니페스트의 정본은 `scripts/compose_store_screenshots.py` 의 `SCENES` 다 — 이 표는 그 사본이니 어긋나면 SCENES 를 믿어라.

## 원본

- `raw/ios-current-1.0.13/`: 이번 세트의 캡션 없는 실제 렌더 원본 4장. ★디렉토리 이름의 `1.0.13` 은 처음 만들 때 붙은 이름이 굳은 것이고, 안에 든 것은 위 표와 같은 현행 세트다.
- `raw/android/`, `raw/ios/`: 2026-06-04 이전 세트의 이력 보존본이며 이번 제출 소스가 아니다.
- `fastlane/screenshots/ko/iPhone 6.9 Display/`: App Store용 1320×2868 RGB 원본. ★`fastlane deliver` 가 업로드에 실제로 집어가는 건 이 디렉토리다 — 여기를 갱신하지 않으면 이 폴더를 아무리 고쳐도 옛 이미지가 올라간다 (T-260805-129).

## 재현

```sh
# ① 캡처 — 시뮬레이터 실 렌더를 build/screenshots/<label>/ 로 산출
SHOT_ONLY=iphone-6.9 bash scripts/gen-store-screenshots.sh

# ② 합성 — 세 출력 경로를 한 번에 채운다. ★--ios-out 을 빠뜨리면 fastlane 업로드분이 낡는다
python3 scripts/compose_store_screenshots.py \
  --raw build/screenshots/iphone-6.9 \
  --out store/screenshots/ko \
  --raw-out store/screenshots/ko/raw/ios-current-1.0.13 \
  --ios-out "fastlane/screenshots/ko/iPhone 6.9 Display"
```

①의 산출 경로는 `build/screenshots/<label>/` 이라 ②의 `--raw` 에 그 하위(`iphone-6.9`)까지 적어야 한다. 상위만 주면 `raw 없음` 으로 죽는다.

하니스는 데모 메모를 로컬에만 주입한다. 결제·네트워크 요청 없이 앱의 실제 위젯을 렌더한다.

## 갱신할 때

캡처를 다시 뜨면 ★매니페스트에서 빠진 컷의 옛 산출물이 세 경로에 그대로 남는다. ②는 SCENES 에 있는 파일만 덮어쓰고, 없어진 파일은 지우지 않기 때문이다. PR#124 가 SCENES 만 고치고 PNG 를 남겨 폐지 문구가 픽셀에 구워진 채 3주를 버틴 게 이 경우다(T-260805-129). 컷을 뺐다면 세 경로에서 그 파일도 함께 지워라.

검증은 파일명 grep 으로 부족하다 — 문구가 이미지 안에 렌더돼 있어서다. macOS Vision OCR 로 픽셀을 읽어 대조하고, 반드시 ★머지 전 상태에서도 같은 검사로 검출되는지(양성 대조군) 함께 확인해라. 안 그러면 계기가 항상 초록인지 구분이 안 된다.
