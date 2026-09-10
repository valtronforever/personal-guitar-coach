# Chord feasibility protocol v1

Frozen before any chord benchmark results are evaluated (2026-09-10). This is a bounded research experiment, separate from production monophonic assessment. Changing this protocol after viewing held-out results requires a new version and fresh test data.

## Data and split

Use GuitarSet 1.1.0 acoustic comping audio and note annotations by Xi, Bittner, Ye, Pauwels and Bello, DOI 10.5281/zenodo.3371780. If upstream download is unavailable, use the pinned jhartquist/guitarset mirror, preserving its revision, note-label transformations, original attribution and hashes. Never describe the mirror as independently verified ground truth. Avoid the three upstream files with known annotation errors. Select mirror row indices 0, 40, 60, 100, 120, 160, 180, 220, 240, 280, 300 and 340 before inspecting predictions; require comping style and two recordings per player. These fixed index choices sample two repertoire positions per player and are not selected by model performance. Players 0–3 are development, players 4–5 held out. Both recordings and all derived distortions stay in their player's split. Same repertoire across players means player-held-out, not composition-held-out.

Evaluate clean mono pickup mix; derive a separately labeled tanh distortion condition after gain normalization. This is simulated distortion of acoustic pickup recordings, not genuine electric/amplifier data. Actual clean/distorted electric recordings with human labels remain U06. Record observed voicing diversity from note sets rather than assuming every chord has multiple voicings.

## Separate questions

1. **Identity:** 24 major/minor triad classes. Reference identity is derived only when active reference pitch classes exactly form a major/minor triad; all other pitch sets are unknown. This measures audible triad identity, not the score's intended chord or bass inversion. Report precision among accepted predictions, recall over all known references, coverage, confusion counts and unknown false acceptance.
2. **Missing/extra notes:** compare independent estimated MIDI sets with the active note annotations, at 250-ms grid times away from annotated transitions (all expected active notes cover the entire analysis window). Report micro precision/recall/F1, exact set accuracy and octave errors. Do not map estimated notes to strings/fingers; duplicate pitches on two strings are not independently identifiable.
3. **Strumming rhythm:** group annotated note onsets into attacks within 60 ms from each group's first onset; treat these as a proxy, not human strum labels. Compare independent spectral-flux onset detections one-to-one within 50 ms, report precision/recall and matched absolute timing error. Annotated strings within a slow rake can exceed that group window; no physical rhythm support claim follows.

## Fixed baselines

- Spectral chroma template identity: Hann-window magnitude spectrum, local peaks assigned to nearest MIDI, aggregated into pitch classes. Template cosine similarity; unknown below 0.8 similarity or 0.08 lead over second-best. No expected-chord restriction.
- Harmonic dictionary nonnegative least-squares multipitch: MIDI 36–88, eight harmonics with 1/h weights; 186-ms window at 22.05 kHz, FFT 4096; declare components above 20% of maximum, require fit residual <=0.45 and at most six detected pitches; otherwise unknown. Convert detected pitch classes to exact major/minor identity when possible.
- Production `mono-mpm-flux-2` remains a monophonic abstaining baseline. Measure actual output/quality on the same clips separately; its output can contain at most one note and is not a chord estimator.
- Negative controls: silence, noise, single notes, power dyads, major/minor ambiguity and dense clusters; include synthetic original harmonic signals with known pitches and controlled missing/extra notes. Do not treat them as unseen guitar recordings.

No threshold tuning on held-out players. Fixed candidate parameters may fail; no-go is valid. Basic Pitch's local CoreML/ONNX export and license should be reviewed as a future candidate; library/model benchmark is optional and must be labeled unmeasured if not executed. Never substitute published accuracy for this corpus.

## Decision gates

To consider a later user-facing identity hint: >=95% accepted identity precision, >=80% known-identity recall, <=5% unknown false acceptance on each clean and distorted held-out condition, with sufficient per-class support (at least 20 independent attacks per supported class across two unseen players). To consider missing/extra-note feedback: >=95% pitch-set precision and recall and >=90% exact set accuracy per condition. Rhythm: >=95% attack precision/recall, matched timing p95 <=30 ms, independent human strum labels and validated route latency. Report absent classes and clustered samples; frame counts do not establish independent attacks.

Performance: measure feature/estimator processing time, algorithmic window delay, process CPU/RSS separately. Offline real-time factor <0.25 is a screening target only; native streaming latency, CoreML conversion equivalence, callback health and thermal behavior need separate work. Product score stays disabled unless all required data, accuracy, unknown and runtime gates pass. Failure or insufficient evidence means no-go for integration, not proof that polyphonic estimation is impossible.
