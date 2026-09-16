# Input-level guidance — local review

Reviewer: implementation agent (same-agent review; not independent).

Scope: shared input meter, gain guidance, three screen integrations, localized/accessibility content and invalid/stopped-state behavior. No DSP, realtime callback, calibration model, persistence or assessment changes.

Findings and fixes:
- Existing linear amplitude meter made a −40 dBFS signal occupy only 1% of the bar. New logarithmic display uses one third of the −60…0 dBFS range.
- Existing setup status used a different clipping threshold (0.99) from the analyzer/calibration (0.995). Presentation now uses the latter.
- Stopped snapshots could otherwise look like live healthy input. Inactive display clears the readout; missing/invalid/zero-frame input cannot show a working level.
- Working amplitude is not evidence of pitch/preflight readiness. The text explicitly distinguishes them, and regression coverage checks this distinction.
- Gain targets refer to plucks; pauses and natural decay must not encourage constantly raising gain.

Validation: localization (625 en/uk keys), generated project and whitespace checks pass. App sources compile with Command Line Tools using the installed macOS 26.5 SDK, but local tests cannot load the missing Testing module. Full Xcode is currently gated by its unaccepted updated license. CI and rendering results to be appended after verification.

Open: actual selected-interface/guitar response, native sheet layout and VoiceOver. Computer-use bridge fails with “Sky Computer Use native pipe closed before response”. Offline ImageRenderer artifacts, when produced, do not close those hardware/native gates.
