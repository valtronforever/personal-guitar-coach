# Held voices — same-agent review

Implementing-agent review, not independent. Status: `in_progress`; software delivery is under verification, native/hardware gates remain open.

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
