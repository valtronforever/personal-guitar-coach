# Low-register curriculum support — local review

2026-09-16. Same-agent review, not independent. Scope: A1–B1 graded targets, repeat-onset detection, preset/lesson integration and staff display. Part of the active full-curriculum task; not full-course acceptance.

## Findings and fixes

- Merely lowering the MIDI gate would lose low-note reattacks. An initial 72-case probe passed 69 cases; three A1 harmonic fixtures detected only one of four attacks. The rolling background already contained the broad rising transient before its flux peak. Excluded the latest two 10 ms hops from the eight-hop background. Kept the flux/energy thresholds, falling guard, 80 ms startup and refractory time. Worker-only DSP; callback ownership unchanged.
- Unified Settings eligibility with the actual-frequency gate. A1 at A4=400 remains below 55 Hz even though its MIDI number is allowed. Domain tests retain this rejection and historical snapshot readability. All eight standard/drop presets qualify at A4=440.
- Bumped analysis to `mono-mpm-flux-4` and capability to `mono-capability-2`. Route identity includes analysis version in AudioSessionCoordinator, so old calibration is not silently reused. Historical attempts keep their versions; no old scores are recalculated.
- Standard/Drop was a self-check-only topic although the agreed scope includes measurable practice. Enabled its original four-note example as an explicit practice entry, bumped lesson/exercise and both text versions, and explained the assessment limits in both languages. Independent pitch goldens cover every preset and all five neck lengths at minimum/default/maximum tempo.
- Staff rejected A1 despite enough canvas space. Extended the display floor; checked sounding A1 versus octave-transposed written A2, five ledger lines and label containment. Reviewed real Canvas renders in [light](low-register/a1-light.png) and [dark](low-register/a1-dark.png). These renders establish notation layout, not live app interaction.
- The new PCM-to-assessment test incorrectly required exactly 100 pitch points; the scorer intentionally preserves sub-cent errors. Corrected it to ≥95 while retaining four matched notes, zero misses/extras, <15-cent errors and ≤30 ms timing. No scoring implementation was changed to satisfy the test.

## Verification

- Full audio regression: **4,476 cases**, MPM and YIN; [per-case aggregate artifact](../benchmarks/low-register-audio.json). All existing gates passed. The 540 MPM low-register cases cover two rates, supported reference frequencies, three onset phases, three harmonic profiles and 200/300/500 ms notes. All 2,160 attacks resolved; zero misses/extras; onset error p95 11.12 ms, stable-pitch error p95 0.108 cents. The recorded development corpus retains 99.05% reliable coverage, onset recall 1, two extra transients; it is not new hardware evidence.
- Core: **202 tests** covered (23 Persistence, 69 Learning, 36 Domain, 70 Audio, 4 AgentBridge). Final full run passed all except the pre-existing SPSC test's five-second scheduling deadline while Release compilation also ran. No sequence mismatches occurred. After compilation completed, all five RealtimeBufferTests passed unchanged in 0.001 seconds. The new end-to-end PCM/collector/assessment, repeated attacks, held notes and 50 Hz rejection tests passed.
- App: **124 tests** passed. Historical six-lesson × eight-preset save/retry matrix now covers all 48 attempts instead of skipping 11 low-register combinations. Tuner detuning behavior and staff rendering remain covered.
- Project generation current; UI test sources typechecked; **785** bilingual UI keys; **29** lesson bundles validated. Four Python tests and partial 128-topic curriculum audit passed (16 authored, 7 needing review, 105 todo). Full-course acceptance is intentionally not claimed.
- Local Release/archive built and ad-hoc signature/resources checked; [bundle report](../benchmarks/low-register-release-bundle.json). No local Debug .app built or installed. This newly built Release was not launched for native interaction validation.

Reproduce with `swift test --package-path Packages/GuitarCoachCore`, `swift test`, `swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --output /tmp/low-register-audio.json`, then `python3 Scripts/check_audio_benchmark.py /tmp/low-register-audio.json`. Use the stable Xcode developer directory as recorded in README. Staff screenshots use `COACH_STAFF_RENDER_DIR` with StaffRenderTests.

## Remaining validation

Clean real guitar A1–B1 accuracy, pickup/attack variation, interface routing and updated instrument synchronization remain pending_user in USER-VALIDATION. No promise of distorted/polyphonic accuracy, physical string identification or note-offset grading. The ≥200 ms duration and 55 Hz floor remain explicit. The 128-lesson curriculum and later rhythm/articulation functionality remain in progress.
