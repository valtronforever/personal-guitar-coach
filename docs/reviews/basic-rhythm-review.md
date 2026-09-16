# Basic rhythm course and accents — local review

2026-09-16. Same-agent review, not independent. Scope: complete authored content for topics 17–24, accent metadata/preview/notation, compatibility and regression checks. The other curriculum modules remain in progress.

## Findings and fixes

- Added six original bilingual lessons: eighths, rests/re-entry, slow sixteenths, accents, simple meters and an eight-bar study. Reviewed/expanded the existing pulse lesson without changing its musical version; dotted/tied notes are supplied by PR #66. Each new lesson has worked examples, explicit counts, progressive practice and specific self-review. The study is 30,720 ticks /eight 4/4 bars /25 attacks, with two four-bar phrases and a sustained ending.
- Sixteenths at a typical 100 BPM would fall below the verified 200 ms attack gate. This exercise explicitly uses 40–70 BPM (default 50). All newly authored exercises qualify at minimum/default/maximum tempo across eight presets and all five fret counts; reference pitch remains instrument-dependent.
- Merely explaining accents would leave preview unable to demonstrate them. Added optional `accented` attack metadata, visible/accessibility markers and a 1.5× reference amplitude. Normal/practice TAB and staff share the flag. A continuation of a tie does not repeat an accent; rest accents are invalid. Practice mode never plays the reference guitar tone. The lesson explicitly separates measured pitch/timing from self-assessed dynamic contrast.
- Kept accent markings clear of compact TAB note numbers/duration fractions by using the existing bottom space; staff marks remain above the staff with a clamped high-note position. Reviewed actual offline renders in [staff](basic-rhythm/staff-accents-light.png), [Ukrainian compact TAB](basic-rhythm/practice-accents-uk-light.png) and [English dark TAB](basic-rhythm/practice-accents-en-dark.png). These are not native VoiceOver evidence.
- Default-false accent encoding is omitted, preserving historic canonical JSON and AI digests. Activity/tuning adaptation retains both accent and sustain flags. Audio scores do not pretend to measure accent strength or pick direction.
- The initial full Core run reproduced the pre-existing SPSC test timeout: cooperative producer/consumer tasks were starved by simultaneous synchronous DSP fixtures (no sequence mismatch). Replaced the test workers with separate Dispatch queues, modeling actual independent capture/analysis threads. Retained both 10,000-item counts, ordering assertions and the five-second worker deadlines; no production ring code or confidence threshold changed. Full-suite repeat is recorded below.

## Verification

- App: **136 tests passed**, including independent rhythm-count goldens, 3/4 count/grouping, shifted accent positions and all preset/fret/tempo variants. Final two render tests passed with both languages/themes and compact/wide layouts.
- Core: **216 tests passed** in the final full run (23 Persistence, 74 Learning, 38 Domain, 76 Audio, 5 AgentBridge), including the concurrency test under simultaneous DSP load. Two focused accent tests also passed (44.1/48 kHz sample-for-sample amplitude ratio, unchanged frame timing, silent practice reference and legacy encoding/rest rejection).
- **36 bilingual lesson bundles**, **802 localized UI keys**, generated project current. Partial inventory: **24 authored, 6 needing review, 98 todo**. No claim of full-course acceptance.
- Release/artifact checks pending.

## Remaining validation

Real-guitar timing/cleanliness, audible accent contrast through the user's output, minimum-window keyboard/VoiceOver behavior and complete course acceptance remain pending_user. Dynamics is deliberately self-assessed; automatic grading still follows measured pitch/timing/opt-in sustain evidence.
