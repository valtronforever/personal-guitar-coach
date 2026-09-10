import Foundation

public enum CalibrationError: Error, Equatable, Sendable { case invalidRoute, invalidProfile, invalidTimestamp, insufficientEvidence }

public struct CalibrationEndpoint: Codable, Hashable, Sendable {
    public let uid: String
    public let channel: Int
    public let sampleRate: Double
    public let bufferFrames: UInt32
    public let deviceLatencyFrames: UInt32?
    public let streamLatencyFrames: UInt32?
    public let safetyOffsetFrames: UInt32?

    public init(uid: String, channel: Int, sampleRate: Double, bufferFrames: UInt32,
                deviceLatencyFrames: UInt32? = nil, streamLatencyFrames: UInt32? = nil, safetyOffsetFrames: UInt32? = nil) throws {
        guard !uid.isEmpty, uid.utf8.count <= 4096, (1...256).contains(channel), sampleRate.isFinite,
              (8000...192000).contains(sampleRate), (1...8192).contains(bufferFrames),
              [deviceLatencyFrames, streamLatencyFrames, safetyOffsetFrames].compactMap({ $0 }).allSatisfy({ Double($0) <= sampleRate * 5 }) else {
            throw CalibrationError.invalidRoute
        }
        self.uid = uid; self.channel = channel; self.sampleRate = sampleRate; self.bufferFrames = bufferFrames
        self.deviceLatencyFrames = deviceLatencyFrames; self.streamLatencyFrames = streamLatencyFrames; self.safetyOffsetFrames = safetyOffsetFrames
    }
    /// Hardware latency only. A buffer/safety offset is not applied again to the HAL data timestamp.
    public var hardwareLatencySeconds: Double? {
        guard let deviceLatencyFrames, let streamLatencyFrames else { return nil }
        return (Double(deviceLatencyFrames) + Double(streamLatencyFrames)) / sampleRate
    }
    private enum CodingKeys: String, CodingKey { case uid, channel, sampleRate, bufferFrames, deviceLatencyFrames, streamLatencyFrames, safetyOffsetFrames }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(uid: v.decode(String.self, forKey: .uid), channel: v.decode(Int.self, forKey: .channel),
            sampleRate: v.decode(Double.self, forKey: .sampleRate), bufferFrames: v.decode(UInt32.self, forKey: .bufferFrames),
            deviceLatencyFrames: v.decodeIfPresent(UInt32.self, forKey: .deviceLatencyFrames),
            streamLatencyFrames: v.decodeIfPresent(UInt32.self, forKey: .streamLatencyFrames),
            safetyOffsetFrames: v.decodeIfPresent(UInt32.self, forKey: .safetyOffsetFrames))
    }
}

public struct CalibrationRoute: Codable, Hashable, Sendable {
    public static let normalizationVersion = "hal-input-minus-hardware/player-output-plus-hardware-1"
    public let input: CalibrationEndpoint
    public let output: CalibrationEndpoint
    public let backendVersion: String
    public init(input: CalibrationEndpoint, output: CalibrationEndpoint, backendVersion: String) throws {
        guard !backendVersion.isEmpty, backendVersion.utf8.count <= 4096 else { throw CalibrationError.invalidRoute }
        self.input = input; self.output = output; self.backendVersion = backendVersion
    }
    public var usesSeparateDevices: Bool { input.uid != output.uid }
    public var signature: String {
        // Validated finite values make this encoding total. Base64 avoids separator/UID ambiguity.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return Self.normalizationVersion + ":" + (try! encoder.encode(self)).base64EncodedString()
    }
    public func observedTime(inputHostSeconds: Double) throws -> Double {
        guard inputHostSeconds.isFinite, inputHostSeconds >= 0 else { throw CalibrationError.invalidTimestamp }
        return inputHostSeconds - (input.hardwareLatencySeconds ?? 0)
    }
    public func expectedTime(renderEpochSeconds: Double, sampleFrame: Int64) throws -> Double {
        guard renderEpochSeconds.isFinite, renderEpochSeconds >= 0, sampleFrame >= 0 else { throw CalibrationError.invalidTimestamp }
        return renderEpochSeconds + Double(sampleFrame) / output.sampleRate + (output.hardwareLatencySeconds ?? 0)
    }
    private enum CodingKeys: String, CodingKey { case input, output, backendVersion }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(input: v.decode(CalibrationEndpoint.self, forKey: .input), output: v.decode(CalibrationEndpoint.self, forKey: .output),
                      backendVersion: v.decode(String.self, forKey: .backendVersion))
    }
}

public struct CalibrationEvidence: Codable, Equatable, Sendable {
    public let algorithmVersion: String
    public let matchedPulses: Int
    public let missedPulses: Int
    public let extraPulses: Int
    public let durationSeconds: Double
    public let residualP95Seconds: Double
    public let driftSeconds: Double
    public init(algorithmVersion: String, matchedPulses: Int, missedPulses: Int, extraPulses: Int,
                durationSeconds: Double, residualP95Seconds: Double, driftSeconds: Double) throws {
        guard !algorithmVersion.isEmpty, algorithmVersion.utf8.count <= 256,
              (8...512).contains(matchedPulses), (0...512).contains(missedPulses), (0...512).contains(extraPulses),
              Double(missedPulses + extraPulses) <= Double(matchedPulses) * 0.2,
              durationSeconds.isFinite, (10...1800).contains(durationSeconds), residualP95Seconds.isFinite,
              (0...0.5).contains(residualP95Seconds), driftSeconds.isFinite, abs(driftSeconds) <= 0.5 else {
            throw CalibrationError.insufficientEvidence
        }
        self.algorithmVersion = algorithmVersion; self.matchedPulses = matchedPulses; self.missedPulses = missedPulses; self.extraPulses = extraPulses
        self.durationSeconds = durationSeconds; self.residualP95Seconds = residualP95Seconds; self.driftSeconds = driftSeconds
    }
    private enum CodingKeys: String, CodingKey { case algorithmVersion, matchedPulses, missedPulses, extraPulses, durationSeconds, residualP95Seconds, driftSeconds }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(algorithmVersion: v.decode(String.self, forKey: .algorithmVersion), matchedPulses: v.decode(Int.self, forKey: .matchedPulses),
            missedPulses: v.decode(Int.self, forKey: .missedPulses), extraPulses: v.decode(Int.self, forKey: .extraPulses),
            durationSeconds: v.decode(Double.self, forKey: .durationSeconds), residualP95Seconds: v.decode(Double.self, forKey: .residualP95Seconds),
            driftSeconds: v.decode(Double.self, forKey: .driftSeconds))
    }
}

public enum CalibrationMethod: String, Codable, Sendable { case estimated, manual, measured }
public enum RhythmCapability: String, Sendable { case available, routeMismatch, unmeasured, durationUnverified, missingClock, uncertain }

public struct CalibrationProfile: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let revision: Int
    public let route: CalibrationRoute
    public let createdAt: Date
    public let method: CalibrationMethod
    public let residualOffsetSeconds: Double
    public let uncertaintySeconds: Double
    public let evidence: CalibrationEvidence?

    public init(id: UUID = UUID(), revision: Int = 1, route: CalibrationRoute, createdAt: Date = Date(), method: CalibrationMethod,
                residualOffsetSeconds: Double, uncertaintySeconds: Double, evidence: CalibrationEvidence? = nil) throws {
        guard revision > 0, createdAt.timeIntervalSinceReferenceDate.isFinite, residualOffsetSeconds.isFinite,
              (-1...1).contains(residualOffsetSeconds), uncertaintySeconds.isFinite, (0...5).contains(uncertaintySeconds),
              (method == .measured) == (evidence != nil) else { throw CalibrationError.invalidProfile }
        if let evidence {
            // Keep a 10-ms calibration-detector allowance in addition to measured residual jitter.
            guard uncertaintySeconds >= evidence.residualP95Seconds + 0.01 else { throw CalibrationError.invalidProfile }
        }
        self.id = id; self.revision = revision; self.route = route; self.createdAt = createdAt; self.method = method
        self.residualOffsetSeconds = residualOffsetSeconds; self.uncertaintySeconds = uncertaintySeconds; self.evidence = evidence
    }
    public func timingError(observedNormalizedTime: Double, expectedNormalizedTime: Double) throws -> Double {
        guard observedNormalizedTime.isFinite, expectedNormalizedTime.isFinite else { throw CalibrationError.invalidTimestamp }
        let result = observedNormalizedTime - expectedNormalizedTime - residualOffsetSeconds
        guard result.isFinite else { throw CalibrationError.invalidTimestamp }
        return result
    }
    public func rhythmCapability(route current: CalibrationRoute, toleranceSeconds: Double, durationSeconds: Double,
                                 clockDriftSeconds: Double?, onsetUncertaintySeconds: Double = 0.03) -> RhythmCapability {
        guard current == route else { return .routeMismatch }
        guard method == .measured, let evidence else { return .unmeasured }
        guard toleranceSeconds.isFinite, toleranceSeconds > 0, durationSeconds.isFinite, (0...86400).contains(durationSeconds),
              onsetUncertaintySeconds.isFinite, onsetUncertaintySeconds >= 0 else { return .uncertain }
        if current.usesSeparateDevices && durationSeconds > evidence.durationSeconds { return .durationUnverified }
        guard let clockDriftSeconds, clockDriftSeconds.isFinite else { return .missingClock }
        let uncertainty = uncertaintySeconds + onsetUncertaintySeconds + abs(clockDriftSeconds)
        return uncertainty <= toleranceSeconds / 2 ? .available : .uncertain
    }
    private enum CodingKeys: String, CodingKey { case id, revision, route, createdAt, method, residualOffsetSeconds, uncertaintySeconds, evidence }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(UUID.self, forKey: .id), revision: v.decode(Int.self, forKey: .revision),
            route: v.decode(CalibrationRoute.self, forKey: .route), createdAt: v.decode(Date.self, forKey: .createdAt),
            method: v.decode(CalibrationMethod.self, forKey: .method), residualOffsetSeconds: v.decode(Double.self, forKey: .residualOffsetSeconds),
            uncertaintySeconds: v.decode(Double.self, forKey: .uncertaintySeconds), evidence: v.decodeIfPresent(CalibrationEvidence.self, forKey: .evidence))
    }
}
