# Audio-file AI coach

Status: `pending_user` (software verification complete; PR/CI completion recorded below).

## Scope

Opt-in **Record & analyze** action for one practice take (up to 120 seconds), WAV with guitar and a separate scheduled metronome reference, automatic local Codex/Claude Code invocation, lesson-specific en/uk recommendations. Import existing WAV/MP3 as an additional entry point. No manual command/export/import step in the normal flow.

## Acceptance

- Ordinary practice saves no raw audio. One AI action records once and starts analysis after assessment, without changing its numeric score.
- Use the existing capture coordinator and worker; no second input pipeline or recording work in the audio callback. Bounded memory, explicit recording failure on loss/overflow.
- Preserve clean guitar on channel 1. Channel 2 is reconstructed from the actual transport plan and render epoch, labelled as a reference rather than measured headphone sound. Calibration uncertainty remains explicit.
- Main app remains sandboxed. A separate application-private XPC service runs installed CLI with existing CLI-owned authentication. Bounded input/output, timeout/cancellation, no shell interpolation.
- Context includes the lesson goal/text, exact frozen exercise/range/BPM/tuning/position and assessment/calibration versions. Imported-file alignment is unverified.
- Validate structured feedback identity/language/evidence references, retain versioned local artifacts, allow retry/deletion. AI text is supplemental and cannot replace scores.
- EN/UK and accessible controls. No credentials/private guitar recordings committed.

## Validation

- Full Core suite: 173 tests / 36 suites passed; final focused runner suite: 4 tests passed.
- Full App suite: 90 tests / 23 suites passed; final focused audio/one-action suite: 5 tests passed.
- Localization: 605 EN/UK keys; generated project, Python author tests and UI API type-check passed.
- Local signed Release .app and ZIP built and verified: [bundle evidence](../docs/benchmarks/audio-agent-coach-bundle.json).
- Actual signed sandbox-to-XPC probe passed without provider calls; Codex 0.154.0 returned structured Ukrainian feedback on a generated sine through the real CLI integration.
- Claude 2.1.236 starts but its current OAuth session is expired and cannot refresh (also reproduced directly from Terminal). Reauthentication is pending_user.
- Native UI automation could not inspect the app: `Sky Computer Use native pipe closed before response`. Hardware, EN/UK visual/VoiceOver acceptance and coaching quality remain explicitly open in [USER-VALIDATION](../docs/USER-VALIDATION.md).
- Same-agent [local review](../docs/reviews/audio-agent-coach-review.md); [design and usage](../docs/AUDIO-AGENT-COACH.md).
- PR/CI: pending publication. No private recordings or credentials used in tests.
