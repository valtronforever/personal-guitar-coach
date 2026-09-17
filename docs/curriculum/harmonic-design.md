# Harmonic targets: implementation decisions (topic 94)

Implemented on `codex/harmonic-notes`; software verification is in progress. This document records the design rationale; the authoring contract and tests define the current bounded implementation.

Represent optional bounded harmonic metadata in MusicalEvent. Natural: physical touch position near frets12/7/5, partial2/3/4. Artificial introduction: fretted base and octave touch twelve frets above it; physical base and touch have distinct roles. Do not reuse ordinary fret->pitch for natural fret7 (its harmonic is open+19, not open+7). Do not claim pinch-harmonic detection; teach intentional touched octave artificial harmonics first, with separate gesture self-check.

Centralize event sounding pitches and exact target/reference frequencies in Domain. Nearest MIDI labels for partial3 (+19) differ by ~1.96 cents from ideal open frequency×3. Reference/assessment should share exact multiplier rather than incorrectly treating a natural harmonic as a stopped note. Preserve old ordinary-note encoding/math and no history regrading. Validate mutually exclusive note types, supported nodes, string counts, no rests/chords/moving-technique ambiguity; enforce physical touch reachability. Harmonic sound does not identify physical production technique.

Actual direct-position sounding consumers found:
- Domain/Exercise.swift resolvedEvents
- Domain/Assessment.swift target frequency structural validation line169
- Learning/AssessmentEngine.swift frequencies line15
- Audio/TransportPlan.swift frequency cache line72 (outside callback)
- Learning/ActivityTextRenderer.swift sequence/notes and scoped position strings
- Learning/LessonActivity.swift visual highlighted positions
- App/CoachExchange.swift expected note description line93
- App/ResultDetailView.swift expected note display line187
- App/AssessmentFixtureView.swift synthetic frequency line32
Tuner/calibration fret0 remain ordinary pitch and should not be changed. Transition/chain code retains ordinary semantics because harmonic combinations will initially be forbidden.

Natural nodes must not silently move under pitch-preserving transposition/relocation. A physical-pattern lesson can retain nodes and derive sound from each tuned open string (including Drop's lower sixth); no invented key-preservation claim. For transposeIntervals activities either validate the unchanged natural node reaches the intended target or explicitly report unavailable. Artificial base relocation can use +12 linked reachability, with both positions inside the instrument/allowed region. Fingering-only materials that drop event metadata must reject harmonic projections unless explicitly supported. Default lesson examples can disable relocation, but engine must not silently lose metadata when authors request it.

FretboardModel currently receives only ordinary positions and independently computes tuning.pitch. Add explicit touch/stop roles and sounding labels through snapshots, selection, preview and practice board. Touch indicators need a distinct symbol/VoiceOver label (not merely a filled stopped fret circle). TAB: angle-bracket node for natural and base plus touched-node cue for artificial. Staff: sounding MIDI, diamond head/explicit harmonic cue. Timeline keeps actual single attack/sustain ticks. Expected reference remains synthetic; no real timbre or gesture claim.

Assessment can reuse monophonic frequency/onset matching but needs tests for ideal multipliers, wrong stopped-fret pitch, octave/subharmonic confusion, unknown/silent evidence, history/coach provenance, same expected reference/feedback. Selected attempts opt into `mono-capability-7` and `monophonic-assessment-8`; the underlying detector remains `mono-mpm-flux-4`. Bounded callback pipeline remains unchanged.

Read/validate official primary acoustics notes: https://phys.unsw.edu.au/jw/strings.html ; https://phys.unsw.edu.au/jw/musFAQ.html ; https://newt.phys.unsw.edu.au/jw/harmonics.html . Nodes are approximate physical fret landmarks; real string stiffness/intonation can move the optimal touch point. No text copied.
