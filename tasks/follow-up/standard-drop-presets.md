# Standard and drop tuning families

Status: `done`

User request (2026-09-12): offer E, D, C and B Standard, each with its corresponding drop tuning.

Strings below are ordered 6 → 1 (thickest → thinnest). Drop lowers string 6 by one whole tone from the paired Standard profile; strings 1–5 are unchanged.

| Standard | Strings | Drop | Strings |
| --- | --- | --- | --- |
| E Standard | E2 A2 D3 G3 B3 E4 | Drop D | D2 A2 D3 G3 B3 E4 |
| D Standard | D2 G2 C3 F3 A3 D4 | Drop C | C2 G2 C3 F3 A3 D4 |
| C Standard | C2 F2 B♭2 E♭3 G3 C4 | Drop B♭ | B♭1 F2 B♭2 E♭3 G3 C4 |
| B Standard | B1 E2 A2 D3 F♯3 B3 | Drop A | A1 E2 A2 D3 F♯3 B3 |

Acceptance: one shared eight-profile registry in paired order, localized names, persistence without changing old IDs/snapshots, tuner targets and automatic lesson adaptation for each profile. Preserve the existing C2–E6 grading gate: low-note exercises remain visible with explicit unsupported-pitch feedback. Do not broaden audio capability merely by adding a preset. Verify new low tuner targets with synthetic PCM; physical validation remains separate.

Boundary fix: exact A1/55 Hz oscillated out-of-range in PCM tests. Analyzer version 3 gives observations one semitone of margin below the lowest target (about 51.913 Hz); target and grading limits remain unchanged. New tests cover detuning in both directions and rejection below the observation range.

Evidence: 202 tests passed; final tuner regressions and 360-case audio benchmark passed; signed Release app/ZIP and en/uk native preset menus verified. See [same-agent review](../../docs/reviews/06-standard-drop-presets-review.md), [audio report](../../docs/benchmarks/06-standard-drop-audio.json), and [bundle report](../../docs/benchmarks/06-standard-drop-release.json). Hardware-dependent parent tasks retain their existing status.
