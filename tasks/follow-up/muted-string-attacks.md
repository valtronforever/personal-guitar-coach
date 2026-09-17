# Muted-string attacks and funk study

Status: `pending_user`

Implement explicit unpitched muted-string attacks for display/reference/self-practice. Keep them distinct from a rest and a pitched palm-muted note; author the funk study (102) with short chords, muted attacks and syncopation. Share physical string labels across adaptation, fretboard, TAB/staff and text, render deterministic percussive reference without a new capture pipeline, reject automatic pitch grading and metadata-losing fingering projections. Preserve existing encoding and history. Verify pure/mixed patterns, all tunings/necks, notation/localization, reference and signed root-only Release. Native/hardware acceptance remains pending.

Implementation and [same-agent review](../../docs/reviews/muted-string-attacks-review.md) cover no-pitch metadata, deterministic reference, TAB/staff/fretboard, text and five bilingual funk activities. Targeted Domain/reference/200-case course/App tests pass; 111 bundles/915 keys validate, full Learning 141 and Domain 63 pass. Inventory: 105 authored/23 todo. Full Audio/App and root-only Release/CI still completing; native/hardware gates remain open.

Full Core succeeds: 141 Learning, 63 Domain, 111 Audio, 23 Persistence and six AgentBridge tests; full App 183 tests pass. Root Release/archive validates 111 bilingual bundles and signed sandbox-to-XPC passes without a provider call. [Bundle evidence](../../docs/benchmarks/muted-string-attacks-release-bundle.json). Exact-head CI/merge still pending; native/hardware acceptance remains open.

Exact-head CI 35193742343 passed in 32m41s on `9ff554fd23dfb9338a82a354f465f6438fd718a7`; PR #92 merged as `88b0986b9ff721256e72cdd0952802eb891a5a0e` at 2026-09-17T07:50:43Z. Native/guitar acceptance remains open.
