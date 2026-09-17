# Improvisation course — same-agent review

Status: local software/Release checks passed; exact-head CI/merge pending. This is a same-agent content/software review, not an independent review or hardware acceptance.

Scope: curriculum 85–88, completing the authored ear/improvisation module. Four substantive bilingual lessons use existing reference playback, explicit rests, notation, tuning/region resolution and learning tasks. Only three fixed chord-tone exercises are graded; original motifs, answers and solo choices are self-observed.

Musical and product checks:

- Topic 85 contrasts a root/minor-third seed, a changed rhythm and a third-pitch expansion. The learner repeats, varies one feature and leaves a full silent bar before adding more vocabulary.
- Topic 86 provides a synthesized I–IV–V–I triad backdrop for self-practice, separate root and third targets, and two quarter-note approaches leading to a half-note landing. The final tonic root alone opts into audible sustain assessment. Fixed-target scoring has no chord backdrop and does not claim creative/chord-recognition assessment.
- Topic 87 supplies two distinct calls with an empty second bar for an original answer, plus a complete four-bar model. The response slot is explicitly unscored; it is not treated as a scored rest that the learner must obey. Preview looping allows call → answer → next call without a new capture pipeline.
- Topic 88 contains a two-bar opening, four-bar development, two-bar ending and their complete eight-bar combination. The model uses a minor-pentatonic vocabulary, rhythmic variation, a prepared high point and a deliberately quiet ending. The learner plans and compares original versions rather than matching a creativity score.
- The backdrop contains simultaneous chords. An initial presentation test assumed the existing staff supported polyphony; that assumption was wrong. The final test verifies all chord targets in TAB and explicit `StaffLimitation.polyphony`, while every monophonic model has complete staff notation. The existing limitation remains truthful; no incomplete chord staff is substituted. Chord shapes remain available on TAB/fretboard with audible preview.
- Corrected Ukrainian typographical/imperative wording and localized major/minor descriptions around dynamic root tokens. The source root and transposition policy stay independent of translated prose.

Evidence collected:

- 2,120 resolutions: 13 movable examples × 4 choices plus one fixed backdrop, across 8 tunings × 5 fret counts. Independent goldens cover pitches, chord-tone landings, source timing, complete silent slots and 2/4/2/8-bar solo forms; all graded entries validate at 40/60/90 BPM. One Learning test passed (2.885 s), `/tmp/improvisation-matrix.log`.
- Two App presentation/transport tests passed (2.003 s), `/tmp/improvisation-presentation-fixed.log`. Every new example has complete TAB; monophonic examples have complete staff. Both 44.1/48 kHz render checks find zero teacher samples in the response bar, audible metronome samples when enabled, and identical teacher samples at the next loop. This is deterministic synthesized output, not hardware listening evidence.
- 94 bilingual bundles validate with no issues; inventory is 88 authored /40 todo, 88 visible lessons and 6 legacy compatibility bundles. 888 UI keys validate. Existing catalog-count tests retain explicit expected counts, updated for four new bundles.

Full Learning: 127 tests in 41 suites passed (130.227 s), `/tmp/improvisation-learning-full.log`. Four Python authoring/audit tests passed (10.802 s); generated project, localization and UI-source checks pass. Full App: 169 tests in 50 suites passed (194.057 s), `/tmp/improvisation-app-full.log`.

Root-only Release/archive checks passed in `docs/benchmarks/improvisation-release-bundle.json`: arm64, macOS 14, ad-hoc signature, hardened runtime, expected entitlements, 94 bundles /283 YAML resources. Binary SHA256 `933a0e0f07c00ad4acda40efad8087eaa66f48983b388f4d5dcb22b3842a1c66`; ZIP SHA256 `705b96ddd10ec62a91c437be5f8e365cdf170cfaff15b8911c3fccd978af43e5`. `/tmp/improvisation-release.log`, `/tmp/improvisation-bundle.log`. Signed sandbox → separate XPC → invalidRequest probe passed, no provider called (`/tmp/improvisation-xpc.log`). Exact-head CI/merge remain open. Native listening, original guitar responses, keyboard/VoiceOver and hardware checks remain pending. No local Debug app is built. Full 128-topic acceptance remains open.
