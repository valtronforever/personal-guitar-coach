import Foundation
import Domain

public enum LessonAdaptationPolicy: String, Codable, Sendable { case fretPattern, transposeIntervals }

/// Tuning adaptation determines pitches; material policies independently permit relocation.
public struct LessonAdaptationDefinition: Codable, Equatable, Sendable {
    public let policy: LessonAdaptationPolicy
    /// Author reference for transposition. String 1 preserves the existing Standard/Drop key behavior;
    /// string 6 lets a bass-rooted riff follow the instrument's lowest open string.
    public let anchorString: Int
    public init(policy: LessonAdaptationPolicy) { self.policy = policy; anchorString = 1 }
    public init(policy: LessonAdaptationPolicy, anchorString: Int) throws {
        guard (1...6).contains(anchorString), policy == .transposeIntervals || anchorString == 1 else {
            throw LessonAdaptationError.invalidTemplate
        }
        self.policy = policy; self.anchorString = anchorString
    }
    func transposition(from source: TuningProfile, to target: TuningProfile) -> Int {
        guard policy == .transposeIntervals else { return 0 }
        return target.strings[anchorString - 1].openPitch.midi - source.strings[anchorString - 1].openPitch.midi
    }
    private enum CodingKeys: String, CodingKey { case policy, anchorString }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(policy: values.decode(LessonAdaptationPolicy.self, forKey: .policy),
                      anchorString: values.decodeIfPresent(Int.self, forKey: .anchorString) ?? 1)
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(policy, forKey: .policy)
        if anchorString != 1 { try values.encode(anchorString, forKey: .anchorString) }
    }
}
public enum LessonAdaptationError: Error { case unplayable, invalidTemplate }
