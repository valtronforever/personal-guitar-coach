# Personal timing synchronization wizard

Status: `in_progress`
Dependencies: 11–18. Follow-up to task 15; cable calibration is excluded from the current UI.

## Acceptance

- Independent input/output/channel selection; open-string target follows the instrument tuning.
- Clean pitch preflight, four listening clicks, sixteen played clicks at 60 BPM, repeated in a second pass.
- Reject missing/extra/wrong/uncertain notes, clipping, data loss, unstable offsets, clock loss and route changes.
- Review and explicitly apply a fixed personal compensation; cancellation/failure preserves the previous profile.
- Distinguish approximate personal timing from hardware measurement in practice and history.
- Recheck after relaunch, reconnect, sleep, route/format/instrument change. Never learn compensation from practice mistakes.
- English/Ukrainian, keyboard and VoiceOver labels. Reported output latency affects cursor; personal residual does not identify output-only latency.
- Validate pure estimator, scoring, persistence migration, lifecycle and failure paths; record separate real-device gates.

## Evidence

- Core full suite: 166 tests / 34 suites passed; added legacy-v1 regression subsequently passed in the focused 19-test / 4-suite run (including recorded assessment corpus).
- App full suite: 85 tests / 22 suites passed. After receipt cleanup, all 6 calibration store/flow regressions passed again.
- 572 UI localization keys validated in en/uk; generated Xcode project current; UI-test sources typechecked; git diff whitespace check passed.
- Local Release app and ZIP built with ad-hoc signing; 13 bundled bilingual lessons validated. Bundle report: [15-personal-sync-bundle.json](../docs/benchmarks/15-personal-sync-bundle.json).
- Same-agent [local review](../docs/reviews/15-personal-sync-review.md) completed with findings and fixes.
- Native UI inspection attempted: computer-use bridge returned “Sky Computer Use native pipe closed before response”. No live UI/audio result is claimed. Real Scarlett/wired/Bluetooth, keyboard/VoiceOver and layout gates remain in [USER-VALIDATION](../docs/USER-VALIDATION.md).
- PR/CI/merge pending.
