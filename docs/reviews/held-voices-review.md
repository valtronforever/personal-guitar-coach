# Held voices — same-agent review

Implementing-agent review, not independent. Status: `pending_user`; software delivery is under verification, native/hardware gates remain open.

The event contract now represents independent bass/chord continuations through changing melody. Nonoverlapping events list all sounding physical positions and optional sorted heldStrings; new attacks are the complement. Exercise validation rejects first-event/broken/gapped/changed-fret ties, silent/duplicate/unrelated string references, automatic grading, and currently unsupported mixed technique references. Empty metadata preserves old encoding. Complete voice spans carry the original attack/phase/accent to the final release.

Review decisions:
- A changing melody must not restart bass or change its volume normalization. Audio uses complete spans and a stable maximum-active-voice divisor, with fades only at actual voice ends or the selected range boundary. No capture pipeline, callback work or DSP capability is added.
- Whole-exercise fixed positioning is explicit for the first contract. The resolver retains physical string identity and adjusts fret/pitch for each target tuning; it cannot independently revoice a tied chord. Named-shape projection and event-scoped fragments are rejected before information can be lost.
- Both TABs show held frets in parentheses and announce continuation. The board retains sounding positions. Existing polyphonic staff limitations remain explicit, including bars containing only a remaining held voice; no fabricated fresh attack is engraved.
- Two substantive en/uk lessons provide nine activities: independent bass/melody parts, held bass, alternating bass under a held melody, complete four-bar fingerstyle, separate melody/supporting chords, retained harmony and a complete chord-melody phrase. Five physical/listening self-checks per lesson; no fake simultaneous-note grade. Bodies: 345/281 and 335/268 English/Ukrainian words, plus activity/task guidance.
- Fixed an authoring-script insertion that initially placed lesson IDs under the catalog module list; loader rejected it and the IDs were moved into the lesson list. Fixed a Ukrainian typo. A test helper initially used the wrong report type; corrected before rerunning. Neither failure required a production workaround.

Evidence:
- Domain: two tests pass (0.001 s) covering correct merged lifetimes, release/repeated attack, legacy omission/roundtrip and invalid/unsupported contracts. Audio: independent C3/E4/F4 analytic reference, bounded chunks, seek, loops and practice silence pass at 44.1/48 kHz (0.580 s).
- Learning: 360 activity/preset/neck cases plus loader/projection/template regression pass (two tests, 3.354 s). Independent attack-pitch arrays and form durations are checked; all physical held strings and original lifetimes survive adaptation.
- App: presentation/accessibility/fallback and offline fixture tests pass (two tests, 0.211 s). Inspected `/tmp/held-visuals/held-uk-light.png` and `held-en-dark.png`: ordinary and parenthesized frets/legend readable at 800pt. Four en/uk light/dark fixtures exist; these are not native app interaction.
- Content loader: 120 bundles, zero issues; inventory 114 authored/14 todo. Localization 917 keys and generated project checks pass. Full Core/App and signed root-only Release evidence follow below.

Python author/bundle script tests: five passed (14.761 s). UI-test sources type-check. Full Core/App remain running; no completion claim yet.

Full Core passes: Persistence 23/4 (0.054 s), Learning 144/51 (197.746 s), Domain 65/21 (0.345 s), Audio 112/39 (509.300 s), AgentBridge 6/1 (1.608 s): 350 tests total. Full App passes 187 tests/59 suites (236.398 s). Logs: `/tmp/held-core-full.log`, `/tmp/held-app-full.log`. Parent test-only CI complexity fix was merged after these suites; its own 1,160-case rerun passed, with no product changes.

Signed root-only Release/archive validates 120 bilingual bundles / 361 YAML files, arm64/macOS14, ad-hoc hardened sandbox and expected entitlements. Binary SHA256 `75609ebea69608d20cee7dd4fecbbec797f63e556850569c9a934d49bc6eb8b3`; archive `41ed0f0dadb1a40ccb1ba4b1f7780aa5f13d778b39f818fae3b3727a6e29db67`. See `docs/benchmarks/held-voices-release-bundle.json`. Signed sandbox→XPC→invalidRequest passes without invoking a provider. No actual app launch or guitar acceptance is claimed. Exact-head CI/merge remain open.

## Merged software evidence (2026-09-17)

[PR 94](https://github.com/valtronforever/personal-guitar-coach/pull/94) merged as `c9a1ab62b999f0bc32ad3b2e003429e783b2ae29` after [CI 35198220713](https://github.com/valtronforever/personal-guitar-coach/actions/runs/35198220713) passed on exact head `3459d5df20e153c770f1bb8b53d4e0dfb0a51a4e`. Signed Release/software evidence above remains valid; native and actual-guitar acceptance remains `pending_user`. Earlier in-progress notes describe historical checkpoints.
