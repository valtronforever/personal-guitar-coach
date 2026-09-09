# Task 11 — local implementation review

Reviewed by the implementing agent on 2026-09-10; this is not an independent review. Software is implemented; physical capture/route checks remain pending U01/U04/U08.

## Scope and fixes

- Replaced per-sheet `AudioProbeModel` pipelines with one application `AudioSessionStore` / `AudioSessionCoordinator`. Both main-window and Settings sheets use the same selection and audio owner. Hardware calls remain outside MainActor; preview dismissal only stops setup activity, not a tuner/practice owner.
- Removed the prototype's automatic fallback when a saved UID disappears. Missing devices retain their identity and channel; HAL device/format notifications and periodic discovery interrupt an active stream. Returning hardware and wake refresh availability without restarting capture.
- Serialized input/output mutations. A deliberately suspended start, concurrent Stop and subsequent Start confirm the old completion cannot stop the new pipeline. Partial backend-start failure now queues cleanup before another activity. Twenty repeated start/stop cycles keep at most one active input and preserve explicitly selected channel 1/2.
- Permission denial, restricted/not-determined state, cancellation while awaiting permission, busy-device detection, unsupported format, stopped streams and data loss have explicit paths. Silence with arriving frames remains healthy capture. Drop/invalid-sample/timestamp-gap counters cannot be silently treated as a musical failure. Interruption retains the last metrics as a labelled historical snapshot.
- Added sample-time validity to the C packet metadata and worker-side continuity/non-finite checks. Callback allocation, logging and locking behavior did not change; the ring remains bounded and channel extraction stays in C. No raw PCM persistence or software monitoring was added.
- Sample rate, buffer range/settable flags and selected-channel or master input level are queried from HAL. Applying a control stops capture, rechecks capability and refreshes actual values. Gain has an explicit Apply action so keyboard changes are not dependent on a drag-end callback. Only selected device properties are mutated; no system-default routing property is written.
- Output test clicks use the explicitly selected channel in the output device's native channel count, with all other client channels silent. Physical output channel mapping/audibility remains unverified in this task.
- Review found that two sequential stop/configure calls could erase the route-change reason. Configure now preserves an existing interruption. External stream-format changes also advance the route revision for future calibration invalidation.
- Audio preferences use a separate versioned atomic document. Load/save failures preserve original files; write failure does not publish an unsaved selection. Explicit None clears the UID and resets the corresponding channel; corrupt/future preference documents disable editing with a localized retry notice.

## Evidence

- Core Swift Testing: **57 tests in 9 suites**. Audio tests use a synthetic runtime/permission provider; C ring tests cover selected channel extraction, FIFO/bounds/overflow and timestamp transport. Persistence tests cover audio-selection round-trip, invalid values, corrupt/future files and independent history clearing.
- App Swift Testing: **30 tests in 8 suites**. New cases verify missing saved UIDs, channel persistence, explicit clearing, failed saves and preserved future-version files without requesting permission.
- Localization: **243 en/uk UI keys**; source format/placeholders passed validation.
- Generated project check and UI-test source type checking passed. Actual UI XCTest execution remains U07.
- Native Debug and Release `.app` builds, strict ad-hoc signature verification and `git diff --check` passed.
- Native CUA walkthrough: both setup entry points share MacBook Pro Microphone / MacBook Pro Speakers and explicit output channel 2; current microphone format reads 48,000 Hz / 512 frames, with a readable master input-level capability. Both locales and dark/light appearance were inspected. None clears selections and resets channels to 1. Test selections were cleared and System language/appearance restored.
- Current discovery differs from task 02: Scarlett is **absent** from the device menus on 2026-09-10. Built-in, Microsoft Teams virtual audio and MOMENTUM 4 devices are listed. This is discovery evidence only. No input Start, test click, sample-rate/buffer mutation or gain application was performed during this walkthrough.

## Open gates

U01: physical USB input channel identity, 44.1/48 kHz, simultaneous click/input, hot-plug, busy-device/format/sleep behavior and sustained capture. U04: acoustic microphone/piezo and click leakage. U08: normal microphone permission flow; the earlier UserNotificationCenter restriction is not bypassed. Full calibration and rhythm-route capability remain task 15/U03. Monophonic DSP replaces level-only observation in task 12.
