# Design author-controlled lesson positioning

Status: `done`

Scope: design the lesson format and authoring workflow for opt-in positioning of a note, fragment, exercise, fingering or whole lesson; author-limited positions and guided teaching steps. This task delivers a reviewable specification and implementation backlog, not a runtime/schema rollout.

Acceptance: distinguish current behavior from proposed behavior; specify source reuse, permissions, available regions, context isolation, teaching/practice flow, unavailable states, localization, validation, history/version migration and concrete JSON examples. Link implementation tasks with acceptance criteria; validate example references and independent pitch feasibility against current source content.

Design delivered: [specification](../../docs/design/lesson-positioning/README.md), [guided activity example](../../docs/design/lesson-positioning/authoring-example.json), [other material policies](../../docs/design/lesson-positioning/material-examples.json), [160-case feasibility evidence](../../docs/design/lesson-positioning/example-checks.json) and [same-agent review](../../docs/reviews/10-lesson-design-review.md). Example syntax/references, locale placeholder parity and independent source-note feasibility were checked. The design artifacts predate implementation; runtime delivery is tracked below.

## Implementation delivery

LD01–LD04 are delivered atomically on `codex/lesson-activities` under the user amendment below. All current resources and consumers use schema 2; stage verification is recorded independently.

| ID | Task | Status | Dependencies |
| --- | --- | --- | --- |
| LD01 | Versioned author model and pure activity resolver | `done` | Design |
| LD02 | Contextual lesson reader, guided steps and preview | `pending_user` | LD01 |
| LD03 | Contextual practice, history and legacy migration | `pending_user` | LD01, LD02 |
| LD04 | Author tooling, course migration and acceptance | `pending_user` | LD01–LD03 |

### LD01 — Versioned author model and pure activity resolver

Add schema-2 materials, activities, source fingerings, explicit positioning policies and practice entries. Reject schema-1 lesson manifests before decoding their payload. Positioning defaults off for v2 and is independent of tuning adaptation policy. Resolve one note, contiguous fragment, exercise, shape and whole-lesson materials; support auto/list/range start choices and width 1–6. Distinguish malformed author data from instrument-specific unavailability. Normalize fragment exercises with source tick/event provenance. Validate before a lesson becomes visible.

Acceptance: E/D/C/B Standard and all four corresponding Drops × five neck sizes; independent C Standard major from 7 golden targets; Drop width-5 failure/width-6 feasibility; forbidden fixed/default choices, duplicates, unknown schemas, bad references, noncontiguous events, rest-only practice rejection, whole-material availability, simultaneous shapes and linked arpeggio consistency. Ordering catalog schema remains 1; migrated source lessons retain equivalent musical targets. Prototype material/context types stay in Learning; frozen runtime selection/provenance belongs in Domain without UI/audio imports.

### LD02 — Contextual lesson reader, guided steps and preview

Replace the reader's one mutable resolved lesson/position with explicit activity selection and per-activity immutable snapshots. Connect steps and the example card to their activity. Learner activities show permitted choices; fixed activities show authored instructions and no picker. Several steps sharing one activity share state; distinct activities using the same notes stay independent. Keep theory accessible when one activity is unavailable. Stop preview on activity/choice changes, including identical-pitch exercises. Add versioned bookmarks without an old lesson-API adapter.

Acceptance: note exploration → scale exploration → original guided example → fixed-7 example → return restores the independent choice and correct step; all text/fretboard/TAB/staff/preview targets agree. Changing tuning/neck retains an explicit invalid choice with recovery where permitted. Existing read marks and new activity bookmarks, language switching, source-text tokens, en/uk picker labels, keyboard/VoiceOver and light/dark layout covered. Native checks unavailable to automation remain explicitly pending_user.

### LD03 — Contextual practice, history and legacy migration

PracticeEntry replaces bare exercise ID for new lessons. Freeze activity/material/entry IDs, choice, full policy, resolver version, source mapping and actual resolved exercise/instrument in evidence. Preflight rejects selections outside author constraints and existing capability limits. Old attempts retain legacy width-5 semantics and remain readable without rerating. Each guided performance is a new attempt; stop/finish the previous one before changing context. Store manual position self-confirmation separately from audio pitch/timing evidence. Retry uses the snapshot, and comparison checks contextual compatibility.

Acceptance: single-note/partial-bar fragment practice, fixed original versus fixed 7, same exercise reused across activities, active-attempt interruption, metadata mismatch before audio, old history without new fields, legacy-position snapshots, changed/deleted author policy after save, retry after tuning/fret changes, source-event recommendation mapping and insufficient signal. No claim that audio proves use of the requested fret. No continuous mid-performance position changes in this task.

### LD04 — Author tooling, course migration and acceptance

Extend the scaffold and documented template after LD01–LD03 can consume them. Default opt-out; allow authors to configure material scope, auto/list/range, width, learner/fixed choices and ordered guided steps. Add a bounded author report listing available starts and failure reasons per activity/tuning/neck. Explicitly migrate existing three interval lessons to equivalent whole-lesson policies and keep physical lessons opted out. Add one original bilingual demonstration lesson using the same source material in several activities; do not duplicate a course per tuning. Use one current text edition and update content versions for new teaching sequences.

Acceptance: generated drafts load under schema 2, source IDs and locale maps match, illegal policies are diagnosed, schema-1 ordering catalogs load only schema-2 lesson manifests, published course choices remain equivalent after migration, and a author can create the documented note/exploration/original/fixed-7 sequence without adding Swift logic. Full Core/App tests, content validation, localization, bundle, Xcode builds and recorded same-agent review; real guitar/native pedagogy acceptance remains explicitly separated from mathematical feasibility.

Out of this implementation tranche: visual author editor, arbitrary scripting, generated scale library, key-changing transposition, octave substitution, continuous position-transition assessment, polyphonic scoring and extra instrument types.


## User amendment — one lesson API

The user explicitly removed the requirement to support the old lesson API. LD01–LD04 now migrate model, consumers, resources and scaffold to the sole new format in one coordinated feature PR; no schema-1 lesson adapter, old whole-lesson API, dual text editions or compatibility tests for those APIs are required. Historical practice evidence remains readable without regrading because it is a persistence contract, not a lesson API. This amendment supersedes contrary compatibility and separate-merge wording above. Keep the four implementation stages and acceptance coverage for all new behavior.


## Implementation evidence (atomic delivery)

All four stages are implemented in the sole schema-2 API. The statuses above describe the delivered feature after its coordinated PR merge; `pending_user` tracks only the explicitly deferred native/physical acceptance in U05/U07/U10. No old lesson decoder, whole-lesson compatibility facade or dual text edition remains. Saved practice evidence is preserved independently.

- [Same-agent implementation review](../../docs/reviews/10-lesson-activities-review.md), including concrete findings/fixes and repeat checks.
- Full Core: 157 tests / 32 suites; full App: 81 tests / 22 suites, both passed. Final metadata refinements: five Domain and eleven App tests passed.
- 13 bilingual lesson bundles validate; seven are visible in the library. 541 en/uk UI keys, generated project and UI source type-checks pass.
- Four scaffold modes load, four invalid CLI argument cases reject without writes; [actual runtime report](../../docs/design/lesson-positioning/runtime-availability.json) verifies 160 activity/instrument rows.
- Signed local Release and archive checks: [bundle evidence](../../docs/benchmarks/10-lesson-activities-bundle.json).
- Exact-head GitHub regression/native Debug/Release checks gate the feature PR merge. Native CUA timed out twice; real guitar, VoiceOver and full layout/pedagogy acceptance remain open, not inferred from tests.
