# Explicit eighth-note triplets and shuffle — local review

2026-09-17. Same-agent Domain/Learning/notation/content review. Scope: three eighth-note slots per quarter beat, 2:1 shuffle pairs and curriculum topics 65–66. Full curriculum remains in progress.

## Contract and findings

- Exercise.triplets declares ordered complete groups of two/three events. Each begins on a quarter beat, spans exactly 960 ticks and contains 320/640-tick events. Rests are supported. Duplicate/missing/out-of-order/overlapping IDs, ordinary 480+480 pairs, incomplete durations and off-beat groups are rejected. This intentionally bounded contract is not arbitrary tuplets or a global swing switch.
- Authoritative times remain the event ticks. The new optional collection is omitted when empty; old canonical encoding is preserved. Activity resolution retains groups and frozen results retain them. Event-scoped materials must include whole intersected groups and normalize from a quarter boundary. Visual steps may still select one note without cutting the source activity.
- Timeline indexes membership/bar ranges once. Written eighths and quarter/eighth shuffle pairs appear under explicit 3 brackets in TAB and staff. Rest breaks retain their group bracket without beaming across silence. Adjacent groups cannot beam into one another. Spoken descriptions include the triplet subdivision; no note/rest is inferred from a symbol.
- Offline review found adjacent staff brackets initially shared an endpoint. Added visible separation, retaining correct group spans and note membership. Compact TAB brackets needed clearance below existing accents; only exercises with triplets add 16 points to row height. Normal TAB reserves its own extra annotation space; non-triplet layouts remain unchanged.
- Two original bilingual lessons compare quarters/eighths/triplets and straight/shuffled eighths, then progress through repeated targets and melodic string changes. Final silent slots are explicit. The text distinguishes three ordinary quarters, equal triplets, the 2:1 shuffle target and dotted-eighth/sixteenth 3:1. It does not claim one swing ratio fits every style or infer physical picking technique from audio.
- The domain validator avoids building an event index for empty groups. No DSP, callback, storage migration, tempo scaling or additional capture pipeline was introduced.

## Verification

- Targeted domain, lesson and notation tests pass: invalid structures, JSON compatibility, exact-pitch/time adaptation across eight tunings × five fret counts, whole-group material normalization, quarter/eighth written values, rest/beaming behavior and count-in/zoom geometry.
- Four generated signal cases (triplets/shuffle ×44.1/48 kHz) traverse analyzer → collector → assessment. All 12/8 attacks match with no extras, pitch error <15 cents and timing error <40 ms; frozen assessment JSON round trips. Practice click samples are identical with/without notation metadata, and no clicks are inserted at third-beat positions. The test passes in 10.235 s.
- Eight offline images cover English/Ukrainian ×light/dark ×staff/compact TAB. One export from the full test process contained only brackets/cursor; an isolated rerender restored the staff. Added a sampled ink-coverage assertion to reject that partial export, then reran all eight exports successfully (0.522 s). Reviewed images in `docs/reviews/triplet-notation/` are byte-identical to the inspected complete rerenders. The cause of the earlier Canvas export artifact is not established; this does not prove or disprove native window/VoiceOver behavior.
- Content validates 69 bilingual bundles; inventory is 62 authored, 1 needing review, 65 todo. Generated project and 835 UI keys pass. All 142 App tests pass in 143.137 s; targeted render verification passes after its export-quality assertion. All 259 Core tests pass explicitly serially: 23 Persistence, 98 Learning (68.447 s), 40 Domain, 92 Audio (286.812 s), 6 AgentBridge. Signed Release/archive/XPC and exact-head CI are being finalized.

## Remaining acceptance

Real guitar/interface performance, learner comfort and native keyboard/VoiceOver/theme checks remain pending_user in USER-VALIDATION.md. Other meters, tuplet types and later curriculum topics are not claimed as delivered here.
