# Initial timing-settings focus — same-agent review

Scope: initial focus in CalibrationView, reviewed by the implementation agent. No audio, settings, field parsing or saved-value changes.

Native accessibility inspection reproduced the bug: the selected control immediately after opening was `sync.output.manualValue`. The screen had no preferred initial focus target. The fix gives the existing title focus eligibility and selects it with SwiftUI's automatic-priority default focus. Only the title suppresses its focus effect; both manual text fields retain their visible editing ring and remain enabled according to the existing policy.

Review checked that there is no asynchronous clearing or focus assignment on audio refresh, so updates cannot repeatedly end a user's edit. Automatic priority does not override explicit user navigation. SyncTapButton's deliberate first-responder changes when measurement becomes enabled remain unchanged. The title adds a neutral keyboard focus stop before the form.

Local Release app/ZIP build and signature/resources/archive verification passed. Generated project, 719 EN/UK localization keys and UI-source typecheck passed. No new logic tests for this UI-only change. [Bundle evidence](../benchmarks/latency-focus-release-bundle.json).

Live follow-up could not complete: native computer-use successfully inspected the old process and closed its sheets/quit it, but after launching the new Release the connection returned `Sky Computer Use native pipe closed before response`. Reconnect and tool reset did not recover it. A running Release process was observed; new sheet focus/Tab/click/tap-button and VoiceOver behavior remains pending in USER-VALIDATION. Do not treat compilation as proof of focus behavior.

API reference: [Apple defaultFocus](https://developer.apple.com/documentation/swiftui/view/defaultfocus(_:_:priority:)) — the default automatic priority allows user-driven focus navigation to take precedence.
