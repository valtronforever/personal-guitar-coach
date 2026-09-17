# Listen and reproduce without target notation

Status: `in_progress`

Implement the required instrument-response workflow for curriculum topics 81–84: find a heard note, hear and reproduce an interval, repeat a rhythm, and reproduce a short melody without prepared TAB. Existing private listening quizzes cover recognition choices, but currently scored practice always reveals target fretboard/TAB. Do not replace these practical outcomes with generic self-confirmation.

Author an explicit opt-in practice presentation policy with validated private activity/material references. Preserve one resolved exercise for stimulus and response, tuning adaptation, musical time, historical provenance and old encoding when absent. Hide target positions, pitches and rhythmic heads across reading, practice, accessibility and selectors; neutral count-in/pulse feedback is allowed. Deliberate target reveal must mark the attempt as guided. Results may reveal the expected exercise for diagnosis. Reference playback completion means software completion, not proof that the user heard or understood it.

Use the existing coordinator/transport for a listen → prepare → practice sequence. Avoid capture/transport competition or treating reference playback as student input. Keep one-button recording/analysis for the actual response. Freeze reference/reveal conditions in the attempt and invalidate listening preparation when tuning, tempo or range changes. Tests must cover stale completion callbacks, replay/cancel/navigation, answer leaks, snapshots and real audio matching separately.

Provide substantive bilingual progressively harder examples for topics 81–84, using private quizzes where useful for recognition and real scored responses for reproduction. Validate every preset/fret count, localization/accessibility, synthetic evidence, same-agent review, root-only signed Release and exact-head CI/merge. Native hardware validation stays pending_user. No local Debug app.

Local implementation, full suites and signed Release checks are complete; exact-head CI/merge remain in progress. Topics 81–84 now contain 17 private instrument responses and separate recognition/self-observation tasks. Topic 82 is version 2. The library listening filter includes both recognition and reproduction. Inventory: 90 loaded bundles / 84 visible, 84 authored topics / 44 todo. See [same-agent review](../../docs/reviews/listen-and-repeat-review.md).

Parent vibrato PR 84 merged at `850d76574fbbae841fd1ed142ade524e98ed1d10` after exact-head CI `35179866487` passed; merge `78db84b1b5f70dc1897216d889f636cc2cf85287`. Hardware acceptance and the full 128-topic course remain open.

Local evidence: 310 Core / 167 App tests pass; final loader regressions pass; 90 bilingual bundles and 888 localization keys validate; signed root-only Release/archive/XPC checks pass. The review records exact logs, hashes and remaining native/hardware gates.
