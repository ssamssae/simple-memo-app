# Memoyo on-device embedding stage1 spike

T-260713-55 experimental branch only. This app is deliberately isolated from
Memoyo production code and flags, and this branch is **not a main-merge
candidate**. It prepares the later macmini physical-device comparison; the
numbers produced on a simulator or desktop are not device results.

## Compared engines

| Engine ID | Runtime/model | Context | Vector |
| --- | --- | ---: | ---: |
| `embeddinggemma_seq512` | LiteRT EmbeddingGemma mixed precision | 512 | 768D |
| `multilingual_e5_small_onnx` | ONNX generic FP32 E5-small | 512 | 384D |
| `paraphrase_multilingual_minilm_onnx` | ONNX arm64 qint8 MiniLM | 128 | 384D |

Every model and tokenizer is pinned by repository revision and SHA256 in
`models/model-manifest.json`. Engine IDs and dimensions never share an index.
Changing engines therefore means a full reindex, matching the design document.
The two ONNX candidates share the same pinned XLM-R SentencePiece binary. Model
preparation also runs seven fixed token-ID parity cases against outputs captured
from both upstream tokenizer JSON files, including Korean and normalization
edge cases; a mismatch fails before device staging.

## Prerequisites

- Flutter 3.44.0 / Dart 3.12 or newer.
- Android: physical arm64 device, API 24+, `adb`, Java 17, and a configured
  Android SDK.
- iOS: macOS/Xcode, iOS 16+, and an arm64 device. iOS build and measurement are
  intentionally left to the macmini device leg.
- Enough local disk for the selected model plus build output. E5 FP32 is about
  470 MB; do not prepare all candidates when space is constrained.

The desktop3060ti prep host had Flutter 3.44.0 and Dart 3.12.0, but no Java,
Android SDK, or attached `adb` device. No APK was built, and no toolchain was
installed or upgraded to work around that boundary. The MiniLM preparation
path itself was executed end to end: both public artifacts passed SHA256 and
all tokenizer parity checks. Native ONNX/LiteRT execution remains the device
leg; a headless Flutter unit test does not register these platform plugins.

## 1. Prepare one model

Public ONNX artifacts are downloaded from immutable Hugging Face revisions and
checked before use:

```bash
cd tool/ondevice_embedding_stage1
./scripts/prepare_models.sh --engine minilm --output models
# or
./scripts/prepare_models.sh --engine e5 --output models
```

EmbeddingGemma is gated. First review and accept the Gemma terms using the
provider's normal signed-in flow, then download these exact files yourself:

- `embeddinggemma-300M_seq512_mixed-precision.tflite`
- `sentencepiece.model`

Pass the local files to the verifier. This command does not log or accept an HF
token and does not accept terms on your behalf:

```bash
./scripts/prepare_models.sh \
  --engine gemma \
  --output models \
  --gemma-model /path/to/embeddinggemma-300M_seq512_mixed-precision.tflite \
  --gemma-tokenizer /path/to/sentencepiece.model \
  --gemma-terms-accepted
```

See `LICENSES.md` before using or redistributing any artifact.

## 2. Build, stage, and run on Android

The runner builds a debug APK, installs it, copies only the chosen model into
the debug app's private files directory, cold-starts the app, samples memory,
and captures a scoped crash log and result JSON:

```bash
./scripts/run_android_stage1.sh \
  --engine minilm \
  --models models \
  --output results/pixel-minilm
```

Use `--skip-build` only when the same debug package is already installed. Use
`--timeout-sec 2400` for a slow E5 device. The output directory contains:

- `startup-cold.txt` and `startup-warm.txt`: Android activity launch timing.
- `rss-samples.txt` and `meminfo-final.txt`: periodic and final RSS/PSS source
  output from `dumpsys meminfo` while the model remains loaded.
- `result.json`: model load, first (cold) inference, five warm inference
  samples/median, and sequential 100-memo reindex time.
- `logcat.txt`: only stage1/Android-runtime crash lines collected after clearing
  logcat immediately before this run.
- `crash.json`, when Dart caught a failure.

The app uses 100 deterministic, synthetic Korean memos. It never reads Memoyo
user data. The first query and all documents use the model-specific retrieval
prefixes; ONNX token embeddings are attention-mask mean-pooled and L2
normalized. A wrong SHA, unexpected input, unexpected dimension, NaN, or
missing Gemma terms attestation fails closed.

## iOS handoff

On the macmini, run `flutter pub get`, open `ios/Runner.xcworkspace`, and build
the experimental target for an iOS 16+ device. After installing once, use
Xcode's Devices and Simulators container workflow to place the selected files
under:

```text
Library/Application Support/stage1/config.json
Library/Application Support/stage1/models/<engine-id>/<artifact>
```

The config is a two-field JSON object:

```json
{"engine":"paraphrase_multilingual_minilm_onnx","gemmaTermsAccepted":false}
```

For Gemma, set the boolean to true only after the external acceptance step.
The app verifies the committed hashes itself and auto-runs on launch. Retrieve
`result.json`, `state.json`, `events.jsonl`, and `crash.json` from the same
`stage1` directory. The Android runner is the reference for result naming and
cold/warm semantics.

## Battery measurement procedure (physical-device leg)

1. Use the same physical device, OS build, release/debug mode, brightness,
   network state, and ambient conditions for every candidate. Charge above
   80%, unplug, close unrelated apps, and wait until thermal state returns to
   nominal.
2. Record device model/OS, starting battery percentage, charge counter, and
   thermal state. On Android, run
   `adb shell dumpsys batterystats --reset`; on iOS, start an Instruments Energy
   Log recording.
3. Run each engine ten times with a fresh force-stop between runs. Rotate engine
   order between rounds rather than measuring one engine only while the device
   is coolest. Keep the 100-memo corpus unchanged.
4. Save ending percentage/charge counter, `dumpsys batterystats` scoped to
   `com.daejongkang.memoyo_embedding_stage1`, thermal state, and elapsed time.
   On iOS, export the Instruments trace. Mark any thermally throttled or crashed
   run; do not silently discard it.
5. Report raw runs plus median and spread. Vendor/model-card benchmarks are
   context only and must never be labeled as Memoyo device measurements.

## Prep-host verification

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash -n scripts/*.sh
shellcheck scripts/*.sh
dart run tool/verify_xlm_roberta_tokenizer.dart \
  /path/to/sentencepiece.bpe.model e5
```

APK status on desktop3060ti: **not built** because the pre-existing Java and
Android SDK prerequisites were absent. Reproduction on an Android-ready host is
the `run_android_stage1.sh` command above; no forced setup is required here.
