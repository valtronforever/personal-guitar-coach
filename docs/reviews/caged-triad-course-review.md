# CAGED and triad-inversion course review

Same-agent review; no independent reviewer used. Scope: topics 75–76, bilingual content, map/shape/practice semantics, library labels and independent musical/selection checks. No shared runtime changes or relaxed assessment constraints.

## Musical/content decisions

CAGED teaches one major harmony across C/A/G/E/D reference families. Families name source shapes, not separate concert-pitch chords. The C/A forms share the fifth-string root; G/E share the sixth-string root; E/D share the fourth-string octave root. The complete G-family map is a sequence of individual notes; its upper-four-string fragment supplies practical graded material. The root is explicitly C3 before preset transposition, including G-fragment (fifth in bass) and D-family (root an octave higher). Five graded entries cover the five regions, with low-to-high notes and release rests.

Triad inversions use [C4,E4,G4], [E4,G4,C5], [G4,C5,E5] on strings 3/2/1, with explicit C4 harmonic root throughout. The text distinguishes inversion/octave changes from repositioning exact pitches. Three shape checks lead to root→first→second→first and first→root→second→root four-bar phrases; every bar has three quarter attacks plus a quarter rest. Root/third/fifth as bass are taught separately from unchanged chord quality. Both lessons include worked explanations, specific quizzes with explanations and self-observations. Both are intermediate library entries.

## Findings/fixes

- Initial G-family full fingering could not resolve in Drop: its bass moved to fret 10 while inner voices stayed at fret 5, exceeding the existing four-fret simultaneous-grip span. The targeted test correctly reported regionUnplayable. Represented the complete orientation map as display-only sequential notes and retained the comfortable upper-four-string fingering for graded practice. Did not relax the grip solver, substitute octave pitches or claim the full shape was playable. Added selection coverage for all map markers, single-note focus and the practical fragment.
- Initial generated activity labels reused the same root/quality across every voicing. Added family/inversion qualifiers to every shape and string-check label in en/uk, plus a uniqueness assertion, so the practice chooser distinguishes them.
- The first full Learning/App runs were stopped after the targeted map failure was noticed; they are not acceptance evidence. Final runs follow the corrected map and selection test.

## Verification

Final results and signed root Release evidence follow below. Native/hardware/physical comfort checks remain pending in USER-VALIDATION.md; this delivery does not complete topics 77–80 or the 128-topic course.

- Corrected targeted CAGED/inversion run: 2 tests /1 suite pass (1.887 s).
- Final Learning run: 107 tests /31 suites pass (94.239 s), including all tuning/fret and unique-label assertions.
- Final App run: 150 tests /43 suites pass (157.983 s), including the new Drop-map→fragment flow (0.760 s), existing reader/tuning integration and whole-corpus notation checks.
- Final validator: 79 bilingual bundles, zero issues. Localization: 840 en/uk UI keys pass. Partial coverage: 72 authored, 1 needs_review, 55 todo; full acceptance remains incomplete.
- Four Python author-tool tests pass (8.217 s); project generation is current; UI test sources type-check. No native UI execution or hardware evidence claimed.
