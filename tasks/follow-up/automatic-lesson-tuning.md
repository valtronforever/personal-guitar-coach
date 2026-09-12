# Automatic lesson tuning

Status: `done`

User request (2026-09-12): select one tuning in Settings and automatically adapt every course lesson. Confirmed policy: transpose musical lessons with the tuning (C Standard turns C major into A♭ major while preserving the familiar positions).

Implementation contract:

- One six-lesson catalog; retain legacy resources/IDs for historical records and route old bookmarks to the corresponding current lesson.
- Open-string, chromatic and rhythm lessons follow their taught fret patterns. Scales/arpeggios preserve intervals: transpose by the difference of string 1 from its Standard reference, then adjust positions for nonuniform tunings such as Drop D. State this convention explicitly for custom tunings.
- Update both languages, names, note/position explanations, shape, fretboard, TAB/staff, preview and new practice targets from one resolved lesson snapshot.
- Preserve selected step/event IDs across tuning changes. Stop an active attempt/preview; archived results and recommendation retries retain their exact original tuning and targets.
- If the six-string/24-fret instrument cannot represent a target or a supported chord shape, show an explicit localized unavailable state; never silently show or score different notes.
- Meaningful tests cover all presets, custom A4/nonuniform/extreme tunings, musical intervals and pitches, localization, selection/state changes, persistence and archived retry isolation. Build/test, same-agent review, native checks, PR and merge.

Evidence: 200 local tests passed; final template regression passed; Release app/ZIP verified and native Settings to lesson to practice flow checked in en/uk. See [local review](../../docs/reviews/10-automatic-lesson-tuning-review.md), [behavior contract](../../docs/AUTOMATIC-LESSON-TUNING.md) and [bundle report](../../docs/benchmarks/10-automatic-tuning-release.json). Hardware-dependent parent tasks remain pending_user.
