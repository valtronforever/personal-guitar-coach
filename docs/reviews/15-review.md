# Task 15 local review — latency calibration

Implementing-agent review, not independent. 2026-09-10.

## Scope and fixes

Reviewed capture/render host mapping, actual selected-stream metadata, profile identity/decoding/storage, bounded pulse matching, clock validity, cancellation and en/uk UI integration.

- Device and stream latency selectors must be queried on the appropriate object. Resolve the selected stream by starting channel and physical format, then add its latency to device latency. Unknown values stay optional; invalid channel arguments return unknown without unsigned conversion.
- The capture host timestamp labels the first frame of the latest packet. Added `lastPacketFrames` and use `totalFrames − lastPacketFrames`; using totalFrames would introduce a buffer-dependent false drift. Tests vary packet size.
- Buffer/safety metadata is retained for route identity but not subtracted again. One normalized observed/expected formula plus residual offset handles ±50 ms. The backend interpretation remains a documented inference requiring U03 physical confirmation.
- A late cancellation could stop a newer calibration of the same purpose. Capture request UUIDs now protect permission-pending and active ownership. The coordinator regression cancels the first pending permission start, starts another run and verifies stale cleanup cannot stop it.
- Duplicate/stale frames cannot keep clock evidence fresh. Frame regressions, missing metadata after baseline and data loss invalidate the segment; maximum drift is retained across recovery. Separate-device duration and combined uncertainty gate rhythm eligibility.
- A fixed periodic pulse train could align after a missing beat. Irregular spacing and candidate ambiguity checks reject competing fits; misses/extras are bounded. Offline tests cover empty/excess/ambiguous evidence and a missing first pulse.
- App history counters are checked before unsigned subtraction. Lost event/quality prefixes, clipping, missing clocks, route changes and timeout cannot save a partial profile. The completed synthetic App flow saves +50 ms; changing the buffer interrupts without saving.
- The Xcode preview composition also supplies the new shared CalibrationStore environment, so opening calibration from a preview does not miss its dependency.
- Storage publishes only after an atomic successful write, validates envelope/profile identities and preserves corrupt/future documents. App failure/retry/restore tests confirm previous profiles remain intact.

## Validation and limits

97 automatic core tests pass, plus 1 skipped opt-in hardware test (98 reported). 38 App tests pass. Actual TransportPlan PCM → MonophonicAnalyzer → LoopbackEstimator offline tests recover all 12 markers for ±50 ms at 44.1/48 kHz within 20 ms and residual p95 ≤20 ms; positive-delay variants include a weak background sinusoid. Synthetic results are not physical USB measurements.

338 en/uk keys, current generated project and UI-source type-check pass. Debug and Release local native .app builds/ad-hoc signing pass. Native read-only UI inspection: English/dark and Ukrainian/light, scrollable form, visible manual semantics, no-route actions disabled. No capture, permission request or loopback cable was exercised. U03/U08/U09 and actual Xcode UI execution U07 remain open. Tasks 16/17 consume the eligibility service in assessment.
