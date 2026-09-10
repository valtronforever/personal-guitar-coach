# ADR 003 — route calibration and host time

2026-09-10. Implemented software; physical validation remains U03/U08/U09.

## Timestamp contract

The AUHAL callback forwards its timestamp to `AudioUnitRender` and copies the returned channel with that same host timestamp. The analyzer labels onsets from the first packet host origin plus its capture-local frame offset; resolution time is separate from onset time. Apple's [TN2091](https://developer.apple.com/library/archive/technotes/tn2091/_index.html) demonstrates the timestamp handoff and single-device AUHAL topology. The installed macOS SDK's `AudioHardware.h` distinguishes input acquisition and output delivery timestamps from callback wakeup time. We never timestamp attacks with a UI timer or the time an analysis result arrives.

The output epoch comes from `AVAudioPlayerNode` sample time paired with its node render host time. The scheduled future start is only a scheduling hint, not grading evidence. Apple's [presentationLatency](https://developer.apple.com/documentation/avfaudio/avaudioionode/presentationlatency) describes device plus stream latency. The SDK's `AudioHardwareBase.h` separately defines device latency, stream latency and safety offset. Query the selected stream object, identified by starting channel and physical channel count; unknown metadata remains optional.

Our normalization is an implementation inference that must be checked with physical loopback. Normalize input acquisition to the earlier physical input by subtracting input device + selected-stream latency. Normalize render time to physical output by adding output device + selected-stream latency. Buffer size and safety offset are route diagnostics, not additional corrections to an already labeled buffer. Unknown hardware latency is left uncompensated and must be absorbed by measured residual evidence; an estimate never unlocks rhythm scoring.

```text
observed = inputOnsetHost − inputHardwareLatency
expected = outputRenderEpoch + outputFrame / outputRate + outputHardwareLatency
timingError = observed − expected − residualOffset
positive timingError = late
```

Do not subtract DSP resolution delay or another round-trip estimate from that final expression. ±50 ms tests verify the sign and one-time application. Hardware interpretation changes require a new normalization/backend version and fresh profiles.

## Measurement and uncertainty

The calibration transport renders only irregular 12-ms pulses, at seconds 1, 3, 4, 6, 9, 11, 14, 15, 17, 20, 22 and 25. The long option repeats the pattern across approximately 15 minutes. It uses the same chosen input/output channel and sole audio coordinator as practice. No input monitoring or PCM persistence is added. Cable preparation is explicit; low levels and direct monitoring off are explained in both languages.

Reuse onset timestamps, including events without reliable pitch: a short calibration pulse is not a guitar-note success. Reject invalid/clipped samples, lost rolling event/quality history, route changes, missing clocks, interruptions or cancellation. Wait 1.4 seconds after transport completion for the last input event to resolve. A bounded histogram and ordered one-to-one matching find up to eight candidate residual offsets within ±1 second. Require at least eight matched pulses over ten seconds, at most 20% unmatched evidence, and an unambiguous fit. Save only a completed measurement. Silence or extra attacks cannot produce a partial successful profile.

Residual offset is the median. The stored uncertainty allowance includes residual p95, a 10-ms detector allowance, measured pulse-train drift and maximum observed relative clock drift. These are conservative engineering allowances, not a statistical guarantee on unseen hardware. Offline actual-renderer → actual-analyzer tests recover all twelve pulses at 44.1/48 kHz for ±50-ms injections within 20 ms, with residual p95 at most 20 ms. They do not establish physical round-trip precision or acoustic click robustness.

Each endpoint identity includes UID, channel, actual rate/buffer and optional latency/safety metadata. Backend, detector and OS versions also participate. Profiles use validated Codable models and an atomic version-1 `calibration-profiles.json` envelope; corrupt/future documents are preserved. Manual/estimated profiles are explicitly unverified. Another route never silently reuses the active profile.

## Clock and rhythm eligibility

For input, the latest host timestamp labels `totalFrames − lastPacketFrames`, not the end of the packet. Track changes in each stream's own frame-to-host anchor, then compare those changes; never compare device sample counters directly. Repeated frames expire after 500 ms; regressions, loss or invalid metadata invalidate the segment. Retain maximum drift even after the instantaneous difference recovers. A request UUID protects capture startup and cleanup against stale feature tasks.

Rhythm requires a matching measured profile, fresh clocks and combined calibration allowance + practice onset allowance (30 ms from the development benchmark) + live maximum drift no greater than half the exercise timing tolerance. Separate devices also require measured duration at least as long as the attempt. The measured profile alone is not blanket permission to show rhythm or overall scores. Tasks 16/17 consume this gate and freeze its evidence into the attempt; pitch practice and tuner remain available without it.

## Deferred physical procedure

After all 22 software tasks, use the actual USB interface and a compatible output-to-input cable. Record route UID/channel/rate/buffer, hardware latency metadata, input mode, gain and monitoring setup. Run short calibration, repeat after changes, and independently measure compensated residual p95 (target ≤20 ms or narrow eligibility). Run the long option with the supported split-device route and compare first/last pulses under UI load. Confirm reconnecting the guitar preserves the applicable route/input mode. Test missing cable, clipping, hotplug and sleep. No microphone permission or hardware-loopback claim is made by the synthetic tests.
