# Compact manual latency editor

Status: `done`

Improve the manual delay controls for output and instrument: label above the editor, compact numeric field, adjacent localized unit, short Apply action and an explicit example below. Keep native editing chrome, existing initial-focus behavior, validation, accessible action context and stored values.

Acceptance: inspect both languages in light/dark with signed values and disabled controls; rebuild and verify the local Release. No audio/scoring changes or new logic tests for this layout-only work.

Implemented in the shared ManualDelayField: label above, 112-point native rounded numeric field with trailing alignment, adjacent ms/мс, prominent short Apply action, example below. Full output/instrument action names remain in accessibility labels and tooltips; existing identifiers, enablement and action closures are preserved.

Validation: production component rendered via offscreen NSHostingView in grouped Form in EN/UK and light/dark; +120.0, −25,5 and disabled −1000.0 display without clipping. Local previews are in `build/visual-validation/latency-editor-*.png` (not committed build artifacts). Release app/ZIP rebuilt and verified; 721 localization keys, generated project and UI-source typecheck passed. No new logic tests for a cosmetic change. Live native window selection timed out; keyboard/VoiceOver and prior timing hardware acceptance remain open.

Evidence: [same-agent review](../../docs/reviews/latency-editor-layout-review.md), [Release verification](../../docs/benchmarks/latency-editor-release-bundle.json).
