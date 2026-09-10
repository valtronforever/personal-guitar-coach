# Task 22 notation geometry artifacts

Generated from the actual shared `StaffDrawing` with SwiftUI ImageRenderer on the local macOS toolchain. These are offline drawing artifacts, not native app screenshots. No microphone, user performance or VoiceOver was exercised.

The selected samples show actual C-major lesson notes, mixed rhythm/key signature in dark mode, a dark hollow half note/rest, and the highest supported written E7 whole note/ledger lines. Full opt-in generation creates 48 images across eight bars, three signatures and two themes:

```sh
COACH_STAFF_RENDER_DIR=build/staff-renders DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter StaffRenderTests
```

Original vector drawing; system Apple Symbols supplies the clef/accidentals. Final native layout/keyboard/localized controls/VoiceOver remain U05/U07. See ADR 007 and the task-22 review.
