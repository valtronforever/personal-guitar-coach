# Audio-file AI coach — local review

Reviewer: implementation agent (same-agent review; not an independent review).

## Scope

Explicit recording lifecycle, callback/worker separation, PCM/time alignment, offline WAV/MP3 analysis, immutable score boundary, XPC privileges and process lifecycle, prompt/response contract, storage/retention, en/uk controls, SwiftPM/Xcode packaging and CI.

## Findings and fixes

1. A child Process in the sandboxed main app cannot serve as the CLI authentication integration. Replaced the initial manual file-exchange direction with an application-private XPC service. The main app's audio sandbox stays enabled. Actual signed sandbox → XPC → CLI → structured Codex response was verified with a generated sine, not private audio.
2. Mixing the metronome into guitar would contaminate onset/pitch analysis. WAV keeps guitar on channel 1 and a reconstructed transport reference on channel 2, with explicit render/capture host metadata and unmeasured headphone latency. Offline tests assert zero click leakage into guitar and the expected reference onset after a 250 ms pre-roll.
3. Recording could be incomplete or grow indefinitely. Pre-reserved worker storage caps at 150 seconds and rejects invalid packets, discontinuity, missing timestamps, loss/overflow. Normal practice never starts it; the explicit action disables repeats and rejects overly long fragments before capture.
4. A sustained MP3 sine produced reliable pitch observations but no reliable onset event. Added bounded 100 ms reliable pitch samples rather than requiring every audible note to have a detected onset. A genuine generated MP3 now exercises this behavior.
5. Replacing a take before a failed retry would lose provenance of old accepted advice. Each analysis gets a new job directory; previous accepted advice/files remain, while last prepared request enables retry after failure or relaunch. Added per-attempt and global AI-data deletion, plus stale-load protection.
6. Process errors must not look like coaching or expose diagnostic secrets. Bounded output and timeout/cancel reject unsuccessful CLI calls; structured replies must match request/attempt/language and known evidence references. The actual Claude OAuth-expiry failure is classified as authentication, without showing raw CLI diagnostics or changing account settings.
7. Prompts need actual selected lesson content. Snapshot goal, rendered activity/steps, sounding note names, exact exercise/range/BPM/tuning and scoring/calibration evidence. Unknown historical text uses frozen exercise evidence rather than silently using a newer lesson version.
8. File import/copy must be bounded and cancellable. Require a regular WAV/MP3, stream-copy in chunks with a hard 100 MiB limit, analyze the copied bytes, verify the hash again before XPC, and mark imported timing correspondence unverified. Unknown pitch is displayed as uncertain, not 0 Hz.

9. Concurrent import during an in-progress AI take could occupy the only analysis slot and drop the automatic follow-up. Reserve the slot from the initial action, release on interruption, and freeze provider/language/lesson context at that action. Added reservation regression coverage.

## Verification

- Core: full 173 tests / 36 suites passed; focused four AgentBridge tests passed again after diagnostic handling changes.
- App: full 90 tests / 23 suites passed; six focused audio/one-action/reservation tests passed after subsequent bounded-copy/cancellation changes.
- EN/UK: 605 keys validated. Generated project current; Python author tests pass; UI-test API sources type-check (not UI execution).
- Signed debug app: XPC transport validation passed without a provider call. Codex 0.154.0 also passed a real synthetic provider call and returned structured Ukrainian output.
- Claude Code 2.1.236 launches, but its existing OAuth session is expired and cannot refresh. The same failure is reproducible from Terminal; reauthentication is pending_user, not a completed coaching test.
- Signed Release .app/ZIP and no-provider XPC probe passed. Bundle evidence is in `docs/benchmarks/audio-agent-coach-bundle.json`; CI completion is recorded in the task.
- Native UI inspection was attempted and failed with `Sky Computer Use native pipe closed before response`; no visual/hardware acceptance is claimed.

## Remaining acceptance

Real guitar/interface recordings, Bluetooth reference interpretation, recommendation quality and native EN/UK/VoiceOver visual acceptance remain pending_user. Synthetic checks do not prove these. No cable loopback, raw-audio-capable model, hand/finger inference or AI regrading is claimed.
