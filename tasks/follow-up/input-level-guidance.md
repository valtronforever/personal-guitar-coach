# Input signal level guidance

Status: `in_progress`

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

Pending automated checks and same-agent review. Native UI bridge currently fails with “Sky Computer Use native pipe closed before response”; physical guitar, native layout and VoiceOver acceptance remain open.
