# Advanced picking and hybrid coordination — same-agent review

Software verification and merge are recorded below; native/hardware acceptance remains pending_user. This review is by the implementing agent, not an independent reviewer.

## Scope

Four bilingual technique lessons (89 string skipping, 90 economy, 92 sweep, 95 hybrid) provide 17 timed graded monophonic activities, with separate physical self-observation. Optional `pluckFinger` adds p/i/m/a instructions to ordinary single-voice notes, preserved by resolution/history and rendered in TAB/staff/accessibility. It does not change audio capture, reference timbre, expected pitches, matching or scores. `file-coach-9` labels the finger role as authored/unverified. The existing pick-stroke model covers economy/sweep directions without claiming physical gesture detection.

## Findings and corrections

- Fixed string paths are part of these lessons. Relocation is disabled to avoid replacing a skipped/adjacent-string action with an equivalent pitch on another string. Standard/Drop tuning adaptation still changes sounding pitches, with all examples on unchanged-relative upper strings.
- The author helper inherited an inappropriate chords topic. All four new lessons are technique-tagged and the musical matrix explicitly asserts that tag. The same metadata issue in parent legato/tapping was corrected in PR 87 with a separate Release rebuild and regression.
- Economy's initial prerequisite named a nonexistent three-notes-per-string lesson. It now references the existing alternate-picking/C-major lessons; the new three-note-per-string pattern is taught explicitly here. Catalog validation passes.
- The turnaround keeps a separately attacked top pitch to establish the descending U–D–U pattern; the independent matrix checks all directions. Sweep examples use explicit reset rests and separate notes rather than pretending a polyphonic strum was measured. Minor sweep changes only the third; hybrid upper strings have fixed middle/ring assignments.
- The first additional finger branch pushed a large SwiftUI TAB header over the compiler's type-checking complexity limit. Extracted a small header builder with precomputed articulation text, keeping duration/continuation/rest rendering intact. Compilation and offline rendering pass afterward.
- The model rejects contradictory pick/finger, chord/rest and moving-technique cues. Missing optional fields preserve prior canonical encoding; a differential test verifies identical reference PCM and ordinary note assessment with/without p/i/m/a cues. This is instruction provenance, not a new audio capability.

## Evidence so far

- 680 independent activity/instrument cases (17 activities ×8 presets ×5 necks), each at 40/60/120 BPM. Fixed positions, exact MIDI pitches, source timing/rests, picking directions, finger/string roles and encoding are checked. Final matrix plus parent legato matrix: 2 tests, 3.351 s (`/tmp/advanced-picking-final-matrix.log`).
- Full Learning 134 tests/45 suites, 141.702 s; Domain 58 tests/18 suites, 0.339 s (`/tmp/advanced-picking-learning-domain.log`). The three-lesson matrix was later expanded for sweep and rerun as above. Existing DSP was unchanged and its full suite had just passed on the parent; the new differential audio test passes in 0.106 s (`/tmp/advanced-picking-core.log`).
- Full App 175 tests/53 suites, 200.963 s (`/tmp/advanced-picking-app-full.log`), including cue/coach/render changes. Final four-lesson reading/adaptation/notation/practice flow regression after adding sweep and updating catalog counts passes: 13 tests/3 suites, 24.843 s (`/tmp/advanced-picking-final-flow.log`).
- Offline renders `/tmp/picking-visuals/picking-{en,uk}-{light,dark}.png`; inspected Ukrainian light and English dark at 800 points. Down/m/a/m is visible in compact TAB and staff, with a localized legend. No native accessibility/interaction claim follows from ImageRenderer output.
- Coach provenance/response version rejection and render: 2 tests, 0.630 s (`/tmp/picking-render-coach.log`). No AI provider called.
- 905 bilingual UI keys; 100 bilingual lesson bundles; generated project and UI-source checks; five Python tests pass in 11.366 s. Full inventory: 94 authored/34 todo, 100 bundles/94 visible. Partial inventory validation is not full-course acceptance.

Signed root-only Release/archive/XPC and exact-head CI/merge remain to be recorded. Native/hardware acceptance stays pending_user.

Signed root-only Release/archive verified with 100 bilingual bundles (301 YAML files), arm64/macOS14, ad-hoc hardened sandbox and expected audio/read-selected-file entitlements. Binary SHA256 `cfa1ad6cf8298b342c9edfd6865853f451448f3c5e7e234419ebfec33e6c25b7`; archive `e887f533724739820e26c35042b470e58d0e566b450568c2988b9bb8799bf9fe`. See `docs/benchmarks/advanced-picking-release-bundle.json`. Signed sandbox→separate XPC service→invalidRequest passes; no provider called. Native app launch/hardware remain unverified; no local Debug app built. Exact-head CI/merge remains open.

Exact-head CI 35187518296 passed in 26m00s at 7e40da2c95bb01720572ca8fb40d029ea56a499a. PR 88 merged as 829c29fc06ad9fec9e378882bb6af1c5fde38cc6 on 2026-09-17. Remaining acceptance is native/hardware pending_user.
