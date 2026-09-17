# Electric-guitar sound course

Status: `in_progress`

Author substantive bilingual topics 113–120: guitar controls, clean/crunch/high gain, amp/cabinet/IR, EQ, drive/compression/gate, time/modulation effects, expressive hardware and DI/monitoring. Use existing timed references, self-practice/checklists/quizzes and clean monophonic recording practice. Effects are configured on the learner's equipment/software; the app does not supply an amp/effect processor or automatically grade tone/physical gestures. Hardware-only criteria remain unchecked without that hardware.

Provide repeatable controlled comparisons with explicit level matching, signal-route provenance, original musical material and realistic hardware alternatives. Verify curriculum/task/filter semantics, bilingual content, timing/pitch/neck matrices, actual recording claims against code, same-agent review, root-only signed Release/archive/XPC and exact-head CI. Keep full course and hardware acceptance open. No subagents or local Debug .app.

Parent PR 88 carries advanced picking; 94 authored/34 todo before this module.

Full Learning: 136 tests/46 suites, 150.745 s (`/tmp/electric-tone-learning.log`). Full App: 176 tests/53 suites, 211.362 s (`/tmp/electric-tone-app.log`), including eight-lesson filters, full catalog/fretboard/TAB/staff/practice flow and existing recorded-channel/coach tests. Localization: 905 keys; generated project current and UI sources type-check. No production audio code changed. Root-only signed Release/archive/XPC and exact-head CI remain open.

Root-only Release/archive verified with 108 bilingual bundles (325 YAML), arm64/macOS14, ad-hoc hardened sandbox and expected entitlements. Binary SHA256 `176a62b643c76758d7f2860a2688a28dedd7d4028cede305eeeec840a7fcb476`; archive `3c15a637a82ba0b5ebe2a6e8e33c30eee0a90839fc6511a19cd1be2ed63ed5dc`. See `docs/benchmarks/electric-tone-release-bundle.json`. Signed sandbox→separate XPC service→invalidRequest passed without a provider call. No local Debug app, native app launch or hardware acceptance claim. Exact-head CI/merge remains open.
