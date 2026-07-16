#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE=""
OUTPUT="$ROOT/models"
GEMMA_MODEL=""
GEMMA_TOKENIZER=""
GEMMA_TERMS_ACCEPTED=0

usage() {
  printf '%s\n' \
    'Usage: prepare_models.sh --engine e5|minilm|gemma [--output DIR]' \
    '       gemma also requires --gemma-model FILE --gemma-tokenizer FILE' \
    '       and --gemma-terms-accepted (an attestation, not terms acceptance).'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --engine)
      ENGINE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --gemma-model)
      GEMMA_MODEL="${2:-}"
      shift 2
      ;;
    --gemma-tokenizer)
      GEMMA_TOKENIZER="${2:-}"
      shift 2
      ;;
    --gemma-terms-accepted)
      GEMMA_TERMS_ACCEPTED=1
      shift
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

if [ -z "$ENGINE" ]; then
  usage >&2
  exit 2
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    printf 'A SHA256 utility is required (sha256sum or shasum).\n' >&2
    return 1
  fi
}

verify_file() {
  file="$1"
  expected="$2"
  if [ ! -f "$file" ]; then
    printf 'Missing artifact: %s\n' "$file" >&2
    return 1
  fi
  actual="$(sha256_file "$file")"
  if [ "$actual" != "$expected" ]; then
    printf 'SHA256 mismatch: %s\nexpected=%s\nactual=%s\n' \
      "$file" "$expected" "$actual" >&2
    return 1
  fi
}

download_file() {
  url="$1"
  destination="$2"
  expected="$3"
  if [ -f "$destination" ]; then
    verify_file "$destination" "$expected"
    printf 'Verified existing artifact: %s\n' "$destination"
    return
  fi
  temporary="${destination}.part"
  rm -f "$temporary"
  curl -fL --retry 3 --retry-delay 2 --output "$temporary" "$url"
  verify_file "$temporary" "$expected"
  mv "$temporary" "$destination"
  printf 'Downloaded and verified: %s\n' "$destination"
}

copy_file() {
  source="$1"
  destination="$2"
  expected="$3"
  verify_file "$source" "$expected"
  source_absolute="$(cd "$(dirname "$source")" && pwd -P)/$(basename "$source")"
  destination_absolute="$(cd "$(dirname "$destination")" && pwd -P)/$(basename "$destination")"
  if [ "$source_absolute" != "$destination_absolute" ]; then
    cp "$source" "$destination"
  fi
  verify_file "$destination" "$expected"
}

case "$ENGINE" in
  e5)
    ENGINE_ID="multilingual_e5_small_onnx"
    REVISION="614241f622f53c4eeff9890bdc4f31cfecc418b3"
    MODEL_FILE="model.onnx"
    TOKENIZER_FILE="sentencepiece.bpe.model"
    MODEL_SHA="ca456c06b3a9505ddfd9131408916dd79290368331e7d76bb621f1cba6bc8665"
    TOKENIZER_SHA="cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865"
    DIRECTORY="$OUTPUT/$ENGINE_ID"
    mkdir -p "$DIRECTORY"
    download_file \
      "https://huggingface.co/intfloat/multilingual-e5-small/resolve/$REVISION/onnx/model.onnx" \
      "$DIRECTORY/$MODEL_FILE" "$MODEL_SHA"
    download_file \
      "https://huggingface.co/intfloat/multilingual-e5-small/resolve/$REVISION/onnx/sentencepiece.bpe.model" \
      "$DIRECTORY/$TOKENIZER_FILE" "$TOKENIZER_SHA"
    ;;
  minilm)
    ENGINE_ID="paraphrase_multilingual_minilm_onnx"
    REVISION="e8f8c211226b894fcb81acc59f3b34ba3efd5f42"
    MODEL_FILE="model_qint8_arm64.onnx"
    TOKENIZER_FILE="sentencepiece.bpe.model"
    MODEL_SHA="783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672"
    TOKENIZER_SHA="cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865"
    DIRECTORY="$OUTPUT/$ENGINE_ID"
    mkdir -p "$DIRECTORY"
    download_file \
      "https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/resolve/$REVISION/onnx/model_qint8_arm64.onnx" \
      "$DIRECTORY/$MODEL_FILE" "$MODEL_SHA"
    download_file \
      "https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/resolve/$REVISION/sentencepiece.bpe.model" \
      "$DIRECTORY/$TOKENIZER_FILE" "$TOKENIZER_SHA"
    ;;
  gemma)
    if [ "$GEMMA_TERMS_ACCEPTED" -ne 1 ] || \
      [ -z "$GEMMA_MODEL" ] || [ -z "$GEMMA_TOKENIZER" ]; then
      printf '%s\n' \
        'Gemma files require prior external terms acceptance, both local file paths,' \
        'and --gemma-terms-accepted. This script cannot accept terms or fetch them.' >&2
      exit 3
    fi
    ENGINE_ID="embeddinggemma_seq512"
    MODEL_FILE="embeddinggemma-300M_seq512_mixed-precision.tflite"
    TOKENIZER_FILE="sentencepiece.model"
    MODEL_SHA="ad09e81557203cb0e177abf9bf8727dfe138a7d394aa0f70f0b2ed16432e121a"
    TOKENIZER_SHA="d6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7"
    DIRECTORY="$OUTPUT/$ENGINE_ID"
    mkdir -p "$DIRECTORY"
    copy_file "$GEMMA_MODEL" "$DIRECTORY/$MODEL_FILE" "$MODEL_SHA"
    copy_file "$GEMMA_TOKENIZER" "$DIRECTORY/$TOKENIZER_FILE" "$TOKENIZER_SHA"
    timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf '{\n  "termsUrl": "https://ai.google.dev/gemma/terms",\n  "acceptanceMethod": "operator-attested external acceptance before local verification",\n  "recordedAtUtc": "%s"\n}\n' \
      "$timestamp" > "$DIRECTORY/terms-acceptance.json"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ "$ENGINE" = e5 ] || [ "$ENGINE" = minilm ]; then
  (
    cd "$ROOT"
    dart run tool/verify_xlm_roberta_tokenizer.dart \
      "$DIRECTORY/$TOKENIZER_FILE" "$ENGINE"
  )
fi

printf 'Prepared %s under %s\n' "$ENGINE_ID" "$DIRECTORY"
