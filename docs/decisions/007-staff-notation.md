# ADR 007 — Bounded guitar staff presentation

Status: accepted for the task-22 prototype; final native interaction/accessibility validation remains U05/U07. Date: 2026-09-10.

## One musical timeline

`StaffModel` projects the existing `TimelineModel` / `ResolvedEvent` instances. It does not store another timeline, reschedule notes or modify Domain MIDI. Every drawn/selectable symbol retains the canonical event ID, start and duration ticks. The lesson uses its existing `LessonSelection` callback for both Staff and TAB; preview supplies the same cursor tick. Manual selection and playback cursor remain different states.

Sounding MIDI remains authoritative. Written guitar pitch is **sounding MIDI + 12**, solely for display: E2 (40) is written E3 (52) while playback and assessment still use E2/82.4069 Hz at A4=440. The treble clef has an 8 below it to express the octave convention; this indicator must not cause a second transposition. A4 changes frequency through the existing tuning model, not notation spelling.

Clef/notation and sounding transposition are distinct concepts in notation interchange as well, but this task adds no importer/exporter. [MusicXML 4.0 clef](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/clef/), [transpose](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/transpose/)

## Prototype vocabulary

- One monophonic voice; existing 3/4 and 4/4 meters; whole, half, quarter, eighth and sixteenth notes/rests on the 240-tick grid.
- Sounding C2–E6, with written C3–E7 ledger lines. Only one bar is mounted; at most sixteen symbols, each with a 44-point keyboard/click target. Horizontal spacing reuses bar-relative TAB tick geometry. The renderer supports the full displayed pitch range without changing audio capability.
- Treble staff, no signature / G major (F sharp) / F major (B flat). This picker changes notation only and is not an inferred exercise key. No signature and G-major spelling prefer sharps; F-major spelling prefers flats. C-major and A-minor course notes need no signature. This is a deterministic limited spelling policy, not a complete harmonic-context engraver.
- Accidental state is scoped to written letter **and octave** within each bar, initialized from the key signature. Natural signs cancel the signature/earlier accidental; repeated notes suppress redundant signs; each bar resets state. A key selection never changes sounding MIDI.
- Uniform contiguous eighth/sixteenth runs within one quarter beat are beamed together. Rests, gaps, beat boundaries and mixed rhythmic values split groups; isolated flags remain correct. Stems use a common direction and flat beam per group. Sophisticated mixed beams, engraving collision repair, multiple voices and stems for chords are future work.
- Staff selection has a visible outline; keyboard focus has a dashed outline; cursor is separate. Accessibility reports written pitch, sounding pitch, duration and selection in en/uk. Buttons support Space/Return and Shift extension; arrows preserve canonical order across bar changes. Actual native keyboard/VoiceOver execution remains pending.

Unsupported bars show a bilingual explanation and direct the reader to TAB. This includes polyphony, cross-bar holds (ties), gaps requiring invented rest events, incomplete final bars without pickup/ending metadata, dotted/other durations, off-grid timing and out-of-range pitches. The prototype never silently draws a partial chord or invents rest/event IDs. All six current practice exercises can be drawn, while the Em chord diagram itself remains available in the fretboard/TAB modes.

## Drawing and dependencies

`StaffDrawing` is the immutable drawing layer used by the view and offline render artifacts. Staff, noteheads, ledger lines, stems, beams and rests use native vector paths. System Apple Symbols provides the treble clef and accidentals; a local CoreText glyph check confirmed these characters. The font lacked quarter/eighth/sixteenth-rest glyphs, so those rests use original vector paths instead of missing-glyph boxes. Hollow heads erase the underlying staff before outlining, preserving both themes. No music font package or third-party renderer is added.

Offline ImageRenderer artifacts validate the actual notation geometry, including themes, key signs, ledger lines, rests, beams and hollow heads. They do not exercise a native window, menus, VoiceOver or microphone permission. The native computer-use pipe remains unavailable; those checks are explicitly deferred.

## Versioned extension plan

The prototype adds only presentation types and view state; existing exercise/lesson/result schemas do not change. Future authored notation must be introduced through a new validated content/exercise envelope rather than optional fields silently ignored by old readers:

1. **Written spelling / key metadata:** store authored letter/alteration plus instrument octave convention; validate against canonical sounding pitch. Define key changes, courtesy accidentals and double accidentals. Old exercises get an explicit documented default during migration; preserve original versioned source.
2. **Ties:** an explicit relation between consecutive same-sounding-pitch events/segments, with one attack expectation. Keep sound continuity separate from graphic splitting. Version assessment semantics before evaluating tied performance; do not infer ties just from repeated pitches.
3. **Tuplets:** rational duration/group metadata with exact tick representability; validate PPQ divisibility, group sums and non-overlap. Define new tempo/duration capability before grading. Do not round timing to the nearest sixteenth.
4. **Tempo changes:** a versioned tempo map with exact tick-to-output-sample conversion, calibration semantics and immutable session snapshot. Preserve old constant-BPM histories and mark comparisons incompatible when timing context differs.
5. **Techniques:** bend target/curve, slide endpoints, hammer-on and pull-off links need explicit authored relations. Display support and assessment capability are independent. Continuous pitch and legato/onset/offset validation require a new detector/evaluator contract and annotated corpus; existing onset grading must not pretend to understand these techniques.

Current techniques outside the prototype are neither represented nor assessed. A future display-only notation release may show them with explicit non-assessed status while retaining conservative practice gates. No 7/8-string/capo/import/song-library scope is added. The [conditional notation backlog](../../tasks/follow-up/notation.md) lists separate future implementation tasks.
