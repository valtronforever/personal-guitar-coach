# C Standard preset and adapted course

Status: `done`
Related tasks: [06](../06-tuning-settings.md), [19](../19-starter-course.md), [22](../22-staff-advanced-notation.md).

User request (2026-09-11): the connected guitar is physically tuned to C Standard; add the preset everywhere and adapt the starter course so it can be practiced without retuning.

Acceptance:

- Shared built-in C Standard: strings 6 → 1, C2 F2 B♭2 E♭3 G3 C4, MIDI 36/41/46/51/55/60; A4 remains 440 Hz.
- Settings, tuner, fretboard, TAB/staff, preview, practice, saved results and retries use the correct shared target snapshot.
- Six separately identified bilingual variants retain the familiar fingerings with accurate sounding notes, A♭ major, F minor pentatonic and Cm. Original lessons/history remain compatible.
- Exact MIDI/frequency, persistence, fixed-tuning mismatch, staff spelling, synthetic PCM tuner and full lesson/result/retry checks pass; a signed local Release is available.
- Local review records actual defects, fixes and verification. Physical DI accuracy and full beginner/VoiceOver acceptance remain in the existing U02/U05/U10 gates.

Evidence: [same-agent review](../../docs/reviews/06-c-standard-review.md), [release report](../../docs/benchmarks/06-c-standard-release.json), 131 Core + 61 App tests, 12 bilingual lessons/zero content issues, native en/uk preset/step/staff/practice checks. Physical acceptance remains with the existing parent tasks.
