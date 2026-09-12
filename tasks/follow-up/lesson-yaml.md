# YAML lesson resources

Status: `done`

Convert the catalog, all bilingual lessons and author templates from JSON to `.yml`. Keep schema versions, stable IDs, music, text and saved practice evidence unchanged. Load YAML directly in Learning, with author diagnostics for malformed syntax and duplicate keys. Update scaffolding, native bundle verification, documentation and CI. No JSON lesson fallback.

Acceptance: semantic equality with the previous JSON resources; real YAML comments, Unicode and multiline text; malformed document isolation; existing Core/App regression tests; scaffold, content, localization and signed Release bundle checks. Record local review and actual evidence before marking done.

Delivered: `.yml` is the only lesson/catalog file format. Yams 6.2.2 reads the unchanged Codable contracts directly; the Python scaffold and bundle checks use pinned PyYAML 6.0.3. Both dependency licenses ship with the app. Schema and music/content versions are unchanged because all 43 converted files retain identical decoded values.

Evidence: [local review](../../docs/reviews/07-lesson-yaml-review.md), [signed bundle/ZIP](../../docs/benchmarks/07-lesson-yaml-bundle.json). Full Core 160 tests, App 81 tests, two Python tests, four valid scaffold modes and four no-write rejection cases passed. All 13 bilingual bundles, 541 localization keys, author-guide snippets and generated project validate. GitHub native checks gate the feature PR merge. Existing hardware/native acceptance remains independently open.
