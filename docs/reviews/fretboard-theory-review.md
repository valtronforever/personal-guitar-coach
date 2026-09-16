# Fretboard and musical fundamentals — local review

2026-09-17. Same-agent musical, content and integration review. Scope: eight substantive bilingual lessons, topics 41–48. Full course remains in progress; authored modules 1–6 cover 48 of 128 topics.

## Findings and decisions

- Note-name teaching explicitly follows fretPattern, preserving the physical chromatic steps while recomputing current names. Octave and interval lessons instead preserve sounding intervals. Independent expected pitches cover every preset and 19/20/21/22/24-fret neck, including the low-string octave reaching fret 19 in Drop.
- Unison is separated from octave: the former has identical full MIDI pitch, the latter differs by 12. Text and self-checks do not claim a sound score identifies the physical string. B–C/E–F semitone boundaries, sharp/flat equivalents and octave numbers are explained before recall tasks.
- Interval studies explicitly distinguish minor/major thirds, include same- and cross-string examples, and use independent source pitch arrays. Tonic/degree phrases preserve major-scale intervals and compare degree-2 versus degree-1 endings in the same register and context; subjective arrival is not automatically scored.
- Triad studies isolate the third (0–4–7 versus 0–3–7), provide separated-note grading and two ungraded complete voicings with true rests. The lowered-degree label is distinguished from literal flat spelling; chord quality is not reduced to a fixed emotional label.
- The transposition lesson moves every pitch up two semitones within unchanged instrument settings. Rhythm/contour stay intact. The original proposed stable ID transpose-a-melody was restored during editorial inventory review rather than introducing a duplicate curriculum identity.
- The tuning/shape lesson includes an explicitly labeled E Standard/Drop D worked comparison and actual interval-preserving practice for the user's selected tuning. It does not ask users to change Settings without retuning their guitar. Middle/upper fourths explain why one geometric pattern cannot be used across every string pair.
- The fretboard-map lesson uses existing author permissions directly: fixed Original, near-7 and near-12 activities, plus learner selection of Original and windows beginning at 0/5/7/12. Every variant preserves exact pitch and octave; the first note need not be at the window start. All five choices are feasible in the eight-preset × five-neck test matrix. Custom-tuning failures keep the existing explicit unavailable state.

## Verification

- All 58 bilingual bundles validate with no issues; 808 UI keys and generated project checks pass. Inventory: 48 authored, 4 needing review, 76 todo; acceptance remains pending.
- Three independent course tests check source pitch arrays, intervals, rhythmic lengths, true rests, practice eligibility, exact twelve-fret offsets and all five selectable regions across eight presets × five fret counts.
- All 88 Learning tests pass in 54.002 s and all 136 App tests pass explicitly serially in 133.105 s. With the unchanged 23 Persistence /38 Domain /80 Audio /5 AgentBridge suites from the preceding full run, 234 Core tests are covered. Signed local Release/archive validates 58 bundles/175 YAML resources (docs/benchmarks/fretboard-theory-release-bundle.json); the signed XPC invalid-request probe passes without invoking a provider. CI remains pending. Native reading/VoiceOver, real playing comfort, pitch/latency and educational effectiveness remain pending_user. No new DSP algorithm or input-quality claim is introduced by these content lessons.
