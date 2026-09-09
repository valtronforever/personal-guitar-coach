# Task 02 — local review

Reviewed by the implementing agent on 2026-09-09. Scope: native audio probe, AUHAL callback/lifetime, SPSC handoff, actor boundaries, device selection, output scheduling, permissions, and localizations.

## Findings and fixes

1. Core Audio property reads initially passed a managed CFString reference through a raw pointer. Replaced this with Unmanaged and takeRetainedValue, following the SDK's explicit caller-ownership contract. Rebuild is warning-free.
2. Initial device default selection matched the Scarlett vendor name. Replaced it with the USB transport capability and input/output channel checks; selection remains a stable UID.
3. A real probe run blocked MainActor inside AudioUnitSetProperty while a permission request was pending. A one-second process sample located the blocking stack in ClickOutput.start. Moved capture/output lifecycle into separate actors, moved enumeration off MainActor, added visible waiting states, and guarded cancellation/restart with a generation token and serialized cleanup. After rebuilding, Scarlett output starts/stops and the sheet remains responsive.
4. Used modern Core Audio error constants instead of implicit Carbon MacErrors declarations; the C target now compiles without an undeclared-header dependency.
5. Buffer review verifies release/acquire publication, exactly one producer/consumer, explicit overflow, no truncation on undersized reads, fixed allocation, and lock-free counter requirements. Teardown stops/uninitializes/disposes the input unit before buffer release.

## Checks

- Seven package tests passed after fixes: two domain compatibility tests and five realtime-buffer tests, including a 10,000-packet concurrent producer/consumer sequence check.
- Debug and Release .app builds and strict ad-hoc signature verification passed.
- Native device picker shows Scarlett 2i2 USB / channels 1–2 / 44,100 Hz / 512 frames. Output-only click start/stop and sheet dismissal passed after the concurrency fix.
- No input capture or audible guitar/click verification is claimed. The microphone-permission system UI is inaccessible to the computer-use tool. Its explicit access denial was respected.
- Full backend decision, timing assumptions, and route matrix: `docs/decisions/001-audio-backend.md`.

## Remaining evidence

U01/U02/U03/U04/U08 are required for real signal, routing, latency, audibility, format change, and recovery claims. Task 11 supplies production recovery/state handling. These do not block merging the reviewed prototype or implementing dependent tasks, per the user's instruction.
