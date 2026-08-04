#!/usr/bin/env bash
# T-260805-038 — gen-store-screenshots.sh 0장 경로 ★진단 회귀 픽스처.
#
# 왜 있는가: 계수를 `ls "$out"/*.png 2>/dev/null | awk …` 로 쓰면 매치 0건일 때
# ls 가 비영으로 끝나고 `set -o pipefail` 이 그것을 파이프 전체로 전파해,
# ★바로 다음 줄의 진단 echo 에 닿기 전에 `set -e` 가 스크립트를 죽인다.
# 종료코드 1 은 맞는데 ★이유가 한 줄도 안 남는다 — 실패를 가장 알고 싶은 순간에
# 화면이 비어 있다. 디렉토리 자체가 없으면 `find` 로 바꿔도 같은 방식으로 죽으므로
# 그룹 안에서 `|| true` 로 흡수해야 한다.
#
# 이 픽스처가 고정하는 계약 = 「0장이면 ★이유 한 줄 + 비영 종료」.
#   rc 만 재면 수리 전에도 rc=1 이라 통과한다. 그래서 ★출력까지 본다.
#
# 실 flutter·실 시뮬레이터·실 캡처는 절대 타지 않는다. PATH 앞에 xcrun/flutter/sips
# 스텁을 꽂고, 스크립트를 샌드박스로 복사해 실행한다(스크립트가 자기 상위 디렉토리로
# cd 하므로, 복사하지 않으면 실 repo 의 build/ 를 rm -rf 한다).
#
# 대상 스크립트는 GEN_SCRIPT 로 바꿔 끼울 수 있다 — 음성 대조군(옛 판을 넣으면 FAIL)
# 을 돌리기 위한 것이다.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${GEN_SCRIPT:-$ROOT/scripts/gen-store-screenshots.sh}"

pass=0; fail=0
ok()  { echo "ok:   $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

UDID="12345678-1234-1234-1234-1234567890AB"
DEVICE="iPhone 17 Pro Max"
LABEL="iphone-6.9"
EXPECT_W=1320
EXPECT_H=2868

# $1 = flutter 스텁이 할 일 ('' = 아무 것도 안 함 / 'mkdir' = 출력 디렉토리만 생성
#                            / 'png' = PNG 1장까지 생성)
setup() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/repo/scripts" "$SANDBOX/bin" "$SANDBOX/home/.config/flutter"
  cp "$SCRIPT" "$SANDBOX/repo/scripts/gen-store-screenshots.sh"
  chmod +x "$SANDBOX/repo/scripts/gen-store-screenshots.sh"

  # SPM 선행조건 통과용 (스크립트가 $HOME 아래를 본다)
  printf '{\n  "enable-swift-package-manager": false\n}\n' \
    > "$SANDBOX/home/.config/flutter/settings"

  # xcrun 스텁 — simctl list 만 답한다. boot/bootstatus/status_bar 는 무시.
  # resolve_udid 는 "공백4 + 기기이름 + ' ('" 로 시작하는 줄만 고른다.
  {
    echo '#!/bin/sh'
    echo 'case "$2" in'
    echo "  list) printf '    %s (%s) (Shutdown)\\n' '$DEVICE' '$UDID' ;;"
    echo 'esac'
    echo 'exit 0'
  } > "$SANDBOX/bin/xcrun"

  # flutter 스텁 — 실제 캡처 대신 지정된 만큼만 만든다.
  {
    echo '#!/bin/sh'
    case "$1" in
      mkdir) echo "mkdir -p build/screenshots/$LABEL" ;;
      png)   echo "mkdir -p build/screenshots/$LABEL"
             echo "printf 'x' > build/screenshots/$LABEL/01-main.png" ;;
    esac
    echo 'exit 0'
  } > "$SANDBOX/bin/flutter"

  # sips 스텁 — 해상도 대조를 통과시킨다(이 픽스처가 재는 것은 해상도가 아니다).
  {
    echo '#!/bin/sh'
    echo "echo '  pixelWidth: $EXPECT_W'"
    echo "echo '  pixelHeight: $EXPECT_H'"
    echo 'exit 0'
  } > "$SANDBOX/bin/sips"

  chmod +x "$SANDBOX/bin/xcrun" "$SANDBOX/bin/flutter" "$SANDBOX/bin/sips"
}

teardown() { [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"; }

# 스크립트를 샌드박스에서 돌리고 rc·출력을 전역에 채운다.
run_script() {
  OUT="$(
    cd "$SANDBOX/repo" || exit 99
    HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" \
      SHOT_ONLY="$LABEL" FLUTTER_BIN="$SANDBOX/bin/flutter" \
      bash scripts/gen-store-screenshots.sh 2>&1
  )"
  RC=$?
}

# ── 1. 출력 디렉토리가 없는 채로 0장 ────────────────────────────────────────
setup ''
run_script
[ "$RC" -ne 0 ] \
  && ok "디렉토리 부재·0장: 비영 종료 (rc=$RC)" \
  || bad "디렉토리 부재·0장: rc=0 으로 통과했다 — 조용한 성공이다"
case "$OUT" in
  *"PNG 가 0장이다"*) ok "디렉토리 부재·0장: ★이유를 출력한다" ;;
  *) bad "디렉토리 부재·0장: rc 는 맞는데 ★이유가 없다 — 진단이 죽었다. 출력=[$OUT]" ;;
esac
teardown

# ── 2. 디렉토리는 있고 PNG 만 0장 ───────────────────────────────────────────
# (스크립트가 drive 전에 rm -rf 하므로, 스텁이 만들어야 이 상태가 재현된다)
setup 'mkdir'
run_script
[ "$RC" -ne 0 ] \
  && ok "디렉토리 존재·PNG 0장: 비영 종료 (rc=$RC)" \
  || bad "디렉토리 존재·PNG 0장: rc=0 으로 통과했다"
case "$OUT" in
  *"PNG 가 0장이다"*) ok "디렉토리 존재·PNG 0장: ★이유를 출력한다" ;;
  *) bad "디렉토리 존재·PNG 0장: ★이유가 없다. 출력=[$OUT]" ;;
esac
teardown

# ── 3. 정상 경로 회귀 — 파일이 있으면 종전대로 통과 ─────────────────────────
setup 'png'
run_script
[ "$RC" -eq 0 ] \
  && ok "정상 경로: rc=0" \
  || bad "정상 경로: 파일이 있는데 rc=$RC 로 죽었다. 출력=[$OUT]"
case "$OUT" in
  *"1 장"*) ok "정상 경로: 장수를 보고한다" ;;
  *) bad "정상 경로: 장수 보고가 없다. 출력=[$OUT]" ;;
esac
teardown

echo "---"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
