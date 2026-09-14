# Personal timing synchronization

The main calibration UI is Audio setup → Timing synchronization. Cable loopback is not offered. Legacy measured/manual/estimated profiles and the old offline loopback estimator remain readable/testable for historical compatibility; the wizard does not invoke them.

## Procedure

Select the guitar input and its mono channel independently from the metronome output/channel. Bluetooth headphones can be the output without selecting their microphone. Select an open string from the current instrument tuning (default string 3, numbering 1 = thinnest). Tune it first, use a clean signal, mute other strings and use headphones to avoid click leakage into a microphone.

Each of two passes starts with a clean sustained pitch check (up to 20 seconds). The audio renderer then plays four listening clicks and sixteen practice clicks at 60 BPM. Play short separate attacks on the sixteen clicks. Follow the sound: the progress bar is only a display. Between passes capture stops. After both pass, review the offset/repeatability and explicitly Apply. Nothing is saved by a cancelled or unsuccessful pass; storage failures permit retry.

The correction includes residual input/output latency **and personal anticipation/lateness**. Two consistent passes demonstrate repeatability, not absolute hardware accuracy. A constant correction cannot remove varying Bluetooth delay, and it does not reduce the audible delay of live guitar monitoring.

## Evidence and bounds

`personal-two-pass-16-v1` requires all sixteen reliable attacks within ±400 ms of their normalized expected beats. The measurement window extends ±450 ms around its first/last beats; listening/preflight attacks outside it are ignored. Within it, wrong pitches (>50 cents), low clarity (<0.9), uncertain attacks, missing or extra attacks fail the pass. Reject nonfinite/nonmonotonic timestamps, capture gaps, clipping, lost bounded histories, route/revision changes, clock loss after establishment and relative clock drift >20 ms. Capture remains alive for a final 1.8 s plus reported input/output hardware delays to resolve trailing attacks.

The per-pass offset is the median. With sixteen samples nearest-rank p95 absolute deviation is the maximum; require ≤60 ms. The difference between last-five and first-five medians must be ≤40 ms. The two median offsets must agree within 40 ms. Final offset is the mean of the two medians. Repeatability allowance = maximum per-pass deviation + half the between-pass difference + maximum absolute per-pass drift + 10 ms detector allowance + maximum clock drift from either pass. These bounds are engineering policy, not measured human or hardware capability claims. Delays beyond this sub-beat bound fail instead of silently wrapping by a beat.

Domain `PersonalSyncEvidence` persists algorithm version, both offsets/spreads/drifts, chosen string and exact instrument. `CalibrationProfile.method = personal` is exclusive of measured loopback evidence. `calibration-profiles.json` now writes schema 2; schema 1 remains readable and migrates on the next explicit mutation. Old practice records keep their original parameters/results.

## Freshness and scoring

A saved personal profile is usable only after Apply in the current audio session, at the same coordinator route revision and with the same instrument. Its in-memory receipt is not persisted. Relaunch, sleep/wake, hardware notifications, reconnect observed by discovery, or format/channel/route changes require a new two-pass wizard. This intentionally favors rechecking over silently trusting a stale Bluetooth connection. Manual settings changes on an interface that the OS cannot observe (such as physical monitoring controls) also require the user to rerun the wizard.

Practice freezes the eligible profile before capture. Lesson errors never update it. The existing formula remains:

`error = observedNormalized − expectedNormalized − residualOffset`

`monophonic-assessment-2` uses a maximum tolerance of ±200 ms for personal synchronization, still capped at 45% of the closest expected-note interval. Measured profiles keep ±100 ms. Total repeatability allowance + 30 ms onset allowance + live clock drift must fit within half the effective tolerance, otherwise rhythm/overall remain unavailable. Personal timing is `RhythmCapability.approximate`, distinct from `.available` measured timing. Summary, history and conditions identify the method; summary shows effective tolerance. Short calibration does not establish long-run physical clock accuracy: personal mode relies on live drift checks and remains approximate for all durations. The measured profile's historical duration gate remains unchanged.

Assessment v1 decoding remains supported; stored results are validated without rerating. Approximate results cannot claim a measured capability. Different methods/profiles/scoring versions do not enter compatible-score comparisons.

## Cursor

Practice and wizard progress subtract the reported output hardware latency from rendered position (fallback: renderer presentation latency). Audio buffers and assessment timestamps retain the audio-clock contract. The personal residual is never treated as output-only latency: it also contains input latency and playing bias. Therefore unknown/unreported Bluetooth delay may still cause a visual/audio mismatch. There is no claim of physically calibrated cursor alignment.

## Physical acceptance still open

Verify two complete passes and a familiar rhythm lesson through a real interface with wired headphones, then with separate Bluetooth output. Repeat after reconnect/sleep/format changes, and test microphone click leakage, clipping, missing notes and cancellation. Confirm English/Ukrainian layout, keyboard focus and VoiceOver on the native sheet. Automated synthetic DTO/PCM tests cannot close these gates.
