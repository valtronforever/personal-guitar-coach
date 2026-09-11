# C Standard preset and course — local review

Date: 2026-09-11. This is a same-agent review, not an independent review. Scope: shared tuning registry and persistence, every pitch label, fixed-tuning resolution, six bilingual content variants, staff notation, synthetic tuner/assessment and signed local Release.

## Findings and fixes

1. Adding only the preset would leave the six fixed-Standard lessons unplayable on the user's C Standard guitar. Added six independent lesson/exercise IDs at version 1, preserving fret positions and ticks while setting explicit C Standard snapshots. Original six resources are byte-for-byte unchanged. Independent musical goldens verify A♭ major, F minor pentatonic and Cm; original Standard and adapted C Standard practice reject the opposite physical profile.
2. Default sharp labels would show G♯/A♯/D♯ against the adapted flat-key teaching text. Added a derived shared spelling preference for C Standard/equivalent custom pitches, used in settings/editor, tuner, fretboard, TAB accessibility, practice, results and neutral staff notation. No serialized schema, pitch math, frequency or score changes. A♭ major staff goldens verify letter positions/accidentals and the guitar written octave; explicit G/F key choices retain their previous behavior.
3. The initial PCM test incorrectly expected automatic green tuning for every string. Existing harmonic protection correctly asks for manual confirmation for G3/C4 (potential low-C2 harmonics). Corrected the test to assert that behavior explicitly; manual mode must qualify every string. No DSP or safety thresholds were relaxed.
4. Native catalog review found the English article “an Cm”. Corrected it to “a Cm”, rebuilt the release, refreshed the native library and observed the corrected title. Reviewed every new en/uk step and all musical body text, retaining A4 = 440 rather than transposing the reference.
5. The first test compilation caught an incorrect `restoringPitches(of:)` label in the new test; corrected to the existing `from:` API. The subsequent complete App suite passed.

## Verification

Using `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

- `swift test --package-path Packages/GuitarCoachCore`: 131 tests / 26 suites passed; opt-in hardware probe skipped. Includes 48 deterministic perfect/all-missed course cases across 12 lessons and two rates.
- `swift test`: 61 tests / 18 suites passed. Includes 24 synthetic PCM cases (six open strings × two rates × manual/automatic), saved C Standard restoration, language identity, all twelve lesson → visuals → practice → result/history → recommendation retry flows and archived tuning identity.
- `swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons`: 12 bilingual lessons, zero issues.
- `python3 Scripts/check_localizations.py`: 504 UI keys, en/uk and placeholders passed. Generated Xcode project and UI-test source type-check passed.
- `python3 Scripts/build_local.py --configuration release --archive`: passed, rerun after the English article fix; packaged content validator reports 12 lessons/zero issues.
- `python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --archive build/release/PersonalGuitarCoach.zip --report docs/benchmarks/06-c-standard-release.json`: passed; resource parity, ad-hoc signature and ZIP verified. The automated report deliberately leaves launch/hardware flags false; actual bounded native observations follow separately.
- `git diff --check`: passed.

## Actual native Release observations

Launched the rebuilt Release through CUA. Selected C Standard in Tuner; strings 6 → 1 showed C2/F2/B♭2/E♭3/G3/C4. Manual string 6 displayed C2 / 65.41 Hz, waiting for input rather than fabricating a detected pitch. Existing audio UI showed Scarlett 2i2 USB / Channel 1; no capture was started and that channel's physical wiring was not established.

The library listed twelve lessons. In A♭ major, selecting the lower-half step highlighted string 5/fret 3 A♭2 and string 4/frets 0/2/3 B♭2/C3/D♭3. Staff showed written A♭3/B♭3/C4/D♭4, corresponding sounding pitches, all four selected and explicit flat accidentals under no key signature. The native dark screenshot showed readable staff/step layout.

Changed language from System to Ukrainian: Instrument settings retained “Стандартний C”, A4 440 and frequencies 65.41/87.31/116.54/155.56/196.00/261.63. The same lesson/step selection and staff notes survived in Ukrainian. Practice handoff showed the C Standard snapshot and correct string order without tuning mismatch; missing route/calibration/physical confirmation remained explicit and Start stayed disabled. Restored language to System and left appearance at System. Kept C Standard selected for the user's stated physical guitar tuning. Refreshed the rebuilt resources, verified “From a Cm shape…” and left the C Standard introduction open; its TAB exposed C2/string 6/fret 0, rest, C4/string 1/fret 0, rest.

## Limits

Native checks above are bounded interaction/layout/accessibility-tree observations, not a full VoiceOver or beginner walkthrough. Synthetic sine waves and event fixtures do not prove real guitar pitch/onset accuracy. No live capture, physical retuning, recorded attempt, loopback calibration, device parameter change or audible playback was performed. Existing hardware gates remain open in USER-VALIDATION.md; parent task 19 remains pending_user. Local Xcode installation limitations are unchanged; the PR's clean macOS CI checks Xcode Debug/Release.
