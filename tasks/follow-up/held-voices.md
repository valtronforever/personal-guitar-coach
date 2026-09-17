# Independently held voices — fingerstyle and chord melody

Status: `pending_user`

Add explicit held-string continuations to the shared event model, keeping independent bass/chord voices sounding while another voice changes. Validate contiguous physical ties, preserve tuning adaptation, serialize absent metadata compatibly and keep these polyphonic exercises display-only. Use completed voice spans for reference playback without reattacking/fading at internal boundaries; retain phase across chunks/seeks/loops. Distinguish held and attacked frets in both TAB presentations and accessibility. Author substantive en/uk lessons 107–108 with progressive examples and honest physical self-checks. Test invalid ties, projection/scoping, all presets/necks, reference continuity and notation. No new capture pipeline or polyphonic assessment claims; native/guitar acceptance remains pending.

Implemented model/reference/resolver/TAB/accessibility and two bilingual lessons. Targeted Domain/analytic audio, 360 course cases and notation checks pass; 120 bundles/917 localized keys validate. [Same-agent review](../../docs/reviews/held-voices-review.md). Full suites, root Release and CI/merge in progress; actual native/guitar gates remain open.

All 350 Core and 187 App tests pass, along with UI/script/localization checks and the signed 120-bundle root-only Release/archive/XPC. [Bundle evidence](../../docs/benchmarks/held-voices-release-bundle.json). Exact-head CI/merge and actual native/guitar acceptance remain open.

## Merged software evidence (2026-09-17)

[PR 94](https://github.com/valtronforever/personal-guitar-coach/pull/94) merged as `c9a1ab62b999f0bc32ad3b2e003429e783b2ae29` after [CI 35198220713](https://github.com/valtronforever/personal-guitar-coach/actions/runs/35198220713) passed on exact head `3459d5df20e153c770f1bb8b53d4e0dfb0a51a4e`. Signed Release/software evidence above remains valid; native and actual-guitar acceptance remains `pending_user`. Earlier in-progress notes describe historical checkpoints.
