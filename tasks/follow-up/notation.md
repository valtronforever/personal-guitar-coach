# Conditional notation implementation backlog

English follow-up proposals from task 22 / ADR 007. These are not additional active tasks in the authorized 22-task implementation. The bounded staff prototype is implemented; a full engraving/assessment expansion needs a separate scope decision.

| ID | Task | Dependencies | Acceptance evidence |
| --- | --- | --- | --- |
| N01 | Version authored key and enharmonic spelling metadata | ADR 007, U05 notation review | Sounding-pitch validation, double/courtesy accidentals, octave-specific measure state, key changes; explicit migrations/defaults; old lesson/history readability |
| N02 | Add tied-note engraving and one-attack semantics | N01 | Cross-bar ties preserve event/segment identity and sound continuity; same-pitch validation; no extra expected attack at tied boundaries; new assessment version and regression fixtures |
| N03 | Add tuplets and mixed rhythmic beaming | N01 | Exact rational tick durations, validated PPQ/group sums, rests and compound grouping, layout collision handling, supported-duration gates and en/uk accessibility |
| N04 | Add a versioned tempo map | N01 | Exact tick/sample mapping, count-in/loop/pause semantics, immutable calibration/tempo snapshot, deterministic scheduling and actual hardware drift validation; no old-result regrading |
| N05 | Display bends, slides, hammer-ons and pull-offs | N01–N03 as needed | Explicit source/target relations and pitch curves; accessible technique text; visible display-only capability where assessment is unsupported; original course fixtures |
| N06 | Research and validate technique-aware assessment | N05 and independently annotated real input | Continuous pitch/onset/offset evidence, unknown handling, clean DI/microphone/piezo and noise cases; a new algorithm/capability/schema; technique-specific precision/timing gates before enabling scores |
| N07 | Complete staff engraving and native accessibility | N01–N05, U05/U07 | Chords/multiple voices, accidentals/notehead collision handling, bounded page layout, complete keyboard/VoiceOver parity, both themes/locales and narrow-window review |

Guitar Pro/MusicXML import, external song catalogs and new instrument string counts remain separate future decisions. A notation feature must never activate an unsupported audio score merely because its symbol can be drawn.
