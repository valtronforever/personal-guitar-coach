# Practice tablature read-ahead — local review

Reviewer: implementation agent (same-agent review; not independent).

## Scope

Practice-only compact score layout/rows, display-only continuous transport coordinate, count-in insertion, vertical following and lifecycle integration. Lesson/result TAB, rendered audio, assessment timing and stored attempts are unchanged.

## Findings and fixes

- Old practice TAB used 176 pt beats and half-beat horizontal scroll anchors. The new reader fits whole bars responsively (up to four per row), with two or more rows visible at default size and no horizontal following.
- Count-in was hidden from TAB because the old cursor exposed only the exercise start. `TransportPlan.audibleTimelineTick` exposes fractional display ticks before the selected range using the same bounded output-latency compensation; it never adds scored events.
- Cursor interpolation is a 55 ms linear SwiftUI transition between incoming audio samples, not a free-running musical timer. Row changes scroll with a 400 ms animation. Reduce Motion removes these animations. Follow playback can be disabled for manual reading.
- Pause/stop clears the display position synchronously, cancellation cannot republish it, and repeated attempts reset the count-in. Opening TAB during playback follows the current row, not the beginning.
- Row frames now occupy the full viewport width. Rest duration labels were vertically displaced by default center alignment; fixed top-leading event alignment. Fret glyph centers align with the time cursor; narrow duration labels have spacing.
- Zoom scales fret fonts and string spacing as well as row density. Keyboard focus requests survive lazy-row insertion.

## Verification

Focused transport tests: 7 passed, including continuous count-in, fractional samples, selected ranges and 250 ms output latency. Focused App tests: 16 passed (score geometry, practice lifecycle and optional offline rendering). Final full-suite/build results are tracked in the task.

Offline full-view ImageRenderer cannot render the native scroll/control surfaces (blank scroll area and placeholder controls). Extracted the actual shared `PracticeScoreRow` renderer and rendered those same production rows directly for visual review in both languages/themes at 600/980 pt. These artifacts verify score drawing only, not live scrolling or native controls.

Native computer-use check failed with `timeoutReached`; live scroll/keyboard/VoiceOver and guitar/wired/Bluetooth acceptance remain explicitly open in USER-VALIDATION. No hardware synchronization guarantee is inferred from animation tests.

Final local verification: 175 Core tests and 101 App tests passed. Following the final view-only adjustments, five score geometry/render tests passed again; stacked duration fractions remain legible at compact widths. 630 localization keys, project generation, UI source typechecking and whitespace checks pass. Local ad-hoc Release app/ZIP rebuilt and verified, including resources, entitlements and signatures; no Debug bundle recreated. [Bundle evidence](../benchmarks/practice-tablature-release-bundle.json).
