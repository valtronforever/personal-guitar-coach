# Listen and repeat — same-agent review

Status: local software/Release checks passed; exact-head CI/merge pending. Not an independent review. Scope: private response authoring, frozen guidance conditions, coordinated reference/response lifecycle, hidden-target UI and topics 81–84. No native app launch or hardware acceptance is claimed.

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

Verification collected:

- Full Core: 23 Persistence tests (0.054 s), 126 Learning (120.922 s), 53 Domain (0.335 s), 102 Audio (433.747 s), 6 AgentBridge (1.638 s): 310 total, all passed. `/tmp/listen-core-full.log`.
- After the explicit-rest loader guard: 6 Learning tests in 2 suites (6.719 s) and 3 Domain tests (0.005 s) passed. `/tmp/listen-core-final-regressions.log`.
- After course/notation fixture and explicit-rest corrections: 33 App tests in 8 suites passed (57.676 s). `/tmp/listen-final-app-regressions.log`. Final full App: 167 tests in 49 suites passed (189.144 s), including the final privacy-boundary guards. `/tmp/listen-app-final.log`.
- Four Python authoring/audit tests pass (10.164 s); 888 localization keys pass; generated Xcode project is current; UI-test sources type-check. This does not execute native UI tests.
- Root-only signed Release and archive pass `docs/benchmarks/listen-and-repeat-release-bundle.json`: arm64, macOS 14, ad-hoc signature, hardened runtime, expected sandbox/audio entitlements, 90 bundles / 271 YAML files. Binary SHA256 `0cbccad45e2ece7a98a47b6c611f2a8bc72ac36ff1166665ff54eac3b8f981da`; archive SHA256 `f786d123490e838e527540dba134f9b03c8a613d96587abbd9fd6bbbb06141ec`. `/tmp/listen-release.log`, `/tmp/listen-bundle.log`.
- Signed sandbox → separate XPC → invalidRequest probe passed; no provider was called. `/tmp/listen-xpc.log`.

Exact-head CI/merge and native/hardware acceptance remain open. Full course acceptance remains open.
