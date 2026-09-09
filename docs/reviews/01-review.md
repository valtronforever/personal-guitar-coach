# Task 01 — local review

Reviewed by the implementing agent on 2026-09-09; this is a local self-review, not an independent review.

## Scope

Native app lifecycle and composition, package boundaries, stable source identifiers, generated project/scheme, bundle/resources/signing, localization, CI, and new user instructions.

## Findings and fixes

1. **Generator failed before producing a project:** its object-key argument collided with the PBX object's `name` property. Renamed the argument. Regeneration and `plutil -lint` pass; `--check` confirms deterministic output.
2. **Xcode installation is not operational for project commands:** `-version` works but `-list` fails on a missing DVTDownloads symbol. The standard `-runFirstLaunch` remained idle without output for several minutes and was deliberately stopped. Added a SwiftPM build of the same native app sources, catalog compilation, bundle packaging, and ad-hoc signing. Xcode project/UI checks are recorded as U07, not falsely passed.
3. **UI smoke assertion assumed a single isolated static-text value:** native accessibility currently combines welcome text into a readable text element. Check title existence and localized title inclusion using value/label instead of equality. The native AX tree exposes the app title and all welcome/source text. The window renders correctly at 1000×700. XCUITest execution still requires U07.
4. **Raw identifiers could silently misidentify an unknown future input source:** verified Codable rejects an unknown identifier instead of defaulting it to electric guitar. Existing electric/microphone/pickup identifiers decode correctly.

5. **Initial planning files had extra blank lines at EOF:** removed them after checking the full staged initial diff. The final branch diff passes whitespace checks.

## Verification

- Xcode 26.6 (17F113), Swift 6.3.3, macOS SDK 26.5; running arm64.
- `swift test --package-path Packages/GuitarCoachCore`: 2 Swift Testing tests passed.
- `python3 Scripts/build_local.py`: Debug native app built and `codesign --verify --strict` passed.
- `python3 Scripts/build_local.py --configuration release`: Release native app built and signature verified.
- Both bundles contain compiled en/uk UI and microphone-purpose strings; minimum OS metadata is 14.0.
- App launched and was inspected through native accessibility and a screenshot. No audio permission is requested by the welcome screen.
- `python3 Scripts/generate_project.py --check`, `plutil -lint PersonalGuitarCoach.xcodeproj/project.pbxproj`, `git diff --check`: passed.

## Remaining evidence

U07: repair/complete Xcode system components and run the shared-scheme UI tests. Clean-host Xcode CI results are recorded on the PR. macOS 14 and Intel runtime compatibility are not claimed from this arm64 run. No external distribution is requested.
