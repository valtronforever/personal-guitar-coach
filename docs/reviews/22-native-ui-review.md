# Task 22 — final native UI follow-up

Date: 2026-09-10. Same-agent review, after all 22 original implementation PRs were merged. Baseline: `a36a019ad3627dfadd9e48b1b0de63307c7835e7` (PR #44). Follow-up branch: `codex/22-native-ui-validation`.

## Scope and observations

The CUA native connection recovered when selecting the local Release app by its full path. Actual window accessibility trees and screenshots were inspected; these observations are distinct from the earlier offline geometry renders. The Release window had no Debug menu. Read-only process inspection identified the Release executable at `build/release/PersonalGuitarCoach.app/Contents/MacOS/PersonalGuitarCoach`.

- Open strings: staff E3/E5 labels correctly distinguish sounding E2/E4; quarter rests are visible. Clicking high E selects its lesson step. A physical click followed by Right/Space moves to the final rest; Left/Shift-Space extends the selection. AX activation alone does not necessarily establish keyboard focus, so keyboard claims use physical clicks.
- C major: first-bar written C4/D4/E4/F4 and second-bar G4/A4/B4/C5 agree with sounding pitches and quarter-note durations. Right/Space crosses bar 1 → 2, keeps focus on G4 and selects the matching lesson step. Switching to TAB preserves `up-5` / G3 selection.
- Changing System language to Ukrainian and System appearance to Dark preserves the selected lesson and event. Ukrainian lesson, TAB, Staff, practice preflight, idle tuner and empty Progress screens were inspected. F-major key signature displays B-flat while the natural B4 in the C-major exercise receives a natural sign. A resized window retains staff-panel scrolling; this is not a measured minimum-size or VoiceOver acceptance claim.
- Lesson → Practice keeps the C-major exercise, Standard tuning, 60 BPM and four bars. With no selected route or physical-tuning confirmation, Start stays disabled and the explanation identifies the missing audio route. No confirmation checkbox, input capture, playback or permission prompt was activated. Tuner also stays idle; history remains empty.

## Defect and correction

Native keyboard focus drew a second rectangle at the unoffset button origin, to the left of the staff notes, in addition to the correct Canvas indicator. This was reproducible after physical click → arrow → Space, including across a bar boundary. `focusEffectDisabled()` suppresses that displaced native effect; the existing note-position Canvas outline/dash, focus binding, accessible button, 44-point hit target and keyboard handlers remain active.

The rebuilt Release was launched and checked again: C5 at the end of bar 2 → Right/Space selects B4 at the beginning of bar 3 with a single correctly positioned dashed outline. Right/Shift-Space selects A4 as well; B4 keeps its solid selected outline and A4 has the focused dashed outline. The displaced left rectangle is absent. System language and appearance were restored and verified afterwards; both selected IDs survived that change.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/build_local.py --configuration release --archive` passed, including lesson/resource/signature checks.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter StaffTests`: all 6 tests passed (0.008 s). No new model-mirroring test was added for a native focus decoration; the defect and fix were checked in the actual window.
- `python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --archive build/release/PersonalGuitarCoach.zip --report docs/benchmarks/22-native-release.json` passed. That automated report deliberately leaves `appLaunchVerified=false` because the packaging checker never launches apps; the separate manual native launch evidence is recorded above.
- `git diff --check` passed. Full CI evidence and the follow-up merge are linked from issue #22.

## Still open

Selecting the Debug synthetic-results menu again returned “Sky Computer Use native pipe closed before response”; no result-card visual pass is claimed. Re-selecting the Release app restored observation, so the error does not invalidate the successful Release checks above. Actual VoiceOver use, results/retry interaction, full course walkthrough, measured minimum-window checks and Xcode UI-test execution remain pending.

Scarlett is still absent from current audio discovery. Live electric DI, acoustic microphone/piezo, round-trip calibration, audibility, pitch/onset accuracy and the physical 15-minute run remain the existing U01–U10 checks. No hardware acceptance or new implementation scope is inferred from this follow-up.
