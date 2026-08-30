#!/usr/bin/env bash
# T-260804-019 — scripts/build-store.sh fail-closed 게이트 회귀 픽스처.
#
# 왜 있는가: MEMOYO_API 는 3개 클라이언트(embedding·summary·premium_entitlement)가
# String.fromEnvironment 로 빌드시점에 받는데 defaultValue 가 없어 미주입 시 빈 문자열이
# 된다. 예외가 안 나므로 앱은 정상 기동하고 유료 기능만 조용히 죽는다 — 빌드·업로드·심사가
# 전부 그린으로 통과한다. 이 클래스는 사내 4번째 재발이다(집사리모컨 1·첫이름 2·메모요 1,
# ~/.claude/skills/submit-app/lessons/ios-dart-define-runtime-config-required.md).
#
# 실 flutter·실 빌드는 절대 타지 않는다. PATH 앞에 flutter 스텁을 꽂아
# ①호출 여부 ②전달된 인자 ③산출물 내용을 전부 픽스처가 만든다.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/build-store.sh"

pass=0; fail=0
ok()  { echo "ok:   $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

API="https://memoyo-worker.example.workers.dev"
HOST="memoyo-worker.example.workers.dev"

# 각 케이스마다 격리된 샌드박스 + flutter 스텁을 새로 만든다.
# $1 = libapp.so 에 심을 문자열 (빈 값이면 endpoint 미포함 = 조용한 누락 재현)
# $2 = 소비처 모드 (기본 declared) — T-260830-013 으로 게이트가 조건부가 됐다.
#      declared   = lib/ 가 MEMOYO_API 를 읽는다 → 2겹 게이트가 살아 있어야 한다
#      undeclared = 읽는 곳이 0건 → 주입 요구·산출물 검증 없이 그냥 빌드한다
#      ★undeclared 를 「게이트가 없어졌다」로 읽지 마라. 선언이 돌아오면 자동 복귀하며,
#        그 복귀 자체를 케이스 9/10 이 대조군으로 잰다.
setup() {
  SANDBOX="$(mktemp -d)"
  CALLS="$SANDBOX/flutter-calls.txt"
  : > "$CALLS"
  mkdir -p "$SANDBOX/bin"
  cat > "$SANDBOX/bin/flutter" <<STUB
#!/usr/bin/env bash
# flutter 스텁 — 호출 인자를 기록하고 가짜 AAB 를 만든다. 실제 빌드 0.
printf '%s\n' "\$*" >> "$CALLS"
if [ "\${2:-}" = "ipa" ]; then
  # iOS 는 App.framework 안 단일 바이너리에 상수가 박힌다 (zip 아님).
  fw="$SANDBOX/repo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework"
  mkdir -p "\$fw"
  printf 'MachO-ish payload %s tail\n' "$1" > "\$fw/App"
  exit 0
fi
out="$SANDBOX/repo/build/app/outputs/bundle/release"
mkdir -p "\$out" "$SANDBOX/stage/lib/arm64-v8a"
printf 'ELF-ish payload %s tail\n' "$1" > "$SANDBOX/stage/lib/arm64-v8a/libapp.so"
# AAB=zip 을 python3 로 만든다 — zip(1) 은 5노드 전부에 있지 않다(라이덴 부재 실측).
python3 -c "
import shutil,sys
shutil.make_archive(sys.argv[1][:-4], 'zip', sys.argv[2])
shutil.move(sys.argv[1][:-4]+'.zip', sys.argv[1])
" "\$out/app-release.aab" "$SANDBOX/stage"
STUB
  chmod +x "$SANDBOX/bin/flutter"
  # 산출물 경로 계산이 repo_root 기준이라 최소 git repo 를 흉내낸다.
  mkdir -p "$SANDBOX/repo/lib"
  git -C "$SANDBOX/repo" init -q 2>/dev/null
  cp "$SCRIPT" "$SANDBOX/repo/build-store.sh" 2>/dev/null
  if [ "${2:-declared}" = "declared" ]; then
    # 소비처 1건을 흉내낸다. 이 한 줄이 있어야 2겹 게이트가 켜진다.
    printf "const x = String.fromEnvironment('MEMOYO_API');\n" \
      > "$SANDBOX/repo/lib/consumer.dart"
  fi
}
teardown() { rm -rf "$SANDBOX"; }

# 스크립트를 샌드박스 repo 안에서 실행한다. stdout/stderr 는 $OUT, 종료코드는 $RC.
run_gate() {
  OUT="$(cd "$SANDBOX/repo" && PATH="$SANDBOX/bin:$PATH" bash ./build-store.sh "$@" 2>&1)"
  RC=$?
}

echo "== 1. MEMOYO_API 미설정 → flutter 를 부르기 전에 거부한다 =="
setup "$HOST"
unset MEMOYO_API
run_gate android
[ "$RC" -eq 1 ] && ok "exit 1" || bad "exit $RC (want 1)"
[ "$(awk 'END{print NR+0}' "$CALLS")" -eq 0 ] \
  && ok "flutter 호출 0회 (산출 자체를 막았다)" \
  || bad "flutter 가 호출됐다 — 사전 게이트가 없다"
case "$OUT" in *MEMOYO_API*) ok "메시지에 원인 변수명 포함" ;; *) bad "원인이 안 적힌 실패" ;; esac
teardown

echo "== 2. MEMOYO_API 가 공백뿐이어도 거부한다 =="
setup "$HOST"
MEMOYO_API="   " run_gate android
[ "$RC" -eq 1 ] && ok "exit 1" || bad "exit $RC (want 1)"
[ "$(awk 'END{print NR+0}' "$CALLS")" -eq 0 ] && ok "flutter 호출 0회" || bad "공백값이 통과했다"
teardown

echo "== 3. 잘못된 타깃 → usage 로 거부 =="
setup "$HOST"
MEMOYO_API="$API" run_gate web
[ "$RC" -eq 2 ] && ok "exit 2" || bad "exit $RC (want 2)"
teardown

echo "== 4. 산출물에 endpoint 가 없으면 실패 (조용한 누락 차단) =="
setup ""   # libapp.so 에 host 문자열을 심지 않는다
MEMOYO_API="$API" run_gate android
[ "$RC" -eq 1 ] && ok "exit 1" || bad "exit $RC (want 1) — 무력화 빌드가 통과했다"
case "$OUT" in *"$HOST"*) ok "실패 메시지에 찾던 host 명시" ;; *) bad "무엇을 못 찾았는지 안 알려준다" ;; esac
teardown

echo "== 5. 정상 경로 → dart-define 전달 + 산출물 검증 통과 =="
setup "$HOST"
MEMOYO_API="$API" run_gate android
[ "$RC" -eq 0 ] && ok "exit 0" || bad "exit $RC (want 0) / 출력: $OUT"
grep -q -- "--dart-define=MEMOYO_API=$API" "$CALLS" \
  && ok "flutter 에 MEMOYO_API 를 실제로 넘겼다" \
  || bad "dart-define 이 안 붙었다 (넘긴 인자: $(cat "$CALLS"))"
grep -q -- "appbundle" "$CALLS" && ok "android=appbundle 산출" || bad "산출 타깃이 틀렸다"
teardown

echo "== 6. iOS 축도 같은 게이트를 받는다 (첫이름 리젝 2회가 iOS 였다) =="
setup "$HOST"
MEMOYO_API="$API" run_gate ios
[ "$RC" -eq 0 ] && ok "ios exit 0" || bad "ios exit $RC (want 0) / 출력: $OUT"
grep -q -- "build ipa" "$CALLS" && ok "ipa 산출" || bad "ios 산출 타깃이 틀렸다"
grep -q -- "--dart-define=MEMOYO_API=$API" "$CALLS" && ok "ios 에도 define 전달" || bad "ios 경로에 define 누락"
teardown

echo "== 7. iOS 산출물에 endpoint 가 없으면 실패 =="
setup ""
MEMOYO_API="$API" run_gate ios
[ "$RC" -eq 1 ] && ok "ios exit 1" || bad "ios exit $RC (want 1) — 무력화 빌드가 통과했다"
teardown

echo "== 8. AAB 검증에 strings|grep -q 파이프를 쓰지 않는다 (SIGPIPE 오탐 차단) =="
# 정본 교훈: `strings ... | grep -q` 는 일치 즉시 grep 이 끝나며 SIGPIPE 를 내고
# set -o pipefail 이 그걸 파이프라인 실패로 잡아 ★일치했는데 실패로 뒤집힌다.
# 케이스5(정상경로)가 초록인 것이 동작 증거이고, 여기서는 그 금지 패턴의 부재를 못박는다.
# ⚠️ 파일 부재를 「금지 패턴 없음」으로 읽으면 스크립트가 아예 없을 때 초록이 뜬다(가짜 초록).
# 존재 확인을 먼저 건다 — 이 축이 없어 RED 단계에서 실제로 오초록 1건이 났다.
# ⚠️ 주석을 걷어내고 본다 — 이 함정을 ★설명하는 주석 자체가 금지 문구를 담고 있어,
# 원문 그대로 매칭하면 올바른 구현이 자기 경고문 때문에 빨간불이 난다(실측).
if [ ! -f "$SCRIPT" ]; then
  bad "scripts/build-store.sh 자체가 없다"
elif sed 's/[[:space:]]*#.*$//' "$SCRIPT" | grep -qE 'strings[^|]*\|[[:space:]]*grep[^|]*-[a-zA-Z]*q'; then
  bad "금지 패턴(strings | grep -q) 가 남아 있다"
else
  ok "금지 패턴 없음"
fi

echo "== 9. 소비처 0건 → 주입 없이도 빌드한다 (T-260830-013) =="
# lib/ 가 MEMOYO_API 를 안 읽으면 요구할 대상이 없다. 여기서 계속 exit 1 이면
# 지킬 것도 없는데 스토어 출고가 막힌다 — 실제로 그래서 업로드가 멈췄다.
setup "" undeclared
unset MEMOYO_API
run_gate android
[ "$RC" -eq 0 ] && ok "exit 0" || bad "exit $RC (want 0) — 소비처가 없는데 막았다 / 출력: $OUT"
grep -q -- "appbundle" "$CALLS" && ok "빌드는 실제로 돌았다" || bad "flutter 를 안 불렀다"
grep -q -- "--dart-define=MEMOYO_API" "$CALLS" \
  && bad "읽는 곳이 없는데 define 을 붙였다" \
  || ok "define 을 안 붙였다"
teardown

echo "== 10. ★소비처가 돌아오면 게이트도 돌아온다 (조건부의 대조군) =="
# 9 만 있으면 「게이트를 껐다」와 구분이 안 된다. 같은 조건에서 선언 한 줄만 되살려
# 다시 fail-closed 가 되는지 잰다. 이 본이 없으면 조건 분기가 항상-skip 으로
# 퇴화해도 아무도 못 잡는다.
setup "" declared
unset MEMOYO_API
run_gate android
[ "$RC" -eq 1 ] && ok "선언 복귀 시 exit 1 (fail-closed 부활)" || bad "exit $RC (want 1) — 게이트가 안 돌아왔다"
[ "$(awk 'END{print NR+0}' "$CALLS")" -eq 0 ] && ok "flutter 호출 0회" || bad "산출을 막지 못했다"
teardown

echo
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
