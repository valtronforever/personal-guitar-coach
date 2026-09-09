# Task 13 local review — guitar tuner

Reviewed by the implementing agent, not an independent reviewer. Date: 2026-09-10.

## Scope and findings

- Reviewed tuner state transitions, actual/target frequency separation, tuning/A4 propagation, audio ownership, stale analysis, en/uk UI and tests.
- A UI timer can revisit one old reliable frame indefinitely. Fixed by qualifying with DSP stream time and expiring display after 200 ms without a new frame. Intervening bad quality spans and lost bounded-history prefixes reset qualification even when the latest frame is reliable. App regression tests cover each path.
- Median smoothing could preserve a green reading across the ±5-cent boundary. Only raw cents qualify/revoke confirmation; smoothing controls the pointer. Boundary-jitter tests cover this.
- Automatic nearest-note matching can mistake an open high E for a low E harmonic. Automatic targets near another open string’s harmonic/unison request explicit string selection. Manual low E with high E input remains +2400 cents; no physical-string claim is made.
- An output-only setup probe originally allowed non-setup capture to start alongside it. Coordinator rejects this ownership combination; regression verifies stop then tuner acquisition.
- Start/Stop inside scrolling content could be hidden during tuning. Pinned controls to bottom safe area. Added explicit labels, symbols and selection values; no color-only feedback.
- Static SwiftUI text may be exposed as a combined accessibility element. UI assertions use visible text predicates where appropriate; actual VoiceOver and Xcode UI-test execution remain final validation.

## Evidence

77 core tests in 13 suites pass; 34 app tests in 9 suites pass. Includes PCM sine → actual analyzer → tuner → silence integration. Localization validator passes 279 en/uk keys. UI-test sources type-check under Swift 6/macOS 14. Native Debug and Release builds/signing pass. Native dark UI inspected in English and Ukrainian, including synthetic in-tune and silence; no real input or permission was attempted. User language preference restored to System.

PR #35 passed GitHub CI run 34415291760 (4m25s) and merged as fa60d1b on 2026-09-10. U02/U05/U07/U08 remain open. No distribution or notarization.
