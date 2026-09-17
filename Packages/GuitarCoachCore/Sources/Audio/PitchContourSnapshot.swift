import Domain

/// Bounded worker output at the same 50 Hz/window-center clock as sustain, with a separate quality contract.
public struct PitchContourSnapshot: Equatable, Sendable {
    public let version: String
    public let frames: [SustainTraceSample]
    public let totalFrames: UInt64
    public init(version: String = PitchContourTrace.currentVersion, frames: [SustainTraceSample], totalFrames: UInt64) {
        self.version = version; self.frames = frames; self.totalFrames = totalFrames
    }
}
