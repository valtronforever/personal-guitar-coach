# Offline chord research

This experiment cannot start audio capture or change product assessment. Its fixed [protocol](PROTOCOL.md), [corpus manifest](corpus.json), [report](../../docs/research/21-chords.md) and [decision](../../docs/decisions/006-polyphonic-feasibility.md) distinguish identity, pitch sets and strum proxies.

## Reproduction

Python 3.12.7, NumPy 2.3.5 and SciPy 1.17.1 were available locally; inspect the report/environment output for actual versions. These are research-only dependencies, not app dependencies. Install them in an isolated environment if needed. Full corpus acquisition needs network access; subsequent analysis is offline. Raw recordings stay under ignored `build/` and are not included in the app.

```sh
python3 Research/Chords/acquire.py build/research/chords
python3 Research/Chords/benchmark.py build/research/chords /tmp/chords.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release --package-path Packages/GuitarCoachCore BenchmarkChords build/research/chords /tmp/mono-chords.json
python3 Research/Chords/summarize_monophonic.py /tmp/chords.json /tmp/mono-chords.json /tmp/mono-summary.json
python3 -m unittest discover -s Research/Chords -p 'test_*.py'
python3 Research/Chords/benchmark.py build/research/chords /tmp/chord-controls.json --synthetic-only
```

Acquisition checks a pinned mirror revision and rejects truncated labels, wrong style/player splits and known-error files. The committed manifest gives source WAV and canonical note-list SHA-256 hashes; compare downloaded artifacts before reporting a reproduction. A changed mirror must not silently replace the benchmark. Temporary HTTP failures are retried at most twice. No authentication or user recordings are used.

## Attribution and transformations

GuitarSet 1.1.0 by Qingyang Xi, Rachel M. Bittner, Xuzhou Ye, Johan Pauwels and Juan P. Bello, *GuitarSet: A Dataset for Guitar Transcription*, ISMIR 2018, pp. 453–460, [original dataset DOI](https://zenodo.org/records/3371780). Acoustic pickup mix and note annotations are retrieved from the [jhartquist mirror at revision 4aca25487bef5cb0d2c4ec146218f9145402a776](https://huggingface.co/datasets/jhartquist/guitarset/tree/4aca25487bef5cb0d2c4ec146218f9145402a776), whose [license/attribution](https://huggingface.co/datasets/jhartquist/guitarset/blob/4aca25487bef5cb0d2c4ec146218f9145402a776/LICENSE) specifies [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The upstream file/API downloads timed out during this run; the mirror is explicitly identified rather than claimed byte-verified against upstream ZIPs.

The mirror derives note lists from original JAMS and documents three corrections. All three affected tracks are excluded. This project selects twelve recordings, rounds continuous MIDI labels to semitones, derives active pitch sets/triad identities and a 60-ms onset grouping proxy. It resamples to 22.05 kHz for Python baselines and creates a separate `0.5*tanh(4*x/peak)` condition before resampling. These are changes, not original electric/amplifier recordings. Production mono analysis uses the original 44.1-kHz clips and the same distortion formula. No endorsement by dataset authors is implied.

[Upstream annotation guidance](https://guitarset.weebly.com/) says performed chord labels are inferred from notes with lead-sheet segmentation/root; they are not independent evidence of performed note completeness. Therefore this experiment uses note-derived exact triads and does not treat the mirror's chord-name column as human-verified truth. Original string labels inform reference annotations only; predicted output never attributes a note to a string or finger.
