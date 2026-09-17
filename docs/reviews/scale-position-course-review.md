# Scale and position module — local review

2026-09-17. Same-agent content, musical-contract and integration review. Scope: topics 57–64, five new bilingual lessons, three substantive baseline expansions and a broader scale-topic display label. Full 128-topic curriculum remains in progress.

## Content and implementation

- Major and natural-minor interval structures, both pentatonic families and the minor blues passing tone have distinct examples and questions. Natural minor compares parallel major/minor with one tonic (Ukrainian: однойменні), and major pentatonic contrasts major/minor thirds and sixth/minor seventh. The blue note is explicitly the pitch between degrees 4 and 5, including enharmonic ♭5/♯4 naming.
- The existing minor-pentatonic box spans beyond two octaves: the highest written note is a minor third, not a tonic. The revised teaching identifies all three tonics, twelve ascending/eleven descending attacks and the final quarter rest. Major-scale ascent/descent likewise preserves its fifteen attacks and terminal rest.
- Connecting positions authors a deliberate shared unison on 2/5 and 3/9, a picked route across neighboring regions and a tonic-return phrase. Sound-based assessment cannot establish the actual string/finger choice. These activities intentionally do not offer arbitrary relocation of the physical route being taught.
- The existing relocation lesson adds full preparation/comparison guidance, a question and self-observation. Its six-fret window keeps the near-seven activity available in all eight supplied tunings. A window is not a forced hand stretch. The original c-major five-fret window is unchanged: unavailable Drop choices remain unavailable rather than changing notes or silently extending the region.
- Three-/four-note sequences and diatonic thirds use explicit quarter-note ticks and group accents. Three-note grouping across 4/4 bar lines is explicitly distinguished from triplets. Dynamic accents remain listening/self-observation goals, not a new loudness score.
- The stable majorScale topic ID now displays Scales / Гами; both pentatonic families keep their separate topic. Module order, bilingual search and combined scored/quiz/self-practice availability are checked. No persistence-ID migration or DSP change is required.
- Baseline lesson versions advance (major/pentatonic 2→3; relocation 1→2). A parsed comparison against the parent confirms exercise IDs, versions, notes/timing, material definitions and position policies are identical. Historical music is not reinterpreted. New lessons use explicit harmonic roots and transposeIntervals.

## Findings corrected during review

- New standalone quiz/review steps in the two original whole-lesson activities were initially outside that activity's step scope. The existing all-step/adaptation checks exposed this (17 failures). Assigned those steps to the existing lesson activity; no assertion was weakened.
- The isolated YAML-parser fixture copied the expanded c-major prerequisite graph without its prerequisite lessons, causing 15 unrelated curriculum failures. It now clears only prerequisite metadata in that fixture, preserving the parser corruption/healthy-lesson assertions. Runtime prerequisite validation is unchanged.
- Corrected the written descending degree after the high minor third in the connecting phrase, and clarified that alternating the shared note produces four attacks total. Standardized the two baseline Ukrainian lessons to polite plural instructions and removed duplicate numeric title prefixes.
- Reformatted the eight lesson bundles with the repository YAML writer and asserted exact parsed-value equality. Paragraphs remain literal blocks; no anchors or music changes were introduced.

## Verification

- 67 bilingual bundles validate with zero issues; 61 visible lessons. Inventory audit passes with 60 authored, 1 needing review and 67 todo. This is partial inventory validation, not full-course educational acceptance.
- All 96 Learning tests pass in 62.467 s, including three new independent golden tests. The new matrix covers all eight tunings × five fret counts: exact pitch/octave sequences, shared physical positions, tempo eligibility, rests, fixed and learner fret windows, group accents and preserved historical exercise versions.
- Generated Xcode project, 834 bilingual UI keys, four Python author-tool tests and UI-source type-check pass. Native interaction is a separate check.
- All 139 App tests pass in 141.537 s, including ordered scale-module search/filter checks and the full bundled lesson → practice → saved result → retry flow. Signed local Release/archive validates 67 bundles /202 YAML files; report: `docs/benchmarks/scale-position-course-release-bundle.json`. Binary SHA256 `2f4ff283ec851aa5370d7733a2c3765b554690e732765f8da6468b70d88447c7`; archive SHA256 `c5ba18bd63fd798a86b345976212935f4b285a82efbbd3cf3805b31694e97d37`. Signed sandbox-to-separate-XPC invalid-request probe passes without any AI provider call. Native launch is not established by these checks. PR/exact-head CI remains pending. Parent bend implementation has its separate full-Core/DSP evidence; this stage changes content, topic display text and tests only.

## Open acceptance

Real-guitar comfort, physical routes, clean input, perceptual teaching quality, native reader/keyboard/VoiceOver and theme/minimum-window checks remain pending_user in USER-VALIDATION.md. No synthetic or code test establishes those results. Other curriculum modules and their required features remain open.
