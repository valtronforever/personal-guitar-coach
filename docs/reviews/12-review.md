# Task 12 — Local implementation review

Review performed by the implementing agent, not an independent reviewer. Scope: pitch/onset mathematics and primary sources, real-time ownership, bounded evidence, input time/format integrity, capability enforcement, public fixture provenance, deterministic benchmark and integration with the existing coordinator.

## Findings and fixes

1. A 1024-sample onset spectrum and single-hop energy produced false repeated attacks on low harmonic C2. Expanded the spectrum to 2048 samples and smoothed its energy; the full final synthetic/matrix corpus has no extra attacks.
2. A very low C2 at A4=400 hid repeated attacks at 300 ms spacing. Lowered the adaptive positive-flux floor, then added a falling-signal guard after the wider detector incorrectly treated releases as attacks. The final matrix finds all 5,088 repeated-note attacks per method, including this regression.
3. Raw sub-fundamental energy from an unwindowed projection leaked from a negative fifth into the fundamental bin. A Hann projection reduces this leakage while retaining weak real-guitar fundamentals. Selected/double-period comparisons now use interpolated values so high-note lag quantization does not invent octave ambiguity. Negative fixtures produce no reliable note events.
4. Recorded acoustic clips contain strong low-frequency rumble and are not exactly tuned to A4=440. Added bounded high-pass preprocessing while preserving raw clipping evidence. References come from a separate long-window spectral annotation procedure; neither algorithm sees those references during detection. The corpus and report explicitly state their development/estimated-label limitations.
5. Startup spectral history and cropped-source edges could create a spurious first attack. An 80 ms causal-history warm-up suppresses that edge. Preflight/count-in must start capture before graded notes; a tuner can still estimate sustained input. An emitted attack waits for a complete post-onset pitch window.
6. A missing period estimate did not reset the consecutive-stability counter. It now resets on every rejected candidate, preventing nonconsecutive estimates from becoming reliable. Brief clipping could also disappear from the latest UI snapshot, so bounded coalesced quality spans preserve it for assessment consumers.
7. Finite-but-extreme PCM could overflow the filtered Float buffer. Bound values before DSP while preserving the original peak/clipping indication; a dedicated test verifies finite output and retained clipping evidence.
8. A bad packet host timestamp followed by a valid packet could be hidden by last-packet metadata. The reader counts corruption per packet and the coordinator interrupts on it. The regression feeds both packets through the real C ring. The capture worker now checks cancellation between packets and is cancelled by backend stop/deinit, preventing an orphan worker from retaining its ring.
9. Initial corpus-note search windows for two low-string notes and F♯4 had followed rumble rather than the pluck. Regeneration now uses corrected source windows and an independent high-pass envelope; source frames/hashes, resampling and annotation uncertainty are recorded for every clip. Raw downloaded AIFFs remain outside git.

## Verified outcome

- 71 core tests / 12 suites pass, including real C ring → selected mono channel → production reader → note evidence, packet corruption, nonaligned attacks, chunk-size invariance, sample-rate/A4/duration gates, and 136 attacks retaining only 128 events.
- 30 App state tests / 8 suites pass. Existing en/uk catalog remains 243 keys; no new UI flow or strings were introduced. Generated project and UI-source type checking pass; actual UI XCTest execution remains U07.
- Full Release benchmark: 3,360 cases; quick CI regression: 360 cases. Both pass `check_audio_benchmark.py`. Fixture validation verifies all 34 WAV hashes, mono/rate format and provenance offline.
- MPM synthetic pitch p95 0.048 cents; acoustic p95 7.301 cents, with 99.05% of all annotated stable frames within ±15 cents. Matrix onset p95 13.22 ms; acoustic onset p95 30 ms. p95 resolved-note latency is 100/160 ms respectively. These are development-corpus results, not live USB latency claims.
- Native Debug and Release builds and strict ad-hoc signature verification pass. No input Start, permission manipulation or private recording was performed. New detector behavior is exercised offline and through synthetic ring input; physical capture is still pending.
- `git diff --check` passes. PR CI must pass before merge; its actual result belongs to the PR record.

## Remaining limits

Two additional unstable transients in the public A2 clip (one at each rate) remain conservatively counted as extra onsets. The low-gain robustness group loses quiet-tail frame coverage instead of inventing pitches. Those limitations are reported, not removed from denominators. This is not a general polyphony classifier; octave-related tones may be indistinguishable from harmonics.

U02/U04: held-out clean electric DI, real guitar tuning/onset/settling, acoustic/piezo rooms and leakage after all 22 implementations. Task 15 must replace the initial host anchor with validated clock/latency/drift semantics; task 16 must consume rolling event/span IDs without gaps; task 17 must distinguish system/capture quality from musical errors. The 200 ms software gate does not authorize rhythm grading on an uncalibrated route.
