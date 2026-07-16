# T-260716-83 stage1 physical-device measurements

Measured on 2026-07-16 KST from the non-merge experiment branch
`spike/T-260713-55-stage1`. Production code and flags were not touched.

## Coverage and conditions

| Leg | Device / mode | Status |
| --- | --- | --- |
| Android | Galaxy S24 (SM-S921N), Android 16, debug, arm64 | E5 and MiniLM complete; no crash |
| iOS | iPhone 17, release, arm64, wireless | E5 10/10 and MiniLM 10/10 complete; no crash |
| Gemma | both | Skipped fail-closed: no gated model files or external terms-acceptance attestation were present |

Flutter 3.44.6 / Dart 3.12.2 was selected from the existing FVM cache. The
global Flutter installation was not changed.

Android was USB-powered at 100% throughout the leg. Therefore the captured
`batterystats` files are raw diagnostics only, not valid unplugged energy
measurements. The charge counter stayed at 3,880,000 and thermal status stayed
0. No Android battery claim is made.

iOS was reached wirelessly through CoreDevice, with no cable charging. The
first nine completed runs used iOS 26.5.1 (23F81). The phone had updated to iOS
26.5.2 (23F84) before the unlocked continuation, so the remaining eleven runs
cannot form one controlled ten-round battery comparison with the earlier runs.
Performance values are retained as raw descriptive measurements and are split
by OS build below.

## Adopted Android run

The first Android runs were rejected rather than averaged: the S24 moved the
app behind the launcher and Samsung freecess paused it; one E5 restart also
overlapped the still-running coroutine. Those raw folders are retained locally
as invalid diagnostics. The adopted runs used a fresh force-stop with the app
kept foreground and the display awake without changing persistent settings.

| Engine | Cold load | First inference | Warm 5 median | Reindex 100 | Peak PSS | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| MiniLM qint8 | 906.638 ms | 317.219 ms | 41.881 ms | 3,975.359 ms | 724,328 KB | 823,549 KB |
| E5-small FP32 | 1,212.327 ms | 654.404 ms | 386.249 ms | 40,263.359 ms | 1,124,398 KB | 1,223,503 KB |

Both state files ended in `complete`, dimensions were 384, and neither adopted
folder contains `crash.json`. Model and tokenizer hashes in `result.json`
match the committed manifest.

## iOS repeated release runs

The engine order was alternated by round and every launch used
`--terminate-existing`. Round 05 E5 was completed first after unlock, followed
by MiniLM/E5 in round 06, E5/MiniLM in round 07, and the same alternating order
through round 10. All 20 result files ended in `complete`, reported 384
dimensions, and have no `crash.json`.

The combined table is descriptive only because it mixes two OS builds.

| Engine | n | Cold load median (range) | First median (range) | Warm median-of-medians (range) | Reindex 100 median (range) |
| --- | ---: | ---: | ---: | ---: | ---: |
| MiniLM qint8 | 10 | 334.440 ms (290.299–406.652) | 17.598 ms (16.184–23.070) | 16.438 ms (14.840–18.247) | 1,702.957 ms (1,443.673–1,898.192) |
| E5-small FP32 | 10 | 474.447 ms (416.736–559.484) | 239.092 ms (198.668–261.381) | 201.584 ms (186.276–238.276) | 21,687.860 ms (20,768.487–24,184.823) |

The build-separated distributions are the controlled views of the raw values:

| Engine / OS build | n | Cold median (range) | First median (range) | Warm median (range) | Reindex 100 median (range) |
| --- | ---: | ---: | ---: | ---: | ---: |
| MiniLM / 26.5.1 (23F81) | 5 | 387.673 ms (330.530–406.652) | 16.692 ms (16.184–17.693) | 17.100 ms (14.840–18.247) | 1,693.843 ms (1,443.673–1,817.735) |
| MiniLM / 26.5.2 (23F84) | 5 | 322.694 ms (290.299–367.330) | 19.742 ms (16.793–23.070) | 16.346 ms (15.107–16.693) | 1,708.271 ms (1,690.378–1,898.192) |
| E5 / 26.5.1 (23F81) | 4 | 472.949 ms (428.272–539.730) | 224.655 ms (198.668–261.381) | 210.818 ms (186.276–238.276) | 22,141.405 ms (20,768.487–24,184.823) |
| E5 / 26.5.2 (23F84) | 6 | 476.258 ms (416.736–559.484) | 239.092 ms (201.892–249.371) | 201.584 ms (196.981–214.328) | 21,687.860 ms (21,316.464–22,874.941) |

## iOS Power Profiler continuation

Power Profiler was attached immediately after each resumed CoreDevice launch.
This both recorded the run and held the usage assertion required for the app to
remain active over the wireless connection. Eleven valid traces cover round 05
E5 and both candidates in rounds 06–10.

- Round 05 E5 through both round 08 runs stayed `Nominal` at 20% brightness.
- Round 09 E5 transitioned from `Nominal` to `Fair` while brightness moved from
  20% to 21%.
- Round 09 MiniLM and both round 10 runs stayed `Fair` at 21% brightness.
- Every short trace reported `0.0%/hr` in `SystemPowerLevel`. That resolution is
  not sufficient to infer battery drain for these runs.

This continuation does not supply a valid candidate-to-candidate battery
result: the OS build and brightness changed, no comparable start/end battery
percentage or charge counter was available, and the short-interval power value
was zero-resolution. The trace thermal and display observations are reported,
but no iOS energy-consumption claim is made.

Each valid run includes the unmodified `xctrace export` output for the thermal,
charging-interval, and system-power tables as
`power-profiler-selected-tables.xml`. Full `.trace` bundles remain local and
ignored because their metadata contains the device owner/name, device
identifier, and host identifier; they are not copied into Git, the pull
request, or reports.

## Invalid iOS attempts retained

- `round-05-e5-invalid-screen-sleep`: the phone locked during the original E5
  round 05 and the run stopped at `reindexing-100`.
- `round-05-e5-invalid-locked-launch`: CoreDevice returned `RequestDenied` /
  `Locked`; no measurement was adopted.
- `round-05-e5-invalid-coredevice-suspended`: after unlock, an unprofiled
  CoreDevice launch stayed at `verifying-artifacts`. Attaching Instruments
  resumed it after the elapsed-time window was already contaminated, so it was
  rejected and rerun from a clean launch.

These attempts are surfaced rather than silently discarded and are excluded
from every aggregate.

## Build issue found on the iOS handoff

The generated Podfile used dynamic `use_frameworks!`, while both installed
native-runtime packages require static linkage. CocoaPods reproduced this as:

```text
[!] The 'Pods-Runner' target has transitive dependencies that include
statically linked binaries: (onnxruntime-objc and onnxruntime-c)
```

A regression test was observed RED, then the Podfile was changed to
`use_frameworks! :linkage => :static`. The test and `pod install` then passed,
followed by a signed physical-device release build and wireless install.

## Raw outputs

- Android adopted folders: `results/s24-android16/minilm-run-02/` and
  `results/s24-android16/e5-run-02/`.
- iOS completed folders: `results/iphone-ios26/rounds/round-01-*` through
  `round-10-*`.
- The three rejected iOS attempts are retained in their explicitly named
  `invalid-*` folders.
- Each adopted Android folder contains startup, RSS samples, final meminfo,
  result/state/events, scoped logcat, and batterystats reset/final output.
- Each completed iOS folder contains result/state/events; CoreDevice launches
  also include launch output, and the resumed runs include the safe selected
  Power Profiler table export.

Two unrelated app bundle identifiers emitted by Android `AppsFilter` are
redacted from the attached logcat files. No token, signing identity, device
identifier, owner name, or other personal information is attached.

## Verification output

```text
$ /Users/user/fvm/versions/3.44.6/bin/flutter analyze
No issues found! (ran in 5.1s)

$ /Users/user/fvm/versions/3.44.6/bin/flutter test
00:00 +13: All tests passed!

$ /Users/user/fvm/versions/3.44.6/bin/dart format --output=none --set-exit-if-changed lib test
Formatted 14 files (0 changed) in 0.01 seconds.

$ for script in scripts/*.sh; do bash -n "$script"; done
bash_n=PASS

$ shellcheck scripts/*.sh
shellcheck=PASS

$ raw-result validator
result_files=20
state_files=20
crash_files=0
engine_counts:
  10 multilingual_e5_small_onnx
  10 paraphrase_multilingual_minilm_onnx
platform_counts:
   9 ios Version 26.5.1 (Build 23F81)
  11 ios Version 26.5.2 (Build 23F84)
state_phase_counts:
  20 complete
json_schema_checks=PASS
result_state_engine_match=PASS

$ selected-table XML and privacy scan
selected_xml=11
privacy_scan=PASS

$ git diff --cached --check
git_diff_cached_check=PASS
```
