# Authoring bilingual lessons

Lessons are UTF-8 YAML (`.yml`). Manifests use **schema 3 only**. Each lesson has `lesson.yml`, `en.yml` and `uk.yml`; there are no baseline/adaptive text editions. The ordering file `catalog.yml` has its own schema 1. Loading content is read-only, offline and does not request audio permission.

## YAML conventions

Use two spaces for indentation and no tabs. Each file contains one document; comments (`# ...`) are welcome. Use `|-` for literal paragraphs and `>-` to fold wrapped lines into one paragraph without a trailing newline. Quote text containing `: ` or ` #`, strings such as `yes`/`null`, and values beginning with `{{...}}`. Musical numbers remain numbers; booleans use `true`/`false`. Duplicate mapping keys are rejected. Prefer explicit values over YAML anchors, merge keys or custom tags.

The app reads `.yml` directly with Yams; no JSON lesson fallback or generated JSON copy is needed. The lesson contract is schema 3; catalog schema remains 1. Existing lessons moved to schema 3 without changing their content/exercise versions or musical events. Saved settings, practice evidence and machine-readable availability reports remain JSON.

## Create and validate a draft

Set up the Python author tools once and activate the environment when authoring, testing or packaging:

```sh
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r Scripts/requirements.txt
```


```sh
python3 Scripts/new_lesson.py my-lesson
python3 Scripts/new_lesson.py setup-check --mode theory
python3 Scripts/new_lesson.py chord-study --mode selfPractice
python3 Scripts/new_lesson.py listening-study --mode listening
python3 Scripts/new_lesson.py scale-study --policy transposeIntervals --positioning-window 6 --starts 3,7
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons --positions same-notes-new-position > /tmp/positions.json
```

The scaffold defaults to positioning disabled. `--starts` accepts `auto`, a sorted unique list such as `3,7`, or an inclusive range such as `3:12:1`. It requires `--positioning-window` (1–6). Edit both translations and the source exercise before publishing a draft. The position report evaluates one lesson against eight tuning presets and five neck sizes, using the actual resolver. It lists each choice and its failure reason. Mathematical feasibility does not establish ergonomic comfort or audio assessment capability.

The [minimal template](templates/lesson/lesson.yml) and [complete demonstration](../Resources/Lessons/same-notes-new-position/lesson.yml) are loadable examples. The demonstration shares one exercise across note exploration, scale exploration, fixed Original and fixed near-seven performances. Use it to author a teaching sequence without writing Swift.

## Music, materials and activities

| Entity | Author responsibility |
| --- | --- |
| `exercises` | Canonical musical events, timing, source tuning and practice capability |
| `fingerings` | Named source chord shapes, each with an exercise ID establishing its tuning context |
| `materials` | Select reusable musical content and optionally permit positioning |
| `activities` | Instantiate a material with a learner choice or a fixed choice |
| `steps` | Ordered instruction and visual subset, attached to an activity |
| `practiceEntries` | Automatically assessed monophonic practice: stable entry ID, activity ID and source exercise ID |
| `learningTasks` | Optional step-bound checklist, self-practice criteria or multiple-choice question |

A lesson requires positive `version`, difficulty (`beginner`, `intermediate`, `advanced`), topic (`basics`, `chromatic`, `rhythm`, `majorScale`, `pentatonic`, `arpeggios`, `theory`, `technique`, `chords`, `earTraining`, `tone`), nonempty steps and explicit exercises/materials/activities/practiceEntries/fingerings arrays (each may be empty). Bounds: 512 steps, 64 exercises, 4096 events per exercise, 128 materials/shapes and 256 activities/practice entries/tasks. A purely textual lesson needs no exercise, material or audio access.

IDs contain 1–64 lowercase ASCII letters, digits or hyphens, starting with a letter. Lesson and exercise IDs are unique across the catalog; the other IDs are local to their owner. Folder and lesson ID must agree. Invalid lessons produce author diagnostics while healthy lessons remain available.

Six strings use 1 = thinnest and 6 = thickest, with sounding MIDI (C4 = 60). Fret 0 is open; muted strings are separate. PPQ is 960; supported signatures are 3/4 and 4/4. Events are ordered, non-overlapping and have positive duration. Do not duplicate computed target MIDI next to fret positions. Domain derives pitches consistently for every consumer.

Material `source` is one tagged object. Choose one of these alternatives:

```yaml
{kind: lesson}
```
```yaml
{kind: exercise, exerciseID: my-lesson-practice}
```
```yaml
{kind: events, exerciseID: my-lesson-practice, eventIDs: [start, step-up]}
```
```yaml
{kind: fingering, fingeringID: chord-shape}
```

A single event selects one note. An event fragment must be contiguous in source order, including internal rests. Its derived exercise starts at tick 0 while preserving IDs, durations, rests and the source tick offset. A material cannot combine incompatible source tuning contexts. A whole-lesson material includes linked shapes and arpeggios so they retain consistent positions. A chord shape moves as a complete voicing on distinct strings; it remains display/preview only. Use a separate monophonic arpeggio for assessment.

## Learning tasks and completion

`learningTasks` is optional (omitted means no tasks). A lesson may combine all modes. An entirely theoretical lesson can also contain only text and the existing “mark read” action.

| Kind | Required fields | Meaning |
| --- | --- | --- |
| `checklist` | `id`, `stepID`, ordered `itemIDs` (1–32) | Personal confirmation of preparation or understanding |
| `selfPractice` | Same fields as checklist | Self-reported technique criteria; optional musical step for fretboard/TAB/preview/metronome |
| `quiz` | Same fields, 2–8 options, `correctOptionID` | One selected answer, explicit correct/incorrect feedback, explanation and retry |
| Existing `practiceEntries` | Activity and monophonic exercise reference | Performed audio assessment, still subject to signal/timing/capability gates |

Example manifest task:

```yaml
learningTasks:
  - id: clean-chord
    stepID: play
    kind: selfPractice
    itemIDs: [both-notes, unused-strings]
```

Both `en.yml` and `uk.yml` require exactly matching task/item IDs:

```yaml
learningTasks:
  clean-chord:
    title: Assess your sound
    body: Listen before marking these criteria.
    items:
      both-notes: I can hear both intended notes.
      unused-strings: The other strings remain quiet.
```

Questions additionally require a nonblank localized `explanation`. A question checks immediately when an answer is selected, then locks the options until retry. Checklist/self-practice tasks forbid `correctOptionID`, `stimulusExerciseID` and explanation text. Task prose is instrument-independent and cannot contain musical template tokens; use the associated activity copy for computed notes/positions.

For an ear-training question, set `stimulusExerciseID` to a sounding exercise in the step's activity. Use a dedicated `kind: exercise` material, `adaptation.policy: transposeIntervals`, no positioning, a text-only step (`kind: none`), and no practice entry for that activity. The listening step contains exactly one task and is the only step in its activity. The reader hides its activity copy, fretboard and TAB, while **Listen to example** plays the resolved notes through the selected output. No microphone permission is needed. The example uses its full range/default tempo, no count-in, no click and no loop; it stops on navigation or instrument changes. Use generic titles, instructions and answer labels: do not print the correct note/interval in the question or elsewhere in the visible lesson. The validator checks structural/template leaks, not the semantics of natural-language clues.

These are fixed author-written questions, not a randomized question bank. `correctOptionID` is an author assertion: validate it against the example in all supported tunings. Interval-preserving transposition supports questions about direction/interval; absolute note-name questions need instrument-specific answer generation, which is not implemented. The examples use synthesized reference tones; they do not demonstrate pick attack, distortion, muting or other guitar techniques.

The reader exposes tasks for the selected step. Checklist completion means all criteria were checked, explicitly labelled as self-report. Quiz completion means the current answer matches the author's answer. Neither creates a practice score/history entry or marks the whole lesson as read. Read status remains independent. Checkmarks/answers persist across navigation, language changes and restarts. Increment the lesson version when changing task meaning, criteria or correct answers. Old-version responses cannot satisfy new-version tasks. Self-practice/listening responses are also scoped to tuning, fret count, chosen position and resolver version; theory progress does not depend on instrument settings.

The scaffold modes use checked-in templates: [theory](templates/lesson-theory/lesson.yml), [self-practice](templates/lesson-selfPractice/lesson.yml), [listening](templates/lesson-listening/lesson.yml), and default [scored practice](templates/lesson/lesson.yml). The listening mode enforces interval adaptation and disallows positioning. All drafts still require editorial review; the scaffold does not generate new pedagogical content.

## Tuning adaptation and positioning

Optional `adaptation` contains only `policy`:

- `fretPattern`: retain the physical pattern under the selected tuning, appropriate for open strings and technique drills.
- `transposeIntervals`: transpose by the difference between selected and reference string 1, then find positions preserving those intervals. E/D/C/B Standard retain the pattern. Drop adjusts the low string while keeping the intended music.

Without adaptation, a fixed-tuning source stays fixed; a follows-instrument source uses the selected tuning. Every resolved exercise freezes the actual tuning. Lesson positioning happens after choosing sounding pitches and **never changes the key or octave**.

Omitted `positioning`, or `{enabled: false}`, opts out. Enabled materials declare:

```yaml
enabled: true
preserve: soundingPitch
windowFrets: 6
allowedStarts:
  kind: explicit
  frets:
    - 3
    - 7
allowOriginal: true
```

`allowedStarts` also accepts `{kind: auto}` (0–24) and `{kind: range, minimum: 3, maximum: 12, step: 1}`. These are region starts, not every permitted note fret. A region from 7 with width 6 spans frets 7–12, limited by the configured neck. The first note need not be at fret 7. Availability requires the **complete material** to fit; selecting one step does not relax its material's constraints.

Every enabled activity declares exactly one selection:

```yaml
- id: explore
  materialID: scale
  positionSelection:
    mode: learner
    default: {kind: original}
- id: seven
  materialID: scale
  positionSelection:
    mode: fixed
    value: {kind: region, firstFret: 7}
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

## Course modules, library placement and tool links

The runtime catalog can declare `modules`, each with a stable `id`, unique `order` (1–64), and exact `en`/`uk` `titles` and `summaries`. Module names describe learning goals. Keep technical mechanisms out of learner-facing labels. Empty modules are not shown in the library.

A lesson can declare editorial placement independently of its musical revision:

```yaml
curriculum:
  moduleID: first-notes
  ordinal: 16
  durationMinutes: 15
  prerequisites: [reading-tab, adjacent-strings]
  keywords: [melody, мелодія]
```

`ordinal` is a unique global course number (1–1024). Duration is an estimate for one visit (1–120 minutes), not a deadline or unlock condition. Prerequisites and keywords are optional lists, defaulting to empty. Prerequisites must reference other catalog lessons; cycles are rejected. They are suggested preparation, not access restrictions. Standalone author templates may omit curriculum entirely; the library places them after the organized course. Editorial rearrangement alone does not invalidate musical results; changes to teaching/task meaning still require a lesson-version bump.

Search matches every query term against both language editions' title, summary and goal, musical keywords and module titles. Module, difficulty, topic, practice mode and reading-state filters combine with search. Course order is the default, with title and estimated duration alternatives. Reading progress means reading only, never successful playing. Continue restores the unfinished last lesson, or offers the next unread available lesson after a read one. The reader offers step navigation and the next available course lesson.

A step may also specify `tool: tuner`, `tool: audioSetup`, or `tool: settings`. The selected step shows an explicit action to the existing app tool. Text must explain what to check there. Opening a tool does not mark a task complete, start capture automatically, or fabricate a measurement. Audio setup stops lesson preview before opening the shared audio controls.

The full editorial inventory is [coverage.yml](curriculum/coverage.yml), anchored to the [accepted 128 topics](CURRICULUM-SCOPE.md). Delivery states are `todo`, `needs_review`, `authored`, and `verified`. A verified topic needs a checked-in review and, for an extension topic, explicit capability evidence. Run:

```sh
python3 Scripts/check_curriculum.py             # Partial structural/traceability audit
python3 Scripts/check_curriculum.py --complete  # Fails until all 128 topics are verified
```

These commands do not replace the Swift content validator, musical golden tests, editorial review, UI inspection or hardware checks. Adding 128 filenames alone is not course completion.

### Dotted/tied durations and optional sustain assessment

Keep one `MusicalEvent` for a continuous note, including one that crosses a barline. Do not create a second attack for the written continuation of a tie. At PPQ 960, a dotted quarter is `durationTicks: 1440`; a half tied to a quarter is `2880`. Staff notation splits the canonical event into written fragments on the sixteenth-note grid, adding dots/ties; TAB, preview and assessment retain the original ID and one attack. Notes/rests outside this notation grid still have an explicit staff limitation. This stage does not add triplets, compound time, slurs or polyphonic staff notation.

For a clean single-note exercise, an author can opt into stable-pitch coverage:

```yaml
- id: across
  startTick: 1920
  durationTicks: 2880
  kind: note
  positions:
    - string: 3
      fret: 0
  assessSustain: true
```

The flag defaults to false and survives tuning/position resolution. It is invalid on rests, chords and display-only exercises. A marked note must last at least 0.5 seconds at the selected tempo; ordinary attack-only notes retain the 0.2-second gate. Prefer long beginner targets with a clear release/rest. A half-second A1 note stopped halfway can leave too much ambiguous release evidence to score; the app must show insufficient signal rather than guess. This is stable target-pitch coverage, not exact note-off timing, palm-mute quality, finger/string recognition or legato detection. Existing lessons are not silently regraded. The bilingual `dotted-tied-notes` lesson is the reference implementation with separate dots/ties practice entries and a duration quiz.

### Accents

`accented: true` is an optional attack emphasis on a note (including a chord); it is invalid on rests and defaults to false. It survives activity/tuning/position resolution and is omitted from JSON when false to preserve archived digests. Staff and both TAB views show `>` only at the initial attack, never at tied continuations. Accessibility descriptions name the accent.

The synthesized preview renders accented notes at 1.5 times the ordinary reference amplitude with identical onset/duration/frequency. Practice emits no reference guitar tone. This is an audible grouping guide, not an emulation of a pick attack or a measured target loudness. Current automatic scores remain pitch/timing/sustain only; author accent-specific listening criteria for self-assessment, as in `beat-accents`. The low-level bound is 0.3 × toneVolume for an accented reference chord/note, plus at most 0.25 × clickVolume, so default full-volume rendering retains headroom.
