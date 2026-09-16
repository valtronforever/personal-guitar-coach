# Lesson learning modes

Status: `pending_user`

## Scope

Extend the YAML lesson contract with optional step tasks: theory checklists, self-assessed instrument practice, and multiple-choice questions with optional generated audio examples. Keep the existing monophonic practice/assessment pipeline. Allow purely textual lessons and display-only practice without dummy graded exercises. Provide bilingual examples and authoring support, validated references/translations, and persisted task progress separate from reading and audio scores.

Preserve tuning/fret/position adaptation and historical assessments. Audio examples use the existing transport coordinator. Listening questions hide musical answers until answered. Self-report must never claim verified guitar technique. No new polyphonic/technique DSP or full curriculum production in this task.

## Acceptance

- Schema, loader, examples, UI and authoring documentation agree; malformed references and incomplete translations are rejected.
- Theory works without audio; self-practice can display/play chords without automatic grades; a listening question plays and checks an answer.
- Task progress survives navigation/restart; lesson and instrument changes cannot reuse stale instrument-task completion.
- English/Ukrainian, keyboard and accessibility labels; distinct self-report / question feedback / scored practice.
- Relevant Core/App/authoring checks, signed local Release, same-agent review and PR/merge evidence.
- Native listening/keyboard/VoiceOver and real guitar checks remain pending if unavailable locally.


## Implementation and evidence

- Schema 3: optional step-bound `learningTasks` (`checklist`, `selfPractice`, `quiz`), strict item/reference/translation checks, and optional hidden listening stimulus. Musical arrays may be empty. All 13 existing manifests migrate structurally without musical/content/exercise-version changes.
- Native reader, per-step task panels and library mode/topic labels; no diagram for pure theory/listening. Reuse the audio coordinator for output-only examples; no new capture pipeline. Existing scored practice remains monophonic.
- Reading envelope 2 with lazy schema-1 migration, retained reading/bookmarks, independent task responses and exact content/instrument/position contexts. No new numeric technique/audio scores.
- Three bilingual examples and four author scaffold modes. Catalog has 16 bundles / 10 visible lessons (six historical aliases stay hidden).
- Local checks (Xcode 27.0 / macOS SDK, deployment 14): **191 Core tests** (23 Persistence, 62 Learning, 35 Domain, 67 Audio, 4 AgentBridge), **119 App tests**, **2 Python YAML tests**, 740 localized UI keys; all passed. Generated project and UI-test source typecheck pass. 16 lesson bundles validate without issues. Tests use synthetic/offline audio, not a physical guitar session.
- Four offline native-control panel renders inspected at 640-point width, both languages/themes: [render evidence](../../docs/reviews/lesson-learning-modes). No clipped text/control overlap. Interactive XCTest scenarios added but not executed locally.
- Local ad-hoc signed Release app/archive passed [bundle verification](../../docs/benchmarks/lesson-learning-modes-release-bundle.json). Release binary SHA-256: `bbf507ecf98dda55495ddb96f2d10cacaab035d3fa32c5e02a1a8ad96225bc41`.
- [Same-agent review](../../docs/reviews/lesson-learning-modes-review.md); native listening/keyboard/VoiceOver and physical self-practice remain in [user validation](../../docs/USER-VALIDATION.md).
- GitHub validation and merge evidence will be recorded on the PR for this branch.
