# Automatic lesson tuning

Selecting a tuning in Settings → Instrument or Tuner updates the six-lesson starter course. The catalog no longer offers a separate C Standard copy of each lesson. Physical strings still need to match the selected profile; changing a setting does not retune or pitch-shift the input.

## Musical contract

- Open strings, first frets and steady pulse preserve the taught string/fret pattern. Notes, octave relationships and explanations come from the selected tuning; custom outer strings are never assumed to be two octaves apart.
- Major scale, minor pentatonic and minor arpeggio transpose by **selected string 1 MIDI minus reference string 1 MIDI**. For the current Standard-authored lessons the reference is E4/MIDI 64. This defines a predictable convention even for nonuniform custom tunings.
- Uniform changes retain familiar fingerings. C Standard, strings 6 → 1 **C2 F2 B♭2 E♭3 G3 C4**, moves the course down four semitones: A♭ major, F minor pentatonic and Cm. D Standard moves it down two: B♭ major, G minor pentatonic and Dm.
- Drop D, strings 6 → 1 **D2 A2 D3 G3 B3 E4**, has zero global transposition. A minor pentatonic uses frets 7/10 on string 6 instead of 5/8; Em uses fret 2 on string 6. Intervals and sounding notes remain correct.
- Candidate positions are all valid string/fret combinations for the target sounding MIDI. A deterministic cost favors the original string and nearby frets. Chord voices use distinct strings, preserve every sounding voice, and require a fretted span of at most four frets. This is a bounded supported-shape rule, not a guarantee of ergonomic comfort. The arpeggio uses the same mapped positions as its displayed shape. Changed shapes omit old suggested finger numbers.
- Unrepresentable notes/voicings show a localized unavailable state. Visualizable but out-of-DSP-range patterns retain the existing capability gate; no thresholds are widened.

## One source for text, visuals and sound

The six source manifests declare optional `adaptation` metadata: policy plus explicit lesson/exercise versions. `adaptive.en.json` and `adaptive.uk.json` are authored teaching templates, validated alongside the original resources. The loader requires both languages, exact step references and newer versions. Unknown/malformed tokens fail loading for that lesson.

`LoadedLesson.adapted(to:)` produces a validated immutable lesson with resolved positions and a fixed tuning snapshot. Its names, sequences and position explanations derive from that same snapshot. Templates use `{{tuning}}`, `{{reference}}`, `{{openStrings}}`, `{{openExample}}` (string 6 note), `{{root}}`, `{{first}}`, `{{highest}}`, `{{sequence}}`; step templates additionally support `{{positions}}` and `{{notes}}`. Position notation (for example `C2 (6/0)` in C Standard) is explained in both languages. Template values, including custom names containing braces, are inserted literally without recursive expansion.

Pitch labels use the app's chromatic enharmonic spelling convention: flat labels for flat-family transpositions, sharp labels otherwise. This is not full context-sensitive music engraving; for example F can represent the sounding pitch conventionally spelled E♯ in F♯ major. The bounded Staff prototype retains its explicit key selector. Pitch, intervals and assessment do not depend on the spelling.

The reader keeps step/event selection while replacing its resolved lesson. TAB/staff, fretboard and preview share its exercise. Fresh practice requests opt into adaptation; tuning changes stop an active attempt before the new request is configured, clear physical confirmation and require a new attempt. The in-flight evidence retains the original configuration. No capture is started by adaptation.

## Compatibility and versions

Original static source text/exercise versions remain available. Adapted introduction is lesson version 3; the other five are version 2. All adapted exercises are version 2. Saved attempts contain their full exercise/tuning snapshots; neither pitches nor scores are rewritten. History titles resolve using the saved lesson version and tuning rather than the currently selected tuning. Recommendation retries never opt into adaptation and retain their archived tuning requirement.

The six former C Standard resources remain loadable for history. Their catalog entries are hidden from the current six-lesson library, and old lesson navigation/bookmarks resolve to the corresponding canonical lesson. Existing stored bookmarks/read markers remain intact; the newer lesson version is not silently marked read. New visits write the canonical ID.

## Validation

See `docs/reviews/10-automatic-lesson-tuning-review.md` for executed commands, fixes and native evidence. Automated tests cover all presets, nonuniform custom tuning, A4 442, unrepresentable targets, both languages, template failures/literal substitution, independent C Standard/Drop D MIDI sequences, chord/arp mapping, selected steps, versioned bookmarks, 24 saved course attempts/retries and stopping an active synthetic practice with its old snapshot intact. Hardware pitch/onset accuracy and full beginner/VoiceOver acceptance remain open in USER-VALIDATION.md.

## Independent presentation (2026-09-12)

Current adaptive texts keep title, summary, goal and theory independent of instrument settings. The optional `variant` title/body renders the calculated example; a shared native Your variant block displays actual tuning, fret count, open strings and reference pitch, with expandable adaptation/notation/practice guidance. Step text still resolves notes and positions from the same exercise. Generic fields cannot contain tokens when a variant exists. Legacy texts without a variant retain their previous loading contract.

This is an editorial change with unchanged teaching/musical versions and snapshots. `historicalTitle` preserves the prior version's heading for saved results; active catalog/reader/practice headings use generic topic titles. Earlier sections describing note-dependent lesson titles and duplicated tuning guidance describe the previous presentation. The musical contract is unchanged. See [authoring workflow](CONTENT-AUTHORING.md#start-a-new-independent-lesson) for the template and scaffold command.

## Choosing a fretboard position (2026-09-12)

Interval-based lessons offer Original fingering or From fret N. A position constrains every lesson exercise and displayed shape to frets N…min(N+4, instrument fret count). The first note need not be on N. This changes the physical fingering while preserving all sounding MIDI pitches, including octaves, after the normal tuning transposition. It does not change the key, timing, event IDs or teaching version. The same resolved exercise supplies step text, fretboard, TAB/staff, preview and practice. Physical-pattern lessons do not offer this control.

Only regions that fit the complete lesson are offered. With C Standard the major scale near fret 7 starts at string 6/fret 8 (A♭2), then uses frets 7–10; its original A♭ major pitches remain unchanged. E/D/B Standard use the same positions in their respective keys. Corresponding Drop tunings cannot fit that complete scale within frets 7–11 without changing octaves: their next scale degree requires fret 12 on string 6 or fret 5 on string 5. Original and other feasible regions remain available. Low open-note arpeggios and wide-range pentatonic patterns may have few or no alternative bounded regions. No octave substitution, fingering-comfort guarantee or simultaneous chord recognition is implied.

The selection is per lesson and stored with its versioned reading bookmark. Changing tuning/fret count recomputes availability; an incompatible saved region stays explicit until the user selects another or Original. Step selection and reading status are retained. Preview stops when the position changes. Starting a new practice selection interrupts the previous attempt and clears physical confirmation; its evidence remains frozen. Practice, result details and history identify the selected region. New preflight checks positions against the current instrument and requested region. Audio assesses pitch and timing; it cannot establish which string/fret was actually played.

Optional `LessonPosition(firstFret:)` metadata is additive in bookmarks and `PracticeLessonReference`; absent metadata means Original for existing records. Full exercise snapshots remain authoritative, historical retries retain their exact positions and tuning, and comparison requires equal selected-region metadata. No stored files or scores are rewritten, and no musical version bump is required for an alternate fingering of the same versioned target sequence. See [position review](reviews/10-position-review.md) for evidence and remaining native acceptance.
