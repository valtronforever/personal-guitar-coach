# Authoring bilingual lessons

Lesson manifests use **schema 2 only**. Each lesson has `lesson.json`, `en.json` and `uk.json`; there are no baseline/adaptive text editions. The ordering file `catalog.json` has its own schema 1. Loading content is read-only, offline and does not request audio permission.

## Create and validate a draft

```sh
python3 Scripts/new_lesson.py my-lesson
python3 Scripts/new_lesson.py scale-study --policy transposeIntervals --positioning-window 6 --starts 3,7
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons --positions same-notes-new-position > /tmp/positions.json
```

The scaffold defaults to positioning disabled. `--starts` accepts `auto`, a sorted unique list such as `3,7`, or an inclusive range such as `3:12:1`. It requires `--positioning-window` (1–6). Edit both translations and the source exercise before publishing a draft. The position report evaluates one lesson against eight tuning presets and five neck sizes, using the actual resolver. It lists each choice and its failure reason. Mathematical feasibility does not establish ergonomic comfort or audio assessment capability.

The [minimal template](templates/lesson/lesson.json) and [complete demonstration](../Resources/Lessons/same-notes-new-position/lesson.json) are loadable examples. The demonstration shares one exercise across note exploration, scale exploration, fixed Original and fixed near-seven performances. Use it to author a teaching sequence without writing Swift.

## Music, materials and activities

| Entity | Author responsibility |
| --- | --- |
| `exercises` | Canonical musical events, timing, source tuning and practice capability |
| `fingerings` | Named source chord shapes, each with an exercise ID establishing its tuning context |
| `materials` | Select reusable musical content and optionally permit positioning |
| `activities` | Instantiate a material with a learner choice or a fixed choice |
| `steps` | Ordered instruction and visual subset, attached to an activity |
| `practiceEntries` | Stable entry ID, activity ID and source exercise ID |

A lesson requires positive `version`, difficulty (`beginner`, `intermediate`, `advanced`), topic (`basics`, `chromatic`, `rhythm`, `majorScale`, `pentatonic`, `arpeggios`), nonempty steps/exercises/materials/activities/practiceEntries and a `fingerings` array (possibly empty). Bounds: 512 steps, 64 exercises, 4096 events per exercise, 128 materials/shapes and 256 activities/practice entries.

IDs contain 1–64 lowercase ASCII letters, digits or hyphens, starting with a letter. Lesson and exercise IDs are unique across the catalog; the other IDs are local to their owner. Folder and lesson ID must agree. Invalid lessons produce author diagnostics while healthy lessons remain available.

Six strings use 1 = thinnest and 6 = thickest, with sounding MIDI (C4 = 60). Fret 0 is open; muted strings are separate. PPQ is 960; supported signatures are 3/4 and 4/4. Events are ordered, non-overlapping and have positive duration. Do not duplicate computed target MIDI next to fret positions. Domain derives pitches consistently for every consumer.

Material `source` is one tagged object:

```json
{"kind":"lesson"}
{"kind":"exercise","exerciseID":"my-lesson-practice"}
{"kind":"events","exerciseID":"my-lesson-practice","eventIDs":["start","step-up"]}
{"kind":"fingering","fingeringID":"chord-shape"}
```

A single event selects one note. An event fragment must be contiguous in source order, including internal rests. Its derived exercise starts at tick 0 while preserving IDs, durations, rests and the source tick offset. A material cannot combine incompatible source tuning contexts. A whole-lesson material includes linked shapes and arpeggios so they retain consistent positions. A chord shape moves as a complete voicing on distinct strings; it remains display/preview only. Use a separate monophonic arpeggio for assessment.

## Tuning adaptation and positioning

Optional `adaptation` contains only `policy`:

- `fretPattern`: retain the physical pattern under the selected tuning, appropriate for open strings and technique drills.
- `transposeIntervals`: transpose by the difference between selected and reference string 1, then find positions preserving those intervals. E/D/C/B Standard retain the pattern. Drop adjusts the low string while keeping the intended music.

Without adaptation, a fixed-tuning source stays fixed; a follows-instrument source uses the selected tuning. Every resolved exercise freezes the actual tuning. Lesson positioning happens after choosing sounding pitches and **never changes the key or octave**.

Omitted `positioning`, or `{"enabled":false}`, opts out. Enabled materials declare:

```json
{
  "enabled": true,
  "preserve": "soundingPitch",
  "windowFrets": 6,
  "allowedStarts": {"kind":"explicit","frets":[3,7]},
  "allowOriginal": true
}
```

`allowedStarts` also accepts `{"kind":"auto"}` (0–24) and `{"kind":"range","minimum":3,"maximum":12,"step":1}`. These are region starts, not every permitted note fret. A region from 7 with width 6 spans frets 7–12, limited by the configured neck. The first note need not be at fret 7. Availability requires the **complete material** to fit; selecting one step does not relax its material's constraints.

Every enabled activity declares exactly one selection:

```json
{"id":"explore","materialID":"scale","positionSelection":{"mode":"learner","default":{"kind":"original"}}}
{"id":"seven","materialID":"scale","positionSelection":{"mode":"fixed","value":{"kind":"region","firstFret":7}}}
```

A fixed Original uses `"value":{"kind":"original"}`. Original must be allowed when used by either mode. Disabled materials omit `positionSelection`. A permitted choice can still be unavailable on a particular instrument. The UI retains that choice with an explanation, offers feasible alternatives for learner activities and keeps other steps accessible. It never silently substitutes another key, octave or position.

## Steps, text and practice

An event step requires `activityID`, `exerciseID` and ordered `eventIDs` contained in its material. A shape step requires `activityID`, `exerciseID`, `fingeringID` and empty `eventIDs`; the shape lives in the top-level registry. A text-only step has `kind: "none"`, empty events, no exercise/shape, and optional activity ID. Several steps sharing an activity intentionally share its choice; separate activities retain independent choices even when reusing the same exercise.

Each translation has lesson ID/version, locale (`en`/`uk`), generic `title`, `summary`, `goal`, `body`, plus exact `steps` and `activities` maps with nonempty title/body. Generic teaching fields cannot contain instrument tokens. Activity and step templates support:

| Token | Meaning |
| --- | --- |
| `tuning`, `reference`, `openExample`, `openStrings` | Actual tuning, A4 and open strings (6→1) |
| `root`, `first`, `highest`, `sequence` | First pitch class, first sounding pitch, highest pitch and complete material sequence |
| `positions`, `notes` | Complete activity material, or selected visual subset in a step |
| `positionLabel` | Localized Original/region label including authored width |

Use `{{token}}` syntax. Both languages must have matching token sets in corresponding title/body fields. Unknown, malformed, missing or blank content fails validation. A text step without an activity cannot use context tokens. Plain UTF-8 paragraphs use newlines. Prose never determines notes or timing. Review musical and linguistic equivalence manually; structural parity is not a translation-quality assessment.

A practice entry is, for example, `{"id":"seven-practice","activityID":"seven","exerciseID":"my-lesson-practice"}`. It must refer to sounding monophonic material; fragment practice may end in a partial bar. The staff view labels that partial ending and adds no synthetic trailing rests. Simultaneous chords cannot be graded. Existing pitch range, duration/tempo, signal and calibration gates still apply. Every performance is a separate attempt; continuous assessed transitions between positions are outside this release.

## Versioning and saved evidence

Increment lesson `version` and both text `lessonVersion` fields for meaningful teaching changes. Increment the source exercise version when music changes. Localized strings are never persistence keys. Learner bookmarks store choices by lesson version and activity ID. An invalid saved choice stays visible until corrected; incompatible lesson versions reset selection normally.

Practice freezes activity/material/entry IDs, choice, full policy, resolver version, source event IDs/tick offset, localized lesson/activity titles and the actual exercise/instrument. Historical retry uses this evidence without rerunning current author rules. Comparison requires matching activity conditions. Existing saved practice records remain readable without rerating; this is independent of supporting an old lesson API. Prior records without frozen titles may show a generic current title or the saved-exercise fallback.

Manual fingering confirmation is an explicit self-report, separate from audio scoring. It is scoped to activity, choice, tuning and neck, and is cleared for an archived retry. Audio establishes pitch/timing evidence, never which string, fret or finger was used.
