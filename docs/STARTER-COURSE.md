# Starter course

**Current behavior (2026-09-12):** the user sees one six-lesson course that automatically adapts to the tuning in Settings/Tuner. See [automatic lesson tuning](AUTOMATIC-LESSON-TUNING.md) for transposition, Drop D/custom mapping, current templates and history compatibility. The static Standard/C Standard inventories and dated evidence below describe the retained source/legacy resources, not two separate live course choices.

Thirteen bilingual lesson bundles use schema 2: six adaptive starter lessons, one guided position-exploration lesson, and six historical C Standard bundles retained for saved IDs. The library shows seven lessons; the historical bundles are hidden from new-course browsing. Each starter lesson includes a goal, prerequisites, short explanations, selectable steps, explicit Standard tuning (strings **6 → 1: E2 A2 D3 G3 B3 E4**, A4 = 440 Hz), one scored single-note exercise and a recommended starting tempo. The final Standard lesson additionally provides an Em chord example for display/listening only.

| Lesson / resource ID | Focus | Practice | Start / available BPM | Next tempo suggested in text |
| --- | --- | --- | --- | --- |
| Meet your open strings / `open-strings-intro` | String numbering, first tuning, two E octaves and rests | 1 bar, 2 attacks + 2 quarter rests | 60 / 40–100 | Repeat at the same tempo first |
| Your first frets / `first-frets` | Chromatic motion on string 6, frets 0–3 | 2 bars, 8 quarter-note attacks | 60 / 40–100 | 70 after comfortable repeats |
| Keep a steady pulse / `steady-pulse` | Repeated E2, quarter/eighth subdivisions and rests | 2 bars, 8 attacks + 4 rests | 60 / 40–100 | 70 after comfortable repeats |
| C major across the strings / `c-major` | Open-position C3–C4 ascent and return | 4 bars, 15 attacks + a final quarter rest | 60 / 40–100 | 70 after comfortable repeats |
| A minor pentatonic in one position / `a-minor-pentatonic` | A–C–D–E–G across frets 5–8, A2–C5 and return | 6 bars, 23 attacks + a final quarter rest | 50 / 40–90 | 60 after comfortable repeats |
| From an Em shape to separate notes / `em-arpeggio` | Em shape, then separate ascending/descending chord tones | 3 bars, 11 attacks + a final quarter rest | 60 / 40–100 | 70 after comfortable repeats |

These tempo suggestions are optional teaching steps, not automatic promotions or claims of mastery. For direct score comparison, keep the same tempo, fragment, tuning and other saved conditions. Scoring/recommendation rules still determine eligibility; unavailable rhythm is not a playing failure.

## Musical audit

- Chromatic: E2 F2 F♯2 G2 | G2 F♯2 F2 E2. The repeated G2 at the bar boundary needs another attack.
- Rhythm: bar 1 attacks on beats 1, 3, 4, rest on beat 2. Bar 2 attacks on 1, 1-and, 2-and, 3, 4; rests on 2, 3-and, 4-and. Quarter ticks = 960, eighth ticks = 480, total = 7680.
- C major ascending positions: 5/3, 4/0, 4/2, 4/3, 3/0, 3/2, 2/0, 2/1 (`string/fret`). Expected MIDI: 48, 50, 52, 53, 55, 57, 59, 60. Descend through the reverse sequence without repeating the top C, then rest. E–F and B–C are the two semitone pairs.
- A minor pentatonic ascending positions: 6/5, 6/8, 5/5, 5/7, 4/5, 4/7, 3/5, 3/7, 2/5, 2/8, 1/5, 1/8. Expected MIDI: 45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72. The highest note is C5; the text does not call it a two-octave A-to-A scale. Descend without repeating C5, then rest.
- Em, strings 6 → 1: frets 0–2–2–0–0–0 → E2 B2 E3 G3 B3 E4, pitch classes E/G/B. Suggested fingers 2/3 apply to strings 5/4 only. The arpeggio returns E4 → B3 → G3 → E3 → B2 → E2, with the top E4 played once and a final rest.

The entire practice set contains 67 separate expected attacks and 9 rests over 18 bars. Pitches range from E2 to C5. The fastest declared notes are eighths at 100 BPM (300 ms), within the existing ≥200 ms capability. Every practice is checked at its minimum/default/maximum BPM. Selecting Drop D still shows the fixed Standard targets and blocks practice until tuning matches.

## Reading, playing and history

Both locales share one musical manifest. Every musical practice event is referenced by at least one teaching step. Fretboard positions are deduplicated visually, while tablature and assessment preserve repeated note events and distinct attacks. Shape steps show suggested fingers; they do not infer a player's fingers from audio.

Practice in the course uses one sounding note at a time. The Em lesson explicitly distinguishes a ringing chord example from the assessed arpeggio and asks the learner to damp the previous string. Rest duration is taught for listening/counting; the app does not claim validated note-duration detection. Electric-interface input is primary, with acoustic microphone/pickup source options explained in the introduction.

The introduction is now **lesson version 2** because its teaching text adds prerequisites, all six open pitches, tuner/input guidance and result interpretation. Its note/timing exercise remains **exercise version 1**. Existing practice records retain their saved snapshots. A version-1 reading bookmark/read marker does not silently mark the expanded lesson read. All five new lessons begin at lesson/exercise version 1.

## Provenance and validation

Texts, step sequences, fingerings and exercise arrangements were authored specifically for this project. No Songsterr catalog, proprietary course text, song transcription or external recording was copied into these lessons. Conventional scale/chord names describe basic musical material; shared fret/tuning math remains in Domain.

`StarterCourseTests` validates independent MIDI sequences, time/attack/rest counts, tuning and capability limits, reference/localization coverage, and the Em display-only boundary. It evaluates perfect and healthy-all-missed event fixtures at both 44.1 and 48 kHz with a known +50 ms residual offset. These fixtures are deterministic event evidence, **not PCM, microphone capture or proof of live guitar accuracy**.

`StarterCourseFlowTests` loads all twelve actual bundled lessons, selects every step, checks fretboard/TAB state, opens practice without capture, saves synthetic pitch-only results and follows recommendation retry links with the correct exercise/range/BPM. It reloads history in both languages and checks the introduction's version boundary.

Native en/uk layout/VoiceOver and beginner/live-playing review remain in final U05/U07/U10 after all 22 implementation tasks. The current computer-use pipe failure prevents claiming visual validation for this content expansion.


## C Standard course (2026-09-11)

Select the built-in C Standard preset in Instrument settings or Tuner, then a lesson marked C Standard. Both languages include all explanations and steps. Strings **6 → 1: C2 F2 B♭2 E♭3 G3 C4**, MIDI **36, 41, 46, 51, 55, 60**, A4 = 440 Hz. The app does not physically retune or pitch-shift the guitar.

| Resource ID | Sounding material | Same positions and timing as |
| --- | --- | --- |
| `c-standard-open-strings` | C2 and C4, two rests | `open-strings-intro` |
| `c-standard-first-frets` | C2 D♭2 D2 E♭2, then return | `first-frets` |
| `c-standard-steady-pulse` | Repeated C2 with quarter/eighth rests | `steady-pulse` |
| `ab-major-c-standard` | A♭2 B♭2 C3 D♭3 E♭3 F3 G3 A♭3, then descend | `c-major` |
| `f-minor-pentatonic-c-standard` | F A♭ B♭ C E♭; F2 to A♭4 and return | `a-minor-pentatonic` |
| `cm-arpeggio-c-standard` | C2 G2 C3 E♭3 G3 C4 and return; Cm shape display only | `em-arpeggio` |

All new lesson/exercise IDs are distinct and begin at version 1. Original resources, bookmarks and result snapshots remain unchanged. Both courses use `fixedTuning`: choosing the other preset does not silently transpose an existing lesson. History and recommended retries retain the saved exercise/tuning. The C Standard course adds 29 steps, 67 assessed attacks, nine rests and 18 bars. Its lowest pitch C2 (65.406 Hz) is at the existing software capability boundary; no DSP limits or grading thresholds were loosened.

Independent MIDI goldens cover all twelve sequences, both sample rates, tuning mismatch, display-only chord boundaries and result/retry snapshots. Synthetic PCM passes through the real analyzer and manual/automatic tuner for all six C Standard open strings at 44.1/48 kHz. Automatic mode preserves harmonic-ambiguity confirmation for G3/C4; manually selecting the string permits normal tuning feedback. These checks do not establish accuracy on the connected guitar; that remains U02/U10 in USER-VALIDATION.md. C Standard labels use flats across musical views; neutral staff notation displays explicit accidentals without pretending to infer the key.


## Guided positioning extension

[Same notes, different positions](../Resources/Lessons/same-notes-new-position/lesson.yml) reuses one major-scale exercise for a single-note fragment, learner exploration, fixed Original and fixed near-seven performances. The complete scale uses width 6 and allowed starts 3/7; the note uses width 5 and starts 3–12. Each performance is a separate attempt with frozen activity conditions. Generic theory is independent of tuning; activity text, fretboard, tab/staff and practice use the selected snapshot. See [authoring](CONTENT-AUTHORING.md) for the sole current API. Real guitar comfort and native accessibility checks remain in USER-VALIDATION.
