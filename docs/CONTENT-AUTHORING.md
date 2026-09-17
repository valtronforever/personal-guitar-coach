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

The scaffold defaults to positioning disabled. `--starts` accepts `auto`, a sorted unique list such as `3,7`, or an inclusive range such as `3:12:1`. It requires `--positioning-window` (1–13). Edit both translations and the source exercise before publishing a draft. The position report evaluates one lesson against eight tuning presets and five neck sizes, using the actual resolver. It lists each choice and its failure reason. Mathematical feasibility does not establish ergonomic comfort or audio assessment capability.

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

Six strings use 1 = thinnest and 6 = thickest, with sounding MIDI (C4 = 60). Fret 0 is open; muted strings are separate. PPQ is 960; supported signatures are 3/4, 4/4, 6/8, 12/8, 5/4 and 7/8. BPM counts dotted quarters in 6/8 and 12/8, eighths in 7/8, and quarters in the other meters. Events are ordered, non-overlapping and have positive duration. Do not duplicate computed target MIDI next to fret positions. Domain derives pitches consistently for every consumer.

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

## Optional self-practice recording

An activity can explicitly offer **Record self-practice** without turning an ungraded technique task into an audio score:

```yaml
activities:
  - id: full-study
    materialID: full-study
    recording: selfPractice
```

The material must reference one whole `displayOnly` exercise. This activity cannot have an assessed practice entry, and the exercise cannot be a private listening-question stimulus. Recording is off when the field is omitted. Use a distinct ordinary graded activity for single-note assessment; do not change an exercise's capability merely to expose this action.

The sheet freezes the resolved exercise, positions, tuning, neck, lesson version, source mapping and selected BPM. It records one pass after one bar of count-in, with audio-clock metronome and no reference guitar tones. The musical passage must fit 120s and passage plus count-in 130s at the selected tempo. The loader requires at least one allowed tempo to fit; the sheet disables Start and explains when a slower choice exceeds the limit. A maximum 12s capture tail accommodates the current input/output timing; the overall deadline is 145s within the existing 150s bounded recording buffer. An early stop retains an explicitly incomplete take; cancel, lost packets or changed route do not create a review take.

No file is saved automatically. **Save WAV** opens the native destination picker and atomically writes only the selected file. The stereo WAV contains raw selected input in channel 1 and a generated metronome reference in channel 2. This reference is scheduled against the capture host clock; it does not measure headphone delay, align raw guitar attacks using calibration, or prove audible timing. A versioned `pgcx` RIFF chunk holds the frozen lesson/exercise/instrument/route/timing context, completion flag and channel meaning. Ordinary WAV readers ignore this chunk. The explicit **Open saved WAV** action uses the system's default player; there is no built-in multitrack editor or arbitrary-file playback engine.

A finished take means the transport reached the end and valid capture covered its scheduled extent. It is not proof that the learner played, nor an assessed result or AI recommendation. Listen before checking self-practice criteria. Unsaved audio is temporary and discarded on closing or starting another take. Do not instruct learners to use the existing graded Record & analyze flow for polyphonic/self-practice material. File-picker/player interaction and actual-interface acceptance must be checked separately from synthetic export tests.

## Tuning adaptation and positioning

Optional `adaptation` contains `policy` and an optional `anchorString` (default 1):

- `fretPattern`: retain the physical pattern under the selected tuning, appropriate for open strings and technique drills.
- `transposeIntervals`: transpose by the difference between the selected and reference anchor string, then find positions preserving those intervals. With the default string 1, E/D/C/B Standard retain the pattern. Drop adjusts the low string while keeping the intended music.

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

`ordinal` is a unique global course number (1–1024). Duration is an estimate for one visit (1–130 minutes), not a deadline or unlock condition. Prerequisites and keywords are optional lists, defaulting to empty. Prerequisites must reference other catalog lessons; cycles are rejected. They are suggested preparation, not access restrictions. Standalone author templates may omit curriculum entirely; the library places them after the organized course. Editorial rearrangement alone does not invalidate musical results; changes to teaching/task meaning still require a lesson-version bump.

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

### Explicit harmonic root

An activity material can declare a source-tuning harmonic root independently of voice order or bass inversion:

```yaml
- id: minor-shape
  source:
    kind: fingering
    fingeringID: minor-shape
  tonalRoot:
    midi: 45
```

`tonalRoot` requires `adaptation.policy: transposeIntervals` and an explicit source tuning on every source exercise. The resolver transposes this pitch by the same first-string shift used for the sounding material, then renders `{{root}}` using the active tuning's spelling. Fret-region changes preserve it. The root need not be the first/lowest/highest chord voice; MIDI specifies the source root while the current `root` text token shows its pitch class. `{{first}}` still means the first sounding voice and is unchanged. Without the optional field, existing first-note naming behavior remains compatible. Unsupported root transpositions fail explicitly. Changing the musical meaning of an existing published root requires a lesson version bump; saved activity titles remain frozen.

For a lesson with several chords, use separate named materials/activities with their own roots. `minor-chord-shapes` and `major-chord-shapes` demonstrate a named fingering preview plus an independent monophonic arpeggio for each form. A named fingering may reference the arpeggio's source exercise: its shape activity resolves to a display-only chord, while its note activity remains assessable. Do not infer the harmonic root from the sorted string positions of `Fingering`.

### Strummed reference chords

A multi-string note may declare `strum: { direction: down, spreadTicks: 120 }` (or `up`). Down sounds lower strings before higher strings; up reverses the order, independently of the order of `positions`. `spreadTicks` is the time between the first and last string in the exercise PPQ; default 120, range 1…960, strictly shorter than the event. Omitted strings do not sound. Specify a smaller set of positions for a partial upstroke. A rest cannot carry a strum. An omitted stroke is not necessarily silence: extend the preceding event if it should keep ringing, or write a rest if the sound must stop.

TAB displays ↓/↑ as picking-hand directions; these are not instructions to move vertically through the TAB drawing. Preview staggers synthetic voices within one canonical event. Chord events remain `displayOnly`; this metadata does not introduce polyphonic scoring or prove the player's physical stroke direction. For author-guided practice, pair the timed reference with a specific `selfPractice` task. Omitted `strum` keeps prior playback and encoding unchanged.

### Open-bass transposition anchor

For a riff whose tonic must remain the instrument's open lowest string, use:

```yaml
adaptation:
  policy: transposeIntervals
  anchorString: 6
```

All voices and material `tonalRoot` use this same offset. An E-rooted source becomes D-rooted in Drop D, with its root/fifth/octave shape changing from 6/0–5/2–4/2 to 6/0–5/0–4/0. This deliberately changes the key when the bass is dropped. Omit the field for established-key lessons, whose default string-1 behavior remains unchanged. Valid anchors are 1–6; `fretPattern` may only retain the default anchor because it does not transpose intervals. Increment the lesson version when changing an existing lesson's anchor. Relocation remains an independent pitch-preserving operation and cannot promise an open bass in a higher fret region.

### Palm-muted reference notes

Use optional event field palmMuted: true to mark P.M. in normal/compact TAB and staff, with localized accessibility descriptions. It survives tuning/position resolution and frozen exercise serialization; false is omitted from old canonical JSON. Rests and assessSustain notes cannot carry this field. Exercises containing it must be displayOnly: short muted-input pitch/timbre grading has not been validated.

Preview applies a fixed 90 ms exponential decay to each reference voice from its original onset (including staggered strum voices), without changing musical duration, frequencies or attacks. Seeking preserves decay age. This is a synthetic short-versus-ringing comparison, not realistic guitar/amp modeling or evidence of hand technique. Practice continues to emit only clicks. Teach contact, pitch clarity and damping through specific listening/self-practice criteria. See palm-muting and first-overdriven-riff for complete examples.

### Single-note picking cues

A single note may declare pickStroke: down or up. Use strum.direction for a multi-string chord; do not declare both. Rests cannot carry a picking cue. TAB/staff show the arrow only at the attack, and localized accessibility names it. Tuning/position resolution and frozen practice snapshots retain the cue.

This is an authored physical instruction, not an inferred stroke direction. The reference waveform and automatic pitch/attack assessment remain identical to an unmarked note. For alternate picking, explicitly label the authored sequence and include a separate self-observation criterion. An upstroke-start group is valid. See alternate-picking and hand-synchronization.

### Timed bends and returning bends

One sustained, fretted single note may declare a bend in event-relative ticks:

```yaml
- id: returning-bend
  startTick: 0
  durationTicks: 2880
  kind: note
  positions: [{string: 3, fret: 9}]
  bend:
    semitones: 2
    riseStartTick: 480
    riseEndTick: 960
    releaseStartTick: 1920
    releaseEndTick: 2400
```

The first plateau starts at zero cents. The rise reaches `semitones × 100` cents; omit both release fields to hold that pitch until the note ends. Include both to return to zero cents before the end. All boundaries must be strictly increasing and inside the event. Supported amounts are one or two semitones; bends on rests, open strings, chords, palm-muted or `assessSustain` notes are rejected. Other ordinary notes/rests may share the exercise. The starting fret remains the physical contact; no duplicated target MIDI is authored. Transposition/relocation retain the relative bend and exclude open-string relocation candidates.

TAB/staff use `b1`/`b2` for the semitone amount and `r` for an audible return. Selecting a bend shows an authored pitch curve with beat/cents axes. Preview renders a phase-continuous synthesized pitch path, including seek/chunk continuity; practice output still contains clicks only. These are audible pitch references, not realistic string or finger mechanics. Author a separate fretted target comparison and self-observation criteria; an audio match cannot establish that the player bent instead of changing frets.

Initial automatic capability is deliberately bounded: base approximately G3 (195.9 Hz) through A5 (880 Hz), destination ≤1100 Hz, every phase ≥0.4 seconds, and rising/falling speed ≤400 cents/second. Range/tempo gates evaluate the resolved tuning and A4 reference, never silently change tempo or pitch. The two bundled lessons use 40–60 BPM and feasible positions in all eight preset tunings and all five neck sizes. This does not prove hand comfort or hardware performance.

`periodic-window-center-1` captures moving periodic estimates separately from stable-note sustain. Results retain the curve and per-phase ±35-cent coverage, silence, unknown coverage and signed median pitch error. Every phase must have ≥80% known evidence. Each phase contributes equally to the bend score; scoring v4 combines that score and existing attack/rhythm score equally before extra-attack penalties (mixed sustain exercises subsequently retain their existing 80/20 sustain weighting). Uncalibrated rhythm still has no overall/timing score. Flux observations inside the bend are kept but are not scored as additional pick attacks. The graph uses the observed initial attack when available, with archived latency applied only once.

`first-bend` and `bend-target-and-release` are complete examples. Slide, hammer-on/pull-off links and vibrato are separate authoring/analysis extensions; do not substitute a bend field for those techniques.

### Complete scale and position module

Topics 57–64 demonstrate three distinct authoring choices without adding another runtime scale model:

- `natural-minor`, `major-pentatonic` and `blues-scale` use explicit note events, interval-preserving adaptation and independent `tonalRoot` values. Scale degrees are teaching text; resolved note labels and scoring come from the shared exercise. Same-tonic contrasts use explicit altered pitches, not a fixed fingering assumed to define a key.
- `connect-scale-positions` authors a deliberate route across adjacent areas. Its shared-note example uses two different string/fret pairs for the same pitch. No relocation permission is added because the taught physical route is intentional; sound-based grading does not establish use of that route.
- `same-notes-new-position` retains exact sounding pitches/octaves through a learner-selected note window, whole-scale exploration and a fixed near-seven activity. Its six-fret scale window accommodates Drop geometry; a window is not a mandatory hand stretch. `c-major` retains its narrower five-fret exploration policy, so only fully playable options are offered.
- `scale-sequences` represents groups of three/four and diatonic thirds as ordinary quarter notes plus accent metadata. Melodic grouping never implies tuplets or changes ticks. The final silent beats/bars are explicit rests.

Each module lesson includes a degree/relationship question and a separate self-observation task. The three expanded baseline lessons increment lesson versions while preserving exercise IDs, versions and musical events. Historical attempts remain frozen. The stable `majorScale` topic key is displayed as “Scales” / “Гами” to accommodate both major and minor families; saved IDs do not change.

### Eighth-note triplet groups and introductory shuffle

Triplet intent is explicit on the exercise. Its event ticks remain the sole sounding-time source:

```yaml
events:
  - {id: a, startTick: 0, durationTicks: 320, kind: note, positions: [{string: 3, fret: 5}]}
  - {id: b, startTick: 320, durationTicks: 320, kind: rest, positions: []}
  - {id: c, startTick: 640, durationTicks: 320, kind: note, positions: [{string: 3, fret: 7}]}
triplets:
  - {id: first-beat, eventIDs: [a, b, c]}
```

This first contract covers three written eighth-note slots in one quarter beat (3:2). Each group starts at a 960-tick beat boundary and consists of two or three contiguous, ordered events totaling 960 ticks. Each event occupies one slot (320 ticks) or two (640 ticks). Two-slot events are written as quarter notes/rests inside the bracket: a 640+320 pair is the explicit 2:1 beginner shuffle. Rests may belong to the group; IDs are unique and an event cannot belong to two groups. Missing/reordered/partial/overlapping groups are rejected. Other tuplets, arbitrary swing ratios and groups spanning beats are outside this contract.

Ordinary events remain unchanged. Three ordinary quarters are not a triplet merely because there are three of them; absent metadata does not trigger guessed conventional notation for a 320-tick grid. Empty triplet arrays are omitted from canonical encoding, preserving old practice/coach digests. A material selecting events must include any intersected group in full and, if groups are present, begin at a quarter boundary so normalization preserves their placement. A visual step may highlight a single group member while its activity retains the complete exercise.

Both TAB forms show written values and a 3 bracket; staff beams full three-note runs and keeps the bracket when a rest or quarter/eighth pair prevents beaming. Spoken note/rest descriptions name the triplet subdivision. Compact rows reserve extra space only for exercises with groups, preserving ordinary row density. Reference, metronome, cursor and assessment still use actual event ticks; no extra click or hidden tempo change is introduced. The `triplets` and `swing-shuffle` lessons use clean monophonic practice at 40–90 BPM. Real swing timing can vary: the latter lesson explicitly teaches a fixed target, not an authenticity score for all styles.

### Syncopation, gallop and displaced figures

Topics 67/69/70 reuse authoritative ordinary event ticks rather than a separate rhythm-pattern engine. `syncopation` places attacks after explicit eighth rests and marks only the long held notes with `assessSustain`; a cross-bar hold remains one event/attack while notation fragments it with ties. `gallop-patterns` uses 480+240+240 and 240+240+480 groups, continuous alternate-pick cues, a sixth-string transposition anchor and a conservative 40–70 BPM practice range. The open bass and upper seventh/ninth/tenth-semitone replies retain their intervals in Standard and Drop. Muted tone and physical picking direction remain self-observation.

`displaced-accents` repeats ordinary eighths in three-note groups across three 4/4 bars, shifts the entire cycle by an eighth, and compares four entries for the same two-beat motif. Accent metadata changes reference emphasis, not tempo or scoring. None of these exercises declares a triplet. Leading/trailing silence is explicit, including offbeat long rests that may require multiple written rest fragments; fragments retain one source event ID and never acquire ties.

### Deliberate metronome omissions

An exercise may declare an optional metronome pattern:

```yaml
metronome:
  silentBeatTicks: [3840, 4800, 5760, 6720]
```

This example silences all four quarter clicks in bar 2 of 4/4. Values are strictly increasing, unique, nonnegative quarter-beat onsets (multiples of PPQ 960), strictly before the exercise end; at most 4096 omissions are accepted. The exercise must end on a quarter boundary. Omit the object for ordinary continuous clicks; an empty array is rejected. The contract describes omitted quarter clicks, not a tempo change, guitar rest or arbitrary metronome subdivision.

The full count-in remains audible. Preview and practice honor the authored omissions; practice still emits no reference guitar tones. Seek and repeated ranges use source exercise coordinates, so the same bar retains the same omissions. Keep an audible return inside a practice range when the educational task depends on comparing it with the gap. Event-scoped materials must contain whole quarter beats; resolution filters and rebases omission ticks along with the music. A fingering-only display has no metronome pattern.

The compact score names silent beat numbers beside a crossed-out speaker; the setup notice explains that the guitar continues. Every written note remains in assessment, including silence in the click track. Saved exercise snapshots retain the pattern; absent fields preserve old canonical encoding. The recorded reference channel uses the same transport plan and therefore the same omissions. New gapped coach requests use `file-coach-3` and explain deliberate silence; ordinary/bend requests retain versions 1/2. `missing-clicks` provides sparse 2/4 clicks, single silent bars and a two-bar gap, with explicit audible returns and internal-pulse self-observation.

### Compound and odd meters: what BPM counts

| Signature | BPM/click unit | Pulses per bar | Default grouped emphasis |
| --- | --- | --- | --- |
| 3/4 | Quarter, 960 ticks | 3 | Downbeat |
| 4/4 | Quarter, 960 ticks | 4 | Downbeat |
| 5/4 | Quarter, 960 ticks | 5 | 3+2 |
| 6/8 | Dotted quarter, 1440 ticks | 2 | Downbeat |
| 12/8 | Dotted quarter, 1440 ticks | 4 | Downbeat |
| 7/8 | Eighth, 480 ticks | 7 | 2+2+3 |

The denominator describes written notation; the named pulse defines BPM. At 60 dotted-quarter BPM, a 6/8 bar lasts two seconds and each eighth lasts one third of a second. At 120 eighth-note BPM, a 7/8 bar lasts 3.5 seconds and each eighth lasts half a second. Count-in uses one whole bar of these pulses. PPQ remains 960 for every signature. Tempo is constant within an exercise; no tempo map or mixed-signature bar sequence is implied.

An optional `beatGrouping: [3, 2, 2]` on a 7/8 exercise changes group starts to units 1, 4 and 6. Positive counts must sum to the pulse count. Explicit groups emphasize each beginning; default simple/compound meters only emphasize the bar downbeat. Grouping changes neither note events nor bar duration, and does not itself mark guitar-note accents: use existing event `accented` values to author that separate reference target. The `odd-meters` lesson compares alternative groups with identical note pitches/times. A pitch/timing score does not verify accent strength.

Metronome omissions now validate against the signature's pulse grid: e.g. 1440 is the second 6/8 pulse; 960 is not a click there. The pattern's standalone grid accepts multiples of 480; Exercise applies the actual pulse and duration constraints. Existing quarter-meter patterns retain their previous meaning. Grouped/non-baseline event materials must span whole bars so rebasing cannot silently change group phase; ordinary 3/4/4/4 omission-only materials may still span whole quarter pulses. Fingering-only displays retain a complete bar.

Staff beams three eighths per compound pulse and the authored groups in 7/8. Simple-meter eighths retain beat-pair beaming even when 5/4 click accents group quarters. Long offbeat notes split at notation-group boundaries with ties and one canonical attack. Both TAB layouts, cursor/follow positions, spoken beat coordinates and bend-curve axes use the named pulse. Preview, practice and result tempo labels identify that unit. Practice duration and pitch/sustain/bend capability gates use actual seconds; changing the signature cannot bypass minimum note/phase duration.

`compound-meters` compares a four-bar 6/8 melody with the same music in two 12/8 bars and a final sustained dotted-quarter tonic. `odd-meters` provides 3+2/2+3 quarters and 2+2+3/3+2+2 eighths. New grouped/non-baseline coach requests use `file-coach-4`, carrying the signature and grouping; previous ordinary, bend and omission request versions remain valid for their historical conditions.

## Slides and legato pitch transitions

A single monophonic note may carry `pitchTransition`. It keeps **one initial attack target**, with the destination inferred on the same string by its signed semitone/fret interval. This is separate from a bend and cannot coexist with `bend`, `assessSustain`, `palmMuted`, a chord or a rest on the same event. An initial `pickStroke` is allowed.

```yaml
id: slide-up
startTick: 0
durationTicks: 2880
kind: note
positions:
  - string: 3
    fret: 5
pitchTransition:
  kind: slide
  semitones: 2
  startTick: 960
  travelTicks: 960
```

At 60 quarter-note BPM this holds C4 for the first beat, travels during the second and holds D4 during the third. `startTick` inside the transition is relative to the event. A slide requires positive `travelTicks` and both endpoints fretted. `hammerOn` requires a positive interval; `pullOff` a negative interval. Both use zero/omitted `travelTicks`, so the target arrives exactly at the local `startTick`. Open endpoints are permitted for legato. Intervals are nonzero and bounded to ±12 semitones; start is positive and target arrival must precede event end.

The resolver preserves the interval and both endpoints on one string. Every endpoint must fit the instrument and any selected region. A region that contains only the starting fret is unavailable. Open-string technique materials can disable repositioning to retain their teaching purpose. Text `positions`/`sequence` includes both endpoints; source selection and practice ranges retain the complete event.

TAB places each endpoint at its musical time with h/p/slide connection. Conventional staff notation separates the target pitch and never ties two different pitches. Written subdivisions must fit the supported sixteenth or explicit-triplet grid; other timings retain TAB/curve presentation and an explicit staff limitation. Reference playback is an abstract continuous-phase pitch model, not a timbral simulation of finger contact.

Graded practice currently uses a conservative clean-input envelope: base 195.9–880 Hz, target 195.9–1100 Hz, base/target plateaus at least 0.4 s. Slides additionally need at least 0.5 s travel and at most 200 cents/s. Timing uses the exercise's actual metronome pulse. Unsupported frequency/speed is unavailable rather than automatically simplified. The shipped introductory exercises use 40–60 BPM.

`pitch-transition-assessment-1` measures base/travel/target for slides and base/target for legato. Endpoints use ±35 cents; slide travel allows ±85 cents around its reference to accommodate fret steps. Multi-fret slides additionally need at least 0.1 s of pitched coverage within ±35 cents of each intermediate semitone. A one-fret slide has no intermediate fret and cannot be distinguished from a well-timed pitch step by this check. More than 20% unknown coverage in any phase withholds the score. Initial settling is excluded for 200 ms; phase boundaries have 60 ms guards. Known silence is a measured failure, not unknown evidence.

Only the initial attack has an attack-timing score. Phase coverage is not an exact secondary-attack timestamp. Internal flux observations remain archived but are excluded from extra-pick penalties. Sound cannot identify the actual finger/string or prove a slide, hammer-on, pull-off or absence of repicking. Author explicit self-observation alongside measured practice. Physical-interface validation remains separate from synthetic tests.

### Vibrato (topic 56)

A single fretted `MusicalEvent` can carry `vibrato: {extentCents: 80, startTick: 960, endTick: 4800, periodTicks: 480}`. These are event-relative ticks; the event duration must extend past `endTick`. The initial positions remain the only attack targets. Vibrato is an upward pitch oscillation returning to its base each period; it does not identify a finger movement. It cannot share an event with a bend, pitch transition, palm-mute cue, chord or sustain assessment. Initial pick direction is allowed. Domain accepts 1–200 cents and at least two complete cycles; the assessed capability is deliberately narrower.

The first graded envelope is 30–100 cents, 1–3 cycles/second, at least four complete cycles, base frequency 195.9–880 Hz, top frequency at most 1100 Hz, and at least 0.4s of stable base and return. Rate uses the exercise's actual `pulseTicks`, never an assumed quarter note. Preview remains available outside grading limits. Authors must choose BPM bounds that keep every activity within the envelope; the vibrato lesson uses 60–90 BPM. Ordinary steady-note preparation opts into `assessSustain`, separately from vibrato.

TAB/staff keep one canonical event (ties across barlines) and place a wavy mark over the authored modulation interval. The target curve describes width and rate; it is not an exact oscillation-phase matching requirement. Learner relocation preserves base pitch, timing and modulation metadata, and requires a fretted target. Tuning adaptation transposes the base as usual; cents/period are unchanged. Avoid using this single gesture as a stand-in for combined bend/vibrato or multi-change legato chains.

## Listen and repeat with instrument response

A practice entry may opt into `presentation: listenAndRepeat`. Omit this field for the usual shown-target practice. The author still supplies a real monophonic `Exercise`; its resolved pitches, timing, selected bars and tempo drive both the synthesized reference and the later recorded/measured response. See `Resources/Lessons/find-heard-note` and `Resources/Lessons/repeat-a-rhythm` for complete bilingual examples.

```yaml
steps:
  - id: response-a
    kind: none
    eventIDs: []
    activityID: response-a
materials:
  - id: response-a
    source:
      kind: exercise
      exerciseID: my-private-exercise
activities:
  - id: response-a
    materialID: response-a
practiceEntries:
  - id: response-a
    activityID: response-a
    exerciseID: my-private-exercise
    presentation: listenAndRepeat
```

This mode requires `transposeIntervals`, a complete private exercise with every silent interval represented by an explicit rest, a material used by exactly one activity, one practice entry and one text-only step. Do not add position controls, another material pointing at its exercise, a fingering for that exercise, or a quiz/self-task on that response step. Use separate private quiz stimuli for recognition questions and separate steps for reflection. The loader rejects these structural leaks and rejects context tokens in the private step/activity titles and bodies. Authors must also review hardcoded prose and other exercises: the validator cannot infer whether words or duplicated notes give away an answer.

Use neutral labels such as “Response A”, describe a comparison method, and avoid printing the answer's pitches, fret numbers or exact rhythm. Provide several progressively harder original examples. The learner may listen repeatedly, search on the guitar before capture, then start after a fresh count-in. Changing tempo, bar range, tuning or audio route invalidates preparation. Reference playback has no input capture, and the practice uses the existing single capture owner with the reference tone disabled. Recording/analysis remains one action for the response.

The learner may deliberately reveal notation and fretboard targets. This remains guided for the current selection, including replays and tempo/range changes. Each performed configuration freezes `listeningConditions` version 1 (completed reference, targets revealed), paired with `PracticeActivityReference` schema 2 and the resolved exercise. Results identify whether targets were hidden during that attempt; guided and hidden conditions are not compared as equal. Older ordinary activity schema 1 and configurations omit the new fields and retain their encoding. A retry must prepare again. Results may display the expected notes for diagnosis.

This is measured pitch/onset reproduction, not proof of perfect pitch, hearing, unfamiliar material, memory, fingering or general ear-training proficiency. The examples are fixed, not randomized. Software playback completion does not prove perception. Rhythm needs valid calibration; manual calibration is explicitly approximate, and missing audio still withholds a score. There is no transcription editor: learners can write their own notes externally and submit a guitar response. The `file-coach-7` exchange includes the frozen listening conditions and instructs the coach to honor these limits.

### Multi-target legato chains

Use optional `legatoChain` on a single-voice note for 1–8 sequential unpicked targets. One `MusicalEvent` retains one initial attack; each target is a stable pitch plateau, not a new pick event. `semitones` is relative to the **preceding** target (the first relative to the base), while `startTick` is absolute within the parent event. The cumulative offset must stay within ±24 semitones and all reached frets must be 0–24 on the same string. Strictly increasing positive target ticks must precede the event end. `hammerOn` and `tap` require a positive interval; `pullOff` requires a negative interval, each at most 12 semitones. `pickStroke`/accent describe only the initial attack. Chain, bend, single transition, vibrato, assessed sustain and palm mute cannot coexist on one event.

```yaml
legatoChain:
  targets:
    - {kind: hammerOn, semitones: 3, startTick: 960}
    - {kind: tap, semitones: 4, startTick: 1920}
    - {kind: pullOff, semitones: -4, startTick: 2880}
    - {kind: pullOff, semitones: -3, startTick: 3840}
```

With a 4800-tick parent this is five quarter notes: base, +3, +7, +3, base. TAB/staff and the pitch curve show all targets; notation fragments keep the source event ID. Ties connect only a sustained plateau, never distinct pitches. A string change needs a new event/initial attack; this first chain contract does not infer an unpicked cross-string articulation.

The clean monophonic envelope requires initial 195.9–880 Hz, all plateaus 195.9–1100 Hz, and at least 0.4 s per plateau at the requested meter pulse/BPM. Display/reference are broader than assessment. The app measures audible pitch coverage, not the hand/finger, fret, string or absence of repicking. Add a separate physical self-check rather than reporting the gesture as measured.

Positioning checks every intermediate target when choosing a starting position. `windowFrets` now permits 1–13: this is a search region, **not** a claim of a feasible one-hand stretch. Chord voicings retain the existing four-fret span constraint. Wider regions can describe two-handed tapping, while physically essential string-crossing tasks should disable relocation. Available choices are pruned against the actual instrument/fret count. Topics 91/93 demonstrate short→long chains, fixed three-string crossings and repeated tapped minor-triad cycles. Missing optional fields preserve earlier canonical encoding and saved grades.

### Picking-hand finger cues

Optional `pluckFinger: thumb | index | middle | ring` labels an ordinary single-voice note's initial attack with p/i/m/a. These are picking-hand roles, independent of left/right-handed playing. The cue cannot coexist with `pickStroke`, strum, bend, transition, vibrato or legato chain in this first contract, and cannot be attached to a rest/chord. Sustained ordinary notes may carry the initial cue; continuations do not repeat it. It is not an audio-detected articulation and does not change pitch, timing, reference timbre or scoring parameters.

```yaml
- id: upper-note
  kind: note
  startTick: 960
  durationTicks: 960
  positions: [{string: 2, fret: 5}]
  pluckFinger: middle
```

Topics 89/90/92/95 retain fixed string patterns for skipping/economy/sweep/hybrid teaching. Their ordinary note assessment checks audible pitch/time, while explicit self-checks cover picking direction, hand use, finger rolling, string separation and muting. Hybrid examples use arrows for the pick and m/a for upper strings. Describe intentional monophonic release in measured practice; do not imply that the same score assesses an overlapping chord texture. Changes to an existing lesson's physical cues require a new lesson/exercise version; these new lessons begin at version 1.

### Natural and touched artificial harmonics

Optional `harmonic` separates a note's physical locations from its audible target. The initial contract supports natural partials 2/3/4 near frets 12/7/5, and touched artificial octave harmonics (partial 2 only). For a natural harmonic, `positions` contains the touch landmark; for an artificial harmonic, it contains the stopped base. Each event has exactly one voice and one initial attack. Harmonics cannot be combined on one event with a bend, transition, vibrato, chain, palm mute or picking-finger cue. `pickStroke` describes the initial attack; optional `assessSustain` measures audible duration. Rests and chord events cannot carry this metadata.

```yaml
- id: natural-third
  kind: note
  startTick: 0
  durationTicks: 1920
  positions: [{string: 3, fret: 7}]
  harmonic: {kind: natural, partial: 3}
- id: touched-octave
  kind: note
  startTick: 1920
  durationTicks: 1920
  positions: [{string: 3, fret: 5}]
  harmonic: {kind: artificial, partial: 2}
```

In E Standard these sound approximately D5 and C5. The first target is the open G3 frequency multiplied by three, rather than stopped-fret D4. The third partial is about 1.955 cents above its equal-tempered MIDI label; Domain supplies that exact ideal multiplier to both synthesized reference and assessment. A real string's node may lie slightly away from its fret landmark. Artificial bases must be frets 1–12, with a second physical touch at base +12; both must fit the instrument and chosen region.

Natural nodes retain their physical locations under `fretPattern`, deriving the sound from each tuned open string, including Drop's sixth string. Under `transposeIntervals`, an unchanged node must produce the intended transposed pitch or the activity is unavailable; it is never moved as an ordinary stopped note. Artificial octave bases can be relocated while preserving the sounding pitch with the linked +12 touch bound. `windowFrets: 13` can include both positions and describes a two-hand region, not a one-hand stretch. Named-fingering sources from an exercise containing harmonics are rejected in this first contract, preventing a fingering projection from discarding harmonic metadata.

TAB uses angle brackets for a natural touch and an ordinary base with the touched fret above it for artificial harmonics. Staff uses sounding pitches and diamond heads; N.H./A.H. identify the authored type. The fretboard uses distinct touch diamonds and explicit base/touch targets. Text `sequence`/`notes` describes the audible pitches, while `positions` describes physical touch/stop roles. Lesson 94 (`harmonics`) demonstrates six progressive activities, including an artificial octave relocation whose higher region is unavailable on short necks.

The score checks audible monophonic pitch, onset and optionally sustain within the existing capability envelope. It does not detect the hand, node, string, pinch gesture or harmonic timbre. Physical execution and unwanted strings remain self-checks. The reference is synthesized, not a recorded harmonic demonstration. Harmonic attempts opt into `mono-capability-7`, `monophonic-assessment-8` and `file-coach-10`; ordinary events omit the new field and preserve prior encoding/versions. Stored exact targets are validated and never silently regraded.

### Unpitched muted-string attacks

A fully damped string scratch is a sounded event distinct from a rest and from a pitched `palmMuted` note. Author it as `kind: note`, empty `positions`, and explicit `mutedAttack`. The strings must be a nonempty sorted unique list of 1–6. Direction is an optional picking-hand cue, not detected technique. Do not use a negative fret, MIDI placeholder or a rest for this sound.

```yaml
- id: scratch
  kind: note
  startTick: 240
  durationTicks: 240
  positions: []
  mutedAttack:
    strings: [1, 2, 3]
    direction: up
```

Muted attacks require `assessmentMode: displayOnly`, including in mixed pitched/unpitched phrases. They cannot coexist on an event with sounding positions, sustain assessment, palm mute, strum/pick/finger metadata, harmonics or pitch-motion techniques. Put direction inside `mutedAttack`; `accented` can mark an initial rhythmic accent. The event duration occupies musical time, while the reference is a short decaying noise burst, not a sustained tone or a realistic guitar sample. The single transport owns that reference; no additional capture pipeline is involved.

Tuning changes and region choices retain the specified physical strings without inventing a pitch. TAB shows × on those strings, staff shows an unpitched cross with rhythm/stem/beam and no accidental, and the fretboard shows muted strings. `sequence`/`notes`/`positions` text includes a localized muted-string label rather than silently dropping the event. Named-fingering projections from any exercise containing muted attacks are rejected because an ordinary fingering would lose the attack instruction. The normal staff polyphony limit still applies to simultaneous pitched chords; it reports its existing limitation instead of showing one chord tone as the whole chord.

Topic 102 (`funk-study`) progressively separates short chord stabs, scratches and rests, then combines them in syncopated patterns and a four-bar study. Its physical and musical checks are self-reported. There is no automatic pitch, damping or noisy-attack score for these events. Ordinary event encoding omits `mutedAttack`, preserving prior saved data; no prior result is regraded.

## Independently held voices

For display-only fingerstyle/chord-melody references, each nonoverlapping event lists **all currently sounding positions**. Optional `heldStrings` lists sorted unique physical strings that continue from the immediately preceding adjacent event without another attack. Every held position must match the preceding string and fret exactly. Positions not listed in `heldStrings` are new attacks, including repeated fret numbers; omitted positions end. A fully held event is allowed for a release of another voice, but cannot be accented because it has no new attack.

```yaml
- id: start
  startTick: 0
  durationTicks: 960
  kind: note
  positions: [{string: 5, fret: 3}, {string: 2, fret: 5}]
- id: melody-change
  startTick: 960
  durationTicks: 960
  kind: note
  positions: [{string: 5, fret: 3}, {string: 2, fret: 6}]
  heldStrings: [5]
```

This is one continuous bass plus two separately attacked upper notes, not two complete chord attacks. An absent/empty field retains historical encoding. The first contract supports plain pitched display-only exercises: do not combine held-voice exercises with strum, palm-muted, harmonic, moving-pitch or unpitched-attack metadata. Authors must use whole exercise/lesson materials and `positioning: {enabled: false}`; event fragments, named-fingering projection and learner relocation are rejected rather than silently removing holds. Interval adaptation preserves each physical string and adjusts its fret to the transposed pitch (including Drop); an out-of-range result is unavailable. Standard transpositions retain the same frets.

Both TABs show held frets in parentheses with a localized legend and spoken continuation. The fretboard shows all active positions; preview merges the individual voice spans without reattacking at intervening melody events. Existing polyphonic staff fallback is explicit. Simultaneous voices, hand coordination and balance remain self-reviewed; no automatic polyphonic score is provided. Topics 107–108 demonstrate both held bass/moving melody and held melody/changing bass, then retained lower chord voices.

### Fixed-note rapid rhythm practice

Use `assessmentMode: rhythmOnly` on an exercise when rapid repeated attacks matter and settled pitch for every note is unavailable. Reference examples: `tremolo-picking` version 2, `fast-short` and `fast-long`. Authors still provide actual fret positions, ticks, rests and ordinary practice entries; the same music drives TAB, staff, preview and capture. This mode is separate from `monophonic` and `displayOnly`.

The initial contract requires one identical physical note position throughout the exercise, optional rests/pick/accent cues, no chord, held voice, muted attack, palm mute, sustain assessment, harmonic, strum or pitch-motion technique. Actual sounding targets must be 110–440 Hz after tuning adaptation; every note must last at least 0.15 s at the selected meter/BPM. Sixteenths therefore reach 100 quarter-note BPM. Unsupported registers/tempos are refused, not silently rewritten. Hidden listen-and-repeat remains monophonic. The final changing-pitch tremolo study stays display-only.

The result grades detected attack timing, misses and extra onsets using independent periodic-window signal checks. It deliberately omits `pitchScore` and every `centsError`; target notes remain instructions. It does not grade accent dynamics, pick alternation, hand movement or technique. It requires eligible route calibration and the existing uncertainty/drift bounds. At 100 BPM the 67.5 ms rhythm tolerance permits at most 33.75 ms total uncertainty; the rapid onset allowance is 20 ms, leaving at most 13.75 ms for calibration/drift. Manual synchronization retains its 50 ms allowance, so it generally needs a slower tempo (40 BPM works with zero additional drift). Do not promise a high-speed timing score from rough manual settings. Unavailable rhythm has no pitch fallback and is labeled explicitly.

Frozen versions are `repeated-attack-capability-1`, `repeated-attack-assessment-1` and `file-coach-11`. Existing per-note `reliable` still means settled pitch; this mode instead consumes the already bounded `periodic-window-center-1` trace alongside the existing detected onsets. Ordinary monophonic parameters, evidence and historical results remain unchanged. Teaching texts must distinguish this software capability from real-guitar validation, which is still pending.
