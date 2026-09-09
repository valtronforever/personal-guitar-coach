# Task 14 local review — metronome and example playback

Implementing-agent review, not independent. 2026-09-10.

## Scope and fixes

- Checked sample scheduling, count-in/seek/loop boundaries, reference synthesis, output routing, host timestamps, cancellation/ownership, view transitions and localization.
- Rounded beat or loop lengths would accumulate timing drift. Every boundary is calculated from its absolute tick. Offline 15-minute tests at five tempos/two rates retain at most half a sample of quantization; PCM is invariant under chunk partitioning.
- Releasing a previous view could stop a newer preview. Reserved request UUIDs and generation checks now protect pending starts as well as active playback; cancelled/restarted coordinator and app pause/seek/resume tests pass.
- Preview must work without capture permission and must not poll input for liveness. Coordinator gives it output-only ownership, skips input liveness/permission revocation for that owner, and still monitors output route changes. Practice output requires an existing practice capture and its renderer cannot emit reference tones.
- Stopping an engine at the last rendered frame could truncate output still in the presentation pipeline. Completion waits a bounded presentation estimate plus buffer/tail, then stops and clears the node. Native silent output test reached completion with a valid host anchor.
- Inline playback options clipped lower strings at minimum window size. Moved options into a popover, used compact 32-point fretboard rows in the lesson reader and icon buttons with localized labels/help. Native Ukrainian light minimum-window check shows all six strings and instructions.
- The popover initially used the system language. Explicit locale injection fixes its Ukrainian labels and paragraphs; inspected in the native app.
- Request validation bounds events, duration and rendering memory; huge Int64 durations reject without overflowing. Zero-output device/channel validation does not construct an invalid closed range.

## Validation and limits

85 automatic core tests pass; 1 opt-in hardware test is skipped in the normal 86-test run. 35 app tests pass. Transport subset rerun after duration validation. 304 en/uk keys, project generation check and Swift 6 UI source type-check pass. Debug/Release native app builds and ad-hoc signing pass.

Explicit silent backend test: MacBook Pro Speakers / BuiltInSpeakerDevice, 44100 Hz, 512 frames, output channel1, both volumes zero. One test passed in 0.674 s; rendered16433 frames and reported presentation estimate0.001474 s with valid host anchor. This verifies actual AVAudioPlayerNode progression/completion/cleanup, not audible output or calibrated latency. No input capture or permission request.

UI tests are source-checked only (U07). Physical click/example audibility, 15-minute output measurement, USB routing and input leakage remain U09. Normal language/appearance preferences were not changed: temporary process launch arguments were used for Ukrainian/light inspection. CI must pass before merge; its result will be recorded after the PR run completes.
