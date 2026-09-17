# Multi-target legato and tapping phrases

Status: `in_progress`

Implement the required multi-target unpicked pitch workflow for topics 91 (longer legato) and 93 (tapping). The current single PitchTransition can express only a base and one target. Do not author a longer unpicked phrase as separately picked events or replace its measured pitch outcome with generic self-confirmation.

Design a bounded, opt-in event-local chain with ordered targets, explicit technique cues, one initial attack, shared pitch/fret/time resolution, appropriate same-string/fret constraints and old optional encoding preserved. Reuse existing contour collection, coordinator and worker reference renderer. Assess audible target phases with separate wrong/silent/unknown outcomes, calibrated initial-attack timing and honest limits on physical technique inference. Freeze versions and historical conditions; integrate result/feedback/coach provenance.

TAB, staff and detailed pitch curves must show each target at its authored time without inventing initial attacks; source selection/position/tuning/loop/seek semantics stay consistent. Extend reference phase integration and capability checks using meaningful numerical and synthetic PCM tests, then author substantive en/uk progressive lessons with independent musical goldens. Record native/hardware checks separately in USER-VALIDATION.

Read `docs/CONTENT-AUTHORING.md`, the existing transition/vibrato models, assessment and renderer before choosing concrete API names. `/tmp/advanced-technique-design.md` contains exploratory notes, not an implemented contract. All relevant build/tests, same-agent review, root-only signed Release/archive/XPC and exact-head CI/merge are required. No local Debug app and no subagents.

Parent improvisation PR 86 at `cf1bfb4` is pending CI and stacked on listen-and-repeat PR 85. Current delivered-authoring inventory: 88 topics /40 todo, 94 bundles /88 visible. This extension is starting; no chain capability or new lesson is accepted yet.

Implemented the new event-local chain, capability/assessment versions, shared resolver/reference/contour/notation/result/coach flow and substantive topics 91/93. Inventory: 90 authored /38 todo, 96 bundles /90 visible. String-crossing lesson activity preserves its fixed pattern; other activities expose playable relocations. Parent PRs 85/86 merged after exact-head CI. See [same-agent review](../../docs/reviews/legato-chains-review.md) for concrete fixes and software evidence. Full Core/final mixed test, signed root-only Release, CI/merge and native/hardware acceptance remain open at this checkpoint.

Local delivery is verified: 323-test full Core suite plus the new mixed-technique case; 171-test full App suite plus coach/render cases; 520 musical resolutions; 96 bilingual bundles/900 UI keys; five Python checks; generated project/UI-source checks; signed root-only Release/archive/XPC. The review records all logs/hashes. Exact-head CI/merge remain in progress. Native/hardware acceptance stays open.
