# Authored pitch transitions: slides and legato

Status: `pending_user`

Part of the full-course objective: implement topics 51–53 (slides, hammer-on, pull-off) with real notation/reference/assessment support, not generic self-check replacements. Topic 56 vibrato remains a separate modulation contract. Use the existing bounded periodic contour and one audio coordinator; no new capture callback work or automatic raw recording.

## Design constraints to resolve and implement

- One canonical picked note may have a signed pitch transition and target fret on the same string. The model must distinguish slide, hammer-on and pull-off, validate direction, event-local timing and reachable start/end frets, and keep a single initial attack target. Show start/target positions, TAB technique marks and target timing. Scoping must retain the complete event.
- Adaptation/repositioning must preserve the signed interval and keep both endpoint frets on one string within the selected neck/region. Do not use a second simultaneous voice or duplicate the pitch calculation in views.
- Audio can validate the audible starting/target pitches and timing/path, not which finger, string or hand gesture produced them. Internal flux during the authored change cannot automatically prove a new picked attack; keep raw observations but distinguish scored extras.
- Fretted slides pass through chromatic positions. Do not reuse a bend's tight continuous-cent trajectory as a slide contract: allow fretted steps and detector boundary blending while rejecting wrong endpoints/direction or no travel. Establish conservative duration/frequency/rate bounds with synthetic evidence before enabling graded practice. A fast unsupported transition must be explicitly unavailable, not fabricated success.
- Hammer-on/pull-off pitch changes can be abrupt. Use an exact authored change tick and suitable boundary allowances, rather than forcing a slow bend ramp. Validate positive hammer-on and negative pull-off intervals, with open-string endpoints where allowed.
- Freeze optional metadata and new result/parameter/feedback/prompt versions; old absent fields/canonical digests/history must remain readable without rescoring. Share clock conversion with the exercise's actual pulse.
- Add original bilingual progressive lessons, not just notation demos. Verify all eight presets ×five fret counts, exact endpoint pitches/ticks, render/seek/repeat, noisy/missing/wrong contours, offset applied once, complete-event scopes, result persistence and advice. Native/real instrument validation remains pending_user.

## Inspection finding

`BendEvaluator.evaluate` still calls `BendCapability.supports` without the exercise pulse, although MonophonicCapability passes it and the evaluator's frame timing already uses it. This can withhold an otherwise supported 7/8 bend because the capability guard assumes quarter BPM. Fix with an explicit pulse argument and an independent odd-meter regression as part of this work. Do not change or silently recalculate old saved results.

Implementation and acceptance evidence remain open. Same-agent review and a signed root-only Release are required; no local Debug app build.

## Initial implementation

Added a Domain PitchTransition value with signed direction, exact change tick for legato or travel duration for slides, endpoint validation and continuous-phase synthetic reference integration. MusicalEvent carries it optionally and omits absent metadata from encoding. Initial attack pitches remain separate from display/reachability endpoints. Resolver candidates now validate linked endpoints against both fret count and selected region. Full consumers, capability, scoring and lessons are still under implementation.

Fixed the inspected BendEvaluator pulse omission; three BendAssessmentTests pass (0.011 s), including an independent half-pulse /0.5-second trajectory in all six meters with +120 ms compensation applied once. The initial two Domain transition tests pass (0.012 s), including direction/bounds, exact step/slide boundary values, JSON and numerical integration. These are partial software checks, not release acceptance.

## Integrated implementation

Implemented optional signed transition events, linked endpoint relocation, continuous-phase preview, existing contour collection, phase assessment/extra-observation semantics, versioned archives and agent context, TAB/staff target timing, result curves and measured recommendations. Added substantive bilingual `slides`, `hammer-ons`, `pull-offs` with nine graded exercises total, quizzes and self-observation. All 86 lesson bundles validate; course inventory is 79 authored /1 needs_review /48 todo. Vibrato and the rest of the curriculum remain open.

Targeted checks and review findings are recorded in [same-agent review](../../docs/reviews/pitch-transitions-review.md). Complete suite and signed root Release checks are running/pending; status remains in_progress until delivery and exact-head CI/merge. Real instrument/native checks are not claimed.

Complete core suites now pass (291 tests across Persistence/Learning/Domain/Audio/AgentBridge), followed by the additional capability, mixed-score and Drop-bass regressions. Corrected complete App suite passes 155 tests; five final notation/localization/render checks pass after the spoken-language fix. Four Python tests, content/localization/project checks and UI source type-check pass. Signed root-only Release packaging is in progress; no Debug app build or real-interface validation was performed.

Signed root Release/archive and bundle audit pass: 86 lessons /259 YAML, en/uk, arm64 macOS 14, expected sandbox and ad-hoc hardened signature. The separate XPC probe passes without a provider call. [Evidence](../../docs/benchmarks/pitch-transitions-release-bundle.json). Local implementation is reviewable; exact-head CI/merge remains open, with native/hardware validation pending afterward.

Exact-head CI35177204960 passed (24m58s) for4339b51b2acabc052c5e799c160a7eb1e9e08785; PR83 merged2026-09-17. Real-instrument/native user validation remains pending.
