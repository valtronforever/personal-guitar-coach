# Full curriculum, stage 1 — local review

2026-09-16. Same-agent review, not an independent review. Scope: course organization, query/navigation, author metadata/tool links, and the first 16 topics. The complete 128-topic objective remains in progress.

## Findings and fixes

- Historical musical golden tests selected every graded lesson and assumed the activity ID `lesson`. New lessons legitimately use `example`. Restricted the historical golden tests to their explicit six/twelve IDs, preserving their independently specified pitches and counts. General catalog-to-practice/history tests still cover every registered graded entry. Added separate golden targets for the five new scored studies across 8 presets × 5 fret counts, at each declared minimum/default/maximum tempo.
- Minimal YAML/task-validation fixtures copied real lessons without their new editorial module. Added the fixture module or deliberately removed placement before task mutation, so negative tests still exercise the intended failure rather than an unrelated missing module.
- Course placement needed its own validation: unique module order/global lesson ordinal, bilingual labels, bounded duration/keywords, existing prerequisite references, self-reference rejection and cycle detection. Added negative and standalone-template tests; optional lists decode to empty. A corrupt lesson cannot reserve global exercise IDs before its bilingual presentation validation passes.
- Read status and performance are different. Filter/continuation tests cover never-read, visited, read and stale-version records. Reading labels do not assert proficiency; self-practice does not create a numerical score. Updated the posture lesson to version 2 after changing teaching content, and verified old responses remain stored without satisfying the new version.
- Search works across English/Ukrainian regardless of interface language and combines all words with all selected filters. Added result/sort/group tests and explicit clear controls. Native inspection exposed an obsolete empty-state instruction mentioning only difficulty/topic; broadened both translations to all filters.
- Reader adds advisory prerequisite links, previous/next step, explicit course return and next available lesson. Module title is separate from the Course button, so the button does not misleadingly promise a module-specific destination. Tool links preserve the shared audio lifecycle and do not fabricate task completion.

## Content review

Authored topics 1–16: parts, seated/standing support, pick grip, signal chain, input gain, six-string tuning, standard/drop comparison, practice preparation, existing open-string/first-fret exercises, clear fretted tone, separate down/up strokes, adjacent-string crossing, deliberate note stopping, TAB reading and an original four-bar melody. New text exists in both languages with specific actions and observation criteria. Original musical examples are not transcriptions of copyrighted songs.

Checked string numbering (1 thin, 6 thick), actual concert pitches, standard/drop partner mapping, fixed-position versus interval-preserving adaptation, explicit physical retuning, gain versus listening level, rests and phrase lengths. The app can assess pitch/onset timing in the new graded studies; grip, stroke direction, muting/buzz and body position remain explicitly self-observed. Tuning uses the existing live tuner. The stopping-note lesson does not claim automatic offset detection.

Primary setup references consulted: [JustinGuitar guitar basics](https://www.justinguitar.com/modules/before-you-begin-guitar-basics), [Fender electric guitar anatomy](https://www.fender.com/articles/instruments/electric-guitar-101), [Focusrite instrument input troubleshooting](https://support.focusrite.com/hc/en-gb/articles/26461050960658-I-m-getting-little-or-no-signal-from-my-guitar-instrument-level-equipment). Teaching prose/examples are original. UI references are recorded in the task.

## Verification

- Core: 197 tests passed across the full run plus the final Learning rerun (23 Persistence, 68 Learning, 35 Domain, 67 Audio, 4 AgentBridge). No audio algorithm changed in this stage.
- App: 123 tests passed, including new query/reading/continuation/mode coverage and every bundled practice-to-history/retry flow.
- Python: 4 tests passed, including scope-drift/missing-delivery/false-completion failures. `check_curriculum.py` reports 16 authored, 7 needing review, 105 todo. `--complete` correctly fails; no full-course acceptance claim.
- 29 bilingual lesson bundles validate, including 23 visible lessons and 6 historical aliases. 785 UI keys validate in en/uk. Project generation current and XCTest sources typecheck.
- Live local Release: Ukrainian/dark library and filter panel inspected via native screenshots/accessibility. Module filter produced 8/23, combined listening filter produced 0/23, clear-all restored 23/23, and English search `first melody` in Ukrainian UI produced the single correct lesson. No capture or playback was started.
- On opening that lesson the external `SkyComputerUseService` closed its pipe; its diagnostic reports were generated while `PersonalGuitarCoach` remained running. Reset/retry did not restore the service. Reader interaction, minimum-window/light/English and VoiceOver acceptance therefore remain open. Offscreen whole-window render attempts contained missing composited layers and were rejected as visual evidence, not reported as passed.
- Signed local Release/archive verification: see `docs/benchmarks/full-curriculum-stage-1-release-bundle.json`. No local Debug .app was built or installed.

## Remaining scope

Full-course delivery is not done. Later modules need dotted/tied/tuplet/compound rhythm, articulation and contour evidence, listening/reproduction workflows and recording in self-practice. Existing low-register monophonic grading restrictions (below C2) still apply to old open-string studies in some low presets; tuner/visual adaptation is a separate capability. These are tracked in the full curriculum task, not hidden by a completed count. Real instrument, monitor route, learner ergonomics and remaining native accessibility checks need explicit hardware/user evidence.
