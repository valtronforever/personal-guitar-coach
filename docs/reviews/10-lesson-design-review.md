# Author-controlled positioning design review

Date: 2026-09-12. Reviewer: the authoring agent (same-agent review). Scope: proposed lesson schema, source reuse, configurable permissions, guided steps, state/attempt isolation, validation and migration. No runtime code changed.

Findings addressed in the specification:
- A top-level movable flag cannot express one-note or fragment activities and two independent uses of a scale. Named materials define scope; activities define independent instances and steps reference them. Whole-lesson scope is still possible without hidden override precedence.
- A list of numbers is ambiguous between note frets and region starts. `allowedStarts` is explicitly a tagged auto/list/range union; window width is separate and all source pitches must fit. Original is an independent author permission.
- Using only the tuning adaptation policy as permission mixes two different concepts. V2 positioning is explicit, defaults off and applies after tuning-derived pitch resolution. V1 implicit behavior remains isolated in a legacy adapter.
- Two fixed guided activities sharing an exercise cannot be distinguished by practiceExerciseIDs or one lesson bookmark. New activity/practice-entry identities, per-activity state and frozen policy/source provenance make this explicit.
- A single-note activity does not automatically fit the current whole-source-bar practice path. The design derives a normalized fragment exercise with an allowed partial final bar and retains source tick/event mapping; no surrounding notes are silently added.
- A saved first-fret value is insufficient when policy width changes. New snapshots include the full policy and resolver version; legacy attempts retain width 5 and no history rerating occurs.
- Tone recognition cannot prove that the learner used the requested physical position. Manual confirmation, reading and audio evidence remain distinct; continuous transitions during one performance are explicitly outside the initial implementation tranche.
- New semantic fields in schema 1 could be ignored. The proposal uses schema 2 with a v1 adapter and diagnostics for misplaced v2 fields; production resources/templates remain unchanged until their reader is implemented.

Validation: example JSON parses; references were checked against the actual c-major-practice exercise, activities/materials/practice entries and ordered event subsets; en/uk activity IDs and template tokens match. Independent monophonic feasibility calculation covered 160 cases (eight tunings, five neck lengths, two window widths, two region starts), with compact evidence in docs/design/lesson-positioning/example-checks.json. Width 5 correctly excludes fret-7 major scale in Drop tunings; width 6 admits it without octave changes. No Swift build/test or native UI execution is claimed for this documentation-only task.

Remaining implementation is explicitly todo in LD01–LD04. The current app still uses whole-lesson positioning inferred from transposeIntervals; the proposed JSON cannot yet be loaded as a production lesson.
