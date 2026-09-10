# ADR 004 — Deterministic monophonic assessment

Status: implemented software contract; real electric-interface/held-out validation remains U02/U03/U10.

## Assignment and timing

`AssessmentEngine` in Learning takes a closed immutable `PracticeEvidence`; it never reads PCM, current UI preferences or the expected fret while detecting a pitch. `AssessedPractice` in Domain preserves both the inputs and the resulting assignment/metrics. No physical string or finger is inferred from sound.

Parameter version `monophonic-assessment-1` freezes these values:

| Parameter | Value |
| --- | --- |
| Insertion / deletion cost | 1 / 1 |
| Match cost | absolute corrected time difference / candidate radius |
| Candidate radius | min(300 ms, 49% of the nearest neighboring expected attack interval); 300 ms for one note |
| Rhythm tolerance | min(100 ms, 45% of the shortest expected attack interval); 100 ms for one note |
| Pitch tolerance | 50 cents from the target frequency |
| Pitch / rhythm weight | 0.6 / 0.4 |
| Extra-attack penalty | 20 × extras / (expected + extras) |
| Uncertainty fraction | >20% of expected notes prevents grades |
| Detector onset uncertainty allowance | 30 ms, plus calibration uncertainty and measured clock drift |

A monotonic dynamic program assigns attacks one-to-one with two cost rows and a byte backtrace. At the configured maxima (1024 notes, 2048 attacks), the backtrace is about 2.1 MB. Matching never uses pitch. Exact ties prefer a match; remaining insertion/deletion ties prefer deletion. Input order is stable; time-ordered duplicate attacks still cannot satisfy two notes.

Expected event times use absolute rounded output sample frames and the actual render epoch. The input onset is already normalized once by the collector. Subtract the frozen calibration residual once to compare it with an expected time; positive error is late. The task 16 ±100-ms collection guards apply, so the wider matching window does not admit count-in events outside that guard. Onsets inside an explicit rest are extras, even if another note is nearby. Gaps have no expected onset; unmatched attacks in them are extras. Sustains do not require additional attacks; note-off duration is not graded.

The calibrated rhythm gate requires a matching measured profile, supported session duration, fresh clock evidence, and total calibration + onset + drift uncertainty no greater than half the tolerance. Manual/estimated/no profile permits pitch feedback only. Timing errors, rhythm score and overall score are nil when the gate is closed. Coarse temporal assignment still uses the normalized route and any explicit residual; accurate route setup matters even for pitch feedback.

## Quality and result semantics

Per-note pitch points are `max(0, 1 − abs(cents) / 50)` and rhythm points are `max(0, 1 − abs(timeError) / tolerance)`. All expected notes remain in the denominator. Missed and uncertain notes contribute zero. Overall is the rounded, clamped weighted 0–100 score less the extra penalty.

A matched unreliable attack is uncertain. Clipping overlapping the first 300 ms of the expected or matched attack (limited by the expected note's end) also makes that note uncertain. A missing onset with at least 100 ms of non-silent uncertain input in that window is uncertain, rather than an ordinary miss. The collector preserves bounded quiet/unstable/ambiguous/out-of-range/warming-up spans for this decision. A reliable resolved onset supersedes ordinary transient settling; clipping is never superseded. True silence does not populate uncertain spans.

Uncertain expected notes plus uncertain extra attacks, divided by expected-note count, determine the 20% gate. This deliberately retains suspicious extra attacks instead of hiding them. At or below 20%, uncertain notes stay zero in the denominator. Above it, all aggregate grades are unavailable. Counts, raw inputs and assignment evidence remain visible/stored. A missing onset can be both unassigned and uncertain: uncertainty is a quality flag, not another mutually exclusive matching outcome.

A completed, confirmed, healthy all-missed attempt is zero when rhythm is eligible; without calibration it has pitch zero and no overall. Failed preflight is insufficient signal. A paused, cancelled or interrupted attempt has no aggregate grades. Reliable per-event measurements can be retained for inspection without treating a partial attempt as a completed assessment. Recommendations must additionally check validity in task 18.

## Storage and application ownership

New session documents use outer schema 2, containing the compatible result-summary envelope 1 and an assessed-attempt envelope 1. The detailed payload includes lesson/version, exercise/version, tuning/reference A4/source, original capability version, selected bars/BPM, full route/calibration, render epoch, drift, analysis version, measured attacks/quality intervals, fixed scoring parameters, assignment and frozen scores. No raw audio is stored.

Session schema 1 remains readable with its original summary and no fabricated detailed evidence. Decoding checks identities, selected canonical targets, one-to-one monotonic references, all in-guard attacks accounted for, summary/detail agreement and finite bounded values. It does not rerun alignment or scoring. Historical configuration decoding does not apply today's DSP capability limits; a new run explicitly validates current capability. Unknown document/scoring versions and corrupt files are preserved and reported, not overwritten.

`AssessmentStore` evaluates on a detached worker and awaits the atomic repository save before automatic repetition proceeds. A failed save retains one bounded pending attempt, stops automatic repeats and requires retry before another attempt. Identical saves are idempotent. History refresh generations discard stale UI responses; the repository actor orders saves and clearing. Latest in-memory result and saved history are separate states.

## DSP refinement and validation limits

Task 17 changes the event-analysis version to `mono-mpm-flux-2`: event pitch needs five consecutive stable, reliable post-onset estimates and uses their median with minimum clarity. The original onset timestamp is retained and the 300-ms resolution timeout remains. The three-frame live display estimate remains separate. The change addresses an observed early octave error on one public 44.1-kHz guitar clip and reduces sensitivity to a single early window. Existing calibration routes contain the analysis version, so profiles from the earlier backend do not silently become valid for the new one.

An experimental extra energy-rise requirement for spectral-flux onsets was rejected after the full duration matrix missed supported repeated notes. The original onset detector remains. This correction is not a claim that every release transient or quiet attack is now classified perfectly.

The new recorded pipeline test uses the unchanged public Iowa clips, with silence padding to exercise count-in/finalization, and the independently estimated first-onset/frequency annotations. Two B3 files have no onset annotation and are excluded from onset assessment (they remain in the existing pitch benchmark). Secondary tail transients are not fully manually annotated. The test retains their uncertainty; it does not force every clip to receive a grade or call every transient a proven player mistake. The benchmark report records scored coverage and this limitation. These development recordings do not replace clean electric DI, microphone/piezo, human musical assessment or physical timing validation.
