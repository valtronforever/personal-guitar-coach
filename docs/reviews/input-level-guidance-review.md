# Input-level guidance — local review

Reviewer: implementation agent (same-agent review; not independent).

Scope: shared input meter, gain guidance, three screen integrations, localized/accessibility content and invalid/stopped-state behavior. No DSP, realtime callback, calibration model, persistence or assessment changes.

Findings and fixes:
- Existing linear amplitude meter made a −40 dBFS signal occupy only 1% of the bar. New logarithmic display uses one third of the −60…0 dBFS range.
- Existing setup status used a different clipping threshold (0.99) from the analyzer/calibration (0.995). Presentation now uses the latter.
- Stopped snapshots could otherwise look like live healthy input. Inactive display clears the readout; missing/invalid/zero-frame input cannot show a working level.
- Working amplitude is not evidence of pitch/preflight readiness. The text explicitly distinguishes them, and regression coverage checks this distinction.
- Gain targets refer to plucks; pauses and natural decay must not encourage constantly raising gain.

Validation: localization (626 en/uk keys), generated project and whitespace checks pass. App sources compile with Command Line Tools using the installed macOS 26.5 SDK, but local tests cannot load the missing Testing module. Full Xcode was initially gated by its unaccepted updated license; the user subsequently accepted it (see final verification below).

Open: actual selected-interface/guitar response, native sheet layout and VoiceOver. Computer-use bridge fails with “Sky Computer Use native pipe closed before response”. Offline ImageRenderer artifacts, when produced, do not close those hardware/native gates.

Follow-up review: the English silent-state guidance was truncated in the first offline rendering. Added intrinsic vertical sizing for both guidance paragraphs and removed duplicate dBFS units from the RMS label. Re-rendered and visually inspected all four English/Ukrainian light/dark PNGs at 600 pt width in `build/input-level-renders/`: text is complete, ticks and cursor are readable. The renderer ran against the production SwiftUI view via a standalone CLT executable using SDK 26.5; it is not native app interaction.

All four numerical/state regression scenarios also passed locally in a standalone executable using the production reading model (Swift Testing assertions translated to preconditions because CLT lacks Testing). CI's first run found a nested `#require` expansion unsupported by its Swift Testing toolchain in the optional renderer; split the two optional unwraps into separate statements. Full CI rerun passed in merged PR #56.

Final verification (2026-09-16): CI passed 173 Core tests, 96 App tests, localization/project/audio checks, signed Release packaging/XPC smoke and both native Xcode builds. After user license acceptance, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/build_local.py --configuration release --archive` completed locally. `Scripts/check_local_bundle.py` verified the installed app and ZIP, ad-hoc hardened-runtime signatures, sandbox entitlements, all 13 bilingual lessons and compiled translations. The deployment minimum remains macOS 14.0; no Debug app was recreated. [Bundle evidence](../benchmarks/input-level-release-bundle.json). App launch, live guitar and native VoiceOver acceptance are still open; this build does not claim them.
