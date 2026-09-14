# Personal synchronization — local review

2026-09-14. Same-agent review; this is not an independent review.

## Scope

Two-pass runtime ownership and failure paths; repeatability estimator; calibration profile/schema migration; scoring/history labels and versioning; freshness; input/output separation; display timing; English/Ukrainian resources and native project inclusion.

## Findings and fixes

1. A playing-based residual includes personal timing bias and input latency. Treating it as measured hardware evidence or output-only cursor delay would be misleading. Added exclusive personal evidence/method and approximate scoring labels; cursor uses reported output latency only. The documentation explicitly states the remaining unknown Bluetooth delay.
2. Matching regular beats across a full-beat search can hide missing attacks. Bound each measured attack to ±400 ms, require all sixteen, reject in-window extras/wrong/uncertain notes and compare two independent passes. Synthetic positive/negative delay, dropped first/last note, whole-beat shift, extra attack and unstable timing cases cover these decisions.
3. A profile restored for an identical device UID could silently survive reconnection. Keep nonpersisted session/revision receipts, invalidate on hardware/power events, require matching instrument, and recheck freshness during active personal practice as well as at start. Tests cover relaunch, sleep, changed route between passes and active-practice invalidation.
4. Asynchronous cleanup/apply could publish a stale or unsaved candidate. Capture UUID leases prohibit overlapping runs, apply validates session/revision, failed writes preserve the previous profile, and receipt publication cannot make a changed route eligible. Tests cover cancellation, bad pitch, clipping, changed route, failed write/retry and stale candidate apply. Superseded receipts are removed.
5. Delayed trailing attacks and cursor position need different corrections. Extend evidence drain for reported output delay and positive residual; only shift cursor by output metadata, never by personal residual. The existing final-drain assertion was updated from 1.41 to 1.42 seconds for a fixture with 10-ms input and output latency.
6. New approximate tolerance must not silently change saved results. Scoring v2 permits a maximum 200-ms personal tolerance (still interval/uncertainty gated), retains existing measured behavior, and decodes v1 without rerating. Calibration documents read schema 1 and write schema 2 on mutation.

## Verification

Final command results are recorded in tasks/personal-sync-wizard.md. Core suite, app suite, targeted new persistence/scoring/lifecycle regressions, localization validation, generated-project consistency and UI-source typecheck are required. Local Release bundle validation and GitHub CI are tracked there.

## Remaining limits

Real guitar/interface/Bluetooth passes, native accessibility/layout and physically audible cursor alignment remain user-validation gates. Synthetic analysis DTOs are not an actual device measurement. The retained offline loopback code is historical; there is no cable calibration UI. A two-pass human exercise estimates repeatability, never an absolute hardware latency bound.

Native UI attempt: `cua.getApp` on the new Release path failed with “Sky Computer Use native pipe closed before response”; no alternative UI automation or live calibration was performed.
