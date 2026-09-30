# Task 13 local review — guitar tuner

Reviewed by the implementing agent, not an independent reviewer. Date: 2026-09-10.

## Scope and findings

- Reviewed tuner state transitions, actual/target frequency separation, tuning/A4 propagation, audio ownership, stale analysis, en/uk UI and tests.
- A UI timer can revisit one old reliable frame indefinitely. Fixed by qualifying with DSP stream time and expiring display after 200 ms without a new frame. Intervening bad quality spans and lost bounded-history prefixes reset qualification even when the latest frame is reliable. App regression tests cover each path.
- Median smoothing could preserve a green reading across the ±5-cent boundary. Only raw cents qualify/revoke confirmation; smoothing controls the pointer. Boundary-jitter tests cover this.
- Automatic nearest-note matching can mistake an open high E for a low E harmonic. Automatic targets near another open string’s harmonic/unison request explicit string selection. Manual low E with high E input remains +2400 cents; no physical-string claim is made.
- An output-only setup probe originally allowed non-setup capture to start alongside it. Coordinator rejects this ownership combination; regression verifies stop then tuner acquisition.
- Start/Stop inside scrolling content could be hidden during tuning. Pinned controls to bottom safe area. Added explicit labels, symbols and selection values; no color-only feedback.
- Static SwiftUI text may be exposed as a combined accessibility element. UI assertions use visible text predicates where appropriate; actual VoiceOver and Xcode UI-test execution remain final validation.

## Evidence

77 core tests in 13 suites pass; 34 app tests in 9 suites pass. Includes PCM sine → actual analyzer → tuner → silence integration. Localization validator passes 279 en/uk keys. UI-test sources type-check under Swift 6/macOS 14. Native Debug and Release builds/signing pass. Native dark UI inspected in English and Ukrainian, including synthetic in-tune and silence; no real input or permission was attempted. User language preference restored to System.

PR #35 passed GitHub CI run 34415291760 (4m25s) and merged as fa60d1b on 2026-09-10. U02/U05/U07/U08 remain open. No distribution or notarization.

## Upper-string indicator fix — 2026-09-30

Reviewed locally by the implementing agent; this is not an independent review.

- Traced `MonophonicAnalyzer → TunerModel → TunerTracker → TunerReadingView/TunerCentsMeter`. The Canvas draws a marker only for non-nil `indicatorCents`. The automatic ambiguity branch returned before calculating display cents, consistently hiding Standard B3/E4 despite reliable frequency updates.
- Moved ambiguity handling after the shared five-frame median calculation. Reliable ambiguous targets keep raw/smoothed cents, while `chooseString` still prevents in-tune qualification. No DSP frequency, capture callback, target selection, capability, persistence or assessment algorithm was changed.
- Checked qualification leakage and stale display: ambiguity clears `stableSince`, manual mode resets the tracker, unreliable signal clears readings, and the app retains its 200 ms expiry. Regression covers median behavior while ambiguous, silence/recovery and the full fresh 300 ms manual confirmation interval.
- Updated en/uk help to explain that the scale is relative to the suggested target. Numeric signed cents remain available as text; the pointer remains supplementary to that text.
- Reproduced the bug before the fix: both parameterized upper-string cases failed because `cents` was nil. After the fix, all 6 `TunerTrackerTests` pass, including detuning, harmonics/manual octave, invalid signal, timing gaps and tuning changes.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TunerModelTests`: all 7 tests pass. New sine PCM cases cover Standard strings 1/2 at −25/0/+25 cents and 44.1/48 kHz, plus expiry. Existing PCM tests now also assert a visible centered indicator on every string of C/B Standard and Drop C/B♭/A, in automatic and manual modes.
- `python3 Scripts/check_localizations.py`: passes all 951 en/uk UI keys and format placeholders. Native UI/VoiceOver and real-guitar acceptance are not claimed; the exact follow-up is recorded in USER-VALIDATION.md.
- `python3 Scripts/build_local.py --configuration release --archive` and `python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --archive build/release/PersonalGuitarCoach.zip`: pass. Local Release `.app`/ZIP rebuilt with ad-hoc signatures and 134 bilingual lessons validated; build artifacts remain ignored.
