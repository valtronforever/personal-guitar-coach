# Movable harmony: full-barre delivery review

Same-agent review; no independent reviewer was used. Scope: topics 73–74, their bilingual YAML, catalog/coverage entries and independent musical checks. No audio detector, scoring algorithm or shared runtime model changes in this delivery.

## Content and musical review

The major lesson teaches sixth-root and fifth-root forms, root location, complete-shape movement by two frets, individual-string diagnosis and short relaxed attempts. The minor lesson compares both major references with minor partners, identifies the changed third on string 3 or 2, and distinguishes changing quality from transposing a complete shape. Both contain a specific quiz with explanation and separate self-observations. Major reference shapes in the minor lesson are not graded practice entries.

Independent reference MIDI values: sixth-root major [45,52,57,61,64,69], moved major [47,54,59,63,66,71], fifth-root major [50,57,62,66,69]; minor variants [45,52,57,60,64,69], [50,57,62,65,69], moved minor [47,54,59,62,66,71]. Explicit roots remain the harmonic root rather than the first canonical chord voice. Eight shape activities are display-only; six practices contain one note per quarter at 40–90 BPM, followed by enough rest to complete two bars. Preset transpose offsets are [0,0,-2,-2,-4,-4,-5,-5]. Drop preserves these chord intervals by moving string 6 up two frets relative to the reference shape; stale finger numbers are cleared. All 19/20/21/22/24-fret choices contain these positions.

The text explicitly labels E/A as reference families, uses resolved root/position tokens in activities, and explains that Drop may alter the straight-barre fingering. The sound of separately played notes does not establish barre contact, physical comfort or a simultaneously clean chord. Those observations remain manual.

## Findings and corrections

- Initial author output omitted quiz explanations. The strict content validator rejected both bundles; added original en/uk explanations for transposition versus a changed third. The final 77-bundle validator reports zero issues.
- The new test initially inferred integer BPM literals and failed compilation; use Double test tempos as required by the existing API.
- Initial shape goldens assumed low-to-high ordering for chord snapshots. Canonical fingering snapshots intentionally order strings 1→6, while timed practice retains authored strings 6→1. Corrected the expected shape ordering explicitly; did not sort away the sequence assertion for practices.
- Updated the three existing fixed inventory assertions to 77 total /71 visible bundles. Historical lesson aliases remain included in the total and hidden from the course library.

## Verification

Final checks and Release evidence are recorded below after completion. Native reading, keyboard/VoiceOver, physical barre/Drop comfort and actual interface practice remain open in USER-VALIDATION.md. Topics 75–80 and the full 128-topic curriculum remain in progress.

- 105 Learning tests /30 suites pass (88.743 s), including the new full-barre goldens (0.939 s) and existing catalog/adaptation/authoring checks. No new algorithm tests were required because runtime code is unchanged.
- 149 App tests /42 suites pass (154.032 s), including automatic tuning, reader/practice integration and full-corpus notation.
- 77 bilingual bundles validate with zero issues; all 840 UI keys validate. Partial 128-topic inventory: 70 authored, 1 needs_review, 57 todo; not full-course acceptance.
- Four Python author-tool tests pass (7.869 s); generated project is current; UI test sources type-check. Native UI execution was not claimed.
