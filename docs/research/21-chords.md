# Chord assessment feasibility — task 21

**Decision: no-go for product chord scoring or identity hints with the evaluated methods.** Low recall, incomplete note sets, excessive false strum detections and insufficient class support fail the predeclared gates. This is an integration decision for the measured methods/data, not a claim that chord recognition is impossible. MVP chord diagrams and separate-note arpeggio assessment remain available.

## Corpus and experimental boundary

The [frozen protocol](../../Research/Chords/PROTOCOL.md) selected twelve GuitarSet acoustic pickup-mix performances, 296.196 seconds total, from six players. Players 0–3 supply eight development recordings; players 4–5 supply four held-out recordings. Selection and parameters were fixed before results. Each player performs two repertoire positions (BN1-129-Eb and Rock2-142-D). Repertoire overlaps: this is player-held-out, not composition-held-out or a statistically representative guitar population.

Sources and CC-BY-4.0 attribution, pinned mirror revision, transformations and download caveat are in the [research README](../../Research/Chords/README.md). The [manifest](../../Research/Chords/corpus.json) records each WAV hash and canonical note-list hash. Upstream Zenodo requests timed out; the accessible mirror was used and was not byte-compared with upstream archives. Three known-error tracks are excluded. The reference is derived from provided note annotations, not independent human labels created for this product. Original authors distinguish instructed chords from performed chords inferred using notes/lead-sheet segmentation. [GuitarSet documentation](https://guitarset.weebly.com/)

A clean condition uses recorded acoustic pickup mix. A second condition applies `0.5*tanh(4*x/peak)` to the same original audio. It stays in the same player's split. It is **derived distortion**, not a real electric amplifier or an unseen second recording. Real clean/distorted electric DI, microphone/piezo variation and independent human strum labels remain U06.

Grid sampling every 250 ms retains only nonempty note sets with no annotated onset/offset inside a 186-ms analysis window. This leaves 121 development and 61 held-out frames per condition; 49 held-out frames are actually polyphonic (at least two distinct MIDI pitches), with 27 distinct note-set voicings overall. Transition exclusion selects relatively stable, easier material and is not full streaming coverage. Consecutive frames and repeated chords are correlated. Only 18 held-out frames are exact major/minor triads, covering five classes: C major (3), Bb major (2), D minor (10), Eb major (1), Ab major (2). No class satisfies the required twenty independent attacks per class; no support claim can follow.

## Methods and results

Two independent-from-target Python baselines use a 4096-sample Hann window at 22.05 kHz. Spectral chroma matches all 24 major/minor templates with fixed similarity/margin rejection. Harmonic NNLS estimates MIDI 36–88 using an eight-harmonic dictionary and rejects poor fits, more than six components or weak components according to the protocol. Neither is given an expected chord or fingering. Missing/extra feedback is evaluated as the observable MIDI set; duplicate same-pitch strings are not distinguishable.

### Identity on held-out players

Precision includes accepted predictions on unknown reference material. Recall includes every known reference, including abstentions. Unknown references include incomplete, extended, ambiguous and single-note pitch sets, not just silence.

| Method | Condition | Correct / accepted | Known recall | Overall coverage | Unknown false acceptance |
| --- | --- | --- | --- | --- | --- |
| Chroma | Clean | 14 / 19 (73.7%) | 14 / 18 (77.8%) | 19 / 61 (31.1%) | 5 / 43 (11.6%) |
| Chroma | Derived distortion | 13 / 18 (72.2%) | 13 / 18 (72.2%) | 18 / 61 (29.5%) | 5 / 43 (11.6%) |
| Harmonic NNLS | Clean | 6 / 6 (100%) | 6 / 18 (33.3%) | 6 / 61 (9.8%) | 0 / 43 |
| Harmonic NNLS | Derived distortion | 5 / 5 (100%) | 5 / 18 (27.8%) | 5 / 61 (8.2%) | 0 / 43 |

Six or five correct accepted answers do not establish a reliable feature. Chroma fails precision/unknown gates; harmonic NNLS fails recall/coverage and class-support gates. Per-class confusion counts, all retained frame predictions and reference sets are preserved in [21-chords.json](../benchmarks/21-chords.json).

### Missing/extra MIDI notes on held-out players

| Condition | Polyphonic frames | Pitch precision | Pitch recall | F1 | Exact set accuracy |
| --- | --- | --- | --- | --- | --- |
| Clean | 49 | 98.7% (74 TP / 1 FP) | 40.0% (111 FN) | 56.9% | 11 / 49 (22.4%) |
| Derived distortion | 49 | 95.1% (78 TP / 4 FP) | 42.2% (107 FN) | 58.4% | 10 / 49 (20.4%) |

Conservative rejection reduces false notes while missing most sounding notes; it cannot distinguish a player's omitted note from an estimator's omission. The artifact also keeps the complete 61-frame metrics (36.1% / 34.4% exact sets) so removal of monophonic frames is transparent. No thresholds changed after viewing results. The additional polyphonic-only table was added during review to avoid single-note fragments inflating a chord conclusion.

### Strum timing proxy on held-out players

The reference groups note onsets within 60 ms of each group's first onset. An independent spectral-flux detector is matched one-to-one within 50 ms; dynamic programming maximizes matches then minimizes timing error. This is a note-group proxy, not a human-labeled pick stroke; a slow rake may be split or rapid strokes merged.

| Condition | Expected / detected / matched | Precision | Recall | Matched error median / p95 |
| --- | --- | --- | --- | --- |
| Clean | 340 / 445 / 300 | 67.4% | 88.2% | 10.4 / 21.9 ms |
| Derived distortion | 340 / 447 / 298 | 66.7% | 87.6% | 11.2 / 22.3 ms |

Matched timing error alone looks acceptable but ignores 145/149 false detections and 40/42 misses. Precision/recall fail. The detector timestamps flux peaks at their window center; this is an offline estimate, not measured route compensation. No chord rhythm grade is enabled.

### Negative controls and existing mono baseline

Seventy-four original harmonic controls cover major/minor triads, single notes, power dyads (missing thirds), clusters, added sevenths, silence/noise and derived distortion. Of fifty unknown cases, chroma falsely accepts eighteen and harmonic NNLS six. Both classify all twenty-four known triad controls correctly; synthetic success does not generalize to recordings. Individual controls are in the artifact.

The actual production `mono-mpm-flux-2` CLI processes all recordings at 44.1 kHz, collecting the full event stream as rolling snapshots advance. On held-out eligible frames it emits a reliable pitch on 10/61 clean and 12/61 distorted frames; audible-set recall is only 5.1% in both conditions. Exact-set matches occur only in single-note reference fragments. This confirms it cannot be repurposed as a chord estimator. Some chord/transient frames can still yield a plausible single pitch; its reliability flag is not proof that only one string sounded. Chord exercises remain rejected by monophonic assessment mode. [Mono baseline artifact](../benchmarks/21-monophonic.json)

## Cost and local ML candidate

Measured on M2 Max/macOS 26.6.2, Python 3.12.7, NumPy 2.3.5, SciPy 1.17.1. Final Python run: 2.697 s wall, 3.417 s process CPU, 169,279,488-byte process peak RSS. Held-out estimator-plus-proxy processing factors were 0.00324 clean and 0.00339 distorted versus audio duration; sparse selected windows make this **not** a continuous-frame DSP budget. File loading/resampling are outside each per-track analysis timer but inside total time. A 186-ms centered window needs about 93 ms future context plus processing. RSS is process high-water, not a leak analysis.

Production mono baseline processing factor was 0.0297 clean / 0.0304 distorted on held-out recordings. It analyzes continuous PCM but emits one pitch. Neither measurement includes live callback scheduling, thermal behavior or user-interface load. Full streaming and physical timing remain unmeasured.

Spotify Basic Pitch is a candidate for further local evaluation: its repository offers CoreML/TFLite/ONNX model forms and Apache-2.0 licensing. The reviewed source revision is `fa5997af0a8210982619003269994a1be25eddf3`; its constants use 22.05-kHz mono and roughly two-second model windows. GuitarSet appears in its dataset constants, so this experiment's player split must not automatically be called unseen for that pretrained model. No model was installed, converted, benchmarked or integrated here; published accuracy/real-time claims are not transferred to this product. A future experiment needs documented training/test separation, model and code hashes, license/notice retention, CoreML equivalence and actual latency. [Basic Pitch repository](https://github.com/spotify/basic-pitch), [reviewed constants](https://github.com/spotify/basic-pitch/blob/fa5997af0a8210982619003269994a1be25eddf3/basic_pitch/constants.py), [original paper](https://arxiv.org/abs/2203.09893)

The numerical baseline implementation is original research code; NumPy and SciPy are research-only BSD-licensed dependencies. No new runtime dependency was added to the app. [NumPy license](https://github.com/numpy/numpy/blob/main/LICENSE.txt), [SciPy license](https://github.com/scipy/scipy/blob/main/LICENSE.txt)

## Reproduction and remaining work

Run the commands in [Research/Chords/README.md](../../Research/Chords/README.md). The five research tests verify exact identity/unknown semantics, one-to-one matching, non-chained onset groups, silence rejection and denominator handling. Source audio/annotation hashes and all report rows allow audit. Software no-go and a reproducible experiment are delivered; U06 independent electric recordings/labels remain `pending_user`. Follow-up implementation requires the separate [backlog](../../tasks/follow-up/chord-assessment.md) and evidence gates in [ADR 006](../decisions/006-polyphonic-feasibility.md).
