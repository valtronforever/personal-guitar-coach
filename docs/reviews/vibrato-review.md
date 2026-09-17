# Vibrato: same-agent review

Status: implementation review in progress. This is not an independent review. Full suites, root Release and exact-head CI/merge are still outstanding.

Scope: authored single-note modulation, preset/region resolution, prepared reference phase, periodic-contour measurement, versioned results/agent exchange, notation/accessibility, and the five-activity bilingual topic 56 lesson.

Findings and corrections:
- The initial reference test requested more than the renderer's 48000-frame worker bound. Kept the production bound and tested permitted chunks plus independent later-phase samples instead. Chunk/seek/loop/count-in/practice-silence tests then passed all six meters at 44.1/48kHz.
- A median rate plus dispersion relative to that median could hide a single slow cycle: the independent irregular fixture measured 1.70Hz with 15%dispersion despite a slow outlying interval. Persisted slowest/fastest cycle rates and required every measured interval within ±20%target. The same irregular fixture now fails musically, and both-rate harmonic PCM regressions still pass.
- Copied coach test initially retained transition-specific expected text and stopped contour before the vibrato return. Corrected the fixture to the actual four-second event and vibrato metadata. Eight coach tests pass, including exchanged observation-ID tamper rejection; no provider was called.
- Notation accessibility initially risked describing cycles/second using the exercise's default BPM during tempo changes. Described cycles per musical beat instead; this remains accurate at every selected tempo. The result separately reports measured cycles/second.
- Unsupported/unknown signal never produces a vibrato success score. Flat/wrong/irregular but known audio remains measured failure. The initial attack is distinct from internal spectral flux, which is retained but not treated as proof of repicking.

Evidence so far: four Domain model/reference tests (latest capability test pending full suite); one statistics unit; three assessment/clock/version tests; two independent PCM tests with 23 generated cases; one course matrix across 8tunings×5necks×3position choices×5activities; two notation/offline render tests; eight coach tests. Logs under `/tmp/vibrato-*`. Content validator reports87 bilingual bundles,0 issues; localization check875 keys. Inventory80 authored / 1 needs_review / 47 todo, not full-course acceptance. Visual fixtures `/tmp/vibrato-visuals` render both languages/themes; Ukrainian light preview inspected for wavy timing spans, tied notes and target curve. Actual native interaction/audio hardware is still pending.
