# Task 10 — local implementation review

Reviewed by the implementing agent on 2026-09-10; this is not an independent review.

## Scope and findings

Reviewed selection identity across lesson steps, exercise-scoped event IDs, range selection, fixed/following tuning, reading persistence, navigation, bilingual UI and test isolation.

- An event can belong to multiple steps. `LessonSelection` retains the current matching step, otherwise selects the first manifest match; IDs are scoped by exercise. Explicitly choosing a step clears the manual range even when the step ID has not changed. Tests cover noncontiguous step references, range extension, repeated event IDs in different exercises, rests, text-only steps and display-only fingerings.
- Rapid bookmark changes must not let an older disk write overwrite a newer selection. The reading store uses one draining writer and retains failed pending state for retry. A deliberately suspended first write verifies that the last step and read version survive concurrent UI changes. Reading has its own versioned document; corrupt/future documents are preserved and clear-history leaves it untouched.
- The initial reader scrolled past the introduction even on a first visit. It now scrolls automatically on appearance only when restoring a bookmark; explicit step changes still reveal the selected text.
- Existing UI launch tests assumed an empty reading history. Added a Debug-only UUID-scoped temporary repository, shared by preferences and reading, so a saved user bookmark cannot change the tests' initial screen. A new UI test covers tab → step → practice → relaunch restoration. Its sources type-check; execution remains U07.
- Practice initially showed tuning only when it mismatched. The handoff now always shows fixed/following policy, tuning name and open-string pitches in explicit 6 → 1 order, plus the mismatch notice when applicable. Display-only exercises cannot create an assessed practice request. Removed development-task wording from its user-facing unavailable state.

## Verification

- Core Swift Testing: **45 tests in 7 suites**, including reading round-trip, invalid data, corruption/future versions and independent history clearing.
- App Swift Testing: **27 tests in 7 suites**, including selection, filtering, request snapshots, writer ordering/retry, and missing/empty/broken catalog states.
- `Scripts/check_localizations.py`: **217** complete en/uk UI keys.
- `Scripts/check_ui_sources.py`: all UI-test sources type-check against macOS 14 / Swift 6. This is not UI-test execution.
- `Scripts/generate_project.py --check`, bundled `ValidateLessonContent`, `git diff --check`: passed.
- `Scripts/build_local.py --configuration debug` and `--configuration release`: native .app builds and strict ad-hoc signature verification passed.
- Native CUA walkthrough: English search with no matches/clear; Ukrainian difficulty filter with no matches/clear; selected full bar → high E retains the full-bar step; low-E step → high-E tab switches to the high-E step. English → Ukrainian preserves the selected step and E4 event. Mark-read persists through process quit/relaunch together with the last lesson/high-E step. Fretboard restores only E4. Practice shows the concrete lesson, Standard pitches and 60 BPM; return-to-lesson restores the step. Progress still has no attempts or score. Test read mark was cleared afterwards; System language restored.
- Native layout inspected at a larger window and the exact 900 × 620 content minimum. Musical views remain selectable, the text area scrolls and selected events remain distinct without depending on color.

No audio service, permission request, raw recording or fabricated assessment is part of this task. Display-only chord mapping is covered by validated lesson fixtures in AppTests; native chord rendering evidence remains in reviews 08/09. Human musical/VoiceOver walkthrough remains U05; actual Xcode UI-test execution remains U07.
