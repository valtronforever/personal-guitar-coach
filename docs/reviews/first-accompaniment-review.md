# First accompaniment course — local review in progress

2026-09-17. Same-agent editorial and code review. Scope: complete authored module 4 with chord changes, intended-string selection, small barre, and an original sixteen-bar verse/chorus study; expand the existing arpeggio teaching. Not completion of all 128 topics or hardware acceptance.

## Findings and decisions

- Changes distinguish a real silent preparation beat from uninterrupted quarter-note accompaniment. Four bars alternate the five-/four-string minor forms. No numeric chord-change success is inferred from monophonic input.
- String-selection examples distinguish an open string from a muted one. The deliberately added bass is a chord tone, so the text correctly describes a changed inversion/voicing, not an out-of-key error. Only the intended separated pitches have graded practice entries.
- Small barre is a physical technique: `fretPattern` preserves fret 5 and a shared index finger across two/three adjacent strings. It does not preserve a named chord by moving the fingers elsewhere. Reference shapes are display-only; six separated notes followed by two resting beats provide honest pitch practice, with the physical barre self-reported.
- The original song study has eight whole-bar verse attacks followed by 32 quarter attacks across eight chorus bars. The same two-bar chord route resolves to the opening minor at the end. Synthetic references keep the same tempo; chorus accents/density supply the contrast. There is no copyright song material or simultaneous-chord scoring claim.
- Expanded arpeggio guidance explains the top-note turn, final rest, targeted repeats and separation of scored notes from ungraded ringing arpeggios. Lesson version is now 3 for the expanded teaching; sounding targets, exercise versions and timing are unchanged. Historical results retain their frozen context. References to the top physical string were replaced by the highest target so alternative fret regions remain accurate.

## Verification

- All 43 bilingual bundles validate; partial curriculum audit has 32 authored, 5 needing review, 91 todo. Modules 1–4 are authored, with acceptance still pending.
- 80 Learning tests pass, including independent bass MIDI goldens, all chord intervals, exact section boundaries, bar lengths, string counts, single-finger barres and practice eligibility across eight tunings × five neck lengths.
- All 136 App tests pass. After the lesson-version update, all 80 Learning tests pass again and all 43 bundles validate. 807 UI keys and the generated project pass their checks. The explicit serial App run also passes all 136 tests in 123.065 seconds. Signed Release/archive and XPC checks pass in the original root path; report `docs/benchmarks/first-accompaniment-release-bundle.json` covers 43 bundles/130 YAML files. PR/CI remain pending. Native en/uk reader/VoiceOver and real instrument comfort/clarity remain pending_user.

A fresh attempt to inspect the native app via the computer-use service returned timeoutReached (-10005); no native window interaction was established, and no UI acceptance was inferred from the signed bundle checks.

Consolidated delivery in PR #69 together with strum support. Final explicit-serial Learning run: all 80 tests passed in 30.533 seconds. Together with the unchanged 23 Persistence /38 Domain /78 Audio /5 AgentBridge suites, 224 Core tests are covered; all 136 App tests also pass explicitly serially. Full consolidated CI remains required.
