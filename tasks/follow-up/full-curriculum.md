# Full electric-guitar curriculum and library UX

Status: `in_progress`

## Authorized objective

Implement all 128 lessons from [the original agreed table](../../docs/CURRICULUM-SCOPE.md), including functional extensions needed to teach/practice them, and improve structure, presentation and filters. The scope is the full course, not a count of placeholder files. Every lesson needs original bilingual teaching, a specific worked example, progressive practice and relevant feedback/self-reflection. Existing history, tuning/fret adaptation, accessibility and honest assessment rules remain in force.

## Delivery and audit

1. **Curriculum/library foundation + modules 1–2** — authored; full acceptance audit pending. Stable 16-module organization, ordering, prerequisites/duration, reading progress, continue, combined search/filter/sort, lesson navigation. Preserve exact 128-topic inventory in a coverage ledger.
2. **Modules 3–6** — in progress; all eight module-3 topics now authored. Rhythm/notation extensions (dotted/tied notes), chord/strumming examples, rock/metal rhythm, fretboard theory. No chord recognition claims from monophonic evidence.
3. **Modules 7–10** — todo. Articulation-aware lesson/notation and measurable pitch-contour practice for slides/legato/bends/vibrato; scales; compound/odd time, triplets/shuffle, missing clicks; harmony.
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
