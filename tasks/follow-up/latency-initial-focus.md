# Neutral initial focus in timing settings

Status: `pending_user`

Opening timing settings should not begin editing a manual latency value. Start keyboard focus at the existing window title, while preserving Tab/click access to both fields and the deliberate focus of the measurement tap button. Use SwiftUI's default focus priority so normal user navigation takes precedence. No audio, stored values, validation or localization changes.

Acceptance: reopen the sheet with neither manual field editing; Tab/click can still reach the fields; tapping calibration can take keyboard focus. Rebuild the local Release app and record checks and same-agent review.

Implemented with a focusable title and `.defaultFocus` at automatic priority. The title has no decorative focus ring; the editable fields keep their native rings. No delayed or recurring focus reset is used.

Validation: local Release app/ZIP rebuilt, signature/resources/archive verified; 719 localized keys, generated project and UI-source typecheck passed. Native inspection confirmed the original field autofocus. After restarting into the new Release, native computer-use returned a closed-pipe error, including after reconnect/reset; reopening/Tab/tapping and VoiceOver acceptance remain pending. No new logic tests for this UI-only change.

Evidence: [same-agent review](../../docs/reviews/latency-initial-focus-review.md), [Release bundle](../../docs/benchmarks/latency-focus-release-bundle.json), [native acceptance](../../docs/USER-VALIDATION.md).
