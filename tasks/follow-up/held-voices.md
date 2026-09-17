# Independently held voices — fingerstyle and chord melody

Status: `in_progress`

Add explicit held-string continuations to the shared event model, keeping independent bass/chord voices sounding while another voice changes. Validate contiguous physical ties, preserve tuning adaptation, serialize absent metadata compatibly and keep these polyphonic exercises display-only. Use completed voice spans for reference playback without reattacking/fading at internal boundaries; retain phase across chunks/seeks/loops. Distinguish held and attacked frets in both TAB presentations and accessibility. Author substantive en/uk lessons 107–108 with progressive examples and honest physical self-checks. Test invalid ties, projection/scoping, all presets/necks, reference continuity and notation. No new capture pipeline or polyphonic assessment claims; native/guitar acceptance remains pending.

Implemented model/reference/resolver/TAB/accessibility and two bilingual lessons. Targeted Domain/analytic audio, 360 course cases and notation checks pass; 120 bundles/917 localized keys validate. [Same-agent review](../../docs/reviews/held-voices-review.md). Full suites, root Release and CI/merge in progress; actual native/guitar gates remain open.
