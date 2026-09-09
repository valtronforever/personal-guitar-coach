# Task 06 local review

Self-review by the implementing agent; no independent review is claimed.

Reviewed note parsing, immutable presets, profile identity/revision conflicts, selected-profile consistency, reference frequency, shared instrument state, localization, and historical compatibility.

## Findings and fixes

- Native inspection exposed raw `tuning.preset.standard` instead of a label. Direct interpolation into LocalizedStringKey selected the interpolation initializer. Computed keys now pass through String variables; the same pattern was fixed in history validity labels, and the catalog checker rejects this mistake.
- A new practice pitch-range guard initially risked applying today's capability limits when reading old history. Structural snapshot validation is now separate from current practice eligibility. Old data stays readable when analysis limits evolve.
- Result envelopes must inspect the nested schema before interpreting their payload. PracticeRecord now rejects a future result schema before decoding an unknown payload shape; the regression fixture uses a genuinely different shape.
- Filled editor fields originally lost their visible placeholder labels. Persistent labels now identify the profile name and A4; the sheet receives an explicit app locale. Native Ukrainian inspection confirms translated labels and fully wrapped text.
- Preferences now reject contradictory selected-profile/list snapshots, preset replacement, stale revisions, and invalid IDs. Revision increments are overflow-safe and unchanged edits retain their revision.
- Native Settings remembers its selected tab across launches. The authored language-switch UI test now explicitly opens General before finding the language picker.

## Actual verification

- 32 core tests in five suites and seven AppTests in two suites pass. Coverage includes ASCII/Unicode accidentals and octave crossings, invalid inputs, profile revisions, custom save/edit/reload, source/orientation preservation, stale-edit rejection, language-independent IDs, and notification before snapshot publication.
- Debug and Release .app builds and strict ad-hoc signatures pass. Project and catalog checks pass for 118 en/uk keys.
- Native CUA: Standard E2 82.41 Hz and Drop D D2 73.42 Hz; only string 6 changes. Drop D persists across relaunch and switching to Ukrainian. Invalid A4 `nan` removes frequency values and disables Save; 442 restores valid targets and Save; cancelling leaves 440 and the original profile untouched.
- Inspected English and Ukrainian native Settings/editor layouts and accessibility labels. Native test drafts were cancelled; no test custom profile was added to the user's preferences. Restored Standard, right-handed, electric-interface, System language/appearance after checks.

## Integration still owned by later tasks

- `instrumentWillChange` is the tested synchronous boundary for the practice coordinator to interrupt before a new snapshot appears. The running-attempt integration is task 16; no running practice session exists yet.
- `TuningRequirementView` and the fixed-tuning domain check are ready for lesson/practice preflight in tasks 10/16.
- C2–E6 is the initial musical eligibility target, not claimed measured DSP performance. Tasks 12/17 add measured frequency/tempo capability checks; hardware remains in final user validation.
