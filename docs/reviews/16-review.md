# Task 16 local review

Reviewed by the implementing agent; this is not an independent review.

## Scope and corrections

Reviewed immutable practice configuration/state transitions, input/output ownership, preflight evidence freshness, bounded observation aggregation, final-note draining, repeats, UI handoff and cancellation, localization and accessibility.

- A new output segment originally risked resetting input clock drift even though the analyzer retained its first capture epoch. ClockDriftTracker now derives that baseline from analyzer timestamps; the regression retains 30 ms then 60 ms across separate output UUIDs.
- Repeated UI snapshots cannot establish 200 ms stable input: preflight uses the analyzer's reliable quality span and fresh frame timestamp, and rejects loss/clipping/invalid samples. Synthetic real-analyzer checks cover initial short signal, sustained clean signal, clipping and silence.
- Finalization requires both the conservative 1.4-second + known hardware input drain and the resolved analyzer watermark. The collector retains the last delayed attack, excludes count-in/post-guard attacks, updates growing clipping spans, and interrupts on lost rolling prefixes or the 2048-observation cap.
- Output-only stop with `keepingCapture` validates the exact request UUID and purpose. Separate repeat output UUIDs retain the input lease; stale cleanup cannot stop a newer owner. Each attempt has fresh observations and immutable configuration.
- Seeking the already selected bar now interrupts the active attempt, as do tempo, source/tuning and exercise changes. Leaving the screen freezes partial evidence for the consumer but clears the old attempt from the new screen after cleanup. Tests cover these transitions and unplug during the final drain.
- Whole-bar controls use bounded steppers and checked tick multiplication rather than enumerating arbitrarily large menus. Expected fretboard positions are restricted to the selected range; TAB selection chooses a whole bar (Shift extends it) and explains that behavior.
- The parent view accessibility identifier was propagating to all action buttons. It was moved to the title; native inspection confirms distinct Start/Pause/Stop IDs. The phase uses a contained accessibility group. Missing-route text explains disabled Start.

## Validation and limits

107 reported core tests pass (one opt-in hardware test skipped); 44 App tests pass. Fake runtime flows cover independent repeats with a played first attempt and healthy silent second attempt, pause/retry, tuning snapshot immutability, missing physical confirmation, 10-second signal timeout, navigation cleanup, same-bar seek/tempo interruption and unplug during finalization. These are software evidence, not USB capture measurements.

396 en/uk keys, generated project and UI-test source type-check pass. Native read-only inspection covers English/dark and Ukrainian/light, minimum 900×620 content area, all six strings in fretboard and TAB, collapsed options and persistent action controls. The actual Xcode UI suite remains U07. No input permission or capture was attempted. U10/U01/U02/U03/U08/U09 remain open. Task 17 consumes the bounded evidence callback for scoring and persistence; no fabricated score or raw recording is stored by this task.

Debug and Release native local .app builds pass with ad-hoc signing (`Scripts/build_local.py --configuration debug|release`).

PR #38 passed CI 34422938399 on b02c6c5 and merged as a0604f8.
