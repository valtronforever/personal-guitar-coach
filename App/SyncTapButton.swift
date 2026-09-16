import SwiftUI
import AppKit
import AVFAudio

/// Captures key-down/mouse-down event time, not button-release or SwiftUI render time.
struct SyncTapButton: NSViewRepresentable {
    let title: String
    let enabled: Bool
    let onTap: (Double) -> Void
    let onInvalidTime: () -> Void
    func makeNSView(context: Context) -> TapButton {
        let button = TapButton(); button.bezelStyle = .rounded; button.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setAccessibilityIdentifier("sync.tap")
        return button
    }
    func updateNSView(_ button: TapButton, context: Context) {
        let becameEnabled = !button.isEnabled && enabled
        button.title = title; button.setAccessibilityLabel(title); button.isEnabled = enabled
        button.onTap = onTap; button.onInvalidTime = onInvalidTime
        if becameEnabled { button.window?.makeFirstResponder(button) }
    }
    final class TapButton: NSButton {
        var onTap: ((Double) -> Void)?
        var onInvalidTime: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if isEnabled { window?.makeFirstResponder(self) } }
        override func mouseDown(with event: NSEvent) {
            guard isEnabled else { return }
            window?.makeFirstResponder(self); record(event.timestamp)
        }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 49 || event.keyCode == 36 {
                if isEnabled && !event.isARepeat { record(event.timestamp) }
            } else { super.keyDown(with: event) }
        }
        override func keyUp(with event: NSEvent) {
            if event.keyCode != 49 && event.keyCode != 36 { super.keyUp(with: event) }
        }
        override func accessibilityPerformPress() -> Bool {
            guard isEnabled else { return false }
            record(ProcessInfo.processInfo.systemUptime); return true
        }
        private func record(_ timestamp: Double) {
            let uptime = ProcessInfo.processInfo.systemUptime
            let host = AVAudioTime.seconds(forHostTime: mach_absolute_time())
            guard let value = SyncInputTimestamp.hostSeconds(event: timestamp, uptime: uptime, hostNow: host) else { onInvalidTime?(); return }
            onTap?(value)
        }
    }
}
