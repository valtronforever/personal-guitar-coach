# Independent timing settings

Audio setup → Timing synchronization contains **two independent settings**. Output alignment defaults to **0 ms**. Measuring it is optional; the instrument measurement works immediately with zero. Neither measurement applies itself. Cable loopback is not offered.

## Output alignment

Choose the metronome output and channel; a guitar input and microphone permission are not required. Start output measurement, listen to four clicks, then press the focused button, Space or Return on each of sixteen clicks at 60 BPM. Review the timeline and measured offset, then Apply output alignment. Reset restores zero. The value is additional to hardware latency already reported by the device; it includes personal tapping bias and mouse/keyboard delay, so it is approximate alignment, not an isolated measurement of hardware latency. It does not reduce audible live-monitoring delay or remove variable Bluetooth delay.

Mouse-down/key-down timestamps use the native event's uptime, mapped to host time at delivery. Key repeats are suppressed, and no global keyboard monitor is installed. Nonfinite, reversed or more than two-second-old timestamps reject measurement. Accessibility activation uses activation time. The UI does not schedule audio clicks.

The setting is saved per exact output endpoint (UID/channel/rate/buffer/reported timing). Reconnecting a variable-delay output is a reason to remeasure it. Missing profiles mean zero; corrupt storage produces an error instead of silently resetting preferences.

## Instrument alignment

Select the input and mono channel independently from the output. Select an open string from the current tuning (default string 3; 1 = thinnest), tune it, and mute other strings. Start instrument measurement. A sustained clean-pitch check runs for up to 20 seconds. Then listen to four clicks and play sixteen separate notes at 60 BPM, following the sound. Let each note sound for about half a second before muting so pitch can settle. Use clean input and avoid click leakage into microphones.

This is one instrument measurement, independent of the optional output measurement. It uses the **saved** output alignment, never an unapplied candidate. The measured instrument value is the remaining offset relative to that output alignment. Review the remaining value, total compensation, repeatability and timeline before Apply. Changing/resetting output alignment invalidates instrument eligibility and any pending instrument candidate; old stored evidence is not rewritten.

## Manual entry

Both settings accept signed milliseconds with a decimal dot/comma. Values and combined output + remaining-instrument compensation are limited to −1000…+1000 ms. Output has two explicit references: **additional correction** or **total delay from specification** (the latter must be nonnegative). For a total specification, the app subtracts the endpoint's already-reported hardware latency before storing the additional correction. Unknown reported latency is zero. The displayed additional setting may therefore differ from the entered total; the original entered value and its reference are preserved in `ManualOutputAlignment` (`output-manual-v1`). Actual Bluetooth connections may differ from published specifications.

The user can inspect the retained failed timeline, disregard unrepresentative beats themselves, and enter the remaining instrument offset. This does not remove detections, change the trace, or turn a failed measurement into accepted measurement evidence. Explicit Apply saves `ManualInstrumentSyncEvidence` (`manual-instrument-sync-v1`) and method `manualPersonal`, with the current instrument/output snapshot. Saved fields are restored on opening the sheet; after reconnect/relaunch the value can be reapplied without a new measurement.

Per explicit user choice, manual instrument settings enable **approximate rhythm scoring**, labeled **Manual setting** in practice, summary, details and history. They never claim measured timing. They still require valid input, confirmed signal, a current-session Apply receipt, matching route/instrument/output, live clocks and the ordinary assessment validity gates. `manualPersonal` uses a fixed 50 ms scoring-policy allowance plus the existing 30 ms onset allowance and observed clock drift; 50 ms is not a measured error bound or a hardware accuracy guarantee. The approximate tolerance remains capped at ±200 ms and at 45% of adjacent-note spacing, so sufficiently fast or unstable attempts may remain uncalibrated. Legacy `manual`/`estimated` records retain their previous unmeasured semantics.

## Evidence, compensation and bounds

For each measurement all sixteen events must be present within ±400 ms of their expected clicks. Only events in the first-to-last measured click window extended by ±450 ms enter acceptance. Four warmup clicks and all captured events remain in the timeline. The median offset is retained; maximum absolute deviation must be ≤60 ms and the difference between last-five and first-five medians ≤40 ms. These are engineering policy limits. No between-pass agreement gate applies to the two separate settings.

Instrument measurement also rejects wrong pitches (>50 cents), clarity <0.9, uncertain attacks, clipping, gaps/lost bounded histories, invalid timestamps, route/revision changes, clock loss and relative clock drift >20 ms. It drains capture for 1.8 seconds plus reported hardware delays. Output measurement rejects render-anchor drift >20 ms and records that allowance. Both event histories are bounded to 128; overflow rejects rather than silently dropping data.

`OutputAlignmentProfile` uses `output-taps-16-v1`, saving the endpoint, offset, spread, drift and output clock allowance. `InstrumentSyncEvidence` uses `instrument-sync-16-v1`, saving the exact instrument/string, output setting snapshot (nil = zero) and remaining guitar offset/spread/drift. Instrument uncertainty conservatively sums both measurements' spreads, absolute drifts and clock allowances, plus 10 ms detector allowance. Output-only alignment cannot enable a rhythm score.

The stored personal compensation is `outputAlignment + remainingInstrumentOffset`. The scoring formula is unchanged and applies that total **once**:

`error = observedNormalized − expectedNormalized − totalCompensation`

Normalization subtracts reported input hardware latency from observed host timestamps and adds reported output hardware latency to rendered click times. Neither reported latency nor the output setting is subtracted again in assessment. Signed offsets are retained; constant personal anticipation/lateness remains inseparable from audio delay.

## Persistence and freshness

`output-alignment.json` schema 1 stores output preferences separately. `calibration-profiles.json` writes schema 3 and reads schemas 1/2/3. Legacy two-pass `PersonalSyncEvidence`, measured/manual/estimated profiles and previous practice records remain readable without rewriting or rerating their evidence. A profile contains exactly one matching provenance type: legacy two-pass, new measured instrument evidence, or explicit manual instrument evidence. The persisted history method enum also includes `manualPersonal`; old records are not rewritten.

Instrument eligibility requires explicit Apply in the current audio session, unchanged route revision/instrument and the same saved output setting. Its in-memory receipt is not persisted. Relaunch, sleep/wake, hardware notifications and route/format changes require instrument remeasurement. Output alignment persists as a preference, but should be checked after a Bluetooth connection changes. A practice attempt freezes output and instrument settings; later edits never change its evidence.

Personal rhythm remains `approximate`. Scoring v2 retains a maximum ±200 ms tolerance (also capped at 45% of the nearest note interval); measured timing retains ±100 ms and its duration gate. Repeatability allowance + 30 ms onset allowance + live drift must fit within half the effective tolerance, otherwise rhythm/overall remain unavailable. Compatibility checks keep differing profile/method/scoring versions separate.

## Display and retained diagnostics

Practice cursor and instrument timeline subtract reported output latency plus the independently saved output alignment (up to ±1 second for manual entries). They never use total guitar compensation as a display delay. Output-only alignment can move the practice cursor even when rhythm scoring is unavailable. When endpoint hardware timing is unknown, a measured output offset already includes the unknown presentation delay: the cursor does not add the renderer fallback again. Before an output setting exists, practice retains its renderer-presentation fallback. Calibration timelines always use the same hardware-or-zero reference as their expected timestamps.

Each measurement has a separate two-row timeline: four listening lines and sixteen measured lines. Dots show taps/matching detections, triangles other detected pitches, question marks uncertain attacks and hollow markers empty beats. Signed millisecond deltas are relative to the nearest line; the guitar chart explicitly identifies the output alignment already used. All events, including extras/out-of-range events, remain available in a detail list. The chart's nearest-line association is diagnostic, not an acceptance score.

Timelines survive success, failure, cancellation and closing/reopening the sheet **within the current app session**. Starting another measurement replaces only that setting's timeline. Context labels retain device/string information; configuration changes mark affected charts stale. No calibration audio is recorded. Numeric diagnostics include available target/detected frequency, peak, counts, timing spread/drift and clock drift. A normal input level alone does not prove valid pitch/onset detection.

## Physical acceptance still open

Verify optional output tapping with mouse/Space/Return and VoiceOver, then instrument-only at default zero and with an explicitly saved output value. Check signed manual entry with dot/comma, total-specification conversion, approximate Manual setting labels, failed-trace retention and reapply after reopening/relaunch. Test a real interface with wired and Bluetooth outputs, warmup/final clicks, missing/extra/muted/wrong notes, cancellation, reconnect/sleep and screenshots after reopening the sheet. EN/UK, light/dark timeline renders are offline production-view checks; native focus, accessibility and real audio accuracy remain separate gates. Synthetic analysis DTOs do not diagnose the user's original real-guitar first-measurement failure.
