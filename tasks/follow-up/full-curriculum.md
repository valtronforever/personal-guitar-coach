# Full electric-guitar curriculum and library UX

Status: `in_progress`

## Authorized objective

Implement all 128 lessons from [the original agreed table](../../docs/CURRICULUM-SCOPE.md), including functional extensions needed to teach/practice them, and improve structure, presentation and filters. The scope is the full course, not a count of placeholder files. Every lesson needs original bilingual teaching, a specific worked example, progressive practice and relevant feedback/self-reflection. Existing history, tuning/fret adaptation, accessibility and honest assessment rules remain in force.

## Delivery and audit

1. **Curriculum/library foundation + modules 1–2** — authored; full acceptance audit pending. Stable 16-module organization, ordering, prerequisites/duration, reading progress, continue, combined search/filter/sort, lesson navigation. Preserve exact 128-topic inventory in a coverage ledger.
2. **Modules 3–6** — authored; native/hardware acceptance remains open. Rhythm/notation extensions (dotted/tied notes), chord/strumming examples, rock/metal rhythm, fretboard theory. No chord recognition claims from monophonic evidence.
3. **Modules 7–10** — in progress. Picking/synchronization, bends/returns, scales/positions and the complete advanced-rhythm module are authored with their software extensions. The harmony module is authored; slides/legato/vibrato still require implementation.
4. **Modules 11–14** — todo. Listen/reproduce tasks, guided improvisation; advanced guitar techniques and original genre studies. Add required functionality rather than silently reducing R lessons to generic checklists.
5. **Modules 15–16** — todo. Sound/recording and repertoire/composition workflow, original complete studies, self-practice recording support where required.
6. **Full acceptance audit** — todo. 128-topic mapping, bilingual/content/musical review, all presets/fret counts, functionality-specific DSP/notation/transport checks, library/filter/reader tests and rendered UX evidence, signed Release, review/PR/merge. Hardware-dependent proof stays explicitly pending_user and never becomes fabricated success.

## UX decisions

Use a grouped, ordered course library rather than a flat list of 128 cards. Let learners choose freely; prerequisites are guidance, not locks. Keep read state separate from assessed/self-reported mastery. Provide continue, visible active filters, clear-all, useful empty states and stable IDs across language changes. Search both localized names and musical keywords. Keep filter controls compact at the minimum window size.

Primary references: [Apple Searching](https://developer.apple.com/design/human-interface-guidelines/searching), [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [SwiftUI search placement](https://developer.apple.com/documentation/SwiftUI/Adding-a-search-interface-to-your-app). These inform placement/scannability; app-specific choices will be verified with rendered/interaction evidence.

## Progress log

- 2026-09-16: recovered the exact 128-lesson/16-module proposal from the current conversation. Baseline main 514ebaf; repository clean. Previous learning-mode implementation is complete software work, not completion of this new full-curriculum goal.
- Stage 1 authored: 16 introductory topics (13 new bundles, expanded posture lesson, existing two first-note studies); 23 visible lessons/29 total including historical aliases. Course metadata and UI/query implementation complete, software checks passed; see [same-agent review](../../docs/reviews/full-curriculum-stage-1-review.md). Coverage intentionally remains authored, with 7 later baseline topics needing editorial review and 105 todo. Partial inventory audit passes; full acceptance correctly fails. Native Ukrainian/dark filter/search verified; remaining reader/minimum-window/VoiceOver checks open after UI automation service failure.
- Stage 1 merged in PR #64 (3ebb81e). Low-register follow-up adds A1–B1 grading, fixes repeated low-note onset suppression, and enables graded Standard/Drop practice. See the [same-agent review](../../docs/reviews/low-register-practice-review.md); real-guitar validation stays pending. Full course remains in progress.

- Rhythm extension implemented: dotted/tied staff fragments retain one canonical attack; selected/resumed ranges include whole events. Opt-in sustained-note coverage has bounded trace evidence, honest uncertainty and versioned scoring. Topic 22 now has a substantive bilingual lesson with two practice entries. Software/release evidence: [local review](../../docs/reviews/rhythm-duration-review.md). Native/hardware checks remain pending; other module 3–6 topics remain open.

- Basic-rhythm continuation: six new bilingual lessons plus expanded pulse guidance complete authored topics 17–24. Added explicit accent notation/reference dynamics, conservative sixteenth tempos and original eight-bar study. See [same-agent review](../../docs/reviews/basic-rhythm-review.md). Inventory: 24 authored, 6 needing review, 98 todo; remaining modules and full acceptance stay open.

- Module 4 in progress: explicit material harmonic roots avoid naming a chord from its first voice; topics 25–26 now have reviewed minor/major forms, chord previews and separated-note practice. [Review/evidence](../../docs/reviews/first-chord-forms-review.md); 77 Learning /136 App tests and signed local Release checks pass; PR #68 merged after full CI.

- Strum extension and topic 28 authored: direction/spread metadata, ordered reference voices and accessible TAB arrows; skipped contacts extend the preceding chord. 39 bundles/27 authored topics. Core/App/content/render checks pass as detailed in [local review](../../docs/reviews/strum-reference-review.md); signed local Release passes; PR/CI pending.

- First accompaniment continuation: topics 27, 29, 31 and 32 authored; topic 30 arpeggio guidance expanded. All modules 1–4 now authored (32 topics), 43 total bundles/37 visible. Independent musical checks and editorial findings: [local review](../../docs/reviews/first-accompaniment-review.md). 43-bundle signed Release/XPC, 80 Learning tests and both parallel/explicit-serial 136-App-test runs pass. PR/CI and hardware acceptance remain open; modules 5–16 still require implementation.

- The strum and first-accompaniment changes are consolidated in PR #69. Explicit serial Core/App runs avoid unrelated fixture starvation without changing any deadlines or assertions; final CI is pending.

- Rock-rhythm foundation: optional author-selected open-string transposition anchor; topic 39 Drop riff authored and topic 33 power-chord lesson expanded with moved/octave forms, quiz and separated-note practice. 44 bundles/38 visible; 34 authored topics. [Review](../../docs/reviews/open-bass-anchor-review.md) records independent tuning/fret checks and a signed 44-bundle Release/XPC pass; CI and physical acceptance remain open.

- PR #69 merged as 0f79d54 after complete CI run 35153895995 passed (both Core/App suites explicitly serial, DSP regression, synthetic soak, signed bundle/XPC and CI builds).

- Rock-rhythm module continuation: topics 34–38 and 40 authored, completing authored modules 1–5 (40 topics). Added validated P.M. notation/reference metadata, display-only guard, decay-preserving seeking and English/Ukrainian accessibility. Total 50 bundles/44 visible. All 231 Core/136 App tests, content/localization/UI-source checks and signed Release/XPC pass; CI and physical acceptance remain open.

- Fretboard-theory module: topics 41–48 authored with distinct physical-pattern/interval policies, unison/octave and degree/triad/transposition examples, and fixed/learner fret-region activities. 58 bundles/52 visible, 48 authored topics. [Review](../../docs/reviews/fretboard-theory-review.md) records independent musical and instrument-matrix checks, all 88 Learning/136 App tests and a signed 58-bundle Release/XPC pass; CI and physical acceptance remain open.

- PR #70 merged as 8873e61 after full CI 35156066168 passed. PR #71 was reopened and retargeted to main after GitHub closed it on deletion of its former base branch; its current head is rebased onto the accepted open-bass implementation and awaits replacement CI.

- Lead-foundation introduction: single-note picking cues implemented and topics 49–50 authored. 60 bundles/54 visible, 50 authored topics; [same-agent review](../../docs/reviews/picking-directions-review.md) records cue, encoding, audio invariance and visual checks. All 237 Core/136 App tests, signed 60-bundle Release/XPC and content/localization/UI checks pass; PR/CI pending. Slides/legato/bends/vibrato still require their expressive analysis extensions.

- PRs #71–73 merged after exact-head CI runs 35157894822, 35159108366 and 35159113227 passed. Merge commits retained stack ancestry; main is 45861d5.

- Bend extension and topics 54–55 authored: timed half/whole-step pitch bends/returns, continuous reference, bounded moving-pitch evidence, phase assessment and retained diagnostic graph. 62 bundles/56 visible, 52 authored topics, 4 needing review, 72 todo. [Same-agent review](../../docs/reviews/bend-assessment-review.md) records 251 Core/138 App tests, final targeted reruns and a signed 62-bundle Release/XPC pass; CI and real-guitar acceptance remain pending. Topics 51–53/56 require their own slide/legato/vibrato extensions and are not relabeled as completed self-practice.

- Scale/position module continuation: topics 57–64 authored with five new lessons and substantive expansions of the three baseline studies. Full major/natural-minor and both pentatonic families, blues passing tones, neighboring-position routes, exact-pitch relocation and quarter-note sequences now have distinct practice plus quizzes/self-observation. Inventory: 67 bundles/61 visible, 60 authored topics, 1 needing review, 67 todo. See [same-agent review](../../docs/reviews/scale-position-course-review.md); 96 Learning /139 App tests, content/localization/UI checks and signed 67-bundle Release/archive/XPC pass; exact-head CI remains pending. Full curriculum and native/hardware acceptance remain open.

- PR #74 merged as 92715ee after exact-head CI run 35163893733 passed; the scale continuation PR #75 was retargeted to main without deleting its former base branch.

- Advanced-rhythm introduction: explicit complete eighth-triplet groups, conventional notation in both TABs/staff, preserved actual ticks and scoped-material validation; topics 65–66 authored with comparison, pulse and melodic examples. Inventory: 69 bundles/63 visible, 62 authored topics, 1 needing review, 65 todo. [Same-agent review](../../docs/reviews/triplet-notation-review.md) records software/render/synthetic-capture evidence; 259 Core /142 App tests and the signed 69-bundle Release/archive/XPC checks pass; exact-head CI remains pending. Full curriculum remains in progress.

- PR #75 merged as 00da753 after exact-head CI run 35164627711 passed. Triplet PR #76 was retargeted to main with its base branch retained.

- Rhythm-phrasing continuation: topics 67/69/70 authored with offbeat/held syncopation, ordinary/reverse gallop and displaced eighth-note groups. Existing sustain, pick-cue, accent and open-bass policies supply their distinct practice contracts. Inventory: 72 bundles/66 visible, 65 authored topics, 1 needing review, 62 todo. See [same-agent review](../../docs/reviews/rhythm-phrasing-course-review.md): 100 Learning /143 App tests and the signed 72-bundle Release/archive/XPC checks pass; exact-head CI is pending. Full curriculum remains in progress; native/hardware acceptance remains pending.

- PR #76 merged as d2250e2 after exact-head CI run 35166516387 passed; rhythm-phrasing PR #77 was retargeted to main.

- Metronome omission extension and topic 72 authored: explicit silent quarter clicks retain count-in, audio clock, all guitar targets and source-coordinate repeat behavior. Compact score markers and recorded reference reflect the same omissions. Inventory: 73 bundles/67 visible, 66 authored topics, 1 needing review, 61 todo. All 265 Core tests, 143 existing App tests plus nine targeted App/coach checks, content/localization/render checks and signed 73-bundle Release/archive/XPC pass; [same-agent review](../../docs/reviews/metronome-gaps-review.md) records evidence. Exact-head CI is pending; full curriculum and native/hardware acceptance remain open.

- PR #77 merged after exact-head CI run 35167647580 passed; metronome-gap PR #78 was retargeted to main without deleting its base branch.

- Compound/odd-meter extension and topics 68/71 authored: explicit dotted-quarter/eighth BPM, validated group accents, shared seconds conversion, correct signature/beams and named pulse in UI. All 269 Core /149 App tests, final targeted render/timeline/coach checks and the signed 75-bundle Release/archive/XPC checks pass; exact-head CI is pending. The advanced-rhythm module 65–72 is now authored. Inventory: 75 bundles/69 visible, 68 authored topics, 1 needing review, 59 todo. [Extension task](compound-odd-meter.md) and [same-agent review](../../docs/reviews/compound-odd-meter-review.md) track software/release evidence; full curriculum remains in progress and native/hardware acceptance remains open.

- PR #78 passed exact-head CI run 35168654409 and was merged. Its stable 73-bundle Release remains the local build while the compound/odd continuation is under validation.

- Full-barre harmony topics 73–74 authored: two major families, moved roots, two explicit major/minor comparisons and six separated-note practices. Inventory: 77 bundles/71 visible, 70 authored topics, 1 needing review, 57 todo. [Harmony delivery](movable-harmony-course.md) and [same-agent review](../../docs/reviews/movable-harmony-course-review.md) track verification; native/hardware acceptance, topics 75–80 and the full course remain open.

- PR #79 merged after exact-head CI 35170881942 passed on 27da78c; compound/odd-meter software is pending_user only for native/hardware acceptance. CAGED and inversion topics 75–76 are authored with explicit harmonic roots, a playable fragment distinct from the complete G note map, unique family/inversion labels and two transition phrases. Inventory: 79 bundles/73 visible, 72 authored topics, 1 needing review, 55 todo. [Review](../../docs/reviews/caged-triad-course-review.md); full curriculum and remaining harmony work stay in progress.

- PR #80 merged after exact-head CI 35171442048 passed on 7bc4e50. Harmony topics 77–80 are authored, completing the authored module: seventh qualities, function/voicing separation, wide/connected voice leading and progressive arpeggios. Inventory: 83 bundles/77 visible, 76 authored topics, 1 needing review, 51 todo. [Review](../../docs/reviews/harmony-progressions-course-review.md) records musical and delivery evidence. Full curriculum and actual hardware/native acceptance remain open.

Pitch-transition delivery is being packaged: topics 51–53 (`slides`, `hammer-ons`, `pull-offs`) now provide nine measured exercises with actual target timing and separate gesture self-observation. Total inventory is 79 authored /1 needs_review /48 todo (86 loaded bundles, 80 catalog-visible lessons). Core/App and targeted software checks pass; signed Release/CI/merge remain open for this delivery. Topic 56 vibrato and modules 11–16 remain required work; the overall objective is still in progress.

Vibrato topic 56 is authored with five progressive activities and width/rate/regularity assessment (follow-up in_progress; Release verified, CI/merge pending). Inventory: 80 authored / 1 needs_review / 47 todo. Modules 1–10 are authored; this does not establish hardware acceptance or completion of all 128 topics.

PR 84 merged after exact-head CI `35179866487` passed. Listen-and-repeat topics 81–84 are authored with 17 private guitar responses, shared reference/response musical time and frozen guidance conditions. Expanded interval lesson is version 2; listening filter includes both quiz stimuli and actual guitar responses. Inventory: 84 authored / 44 todo, 90 bundles / 84 visible. Targeted checks pass; full suites, signed Release and exact-head CI for this follow-up are in progress. [Task](listen-and-repeat.md), [same-agent review](../../docs/reviews/listen-and-repeat-review.md). Full curriculum and hardware acceptance remain open.

Listen-and-repeat local verification completed: 310 Core /167 App tests, final loader regressions, 90 bundles/888 localization keys and signed root-only Release/archive/XPC passed. Exact-head CI/merge pending; topics 85–128 and full acceptance remain required.

Topics 85–88 are authored: motifs, chord-tone landings, call/response slots and an eight-bar solo form. All 11 initial modules now have their eight topics authored; this is not full acceptance. Inventory: 88 authored /40 todo, 94 bundles /88 visible. A 2,120-resolution matrix and reference/notation checks pass; [task](improvisation-course.md) and [same-agent review](../../docs/reviews/improvisation-course-review.md) track full suites/Release/CI still in progress. Parent listen-and-repeat PR 85 is pending CI.

Improvisation local delivery verified: 127 Learning /169 App tests, 94 bundles/888 localization keys and signed root-only Release/archive/XPC pass. Exact-head CI/merge pending. Module 11 is authored; 40 advanced-technique/style/composition topics and full acceptance remain required.

PR 85 merged after exact-head CI. Legato-chain extension and topics 91/93 are being verified: 90 authored /38 todo, 96 bundles /90 visible. This adds multiple unpicked pitch targets, wider positioning search regions for tapping, notation, reference/contour assessment and explicit physical self-checks. No hardware/full-course acceptance is implied.
