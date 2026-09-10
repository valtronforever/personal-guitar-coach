# Task 17 assessment and audio validation

Software development evidence on the local M2 Max/macOS 26.6.2/Xcode 26.6 toolchain. Synthetic timing/calibration is not a physical USB measurement. U02/U03/U10 remain open.

## Full DSP regression

The final `mono-mpm-flux-2` implementation passed all 3,360 original benchmark cases and the unchanged musical/quality gates. Only the expected algorithm version in the checker changed. The [compact per-case artifact](17-audio-analysis.json) preserves coverage, timing, quality and processing results; the earlier [task 12 report](12-audio-analysis.md) remains the historical v1 baseline.

| MPM dataset | Cases | Pitch error median / p95 (cents) | Onset error median / p95 (ms) | Resolution p95 (ms) | Extra attacks |
| --- | --- | --- | --- | --- | --- |
| synthetic | 318 | 0.005 / 0.048 | 0.000 / 0.000 | 160.0 | 0 |
| durationMatrix | 1272 | 0.005 / 0.060 | 3.220 / 13.220 | 160.0 | 0 |
| recorded | 34 | 0.791 / 7.301 | 0.000 / 30.000 | 220.0 | 2 |

An experimental additional energy-rise condition for spectral-flux onsets failed 23 supported duration-matrix cases and was removed. The retained change confirms five reliable post-onset pitch frames, emits their median frequency/minimum clarity, and preserves the original onset detector and timestamps. The full repeat/duration matrix passes again, including 200-ms notes and A4 400/440/480-Hz endpoints.

Reproduction:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --output /tmp/coach-audio-v2.json
python3 Scripts/check_audio_benchmark.py /tmp/coach-audio-v2.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/GuitarCoachCore --filter RecordedAssessmentTests
```

## Annotated recorded input → assessment

The unchanged [Iowa corpus and provenance](../../Tests/Fixtures/Audio/README.md) contains 34 acoustic clips. The two B3 clips have no onset annotation and remain excluded from onset grading; all 34 are still in the existing pitch benchmark. Each of the other 32 clips is preceded by silence aligning its independently annotated first onset with the expected note, and followed by 1.5 seconds of silence to exercise late analysis/finalization. This creates an abrupt boundary at the end of each finite clip and may itself create a transient; these padded single-note fixtures are not continuous natural performances. The test uses the actual analyzer, collector and evaluator; calibration/clock evidence is synthetic.

All 32 annotated first attacks match their expected event exactly once. The annotations use a long stable spectral window, while event pitch is measured earlier, so the difference is a development consistency check rather than laboratory pitch ground truth. Independent frequency annotations differ from equal-tempered A4=440 targets; they must not be forced to score 100.

Event-frequency deviation from the independent reference: median 1.549 cents, p95 12.700, maximum 13.953. Maximum first-onset error: 30.000 ms. 18 of 32 receive a grade; the remaining 14 contain uncertain extra detections in the tail/guard and remain unscored. Secondary transients have no exhaustive human annotation. No detector threshold or matching rule was altered to erase these observations.

The scored-coverage regression floor is 18/32, with at most 14 uncertain extras; this is explicitly a development-corpus baseline, not an accuracy or product-support claim. Human labeling of release transients and held-out clean electric/piezo/microphone runs are still necessary. Counts retain every in-guard attack. A low/absent grade here is not a diagnosis of a player's technique.

| Clip | Event pitch deviation from target (cents) | Independent reference deviation (cents) | Onset error (ms) | Overall | Uncertain extras |
| --- | --- | --- | --- | --- | --- |
| iowa-midi40-44100.wav | -37.71 | -40.40 | 0.00 | 55 | 0 |
| iowa-midi40-48000.wav | -37.68 | -40.40 | 0.00 | 55 | 0 |
| iowa-midi41-44100.wav | -30.99 | -31.41 | 30.00 | 51 | 0 |
| iowa-midi41-48000.wav | -31.26 | -31.41 | 30.00 | 50 | 0 |
| iowa-midi42-44100.wav | -32.32 | -37.45 | 0.00 | 61 | 0 |
| iowa-midi42-48000.wav | -32.20 | -37.45 | 0.00 | 61 | 0 |
| iowa-midi43-44100.wav | -35.51 | -41.05 | 0.00 | 57 | 0 |
| iowa-midi43-48000.wav | -36.43 | -41.05 | 0.00 | 56 | 0 |
| iowa-midi44-44100.wav | -30.12 | -39.66 | 0.00 | 64 | 0 |
| iowa-midi44-48000.wav | -30.58 | -39.66 | 0.00 | 63 | 0 |
| iowa-midi45-44100.wav | -40.72 | -34.46 | 0.00 | Unscored | 1 |
| iowa-midi45-48000.wav | -38.96 | -34.46 | 0.00 | Unscored | 1 |
| iowa-midi46-44100.wav | -39.11 | -38.71 | 0.00 | Unscored | 1 |
| iowa-midi46-48000.wav | -38.99 | -38.71 | 0.00 | Unscored | 1 |
| iowa-midi47-44100.wav | -42.30 | -29.60 | 0.00 | 49 | 0 |
| iowa-midi47-48000.wav | -43.56 | -29.60 | 0.00 | 48 | 0 |
| iowa-midi64-44100.wav | -22.45 | -24.78 | 0.00 | Unscored | 1 |
| iowa-midi64-48000.wav | -22.21 | -24.78 | 0.00 | 73 | 0 |
| iowa-midi65-44100.wav | -19.82 | -21.27 | 10.00 | Unscored | 1 |
| iowa-midi65-48000.wav | -19.84 | -21.27 | 10.00 | Unscored | 1 |
| iowa-midi66-44100.wav | -19.27 | -20.55 | 0.00 | Unscored | 1 |
| iowa-midi66-48000.wav | -19.21 | -20.55 | 0.00 | Unscored | 1 |
| iowa-midi67-44100.wav | -21.48 | -20.03 | 0.00 | Unscored | 1 |
| iowa-midi67-48000.wav | -21.55 | -20.03 | 0.00 | Unscored | 1 |
| iowa-midi68-44100.wav | -18.26 | -19.52 | 0.00 | 78 | 0 |
| iowa-midi68-48000.wav | -18.31 | -19.52 | 0.00 | 78 | 0 |
| iowa-midi69-44100.wav | -20.35 | -21.51 | 0.00 | 76 | 0 |
| iowa-midi69-48000.wav | -20.38 | -21.51 | 0.00 | 76 | 0 |
| iowa-midi70-44100.wav | -17.62 | -19.20 | 20.00 | Unscored | 1 |
| iowa-midi70-48000.wav | -17.56 | -19.20 | 20.00 | Unscored | 1 |
| iowa-midi71-44100.wav | -18.16 | -18.86 | 0.00 | 78 | 0 |
| iowa-midi71-48000.wav | -18.32 | -18.86 | 0.00 | Unscored | 1 |

## Golden assignment and storage

Nine deterministic assessment tests cover perfect/±50-ms compensated inputs, semitone/octave errors, early/late attacks, a dropped middle note, shifted sequence, duplicate/repeated pitches, rests/extras, uncertainty/clipping/non-silent bad input, healthy silence, failed/partial attempts, missing calibration/clock, short intervals, NaN rejection and a 1024-note/2048-attack limit. Repository/App tests also reopen schema-1 legacy and schema-2 detailed results, preserve unknown future documents, retry failed saves without duplication, and save two independent fake-runtime practice repetitions. These checks are separate from musical/hardware acceptance.
