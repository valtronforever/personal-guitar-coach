# Choose a lesson's fretboard position

Status: `pending_user`

User request: move a major-scale example near fret 7 while keeping the key. Confirmed policy: find another fingering near the selected fret; the first note need not be exactly on it. Keep sounding pitches including octaves; do not silently transpose to fit.

Acceptance: choose Original or a supported region of up to five frets for interval-based lessons; preserve notes, rhythm, lesson steps and actual tuning; update text, fretboard, TAB/staff, preview and practice together. Persist the lesson selection and freeze position metadata in attempts/retries; tuning/fret-count changes must preserve or explicitly reject the requested region. Physical-pattern lessons keep their teaching semantics. Validate all presets/fret counts, fret 7 golden targets and impossible regions, persistence/history and native en/uk UI if the automation bridge is available.


Implementation: optional Domain region, complete-lesson resolver/options, native en/uk picker, synchronized reader/preview/practice and immutable bookmark/attempt/retry metadata. Original remains available; physical-pattern lessons keep their teaching semantics. Software acceptance passes; native/hardware acceptance is explicitly deferred.

Evidence: [same-agent review](../../docs/reviews/10-position-review.md), [signed Release report](../../docs/benchmarks/10-position-release.json), [musical contract](../../docs/AUTOMATIC-LESSON-TUNING.md#choosing-a-fretboard-position-2026-09-12). Full Core 146 tests and App 76 tests passed; the final added preview regression plus existing preview test pass separately. 528 localized keys, generated project and UI-test source checks pass. GitHub CI checks the final full tree and Xcode Debug/Release before merge.

Remaining: [U05/U07 native position follow-up](../../docs/USER-VALIDATION.md). CUA returned the native-pipe-closed error; no native layout/interaction/VoiceOver or physical fret-location evidence is claimed. This pending acceptance does not block software merge under the user's existing deferral rule.
