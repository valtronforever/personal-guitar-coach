# Tremolo picking — same-agent review

Implementing-agent review, not independent. Status: verification in progress.

Topic 96 now has five bilingual activities: quarter/eighth subdivision comparison, measured eighth-note bursts and recovery, fast one/two-beat sixteenth bursts, a whole-bar burst and a four-bar pitch-changing study. Two moderate-speed activities use existing clean monophonic grading; three fast examples use reference/metronome/self-practice. A five-criterion physical review and a factual subdivision quiz complete the lesson.

Review decisions:
- Fast sixteenths at 80–160 BPM fall below the current 0.2-second note-analysis limit. They are explicitly displayOnly, have no practice entry and reject automatic scoring. No detector capability is expanded or falsely advertised.
- All examples retain a single physical string and fixed original positioning, so the movement task is not silently transformed by an alternative fingering. Standard transposition derives new sounding notes; Drop leaves this upper-string exercise consistent with its Standard family.
- Pick arrows alternate per burst, restarting after explicit rests. Quarter/eighth comparison, one/two/four-beat burst lengths, complete recovery and the four-bar final form are independently checked. Beat accents mark the pulse and are not physical force instructions.
- Moderate exercises are valid at 40/60/120 BPM; at the maximum, the eighth notes last 0.25 s. Direction, movement, comfort, evenness and fast execution remain self-reviewed, distinct from measured pitch/time.
- The text distinguishes picking tremolo from an effect or vibrato arm, asks for gradual repeatable tempo choices, and provides concrete start/stop and comparison methods. It does not diagnose the player's hand from audio or require maximum-speed playing. Body lengths: 405 English/338 Ukrainian words, plus activity instructions and tasks.

Evidence:
- 200 activity/preset/neck cases passed in 1.594 s (`/tmp/tremolo-course.log`), including independent pitch arrays, exact lengths/rests, physical string, cue direction, scored/unscored boundaries and localization invariance. Self-checks remain incomplete with partial confirmation; quiz answer is four attacks per quarter-note beat.
- Partial inventory: 104 authored/24 todo, 110 bundles/104 visible. Localization 911 keys passed. No new production code, DSP, dependency or callback changes. Parent harmonic checks are recorded separately.
- Full Learning/App, content and signed root-only Release/archive/XPC results are pending below. No native app interaction or real fast-picking performance is claimed.

Full App: 180 tests/55 suites passed in 219.379 s (`/tmp/tremolo-app-full.log`), including the complete 110-bundle catalog. Generated project is current. Full Learning and Release evidence follow below.

Full Learning: 139 tests/48 suites, 166.323 s (`/tmp/tremolo-learning.log`). Root Release validates 110 bilingual bundles with zero issues. Signed archive/bundle checks pass: arm64/macOS14, ad-hoc hardened sandbox, expected entitlements, 331 YAML resources and both locales. Binary SHA256 `f5bf75ae94b2cfd849c64fe0ff3f77cdabc8cddb3daa432a68edb1723dc73b90`; archive `ddf28c14f75e1de0e34dff46919e37a3dd6435233cead33eb197074a4056874b`. See `docs/benchmarks/tremolo-picking-release-bundle.json`. Signed sandbox→XPC→invalidRequest passed without a provider invocation. Exact-head CI/merge and native/hardware gates remain open.
