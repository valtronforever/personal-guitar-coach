# Configurable fret count — local review

Date: 2026-09-12. Reviewer: the implementing agent (same-agent review, not independent).

Scope: instrument domain/persistence, Settings en/uk, all fretboard construction paths and keyboard/jump bounds, lesson adaptation, preview lifecycle, practice preflight/interruption/retry, historical conditions and comparisons.

Findings and fixes:
- Instrument reconstruction during tuning/source/orientation edits could revert geometry to the default. Every current-profile reconstruction now carries `frets`; an App test exercises every choice through each edit and repository reload.
- Filtering visible fret cells alone would leave unplayable targets in lessons and practice. The shared resolver now filters candidate fingerings, rejects impossible patterns, and practice independently checks the selected range. Regression: string 2/fret 24 in E Standard can move to string 1/fret 19 with the same MIDI 83; string 1/fret 24 is unavailable on a 19-fret guitar.
- Archived retries must not restore a historical 24-fret instrument over the current 19-fret guitar. Retry preserves current geometry and validates the selected fragment. Historical snapshots retain the original conditions.
- A count change with unchanged tuning/notes could evade request refresh and active-attempt interruption. Requests carry geometry; a simulated active session now stops with `changedInstrument`, keeps 24-fret evidence and resets to the new 19-fret request.
- An unavailable-range message inside collapsed practice options could hide the reason Start is disabled. It now appears next to practice status.
- Historical comparisons could mix physically different instruments. Compatibility now requires equal fret counts; round-trip and comparison regressions cover this.
- Test fixtures initially supplied a required tuning without the required fixed-tuning policy, and separately created unequal calibration UUIDs for a positive comparison. Corrected those fixture conditions; targeted retests passed. No production audio algorithm changed.

Verification:
- Core full suite: 138 tests / 27 suites, passed (56.172 s). Added final comparison test and reran all 7 FeedbackTests, passed; final inventory is 139 Core tests.
- App full suite: 71 tests / 20 suites, passed (79.025 s). Includes persistence for all five counts, v2→v3 migration without read-time rewrite, legacy default 24, invalid counts, both fretboard orientations, practice range limits, archived retry geometry, selection preservation and active-session interruption.
- Course matrix: 8 presets × 5 counts × 6 lessons (240 combinations) all produce reachable positions; separate high-fret fixtures cover remapping and impossible targets.
- Localization checker: 515 en/uk UI keys and placeholders passed. Generated Xcode project current; UI-test source typecheck passed. Twelve bilingual lesson resources validated.
- Release app/ZIP built locally, ad-hoc signed, sandbox/hardened runtime and bundled resources checked. [Bundle report](../benchmarks/06-fret-count-release.json).
- Native Release app launched and inspected through accessibility: English and Ukrainian Settings menus contain 19/20/21/22/24; choosing 19 updates the instrument summary and lesson grid from 150 to 120 note buttons, and jump menu ends at 19. Last fret's six positions exist. C Standard and the selected upper-half lesson step remain intact. Restored original System language and default 24 after checking. Settings preview construction shares the tested model; its disclosure was not successfully expanded by UI automation.

Limits: no real audio capture or hardware scoring was claimed. Native inspection covers the new setting/lesson-grid flow, not a complete VoiceOver/light/dark audit. Local SwiftPM and Release builder were used; Xcode Debug/Release app-target checks run in GitHub CI. Existing hardware-dependent parent tasks retain their pending_user status.
