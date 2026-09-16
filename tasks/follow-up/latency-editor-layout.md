# Manual latency controls and nonnegative settings

Status: `done`

Improve both manual editors with a label above the numeric field, localized unit, short Apply action and example. Per the user's explicit follow-up, both settings, including additional corrections, accept only 0–1000 ms; combined compensation must not exceed 1000 ms.

Implemented in the shared ManualDelayField, preserving native editing, initial-focus behavior and full accessible action context. Invalid entries show an inline explanation. Model/store guards also reject negative settings, and total-specification subtraction must not produce a negative correction. Negative measured candidates retain diagnostic timelines but cannot Apply.

Previously stored signed evidence remains readable and unchanged. Negative output settings are inactive with an explicit zero-fallback notice; negative instrument settings cannot enable scoring. Users can reset or replace them. New selection policy does not rewrite historical snapshots, scores or schemas.

Validation: 4 relevant Domain tests and 13 App tests passed, covering parsing, boundaries, direct calls, signed legacy records, preserved negative measurement traces and positive flows. Production control renders cover EN/UK and light/dark; final Release app/ZIP signature/resources/archive verification passed (724 localized keys); evidence is linked below. Native selection timed out, so keyboard/VoiceOver and real timing acceptance remain open in USER-VALIDATION.

Evidence: [same-agent review](../../docs/reviews/latency-editor-layout-review.md), [Release verification](../../docs/benchmarks/latency-editor-release-bundle.json). Local preview PNGs live in build/visual-validation and are not committed.
