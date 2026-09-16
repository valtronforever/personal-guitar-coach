# Independent output and instrument latency settings

Status: `pending_user`

User scope: two independent settings, output alignment defaults to zero. Optional output-only keyboard/mouse calibration; separate guitar measurement uses the saved output value, with no mandatory first step. Each retains a screenshot-friendly beat/attack/error timeline, including failure/cancellation. Taps are approximate personal alignment, not isolated hardware latency.

Acceptance: output-only route requires no microphone/capture; event timestamps preserve actual input time; repeated keys suppressed; all bounded markers and missing/extra/uncertain detections remain inspectable; independent explicit Apply/reset; instrument compensation snapshots output setting and never double-applies it; changed output invalidates instrument freshness; old calibration/history remains readable; EN/UK and keyboard/accessibility; default-zero output affects practice cursor independently of rhythm eligibility. Local signed Release, tests, review and real-device gates documented before completion.

Additional user scope: signed manual input for both settings, output correction/total-specification reference, and approximate rhythm scores labeled Manual setting. Preserve failed diagnostic traces and original entered values; do not invent successful measurement evidence.

## Implementation and evidence

- Separate output-only taps and instrument measurement; default output = 0, no mandatory first step. Manual signed values can be applied without a successful measured pass. Total output specifications are normalized against reported device latency.
- Immutable output/instrument/manual provenance, explicit Apply, current-session instrument receipts, persisted values and exact configuration snapshots. Manual rhythm is explicitly approximate; legacy manual/estimated semantics and old histories remain unchanged.
- Two retained 4+16-beat timelines with every bounded event, signed deltas, missing/extra/wrong/uncertain markers and out-of-range details. Failed charts survive applying a manual estimate, cancellation and sheet reopen in the same session. Route/config changes identify stale context.
- Full Core suite: 185 tests passed. Full App suite: 112 tests / 31 suites passed. Subsequent five focused storage tests passed after the idempotent-output-reset review fix. Focused tests also cover default-zero/output-only, failure/cancel/overflow/timestamps, manual scoring without measurement evidence, invalid-audio/clock gates, historical round-trip and total-specification normalization.
- 719 EN/UK localization keys and placeholder validation, generated Xcode project, UI-test source typecheck, two author-tool tests and whitespace checks passed.
- Eight offline production timeline renders (EN/UK × light/dark × 600/940 points). Visually inspected Ukrainian narrow/light and English wide/dark, including missing, wrong, uncertain and duplicate events. These do not establish native keyboard/VoiceOver operation or real audio accuracy.
- [Same-agent review](../../docs/reviews/independent-latency-settings-review.md). Physical Scarlett/Bluetooth timing, live manual controls/focus/accessibility and the original first-pass failure remain in [user validation](../../docs/USER-VALIDATION.md). Native computer-use selection timed out; no live capture was started for this work.
- Local Release app and ZIP rebuilt with Xcode 27.0 / Swift 6.4 and ad-hoc signature; bundle/resources/13 bilingual lessons/archive verified: [bundle evidence](../../docs/benchmarks/independent-latency-release-bundle.json). No Debug app was created. The running app must be reopened to load the new executable.

2026-09-16 policy update: the later [manual latency controls task](latency-editor-layout.md) restricts newly applied output/instrument settings to 0–1000 ms, including additional corrections. Signed measurement traces and historical snapshots remain intact; prior signed-entry acceptance below describes the original implementation.
