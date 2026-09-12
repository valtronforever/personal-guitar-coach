# Independent lesson text and authoring — local review

Date: 2026-09-12. Reviewer: the implementing agent (same-agent review, not independent).

Scope: all six current adaptive en/uk resources, generic teaching/example separation, loader/resolver compatibility, reader presentation and historical headings, draft creation/template and author documentation. Standard/Drop musical calculations and all existing musical manifests remain unchanged.

Findings and fixes:
- The old title/summary/body mixed theory with resolved pitches and repeated setup prose. Generic fields now remain constant; variant/step templates contain calculated details, and one native component provides instrument conditions and expandable common guidance. Parity, nonblank and token validation cover the added fields.
- Renaming the current heading could silently rename past results. Optional historicalTitle preserves the original version's heading; current catalog/reader/practice use the generic title. Existing lesson/exercise versions remain unchanged for this editorial reorganization with equivalent goals and unchanged steps/events. Regression verifies both historical languages and bookmark retention.
- Scaffold IDs need room for the exercise suffix and must not overwrite data. The command constrains IDs, refuses existing folders/catalog entries and collisions with existing exercise IDs, prepares a full folder before catalog registration and rolls back its own folder on registration failure. Tests check unsafe IDs, duplicate refusal, collision refusal and unchanged existing bytes.
- An incomplete template folder could be silently copied with globbing. Draft creation now requires every one of the five expected JSON resources before registration.
- The existing adaptive text renderer incorrectly required exercise data for a text-only step, despite the authoring contract permitting kind none. It now renders such steps without leaking the previous step's positions/notes. The complete authoring template includes a text-only reflection step, exercised through the real loader/resolver for both policies.
- The open-string example title originally used the highest pitch as if it always represented string 1. The variant now identifies strings 6 and 1 directly; the computed sequence carries their actual pitches even in nonuniform custom tunings.

Evidence:
- Full Core suite: 142 tests / 28 suites passed (55.173 s); full App suite: 72 tests / 20 suites passed (80.601 s). After the final scaffold collision/text-only fixes, all 19 LessonAuthoring/LessonAdaptation/LessonContent tests passed (0.823 s).
- 240 current-course instrument combinations retain identical generic title/summary/goal/body while resolving example pitches. Existing golden MIDI/Drop voicing and persistence/active-practice tests pass. No existing lesson.json musical file changed.
- Real scaffold output for both policies loads in a temporary catalog, resolves all eight presets on a 19-fret instrument, contains both translations and clears visualization for its text-only step. No sample lesson was added to the production catalog.
- Localization: 522 UI keys, en/uk format placeholders passed. Generated project current; UI-test source typecheck passed. Release builder validates all 12 bilingual bundled lessons. Final signed arm64 Release app and ZIP pass the [bundle check](../benchmarks/07-authoring-release.json).

Native verification limitation: the new Release app was launched and its process confirmed running, but the CUA native bridge repeatedly returned “Sky Computer Use native pipe closed before response”, including after resetting the session. Consequently this change has no claimed native visual/interaction acceptance in either language. The concrete U05 follow-up is in USER-VALIDATION.md; software/build verification and merge can proceed under the project's existing deferred-user-validation rule. No microphone capture, hardware accuracy, full VoiceOver or visual theme audit was claimed. Xcode Debug/Release app-target checks are delegated to GitHub CI; local checks use SwiftPM and the release builder.
