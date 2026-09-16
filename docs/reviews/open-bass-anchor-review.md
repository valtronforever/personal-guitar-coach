# Open-bass lesson anchor and rock-rhythm foundation — local review

2026-09-17. Same-agent code and bilingual editorial review. Scope: optional author-selected transposition anchor, substantive Drop riff lesson (topic 39), and expanded power-chord introduction (topic 33). Full curriculum remains in progress.

## Findings and decisions

- A riff rooted on the lowest open string cannot keep both its open bass and the default high-string-derived key when moving Standard to Drop. The optional validated adaptation.anchorString: 6 makes this musical decision explicit in YAML. Default 1 preserves existing course behavior; fretPattern does not permit a nondefault transposition anchor. The same transposition helper drives pitches and named harmonic roots.
- Resolved exercises retain immutable pitch/time targets in practice history. Existing default definitions omit the new field when encoded; the expanded power lesson increments its lesson version to 2 while preserving its original reference exercise/version.
- Drop examples preserve root/fifth/octave and open-string bass across all eight presets. Standard shapes become the appropriate Drop geometry; misleading finger suggestions are removed when geometry changes. Custom tuning can still make a shape unavailable: no universal physical fingering guarantee is claimed.
- The power-chord introduction now distinguishes a fifth from major/minor thirds, demonstrates a moved root and optional octave, includes a knowledge question and a separated-note practice entry. Its initial simultaneous example remains ungraded; a previous test that assumed the whole lesson had no graded entries was narrowed to assert this actual contract.
- The four-bar riff uses an explicitly counted 1-and-2-3-4 pattern. Single bass notes and separated chord pitches can be graded; the full riff with simultaneous chords is a reference/self-practice activity. Palm muting, hand placement and chord clarity are not inferred from monophonic input.
- New resolver call sites bind the validated adaptation instead of force-unwrapping it.

## Verification

- All 44 bilingual bundles validate. Inventory audit: 34 authored, 4 needing review, 90 todo; full-course acceptance remains open.
- 84 Learning tests pass, including independent MIDI/interval, open-bass, root-label, fret/string, event timing and graded-entry goldens across eight presets × five fret counts.
- All 136 App tests pass explicitly serially in 125.079 seconds. Generated Xcode project and 807 localized UI keys pass checks.
- Focused rerun after the optional-binding cleanup, signed Release/archive, XPC and CI evidence will be recorded below.
- Native reader/VoiceOver, actual string comfort, real-guitar capture and perceived reference usefulness remain pending_user. Synthetic/code checks do not establish those outcomes.
