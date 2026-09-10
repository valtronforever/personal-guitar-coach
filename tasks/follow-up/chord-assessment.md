# Conditional chord-assessment follow-up backlog

These English tasks are proposals arising from task 21 / ADR 006. They are not active additions to the authorized 22-task implementation and do not promise chord scoring.

| ID | Task | Dependencies | Acceptance evidence |
| --- | --- | --- | --- |
| C01 | Build an independently annotated electric/acoustic chord corpus | U06 user session | Clean DI and real amplifier distortion, microphone/piezo, multiple guitars/players/voicings, wrong/missing/extra/unknown cases, permission/provenance; human note and pick-stroke labels with disagreement; player/instrument/repertoire-separated held-out groups; no augmentation leakage |
| C02 | Evaluate local multipitch/ML candidates | C01 | Pin code/model/runtime/license/notice hashes; audit training-data overlap; Basic Pitch or another justified local candidate; compare same folds against current baselines; class-wise precision/recall/confusion, complete-note sets, unknown false acceptance and genuine strum timing; keep held-out thresholds frozen |
| C03 | Establish native streaming capability and cost | C02 passes accuracy/support gates | CoreML/native output equivalence, actual lookahead and event timestamps, calibrated latency, memory/CPU/thermal bounds, bounded worker integration and real 15-minute callback/drop metrics; no processing in audio callback |
| C04 | Version chord evidence and conservative assessment | C01–C03 pass; explicit decision to implement | Separate identity/pitch-set/strum evidence, supported vocabulary and unknown states; no string/finger inference; parameter/schema versions; preserve old monophonic results; deterministic negative fixtures and independent hardware validation |
| C05 | Add bilingual chord hints or scoring at the validated capability level | C04, user-facing scope chosen | EN/UK, accessible uncertainty, evidence-based recommendations, diagrams linked by canonical event IDs, no fabricated grade on missing/ambiguous input; independently reviewed beginner walkthrough |

Promotion gates remain those frozen in Research/Chords/PROTOCOL.md: identity precision ≥95%, recall ≥80%, unknown false acceptance ≤5%, adequate per-class independent support; pitch-set precision/recall ≥95% and exact sets ≥90%; strum precision/recall ≥95%, matched p95 ≤30 ms with independent stroke labels. Passing only identity must not activate missing-note or rhythm grading. A failed or underpowered experiment remains no-go.
