# Visible manual latency inputs

Status: `done`

The macOS grouped Form displayed the TextField title as a separate label and left the value visually borderless. Both manual latency fields now explicitly use a rounded bordered native control with a visible field background/focus ring; the signed-value example is a caption below the field. The accessible label, field identifiers, bindings and apply behavior remain unchanged.

Validation: build, localized resources and visual verification passed. Cosmetic scope; no new logic tests required.

- Shared production field rendered offscreen in a grouped Form for EN/UK and light/dark; entered values, borders/backgrounds and below-field examples are visible without clipping. Native NSHostingView rendering was used because ImageRenderer does not render TextField internals.
- Local Release app/ZIP rebuilt and signatures/resources/archive verified: [bundle evidence](../../docs/benchmarks/latency-field-release-bundle.json). 719 localization keys, 13 lessons, generated project and UI-source typecheck passed. No new logic tests for this cosmetic change.
- [Same-agent review](../../docs/reviews/latency-field-affordance-review.md). Native live-window access remains unavailable (computer-use pipe closed); no hardware/keyboard outcomes are newly claimed.
