# Final user and hardware validation

The user requested that checks requiring their help take place **after all 22 implementation tasks**. These checks do not block software implementation or merging reviewed code. They remain open evidence requirements, not presumed successes. No distribution or notarization is planned.

## Pending checks

| ID | Related tasks | Needed evidence | State |
| --- | --- | --- | --- |
| U01 | 02, 11 | Electric guitar into the user's USB interface: input/channel identity, clean level, simultaneous headphone click, unplug/replug, 44.1/48 kHz where supported | Pending final user session |
| U02 | 12, 13, 17 | Actual guitar recordings/playing: low/high notes, repeated attacks, sustain, alternate tuning, pitch/onset accuracy and tuner behavior | Pending final user session |
| U03 | 15, 17 | Loopback or otherwise measured route latency/uncertainty and long-session drift; correct early/late grading | Pending final user session |
| U04 | 11, 12, 20 | Acoustic guitar through a microphone or piezo pickup: source selection, background noise and click leakage, reliable/uncertain feedback | Pending final user session |
| U05 | 19, 20, 22 | Beginner walkthrough of lessons, accessibility, musical fingering/notation, and localized feedback with the user's playing | Pending final user session |
| U06 | 21 | Unseen real guitar chord recordings with labels for held-out polyphonic research validation | Pending final user session |
| U07 | 01, 20 | Complete/repair Xcode 26.6 system components: xcodebuild project commands fail loading IDESimulatorFoundation because /Library/Developer/PrivateFrameworks/DVTDownloads lacks a symbol. The standard runFirstLaunch process was stopped after remaining idle without output; no success claimed. Then run Xcode UI tests. Native SwiftPM .app builds and package tests remain usable. | Pending final environment validation |

Record the Mac/macOS, interface/driver, channel, actual sample rate/buffer, source type, procedure, observed result, and any fix/retest here. Do not record private audio without an explicit recording action. Synthetic and software-only checks belong in the individual task evidence and cannot close these hardware rows.
