# Audio-file AI coach

The practice screen has an explicit **Record & analyze** action. Normal Start does not record. After the usual tuning confirmation/signal preflight, the action records one take, runs the existing assessment, and automatically requests supplemental advice from the provider selected in Settings → AI coach. The action reserves its analysis slot and freezes provider/language/context at the start. Repeats are disabled for this action; select a fragment up to 120 seconds.

## Audio and timing

The existing AUHAL callback still writes only its bounded C ring. Opt-in PCM collection runs on PCMReader with a reserved maximum of 150 seconds of mono samples (28.8 MB at 48 kHz). Invalid timestamps/samples, loss, discontinuity or capacity overflow reject the recording. File I/O and offline DSP run outside capture/MainActor. The capture coordinator remains the sole owner of input.

WAV channel 1 is the selected guitar input. Channel 2 is reconstructed using the same TransportPlan, BPM, count-in, range and click gain, aligned using capture and render host timestamps. It is **not a loopback measurement** and does not reveal actual Bluetooth/headphone latency. Personal calibration still includes player bias. AI analysis never changes a score or asserts string/finger recognition.

An imported WAV/MP3 may be 44.1/48 kHz, at most 150 seconds and 100 MiB. The user explicitly chooses its one-based channel; channels are never mixed. Correspondence with the saved practice and the recording's start offset are unverified. Only app recordings include capture/render alignment metadata.

## Agent boundary

The app is sandboxed with audio-input and user-selected-read-only entitlements. An embedded **application-private, non-sandboxed XPC service** launches the installed CLI as the current user. This is an intentional privilege separation for local CLI authentication; it is not an App Store/distribution design. It has no administrator privileges. The main app cannot execute arbitrary shell text through the protocol: inputs are bounded request/audio Data and the two enumerated providers, with cancellation.

The service verifies the audio hash, creates a private temporary directory and passes an absolute WAV/MP3 path plus the local DSP report and lesson context in the prompt. Codex/Claude in this integration do not natively hear WAV/MP3. They interpret the app's measured evidence. Do not describe this as an audio-capable model. Codex uses a read-only execution sandbox, disables shell/exec, apps/plugins/hooks, subagents, images and web search, ignores user configuration/rules and uses an ephemeral session; Claude uses safe mode, no tools/MCP/hooks and no persisted session. CLI-owned auth remains outside the app. CLI admin policy may still apply.

The default hosted models require network/account access and may consume existing usage. Data sent to the provider includes the selected attempt's lesson and audio measurements/assessment (including route/calibration context); raw audio stays in local files; the configured analysis invocation disables tools that could read/upload it. Core learning/tuning/scoring remains offline and independent of AI.

Verified development CLI versions: Codex 0.154.0 and Claude Code 2.1.236. Install/sign in through Terminal first. Discovery checks /opt/homebrew/bin, /usr/local/bin, ~/.local/bin and the bundled Codex app CLI. There is no API key field or provider installation flow. Timeouts are five minutes; missing CLI, invalid response, authentication/network/process failure and cancellation are explicit errors. The UI offers retry using the saved take.

## Files and advice

Opt-in data lives in Application Support/PersonalGuitarCoach/AgentCoach/<attempt UUID>/<job UUID>/ inside the app container: audio.wav/audio.mp3, request.json and accepted response.json. Each retry creates another job; the last accepted response is also retained at attempt level. The request snapshots exercise, tuning, scoring, calibration, prompt and DSP versions; feedback includes provider, language and timestamp. Requests use file hashes and practice digests to prevent accidental cross-attempt reuse. Unknown evidence references/language/identity are rejected. This validates structure/provenance, not the truth of generated prose; the UI labels it AI advice.

Delete a take and all its AI jobs from its result, or delete all AI files in Settings. AI data is a separate store from practice history, so Settings deletion also removes files whose practice entry was cleared. Cancellation terminates the provider request and leaves already prepared local data for retry/deletion. Provider-owned logging/account retention follows that provider's configuration.

## Verification

`swift test` includes file/channel/quality, metronome alignment, response validation and the one-action practice flow. `swift test --package-path Packages/GuitarCoachCore` includes recording loss/overflow and fake-provider failure/timeout tests. These do not send private recordings to a provider.

The AgentServiceProbe executable is test tooling only and is not distributed in the app. A temporary ad-hoc signed sandbox bundle containing the actual XPC service can use it to verify transport without invoking a provider. Real interface, UI/VoiceOver and provider coaching-quality acceptance remain separately recorded in USER-VALIDATION.md.

References: [Apple XPC service design](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html), [Codex noninteractive mode](https://developers.openai.com/codex/noninteractive), [Claude CLI reference](https://code.claude.com/docs/en/cli-reference).
