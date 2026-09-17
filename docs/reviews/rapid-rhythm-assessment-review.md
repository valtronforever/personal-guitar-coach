# Rapid rhythm assessment — same-agent review

Status: implementation under verification. This is a same-agent review, not independent review.

Scope: author schema and current-practice bounds, unchanged pitched assessment, periodic signal versus settled-pitch evidence, sequence assignment/rest/count-in semantics, calibration eligibility, immutable storage/retry, bilingual result/history/coach claims and tremolo lesson adaptation.

Findings and fixes:

1. The original full-course audit found fast tremolo only displayed while moderate preparation was graded. Added an explicit rhythm-only capability to two fixed-note burst exercises. Changing-pitch study stays honestly self-practice; no promise of gesture/dynamics recognition.
2. Existing `PracticeAttack.reliable` certifies settled pitch, so treating it as attack confidence would discard valid rapid events or fabricate pitch. Preserve that field and collect the independent periodic trace for quality gating. Two coherent periodic frames allow timing only; pitchScore/cents are absent and validated as absent in new-version results.
3. The first actual-worker test withheld every120 BPM score: ordinary30 ms onset uncertainty already exceeded half the56.25 ms rhythm tolerance before calibration. Do not relax the calibration rule. The expanded phase/register corpus then disproved the initial15 ms bound (observed15.77 ms). Use a conservative20 ms allowance and narrow the supported rate to notes≥150 ms/sixteenths≤100 BPM; test an exceptionally precise10 ms synthetic calibration. Explicitly test that50 ms manual alignment only supports slower tempo (40 BPM) and remains uncalibrated at100 BPM. Hardware accuracy remains unverified.
4. Generic uncalibrated UI said “Pitch feedback only”, which would falsely describe the new result. Add a specific bilingual rhythm-unavailable label, omit the pitch metric, label history, suppress green uncalibrated rhythm annotations and version the agent prompt. No fabricated pitch advice or score.
5. Storage validation previously required pitchScore for all valid results. Permit its absence only under the exact rhythm algorithm and matching exercise mode, preserving historical monophonic constraints and frozen parameters. No history regrading or schema-wide migration.
6. Initial author-edit helper failed before writing localized files due to an unanchored YAML-block regex; corrected anchoring, updated both locales/version and independently validated the resulting bundle. No failed partial localized release was produced.

Software and release evidence: pending final runs. Native view interaction/VoiceOver and actual clean guitar, envelope/pick variation, interface/Bluetooth performance remain in USER-VALIDATION.md. No new callback work, capture pipeline, provider request or Debug app.

The full App regression exposed a historical synthetic course-flow fixture with no periodic trace and a universal zero pitch-score assertion. Supply explicit synthetic silence trace for rhythm-only entries and require absent pitch; preserve the existing pitch assertion for every ordinary entry. No production uncertainty gate was relaxed.
