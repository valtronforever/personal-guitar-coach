# Jazz and modal specialization course — same-agent review

Implementing-agent review, not independent. Status: `in_progress`, actual native/guitar acceptance remains open.

Six bilingual lessons complete specialization topics 105–112 around existing fingerstyle/chord melody: ii–V–I comping, chromatic jazz lines, Dorian versus natural minor, harmonic minor, melodic-minor conventions and tension/resolution. There are 27 new activities (18 graded monophonic, nine display-only references) with distinct examples and self-review. No production/DSP/dependency change is needed beyond the held-voice parent extension.

Review decisions:
- ii–V–I shell voicings explicitly omit fifths, retain roots/thirds/sevenths and connect the two guide-tone lines. Grade only separated arpeggios and guide tones; sparse/offbeat chord support remains self-reviewed. Offbeat attacks are exactly the eighth after beat1 and beat3.
- Jazz lines establish specific target thirds/tonic before approaches/enclosures. Original straight eighths have explicit chord-area/bar boundaries; no backing track or automatic style score is claimed.
- Dorian/natural minor share one tonic and differ only at degree6. A real two-bar tonic pedal and a held-bass/moving-melody model provide audible context. Monophonic scales/phrase are graded; playing against a reference is self-practice.
- Harmonic minor preserves b3/b6 and raises7; the characteristic three-semitone augmented second and final semitone are checked. The dominant reference is explicitly rootless; its third resolves into the minor tonic.
- Melodic minor names both classical directional and jazz bidirectional conventions rather than enforcing a universal direction rule. Minor-major-seventh arpeggio and an application phrase preserve their actual major6/7 targets; generic teaching remains tuning-independent.
- Tension examples have actual held bass/upper voices. In the prepared suspension, the upper note starts over dominant-root bass, continues through the tonic-bass change, then resolves down a semitone. The two voices have independent canonical lifetimes; no fresh upper attack is invented at the harmony change.
- Every example has fixed original positioning, complete musical bars and explicit source roots. Six self-practice tasks distinguish musical/physical decisions from audible exact-note scores. Body lengths en/uk: 338/257, 350/261, 323/256, 312/250, 317/259, 329/253 words, plus specific activity/task guidance.

Evidence:
- Independent target arrays, exact form/bar counts, grade gates at 40/60/120 BPM, degree relationships, offbeat placements and held-voice suspension/pedal lifetimes passed for 27 activities × 8 presets × 5 necks =1,080 cases (2.816s, `/tmp/jazz-modal-matrix.log`). No synthetic signal or real guitar run is represented by this content test.
- Loader validates 126 bundles, zero issues; partial inventory 120 authored/8 todo. Localization 917 keys, generated-project and diff checks pass. Full Learning/App, Release/CI and native acceptance remain pending below.

Full Learning: 145 tests/52 suites passed in304.611s; full App:188 tests/59 suites passed in330.715s (`/tmp/jazz-modal-learning-full.log`, `/tmp/jazz-modal-app-full.log`). UI-test sources type-check. Parent typed-helper CI fix was fast-forwarded with identical test data and its separate regression pass; no production behavior changed. Signed root-only Release and fresh CI are next.

Signed root-only Release/archive validates126 bilingual bundles / 379 YAML files with zero issues, arm64/macOS14, ad-hoc hardened sandbox and expected entitlements. Binary SHA256 `5c6afa369f623da9db700164dd055e7909e9bf7ba517d31d65eb262194558e58`; archive `c72fb42b14cad4af1b70b7a42f00636f05b86af763315417afd3fcbeaf06237a`. See `docs/benchmarks/jazz-modal-release-bundle.json`. Signed sandbox→XPC→invalidRequest passes without a provider call. Actual native app/guitar/provider acceptance remains open; exact-head CI/merge are pending.

## Merged software evidence (2026-09-17)

[PR 95](https://github.com/valtronforever/personal-guitar-coach/pull/95) merged as `5e1c557de85f4b00ac21990d8dee0aa490472f65` after [CI 35198635079](https://github.com/valtronforever/personal-guitar-coach/actions/runs/35198635079) passed on exact head `8d5e5d015b5691a6e9d7a64c9283a637bffb3f29`. Signed Release/software evidence above remains valid; native and actual-guitar acceptance remains `pending_user`. Earlier in-progress notes describe historical checkpoints.
