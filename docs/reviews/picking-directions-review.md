# Picking directions and coordinated-note practice — local review

2026-09-17. Same-agent code, content and visual review. Scope: optional single-note picking cues, alternate-picking and hand-synchronization lessons (topics 49–50). Full curriculum remains in progress.

## Findings and decisions

- Optional pickStroke: down/up belongs to a single note only. Rests, multi-string chords and simultaneous strum metadata are rejected; chord direction remains the existing strum contract. A shared derived direction feeds notation without adding a second encoded value.
- The field survives lesson resolution and frozen exercise round trips. Omitted cues keep historical canonical encoding unchanged. Picking direction does not modify reference samples, pitch/time targets or assessment; tests compare up/down/omitted audio exactly at 44.1/48 kHz. No physical stroke inference is claimed.
- Both TAB forms and staff show directions at initial attacks, never tied continuations. Localized spoken descriptions include the intended direction. Offline low-A1 staff and compact score fixtures include mixed accent, P.M. and direction cues.
- Visual review found compact upstroke heads crowding P.M. text. Muted-note direction uses a smaller symbol and lower center; rerendered Ukrainian/light 600px and English/dark 980px layouts retain separation from P.M. and fret digits. Native VoiceOver and hand comfort are pending_user.
- The alternate-picking lesson progresses from one repeated target to string crossing and an explicit upstroke start. The synchronization lesson uses a three-string chromatic route with a full release bar and four-note bursts with two quiet beats. Both retain physical fret patterns and adapt sounding targets to the selected tuning. Individual hand cause, finger choice and tension are self-observed, distinct from pitch/attack feedback.

## Verification

- 60 bilingual bundles validate; 809 UI keys, generated project and UI-source type-check pass. Inventory: 50 authored, 4 needing review, 74 todo.
- Independent course matrix verifies exact positions, alternating cues, upstroke start, note/rest durations and scored eligibility across eight tunings × five fret counts. JSON round trips and invalid cue combinations pass. Existing strum/palm-muted reference tests pass unchanged.
- Full Core/App and signed Release evidence remains pending below. Native accessibility, actual guitar strokes and practical playing accuracy are not established by the synthetic/code tests.
