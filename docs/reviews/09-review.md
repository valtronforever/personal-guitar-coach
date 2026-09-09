# Task 09 local review

Self-review by the implementing agent; no independent review is claimed.

Reviewed canonical tick geometry, note/rest duration, bar continuation, range selection, keyboard navigation, cursor following, long exercises, native integration, localization and test coverage.

## Findings and fixes

- Keyboard focus could not move from bar 16 to an event in a page that had not been inserted yet. Navigation now stages the target, inserts/reveals its bar, and establishes focus when its native button appears. Space/Return also handle the insertion boundary. Native forward and reverse 16↔17 transitions select the correct stable event IDs.
- Unselected rests had a different intrinsic label height, moving their duration and symbol vertically. Event content now has an explicit top-leading origin; rests retain the same time geometry whether selected or not.
- The complete panel rendered blank inside the lesson although its accessibility tree existed and the standalone fixture rendered. Reduced the case to individual components and isolated the trigger to the explanatory Text's vertical `fixedSize` constraint. Removed that constraint, gave ordinary wrapping a bounded three-line area, and verified the integrated screen at the minimum and larger window sizes. Original scrolling, lazy rendering and background styles remain enabled. Accessibility-tree existence alone was not treated as proof of correct rendering.
- Following only the current bar hid the cursor within a wide bar at 2× zoom. Static half-beat layout anchors now follow the incoming tick inside the bar; the renderer does not create a clock. Targets change at most twice per beat. Native checks keep tick 74,640 (bar 20, beat 2.75) and tick 76,800 (exercise end) visible at 2× zoom.
- The final boundary needs a visible cursor and an end label rather than an apparent fifth beat of 4/4. The line is centered on the tick boundary; the endpoint caption explicitly says the exercise has ended. Continuation values/hints distinguish a held event across a barline from a new attack.
- Exercise changes clear stale page/focus/follow state. Very large absolute ticks use bar-relative integer subtraction before conversion to points; only a bounded 16-bar page is constructed.
- The fretboard finger shorthand `F3` looked like another pitch. It now shows a small numeric finger hint with a localized legend; native Em and muted-string fixtures verify the distinction.

## Verification

- 42 core tests in six suites and 18 app tests in four suites pass. Timeline fixtures cover 3/4 and 4/4, quarters/eighths/sixteenths, rests, gaps, held-note continuation, chord alignment, range anchors, hit testing after scroll/zoom, incoming cursor ticks, half-beat following, and a final partial bar at Int64.max.
- Debug and Release app builds, strict ad-hoc signatures, generated-project consistency, whitespace checks and 185-key en/uk catalog validation pass.
- `Scripts/check_ui_sources.py` type-checks all UI-test sources with Swift 6 and the selected macOS 14+ Xcode SDK. Added it to CI. This is not execution of XCTest: local Xcode UI execution remains U07. A smoke test records the page-boundary regression.
- Native CUA verified mixed rhythm/rest layout, range selection through Shift-Space, keyboard activation, stable IDs after zoom/scroll, the final event of a 20-bar exercise, 16↔17 keyboard transitions, and externally driven cursor position/following at 1×/2×. The fixture is explicitly labelled as no audio.
- Native chord checks show six Em fret numbers at one tick and six expected positions on the fretboard, including open strings and suggested fingers. A separate fixture shows two muted strings with × and no sounding pitch in their accessible labels. Synthetic detected-pitch display stays separate from the strings.
- The real bundled lesson switches between the two musical views, accepts event/range selection and shows the corresponding fretboard positions. English/dark and Ukrainian/light were inspected at the exact 900×620 minimum content size and a larger window. E4 selection survived a language switch. System language/appearance were restored.

The Developer fixture window and resize helper compile only in Debug. They do not start audio, write attempts, or represent a real guitar assessment. Playback audio remains task 14; complete bidirectional lesson-step selection and restoration remain task 10.
