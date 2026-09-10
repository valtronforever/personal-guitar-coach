# Final user and hardware validation

The user requested that checks requiring their help take place **after all 22 implementation tasks**. These checks do not block software implementation or merging reviewed code. They remain open evidence requirements, not presumed successes. No distribution or notarization is planned.

## Pending checks

| ID | Related tasks | Needed evidence | State |
| --- | --- | --- | --- |
| U01 | 02, 11 | Electric guitar into the user's USB interface: input/channel identity, clean level, simultaneous headphone click, unplug/replug, 44.1/48 kHz where supported | Pending final user session |
| U02 | 12, 13, 17 | Actual guitar recordings/playing: low/high notes, repeated attacks, sustain, alternate tuning, pitch/onset accuracy and tuner behavior | Pending final user session |
| U03 | 15, 17 | Loopback route latency/uncertainty and long-session drift; correct early/late grading. Task 15 software and synthetic ±50-ms paths are implemented; follow ADR 003 for physical measurements, input-mode consistency and independent residual p95. | Pending final user session |
| U04 | 11, 12, 20 | Acoustic guitar through a microphone or piezo pickup: source selection, background noise and click leakage, reliable/uncertain feedback | Pending final user session |
| U05 | 18, 19, 20, 22 | Beginner walkthrough of lessons, accessibility, musical fingering/notation, and localized feedback with the user's playing | Pending final user session |
| U06 | 21 | Unseen real guitar chord recordings with labels for held-out polyphonic research validation | Pending final user session |
| U07 | 01, 04, 17, 18, 19, 20 | Complete/repair Xcode 26.6 system components: xcodebuild project commands fail loading IDESimulatorFoundation because /Library/Developer/PrivateFrameworks/DVTDownloads lacks a symbol. The standard runFirstLaunch process was stopped after remaining idle without output; no success claimed. Then run Xcode UI tests. Native SwiftPM .app builds and package tests remain usable. | Pending final environment validation |
| U08 | 02, 11, 13, 20 | Approve the app's normal macOS microphone permission dialog, then validate actual Scarlett input. The computer-use tool disallows UserNotificationCenter; this restriction was not bypassed. The input permission flow was left unconfirmed and the probe closed. | Pending final user session |
| U09 | 14, 15, 16, 20 | Audible click/example on the selected USB headphone channel at several BPM; 15-minute measured output timing and UI-load run; note/cursor alignment, loop boundaries, and input click leakage. Task 14 native built-in output was exercised silently; this does not establish audibility or round-trip latency. | Pending final user session |
| U10 | 16, 17, 18, 19, 20 | Full physical practice: lesson handoff, tuning confirmation and clean signal preflight, count-in alignment, first/last attacks, healthy all-missed attempt, pause/seek/tempo/retry, repeated independent attempts over 15 minutes, unplug/sleep during final drain, bounded memory and no cross-attempt evidence. Repeat includes a finalization pause and new count-in. Verify electric DI first, then microphone/piezo. | Pending final user session |

Task 02 discovery (2026-09-09): Scarlett 2i2 USB was connected with 2 inputs, 2 outputs, 44,100 Hz and a 512-frame buffer. Native output click start/stop succeeds; audibility, input PCM and played-guitar evidence are still pending. Task 01 Xcode Debug/Release builds passed on a clean GitHub runner in PR #23; local Xcode UI tests still require U07.

Record the Mac/macOS, interface/driver, channel, actual sample rate/buffer, source type, procedure, observed result, and any fix/retest here. Do not record private audio without an explicit recording action. Synthetic and software-only checks belong in the individual task evidence and cannot close these hardware rows.

Task 09 adds independent UI-test source type checking (`Scripts/check_ui_sources.py`), now passing locally and included in CI. It verifies Swift/XCTest API compilation without loading the broken xcodebuild component; U07 still requires actual UI-test execution.

Task 11 discovery (2026-09-10): Scarlett is currently absent from the native input/output menus. MacBook Pro Microphone reports 48,000 Hz and 512 frames with master input-level control; MacBook Pro Speakers exposes two selectable output channels. Built-in, Teams virtual audio and MOMENTUM 4 are listed. No input capture, test click or hardware parameter change was attempted in this task. Shared settings/UID-channel persistence and en/uk dark/light UI were verified; test selections were cleared afterwards. U01/U04/U08 remain open, including physical output-channel mapping after the explicit-channel output change.


Task 12 software evidence: MPM/energy-flux analysis runs on the sole PCM worker; 71 core tests and a 3,360-case full offline benchmark pass. Public Iowa acoustic clips are development data with independent estimated annotations, not the user's recordings or proof of electric-interface capture. U02 additionally needs a held-out clean electric DI corpus/live playing, dominant harmonics/low notes, onset repeats and actual tuner settling; U04 needs room noise/piezo/click leakage. No input permission or capture was attempted for task 12.

Task 17 visual-check limitation (2026-09-10): the native computer-use connection returned “Sky Computer Use native pipe closed before response” after selecting the synthetic assessment fixture. The app process remained running; reconnecting and resetting the tool did not restore observation. The new assessment card has build/state/localization coverage, but its native visual/accessibility inspection is still pending. No microphone or system permission was requested. Repeat the en/uk and light/dark assessment-fixture inspection once the connection is available.

Task 18 adds results/history/recommendation flows to U05/U07/U10. Inspect both languages and themes, narrow-window wrapping, keyboard/VoiceOver TAB symbols and evidence disclosure, result → audio setup sheet handoff, saved tuning → tuner, repeated retry → fresh confirmation/count-in, and history language changes without score mutation. The native computer-use channel still returned the same pipe-closed error on reconnect; no visual success or executed UI-test result is claimed. Software tests cover thresholds, archive restoration, comparisons and navigation state.

Task 19 expands the course to six original en/uk lessons (see `docs/STARTER-COURSE.md`). U05/U07 must inspect all steps and long texts in both languages/themes, first-fret comfort, C-major and pentatonic string changes, and the Em shape versus separate-note practice distinction. U10 should include at least the repeated-note/rest rhythm exercise and Em arpeggio on the real guitar. Synthetic event fixtures validate targets, grading and saved retry links only; they do not establish live performance accuracy.

Task 20 adds the consolidated [product acceptance matrix and 15-minute physical protocol](VALIDATION.md). Signed local Release/ZIP and offline resources are verified; final offline launch, icon presentation, real-time CPU/RSS/clock drift and callback loss measurements remain U07/U09/U10. The accelerated 900-second synthetic-event benchmark does not close any physical gate. No Scarlett was connected during the task-20 discovery check.

Task 21 delivered a [reproducible chord feasibility study](research/21-chords.md) and no-go ADR. U06 still needs independent electric DI/real-distortion/microphone/piezo recordings and human note/strum labels. The twelve-recording public acoustic player-held-out subset and its simulated distortion fail integration gates and do not close those physical requirements. Product chord scoring remains disabled.
