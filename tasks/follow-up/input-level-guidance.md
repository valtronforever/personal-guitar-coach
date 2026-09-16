# Input signal level guidance

Status: `pending_user`

## Scope

Replace the linear unlabeled guitar-input meter with one shared dBFS scale in Audio setup, personal synchronization and practice preflight. Show weak/working/high zones, actual peak/RMS, overload and actionable gain guidance in English/Ukrainian. Use text and symbols as well as color. A useful amplitude does not establish pitch recognition or calibration readiness. Preserve DSP/calibration thresholds and existing stored data.

## Acceptance

- Logarithmic −60…0 dBFS scale with labeled −30 and −6 dBFS guidance boundaries.
- Distinguish inactive, unavailable, silence, weak, working, high and clipping; the clipping guard matches the existing 0.995 amplitude threshold.
- No stale reading presented as live after monitoring stops.
- Normal plucks, not pauses/note decay, are the gain reference. Explain selected-string/clean-pitch requirements.
- Boundary, invalid-input, dB conversion and stopped-state checks; localization/project/build validation.
- Update local Release only after validation; do not recreate an installed Debug app.

## Validation

Software checks and same-agent review completed. Native UI bridge currently fails with “Sky Computer Use native pipe closed before response”; physical guitar, native layout and VoiceOver acceptance remain open.

- Four production-model smoke scenarios pass locally: dB conversion/geometry, thresholds including 0.995 clipping, inactive/missing/invalid input, and amplitude versus preflight readiness.
- 626 English/Ukrainian keys, generated project and whitespace checks pass.
- Offline SwiftUI rendering inspected in both languages and themes; fixed a truncated paragraph and re-rendered. Artifacts are local generated files in `build/input-level-renders/`.
- After the user accepted the Xcode license, the local Release app and ZIP were rebuilt on 2026-09-16 using Xcode 27.0 / Swift 6.4. The packaged executable retains macOS 14.0 minimum deployment. Signature, sandbox entitlements, 13 bilingual lessons, compiled catalogs and archive contents passed verification; no Debug app was recreated. [Bundle evidence](../../docs/benchmarks/input-level-release-bundle.json).
- [PR #56](https://github.com/valtronforever/personal-guitar-coach/pull/56) is merged. [CI](https://github.com/valtronforever/personal-guitar-coach/actions/runs/35052882796) passed 173 Core tests, 96 App tests, signed Release packaging and native Debug/Release builds, including the corrected optional-renderer macro compile issue. [Same-agent review](../../docs/reviews/input-level-guidance-review.md).
