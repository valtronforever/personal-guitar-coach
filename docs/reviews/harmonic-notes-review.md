# Harmonic notes — same-agent review

Implementing-agent review, not an independent review. Status: software verification in progress.

## Scope and findings

Explicit natural partials 2/3/4 and touched artificial octaves now have canonical sounding pitch/frequency distinct from physical touch/base positions. Topic 94 has six bilingual progressive activities, one physical self-practice task with four criteria and one factual quiz. This is not pinch-harmonic, timbre or hand-gesture detection.

- Direct stopped-fret pitch consumers in resolved exercises, assessment, reference, text, board, result and coach context would produce a wrong natural third-partial target. They now share Domain `soundingPitches`, exact `soundingFrequencies` and role-bearing `visualTargets`; the ordinary instrument pitch map remains unchanged. The third partial uses the ideal multiplier rather than rounding to the MIDI label.
- Ordinary region relocation could move a natural node or place an artificial touch off the neck. Natural nodes remain fixed and incompatible interval-transposing activities report unavailable. Artificial octave relocation validates base and linked +12 touch; the author search window permits 13 frets for two hands. Named-fingering projections from harmonic exercises are rejected rather than losing metadata.
- Multiple selected events can place ordinary and harmonic targets at the same physical position. The board retains every target pitch and identifies the presence of a touch instead of silently replacing one target. Text notes omit the artificial stopped base from the audible sequence, while physical positions include both roles.
- The first StaffView edit accidentally duplicated a Canvas draw block into accessibility text. Compilation caught it; the invalid block was removed and the actual drawing retained. Targeted App tests and offline renders subsequently passed.
- Reference phase must survive chunk boundaries, seeks and loops. Harmonic references retain their original note onset; a separate ideal sine oracle verifies exact third-partial frequency at both sample rates. Measured practice keeps the expected tone silent.
- Harmonic attempts select capability 7, assessment 8 and coach prompt 10. Old events omit the field; earlier algorithm versions/ordinary encoding are preserved. Frozen results reject a downgraded assessment version or rounded equal-tempered target. Existing sustained-note evidence uses the exact harmonic target.
- All physical hand/node/finger, pinch and timbre claims are explicitly withheld. No new capture owner, DSP backend or audio callback allocation was introduced. Actual guitar residual fundamentals, noise and pickup behavior remain hardware acceptance work.

## Verification evidence

- Domain: three tests, 0.005 s; all eight presets ×six strings ×three natural partials, artificial base/touch bounds, third-partial 1.955-cent oracle, invalid metadata and ordinary canonical encoding (`/tmp/harmonic-domain-tests.log`).
- Course: two tests, 2.624 s; 296 activity/tuning/neck/choice cases with independent expected MIDI sequences, Drop sixth-string targets, exact third frequencies, unchanged ticks and physical roles. All graded selections validate at 40/60/100 BPM; unavailable natural transposition and metadata-losing fingerings reject (`/tmp/harmonic-course.log`).
- Synthetic PCM: initial three tests, 30.697 s, 44.1/48 kHz isolated natural/artificial partials, existing collector/assessment and frozen result round-trip. Wrong stopped notes/fundamentals and silence are musical misses; uncertain noise/clipping withhold a score (`/tmp/harmonic-pcm.log`). Additional sustain/history test passed in 2.486 s (`/tmp/harmonic-sustain.log`); the full suite below rechecks all four together.
- App targets/coach: three tests in two suites, 1.615 s (`/tmp/harmonic-app-targets.log`). C Standard selection/practice touch roles, sounding TAB/staff, en/uk spoken labels and exact frozen coach context; no actual provider invocation.
- Offline SwiftUI render fixture: 0.272 s (`/tmp/harmonic-render.log`). Inspected `/tmp/harmonic-visuals/harmonic-uk-light.png` and `harmonic-en-dark.png`: angle-bracket nodes, artificial base/touch pair, diamond staff, N.H./A.H. and localized instructions are readable at 800-point fixture width. These are render fixtures, not a native app interaction/VoiceOver acceptance test.
- Content: 109 bilingual bundles, zero issues. Partial course audit: 103 authored/25 todo. Localization: 911 en/uk keys and matching placeholders. Generated project current. Python author tests: five pass, 12.515 s. `git diff --check` passes.

Full Core/App, signed root Release/archive/XPC and exact-head CI results will be recorded after completion. Native application interaction and real-instrument acceptance remain open in USER-VALIDATION.

The first full Core run exposed two old tests that still treated a 13-fret search window as invalid. The harmonic contract intentionally permits that inclusive width for base +12 touch. Updated both rejection boundaries to 14 and added explicit acceptance at 13; no production behavior was changed to satisfy the obsolete assertions. The full run's other suites continue, and Domain will be rerun after completion.
