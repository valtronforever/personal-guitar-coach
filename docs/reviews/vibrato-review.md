# Vibrato: same-agent review

Software review complete; CI/merge and real-instrument/native acceptance remain open. This is not an independent review.

Scope: authored single-note modulation, preset/region resolution, prepared reference phase, periodic-contour measurement, versioned results and agent exchange, notation/accessibility, and the five-activity bilingual topic 56 lesson.

Findings and corrections:
- The first reference test exceeded the renderer's 48000-frame worker bound. Kept the production bound and tested permitted chunks plus independent later-phase samples. Chunk, seek, loop, count-in and practice-silence checks pass for all six meters at 44.1/48 kHz.
- Median rate and dispersion relative to that median could hide a slow cycle: an independent irregular fixture measured 1.70 Hz with 15% dispersion despite an outlying interval. Persisted slowest/fastest cycle rates and required every measured interval within ±20% of the target. The same fixture now fails musically, while harmonic PCM regressions still pass.
- A copied coach fixture retained transition-specific text and ended the contour before the vibrato return. Corrected it to the four-second event and vibrato metadata. All eight coach tests pass, including observation-ID tamper rejection; no provider was called.
- Notation accessibility risked describing cycles/second using default BPM during tempo changes. It now describes cycles per musical beat. Results separately report measured cycles/second.
- The generic capability message suggested only lowering tempo, which can make a vibrato rate too slow. It now identifies pitch, duration or technique limits and asks for a supported tempo. Vibrato instructions give the supported width, rate, cycle count and stable-phase duration.
- Validation rejects positive modulation coverage without measured cycle rates, or measured metrics without a normalized start. Mixed bend/transition/vibrato/sustain scoring preserves the previous result when vibrato is absent; the added fixture independently expects 89 rather than the old 90.

Verification:
- Full Core: 23 Persistence tests (0.052 s), 125 Learning (111.354 s), 50 Domain (0.331 s), 102 Audio (456.549 s), 6 AgentBridge (1.587 s): 306 tests total. `/tmp/vibrato-core-full.log`.
- Full App: 159 tests in 47 suites (168.394 s). `/tmp/vibrato-app-full.log`.
- Final stricter-metrics/mixed-motion changes after the full-suite snapshot: 4 Learning tests in 2 suites, including both mixed configurations (0.038 s). `/tmp/vibrato-final-regressions.log`.
- Independent harmonic PCM covers 23 cases: both sample rates, G3/A5, widths 30/100 cents, rates 1/3 Hz, 0.4-second plateaus, and separate wrong-width/rate/base, flat, silence, noise and clipping inputs. This is synthetic evidence, not a physical guitar recording.
- The five activities preserve expected pitches and metadata across 8 tunings × 5 neck lengths × 3 position choices. All requested BPM bounds remain within capability.
- Two notation/offline render tests pass. `/tmp/vibrato-visuals` contains both languages/themes; Ukrainian light and English dark were inspected for wavy timing spans, tied notes and target-curve readability. These do not establish native interaction.
- 87 bilingual bundles validate with 0 issues; 875 localization keys pass. Four Python authoring/audit tests pass (9.770 s), generated project is current, and UI-test sources type-check.
- Root-only Release and ZIP verified in `docs/benchmarks/vibrato-release-bundle.json`: arm64, macOS 14, ad-hoc signature, hardened runtime, expected sandbox/audio entitlements, 87 bundles / 262 YAML resources. Binary SHA256 `d620ce4803765e08e780e4f034d1590b52bc9eb5fc7455dd0b8886d9d4ce6397`; archive SHA256 `89669dee997c91a2d377e4602913f53d671acc35d370af6cb408d14b32ae44ab`. Final signed sandbox → separate XPC → invalidRequest probe passed, with no provider call. `/tmp/vibrato-release-final.log`, `/tmp/vibrato-xpc-final.log`.

No native app launch, real guitar vibrato, audio-route or user acceptance is claimed. The course inventory is 80 authored / 1 needs_review / 47 todo, not full-course acceptance.

PR 84 merged at exact head `850d76574fbbae841fd1ed142ade524e98ed1d10` after GitHub Actions run `35179866487` passed in 21m53s. Merge commit `78db84b1b5f70dc1897216d889f636cc2cf85287`. Hardware/user validation remains open.
