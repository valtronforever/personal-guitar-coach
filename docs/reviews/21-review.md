# Task 21 local review

Same-agent review of the research protocol, acquisition/provenance, estimator and metric code, production monophonic baseline, artifacts, no-go ADR and conditional backlog. This is not independent musical annotation or an independent code review.

## Findings and fixes

1. Upstream downloads timed out; the accessible GuitarSet mirror states its own derived-label corrections. Pinned its revision, excluded all three known-error tracks, recorded WAV/note-list hashes and explicitly documented that source-ZIP equivalence was not verified. Acquisition now rejects any mismatch against the committed manifest and retries transient HTTP failures only twice.
2. The mirror's description calls chord labels manually verified, while upstream explains inference from notes/lead sheets. Used the note annotations to derive exact audible triads instead; did not adopt the mirror's stronger ground-truth claim. Human validation remains U06.
3. Overall note-set accuracy included single-note portions of comping. Added a separately reported polyphonic-only slice without removing any original rows or changing thresholds. Held-out exact sets fall from 36.1/34.4% overall to 22.4/20.4% on actual polyphonic frames.
4. A monophonic analyzer's rolling event list could lose early events on longer clips. The research CLI drains new IDs after each block and checks collected last ID against totalEvents, preserving the complete offline event stream. It never enables chord assessment.
5. Distortion applied after Python resampling would differ from the Swift baseline. Both now apply the same tanh formula to original-rate input before any Python downsampling; changed before recorded predictions were evaluated. The condition stays labeled derived acoustic distortion.
6. A low matched-onset p95 could hide excessive false detections. Report precision/recall and complete expected/detected/matched denominators beside timing error; note-group labels remain a proxy.
7. Basic Pitch references GuitarSet in its source configuration, so these player folds cannot automatically establish unseen-model evaluation. Recorded this data-overlap concern and left the candidate unmeasured/unintegrated. No model performance borrowed from publications.

## Validation

- Fixed twelve-recording acquisition succeeded, two recordings per player; 296.196 s unique recorded audio. Full clean/derived-distortion experiment passed; 121 development and 61 held-out eligible frames per condition, including 49 held-out polyphonic frames. Every prediction/confusion/reference and source hash is retained.
- Production Release BenchmarkChords compiled and processed all 24 conditions; total event IDs were retained. No app capture/permission occurred.
- Five Python research contract tests pass: identity/unknown, one-to-one timing, onset-group boundary, silence and metrics including unknown/abstention denominators. Seventy-four deterministic control cases executed.
- The frozen identity, note-set and strum criteria fail; no thresholds changed after inspecting held-out results. No-go ADR leaves production UI and scoring unchanged.
- Generated project/localizations/UI-source checks and final PR CI results are recorded with merge evidence. Real electric/amplifier/piezo/microphone corpus validation and human strum labels remain U06; this task is pending_user rather than falsely complete.
