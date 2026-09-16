# Calibration failure diagnostics — same-agent review

Scope: synchronization rejection reporting, transient evidence, timing gate extraction, instructions and lifecycle regressions. Reviewed by the implementation agent, not independently.

## Findings and fixes

- One generic “two consistent passes” error erased failures from signal preflight, the first pass, pitch/attack validation, clocks and second-pass agreement. Added specific localized reasons and a retained pass report. Failure still clears the candidate/first pass and never saves compensation.
- Coordinator `.failed`/`.interrupted` states were flattened to `routeChanged` by the capture lease guard. Preserve the concrete backend error.
- Timing thresholds were not visible: ±400 ms was only the matching window, while spread was limited to 60 ms and within/between-pass drift to 40 ms. Diagnostics now use the exact common estimator calculations; acceptance, normalization, profile schema and versions stay unchanged.
- Immediate cancellation before the task starts could leave a misleading audio failure. Check cancellation before starting and classify backend cancellation as cancellation; regression verifies report cleanup.
- “Short notes” did not explain pitch settling. Instructions now say to sustain each note for about half a second before muting. Synthetic full-pass C2 at 44.1/48 kHz yields sixteen reliable attacks; this does not establish physical guitar recognition.

## Validation

Six focused Core tests and eight focused App tests pass. Coverage includes exact failure gates, first-pass diagnostics, count/pitch quality distinctions, no save on failures, second-pass disagreement, retry/cancellation and route freshness. Generated project, bilingual localization catalog and UI-source typecheck pass. Native computer-use access works for read-only route inspection. Physical failed-pass cause and successful real calibration remain open, with no change to the acceptance policy to conceal that uncertainty.

Final local evidence: 105 App tests in 28 suites passed; the added real-backend-error propagation assertion passed in a subsequent focused lifecycle test. Six focused Core tests include the actual analyzer C2 PCM pass at both supported rates. 663 localization keys, project generation, UI-source typecheck and whitespace checks pass. Release .app/ZIP built and passed the bundle verifier (13 bilingual lessons, signatures, entitlements/resources/archive); no Debug .app recreated.

Native read-only inspection confirmed selected route and updated instructions. The old executable was closed through the native menu; the computer-use bridge then returned “native pipe closed before response”, including after reset, and could not reopen the app. The new diagnostic report's native layout/VoiceOver and real failed-pass cause are explicitly not claimed as verified. [Bundle evidence](../benchmarks/calibration-diagnostics-release-bundle.json).
