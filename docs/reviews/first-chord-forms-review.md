# First chord forms and harmonic root — local review

2026-09-16. Same-agent review, not independent. Scope: explicit author-controlled harmonic roots and original minor/major introductory chord lessons (topics 25–26). Not completion of the remaining chord/rhythm-guitar modules.

## Findings and fixes

- Fingering sorts positions by string number. Deriving `root` from the first voice labels an A minor shape as E minor, and relocating an inversion can change the apparent name. Added optional material `tonalRoot` in source pitch coordinates with interval-preserving/source-tuning validation. It transposes with the music and survives fret-region changes; it does not alter `first` or the notes themselves. Default absence preserves old decoding/rendering.
- Added three minor forms and three parallel minor/major comparisons, with explicit silent-string exclusions and suggested finger numbers. Separate named shape activities produce display-only chord references; note activities grade deliberately separated arpeggios. The text explains the mono input requirement and that successful individual pitches do not certify simultaneous chord clarity.
- Drop changes the lowest-string fret of the six-string forms. Existing adaptation intentionally removes invalidated finger suggestions; the lessons explain this instead of prescribing the old fingering. Four-/five-string forms remain alternatives while the learner develops the six-string shape.
- Independent tests compare each resolved chord to `{0,3,7}` or `{0,4,7}`, expected root-name goldens, string count/exclusions, practice eligibility and silence padding across all eight presets and five fret counts. They reject polyphonic shape grading and test shape-only and alternate-region root naming.

## Verification

- 38 bilingual bundles load; three new focused tests pass (root round-trip/validation, inversion/position independence, full chord matrix).
- All 77 Learning tests and 136 App tests pass. All 802 en/uk UI keys validate; generated project is current; partial 128-topic inventory passes with 26 authored, 6 needing review and 96 todo. Same-agent code and bilingual instructional review completed. Root-path Release/bundle checks and PR/CI/merge remain pending.
- Native English/Ukrainian reader/VoiceOver and real guitar chord comfort/clarity remain pending_user. No polyphonic recognition, measured finger identification or full course completion claimed.
