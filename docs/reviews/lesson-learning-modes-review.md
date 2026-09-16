# Lesson learning modes — local review

2026-09-16. Same-agent implementation review, not an independent review.

Reviewed manifest/localization validation, musical adaptation, reader/preview state, persisted task contexts, author scaffolds, migration and representative content. No new DSP or numerical assessment rules.

## Findings and corrections

1. Mandatory exercises/materials/activities/practice entries made theoretical and self-assessed lessons impossible. Schema 3 permits empty musical arrays while still validating every existing reference, nonempty source materials and monophonic graded entry. The new checklist/question lesson has no musical objects at all; the power chord is `displayOnly` and cannot produce a practice request/assessment.
2. The first listening prototype changed the preview model's metronome, loop and tone-volume preferences. Replaced it with per-transport overrides. A synthetic runtime regression verifies no count-in/click/loop, audible reference despite a previously muted tone, preserved normal-preview preferences and stopped transport on navigation.
3. Bookmark writes reconstruct the bookmark during visit/read toggles. Extended both paths to retain task responses; context equality prevents old content/tuning/fret/position responses from counting as current completion. Tests cover rapid navigation, restart, schema-1 read/no eager rewrite, schema-2 save, version changes and independent practice history.
4. A listening question could reveal its answer through the normal activity/diagram panel, and a fret-pattern adaptation could change its interval in a drop tuning. The reader hides those panels; the loader requires a dedicated text-only listening activity, one task, no graded entry/positioning, and interval-preserving adaptation. Negative tests reject invalid answers/references, malformed translations, template-token leaks and forbidden combinations. Authors still must avoid natural-language clues and assert a musically correct answer; arbitrary prose cannot be validated semantically.
5. Several existing course tests assumed every newly appended lesson belonged to the original graded six-lesson series or had activity ID `lesson`. Scoped those historical golden tests to the graded starter series, retained their counts/targets, updated complete-catalog counts, and added a separate all-eight-tunings/all-five-neck-sizes matrix for both new musical examples. Compared every pre-existing manifest against main: only `schemaVersion` changed; no musical data or content/exercise version changed.

## Verification

- Core: 191 tests passed (23 Persistence, 62 Learning, 35 Domain, 67 Audio, 4 AgentBridge).
- App: 119 tests passed, including theory/listening visibility, chord playback without grading, task persistence/context invalidation and output-only transport behavior.
- Python author YAML tests: 2 passed; each new scaffold mode also generated and loaded a bilingual temporary lesson in Learning tests.
- Generated project current; UI-test sources typecheck. The new native XCTest scenarios are not reported as executed.
- 740 en/uk UI keys and all 16 bilingual bundles validate.
- Four offline `NSHostingView` renders of actual `LessonTaskView` with native controls, 640-point width: unchecked/partial checklist, completed self-assessment, unanswered listening question and incorrect answer/explanation. Reviewed [English/light](lesson-learning-modes/learning-tasks-en-light.png), [English/dark](lesson-learning-modes/learning-tasks-en-dark.png), [Ukrainian/light](lesson-learning-modes/learning-tasks-uk-light.png) and [Ukrainian/dark](lesson-learning-modes/learning-tasks-uk-dark.png). Text wraps without overlap; checkmarks and feedback use symbols/text in addition to state styling. These offscreen renders are not a live app/VoiceOver test.
- [Signed Release bundle/archive](../benchmarks/lesson-learning-modes-release-bundle.json): 16 lesson directories, 49 YAML resources, both languages, ad-hoc signature, offline resources and archive verified. No local Debug .app was built or installed.

Remaining acceptance: interactive playback through a real output, keyboard/VoiceOver and physical self-practice are tracked in USER-VALIDATION. Fixed listening questions are an authoring foundation, not a randomized ear-training engine or recognition of guitar technique. Current monophonic assessment boundaries remain unchanged.
