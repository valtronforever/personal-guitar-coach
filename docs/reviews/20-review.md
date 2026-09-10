# Task 20 local review

Review performed by the implementing agent; this is not an independent review. Scope: local bundle generation/signing, source/resource consistency, icon generation/Xcode integration, accelerated practice evidence benchmark, bounds regression and the product/hardware acceptance matrix.

## Findings and fixes

1. The local app had no icon. Added original code-generated CoreGraphics artwork, all ten macOS asset sizes and ICNS. Xcode uses the AppIcon catalog; SwiftPM packaging uses the same ICNS. Inspected the 1024-pixel source output. Native Dock/Finder presentation remains U07.
2. Packaging removed the previous app before resource/signature work could fail. Assembly now happens in a temporary staging directory with content and full bundle validation before replacement; a failed rename restores the prior app. Optional archive creation stages its ZIP before replacement. A local ZIP is not published.
3. A signed binary alone did not prove usable packaged course/locales. Added a bundle checker for exact compiled translation keys/values, localized microphone purpose, source-identical lesson resources, icon, entitlements, binary target/system dependencies and Release debug-fixture exclusion. The extracted ZIP must yield the same report. Tampered-icon and truncated-ZIP negative checks fail as expected.
4. The long-practice benchmark initially could not construct public audio observation DTOs from another module. Added explicit immutable memberwise constructors, with no analysis behavior/version change. The benchmark remains a separate CLI and cannot start capture.
5. The quality-bound test initially used a Swift expression too complex to type-check, then incorrectly expected an equal split of clipping/uncertainty. Replaced the expression with a typed loop and asserted the actual shared 4096 cap with both categories represented. All five collector tests pass. No collector change was required.
6. A virtual 900-second scenario could be confused with real-time hardware proof. Report fields and documentation explicitly say accelerated synthetic events, no PCM/capture/clock/underrun measurement. RSS is a process high-water value, not a memory-leak conclusion. Physical 15-minute protocol and all unresolved U01–U10 gates remain explicit.

## Verification

- Full local core run: 129 tests, 128 passing plus the newly added assertion failure described above. After the test correction, all 5 PracticeEvidenceTests pass. Full CI suite repeats on the final PR head.
- All 52 App tests passed (16 suites); existing model/storage/calibration/practice/result/course coverage retained.
- Release BenchmarkPractice passed: 45,231 publications, 900 attacks/settling intervals, rolling bounds 128/256, compensated score 100, second-attempt isolation, two exact restored records. Artifact: `docs/benchmarks/20-practice-soak.json`.
- Release quick DSP benchmark: all 360 cases and unchanged gates passed. Timed already-built executable: 9.74 s wall, 9.14 s user + 0.20 s system, peak RSS 25,542,656 bytes. This is offline batch work, not live CPU load. Full 3,360-case v2 artifact remains task 17; no DSP computation changed here.
- Both local Debug and Release builds passed; staged content validator found six bilingual lessons and zero issues. Release and extracted ZIP passed final bundle checks; artifact: `docs/benchmarks/20-local-release.json`.
- Generated Xcode project current; 492 UI keys/EN+UK/format checks pass; UI-test sources type-check; 34 corpus hashes/provenance/formats pass; Python scripts compile; `git diff --check` passes.
- Signature is local ad-hoc with hardened runtime, sandbox and audio-input entitlements. No upload, distribution certificate or notarization.

Local Xcode UI-test execution, final native UI/VoiceOver/offline launch and real USB guitar acceptance remain pending user/environment checks. No critical unresolved software issue was found within this reviewed scope; this is not a claim of hardware MVP acceptance.
