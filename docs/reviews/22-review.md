# Task 22 local review

Same-agent review of staff pitch/spelling, bar/accidental/rhythm projection, lesson selection integration, drawing, keyboard/accessibility metadata, localization and schema-extension plan. Native VoiceOver/user musical acceptance is not claimed.

## Findings and fixes

1. Written guitar octave could contaminate playback/assessment if stored as a second pitch source. The staff keeps only a derived written MIDI (+12) alongside the original resolved event; all callbacks/cursor use canonical IDs/ticks. Tests verify E2 stays sounding E2 and every course exercise preserves exact IDs/pitches.
2. Accidentals must reset per bar and be scoped by letter/octave. Tests cover G-major F-sharp/natural/repeated/cancel/reset, octave independence and F-major B-flat/natural. Key controls change spelling only.
3. System Apple Symbols has the clef/accidental glyphs but lacks the required rest glyphs. A CoreText glyph check caught the issue. Replaced rests with native vector paths; whole/half rests have explicit staff-line placement. Offline render images confirmed no missing-glyph boxes.
4. The initial clef was too small and its G-loop was not aligned with the G4 line. Increased and repositioned it; inspected updated light/dark drawing artifacts. Added the octave 8 directly below its tail.
5. Filling hollow noteheads with an AppKit background color could ignore the renderer's theme. The canvas now erases the head interior before outlining. A dark half-note artifact confirms a dark hole and visible white outline; the high written E7 whole-note artifact confirms ledger lines remain inside bounds.
6. SwiftUI pitch naming initially referenced the `name` function instead of invoking it, causing interpolation warnings. Fixed to `name()`; localized accessibility strings receive real pitch names. Added explicit keyboard focus and Space/Return/Shift handling with pending focus across bars.
7. The first String Catalog update reordered unrelated keys. Restored the existing order and appended only the eleven staff entries, retaining 503 complete en/uk keys.
8. Unsupported notation could otherwise silently lose information. The entire affected bar shows a bilingual limitation instead of a partial chord, split tie or invented gap/rest; TAB remains the complete existing sequence.

9. Positioned invisible markers could share the entire canvas layout frame, defeating horizontal cursor following. Replaced them with real half-beat HStack cells and typed TimelineFollowTarget IDs, reusing the TAB convention. Event hit targets retain their 44-point frames. Also aligned the final cursor with the barline by reserving the note-anchor offset in the canvas width.

10. A partial final measure could look like a complete 4/4 bar with missing rests. Without pickup/ending metadata the prototype now rejects incomplete bars explicitly; fixtures use real rest events to complete supported bars. TAB still shows the canonical partial timeline. Added a regression for this limitation.

11. The fixed-height drawing plus longer localized controls could force the lesson beyond its minimum window height. The staff panel now scrolls vertically within a 180–360-point frame, while its score scrolls horizontally; long explanations remain reachable. Final native window/VoiceOver acceptance is still U05/U07.

## Verification and limits

- Six pure/model/selection staff tests pass, including every practice bar of all six bundled lessons and explicit unsupported cases. Full App suite: 59 tests / 18 suites pass; the renderer test is opt-in for file generation.
- Offline render fixture explicitly executed with `COACH_STAFF_RENDER_DIR=build/staff-renders`: 48 images (eight bars, including the actual C-major lesson × three signatures × two themes), actual shared StaffDrawing via ImageRenderer, expected pixel dimensions. Inspected rhythm/clef/accidentals/beams/ledger and dark hollow/high whole examples. These are geometry artifacts, not a launched-app screenshot or a VoiceOver test.
- Debug/Release local builds, bundled content, signature/archive and final CI results are recorded with task evidence. Project/catalog/UI-source checks pass. No Domain/audio/scoring/storage schema changed.
- Native app reconnect again failed with “Sky Computer Use native pipe closed before response”. No alternative UI-control path or permission bypass was used. U05/U07 must still validate staff↔TAB native selection, rapid cross-bar keyboard focus, both languages at minimum window size, live cursor following and VoiceOver.

No unresolved critical software issue was found in the reviewed scope. This limited prototype is not a complete engraver; ties, tuplets, tempo maps, multiple voices and technique-aware analysis remain explicit follow-up work in ADR 007.
# Native follow-up

After the original PR #44 merge, native observation recovered for the Release app. The [follow-up review](22-native-ui-review.md) records an actual focus-decoration defect, its fix and native retest, plus the remaining acceptance limits.
