# Task 03 — local review

Reviewed by the implementing agent on 2026-09-09; no independent review is claimed.

## Scope and findings

- Checked musical constants against the specified Standard / Drop D / D Standard string order, sounding MIDI octave convention, equal-temperament conversions, and ticks/BPM units.
- **Derived data could become a second source of truth:** removed Codable from ResolvedEvent. Only validated source events plus a tuning snapshot determine resolved pitches; derived events cannot be loaded independently with contradictory pitches.
- **Synthesized decoding can bypass validating initializers:** all externally decoded pitch, position, tuning, fingering, event, and exercise models use custom decoding that calls the validating initializer. Corrupt fret/MIDI/PPQ and missing/duplicate-string fixtures are rejected.
- **Integer/float edge cases could trap:** validate finite positive frequency and bounded reference, check end-tick overflow before addition, validate tempo bounds before constructing ranges, and reject non-finite/out-of-range seconds-to-ticks conversions before Int64 conversion. Log differences avoid an intermediate frequency-ratio overflow/underflow.
- **Learning previews and practice have different tuning requirements:** fixed-tuning previews correctly show the lesson's required pitches, while practice rejects a physically different tuning. Identical pitches in a renamed profile are accepted; A4 changes remain explicit.
- Verified muted and sounded strings are disjoint, open strings cannot carry a fretting-finger hint, rests create no expected pitches, chords remain displayable but cannot enter monophonic assessment, and duplicated/overlapping/out-of-order sequences are rejected.

## Validation

The musical-domain suite includes 15 MIDI boundary/reference round-trip cases, signed cents and octave errors, preset and equivalent-position checks, fret/mute/finger validation, meter/rest timing, tuning policies, chord modes, invalid/overflowing sequences, and corrupt serialized input. No hardware or UI is needed for these rules.

Final commands and counts are recorded in task 03 and the PR. Existing source-identifier and realtime-buffer tests remain part of the regression run. Runtime hardware gates belong to the existing final validation list and do not apply to completion of these pure domain rules.
