# Manual latency field affordance — same-agent review

Scope: appearance of the two manual input controls; no audio, parsing, persistence or scoring changes. Reviewed by the implementation agent, not independently.

The grouped Form treated the example text as the TextField's visible label while leaving the editable value borderless. A shared `ManualDelayField` now explicitly hides the empty label, uses a large native rounded-border field, and puts the localized signed-value example below it. Both fields retain their bindings, accessibility labels/identifiers and disabled state.

Visual verification used the actual production component inside a grouped Form, rendered offscreen with NSHostingView (EN/UK, light/dark). The field frame/background, entered values, caption and adjacent Apply buttons are visible without clipping. ImageRenderer cannot render native TextField internals, so its unsupported-control placeholder was not treated as evidence. No user-app UI events were synthesized. Native computer-use selection returned a closed-pipe error; no live-window/focus verification is claimed.

Release build and signed bundle/archive verification passed; 13 bilingual lessons, 719 localization keys, generated project and UI-source typecheck passed. Cosmetic-only scope: no new logic tests. [Bundle evidence](../benchmarks/latency-field-release-bundle.json).
