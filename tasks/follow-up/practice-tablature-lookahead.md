# Practice tablature read-ahead

Status: `pending_user`

## Scope

Compact multi-bar, multi-row practice TAB with a continuous vertical playhead, visible count-in bar and smooth vertical following. Keep upcoming music visible, preserve bar/range selection and keyboard/VoiceOver access. Existing lesson/result TAB is unchanged.

## Acceptance

- Responsive rows, compact default size and readable zoom; no half-beat horizontal jumps.
- Visual count-in before the selected range: four beats in 4/4, three in 3/4, driven by the existing audio transport.
- Continuous within-bar/within-row cursor and animated row scrolling; automatic following can be disabled for manual reading; respect Reduce Motion.
- Pause, stop, retry, repeat, range/tempo/exercise changes do not leave a moving/stale cursor.
- Same canonical events/tuning/fret positions; no changes to metronome scheduling or scoring clocks.
- Meaningful count-in/latency/boundary/layout/lifecycle tests, English/Ukrainian UI and offline visual review.
- Signed local Release update; do not recreate Debug app. Live guitar/native accessibility gates stay explicit.

## Evidence

- 175 Core tests (20 + 56 + 31 + 64 + 4 across targets) and 101 App tests pass locally with Xcode 27.0 / Swift 6.4. Final view-only refinements were rechecked with all five score geometry/render checks.
- Focused coverage includes 3/4 and 4/4 count-in, 250 ms output latency, fractional samples, nonzero range starts, exact/partial endpoints, resize/zoom, canonical event/pitch identity, pause/reset and repeat lifecycle.
- 630 EN/UK keys, generated project, UI-test source typechecking and whitespace checks pass.
- Actual production score rows rendered in EN/UK, light/dark, 600/980 pt; narrow fractions and rest alignment corrected and re-rendered. Artifacts: `build/practice-score-renders/` (generated, not committed). Full native scroll/control rendering cannot be claimed from these images.
- Local Release .app and ZIP rebuilt, signed and verified; 13 bilingual lessons validated. [Bundle evidence](../../docs/benchmarks/practice-tablature-release-bundle.json). No Debug app was recreated.
- [Same-agent local review](../../docs/reviews/practice-tablature-lookahead-review.md). Native computer use timed out; real smooth scrolling, keyboard/VoiceOver and hardware acceptance remain in [USER-VALIDATION](../../docs/USER-VALIDATION.md).
