# Automatic lesson tuning and fretboard positioning

The current contract is [schema-2 lesson authoring](CONTENT-AUTHORING.md). It replaces the former whole-lesson adaptation API and dual text editions completely.

For six-string E/D/C/B Standard guitars, interval lessons retain the reference fingering and transpose the sounding key. With C Standard, a reference C-major pattern sounds A♭ major. Corresponding Drop tunings change the sixth string by a further whole tone, so interval lessons adjust that string's positions or find another exact-pitch fingering. Physical drills explicitly use `fretPattern` instead. These policies are independent of language and apply before position selection.

## Choosing a fretboard position (2026-09-12)

Authors explicitly enable positioning on a reusable material, with width 1–6, auto/list/range starts and optional Original. Activities choose learner-controlled or fixed positions. A region from fret 7 names a search window; it does not force the first note onto fret 7. Every sounding pitch and octave is preserved. Availability uses the complete material and Settings' 19/20/21/22/24-fret limit.

For the reference major scale in C Standard, width 5 from 7 yields frets 8,10,7,8,10,7,9,10 and returns, sounding A♭ major. In Drop B♭, that whole scale needs width 6 to include fret 12; width 5 is explicitly unavailable. No octave/key substitution is used to manufacture feasibility.

The reader retains independent activity choices, interrupts preview on context changes, and leaves other activities accessible when one fails. Practice freezes the resolved exercise and authored context; archived retries do not reread current author policy. Old practice evidence remains readable and is never rerated. A manual fingering confirmation is separate from audible pitch/timing evidence.

Complete runnable example: [same-notes-new-position](../Resources/Lessons/same-notes-new-position/lesson.yml). Design and acceptance: [lesson positioning](design/lesson-positioning/README.md), [LD01–LD04](../tasks/follow-up/lesson-design-system.md).
