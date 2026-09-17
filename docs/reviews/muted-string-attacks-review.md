# Muted-string attacks and funk — same-agent review

Implementing-agent review, not an independent review. Status: software verification in progress.

## Scope and findings

`MutedStringAttack` is an optional unpitched event source: explicit sorted strings and optional direction, no fret/MIDI placeholders. It is exclusive with pitched/sustained/moving techniques and restricted to display-only exercises, including mixed phrases. Topic 102 adds five bilingual funk activities, a five-criterion self-review and a factual cross/rest/palm-mute quiz. The body contains 418 English/349 Ukrainian words plus worked activity instructions.

- An ordinary note previously required sounding positions; a rest was silent. Added an explicit mutually exclusive muted source instead of abusing either semantics. Pure and mixed exercises reject monophonic grading. Optional encoding is absent for ordinary events; there is no silent history regrading.
- Position resolution and named fingering projections could discard a nonpitch instruction. Resolution now preserves muted metadata; projections from an exercise containing it reject. Snapshot/selection/preview boards show affected strings as muted, with no fabricated open-string pitch target. Text includes a localized scratch label in sequence/positions; other pitch/root calculations retain ordinary behavior.
- An empty pitch list would previously engrave as a staff rest. Staff now separates the unpitched engraving step from actual pitch/accidental data, drawing cross heads with real duration/stem/beam, direction/accent and ties. Rests stay rests and break beams. Full/compact TAB share × string markers. The existing pitched chord-polyphony limitation remains explicit; it is not silently reduced to one voice.
- Reference noise is deterministic by sample age and decays within 80 ms, bounded by the written event end with an end fade. Seek/chunk/loop behavior does not restart the envelope. The renderer stays under the existing single transport owner; no new capture pipeline, real-time allocation, random-state generator or analysis model was added. Practice transport remains reference-silent.
- The first reference test requested more than the renderer's existing 48,000-frame batch limit and correctly threw invalidTime. Fixed the test to render bounded 40,000-frame batches, compare against differently chunked 769-frame output and retain independent silence/energy/bounds checks; production limits were not relaxed.
- The funk examples preserve chord stabs, scratches and actual silent slots. C7's first upper-string voicing is explicitly rootless (third/fifth/minor seventh); the second compact dominant shape and exact 16-slot patterns are independently checked. The synthetic reference and hand/damping quality are not represented as real-guitar evidence or automatic grades.

## Evidence

- Domain: two targeted tests, 0.002 s (`/tmp/muted-domain-reference.log`); valid no-pitch source across all presets, ordinary encoding/round-trip, sorted/unique strings, metadata exclusivity and pure/mixed graded rejection.
- Reference: one test, 0.168 s (`/tmp/muted-reference.log`), at 44.1/48 kHz. Nonzero attack vs silent rest/tail, finite bounded output, tuning independence, distinct chunk sizes, seek into an existing attack, loop repetition and silent practice transport.
- Course: two tests, 3.063 s (`/tmp/funk-course.log`); 200 activity/preset/neck cases, independent slot strings, chord MIDI arrays, exact ticks/durations, cue directions, unpitched vs rest targets, physical snapshot roles, bilingual text and projection rejection. Self-check completion remains partial; quiz answer is an audible unpitched attack.
- App/Staff: ten tests/two suites, 2.750 s (`/tmp/muted-app-tests.log`); no accidental/pitch on crosses, correct stems/beams/rest boundaries, selected muted strings, no fabricated board targets and existing staff regression.
- Offline SwiftUI fixture: 0.225 s (`/tmp/muted-render.log`). Inspected `/tmp/muted-visuals/muted-uk-light.png` and `muted-en-dark.png`: cross rows, one/three-string variants, rests, numbered pitches, arrows/accent, unpitched staff heads and localized legend are readable at 800-point width. This is not native interaction or VoiceOver execution evidence.
- 111 bilingual bundles validate with zero issues; 915 en/uk UI keys and placeholders pass. Partial inventory: 105 authored/23 todo. Generated project current; UI-test sources type-check. Full Learning: 141 tests/49 suites, 170.467 s; Domain: 63 tests/20 suites, 0.393 s; Persistence: 23 tests/four suites, 0.058 s within `/tmp/muted-core-full.log`.

Full Audio/App, signed root-only Release/archive/XPC and exact-head CI results will be recorded below. Actual guitar/native/provider gates remain open.

Full App: 183 tests/57 suites, 222.344 s (`/tmp/muted-app-full.log`). Root Release/archive validates 111 bilingual bundles (334 YAML), arm64/macOS14, ad-hoc hardened sandbox and expected entitlements. Binary SHA256 `103c754c27ae248a19cf6c6f14dcdbefec5bbb369e62577966368b2a6f8446ed`; archive `06512cfdb50fae53893ca7688f34aa3ecf69ee5e2b815482893b616bb818a573`. See `docs/benchmarks/muted-string-attacks-release-bundle.json`. Signed sandbox→separate XPC→invalidRequest passed without calling a provider. No native launch or real-instrument acceptance is claimed.

Full Core completed successfully: Audio 111 tests/38 suites, 512.162 s; AgentBridge six tests, 1.612 s, alongside the Learning/Domain/Persistence results above (`/tmp/muted-core-full.log`). All suites pass. `git diff --check` passes; exact-head CI/merge remains open, with real hardware/native/provider gates pending.

Exact-head CI 35193742343 passed in 32m41s on `9ff554fd23dfb9338a82a354f465f6438fd718a7`; PR #92 merged as `88b0986b9ff721256e72cdd0952802eb891a5a0e` at 2026-09-17T07:50:43Z. Native/guitar acceptance remains open.
