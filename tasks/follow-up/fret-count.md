# Configurable fret count

Status: `done`

User request (2026-09-12): choose 19, 20, 21, 22 or 24 frets in Settings and apply this physical limit throughout the app.

Acceptance:
- One persisted instrument property; default/legacy value 24; open string is fret 0 and does not count as a physical fret.
- English and Ukrainian Settings; selection survives tuning, source, orientation and app reload.
- Fretboard, jump menu and keyboard navigation end at the selected fret.
- Lesson adaptation finds reachable fingerings while preserving target pitches; impossible lessons explain why they are unavailable. TAB, notation and preview share the adapted exercise.
- Practice validates the selected range, stops on a fret-count change and preserves original attempt evidence. Archived retries respect the currently selected physical guitar.
- History shows archived count; comparisons do not combine different counts. Existing snapshots read as 24 without being rewritten/regraded.
- Tuner open-string targets and audio grading capability remain unchanged.

Evidence: 210 tests in the final inventory (138 Core full-suite tests plus the final comparison regression with all 7 FeedbackTests rerun; 71 App tests), localization/project/UI-source checks, signed Release app/ZIP and native en/uk Settings and lesson-grid checks. See [same-agent review](../../docs/reviews/06-fret-count-review.md) and [bundle report](../../docs/benchmarks/06-fret-count-release.json). Hardware-dependent parent task statuses remain unchanged.
