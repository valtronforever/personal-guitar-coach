# Rapid repeated-attack rhythm assessment

Status: `in_progress`

The full-course audit identified a remaining capability gap in topic 96: fast tremolo was display-only. This extension adds explicit fixed-note rhythm assessment without pretending that every short note has a settled pitch.

## Implemented

- Author `assessmentMode: rhythmOnly`, actual repeated fret position/rest/tick data, normal practice entries. Structural guards reject changing pitch, polyphony, muted/palm-muted/held/moving/harmonic/sustain techniques and hidden listening. Sounding register110–440 Hz; notes≥150 ms; fast-short/fast-long allow40–100 BPM. Lesson and changed exercises version2; all preset/neck adaptation stays consistent. Final changing-pitch study remains self-practice.
- Same bounded analyzer/capture pipeline and onset history; additionally retain the existing periodic-window trace. Two coherent periodic frames support timing without changing `PracticeAttack.reliable` or inventing a pitch measurement. Noise/clipping/absent trace stay insufficient, silence after valid preflight is distinct, route/data-loss paths remain intact.
- Versioned result `repeated-attack-assessment-1`/capability1 explicitly omit pitchScore and cents. Existing assignment/rest/count-in rules and penalties apply. Current monophonic limits/versions are unchanged. Persistence rejects a rhythm algorithm with a pitched exercise or pitch score.
- 20 ms rapid onset allowance is bounded synthetic evidence, not hardware accuracy. Calibration still needs half-tolerance eligibility: at100 BPM no more than13.75 ms remain for calibration/drift. Existing50 ms manual allowance can support40 BPM but correctly withholds100 BPM. UI/result/history/retry/local-agent context distinguish this and never claim pitch feedback.
- Both languages explain the distinction, author docs and audio contract state boundaries, real-guitar/native checks remain pending_user.

## Verification in progress

Initial end-to-end synthetic PCM at44.1/48kHz passes16 rapid attacks, misses, extras in rests, uneven spacing, count-in exclusion, changed audible pitch without pitch grading, silence/noise/clipping, absent trace and uncalibrated cases. Expanded phase/register corpus, full regression, local Release and exact-head CI/merge are in progress. No provider, device calibration, real guitar or native file dialog was exercised by these tests.

[Same-agent review](../../docs/reviews/rapid-rhythm-assessment-review.md) will record final evidence. Do not mark the whole128-topic curriculum accepted merely because all files exist; its final mapping/editorial/software review remains separate.

## Final local verification (2026-09-17)

- Domain65 tests/21 suites passed0.342s; Learning150/55 passed243.167s; Persistence23/4 passed0.058s. Following the conservative20 ms/100 BPM adjustment and final mode-storage guard, focused contracts/tremolo2/2 passed2.128s and Persistence23/4 passed0.057s.
- Final rapid audio3 tests/1 suite passed105.918s:54 independent onset/periodicity cases across44.1/48kHz, MIDI45/57/69, three spacings and three onset phases;8 phase-continuous assessed register/rate cases; defects/noise/clipping/silence/count-in/absent-trace/uncalibrated scenarios. The raw125 ms onset probe remains a stress case; current graded practice requires150 ms. These are synthetic PCM, not guitar recordings.
- Final App199 tests/62 suites passed288.243s. Covers all bundled practice→stored result→retry flows, new rhythm-only history/prompt/tuning behavior and manual40-versus100 BPM eligibility. Earlier runs exposed the universal pitch-score fixture and, during the capability adjustment, stale compiled120 BPM assertions; the recorded final run rebuilt after all source/resource changes and passed.
-134 bilingual bundles/403 YAML files validate with zero issues;951 UI keys in en/uk; project generation and UI-source typecheck pass. Five Python author-tool tests passed17.857s. Partial inventory reports128 authored and makes no full-acceptance claim.
- Root-only signed Release .app and ZIP built/verified; arm64 macOS14, ad-hoc signature, hardened sandbox/audio/user-selected-read-write and offline en/uk resources. Report `docs/benchmarks/rapid-rhythm-release-bundle.json`. Binary SHA-256 `81dce547c074614ee29be4c22d456f31faa5c84814e676c6f740c545f2a7cb31`; archive `73ee22f46a153c4c3b6950dbd9ee15bd53231313d0b67d2e7f71f06f879a198e`. Signed sandbox→separate XPC→invalidRequest probe passed without a provider call. No local Debug app. Native launch and hardware remain unverified.

Logs: `/tmp/rapid-{core-regression,contracts-final,app-verified,content-final,author-tests,ui,release,bundle,xpc}.log`. Exact-head CI/PR/merge still pending.
