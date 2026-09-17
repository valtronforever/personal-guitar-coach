# Rapid repeated-attack rhythm assessment

Status: `in_progress`

The full-course audit identified a remaining capability gap in topic 96: fast tremolo was display-only. This extension adds explicit fixed-note rhythm assessment without pretending that every short note has a settled pitch.

## Implemented

- Author `assessmentMode: rhythmOnly`, actual repeated fret position/rest/tick data, normal practice entries. Structural guards reject changing pitch, polyphony, muted/palm-muted/held/moving/harmonic/sustain techniques and hidden listening. Sounding register110–440 Hz; notes≥150 ms; fast-short/fast-long allow40–100 BPM. Lesson and changed exercises version2; all preset/neck adaptation stays consistent. Final changing-pitch study remains self-practice.
- Same bounded analyzer/capture pipeline and onset history; additionally retain the existing periodic-window trace. Two coherent periodic frames support timing without changing `PracticeAttack.reliable` or inventing a pitch measurement. Noise/clipping/absent trace stay insufficient, silence after valid preflight is distinct, route/data-loss paths remain intact.
- Versioned result `repeated-attack-assessment-1`/capability1 explicitly omit pitchScore and cents. Existing assignment/rest/count-in rules and penalties apply. Current monophonic limits/versions are unchanged. Persistence rejects a rhythm algorithm with a pitched exercise or pitch score.
- 20 ms rapid onset allowance is bounded synthetic evidence, not hardware accuracy. Calibration still needs half-tolerance eligibility: at100 BPM no more than13.75 ms remain for calibration/drift. Existing50 ms manual allowance can support40 BPM but correctly withholds100 BPM. UI/result/history/retry/local-agent context distinguish this and never claim pitch feedback.
- Both languages explain the distinction, author docs and audio contract state boundaries, real-guitar/native checks remain pending_user.

## Verification in progress

Initial end-to-end synthetic PCM at44.1/48kHz passes16 rapid attacks, misses, extras in rests, uneven spacing, count-in exclusion, changed audible pitch without pitch grading, silence/noise/clipping, absent trace and uncalibrated cases. Expanded phase/register corpus, full regression, local Release and exact-head CI/merge are in progress. No provider, device calibration, real guitar or native file dialog was exercised by these tests.

[Same-agent review](../../docs/reviews/rapid-rhythm-assessment-review.md) will record final evidence. Do not mark the whole128-topic curriculum accepted merely because all files exist; its final mapping/editorial/software review remains separate.
