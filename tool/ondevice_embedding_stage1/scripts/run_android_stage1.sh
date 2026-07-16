#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PACKAGE="com.daejongkang.memoyo_embedding_stage1"
COMPONENT="$PACKAGE/.MainActivity"
ENGINE=""
MODELS="$ROOT/models"
OUTPUT="$ROOT/results/android"
SKIP_BUILD=0
BATTERY=0
TIMEOUT_SEC=1800

usage() {
  printf '%s\n' \
    'Usage: run_android_stage1.sh --engine e5|minilm|gemma [options]' \
    'Options: --models DIR --output DIR --skip-build --battery' \
    '         --timeout-sec SECONDS'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --engine)
      ENGINE="${2:-}"
      shift 2
      ;;
    --models)
      MODELS="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --battery)
      BATTERY=1
      shift
      ;;
    --timeout-sec)
      TIMEOUT_SEC="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$ENGINE" in
  e5)
    ENGINE_ID="multilingual_e5_small_onnx"
    MODEL_FILE="model.onnx"
    TOKENIZER_FILE="sentencepiece.bpe.model"
    MODEL_SHA="ca456c06b3a9505ddfd9131408916dd79290368331e7d76bb621f1cba6bc8665"
    TOKENIZER_SHA="cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865"
    GEMMA_TERMS=false
    ;;
  minilm)
    ENGINE_ID="paraphrase_multilingual_minilm_onnx"
    MODEL_FILE="model_qint8_arm64.onnx"
    TOKENIZER_FILE="sentencepiece.bpe.model"
    MODEL_SHA="783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672"
    TOKENIZER_SHA="cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865"
    GEMMA_TERMS=false
    ;;
  gemma)
    ENGINE_ID="embeddinggemma_seq512"
    MODEL_FILE="embeddinggemma-300M_seq512_mixed-precision.tflite"
    TOKENIZER_FILE="sentencepiece.model"
    MODEL_SHA="ad09e81557203cb0e177abf9bf8727dfe138a7d394aa0f70f0b2ed16432e121a"
    TOKENIZER_SHA="d6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7"
    GEMMA_TERMS=true
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case "$TIMEOUT_SEC" in
  ''|*[!0-9]*)
    printf 'timeout must be a positive integer\n' >&2
    exit 2
    ;;
esac
if [ "$TIMEOUT_SEC" -lt 1 ]; then
  printf 'timeout must be a positive integer\n' >&2
  exit 2
fi

for command_name in adb flutter awk grep; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 4
  fi
done

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify_file() {
  file="$1"
  expected="$2"
  if [ ! -f "$file" ]; then
    printf 'Missing prepared artifact: %s\n' "$file" >&2
    exit 5
  fi
  actual="$(sha256_file "$file")"
  if [ "$actual" != "$expected" ]; then
    printf 'SHA256 mismatch for %s\n' "$file" >&2
    exit 5
  fi
}

MODEL_DIRECTORY="$MODELS/$ENGINE_ID"
verify_file "$MODEL_DIRECTORY/$MODEL_FILE" "$MODEL_SHA"
verify_file "$MODEL_DIRECTORY/$TOKENIZER_FILE" "$TOKENIZER_SHA"
if [ "$GEMMA_TERMS" = true ] && \
  [ ! -f "$MODEL_DIRECTORY/terms-acceptance.json" ]; then
  printf 'Missing Gemma terms acceptance record; run prepare_models.sh first.\n' >&2
  exit 5
fi

adb get-state >/dev/null
ABI_LIST="$(adb shell getprop ro.product.cpu.abilist | tr -d '\r')"
case "$ABI_LIST" in
  *arm64-v8a*) ;;
  *)
    printf 'The selected runtimes require an arm64-v8a device; found %s\n' \
      "$ABI_LIST" >&2
    exit 6
    ;;
esac

if [ "$SKIP_BUILD" -eq 0 ]; then
  (
    cd "$ROOT"
    flutter pub get
    flutter build apk --debug
  )
  adb install -r "$ROOT/build/app/outputs/flutter-apk/app-debug.apk" >/dev/null
fi

if ! adb shell pm path "$PACKAGE" >/dev/null 2>&1; then
  printf 'Debug package is not installed; omit --skip-build.\n' >&2
  exit 7
fi

mkdir -p "$OUTPUT"
CONFIG_FILE="$(mktemp "${TMPDIR:-/tmp}/memoyo-stage1-config.XXXXXX")"
trap 'rm -f "$CONFIG_FILE"' EXIT
printf '{"engine":"%s","gemmaTermsAccepted":%s}\n' \
  "$ENGINE_ID" "$GEMMA_TERMS" > "$CONFIG_FILE"

adb shell run-as "$PACKAGE" mkdir -p "files/stage1/models/$ENGINE_ID"

stage_file() {
  source="$1"
  destination="$2"
  remote="/data/local/tmp/memoyo-stage1-$$-$(basename "$destination")"
  adb push "$source" "$remote" >/dev/null
  adb shell run-as "$PACKAGE" cp "$remote" "$destination"
  adb shell rm -f "$remote"
}

stage_file "$MODEL_DIRECTORY/$MODEL_FILE" \
  "files/stage1/models/$ENGINE_ID/$MODEL_FILE"
stage_file "$MODEL_DIRECTORY/$TOKENIZER_FILE" \
  "files/stage1/models/$ENGINE_ID/$TOKENIZER_FILE"
stage_file "$CONFIG_FILE" "files/stage1/config.json"

DEVICE_MODEL_SHA="$(adb shell run-as "$PACKAGE" sha256sum \
  "files/stage1/models/$ENGINE_ID/$MODEL_FILE" | awk '{print $1}' | tr -d '\r')"
DEVICE_TOKENIZER_SHA="$(adb shell run-as "$PACKAGE" sha256sum \
  "files/stage1/models/$ENGINE_ID/$TOKENIZER_FILE" | awk '{print $1}' | tr -d '\r')"
if [ "$DEVICE_MODEL_SHA" != "$MODEL_SHA" ] || \
  [ "$DEVICE_TOKENIZER_SHA" != "$TOKENIZER_SHA" ]; then
  printf 'Device-side artifact verification failed.\n' >&2
  exit 8
fi

adb shell run-as "$PACKAGE" rm -f \
  files/stage1/result.json files/stage1/crash.json \
  files/stage1/state.json files/stage1/events.jsonl
adb logcat -c
if [ "$BATTERY" -eq 1 ]; then
  adb shell dumpsys batterystats --reset > "$OUTPUT/batterystats-reset.txt"
fi

adb shell am force-stop "$PACKAGE"
adb shell am start -W -n "$COMPONENT" > "$OUTPUT/startup-cold.txt"
sleep 2
adb shell am start -W -n "$COMPONENT" > "$OUTPUT/startup-warm.txt"

: > "$OUTPUT/rss-samples.txt"
elapsed=0
complete=0
while [ "$elapsed" -lt "$TIMEOUT_SEC" ]; do
  if adb shell run-as "$PACKAGE" test -f files/stage1/result.json; then
    adb shell run-as "$PACKAGE" cat files/stage1/result.json \
      > "$OUTPUT/result.json"
    complete=1
    break
  fi
  if adb shell run-as "$PACKAGE" test -f files/stage1/crash.json; then
    adb shell run-as "$PACKAGE" cat files/stage1/crash.json \
      > "$OUTPUT/crash.json"
    break
  fi
  printf 'sample_utc=%s elapsed_sec=%s\n' \
    "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$elapsed" \
    >> "$OUTPUT/rss-samples.txt"
  adb shell dumpsys meminfo "$PACKAGE" 2>/dev/null \
    | grep -E 'TOTAL PSS|TOTAL RSS|TOTAL SWAP PSS|^[[:space:]]*TOTAL[[:space:]]' \
    >> "$OUTPUT/rss-samples.txt" || true
  sleep 5
  elapsed=$((elapsed + 5))
done

adb shell dumpsys meminfo "$PACKAGE" > "$OUTPUT/meminfo-final.txt" || true
adb shell run-as "$PACKAGE" cat files/stage1/state.json \
  > "$OUTPUT/state.json" 2>/dev/null || true
adb shell run-as "$PACKAGE" cat files/stage1/events.jsonl \
  > "$OUTPUT/events.jsonl" 2>/dev/null || true
adb logcat -d -v threadtime \
  | grep -E 'STAGE1_EVENT|com\.daejongkang\.memoyo_embedding_stage1|AndroidRuntime|FATAL EXCEPTION' \
  > "$OUTPUT/logcat.txt" || true
if [ "$BATTERY" -eq 1 ]; then
  adb shell dumpsys batterystats "$PACKAGE" > "$OUTPUT/batterystats-final.txt"
fi

if [ "$complete" -ne 1 ]; then
  printf 'Benchmark did not complete within %s seconds; see %s.\n' \
    "$TIMEOUT_SEC" "$OUTPUT" >&2
  exit 9
fi

printf 'Stage1 result: %s\n' "$OUTPUT/result.json"
