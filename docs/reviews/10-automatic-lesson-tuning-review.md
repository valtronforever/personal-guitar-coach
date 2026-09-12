# Automatic lesson tuning — local review

Date: 2026-09-12. Same-agent review by the implementing Codex agent; not an independent review.

## Scope and findings

Reviewed tuning-to-lesson resolution, the six bilingual templates, chord/arpeggio consistency, reader/practice state, legacy navigation, persisted results/retries, and native Release behavior.

1. Separate preset copies left other tunings without an adapted course. Replaced the visible library with six canonical adaptive lessons. Retained twelve original resources for historical references.
2. Keeping every fret in Drop D changes musical intervals. Musical lessons now transpose by string 1 and compensate other strings. Independent golden assertions verify C Standard A♭ major, Drop D pentatonic frets 7/10 and Em sixth-string fret 2.
3. Resolving arpeggio notes separately from the chord could choose another voicing. Both now use the same shape mapping. Voices occupy distinct strings, preserve pitches, and obey a bounded four-fret span rule; changed shapes omit stale finger numbers.
4. Recursive template substitution could reinterpret braces in a custom tuning name. Rendering makes one pass, inserts values literally, and rejects unknown/malformed tokens. Missing translations and rest-only musical templates fail closed.
5. Failed adaptation could retain an old fretboard. Reader/practice show a localized unavailable state without a stale playable exercise; recovery to a supported tuning is tested.
6. Changing tuning must not rewrite an active attempt. The regression starts a synthetic attempt, changes the instrument, verifies interruption with the old exercise/configuration, and verifies a fresh request with physical confirmation cleared. Archived recommendation retries do not opt into adaptation.
7. Native review found a fixed C2 (6/0) explanation under Drop D. Added a string-6 note token to all twelve adaptive translations and asserted it for every preset/language. Rebuilt and relaunched Release: Drop D now says D2 (6/0). Corrected the English arpeggio article to “the … shape”.

## Executed verification

With DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer, Xcode 26.6 / Swift 6.3.3, arm64, macOS 26.6.2:

- swift test --package-path Packages/GuitarCoachCore: 135 tests / 27 suites passed (54.318 s).
- swift test: 65 tests / 19 suites passed (23.466 s). Total: 200 tests.
- After the final explanatory-token fix, swift test --package-path Packages/GuitarCoachCore --filter LessonAdaptationTests: all 4 tests passed (0.099 s).
- python3 Scripts/check_localizations.py: 506 en/uk keys covered.
- python3 Scripts/generate_project.py --check and python3 Scripts/check_ui_sources.py: passed.
- python3 Scripts/build_local.py --configuration release --archive: passed; content validator loaded 12 bilingual source lessons with zero issues. The visible catalog has 6 entries; the other 6 sources are historical.
- python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --configuration release --archive build/release/PersonalGuitarCoach.zip --report docs/benchmarks/10-automatic-tuning-release.json: passed signature, sandbox/audio entitlements, deployment target 14.0, both locales, lesson resources and ZIP parity.
- git diff --check: passed.

Tests include 24 synthetic assessed/saved/retried attempts (six lessons × four presets), custom nonuniform tuning and A4 442, impossible targets, exact pitches/intervals, versions, bookmark/range preservation, and history reload. These are software/synthetic evidence, not recordings from a USB interface.

## Native app evidence

Used Release through macOS UI automation, accessibility inspection and a screenshot:

- Library shows six entries; C Standard titles include A♭ major, F minor pentatonic and Cm.
- Selected the major scale upper-half step, changed C Standard → Drop D in Settings. Title, note sequence, step positions, fretboard and TAB changed to C major; the upper-half step stayed selected. TAB exposed G3/A3/B3/C4 at matching positions.
- Opened practice: Drop D and its open-string notes matched the lesson. Changed back to C Standard: request/title changed to A♭ major and physical tuning confirmation remained unchecked.
- Switched to Ukrainian: practice, lesson text, selected step and C Standard fretboard labels were consistent. Screenshot showed upper-half notes E♭3/F3/G3/A♭3 on the native fretboard.
- Relaunched the final bundle and rechecked the corrected Drop D explanation; restored C Standard and System language. The open lesson remains A♭ major with its upper-half step selected.

No capture or audible preview was started. Output routing is not selected, and Start/preview remain disabled. Hardware pitch/onset accuracy, calibration, physical comfort in nonuniform custom tunings, full VoiceOver and beginner acceptance remain open in USER-VALIDATION.md. The bundle JSON reports only structural checks (appLaunchVerified: false); native launch evidence is above. Chromatic note names are not full key-aware engraving; unsupported custom voicings are explicitly unavailable.
