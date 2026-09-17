# Seventh chords, harmonic functions, voice leading and arpeggios

Same-agent review; no independent reviewer used. Scope: authored topics 77–80, their bilingual content, canonical references/practices, curriculum entries and musical/integration checks. Runtime audio/assessment models are reused unchanged.

## Musical decisions

- Seventh chords use narrow four-string voicings on 5/4/3/2: Cmaj7 [48,55,59,64], C7 [48,55,58,64], Cm7 [48,55,58,63], then moved D7 [50,57,60,66]. Quality comparisons alter only the seventh or third; transposition moves all four voices. Explicit root plus maj7/7/m7 suffixes in both languages distinguish them. Four sequential string checks are graded; complete shapes remain display/self-practice.
- Harmonic functions use three-string I [60,64,67], IV [57,60,65], V [59,62,67], vi [57,60,64]. IV/V have their thirds in the bass but retain F/G harmonic roots before tuning transposition. I–IV–V–I and I–vi–IV–V are four-bar chord references, one chord per bar, with no graded chord entries. Roman degrees and root labels have separate roles; the text avoids universal emotional claims.
- Voice leading compares root-position I/IV/V [60,64,67]/[65,69,72]/[67,71,74] with connected [60,64,67]/[60,65,69]/[59,62,67]. The common low C in I→IV and high G in V→I remain, while other voices change. Three graded lines [60,60,59,60], [64,65,62,64], [67,69,67,67] each use three sounded quarter beats and a silent fourth; repeated pitches are reattacked next bar. Opt-in sustain measures sound coverage, not held finger contact. A separate connected arpeggio combines the lines as three quarter attacks and a rest per bar.
- Arpeggios outline changing triads with root/third/fifth/octave targets I [60,64,67,72], vi [57,60,64,69], IV [53,57,60,65], V [55,59,62,67]. A 12-attack quarter phrase leads to 32 flowing eighths and a 35-attack eight-bar mixed-rhythm study. The study includes three quarter rests and ends on C4 for 1920 ticks, with sustain assessment only on that final note. Accents are reference markings, not scored picking-force evidence.

All examples transpose with the selected Standard tuning and adapt across its paired Drop; these new materials use no sixth-string targets. All 19/20/21/22/24-fret settings contain the authored positions. Activities have explicit harmonic roots where needed. Prior stored results and algorithm versions are unaffected because these are new stable lesson IDs, with no runtime model change.

## Review and corrections

- Checked prerequisite IDs against the actual catalog before writing: use `tonic-and-degrees`/`first-song-form` rather than a nonexistent generic chord-progression ID.
- Replaced generic major/minor practice labels with precise seventh suffixes; added role/route labels to distinguish inverted or alternative voicings. The harmonic function follows the chord root, not the first canonical voice.
- Sustained voice lines explicitly require a new attack after each written rest, including common tones, so expected onsets agree with the lesson instructions. The final study note is two beats, not two bars.
- Complete chords never receive monophonic practice entries. Sequential references/practices retain their authored order; canonical fingering snapshots use string 1→6 order. Independent test expectations distinguish the two.

## Verification

Initial targeted musical run: four tests pass (3.746 s), covering every preset/fret choice, symbols, exact pitch order, chord/reference eligibility, voice sustain and phrase timing. Added explicit eighth-note duration assertions for the final study before the complete run. Final results and signed root Release evidence follow below. Native/hardware gates remain open in USER-VALIDATION.md; other course modules remain in progress.

- Final Learning run: 111 tests /32 suites pass (106.801 s), including the strengthened four-test musical contract and all existing authoring/adaptation coverage.
- Final App run: 150 tests /43 suites pass (165.233 s), including complete-corpus staff/reader/practice and tuning checks.
- Validator: 83 bilingual bundles, zero issues. Localization: all 840 UI keys pass. Partial curriculum audit: 76 authored, 1 needs_review, 51 todo; this is not full-course acceptance.
- Four Python author-tool tests pass (9.161 s), generated project is current, UI test sources type-check. No native UI execution or real-interface claim.

## Signed local Release

Root-only Release/archive build passes. Audit verifies 83 lessons /250 YAML files, en/uk offline resources, arm64 macOS 14 minimum, ad-hoc signature, hardened runtime and expected sandbox entitlements. Binary SHA256: `55ddba41f38d8723e5b10392fae29f1b5f747c8e769e22d7f7d4c3974af8e32f`; archive: `228801006c8d13f6319a7c132eb4a02934c8aa6079f780fb308ed3bc860fb77b`. Signed sandbox→separate XPC→invalidRequest passes without an AI provider. [Bundle report](../benchmarks/harmony-progressions-release-bundle.json). No local Debug app was built. Native launch/hardware remain unverified; exact-head CI/merge remain open.
