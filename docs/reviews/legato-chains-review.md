# Legato chains and tapping — same-agent review

Status: verification in progress. This review was performed by the implementing agent, not an independent reviewer.

## Scope and resulting behavior

One authored event can now contain 1–8 same-string hammer/pull/tap targets with one initial attack. The resolver checks every cumulative fret target, the worker reference preserves continuous phase, existing contour collection measures each stable plateau, and frozen results distinguish unknown, silent and incorrect pitch. TAB, staff, VoiceOver target descriptions, retained curves, feedback/retry and coach exchange carry the same event-local targets. Wider 1–12-fret search windows describe positioning regions, not an approved hand stretch; chord span rules remain unchanged. Topic 91 includes an explicit three-string crossing exercise; topic 93 progresses to nine notes from one initial pick.

## Findings and corrections

- Endpoint-only reachability would accept an intermediate tap outside the chosen region even when the phrase returned to its initial fret. Candidate filtering now checks all cumulative offsets, and final instrument/region guards check every target. Independent tests cover Drop bass adjustment, insufficient regions and all preset/neck combinations.
- The former six-fret region maximum could not express the tapping span. Domain regions/policies now permit 12 frets, with a new upper-bound rejection and documentation that search width does not establish physical reachability. A seven-fret region correctly rejects a seven-semitone excursion because both endpoints require eight fret positions.
- Moving the multi-string teaching example could collapse its separate chains onto the same string. That activity now disables relocation to preserve the intended crossing; the remaining five activities permit only playable choices. The original matrix assumption that every activity must expose a relocation was corrected accordingly, not by weakening pitch/fret checks.
- Staff pitch and accessibility previously used the single transition endpoint. They now derive every fragment's actual pitch offset from the base. Targets are not falsely tied to previous different pitches, while a sustained plateau crossing a barline remains tied. h/p/t links and durations have their own tick coordinates.
- Multiple target phases cannot use `kind` as a SwiftUI identity, because all later phases share `.target`. Chain results use stable phase indices and localized note numbers.
- Returning to zero cents would hide higher intermediate targets with the former curve bounds. Bounds/guide levels now include every authored target and observed pitch.
- Synthetic preflight evidence initially used an impossible completed/unconfirmed state; the fixture now uses preflightFailed/noTestSignal. A reference test initially requested 150,000 frames in one bounded call; it now uses the actual ≤48,000-frame worker contract while independent seek/phase checks cover later targets. These were test fixture errors, not accepted hardware evidence.
- Optional encoding omits absent chain fields; assessment decoding rejects mismatched offsets, phase counts, missing valid results and substituted algorithm versions. Motion observations remain in raw evidence, with explicit unscored IDs in coach requests; no physical gesture or provider-listening claim is inferred.

## Evidence recorded so far

- Domain: cumulative directions, exact boundaries, independent phase areas, canonical encoding, malformed decoding, event exclusivity, frequency/duration/region limits.
- Learning: independent five-note contours across every supported meter, +120 ms correction plus +70 ms actual lateness, skipped/late/silent/unknown/unconfirmed/interrupted distinctions, frozen snapshots and feedback. Full course matrix validates both lessons across all eight presets/five neck lengths/available regions and BPM 40/60/90; three-string activity stays fixed.
- Synthetic PCM through MonophonicAnalyzer/PracticeEvidenceCollector: 44.1/48 kHz, initial G3 through E5, 0.4-second plateaus, one/two cycles, wrong/skipped/missing-middle/silent/noisy/clipped input. All 3 tests (two parameter cases) passed in 33.113 s; `/tmp/legato-audio-learning.log`. No physical guitar capture.
- Reference numerical/chunk/seek/loop/meter checks passed in 2.014 s after correcting test call size; `/tmp/legato-resolver-reference.log` (the old region fixture failure in that log was fixed in the later full suite).
- Full App suite: 171 tests/51 suites, 202.235 s, `/tmp/legato-app-full.log`. Additional coach provenance/rejection and offline render tests: 2 tests/2 suites, 0.803 s, `/tmp/legato-visual-coach.log`.
- Offline render fixture at 800 points generated all en/uk × light/dark views under `/tmp/legato-visuals`; inspected Ukrainian light and English dark. Nine targets, barline continuation, h/p/t marks, staff pitches and the returning curve are visible. ImageRenderer output is not native interaction/hardware validation.
- 900 en/uk localization keys, 96 bilingual bundles, generated project and UI-source type-check pass. Four Python checks pass in 11.073 s (`/tmp/legato-python.log`).

Full Core run, final mixed-technique test, signed root-only Release/archive/XPC and exact-head GitHub CI/merge remain to be recorded. Native interaction, real guitar, physical gesture checking and provider execution remain pending_user in USER-VALIDATION.
