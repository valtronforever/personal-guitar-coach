# Rock-rhythm module and palm-muted references — local review

2026-09-17. Same-agent code, musical and bilingual editorial review. Scope: authored topics 34–38 and 40, with a bounded notation/reference extension for palm muting. Together with topics 33/39, modules 1–5 are authored (40 of 128 topics). This is not complete curriculum acceptance.

## Findings and decisions

- Palm muting is explicit event metadata, preserved by lesson resolution and Codable snapshots. False is omitted from canonical JSON. Rests and sustained-note assessment cannot carry the flag; exercises containing it must be displayOnly. This prevents the short synthetic cue from implying validated grading of real muted guitar.
- The synthetic reference keeps the target frequencies, ticks and strum order, with a 90 ms exponential decay per voice. Seeking into a muted note preserves original age instead of starting a new attack. Ordinary unmarked playback stays unchanged, and practice mode still emits no reference guitar tone. Neither amp modeling nor physical technique detection was added.
- Normal TAB, compact TAB and staff display P.M.; localized spoken descriptions name palm muting. Compact notation uses a separate row above the accent/strum symbols. Offline Ukrainian/light 600px, English/dark 980px and low-A1 staff renders were inspected; P.M. fits without covering fret numbers, accents or low ledger notes. Native keyboard/VoiceOver use is still pending_user.
- The moving-power-chord lesson separates travel/rest beats from continuous quarters. Fretting-hand muting distinguishes releasing pressure from exposing open strings, and two-hand muting identifies blocked target versus previous-note overlap versus unused-string resonance. These are specific listening/self-observation exercises, not fabricated automatic technique scores.
- Pedal-tone phrases have independent clean monophonic targets and a lowest-open-string anchor. Full overdriven study has seven changing cells plus a two-beat final chord and two-beat silence, with deliberate P.M./ringing contrast. Its preview is explicitly synthetic and no amplifier effect is implied.
- Content validation caught an incorrect prerequisite ID in the pedal lesson; it now points to first-frets. Bulk YAML reformatting was removed so catalog/coverage diffs retain their established layout.
- Author documentation incorrectly equated an omitted strum with a rest; corrected to distinguish continued ringing from actual silence.

## Verification

- 50 bilingual bundles validate with no issues. Inventory: 40 authored, 4 needing review, 84 todo. All 808 UI localization keys, generated project and UI-test source type-check pass.
- Independent per-activity pitch arrays, bar/note/P.M. counts, chord ending, frozen round trips and practice eligibility pass across eight presets × five neck lengths.
- Reference tests independently calculate samples at 44.1/48 kHz for single and strummed muted notes, chunk equality, bounded seek phase, no practice tones, invalid author data and unchanged legacy encoding. Existing strum tests pass unchanged.
- All 231 Core tests pass explicitly serially: 23 Persistence, 85 Learning, 38 Domain, 80 Audio and 5 AgentBridge (audio suite 233.550 s). All 136 App tests pass in 127.170 s. Signed Release/archive validates 50 bundles/151 YAML files; report: docs/benchmarks/rock-rhythm-release-bundle.json. The signed XPC invalid-request probe passes without invoking a provider. CI remains pending. Real playing comfort, actual sound/latency and native accessibility remain pending_user.
