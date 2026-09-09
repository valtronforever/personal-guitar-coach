# Task 07 local review

Self-review by the implementing agent; no independent review is claimed.

Reviewed schema/version boundaries, musical and localization validation, file containment, duplicate identifiers, visual resolution, native resource membership, and reading without audio services.

## Findings and fixes

- Repeated invalid catalog entries could produce identical warning identities in SwiftUI. Diagnostic entries now have unique identities; tests confirm duplicate catalog entries never create duplicate loaded lessons or warning IDs.
- Identifier checks must reject trailing newlines as well as path traversal. Replaced an end-anchored regular expression with explicit ASCII-byte validation, and compare resolved directory paths for containment. Regression cases include `../escape` and a trailing newline.
- An unbounded warning stack could cover healthy lessons. Warnings now use a collapsible, height-bounded list; an unreadable catalog has a different message from an intentionally empty catalog.
- Native AX inspection found an accessibility ID propagated to both a step heading and its paragraph. The ID now belongs only to the heading; restarted and verified unique IDs in the native tree.
- Native List rows do not expose the NavigationLink ID used in the first draft of the UI smoke test. The authored test now opens the observed localized row by its label and verifies the detail heading. Xcode UI-test execution remains U07, so it is not claimed to have run.

## Verification

- 42 core tests in six suites, including ten lesson-content tests (one with four invalid-musical-data cases), and seven existing app-state tests pass.
- Fixtures cover missing translation, mismatched versions/step keys, blank text, unknown events, duplicate IDs, invalid frets/durations/modes, future schemas, containment, text/manifest round trips, and healthy lessons remaining accessible.
- Resolver tests cover rests clearing note highlights, text-only steps clearing all selection, suggested fingers/mutes, follows-instrument vs fixed-tuning pitches, and display-only chord events coexisting with monophonic practice.
- The CLI validates the actual source sample and the copy inside the Release app bundle: one bilingual lesson, zero issues.
- Debug/Release native builds and strict ad-hoc signatures pass; Xcode generator and 136-key en/uk catalog checks pass. CI now validates bundled lessons.
- Native CUA opened the real bundled lesson, verified all four English steps, switched to Ukrainian while keeping the same lesson open, and inspected the complete translated text at the 900-point main-window width. No audio capture, microphone permission request, or practice score was involved. System language was restored after the check.

The current UI is a working text reader. Click-to-fretboard/timeline interaction, selection restoration, filtering, and practice entry remain task 10, after the renderers in tasks 08–09. The initial sample is not a claim that the six-lesson starter course is finished.
