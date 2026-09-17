# Slides and legato: implementation review

Same-agent review. Scope: optional authored slide/hammer-on/pull-off transitions, linked fret resolution, reference rendering, periodic-contour assessment, persistence, TAB/staff/result presentation, local-agent context and bilingual topics 51–53. Vibrato is a separate remaining extension. No subagents or independent reviewer used.

## Decisions and corrections

- One canonical event retains one picked attack. The destination is inferred from a signed interval on the same string; both endpoints participate in neck/region reachability. Slides require fretted endpoints and a travel interval; legato permits open endpoints and has one change tick. Invalid direction, overflow, timing and incompatible sustain/bend/chord/mute combinations are rejected. Resolved target pitch is validated in Domain.
- A narrow region initially demonstrated the key failure case: C4's starting fret could fit while D4's destination did not. Linked resolver tests reject that region and accept a six-fret region, retaining both endpoint pitches in all eight presets × five neck sizes. Whole-event scoping remains intact.
- Initial broad slide tolerance allowed an early direct jump to earn too much travel credit. Added explicit intermediate-semitone coverage for multi-fret slides and independent early/mid-jump fixtures. Both continuous and chromatic-step correct PCM pass; direct jumps, wrong direction and unchanged pitch receive low phase coverage. Single-fret slides have no intermediate-fret evidence; neither score proves a physical gesture.
- `BendEvaluator` omitted the exercise's pulse in its capability check although frame timing used it. Passed the actual pulse and tested independent half-pulse contours in all six meters with calibration applied once. Existing bend algorithms/results are not silently regraded.
- Preview uses an analytical phase integral from the source onset so seeking, chunking, count-in and loops preserve phase. Practice has no guitar reference tone. The existing periodic trace/collector is reused; no callback work, new capture pipeline or automatic raw recording was added.
- Result metadata is versioned separately from old ordinary/bend attempts. Internal flux remains archived, while scored extras exclude transition motion. Combined bend/transition weighting is per moving note, followed by existing sustain/extra rules. Unknown evidence withholds grades; known silence differs from unavailable signal. Recommendations identify measured phases without diagnosing finger strength or gesture.
- TAB places target frets at their actual time. Staff splits the pitch at target arrival and does not tie different pitches, duplicate the pick arrow or repeat the initial accent. Target accidentals are established correctly across barlines. Unsupported written grids remain explicit. Spoken descriptions on a later target segment use the target pitch/fret.
- Offline fixture review initially showed clipped left edges because the fixture placed an unscaled-width staff in a narrower stack. Fixed the fixture's scaled frame, then inspected English dark and Ukrainian light renders. This is image-render evidence, not a native interaction/VoiceOver test. The graph uses signed relative cents for descending changes.
- Lesson YAML initially omitted required positioning policy fields and used the Swift property name `defaultChoice` instead of serialized `default`. The content validator rejected both; corrected `preserve`, `allowOriginal` and the serialized key. Tests also caught optional-property and nested-macro mistakes in new test code; these were corrected without loosening expectations.

## Teaching contract

Each lesson contains a substantive bilingual explanation, three graded exercises, a technique quiz and self-observation criteria. Every pair starts with a fresh picked note, holds the final pitch, then rests on beat 4. Slides begin travel on beat 2 and arrive on beat 3; legato arrives on beat 2 and holds through beat 3. Fretted single-pair exercises offer original/7th/12th-fret regions; open-string examples retain the teaching position. Phrase examples deliberately vary direction or interval. The examples use clean monophonic signal, 40–60 BPM, and explicitly separate pitch evidence from the physical technique.

## Evidence so far

- Transition Domain: 3 tests pass (0.012 s); learning assessment/resolver/course: 6 tests pass (1.152 s). Musical goldens cover endpoint MIDI, note/rest timing, allowed regions, all eight presets × five neck sizes, two languages and archived exercise round trips.
- PCM/reference: 5 tests /2 suites pass (89.567 s), including 44.1/48 kHz, correct fretted/continuous slides, instant legato, low/high supported pitches, 0.4 s plateaus, descending/single-fret slides, wrong motion, silence/noise/clipping, chunk/seek/loop/count-in and all meters. These are synthetic fixtures, not guitar recordings.
- Initial notation/render run: 4 tests pass (0.387 s); subsequent fixture-only render correction passes. CoachAudioTests: 7 pass (2.400 s), including transition version/targets, separate excluded IDs, response-tamper rejection and ordinary/bend behavior. No AI provider was called.
- Content validator: 86 bilingual bundles, zero issues. Catalog audit: 79 authored /1 needs_review /48 todo. Localization: 857 UI keys, en/uk and placeholders pass. Generated project is current.
- Full-suite, signed root Release/archive, XPC and exact-head CI/merge evidence are still pending and must be recorded before delivery. Native audio, UI navigation, VoiceOver and real guitar acceptance remain open.

## Integration follow-up

The first complete App run exposed old catalog counts (83 total /77 visible), a staff assertion that assumed one pitch throughout every event, and a healthy-silence fixture that collected contours only for bends. Updated the exact inventory to 86/80, derived expected written pitches from authored change ticks/intervals, and supplied known-silence contours for transitions as well. Dedicated missing-contour tests still require insufficientSignal; the retry/history fixture now retains its intended healthy-silence semantics. The corrected full App run passes 155 tests /45 suites (166.734 s).

A final UI review found that Foundation localization in the new spoken description used Bundle.main instead of the user's in-app language. Pass the selected localization function explicitly. Five targeted notation/render tests pass (0.375 s), including en/uk target names and event-local beat coordinates. Re-inspected the corrected Ukrainian light render; signed descending axes and all labels are legible. Four Python author-tool tests pass (9.428 s); UI-test sources type-check. No native interaction or audio claim.

Complete core runs so far: Persistence 23 tests /4 suites (0.058 s), Learning 118 /35 (112.298 s), Domain 45 /14 (0.028 s) pass. The complete Audio run is still active. Additional mixed bend/transition/sustain weighting and capability/Drop-bass regression tests were added during review and are queued after it; do not count them as passed yet. Release packaging and CI remain pending.

Complete core verification finished successfully: 23 Persistence, 118 Learning, 45 Domain, 99 Audio and 6 AgentBridge tests (Audio 377.030 s, AgentBridge 1.769 s). Additional review regressions pass: four Learning tests /two suites (0.024 s) cover mixed bend/transition/sustain weighting and linked Drop-bass endpoints; four Domain tests (0.013 s) cover explicit pulse, minimum phase/travel rate and both frequency bounds. The mixed fixture independently expects bend=100, hammer-on=50, sustain=100 and overall=90. No failed assertions were suppressed. Release packaging remains the next gate.

## Signed root Release

Root-only Release/archive build passes. [Bundle audit](../benchmarks/pitch-transitions-release-bundle.json) confirms 86 lesson bundles /259 YAML files, both localizations, offline resources, arm64 macOS 14 minimum, ad-hoc signature, hardened runtime and expected sandbox entitlements. Binary SHA256: `a267f60182257e747f8b891adaad34d0780133fc48ef73becd250344167e40bd`; archive SHA256: `3a511f0bc3633a13a26c55076b05d1effbe40309c8734714536144a607bfe439`.

Signed sandbox→separate XPC→invalidRequest passes; no AI provider was called. No local Debug app was built. App launch/hardware remain unverified. Exact-head CI/merge is the remaining delivery gate; all other curriculum work remains active.
