# ADR 006 — Keep chord assessment disabled after feasibility study

Status: accepted for current implementation; physical research validation remains U06. Date: 2026-09-10. Scope: task 21. Evidence: [research report](../research/21-chords.md) and its pinned protocol/artifacts.

## Decision

Do not expose polyphonic scores, missing/extra chord-note advice, chord identity hints or strum grades in the production UI. Retain existing chord diagrams and monophonic arpeggio practice. The evaluated chroma and harmonic NNLS candidates fail the predeclared accuracy/coverage or unknown-handling requirements; strum proxies fail precision/recall. Small accepted subsets do not justify selecting a supported chord list. **Supported assessed simultaneous chords: none.**

This decision is specific to the evaluated baselines and evidence. It does not rule out future multipitch or ML methods. The research commands operate only on explicitly supplied local files; they are separate executables/scripts and cannot change saved app scores or acquire user audio.

## Separate observable contracts

- Identity describes audible pitch classes and a declared vocabulary; it is not proof of intended chord, inversion, complete voicing or correct string/finger usage.
- Missing/extra evidence requires reliable independent MIDI sets, validated multiplicity semantics and unknown handling. A missing estimator component is not automatically a player's omission. Identical pitches on different strings cannot be assigned by ordinary mixed audio alone.
- Strum rhythm requires independently labeled strokes, a policy for rakes/up/down strokes, timestamps and calibrated route uncertainty. Note onsets grouped within a fixed window are only a research proxy.

Future unknown/unsupported outcomes must remain unscored. Do not condition detection on the expected chord to make predictions appear correct. A new assessment capability/schema and algorithm version must coexist with immutable monophonic history; no silent regrading.

## Evidence and limits

Twelve real acoustic pickup recordings, eight development/four held-out by player, plus explicitly derived distortion and seventy-four synthetic controls. Held-out polyphonic exact-set accuracy is 22.4% clean / 20.4% derived distortion; known-identity recall for the conservative harmonic method is 33.3% / 27.8%. Actual monophonic processing cannot recover full chords. No class has sufficient independent support. See the report for every denominator, confusion matrix and excluded-transition sampling bias.

The GuitarSet mirror's CC-BY-4.0 provenance/changes are documented; source ZIP equivalence and independent human label validation are not claimed. Genuine distorted electric DI, acoustic-microphone/piezo conditions and native streaming measurements remain open. Dataset/model results from outside sources are not counted as local measurements.

## Future candidate and consequences

Basic Pitch's Apache-2.0 code and local model formats are an evaluation candidate only. Pin model/code/runtime hashes, preserve notices, audit data overlap (GuitarSet is referenced in its training configuration), and measure conversion equivalence, contextual delay and CPU/RSS before proposing integration. NumPy/SciPy stay research-only; the app gains no Python/ML dependency.

The [follow-up backlog](../../tasks/follow-up/chord-assessment.md) defines data collection, alternative model evaluation and conditional UI/assessment work. These are future proposals, not additional tasks silently activated by this ADR. U06 remains pending until the final user stage after task 22; the no-go decision is sufficient to keep MVP behavior honest meanwhile.
