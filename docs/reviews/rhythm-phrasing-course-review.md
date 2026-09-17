# Syncopation, gallop and rhythmic displacement — local review

2026-09-17. Same-agent content, musical-model and notation review. Scope: topics 67/69/70; full curriculum remains in progress.

## Findings and implementation

- Three original bilingual lessons each include three progressive exercises, a specific comprehension question and distinct self-observation criteria. Syncopation separates offbeat entries, two held notes and a cross-bar phrase. Gallop compares 2+1+1 with 1+1+2 sixteenth slots, then changes upper replies over an open bass. Displacement contrasts a three-bar group cycle, its eighth-note shift and four placements of one motif. None is silently encoded as a triplet.
- Syncopation marks only 1440-tick held events for existing sustain coverage. The cross-bar note is one attack; visual ties do not create assessment notes. Gallop uses the sixth-string anchor, preserving the lowest open-string bass and upper intervals in all presets. Its 40–70 BPM range respects the existing shortest-note limit. Pick direction, accent strength and muted timbre are not claimed as measured skills.
- Authoring review corrected prerequisite IDs to actual course entries, clarified English counting syllables and replaced an ambiguous Ukrainian term for a three-note figure. All nine new YAML files use expanded mappings rather than generated anchors; normalization preserves parsed values after the stated editorial corrections.
- The complete App run exposed an incorrect corpus-test assumption: absence of a note tie does not mean a new source event, because a long offbeat rest can have several untied written fragments. Production notation correctly keeps rests silent and untied. The test now selects the fragment at the source event's actual start; a focused regression independently checks the 480+2880 split of a 3360-tick offbeat rest, silence and absence of ties. No production behavior was altered to satisfy the test.

## Verification

- All 100 Learning tests pass in 79.784 s. Two new independent musical tests exercise every activity across eight tuning presets × five fret counts: pitches/intervals, onset ticks, durations, accents, marked holds, quarter/eighth/sixteenth grouping, continuous pick cues, open bass, tempo capability and frozen JSON.
- Initial 142-App-test run had only the two rest-fragment expectation failures described above. The final explicit-serial rerun passes all 143 App tests in 145.337 s, including the added rest regression. The content validator accepts 72 bilingual bundles with zero issues. Signed local Release/archive validates 72 bundles /217 YAML files (`docs/benchmarks/rhythm-phrasing-release-bundle.json`). Binary SHA256 `be8ecf28cffd4b0f9ba3d69b7197600ef43c626bdb7c45d53ef2a1dec9351c40`; archive SHA256 `f653ff75a1406b678f2333c00eb420a08c0fad063cea0dc27cf3278c8fc933d7`. Signed sandbox-to-separate-XPC invalid-request probe passes without a provider invocation. Native launch is not verified; exact-head CI remains pending.
- Generated project, 835 English/Ukrainian UI keys, four Python author-tool tests, partial 128-topic inventory audit and UI-source type-check pass. Inventory is 65 authored, 1 needing review, 62 todo; partial success is not full-course acceptance.

## Remaining acceptance

Native reader, keyboard/VoiceOver, themes, actual guitar comfort and real input performance remain pending_user in USER-VALIDATION.md. No new DSP or audio callback implementation is introduced by this content stage.
