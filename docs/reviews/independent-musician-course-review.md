# Independent-musician course review (121–128)

Same-agent editorial/software review, not an independent review. Scope: all eight remaining course topics, their original music and en/uk teaching, hidden listening targets, shape/held-voice notation, recording opt-ins, module/prerequisite placement and library modes. This is a stage review, not acceptance of the entire 128-topic course or of actual guitar/native behavior.

## Coverage and musical intent

| Topic | Distinct teaching and exercises | Capability |
| --- | --- | --- |
|121 Transcribing a riff/solo | Whole four-bar reference, four individual phrases, rhythm-versus-pitch workflow, paper uncertainty map, reconnect/review | Five hidden listen-and-repeat entries; self-report of method/help used |
|122 Reading music formats | Two unfamiliar two-bar melodies, actual named chord shape with muted strings/fingers, timed chord attacks/releases and separated chord tones | Three monophonic entries; chord/notation self-practice |
|123 Writing a riff | Seed, exact repeat, denser variation, deliberate ending, four-bar whole and own variation | Display-only; explicit ungraded recording of the whole frame |
|124 Two guitars | Separate lower sustained role and upper delayed answer, combined independently held reference, sparser upper alternative | Display-only; three explicit recording activities; one selected capture input |
|125 Rhythm section | Low role, upper two/four attacks, offbeat alternative and final-bar break | Display-only; three recordings; partner/external accompaniment work explicitly distinguished from built-in metronome |
|126 Prepare composition | Intro/A/varied A/bridge/ending, overlap at bars 5–6, full original eight-bar form | One graded boundary; full-study recording; preparation versus performance distinguished |
|127 Control recording | Same learned eight-bar composition, boundary/end repair examples, Save WAV/default-player review and concrete bar-based correction list | Two graded fragments; explicit full ungraded recording |
|128 Personal plan | Evidence-based priority, chromatic control, re-entry rhythm, hidden ear response, musical transfer and a balanced adjustable practice cycle | Three graded entries (one hidden); musical-transfer recording and self-report |

Totals:36 activities,14 graded entries (six hidden listening responses),22 display-only activities and ten recording opt-ins. Each body has 353–376 English words and 273–294 Ukrainian words across five teaching paragraphs, plus distinct step/activity guidance and four/five review criteria. No imported copyrighted song, generated placeholder lesson, polyphonic score or automatic technique diagnosis is asserted.

## Review findings and corrections

- The initial transcription order placed the complete example after the fragments despite asking the learner to map the whole first. Moved the full hidden reference ahead of the four parts and renamed its heading. The learner can return to that same whole after phrase work. Hidden activities contain no note-name/position template leaks; the reader exposes only the deliberate reveal workflow in practice.
- The initial compact reading example was only a chord event, which did not show the full spatial information a chord diagram should convey. It now uses the actual named-fingering material/step with strings 4–6 explicitly muted and suggested fingers on strings 1–3. The separate timed chord pattern shows why a shape alone does not specify rhythm. The three-note preparation checks audible pitches separately, never simultaneous chord recognition.
- A library test initially searched a word appearing only in lesson body text. Search is intentionally defined over localized title/summary/keywords. Corrected the test to a bilingual title query (`бас drums`) and verified it in both UI languages; no unnecessary broad search behavior was introduced.
- Two-guitar and rhythm-section lessons explicitly separate musical role training from unavailable multitrack capture/drum stems/import mixing. They provide original timed role models, joint held-voice playback, metronome practice and actual self-recording. Partner/ensemble listening remains a practical external/hardware exercise. The single selected input is never labeled a full-band recording.
- Performance lesson 127 reuses the exact learned miniature from 126 so the control take tests readiness rather than introducing a new unknown score. The form is eight bars:1 intro;2–3 A;4–5 varied A;6–7 bridge;8 ending. Opening and closing rests remain inside the form. The full take stays ungraded despite two separately measurable repair fragments.
- Own-riff and musical-transfer recordings preserve the supplied score as reference context. Prose explicitly says that the app does not transcribe/composition-edit the learner's new notes. A saved file or completed take is not proof of successful playing. Schedule/repair notes are written by the learner, not falsely presented as an implemented text editor or automatic planner.

- Cross-checking the reading prose against StaffModel exposed an octave error: staff is guitar notation written 12 semitones above sound, while fretboard/target names use sounding pitch. Corrected both translations and the harmonic cue wording. The staff footer still described slides/legato/triplets as unimplemented; replaced that obsolete limitation with current octave/TAB/fallback guidance. The author guide now lists all six supported meters/pulse units, and the architecture points to the resolved activity/YAML API.
- An attempted native app inspection through computer-use timed out before returning a window. This provides no native layout or interaction acceptance; those checks remain pending_user.

## Software evidence

- Independent expected MIDI chords/notes, durations, rests, continuous start ticks, form lengths and held-string roles cover 1,440 activity/preset/neck cases; grading capability checked at 40/60/120 BPM. Two Learning tests passed 5.108s.
- Both-language module/order/mode/query checks plus 400 frozen recording contexts and 240 hidden response contexts: two App tests passed 6.479s. Contexts retain the original instrument when subsequent reading selection changes; hidden entries expose neither TAB nor fretboard answers.
- The prepared and recorded whole-piece event arrays are identical and exactly 30,720 ticks. Combined arrangement has 12 reference voice spans with four lower voices each lasting 3,840 ticks. Chord-shape visual checks confirm mute/finger roles.
- Initial content validator:134 bilingual bundles, zero issues. Partial inventory:128 authored topics. Strict `--complete` intentionally reports all 128 still awaiting final review evidence/status; this stage does not claim final acceptance from the folder count.
- The first full App run exposed three fixed inventory expectations from the previous 120/126 stage. Updated them to the agreed 128 visible / 134 total catalog and retained all legacy bookmark/staff/starter-flow assertions; final rerun is pending.
- Full Learning/App suites, final content/tools, signed root Release/bundle/XPC and exact-head CI/merge remain in progress at this revision.

Native library/lesson layout, keyboard/VoiceOver, actual tuning/ergonomics, guitar timing, two-player rehearsal and file-picker/default-player recording review remain pending_user. Synthetic and mathematical tests do not close them.

## Completed local software checks

Full Learning: 149 tests/54 suites passed 242.340s. Full App after the three inventory corrections: 196 tests/61 suites passed 278.997s; no remaining failures. The final content check validates 134 bilingual bundles with zero issues. Project generation is current, 948 UI keys preserve en/uk placeholder parity, five author-tool tests pass 18.055s, UI-test sources type-check and the partial curriculum audit reports 128 authored topics. Latest reading prose has 374 English / 290 Ukrainian body words after the octave correction. Signed root Release, exact-head CI/merge and the separate complete-course acceptance audit remain open.
