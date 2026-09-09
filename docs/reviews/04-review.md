# Task 04 local review

Self-review by the implementing agent; no independent reviewer is claimed.

Reviewed navigation ownership, localization paths, Settings lifecycle, keyboard commands, accessibility roles, window sizing, and empty-state honesty.

## Findings and fixes

- Native inspection found that SwiftUI's environment locale updated body text but left navigation and Settings window titles stale. Navigation now receives explicitly localized text; a small NSViewRepresentable updates the Settings NSWindow title. Retested Ukrainian → English without relaunch: both titles update and Tuner stays selected.
- The scaffold UI tests referenced a removed static-text ID. Updated them to the new heading identifier and added a keyboard/locale preservation scenario. These Xcode tests are authored, not claimed to have run locally (U07).
- Preview settings originally used System while the view locale was Ukrainian, giving mismatched titles. Preview settings now explicitly match their locale, using isolated preference suites.
- Removed the unused former composition-root struct and welcome view. Navigation state and user preferences have separate owners; no locale-based view identity resets are used.

## Actual verification

- Debug and Release native bundles built and passed strict ad-hoc signature verification.
- Native CUA smoke: all four destinations through Command-1…4, Settings through Command-comma, English/Ukrainian switching in both directions, selection preserved, preferences restored on relaunch, light/dark appearance, accessible headings and control labels.
- Resized to the minimum 900-point width / 620-point content height (672 including native toolbar); Ukrainian tuner description wraps fully without clipping. Also inspected English light and Ukrainian dark screens.
- System preference matching checked with Foundation: uk-UA → uk, en-US → en, fr-FR → en, de-DE followed by uk-UA → uk. Initial native System setting rendered English on this Mac.
- Localization validator passes for 66 keys including English and Ukrainian plural forms and matching format arguments. Xcode project generator check and whitespace check pass.

Live VoiceOver reading and Xcode-driven UI tests remain part of final user/environment validation. No lesson content, tuner signal, or practice result is fabricated by the shell's empty states.
