# Public guitar analysis fixtures

These 34 mono Float32 WAV files are 17 short acoustic recordings at two analysis rates (44,100 and 48,000 Hz). They are development data, used to choose and tune the detector. They are not private recordings, user-interface simulations, or evidence of live USB capture.

## Attribution and permission

Source: [University of Iowa Musical Instrument Samples](https://theremin.music.uiowa.edu/MIS.html), created by Lawrence Fritts. The source permits downloading and use in projects without restrictions (checked 2026-09-10). This is the source's published permission, not an invented SPDX license.

The [guitar recording page](https://theremin.music.uiowa.edu/MISguitar.html) credits performer Brian Penkrot, technicians Shane Hoose and Zach Zubow, a Raimundo 118, Earthwork QTC40 microphone and Metric Halo interface in an anechoic chamber, December 11, 2011. Preserve this attribution with redistributed fixtures.

## Provenance and processing

`manifest.json` records every original download URL/SHA-256, original format, source crop and padding in 96 kHz frames, output format/hash, pitch reference and onset annotation. The downloaded AIFF headers actually contain mono 24-bit/96 kHz audio; we use those headers rather than assuming the web page's listening-format description applies to every link.

`Scripts/prepare_audio_fixtures.py` extracts 0.1 s before the annotated attack and 1.1 s after it, padding the beginning where the source starts too late. It resamples with SciPy `resample_poly` and writes Float32 WAV. It does not normalize levels, denoise, pitch-correct, or save input from a user device. NumPy/SciPy versions are recorded. The original large downloads are not committed.

Nominal MIDI labels follow the chromatic source filenames. The recordings are not exactly at equal-tempered A4=440: `referenceHz` is an independent long-window harmonic spectral estimate from 0.3–1.1 s after the attack. This reference uses a Hann window, zero-padded FFT, interpolated peaks near six nominal harmonics and the median of the three strongest harmonic frequency estimates. It never calls the production pitch detector. It is an estimated reference, not laboratory ground truth.

Onset labels come from an independent 1 ms RMS envelope after a second-order 40 Hz high-pass, with threshold max(0.0008, 3.5% of the local envelope peak), within documented source-note search windows. Their assigned uncertainty is 10 ms, not sample-exact human annotation. B3's source begins too near its attack; its onset label is null and excluded from timing recall/precision, while its pitch remains evaluated. Other unannotated transients count conservatively as extras in the benchmark. Stable-frame measurements use clip time 0.3–1.0 s.

## Reproduction

From the repository root, using Python with NumPy/SciPy installed:

```sh
python3 Scripts/prepare_audio_fixtures.py --source-dir /path/to/source-aiff --download
python3 Scripts/check_audio_fixtures.py
swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --output /tmp/audio-benchmark.json
python3 Scripts/check_audio_benchmark.py /tmp/audio-benchmark.json
```

`--download` is explicit and unnecessary for normal tests/CI. The checked-in WAVs allow offline regression. Synthetic sine/harmonic, noise, clipping, repeated-note and negative-polyphony fixtures are generated deterministically by `AudioTestSupport/SyntheticAudio.swift` and are original project test data.

This acoustic development corpus does not establish accuracy on clean electric DI, distorted guitar, piezo, noisy rooms, every guitar/tuning, or unseen recordings. Those checks remain U02/U04 after all software tasks.
