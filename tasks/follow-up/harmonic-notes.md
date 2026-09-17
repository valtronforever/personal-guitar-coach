# Harmonic note targets and lesson 94

Status: `in_progress`

Implement explicit natural and touched artificial harmonic metadata, with canonical sounding pitches/frequencies distinct from physical fret/node locations. Preserve all ordinary event encoding/math/history. Share semantics across tuning/adaptation, reachability, TAB/staff/fretboard/text, reference, assessment and frozen coach context. Natural nodes must not move as ordinary frets; artificial octave targets need both a stopped base and reachable touch node. No claim of detected hand technique, pinch gesture or harmonic timbre from pitch alone.

Author substantive bilingual lesson 94 with progressive natural partial and artificial octave practice plus physical self-checks. Verify model invariants, ideal multiplier math, wrong stopped-fret pitch, reference/assessment consistency, all presets/necks, notation/VoiceOver, persistence/coach and signed root-only Release. Exact-head CI/merge and hardware/native acceptance tracked honestly. No subagents or local Debug .app.

Current inventory before this extension: 102 authored/26 todo, 108 bundles/102 visible. Parent electric-tone delivery is being packaged. Overall curriculum remains in progress.

Implementation and same-agent review: [harmonic-notes-review](../../docs/reviews/harmonic-notes-review.md). 109 bilingual bundles/103 visible, 103 authored/25 todo. All 296 tuning/neck/activity/choice cases pass; final Domain 61, Learning 138 and App 180 tests pass. Root-only signed Release/archive and XPC boundary pass; exact-head CI/merge is still completing. Real guitar/native/VoiceOver gates remain pending.

Full Audio: 110 tests/37 suites, 513.522 s; Persistence 23/four suites, 0.058 s; AgentBridge six/one suite, 1.642 s. Initial full run failed only on two obsolete Domain boundary assertions; corrected Domain rerun passes. Native/hardware gates remain open.
