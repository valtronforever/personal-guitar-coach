# MVP validation — task 20

Software validation is complete to the scope recorded below; **physical MVP acceptance remains pending**. Per the user's instruction, all checks needing their instrument, permission or environment repair take place after tasks 21–22. The [final user checklist](USER-VALIDATION.md) is authoritative for those open gates. No distribution, notarization or external upload is planned.

## Baseline and provenance

Local checks: 2026-09-10, Apple M2 Max, 12 logical CPUs, 32 GiB RAM, macOS 26.6.2 (25G83), Xcode 26.6 (17F113), Swift 6.3.3, SDK 26.5. Local app architecture is arm64, deployment target macOS 14. Deployment metadata does not establish execution on macOS 14 or Intel. CI builds the Xcode project separately on its recorded macOS runner/toolchain.

Task 20 is based on main `2ecba2cfdd09ec841ac5a0ad8021c90abbfa711f` (task 19), plus its reviewed changes. Benchmark artifacts record this source stage, not a claim of byte-identical builds across SDKs, machines or future commits. Algorithm remains `mono-mpm-flux-2`; this task adds public immutable observation constructors but changes no DSP computation or score thresholds.

Read-only audio discovery found no Scarlett USB interface connected. Built-in microphone reports 48 kHz; Bluetooth default input reports 16 kHz, outside the 44.1/48-kHz analysis matrix. No device configuration was changed and no input capture or microphone permission was requested. Local `xcodebuild` project execution still needs U07 environment repair. The native computer-use pipe failed during task 17 and did not recover in subsequent reconnect attempts; new results/course native UI inspection is not claimed.

## Product acceptance matrix

| Product requirement | Software evidence | Remaining acceptance |
| --- | --- | --- |
| Native macOS app, offline learning | SwiftUI app/Xcode project; local signed Debug/Release bundles; compiled resources and extracted ZIP verified | U07: launch final Release offline, macOS window/menu/icon behavior; other OS/architecture untested |
| Six bilingual text lessons and practice | Six original lessons, 29 steps, 19 JSON resources; content validator and independent MIDI/timing/course-flow fixtures; [course](STARTER-COURSE.md) | U05/U07: beginner, language, fingering and long-text walkthrough |
| Step ↔ fretboard ↔ TAB selection | Shared event IDs, fret positions, tuning and ticks; domain/App synchronization tests; task 08–10 visual evidence | U05/U07: current full-course keyboard/VoiceOver, narrow window, both themes |
| Tuning and instrument profile | Standard, Drop D, D Standard, custom/A4/orientation persistence and validation; fixed-tuning preflight and archived retry tests | U02/U05: physical instrument matches selected target; ergonomic use |
| Explicit audio interface/channel/source | CoreAudio discovery, bounded callback buffer, lifecycle tests, no disconnected-device substitution; task 11 discovery evidence | U01/U04/U08: actual USB/piezo/microphone PCM, channel mapping, permission recovery, hot-plug/rate/buffer/sleep |
| Tuner, monophonic pitch and onsets | DSP unit/regression tests; synthetic matrix and public annotated acoustic development clips; [task 17 benchmark](benchmarks/17-assessment.md) | U02/U04: held-out electric DI and live tuning, harmonics/noise/click leakage |
| Sample-clock metronome and example | Transport render/schedule tests; silent native built-in output smoke evidence in task 14; practice suppresses reference tones | U09: audible selected-channel output, physical timing/cursor alignment, 15-minute load run |
| Calibration and honest rhythm grading | Signed synthetic offsets, clock mapping, drift/uncertainty gates; estimated/manual routes retain pitch-only results | U03: real loopback offset/uncertainty, separate-device drift and independent residual checks |
| Full independent practice attempts | Preflight/count-in/final drain/interruption/retry/save-backpressure App tests; accelerated 900-second event simulation | U10: real playing and healthy all-missed session, repeats, unplug/sleep during drain, sustained CPU/memory |
| Scores and actionable feedback | Deterministic assignment/validity/grades; 32 annotated acoustic first attacks; rule-based advice, comparable history and frozen versions | U02/U03/U05/U10: independent playing accuracy; advice usability. No inferred strings/fingers or polyphonic score |
| Durable local history and settings | Atomic schema/version validation, corruption/future-format preservation, save retry, archived tuning and language-independent history tests | U07/U10: final native recovery/retry interaction |
| English/Ukrainian and accessibility | 492 translated UI keys, placeholder/plural checks, localized microphone purpose, six translated lessons; UI-test source type checking | U05/U07: executed UI tests, VoiceOver, keyboard-only navigation, long text at minimum size, light/dark contrast |
| Local Release artifact | Ad-hoc hardened-runtime signature, exact sandbox/audio-input entitlements, original icon, both catalogs, six lessons, only system dynamic libraries, ZIP re-verification | U07/U08: actual final launch/permission; no distribution acceptance required |

Passing state/model tests do not establish native UI execution. Synthetic calibration does not establish physical latency. The public acoustic corpus is development data, not an unseen electric-guitar test set. The recorded-data assessment fixture yields 18 scored and 14 unscored attempts; uncertain extra detections are retained, not hidden or converted to successful scores.

## Reproducible software checks

Run package commands sequentially when they share a SwiftPM build directory. `build_local.py` uses both packages because it validates staged lesson resources.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 Scripts/generate_project.py --check
python3 Scripts/check_localizations.py
python3 Scripts/check_ui_sources.py
swift test --package-path Packages/GuitarCoachCore
swift test
python3 Scripts/check_audio_fixtures.py
swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --quick --output /tmp/coach-audio.json
python3 Scripts/check_audio_benchmark.py /tmp/coach-audio.json
swift run -c release --package-path Packages/GuitarCoachCore BenchmarkPractice /tmp/coach-practice.json
python3 Scripts/build_local.py
python3 Scripts/build_local.py --configuration release --archive
python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --archive build/release/PersonalGuitarCoach.zip
```

The task-20 full run exercised 129 core tests: 128 passed and the new shared-quality-bound test initially failed because it assumed an equal 2048/2048 split. The collector processes clipping before uncertainty in a publication; the actual contract is their combined 4096 limit. After correcting that assertion, all five `PracticeEvidenceTests` passed. All 52 App tests passed. No production collector behavior changed. Final CI repeats the complete suites on the submitted source.

`BenchmarkPractice` accelerates 900 seconds of **synthetic observation DTOs**, including count-in/tail, into 45,231 publications. It verifies 900 attacks, 900 settling intervals, rolling windows capped at 128 events/256 spans, exact compensated score, fresh-attempt isolation and two immutable saved/restored records. It processes no PCM and measures no callbacks, underruns, physical drift or live 15-minute CPU usage. [Its report](benchmarks/20-practice-soak.json) gives measured process high-water RSS and actual processing time, not leak-free or hardware claims. The task-20 Release quick DSP benchmark passed all 360 cases and the unchanged gates. Running the already-built executable took 9.74 seconds wall, 9.14 seconds user and 0.20 seconds system CPU, with peak RSS 25,542,656 bytes. These are offline batch metrics. The full 3,360-case v2 regression artifact remains task 17 because no DSP computations changed.

The separate shared-bound test checks combined quality evidence stops at 4096, while the existing attack test stops at 2048.

## Local packaging and icon

`Scripts/build_local.py` compiles the selected configuration and assembles resources in a staging directory. Content, catalogs, signature, executable metadata and dependencies are verified before the previous usable app is replaced. A failed final rename restores the previous bundle. `--archive` creates a local ZIP next to the app; the separate checker extracts and verifies its actual payload. Neither command publishes anything.

The icon is original project artwork, drawn with CoreGraphics by `Scripts/generate_icon.swift`: six strings, frets and a selected note. It uses no external bitmap, font or third-party artwork. Its 1024-pixel output was visually inspected. Reproduce the ten native PNG sizes and ICNS with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift Scripts/generate_icon.swift
python3 Scripts/generate_project.py
```

The bundle checker verifies ad-hoc/runtime signing and exactly the two existing entitlements, both compiled locales and microphone reasons, source-identical lesson JSON/icon, icon dimensions, Mach-O macOS-14 target, system-only linked libraries and absence of debug fixture types in Release. Its `appLaunchVerified` and `hardwareVerified` fields intentionally remain false. Negative checks rejected a tampered icon resource and truncated ZIP. The final artifact report is [20-local-release.json](benchmarks/20-local-release.json); `build/` outputs remain ignored by git.

## Final physical 15-minute protocol — pending

After task 22, record Mac/OS, interface/driver, guitar/source, selected input and headphone output channels, actual sample rate/buffer, calibration ID and algorithm versions. Start with clean electric DI and wired headphones on one USB interface. Use the normal macOS permission flow (U08); do not bypass it.

1. Select channel and source, check clean level without clipping, select actual tuning/A4, tune every string, then read and select lesson steps. Verify expected positions and TAB in each language.
2. Measure cable loopback using [ADR 003](decisions/003-calibration-time.md), independently verify residual error and uncertainty, then restore the guitar. An unavailable/unreliable calibration must leave rhythm ungraded.
3. Play repeated-note/rest and Em arpeggio exercises, including correct, deliberately early/late/wrong/missing/extra notes. Inspect evidence, advice, retry fragment and reopened history. A healthy silent performance after successful preflight is missed notes; bad input is a different validity state.
4. Sustain repeated attempts for at least 15 real minutes. Record callback drop/underrun counters, maximum observed clock drift, CPU samples, RSS at start/every minute/end and attempt/evidence counts. Use the same sampling method/interval; publish raw observations and whether RSS reaches a plateau. Accelerated benchmark numbers are not substitutes. Require no unexplained lost buffers, stale cross-attempt events or unbounded growth; rhythm must revoke capability when its uncertainty/drift limits are exceeded.
5. While idle, active and draining, exercise unplug/replug, supported rate/buffer changes, sleep/wake, pause/seek/tempo and failed-save retry. Confirm no misleading score, device substitution, abandoned capture or repeated save. Restore original device settings afterwards.
6. Repeat relevant source/noise/leakage checks for microphone and piezo. Verify final Release offline, both themes/languages, minimum window, all result disclosures, keyboard and VoiceOver. Record failures and fixes before closing U01–U10 or declaring hardware MVP acceptance.

No physical metrics are currently available. Task 20 remains `pending_user`; subsequent research/prototype work is authorized without presenting these gates as passed.
