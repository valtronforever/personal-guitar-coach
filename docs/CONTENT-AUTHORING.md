# Authoring bilingual lessons

Lessons are original, read-only bundled data. Loading and reading them never requests audio permission. The musical model in Domain is the source of pitch, fret, tuning, and timing rules; do not encode independent target MIDI values alongside fret positions.

## Files

```text
Resources/Lessons/
  catalog.json
  open-strings-intro/
    lesson.json
    en.json
    uk.json
```

The checked-in [sample manifest](../Resources/Lessons/open-strings-intro/lesson.json), [English text](../Resources/Lessons/open-strings-intro/en.json), and [Ukrainian text](../Resources/Lessons/open-strings-intro/uk.json) are complete working examples. The introduction is part of the completed software content set for the [six-lesson starter course](STARTER-COURSE.md); native/live-user validation remains pending.

`catalog.json` defines display order:

```json
{"schemaVersion": 1, "lessons": ["open-strings-intro"]}
```

Each entry names a direct child directory. IDs use 1–64 ASCII characters: a lowercase letter first, then lowercase letters, digits, or hyphens. Paths, whitespace, translated text, and slashes are not IDs. Folder and manifest IDs must match. Lesson IDs and exercise IDs are unique across the loaded catalog; step IDs are local to a lesson, and event IDs are local to an exercise. Repeated catalog entries are rejected after the first; other valid lessons remain available.

## Manifest v1

`lesson.json` contains `schemaVersion`, stable `id`, positive `version`, `difficulty`, `topic`, `steps`, `exercises`, and `practiceExerciseIDs`.

- Difficulty: `beginner`, `intermediate`, `advanced`.
- Topic: `basics`, `chromatic`, `rhythm`, `majorScale`, `pentatonic`, `arpeggios`.
- At least one step and exercise are required, along with at least one monophonic practice entry.
- A display-only chord exercise may be included, but cannot appear in `practiceExerciseIDs`.
- Musical data follows [ARCHITECTURE.md](ARCHITECTURE.md) and the validating Domain decoders: six explicitly numbered strings, frets 0–24, PPQ 960, 3/4 or 4/4, ordered non-overlapping events, positive durations, and explicit tuning policy.
- Start with quarter notes (960 ticks), eighths (480), and sixteenths (240). Timing/model validity does not establish measured audio-analysis support; practice also applies the current capability limits.

An event step selects a note, a rest, or an ordered set of events. List an inclusive range by listing its event IDs in exercise order:

```json
{
  "id": "play-the-bar",
  "kind": "events",
  "exerciseID": "open-strings-intro-practice",
  "eventIDs": ["low-e", "first-rest", "high-e", "last-rest"]
}
```

Every event reference must exist in the named exercise. Duplicate or out-of-order references are invalid. A rest selects its timeline event and produces no fretboard note. A set of events may highlight several frets on one string, useful for a scale. The renderer receives positions directly from the resolver, without parsing lesson prose.

A shape step uses `kind: "fingering"`, an `exerciseID` for its tuning context, `eventIDs: []`, and a `fingering` object. `positions` contain `string` and `fret`; `mutedStrings` is a separate array. Optional `fingerNumbers` maps string numbers to fingers 1–4, using JSON object keys such as `"5": 2` and `"4": 3`. The shape must contain at least one sounding or muted string; sounding and muted sets cannot overlap. A text-only step uses `kind: "none"`, `eventIDs: []`, and no exercise/fingering. It clears visual selection.

For both event and shape steps, the referenced exercise determines the tuning: fixed-tuning previews use the exercise's snapshot even when the user's guitar differs; follows-instrument previews use the selected instrument snapshot. Reading an incompatible tuning remains possible, with a mismatch explanation before practice.

## Text resources

Both files contain `lessonID`, `lessonVersion`, `locale` (`en` or `uk`), `title`, `summary`, `goal`, `body`, and a `steps` object. Each step ID maps to a nonempty `title` and `body`. Every required text must contain visible characters. Text is plain UTF-8; paragraphs use newline characters. No prose is parsed for note positions or timing.

```json
{
  "lessonID": "open-strings-intro",
  "lessonVersion": 1,
  "locale": "en",
  "title": "Meet your open strings",
  "summary": "Find low E2 and high E4, with a beat of silence between them.",
  "goal": "Play two open E strings at a steady pulse and leave the rests quiet.",
  "body": "See the complete sample for the full lesson text.",
  "steps": {
    "hear-low-e": {"title": "1. Hear the low E", "body": "Pluck open string 6 on beat 1."},
    "leave-space": {"title": "2. Leave a beat of silence", "body": "Stop the string and keep counting."},
    "hear-high-e": {"title": "3. Hear the high E", "body": "Pluck open string 1 on beat 3."},
    "play-the-bar": {"title": "4. Put the four beats together", "body": "Low E, rest, high E, rest."}
  }
}
```

The two translations must match the same lesson ID/version and exactly the same set of step IDs. Musical references live only in the shared manifest. Missing, blank, or mismatched translations reject the affected lesson, with a reason for the author; they do not silently substitute another language. The UI chooses en/uk without changing lesson identity. Linguistic and musical equivalence still require human review; parity validation cannot prove translation quality.

## Versions and historical data

- Increment lesson `version` when its teaching sequence, steps, or text changes meaningfully; update `lessonVersion` in both translations together.
- Increment exercise `version` when notes, timing, tuning requirements, or assessment meaning changes. Preserve existing IDs when the concept is the same; use a new ID for a distinct exercise.
- Increase `schemaVersion` for incompatible format changes and implement an explicit migration/reader update. Unknown schemas are checked before their payload is interpreted.
- Do not rewrite past practice snapshots or scores when content changes. Preserve their exercise/tuning/result versions; current audio capability limits must not be applied when merely reading history.

## Validation and publishing into a local build

Run from the repository root with the selected Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/GuitarCoachCore
python3 Scripts/check_localizations.py
python3 Scripts/generate_project.py --check
python3 Scripts/build_local.py
```

The CLI exits nonzero for any content issue or an empty catalog and prints lesson ID, reason code, and diagnostic detail. CI validates the actual bundled course. The loader keeps valid lessons available if another lesson fails and never rewrites resource files. In-app warnings explain why entries are unavailable; their list is bounded so it cannot cover the healthy catalog.

Before marking new teaching content complete, inspect both languages in the native app and check the resolver's fretboard/timeline targets. Never substitute a synthetic audio test for actual guitar accuracy evidence. Importing songs, scraping tablature services, and adding copyrighted course text are outside this authoring workflow.
