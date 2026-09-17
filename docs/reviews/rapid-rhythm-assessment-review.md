# Rapid rhythm assessment — same-agent review

Status: local software/Release checks passed; exact-head CI/merge pending. This is a same-agent review, not independent review.

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

## Final local verification (2026-09-17)

- Domain65 tests/21 suites passed0.342s; Learning150/55 passed243.167s; Persistence23/4 passed0.058s. Following the conservative20 ms/100 BPM adjustment and final mode-storage guard, focused contracts/tremolo2/2 passed2.128s and Persistence23/4 passed0.057s.
- Final rapid audio3 tests/1 suite passed105.918s:54 independent onset/periodicity cases across44.1/48kHz, MIDI45/57/69, three spacings and three onset phases;8 phase-continuous assessed register/rate cases; defects/noise/clipping/silence/count-in/absent-trace/uncalibrated scenarios. The raw125 ms onset probe remains a stress case; current graded practice requires150 ms. These are synthetic PCM, not guitar recordings.
- Final App199 tests/62 suites passed288.243s. Covers all bundled practice→stored result→retry flows, new rhythm-only history/prompt/tuning behavior and manual40-versus100 BPM eligibility. Earlier runs exposed the universal pitch-score fixture and, during the capability adjustment, stale compiled120 BPM assertions; the recorded final run rebuilt after all source/resource changes and passed.
-134 bilingual bundles/403 YAML files validate with zero issues;951 UI keys in en/uk; project generation and UI-source typecheck pass. Five Python author-tool tests passed17.857s. Partial inventory reports128 authored and makes no full-acceptance claim.
- Root-only signed Release .app and ZIP built/verified; arm64 macOS14, ad-hoc signature, hardened sandbox/audio/user-selected-read-write and offline en/uk resources. Report `docs/benchmarks/rapid-rhythm-release-bundle.json`. Binary SHA-256 `81dce547c074614ee29be4c22d456f31faa5c84814e676c6f740c545f2a7cb31`; archive `73ee22f46a153c4c3b6950dbd9ee15bd53231313d0b67d2e7f71f06f879a198e`. Signed sandbox→separate XPC→invalidRequest probe passed without a provider call. No local Debug app. Native launch and hardware remain unverified.

Logs: `/tmp/rapid-{core-regression,contracts-final,app-verified,content-final,author-tests,ui,release,bundle,xpc}.log`. Exact-head CI/PR/merge still pending.


CI portability fix: run35207416758 stopped during package compilation because the runner Swift compiler could not type-check the nested zip/contains/pow/range expression within its time budget. Replace that expression with explicitly typed bounds and a simple adjacent-frame loop; the signal-quality contract is unchanged. Repeat focused tests and the root Release, then require a fresh exact-head CI run. This is a compiler failure, not evidence of a passed CI or hardware check.


Portability-fix verification: final focused Learning contracts/tremolo2 tests passed2.177s and rapid PCM3 tests passed106.351s with unchanged assertions. Root Release/archive rebuilt; content134 bundles and signed sandbox→XPC probe pass. Latest binary SHA-256 `59ffe9fc33bc22e2f73a2ee3463ce2c4bd9a4b8018b12e0d5e97a1fc829eae23`; archive `dbf58373ae26a90bdd4750b1c673260f0143103a2bdc6717f3f4aa97c5a457c3`. The benchmark JSON is updated; earlier hashes above are historical. Logs: `/tmp/rapid-portable-{focused,release,bundle,xpc}.log`. The failed CI run is superseded only after a fresh exact-head run passes.
