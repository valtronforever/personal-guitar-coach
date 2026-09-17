# Self-practice recording review

Same-agent local review; not an independent review. Scope: activity opt-in/author validation, frozen capture context, coordinator ownership/cancellation, bounded duration, WAV export and selected-file sandbox permission, en/uk recording sheet and lesson entry point. No new capture pipeline, realtime callback work, AssessedPractice result or provider call.

## Findings and fixes

- A musical 120s limit alone missed the count-in budget for long meters at slow tempos. Author validation and the actual selected-tempo request now additionally cap music plus count-in at 130s, leaving room for a bounded 12s tail and 145s session deadline inside the 150s recording buffer. The sheet disables Start with a translated explanation before capture. Both dotted-quarter and seven-eighths boundaries have pure validation coverage.
- Phase could become review before asynchronous capture cleanup released the owner. `isBusy` now follows the observable capture ID, preventing another take until cleanup finishes. Owner-guarded cancellation cannot stop a later tuner/capture session; tests exercise that race and a busy coordinator.
- Rebuilding the reference plan every UI poll was unnecessary. The model now caches the display plan; the audio clock remains authoritative and the 50ms task only reads state/positions.
- The WAV needed a usable listening/export path without silently calling the graded AI flow. Save WAV uses the explicit native picker, only user-selected-file read-write access, an atomic final write and a private temporary directory removed on exit. Open saved WAV delegates to the system player. The existing service/CLI permissions do not expand.
- A metadata-only completion flag could incorrectly call a truncated recording complete. A completed take now requires sample coverage from before the render epoch through the scheduled end. Export rejects nonfinite samples before touching the destination. A synthetic malformed recording leaves an existing destination byte-for-byte unchanged; failed export leaves the valid in-memory take available for retry.
- Raw input and generated clicks must not imply calibrated, acoustically measured output. Metadata states `assessmentCalibrationApplied: false`, names the channels explicitly, and preserves source mapping, instrument, exercise, route, render/input epochs and output-alignment provenance. A completed transport does not imply successful playing or sound above silence; copy and authoring guide state this.

## Evidence so far

- Six final App tests passed 3.912s: 40 tuning/neck contexts, one complete capture/export, early stop, cancellation and later-owner protection, permission denial, dropped packets, route reconfiguration/unplug, failed endRecording, invalid/short export and unwritable destination. All audio/runtime stimuli are synthetic.
- AVAudioFile reads the exported stereo Float32 WAV after the custom RIFF chunk. Tests verify input sample values, click silence before render epoch, click onset, frame count, RIFF sizes/chunk boundaries, decoded frozen context and absence of score/assessment fields.
- Two Learning tests passed 0.011s: optional YAML roundtrip/unknown mode rejection and author gates for scored entries, fragments/whole-lesson scope, private listening answers, music/count-in duration and compound pulse semantics.
- Generated project, 948 localized keys/placeholder parity, five author-tool tests 16.525s and UI-source typecheck pass. Inventory remains 120 authored / 8 todo; this is not acceptance of all 128 lessons.
- Full Learning: 147 tests/53 suites passed 224.825s. Full App: 193 tests/60 suites passed 257.793s. The later recording-specific race test, seek guard and open-player error UI rebuilt and all six focused tests passed 3.912s. Content validator: 126 bilingual bundles, zero issues. Signed root Release/bundle/XPC and exact-head CI remain pending at this revision.

Native sheet/file-picker/default-player/VoiceOver and real guitar/interface timing remain pending_user in USER-VALIDATION. No native app interaction, microphone capture, provider call or hardware success is claimed by these tests.

A suspended endRecording race is covered: cancel releases the owner, a new tuner starts, and the old completion neither publishes a take nor stops that tuner. Opening a saved file also has translated failure feedback when the system cannot launch a player.

## Local Release evidence (2026-09-17)

Root-only Release .app and ZIP rebuilt successfully with 126 bilingual bundles/379 YAML files and 948 UI keys. Bundle verifier: arm64, macOS 14 minimum, ad-hoc signature, hardened runtime, sandbox/audio-input and user-selected read-write only, en/uk resources and archive verified. Report: `docs/benchmarks/self-practice-recording-release-bundle.json`. Binary SHA-256 `69b80f65ac22c0d2d49726aefd399162c2351bb52f3ab46c8b7c34f692b7f8ab`; archive SHA-256 `0207404dcd787a947b43007dbd70d4257ba7a4ce83ad002d8f1641ecc903b3c7`. Signed sandbox→separate XPC→invalidRequest check passed; no provider called. No Debug app was built locally. Native app launch, real guitar and file-picker/player acceptance remain unverified.

Local logs: `/tmp/self-recording-{focused-final,learning-full,app-full,content,release,bundle,xpc}.log`. Exact-head CI/merge remains open.


Exact-head macOS CI 35201278626 passed on `84836b07c23017cb6b5da582eaec0ba88399328b` (2026-09-17 09:18:56 UTC). PR 96 merged as `3a5dd7d023d3d5577d9b097f96a6ff572539e8fb` at 09:19:52 UTC. Software implementation accepted; native recording/save/player and real-guitar checks remain `pending_user`.
