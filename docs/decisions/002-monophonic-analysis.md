# ADR 002 — Monophonic analysis on the capture worker

Status: implemented for software validation; physical guitar/route gates remain U02/U04. Algorithm `mono-mpm-flux-1`, capability `mono-capability-1`.

## Decision and evidence

Use MPM period estimation, a separate causal energy/spectral-flux onset detector, and explicit signal-quality gates. Compare an original YIN implementation using the same streaming pipeline. The [benchmark](../benchmarks/12-audio-analysis.md) records accuracy, coverage, event errors and offline processing cost; neither candidate uses an exercise, expected pitch, physical string or finger.

MPM provides a normalized period curve and clarity measure useful for explicit ambiguity checks. Our comparison found slightly smaller synthetic pitch errors and fewer unstable short-note frames with MPM, at a modest processing-cost increase. The acoustic corpus gives similar results for both; this is a narrow development comparison, not proof that one algorithm is universally better.

## Primary sources

- McLeod and Wyvill, [A Smarter Way to Find Pitch](https://www.cs.otago.ac.nz/graphics/Geoff/tartini/papers/A_Smarter_Way_to_Find_Pitch.pdf), sections 2–7: shrinking-window autocorrelation, normalization by the two overlapping energy sums, one key maximum per positive lobe after the zero-lag lobe, relative peak selection and interpolation. Our direct vectorized implementation uses Apple Accelerate dot products; no Tartini code is copied. Selected clarity describes periodicity, not the probability that the user's note is correct.
- de Cheveigné and Kawahara, [YIN, a fundamental frequency estimator for speech and music](https://www.ee.columbia.edu/~dpwe/papers/deChevK02-yin.pdf), DOI 10.1121/1.1458024, steps 2–5: squared differences, cumulative-mean normalization, a first qualifying minimum and interpolation. Our comparison uses threshold 0.1, a fixed integration length, and rejects an unqualified minimum rather than forcing a voiced result. It omits the paper's later best-local-estimate search.
- Bello et al., [A Tutorial on Onset Detection in Music Signals](https://hajim.rochester.edu/ece/sites/zduan/teaching/ece472/reading/Bello_2005.pdf), DOI 10.1109/TSA.2005.851998: onset detection separates a novelty function from selection of attack times; energy and spectral changes provide different evidence. Our causal adaptation combines energy rise with positive magnitude flux, an adaptive threshold and a refractory interval. It is not a reproduction of a published benchmark configuration.

Accelerate declarations and availability were checked in the installed macOS SDK (`vDSP_distancesq`, `vDSP_dotpr`, `vDSP_DFT_zop_CreateSetup` and its execution/destruction functions). There are no new runtime third-party dependencies.

## Parameters and quality

- Input: explicitly selected mono channel, 44.1/48 kHz. Two cascaded 30 Hz one-pole high-pass stages reduce DC/rumble. Raw peaks still determine clipping; extreme finite samples are bounded before filtering.
- Pitch: 4096 samples, 10 ms hop, search 35–2500 Hz. MPM relative peak cutoff 0.93 and clarity floor 0.9. YIN uses the same search/frame boundaries for comparison.
- Ambiguity: compare interpolated selected/double-period curve values; an improvement over 0.008 remains explicit. Interpolated values avoid high-note lag quantization creating a false octave warning. A Hann-windowed fundamental-energy fraction below 0.001 is also ambiguous; windowing suppresses leakage from an absent sub-fundamental.
- Onset: 2048-sample Hann DFT; positive magnitude flux divided by current magnitude sum; threshold max(0.16, 3 × recent-eight-hop median + 0.06). An energy rise above 1.8 × the decaying recent RMS can also trigger. A falling-signal guard suppresses offset transients. Startup history and refractory time are 80 ms. Analysis should already be running before count-in/graded notes.
- Levels: silence below 0.001 RMS, voiced gate max(0.0015, 3 × estimated quiet-background floor), clipping at absolute raw sample ≥0.995. Quiet-background adaptation is bounded to 0.0001–0.001 and cannot grow until it hides a loud guitar. It is a quiet-floor estimate, not a general room-noise classifier.
- Stability: three consecutive compatible period estimates (≤15 cents between frames), with a complete pitch window after the pending onset. No stable note within 300 ms produces an uncertain event. Stable sustain does not emit repeated notes. Ending a stream flushes a pending uncertain attack; no note duration/offset grade is claimed.

The analyzer exposes warming-up, silence, quiet, unstable, reliable, clipping, ambiguous, out-of-range and invalid states. A short event may be detected but still be outside grading capability. Non-harmonic chords and an absent-fundamental fifth are negative development fixtures. Octave-related strings can be indistinguishable from one harmonic tone; this is not a reliable polyphony classifier. Clean single-note input remains a precondition.

## Ownership, bounds and time

The existing C SPSC buffer remains the sole PCM handoff. AUHAL's callback does no DSP or allocation. Its single `PCMReader` actor drains in a cancellable worker loop independently of the UI's 20 Hz publication. Each drain is bounded to 64 packets; cancellation is checked between packets. Backend stop/deinit cancels the worker and stops/disposes the input unit; worker ownership keeps ring storage alive until its final read ends.

The analyzer keeps fixed waveform/DFT/period buffers, 128 resolved note events and 256 coalesced quality spans. A span's ID persists while its end extends. Snapshot consumers must replace that last span on an update, track IDs, and reject a skipped prefix; they must not silently discard lost evidence. Quality spans preserve brief clipping/uncertainty even when the latest UI frame has recovered. No raw audio is published or persisted.

Onset frame time is separate from the later `resolvedAt`. Host seconds are the first valid input packet host timestamp plus elapsed stream frames at the nominal rate. They are not delivery/worker time and have no hardware-latency subtraction. Task 15 owns measured clock mapping, drift, route uncertainty and residual offset. Every packet is checked for invalid host timestamps/format and sample discontinuity; a later valid packet cannot hide earlier corruption from the coordinator.

## Capability and follow-up

`Exercise.validateForPractice` now also checks the shared `MonophonicCapability`: MIDI C2–E6, resolved frequency 55–1500 Hz, minimum note duration 200 ms, A4 evaluated from the actual tuning snapshot. The benchmark sweeps A4=400/440/480 and both rates. This permits quarter notes at 40–200 BPM, eighths through 150 BPM and sixteenths through 75 BPM. Display, preview and old history remain available outside this grading range. No BPM is silently changed.

Hardware capture, live tuner responsiveness, electric/piezo/room conditions and a held-out guitar corpus remain U02/U04. The corpus was used during development; neither its estimates nor synthetic samples close those gates. Task 13 consumes these observations for the tuner; tasks 15–17 add clock mapping, capture-session validity and assessment.
