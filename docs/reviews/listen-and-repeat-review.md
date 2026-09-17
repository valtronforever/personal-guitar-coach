# Listen and repeat — same-agent review

Status: implementation under verification; not an independent review. Scope: private response authoring, frozen guidance conditions, coordinated reference/response lifecycle, hidden-target UI and topics 81–84. No native app launch or hardware acceptance is claimed.

Findings and corrections:

- Preview completion releases coordinator ownership and retains a completed snapshot. An initial request-ownership guard rejected every successful reference. The guard now accepts the matching completed snapshot only in idle/no-owner state, keeps route/session checks, waits for the output allowance, and rejects canceled/stale generations. The regression drives a real coordinator with a stub runtime through reference → complete → recorded response.
- Guidance must remain sticky after deliberately revealing a target. A small preparation state retains reveal through replay, cancellation and tempo/range changes; a fresh selection resets it. Configurations require preparation conditions exactly for opted-in activities. A retry preserves the mode and requires fresh preparation.
- A listening response could leak its answer through shared material, visual steps, fingerings, position controls or context tokens. Loader guards reject these combinations; reading selectors provide no target exercise or fretboard visuals for the response. Private recognition quizzes remain separate. Hardcoded prose/duplicated answers require editorial review.
- Matching fixtures initially constructed an impossible completed attempt with no confirmed signal. Fixed the fixture to use the actual preflight-failed state; the production validity contract was retained. Comparison fixtures now use identical calibration ID/date so the guidance condition is the reason hidden/guided attempts are incompatible.
- The full-course notation regression found implicit gaps in new held-note responses. Added explicit rests while preserving attack pitches/timing, and made the private-response loader reject implicit gaps. Revealed/results staff notation can now be checked for every response instead of failing with `.gaps`.
- Updated the explicit catalog count regression from 81 visible/87 loaded to 84 visible/90 loaded after adding three bundles and expanding the existing interval lesson. No catalog assertion was removed.
- ImageRenderer omitted native GroupBox content. Offline visual verification now uses NSHostingView bitmap rendering, which includes the actual controls and text. Both language/theme pairs were generated; Ukrainian light and English dark at 600 points were inspected. Buttons and full instructions fit; pulse selection has an outline in addition to color. This is not native interaction/VoiceOver acceptance.

Current targeted evidence:

- 17 responses across 8 tunings × 5 fret counts (680 combinations), each at 50/60/90 BPM, retain independent pitch goldens and source event timing. Full response/recognition content validates: 90 bilingual bundles, 0 issues; 888 UI localization keys.
- Five targeted response/matching/state tests pass after corrections: reference requires no input or recording; actual response uses one capture and a practice transport with tone volume zero; cancellation/settings changes reject preparation; guided conditions persist; correct/wrong/late/missing-signal fixtures retain truthful scores and calibrated timing limits. Historical Codable omission and malformed-condition guards are covered separately.
- The inventory now has 84 authored topics and 44 todo. Topic 82 is version 2 and includes its original private direction question, three interval-recognition questions and five real instrument responses. Topics 81/83/84 add 4 responses each. The body texts teach distinct comparison methods in both languages; fixed examples are not claimed as randomized unseen tests.

Full suites, signed Release and exact-head CI evidence are still being collected. Full course acceptance remains open.
