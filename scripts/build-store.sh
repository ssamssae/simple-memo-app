#!/usr/bin/env bash
# 스토어 산출물(iOS ipa / Android AAB) 정본 진입점.
#
# 왜 있는가: MEMOYO_API 를 주입하는 자리가 repo·릴리스 경로 통틀어 0건이라 스토어 산출물이
# baseUrl='' 로 나갔다. 이 값을 읽는 3개 클라이언트(memoyo_embedding_client ·
# memoyo_summary_client · premium_entitlement_client)는 String.fromEnvironment 에
# defaultValue 를 안 줘서 미주입 시 빈 문자열이 되고, 예외 없이 객체가 생성된다 —
# 앱은 정상 기동하고 결제화면이 파는 「AI 요약」·「말로 검색」만 조용히 죽는다.
# 빌드·업로드·심사가 전부 그린으로 통과해 어디서도 안 잡혔다. (T-260803-038 / T-260804-019)
#
# 사내 4번째 재발이다 — 집사리모컨 1.0.0+2/+3, 첫이름 Apple 리젝 2회(2.1(b)·2.1(a)),
# 그리고 메모요. 교훈 SoT = ~/.claude/skills/submit-app/lessons/
#   ios-dart-define-runtime-config-required.md
#
# 그래서 이 스크립트는 두 가지를 강제한다:
#   1) MEMOYO_API 없이는 산출 자체를 거부한다 (누락 재발 차단).
#   2) 산출 후 아티팩트에 엔드포인트 문자열이 실제로 박혔는지 검증한다 (조용한 누락 차단).
#
# 사용:
#   MEMOYO_API=https://<worker-endpoint> scripts/build-store.sh <ios|android>
#
# ⚠️ 제거 금지 (DO NOT REMOVE) — 이 가드가 유료기능 먹통 출고의 재발 방지 코드다
#   (헌법 원칙 10 「사고는 코드로」, T-260804-019).
#   폐기 필요시: 마커 유지한 채 로직만 수정하거나 _disabled/ 보관 + 이슈.
#   회귀테스트: scripts/tests/test_build_store_gate.sh

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

target="${1:-}"
case "$target" in
  ios | android) ;;
  *)
    printf 'usage: scripts/build-store.sh <ios|android>\n' >&2
    exit 2
    ;;
esac

# ── 이 앱이 아직 그 값을 소비하는가 ──────────────────────────────────────────
#
# T-260830-013: 백엔드가 끝내 만들어지지 않아(구독은 2026-08-03 판매 종료,
# T-260803-038) MEMOYO_API 를 읽던 3개 클라이언트를 lib/ 에서 철거했다. 소비처가
# 0건이면 이 게이트는 ★지킬 대상이 없는데도 빌드를 막는 장애물이 된다 — 실제로
# 스토어 업로드가 그 때문에 멈췄다.
#
# 그래서 게이트를 없애지 않고 ★조건부로 만든다. 판정 기준은 사람의 기억이 아니라
# lib/ 의 선언 유무다. 백엔드가 생겨 클라이언트가 돌아오는 날 선언도 같이 돌아오고,
# 그 순간 아래 2겹(미주입 거부 + 산출물 검증)이 ★자동으로 되살아난다.
#
# ⚠️ 이 분기를 「항상 skip」으로 바꾸지 마라. 그러면 클라이언트가 돌아온 날
#    T-260803-038 과 똑같은 먹통 출고가 조용히 다시 나간다.
if grep -rqE "String\.fromEnvironment\([[:space:]]*'MEMOYO_API'" lib 2>/dev/null; then
  endpoint_consumed=1
else
  endpoint_consumed=0
fi

if [[ "$endpoint_consumed" -eq 0 ]]; then
  printf '▶ store build: %s (MEMOYO_API 소비처 0건 — 주입·검증 생략, T-260830-013)\n' \
    "$target" >&2
  if [[ -n "${MEMOYO_API:-}" ]]; then
    printf '  ⚠️ MEMOYO_API 가 설정돼 있지만 lib/ 에 읽는 곳이 없어 무시한다.\n' >&2
  fi
  flutter_bin="${FLUTTER_BIN:-$(command -v flutter || true)}"
  if [[ -z "$flutter_bin" ]]; then
    printf '✗ flutter 를 찾지 못했다. FLUTTER_BIN 으로 지정하라.\n' >&2
    exit 1
  fi
  if [[ "$target" == "ios" ]]; then
    "$flutter_bin" build ipa --release
  else
    "$flutter_bin" build appbundle --release
  fi
  printf '✓ store build 완료 (%s)\n' "$target" >&2
  exit 0
fi

# 공백만 있는 값도 거부한다 — Dart 쪽이 .trim() 을 걸어 "   " 는 결국 '' 와 같고,
# 비어 있지 않다는 이유로 통과시키면 정확히 같은 먹통 빌드가 나간다.
api="${MEMOYO_API:-}"
api="$(printf '%s' "$api" | tr -d '[:space:]')"
if [[ -z "$api" ]]; then
  cat >&2 <<'EOF'
✗ MEMOYO_API 가 비어 있다. 스토어 산출을 중단한다.

이 값이 없으면 앱은 baseUrl='' 로 빌드된다. 예외가 안 나므로 앱은 정상 기동하고
결제화면이 파는 「AI 요약」·「말로 검색」만 조용히 죽는다 — 빌드·업로드·심사가 전부
그린으로 통과하며, 앱을 켜서 그 기능을 눌러봐야만 드러난다.

  MEMOYO_API=https://<worker-endpoint> scripts/build-store.sh <ios|android>
EOF
  exit 1
fi

# 엔드포인트 host 만 뽑아 아티팩트 검증에 쓴다 (스킴·경로는 문자열로 안 남을 수 있다).
api_host="$(printf '%s' "$api" | sed -E 's#^[a-z]+://##; s#/.*$##')"
if [[ -z "$api_host" ]]; then
  printf '✗ MEMOYO_API 에서 host 를 추출하지 못했다: %s\n' "$api" >&2
  exit 1
fi

flutter_bin="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "$flutter_bin" ]]; then
  printf '✗ flutter 를 찾지 못했다. FLUTTER_BIN 으로 지정하라.\n' >&2
  exit 1
fi

printf '▶ store build: %s (api host=%s)\n' "$target" "$api_host" >&2

if [[ "$target" == "ios" ]]; then
  "$flutter_bin" build ipa --release --dart-define=MEMOYO_API="$api"
  # App.framework 바이너리에 상수 문자열이 박힌다.
  artifact="$(find build/ios -name 'App' -path '*App.framework*' -print -quit)"
else
  "$flutter_bin" build appbundle --release --dart-define=MEMOYO_API="$api"
  artifact="$(find build/app/outputs/bundle -name '*.aab' -print -quit)"
fi

if [[ -z "$artifact" || ! -f "$artifact" ]]; then
  printf '✗ 산출물을 찾지 못해 엔드포인트 검증을 못 했다. 실패로 처리한다.\n' >&2
  exit 1
fi

# 조용한 누락 차단: 아티팩트에 host 문자열이 실제로 존재해야 한다.
# ⚠️ 함정 2개 (첫이름에서 둘 다 실측으로 밟았다):
#   1) AAB 는 zip 이라 겉면 검사로는 절대 안 잡힌다 — 풀어서 libapp.so 를 봐야 한다.
#   2) `strings ... | grep -q` 는 쓰지 마라. grep -q 가 일치 즉시 종료하며 strings 에
#      SIGPIPE 를 주고, set -o pipefail 이 그걸 파이프라인 실패로 잡아 ★일치했는데
#      실패로 뒤집힌다. 그래서 파이프 없이 grep -a 로 파일을 직접 본다.
found=0
if [[ "$artifact" == *.aab ]]; then
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  # unzip(1) 이 없는 노드가 있어 python3 zipfile 로 푼다 (라이덴 zip 부재 실측).
  python3 -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
    "$artifact" "$workdir"
  while IFS= read -r lib; do
    if grep -aqF "$api_host" "$lib"; then
      found=1
      break
    fi
  done < <(find "$workdir" -name 'libapp.so')
else
  if grep -aqF "$api_host" "$artifact"; then
    found=1
  fi
fi

if [[ "$found" -ne 1 ]]; then
  printf '✗ 산출물에 엔드포인트(%s)가 없다 — dart-define 이 실제로 반영되지 않았다.\n' "$api_host" >&2
  printf '  artifact: %s\n' "$artifact" >&2
  exit 1
fi

printf '✓ 산출물에 엔드포인트 확인됨: %s\n' "$artifact" >&2
printf '✓ store build 완료 (%s)\n' "$target" >&2
