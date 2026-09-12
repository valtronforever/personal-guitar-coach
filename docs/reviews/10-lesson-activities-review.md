# LD01–LD04 implementation review

Reviewer: the implementing agent; this is a same-agent review, not an independent review. Branch: `codex/lesson-activities`, base `74a3d6e`. The user's final amendment explicitly removes the old lesson API. Deliver all stages atomically so the app and bundled resources agree.

## LD01 — Model, resolver and validation

Reviewed schema-2-only decoding, source scope, policy tagged unions, author defaults/fixed values, deterministic candidate selection, exact sounding pitch/octave preservation, fragment timing and linked shapes. Removed schema-1 lesson support, dual text editions and the old whole-lesson API. Source exercises keep stable IDs/versions; the migrated current text version is now the sole published lesson version.

Findings fixed:

- The first GitHub run on the hosted Swift toolchain rejected a large inferred template dictionary with a type-check timeout. Split it into explicitly typed individual assignments; local focused renderer tests and Release were rerun before retrying CI.
- Selecting a whole lesson must not pick one incompatible tuning context implicitly. Validation requires equivalent physical source tunings and policy; renamed equivalent profiles remain valid.
- Conflicting shared chord mappings could overwrite an earlier mapping. Resolution now fails explicitly instead of making linked arpeggios disagree.
- Diagnostics initially collapsed unknown step events and display-only practice into a generic invalid-step error. Restored specific unknown-event/unsupported-mode diagnostics.
- Fragment resolution subtracts its first tick, includes internal rests, retains source offset/IDs and rejects rest-only practice. Single-note and shape-only materials do not drag unrelated events into their snapshot.

Evidence: full Core 157 tests / 32 suites passed in 55.024 s; after the final metadata validation changes, five focused Domain tests passed. Musical tests cover all eight presets and five necks, widths 5/6, exact independent C Standard major targets, Drop seventh-region failure at width 5 and success at width 6, source shapes, custom tuning/A4, forbidden choices, malformed references/schema/text and noncontiguous fragments.

## LD02 — Reader, independent choices and preview

Reviewed active material/step binding, per-activity cache/bookmarks, unavailable context recovery, fixed versus learner UI, localization and preview lifetime.

Findings fixed:

- The old reader replaced the entire lesson with an error when one position failed. The new reader keeps generic teaching and other activities accessible while retaining the invalid choice.
- TAB event IDs can overlap across activities. Selection now stays inside the current snapshot and cannot jump to another activity's step.
- Equal resolved exercises in different activities did not inherently stop preview. An explicit preview context ID forces a stop/reset even when the exercise is identical.
- A one-note fragment exposed StaffModel's full-bar-only limitation. The final partial bar now displays actual symbols without invented rests, with a localized fragment notice. Existing gaps, ties, unsupported durations and polyphony still have explicit limitations.
- Fixed-tuning activities no longer display the adaptive fret-pattern explanation, which would imply their pitches follow Settings.
- Unknown-position step titles containing template tokens use a localized step-number fallback instead of exposing unresolved tokens or internal IDs.

Evidence: full App 81 tests / 22 suites passed in 79.091 s, then 11 focused activity/bookmark/practice tests passed after final guard/title changes. All 13 bundles validate. UI-test sources type-check, generated Xcode project is current, 541 UI keys have en/uk translations and matching format placeholders. New tests cover overlapping activities, independent self-confirmations, return/relaunch state, invalid saved choices, rest/text clearing, shared TAB/staff targets and synthetic preview interruption. Native execution is recorded separately below.

## LD03 — Practice, provenance and history

Reviewed frozen policy/choice/source metadata, separate attempt identity, capability checks before audio, immutable saved evidence, recommendation retry and comparison conditions.

Findings fixed:

- Fresh practice handoff now checks that the snapshot's activity/material/source versions belong to the supplied source lesson.
- Choice/policy, required fixed value, source exercise version/event IDs, offset overflow and region containment are validated before audio. Self-confirmation must match choice, tuning and neck.
- New history and archived practice displays prefer frozen bilingual titles; retry does not need current lesson content and removes the previous self-report.
- Comparison includes lesson version, activity/material/entry IDs, policy, choice, source mapping and resolver version. Identical notes from different authored activities do not become a misleading ranked comparison. Self-report alone does not change scores or comparability.

Evidence: activity tests exercise single-note 0..<960 practice from source tick 3840, JSON/persistence round trips, recommendation event-ID mapping, deleted-content retry, source tuning restoration, legacy records without activity metadata and width-5 historical position decoding. Forged metadata is rejected before audio. Existing synthetic active-attempt interruption, silence/insufficient-signal, scoring and retry tests remain in the full suites. No physical string/fret inference is claimed.

## LD04 — Author tools, resources and documentation

Reviewed all resource migrations, opt-out template, scaffold safety, runnable guided example, policy report and current documentation.

Evidence: 13 bilingual schema-2 bundles, seven visible library lessons (six starter lessons plus the new demonstration; six historical C Standard bundles retain saved IDs). All source lessons/consumers moved together. Four scaffold modes (default/auto/explicit/range) produce loadable drafts; four invalid flag combinations reject without writing. Existing overwrite/path/ID/collision tests remain. The actual CLI report checks 160 activity/tuning/neck rows, 26 choices each; every fixed-seven demo region is feasible at width 6, every fixed Original exposes only Original. Condensed output: `docs/design/lesson-positioning/runtime-availability.json`. This establishes geometry/pitch feasibility, not comfort on a real guitar.

## Release and remaining acceptance

Release build passed; the final signed arm64 macOS 14+ app and ZIP pass strict ad-hoc/hardened-runtime, en/uk resources, 13 lessons / 40 lesson JSON files and archive checks. Hashes and explicit `appLaunchVerified: false` / `hardwareVerified: false` are in `docs/benchmarks/10-lesson-activities-bundle.json`.

Native CUA selection of the rebuilt Release failed twice (including session reset) with `Computer Use server error -10005: timeoutReached`. No screen/VoiceOver/actual launch success is claimed. Exact-head GitHub Debug/Release and regression checks gate merge; their run is linked from the feature PR. Physical input, tuner accuracy, ergonomic comfort, VoiceOver and full pedagogy acceptance remain in `docs/USER-VALIDATION.md`; synthetic/model success does not close them.
