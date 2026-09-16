import Domain

/// Worker output sampled at 50 Hz. Time is the center of the analyzed pitch window.
public struct SustainTraceSample: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let time: AnalysisTimestamp
    public let state: SustainFrame.State
    public let frequency: Double?
    public init(id: UInt64, time: AnalysisTimestamp, state: SustainFrame.State, frequency: Double?) {
        self.id = id; self.time = time; self.state = state; self.frequency = frequency
    }
}

public struct SustainTraceSnapshot: Equatable, Sendable {
    public let version: String
    public let frames: [SustainTraceSample]
    public let totalFrames: UInt64
    public init(version: String = SustainTrace.currentVersion, frames: [SustainTraceSample], totalFrames: UInt64) {
        self.version = version; self.frames = frames; self.totalFrames = totalFrames
    }
}
