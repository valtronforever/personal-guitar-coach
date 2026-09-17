# Compound and odd meter / tempo pulse

Status: `in_progress`

Part of the authorized full curriculum, topics 68 and 71. Add explicit meter/pulse semantics, not only additional time-signature labels. 3/4 and 4/4 retain their historical quarter-note BPM. 6/8 and 12/8 use dotted-quarter BPM; 5/4 uses quarter BPM; 7/8 uses eighth-note BPM and grouped emphasis. Music stays at PPQ 960; no duplicated per-note seconds.

Deliver numerator/denominator, pulse ticks/count, author-selected grouping where relevant, shared time conversions across transport/assessment/capabilities and saved conditions, correctly spaced/readable TAB/staff/count-in, and bilingual pulse labels. Preserve existing saved results and canonical defaults. Metronome omissions must be validated against the actual pulse grid and scoped without shifting their meaning. Calibration's separate probe clock stays unchanged.

Author substantive bilingual 6/8–12/8 comparison and 5/4–7/8 grouping lessons with progressive monophonic practice, quizzes and self-observation. Independently verify note ticks, pulse/group onsets, sample boundaries at multiple rates/tempos, seek/repeat/count-in, notation beams/durations and assessment timing. Include all tuning/fret combinations, rendered UI, local review and signed root Release; native/hardware evidence remains pending_user. Full curriculum remains in progress.

## Implementation decisions

- TimeSignature owns numerator/denominator and pulse ticks/count. Dotted-quarter meters have 1440 ticks per pulse; 7/8 has 480. Add optional Exercise grouping in pulse counts (5/4 defaults 3+2; 7/8 defaults 2+2+3), with positive groups summing to the bar. Defaults omit from JSON; explicit alternatives persist in snapshots.
- Add an explicit pulse parameter to musical time conversion, defaulting to the historical PPQ quarter. Thread through capability, practice duration, matching, sustain, bend evaluation/rendering and transport. Do not convert BPM through a hidden rate that can exceed its validation range.
- Group starts may accent clicks; 6/8 and 12/8 clicks follow dotted quarters, 7/8 follows eighths. Keep exact absolute tick-to-frame rounding, range-source identity and count-in semantics. The separately authored calibration protocol retains its own events.
- Staff prints numerator/denominator, beams three eighths per compound pulse and 2+2+3/other authored odd-meter groups. Long offbeat notation fragments use the relevant group boundary. These fragments never create attacks. TAB/cursor/follow cells and bend graph derive their coordinates from the pulse, with enough note spacing.
- Tempo-unit labels must be visible in preview, practice and saved results in both languages; AI context must interpret the frozen signature. Existing 3/4/4/4 attempts retain exact timing and prompt versions unless they use another new feature.


## Implemented and verified

TimeSignature pulse/group contracts, musical-time consumers, transport, notation, UI labels, coach version 4 and two bilingual lessons are implemented. The [same-agent review](../../docs/reviews/compound-odd-meter-review.md) records 269 Core /149 App tests, the final 13-test render/timeline/coach run, content and localization checks, independent sample/musical goldens and deferred native/hardware acceptance. The signed 75-bundle Release/archive and XPC checks pass, with hashes recorded in the review. Exact-head CI/merge remains open; hardware/native acceptance is deferred.
