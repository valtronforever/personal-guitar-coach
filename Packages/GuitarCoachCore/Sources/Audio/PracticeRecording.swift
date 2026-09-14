import Foundation

/// Opt-in bounded worker storage, separate from the realtime callback. Overflow fails the recording.
public struct PracticeRecording: Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let firstHostSeconds: Double
    public init(samples: [Float], sampleRate: Double, firstHostSeconds: Double) {
        self.samples = samples; self.sampleRate = sampleRate; self.firstHostSeconds = firstHostSeconds
    }
}

struct RecordingBuffer {
    static let maximumSeconds = 150.0
    let sampleRate: Double
    private(set) var samples: [Float] = []
    private var firstHostSeconds: Double?
    private(set) var failed = false

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        samples.reserveCapacity(Int(sampleRate * Self.maximumSeconds))
    }

    mutating func append(_ values: UnsafeBufferPointer<Float>, hostSeconds: Double?, healthy: Bool) {
        guard !failed else { return }
        guard healthy, let hostSeconds, hostSeconds.isFinite,
              samples.count + values.count <= Int(sampleRate * Self.maximumSeconds),
              values.allSatisfy(\.isFinite) else { failed = true; samples.removeAll(keepingCapacity: false); return }
        if let firstHostSeconds,
           abs(hostSeconds - firstHostSeconds - Double(samples.count) / sampleRate) > 0.02 {
            failed = true; samples.removeAll(keepingCapacity: false); return
        }
        if firstHostSeconds == nil { firstHostSeconds = hostSeconds }
        samples.append(contentsOf: values)
    }

    func finish() throws -> PracticeRecording {
        guard !failed, !samples.isEmpty, let firstHostSeconds else { throw AudioBackendError.dataLoss }
        return PracticeRecording(samples: samples, sampleRate: sampleRate, firstHostSeconds: firstHostSeconds)
    }
}
