# Standard/drop presets — local review

Date: 2026-09-12. Same-agent review by the implementing agent; no independent review claimed.

## Scope and findings

- Added a single paired registry: E Standard / Drop D, D Standard / Drop C, C Standard / Drop B♭, B Standard / Drop A. Settings, Tuner, fretboard, practice and course adaptation consume the shared registry/model.
- Renaming the serialized Standard profile would invalidate old preferences because preset snapshots are compared exactly. Kept ID standard, name Standard and revision 1; changed only the English/Ukrainian UI labels to E Standard / Стандартний E. Existing presets are unchanged and the new ones are additive.
- Replaced tests that assumed only four presets with exact independent MIDI matrices, every-string/every-fret checks, all eight persisted selections and custom-profile preservation. All 48 lesson/preset combinations adapt; 37 produce supported practice snapshots, while 11 exercises containing pitches below C2 explicitly reject grading. The grading range is unchanged.
- Synthetic A1/55 Hz initially failed: estimator variation around the 55 Hz observation boundary produced outOfRange at 44.1 kHz or kept resetting qualification at 48 kHz. Analyzer version mono-mpm-flux-3 now accepts observations one semitone below the lowest target (approximately 51.913 Hz). Target limits remain 55–1500 Hz and grading remains C2–E6. No expected note/tuning enters the detector and measured frequencies are not altered.
- Regression verifies A1 at −75/−25/0/+25/+75 cents, flat/inTune/sharp feedback, measured cents within 1 cent, and rejection of 50 Hz, at both rates. Exact automatic harmonic-confirmation behavior remains checked for all five low presets; manually selected strings must qualify normally.
- Updated both analyzer version surfaces and benchmark version assertion. Historical evidence keeps its saved algorithm version.

## Executed checks

Using DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer:

- swift test --package-path Packages/GuitarCoachCore: 136 tests in 27 suites passed (55.971 s after boundary fix).
- swift test: 66 tests in 19 suites passed (81.126 s). Total 202 tests.
- After tightening harmonic-confirmation assertions: swift test --filter TunerModelTests, 6 tests passed (70.298 s; 10 profile/rate cases plus 2 boundary/rate cases).
- swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --quick --output /tmp/presets-audio-benchmark.json; python3 Scripts/check_audio_benchmark.py /tmp/presets-audio-benchmark.json --compact docs/benchmarks/06-standard-drop-audio.json: 360 cases passed, including recorded corpus and duration matrix.
- python3 Scripts/check_localizations.py: 510 en/uk keys passed.
- python3 Scripts/generate_project.py --check: passed.
- python3 Scripts/build_local.py --configuration release --archive: passed; 12 bilingual historical/source lesson resources, zero content issues.
- python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --archive build/release/PersonalGuitarCoach.zip --report docs/benchmarks/06-standard-drop-release.json: passed signature, entitlements, resources and archive parity.
- git diff --check: passed.

## Native Release verification

Launched the rebuilt app through macOS UI automation. Settings showed all eight English presets in paired order. Selected Drop A: strings 6 → 1 were A1/55.00 Hz, E2, A2, D3, F♯3, B3, with the existing explicit below-C2 grading notice. Switched to Ukrainian: all eight labels and open-string values rendered correctly, including Стандартний E/B and Drop B♭. Restored C Standard and System language; the open lesson remains A♭ major.

Synthetic PCM is not real instrument validation. No capture/preview was started. Physical low-string pitch/onset accuracy, approaching A1 from flat on the actual interface, calibration and full accessibility acceptance remain pending in USER-VALIDATION.md. Bundle report appLaunchVerified remains false because that script is structural; native evidence is above.
