# YAML lesson migration — local review

Reviewer: the implementing agent (not an independent review). Date: 2026-09-12.

Scope: all 13 lesson bundles, catalog, template, Learning file decoding, error localization, author scaffolding, package pins/licenses, both packaging paths, tests and author documentation. Domain music/positioning, audio, persisted practice and settings are unchanged.

Findings and fixes:

1. Yams wraps errors thrown by validating Domain initializers in `DecodingError.dataCorrupted`. The initial implementation mislabeled bad frets, negative durations and duplicate events as YAML errors. The loader now unwraps the underlying error; the existing invalid-music cases pass and malformed YAML still has its own localized issue.
2. Python SafeLoader normally accepts duplicate mapping keys. The author tools now reject duplicates explicitly; nested duplicates, malformed syntax, multiple documents and unsafe tags are covered. A non-mapping catalog also produces a clear author error before any writes.
3. Bundle verification previously enumerated only JSON lesson files, which would stop checking the migrated payload. It now checks the exact YAML resource set and hashes, rejects stale JSON lessons, and verifies shipped Yams/LibYAML notices in the signed bundle and ZIP.
4. Converted documentation initially placed alternative YAML mappings in the same example block, creating duplicate keys. Alternatives now have separate blocks and activity examples form a sequence; all authoring-guide YAML blocks parse.

Verification:

- Decoded equality against main commit `93de6a0cf6fc003fd2b441e035fb243c39b802bf` for all 43 migrated files: 40 bundled content/catalog files and three template files. No text, IDs, schema/content/exercise versions, musical events or policy values changed.
- Full Core: **160 tests / 33 suites passed**, 54.029 s. Includes real YAML comments, Unicode, literal/folded text, duplicate keys, invalid UTF-8, multiple documents, type failures, healthy-lesson isolation, missing-vs-malformed files and no JSON fallback.
- Full App: **81 tests / 22 suites passed**, 83.394 s. Existing selection, tuning, positioning, practice, history and retry behavior passes against YAML resources.
- Python author tests: two passed; four scaffold modes (disabled/auto/list/range) validate via the actual Swift loader; four invalid CLI configurations leave the catalog and content unchanged.
- `ValidateLessonContent Resources/Lessons`: 13 bilingual lessons, zero issues. Localization: 541 en/uk UI keys. Generated Xcode project and `git diff --check` pass.
- Local signed Release + ZIP built and verified: [bundle evidence](../benchmarks/07-lesson-yaml-bundle.json), 40 YAML files, both locales and dependency license notices. No additional non-system dynamic dependencies.
- GitHub CI gates merge for the exact feature head, including clean-environment native Debug/Release builds. Its result belongs to the PR checks, not an inferred local Xcode run.

No new hardware acceptance is required for this serialization change. Existing real-guitar, native UI/VoiceOver and older macOS acceptance remains open in USER-VALIDATION; this review does not claim a live app launch or physical audio test.
