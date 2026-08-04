#!/usr/bin/env bash
# 메모요 스토어 스크린샷 캡처 — iOS 시뮬레이터 실 렌더를 PNG 로 산출 (T-260805-017).
#
# 이전 상태: integration_test 가 "[store-shot-ready]" 마커만 찍고 12초 대기했고,
# 실제 촬영은 repo 밖의 손이 했다. 그 손에 해당하는 스크립트가 없어서 재현이 안 됐다.
# 이 스크립트가 그 손을 대체한다.
#
# 설계 규칙 (한줄일기 스크립트의 실패에서 가져온 것):
#   1. UDID 를 /tmp 파일에서 읽지 않는다 — 기기 "이름"으로 simctl 에서 매번 해석한다.
#      (옛 방식은 그 파일을 만드는 단계가 repo 에 없어 새 노드에서 항상 빈 값이었다)
#   2. 한 장도 못 찍으면 ★비영으로 죽는다. 침묵 성공을 만들지 않는다.
#   3. flutter 가 PATH 에 없어도 동작한다 (헤르메스 노드는 PATH 미등록 상태다).
#
# 사용:
#   bash scripts/gen-store-screenshots.sh                  # 전체 기기
#   SHOT_ONLY=iphone-6.9 bash scripts/gen-store-screenshots.sh
#   IPHONE_DEVICE_NAME="iPhone 17 Pro" bash scripts/gen-store-screenshots.sh
#
# 산출: build/screenshots/<label>/<name>.png
#   합성은 별도 단계다: python3 scripts/compose_store_screenshots.py \
#                        --raw build/screenshots/<label> --out store/screenshots/ko
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# ── flutter 위치 (PATH 미등록 노드 대응) ──────────────────────────────────────
FLUTTER="${FLUTTER_BIN:-$(command -v flutter || true)}"
[ -n "$FLUTTER" ] || FLUTTER="$HOME/flutter/bin/flutter"
if [ ! -x "$FLUTTER" ]; then
  echo "❌ flutter 실행파일을 못 찾았다. FLUTTER_BIN=/path/to/flutter 로 지정해라." >&2
  exit 1
fi

# ── 선행조건: Swift Package Manager 는 꺼져 있어야 한다 ───────────────────────
# 켜져 있으면 pod install 이 이렇게 죽는다 (2026-08-05 실측):
#   "A dependency conflict has occurred because google_mobile_ads uses CocoaPods
#    while webview_flutter_wkwebview uses Swift Package Manager."
# 앱이 시뮬레이터에 안 올라가므로 캡처가 0장이 된다. 조용히 넘기지 않고 여기서 죽인다.
# (repo 의 pubspec 을 고쳐 끄는 길도 있지만 그건 릴리스 빌드까지 바꾼다 — 노드 설정으로 둔다)
# 설정 파일 경로는 Flutter 판본에 따라 갈린다 — 있는 것을 전부 본다.
#   3.4x: ~/.config/flutter/settings   (구판: ~/.flutter_settings)
spm_off=0
for _s in "$HOME/.config/flutter/settings" "$HOME/.flutter_settings"; do
  if /usr/bin/grep -q '"enable-swift-package-manager": *false' "$_s" 2>/dev/null; then
    spm_off=1
    break
  fi
done
if [ "$spm_off" -ne 1 ]; then
  echo "❌ 이 노드에서 Swift Package Manager 가 꺼져 있지 않다." >&2
  echo "   google_mobile_ads(CocoaPods)와 충돌해 앱이 안 뜨고 캡처가 0장이 된다." >&2
  echo "   한 번만 실행해라:  $FLUTTER config --no-enable-swift-package-manager" >&2
  exit 1
fi

# ── 캡처 대상 기기 (App Store 스크린샷 슬롯 기준) ─────────────────────────────
IPHONE_DEVICE_NAME="${IPHONE_DEVICE_NAME:-iPhone 17 Pro Max}"
IPAD_DEVICE_NAME="${IPAD_DEVICE_NAME:-iPad Pro 13-inch (M5)}"

# 기기 "이름" → UDID. 정확히 그 이름인 줄만 고른다.
# ("iPhone 17 Pro" 가 "iPhone 17 Pro Max" 를 잡지 않도록 이름 뒤 " (" 를 앵커로 쓴다)
resolve_udid() {
  local name="$1"
  xcrun simctl list devices available \
    | awk -v n="$name" '
        index($0, "    " n " (") == 1 {
          if (match($0, /\(([0-9A-F-]{36})\)/)) {
            print substr($0, RSTART + 1, RLENGTH - 2); exit
          }
        }'
}

shots_written=0

drive_one() {
  local label="$1" device_name="$2"
  local udid
  udid="$(resolve_udid "$device_name")"

  if [ -z "$udid" ]; then
    echo "⚠️  [$label] 시뮬레이터 '$device_name' 이 없다 — 건너뛴다." >&2
    echo "    설치된 기기: xcrun simctl list devices available" >&2
    return 0
  fi

  local out="build/screenshots/$label"
  rm -rf "$out"

  echo "📸 [$label] $device_name ($udid) 부팅 ..."
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true

  # 스토어 캡처용 상태바 고정 (실패해도 캡처 자체는 계속한다)
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --wifiBars 3 --cellularBars 4 >/dev/null 2>&1 || true

  echo "📸 [$label] flutter drive ..."
  SHOT_DEVICE="$label" "$FLUTTER" drive \
    --driver=test_driver/store_screenshots_test.dart \
    --target=integration_test/screenshot_test.dart \
    -d "$udid" \
    --no-dds

  # ★0매치를 정상 경로로 흘려보내고 판정은 계수로 한다.
  # 옛 형태 `ls "$out"/*.png 2>/dev/null | awk …` 는 매치가 0건이면 ls 가 비영으로
  # 끝나고 set -o pipefail 이 그것을 파이프 전체로 전파한다. 그러면 set -e 가
  # ★바로 아래 진단 echo 에 닿기 전에 스크립트를 죽인다 — rc 는 1로 맞지만
  # 이유가 한 줄도 안 남는다. 디렉토리 자체가 없을 때는 find 도 같은 방식으로 죽으므로
  # 그룹 안에서 || true 로 흡수해야 한다 (T-260805-039, 형태는 hanjul PR#96 과 동일).
  local n
  n="$({ find "$out" -maxdepth 1 -type f -name "*.png" 2>/dev/null || true; } | awk 'END{print NR+0}')"
  if [ "$n" -eq 0 ]; then
    echo "❌ [$label] flutter drive 는 끝났는데 PNG 가 0장이다 — $out" >&2
    return 1
  fi
  shots_written=$((shots_written + n))
  echo "✅ [$label] $n 장 → $out/"
  sips -g pixelWidth -g pixelHeight "$out"/*.png 2>/dev/null \
    | awk '/\//{f=$0} /pixelWidth/{w=$2} /pixelHeight/{print f"  "w"x"$2}'
}

only="${SHOT_ONLY:-}"
if [ -z "$only" ] || [ "$only" = "iphone-6.9" ]; then
  drive_one "iphone-6.9" "$IPHONE_DEVICE_NAME"
fi
if [ -z "$only" ] || [ "$only" = "ipad-13" ]; then
  drive_one "ipad-13" "$IPAD_DEVICE_NAME"
fi

# ── 침묵 성공 금지 ────────────────────────────────────────────────────────────
if [ "$shots_written" -eq 0 ]; then
  echo "❌ 캡처된 PNG 가 한 장도 없다. 성공으로 끝내지 않는다." >&2
  exit 1
fi
echo "🎉 총 $shots_written 장 캡처 완료."
