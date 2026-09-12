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
