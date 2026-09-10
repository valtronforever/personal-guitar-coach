# Task 17 local review

Reviewed by the implementing agent; this is not an independent review.

## Scope and corrections

Reviewed monotonic assignment, normalized/sample-rounded timestamps, pitch and rhythm arithmetic, validity gates, bounded evidence, immutable historical records, save/retry ownership and bilingual summary UI.

- Assignment uses time and sequence with insertion/deletion costs, not pitch. Half-step/octave errors stay assigned to the intended temporal slot. The 1024-note/2048-attack boundary has deterministic tests; all eligible attacks must appear exactly once as matches or extras. Persisted targets must match canonical tuning positions, and assignment references must remain monotonic.
- Missing reliable signal is distinct from healthy silence. The collector now retains non-silent uncertainty intervals, with a combined 4096 interval limit and growing-span updates. Missing attacks intersecting sustained uncertain input cannot earn a misleading all-missed zero; reliable resolved attacks supersede normal settling, while clipping remains uncertain. Uncertain notes remain in the denominator and suspicious extras remain counted.
- Normalization and residual compensation are applied once. ±50-ms golden fixtures reach 100; missing/uncertain clocks and unmeasured calibration suppress timing/overall scores. Partial attempts suppress all aggregate grades. The raw per-event evidence is retained without diagnosing physical string/finger technique.
- A public guitar clip at 44.1 kHz exposed a transient octave in the first event-pitch window. Event analysis v2 now confirms five stable post-onset estimates and uses their median. The unchanged 300-ms timeout still bounds finalization. An attempted extra energy-rise condition for onsets was rejected after the full benchmark missed supported repeated notes; that onset change was removed. The final full 3,360-case benchmark passes all original musical/quality gates with the retained pitch change.
- Public recorded release tails contain uncertain additional detections without exhaustive human annotations. They are retained, and affected single-note attempts can be unscored. The recorded pipeline check validates the annotated first attack and records scored coverage; it does not claim all recordings are perfect or label every tail detection a proven player error.
- Detailed session schema 2 preserves all scoring inputs and parameters beside the compatible summary. Legacy schema 1 loads unchanged. Future/corrupt documents are preserved; retry cannot overwrite a conflicting saved attempt. Historical capability is stored and readable without applying current DSP limits; a new run explicitly validates current support.
- The application awaits evaluation and an atomic save before another automatic repeat. Write failure retains one pending attempt and stops repeats; a different attempt cannot overwrite it. Tests retry the exact attempt, verify no duplicates, reopen mixed legacy/current history and preserve an unknown future detail schema.
- History UI refresh uses a generation so older asynchronous reads cannot restore stale rows after a newer read/clear. Enum mappings fail by throwing rather than force-unwrapping a future mismatch.
- The summary accessibility identifier is attached to its heading, with separately identified validity and combined metric labels. This avoids parent identifiers propagating to every leaf. A Debug-only synthetic result window exercises valid, pitch-only, insufficient and interrupted presentation without audio or saved history.

## Evidence and outstanding checks

119 reported core tests pass (one opt-in hardware test skipped), including 9 assessment golden/boundary tests and the 32-clip annotated first-onset pipeline. App tests report 47 passing, including failure/retry and actual fake-practice → evaluator → repository handoff for two independent repetitions. These are software/fixture checks, not hardware capture.

421 en/uk keys, generated-project validation and Xcode UI-test source type-check pass. Native result-card observation could not be completed because the computer-use native pipe closed after the fixture menu action and remained unavailable after reconnection/reset. No native visual/accessibility success is claimed for the new card; U07 records this separately from the existing Xcode environment issue. Physical input/latency/musical checks remain U02/U03/U08/U10.

The final recorded pipeline matches all 32 annotated first attacks: 18 attempts graded, 14 unscored due to uncertain extras; two unannotated B3 clips are excluded from onset assessment. Exact metrics and per-clip results are in docs/benchmarks/17-assessment.md. The successful full DSP artifact is docs/benchmarks/17-audio-analysis.json.

Local Debug and Release .app builds and ad-hoc signing pass. UI-test source checks include the synthetic pitch-only/interrupted result flow; actual native execution remains deferred as described above.
