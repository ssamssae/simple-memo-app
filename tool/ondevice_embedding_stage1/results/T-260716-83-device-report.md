# T-260716-83 stage1 physical-device measurements

Measured on 2026-07-16 KST from the non-merge experiment branch
`spike/T-260713-55-stage1`. Production code and flags were not touched.

## Coverage and conditions

| Leg | Device / mode | Status |
| --- | --- | --- |
| Android | Galaxy S24 (SM-S921N), Android 16, debug, arm64 | E5 and MiniLM complete; no crash |
| iOS | iPhone 17, iOS 26.5.1, release, arm64, wireless | MiniLM 5/10 and E5 4/10 complete; remaining rotation blocked when the device locked |
| Gemma | both | Skipped fail-closed: no gated model files or external terms-acceptance attestation were present |

Flutter 3.44.6 / Dart 3.12.2 was selected from the existing FVM cache. The
global Flutter installation was not changed.

Android was USB-powered at 100% throughout the leg. Therefore the captured
`batterystats` files are raw diagnostics only, not valid unplugged energy
measurements. The charge counter stayed at 3,880,000 and thermal status stayed
0. No Android battery claim is made.

iOS was reached wirelessly through CoreDevice. `xctrace` still classified the
physical phone as offline, so Power Profiler and Activity Monitor recordings
could not start (`Waiting for device to boot`). Consequently no iOS energy or
RSS/PSS claim is made. The release mode was used consistently for both iOS
candidates because a debug app cannot be relaunched through CoreDevice without
an attached Flutter/Xcode debug session; the local-network VM-service channel
was unavailable.

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

## iOS repeated release runs available before lock

The order was alternated by round and every launch used
`--terminate-existing`. Values below are the distribution of the completed
runs; they are performance-repeat data, not battery results.

| Engine | n | Cold load median (range) | First median (range) | Warm median-of-medians (range) | Reindex 100 median (range) |
| --- | ---: | ---: | ---: | ---: | ---: |
| MiniLM qint8 | 5 | 387.673 ms (330.530–406.652) | 16.692 ms (16.184–17.693) | 17.100 ms (14.840–18.247) | 1,693.843 ms (1,443.673–1,817.735) |
| E5-small FP32 | 4 | 472.949 ms (428.272–539.730) | 224.655 ms (198.668–261.381) | 210.818 ms (186.276–238.276) | 22,141.405 ms (20,768.487–24,184.823) |

All nine completed runs ended in `complete` with no `crash.json`. During E5
round 05 the phone locked: events stopped at `reindexing-100`, no result or
crash file appeared, and the next launch was denied with `RequestDenied` /
`Locked`. An unlock request was sent to the operator bot chat and the lock was
polled for five minutes; it remained locked. That incomplete attempt is not
included in the table.

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
- iOS completed folders: `results/iphone-ios26/rounds/round-01-*` through the
  completed parts of `round-05-*`.
- Each adopted Android folder contains startup, RSS samples, final meminfo,
  result/state/events, scoped logcat, and batterystats reset/final output.
- Each completed iOS folder contains result/state/events; rounds launched by
  CoreDevice also include the launch output.

Two unrelated app bundle identifiers emitted by Android `AppsFilter` are
redacted from the attached logcat files. No token, signing identity, device
identifier, owner name, or other personal information is attached.

## Verification output

```text
$ flutter analyze
No issues found! (ran in 4.9s)

$ flutter test  # before the iOS linkage regression was added
00:00 +12: All tests passed!

$ flutter test test/ios_podfile_test.dart  # RED
Expected: contains 'use_frameworks! :linkage => :static'
Actual: use_frameworks!
00:00 +0 -1: Some tests failed.

$ flutter test test/ios_podfile_test.dart  # GREEN
00:00 +1: All tests passed!

$ pod install
Pod installation complete! There are 6 dependencies from the Podfile and 8 total pods installed.

$ flutter run -d <redacted-device-id> --release --no-resident
Xcode build done. 57.2s
Installing and launching... 3.2s
```

Final full-package verification and git diff checks are recorded in the pull
request after the measurement artifacts are staged.
