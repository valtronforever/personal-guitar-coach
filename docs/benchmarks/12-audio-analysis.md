# Task 12 — Audio analysis benchmark

Measured on Apple M2 Max / 32 GiB, macOS 26.6.2 (25G83), Swift 6.3.3 (Xcode 26.6), Release configuration. Full run generated at 2026-09-09T22:30:22Z. Algorithm `mono-mpm-flux-1`; 3,360 cases compare MPM and YIN with the same streaming/onset/quality pipeline. [Compact per-case results](12-audio-analysis.json) retain coverage, error percentiles, event counts and processing time. Re-running the CLI produces individual errors and note events.

## Results

Pitch errors are absolute cents among reliable frames. The percentage column includes **all annotated stable frames** in its denominator, including unavailable/uncertain ones. Resolution is time from reference attack to the resolved note, not onset timing error. RTF = worker processing seconds / audio seconds; this measures offline CPU cost, not live scheduling jitter.

| Corpus | Method | Cases | Pitch median / p95 (cents) | All stable frames within ±15 cents | Onset median / p95 (ms) | Resolution p95 (ms) | RTF |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| synthetic | YIN | 318 | 0.005 / 0.055 | 100.00% | 0.00 / 0.00 | 100 | 0.0213 |
| synthetic | MPM | 318 | 0.005 / 0.048 | 100.00% | 0.00 / 0.00 | 100 | 0.0248 |
| durationMatrix | YIN | 1272 | 0.006 / 0.063 | 99.92% | 3.22 / 13.22 | 110 | 0.0234 |
| durationMatrix | MPM | 1272 | 0.005 / 0.060 | 99.98% | 3.22 / 13.22 | 100 | 0.0276 |
| robustness | YIN | 40 | 0.047 / 1.108 | 85.07% | 0.00 / 10.00 | 110 | 0.0189 |
| robustness | MPM | 40 | 0.036 / 1.056 | 85.07% | 0.00 / 10.00 | 100 | 0.0226 |
| recorded | YIN | 34 | 0.802 / 7.216 | 99.05% | 0.00 / 30.00 | 160 | 0.0245 |
| recorded | MPM | 34 | 0.791 / 7.301 | 99.05% | 0.00 / 30.00 | 160 | 0.0285 |

MPM was selected: both candidates meet the principal development gates, while MPM has slightly smaller synthetic errors and fewer unstable short-note frames. Both remain comfortably faster than real time in this offline measurement. The acoustic pitch difference is small; this does not establish universal superiority.

## Coverage and limitations

- Synthetic: every MIDI pitch 36–88 at both rates, with sine, ordinary harmonics and a dominant second harmonic. All 318 expected attacks per method were found without extras. First attacks are at an aligned 100 ms; their zero timing error is not a general timing guarantee.
- Duration matrix: every MIDI pitch 36–88, A4=400/440/480, 125/200/300/500 ms notes, four repeated attacks, both rates. All 5,088 attacks per method were found without extras. The 125 ms cases explore behavior beyond grading capability; they do not authorize grading faster notes. Separate unit tests exercise first attacks between hop boundaries.
- Robustness: low gain, added noise, loud unclipped input and 20 ms attacks across low/high pitches. All attacks were found without extras. The lower 85.07% frame coverage comes from quiet tails crossing the input gate; those frames are explicitly unavailable rather than assigned a guessed note.
- Recorded: 17 public acoustic guitar clips at both rates, resampled from 96 kHz. Of all 2,414 annotated stable frames, 2,391 are reliable and within ±15 cents of the independent spectral reference (99.05%). All 32 labeled attacks are found; B3's two onset labels are unavailable. There are two additional unpitched/unstable transients in the A2 recording (one per rate), counted conservatively as extras: 32/(32+2) = 94.12% labeled-onset precision. They are not accepted as reliable note events.
- Negative: silence, noise, clipping, out-of-range 40/2000 Hz, a fifth, a triad and an ambiguous octave. No stable-region frames or emitted note events are reliable. Unpitched attacks remain explicit uncertain evidence. This does not detect every possible chord: octave-related strings may resemble one harmonic tone.

The [fixture README](../../Tests/Fixtures/Audio/README.md) documents attribution, permissions, original hashes, crop/resampling and annotation uncertainty. Its pitch references/onsets are algorithmic estimates, not laboratory or human ground truth. This is a development corpus used to tune thresholds; held-out electric DI, piezo/microphone rooms, live capture latency and different instruments remain U02/U04. The original goals remain physical acceptance targets, not claims closed by synthetic tests.

## Grading capability

The implemented software gate requires MIDI C2–E6, 55–1500 Hz after applying the tuning's A4, at least 200 ms per note, and 44.1/48 kHz capture. Quarter notes work across 40–200 BPM; eighths up to 150 BPM; sixteenths up to 75 BPM. Shorter examples remain displayable/playable. This leaves margin beyond the measured 100–160 ms p95 resolution; it does not validate an uncalibrated route's rhythm metric.

## Reproduce and regress

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 Scripts/check_audio_fixtures.py
swift test --package-path Packages/GuitarCoachCore
swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --output /tmp/audio-benchmark.json
python3 Scripts/check_audio_benchmark.py /tmp/audio-benchmark.json --compact docs/benchmarks/12-audio-analysis.json
```

CI uses `--quick` (360 cases, including all 34 recorded clips and A4 endpoint duration cases) plus the same gates. Full local coverage is retained here. The checker validates counts and quality coverage as well as medians/p95; it cannot pass by merely discarding difficult notes. Timing, clipping, ring handoff, packet timestamp corruption, arbitrary chunk boundaries and bounded event history also have unit tests. Actual UI XCTest execution is still U07; task 12 adds no new user-facing strings.
