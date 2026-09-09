# ADR 001 — AUHAL input and separate AVAudioEngine output

Status: implementation selected; physical input validation remains pending U01/U08.

## Decision

Use an input-only HAL Output Audio Unit (AUHAL) for capture. Enable input bus 1, disable output bus 0, bind the exact AudioDeviceID resolved from a persistent UID, request interleaved Float32 at the device's actual sample rate, and extract the selected channel in the C callback. A separate output-only AVAudioEngine owns the selected click output.

This avoids relying on an AVAudioEngine's implicit aggregate-device behavior for independently selected input and output. One engine does not need to own two physical devices. Keep both backends behind actor-isolated lifecycle APIs so synchronous hardware/property calls cannot block MainActor. They must still be coordinated by one application audio owner in task 11.

## Real-time handoff

An input-only AUHAL callback calls AudioUnitRender into preallocated interleaved memory, then copies the chosen mono channel and timestamps into a fixed-capacity SPSC ring. There are no Swift calls, allocation, logging, I/O, blocking locks, or tasks in the callback. C11 64-bit counters are required to be lock-free at compile time. Full/oversized packets increment an explicit drop counter without overwriting unread audio. A serial actor consumes packets and computes level metrics away from the callback and UI thread.

The ring owns 64 slots of up to 8192 mono frames. The input unit owns a fixed interleaved capture buffer. AudioOutputUnitStop/uninitialize/dispose precedes releasing its buffers and ring. A bounded drain processes at most 64 packets; sustained overload remains observable.

## Timing contract

Each packet carries the AUHAL input callback's host time, sample time, actual sample rate, frame count, and host-time validity. These timestamps are observations of the input stream, not a claim of the exact acoustic attack time. Task 15 must measure/normalize hardware and analysis latency. Raw sample counters from independent devices must never be compared.

The output probe schedules one 0.5-second click buffer in a loop at 120 BPM, using AVAudioPlayerNode and a future host-time start. It does not mix input into output. Full meter/count-in/tempo/transport functionality belongs to task 14. Distinct input/output device clocks can drift; full rhythm assessment is unavailable until task 15 validates route uncertainty.

## Evidence on this Mac (2026-09-09)

- Core Audio discovery and native UI identify **Scarlett 2i2 USB**, two input and two output channels, 44,100 Hz, 512-frame hardware buffer.
- Read-only system discovery also sees built-in microphone/speakers, a USB camera input, display output, Bluetooth devices, and a virtual device. Enumeration does not prove these routes are validated for practice.
- The native probe defaults to a USB device with input and output capabilities, without vendor-name matching or changing system defaults.
- After moving hardware operations off MainActor, the selected Scarlett output starts and stops its scheduled click without UI errors or a frozen interface. This verifies the software/device-start path; a person has not confirmed audibility.
- Capture awaits the macOS microphone permission flow. Computer Use explicitly disallows accessing UserNotificationCenter; no alternate method was used to approve or bypass that dialog. Input PCM, clean guitar signal, simultaneous input/output, channel identity under a played signal, unplug/replug, 48 kHz, and loopback remain unverified until the final user session.
- Package tests verify channel extraction, timestamps, FIFO wrap/overflow, bounds, and non-truncating reads. These are synthetic software checks, not physical input evidence.

| Route | Current evidence | Remaining gate |
| --- | --- | --- |
| Scarlett input + Scarlett output | Both discovered; output start/stop passed; capture awaits permission | U01/U08, then U02/U03 |
| USB input + built-in output | Separate backend design supports explicit selection; not exercised | U01/U03 |
| Built-in microphone + built-in speakers | Devices enumerated; not captured | U04/U08; click leakage and latency |
| Acoustic piezo into interface | Same input path by design; source-specific validation pending | U04 |

## Follow-up work

Task 11 adds production coordinator state, format/device change listeners, hot-plug/sleep recovery, preferences, source selection, and setup UX. Task 12 replaces level-only analysis with note evidence. Do not silently grade unsupported formats or routes. U01/U03/U04/U08 are deferred until after all implementations at the user's request.

## Sources

- Apple [TN2091: Device input using the HAL Output Audio Unit](https://developer.apple.com/library/archive/technotes/tn2091/_index.html); modern SDK declarations take precedence over deprecated examples.
- Installed macOS 26.5 SDK `AudioUnitProperties.h` for bus/property semantics and `AudioHardwareBase.h` for persistent device UID and caller-owned CFString properties.
- Apple [AVAudioPlayerNode.scheduleBuffer](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulebuffer(_:at:options:completionhandler:)).

## Task 11 implementation update (2026-09-10)

Production ownership is now `AudioSessionCoordinator` with serial hardware operations, purpose exclusion and generation checks. All native scenes share it. Explicit input/output UIDs and one-based channels persist in a separate versioned document; missing devices do not fall back. HAL property listeners plus periodic discovery detect route/format changes; sleep interrupts and wake requires an explicit restart.

The output probe now connects its player to the output node using the native channel count and populates only the selected output channel. This changes the earlier mono-mixer probe and requires physical channel/audibility validation under U01. Discovery currently sees built-in, virtual and Bluetooth devices; Scarlett is absent. No physical input/output claim is added by the synthetic coordinator tests.

Installed SDK `AudioHardware.h` and `AudioHardwareBase.h` were checked for listener registration/removal, alive/hog properties, sample-rate ranges, buffer-frame ranges and per-element/master volume controls. Read-only properties produce disabled controls; absent gain uses hardware-control guidance. No system default device property is modified. The full test/review record is in `docs/reviews/11-review.md`.
