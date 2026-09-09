# Task 05 local review

Self-review by the implementing agent; no independent review is claimed.

Reviewed atomic write boundaries, recovery behavior, immutable attempt identity, version handling, actor isolation, UI publication after successful saves, deletion scope, and snapshot independence.

## Findings and fixes

- A file-existence check could confuse an unreadable preferences path with missing preferences. Loading now attempts the read and treats only explicit file-not-found errors as first-launch defaults.
- Editing before the first load could temporarily expose defaults. UI preference edits now require completed loading; unsupported/corrupt settings disable editing until explicit recovery.
- The history index is a cache, not the source of truth. If its write fails after an attempt commits, the save returns a warning; the committed attempt stays available on the next rebuild. Tests distinguish this from a failed attempt write.
- A malformed directory ending in .json must not be recursively deleted by Clear history. Deletion now accepts only regular files/symlinks and reports failure for directories. A regression test preserves a nested file.
- Record loading checks filename/UUID consistency, duplicate identities, outer/result schema versions, musical validity, numeric bounds, and score/validity consistency. An uncalibrated snapshot containing an overall grade is rejected.
- Previews now receive an isolated LocalDataStore. Production scenes share one repository actor and never write on the audio callback.

## Verification

- Core Swift Testing suite: 29 tests in four suites; 12 cover persistence, including migration, concurrent saves, real filesystem failure, injected disk-full failure, corrupt/future records, index rebuild, identity conflicts, and delete scope.
- App state suite: three tests confirm failure does not publish an unsaved selection, source preferences restore, and future preferences disable editing until recovery. All use temporary directories, without user data.
- Debug/Release native builds and strict ad-hoc signatures pass. Catalog validation passes for 89 en/uk keys; generated project and whitespace checks pass.
- Native CUA: selected Acoustic guitar · Pickup, relaunched, verified restored selection, then returned to Electric guitar · Audio interface. Progress shows the actual empty history and a disabled Clear button.

The v1 preferences migration fixture is a documented schema compatibility fixture, not a claim of an earlier distributed app. History rows currently expose stored summaries; full result details/recommendations arrive in tasks 17–18. No synthetic attempts were inserted into the user's history, and no audio was recorded. Xcode UI-test execution remains U07.
