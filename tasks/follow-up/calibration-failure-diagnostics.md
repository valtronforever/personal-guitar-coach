# Calibration failure diagnostics

Status: `pending_user`

## Problem and scope

The user reports repeated rejection after the first pass with normal input level, including attempts with a ringing/muted low C2 string. The old `sync.failed` text hid every rejection behind a claim about two inconsistent passes, including failures before a second pass existed. The current input/output route uses separate devices. No specific hardware/DSP cause can be inferred from the old screenshot.

Expose the actual gate and bounded, in-memory evidence: pass/stage, target and last detected frequency, maximum observed peak, measured/matching/wrong/uncertain attacks, timing spread/window/drift, clock drift and between-pass disagreement. Retain this report when capture stops; clear it on retry/cancel/route change. Preserve existing acceptance gates, profile persistence and scoring versions. Clarify half-second note duration instead of ambiguous “short notes”.

## Acceptance and evidence

- Typed failure reasons replace the generic error; backend interruption reasons survive instead of being mislabeled as route changes.
- `PersonalSyncPassAnalysis` is the common calculation used by the acceptance initializer and diagnostics. Matching remains 16 attacks, ±400 ms, spread ≤60 ms, drift ≤40 ms; no selective removal or relaxed scoring.
- Six focused Core tests passed, including 16 C2 half-second PCM notes through the actual analyzer at 44.1/48 kHz. These are synthetic signals, not Scarlett recordings.
- Eight focused App tests passed: retained first-pass count/spread/clock diagnostics, wrong pitches/clipping, second-pass disagreement, retry/cancel, route invalidation and save/freshness behavior.
- Native inspection confirms saved input/output selection without starting capture. Actual failed-pass reason on the user's route remains pending a retry with the updated app.
- Full App suite: 105 tests / 28 suites passed. Final added backend data-loss assertion passed in the focused lifecycle test. 663 EN/UK keys, project generation and UI-source typecheck pass.
- Local Release app/ZIP rebuilt and verified: [bundle evidence](../../docs/benchmarks/calibration-diagnostics-release-bundle.json). No Debug app was recreated.
- [Same-agent review](../../docs/reviews/calibration-failure-diagnostics-review.md). Native route inspection succeeded; after quitting the old app the computer-use bridge closed and could not relaunch it. Updated native diagnostic layout and hardware outcome remain pending; the user was asked to retry with the new report. CI/merge evidence is tracked in the PR.
