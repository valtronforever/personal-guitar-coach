import Foundation

/// Complete authored conditions for one performed activity. Reading never consults live lesson files.
public struct PracticeActivityReference: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let activityID: String
    public let materialID: String
    public let entryID: String
    public let choice: PositionChoice
    public let positioning: PositioningPolicy
    public let requiredChoice: PositionChoice?
    public let resolverVersion: String
    public let source: ExerciseSourceMapping
    public let lessonTitles: [String: String]
    public let activityTitles: [String: String]
    public let selfConfirmation: PositionSelfConfirmation?
    public init(activityID: String, materialID: String, entryID: String, choice: PositionChoice,
                positioning: PositioningPolicy, requiredChoice: PositionChoice?, resolverVersion: String,
                source: ExerciseSourceMapping, lessonTitles: [String: String], activityTitles: [String: String],
                selfConfirmation: PositionSelfConfirmation? = nil) throws {
        schemaVersion = 1; self.activityID = activityID; self.materialID = materialID; self.entryID = entryID
        self.choice = choice; self.positioning = positioning; self.requiredChoice = requiredChoice; self.resolverVersion = resolverVersion
        self.source = source; self.lessonTitles = lessonTitles; self.activityTitles = activityTitles; self.selfConfirmation = selfConfirmation
        try validate()
    }
    public func validate() throws {
        func validID(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 256 }
        guard schemaVersion == 1, [activityID, materialID, entryID, resolverVersion, source.exerciseID].allSatisfy(validID),
              source.exerciseVersion > 0, source.startTick >= 0, !source.eventIDs.isEmpty, source.eventIDs.count <= 4096,
              source.eventIDs.allSatisfy(validID), Set(source.eventIDs).count == source.eventIDs.count,
              Set(lessonTitles.keys) == ["en","uk"], Set(activityTitles.keys) == ["en","uk"],
              (Array(lessonTitles.values) + Array(activityTitles.values)).allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 4096 }),
              requiredChoice == nil || requiredChoice == choice else { throw PracticeError.invalidEvidence }
        try positioning.validate()
        guard positioning.permits(choice), selfConfirmation == nil || selfConfirmation?.choice == choice else { throw PracticeError.invalidEvidence }
    }
    public func validate(exercise: Exercise) throws {
        try validate()
        guard source.exerciseID == exercise.id, source.exerciseVersion == exercise.version, source.eventIDs == exercise.events.map(\.id),
              !source.startTick.addingReportingOverflow(exercise.durationTicks).overflow else { throw PracticeError.invalidEvidence }
        if let confirmation = selfConfirmation, let tuning = exercise.requiredTuning {
            guard confirmation.tuning.hasSamePitches(as: tuning) else { throw PracticeError.invalidEvidence }
        }
        if let region = try positioning.region(for: choice) {
            guard exercise.events.flatMap(\.positions).allSatisfy({ region.contains($0, maximumFret: 24) }) else { throw PracticeError.invalidEvidence }
        }
    }
    public func hasSameConditions(as other: Self) -> Bool {
        activityID == other.activityID && materialID == other.materialID && entryID == other.entryID && choice == other.choice
            && positioning == other.positioning && requiredChoice == other.requiredChoice && resolverVersion == other.resolverVersion && source == other.source
    }
    public func withoutSelfConfirmation() throws -> Self {
        try Self(activityID: activityID, materialID: materialID, entryID: entryID, choice: choice, positioning: positioning,
            requiredChoice: requiredChoice, resolverVersion: resolverVersion, source: source, lessonTitles: lessonTitles, activityTitles: activityTitles)
    }
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, activityID, materialID, entryID, choice, positioning, requiredChoice, resolverVersion, source, lessonTitles, activityTitles, selfConfirmation
    }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        guard try v.decode(Int.self, forKey: .schemaVersion) == 1 else { throw PracticeError.invalidEvidence }
        try self.init(activityID: v.decode(String.self, forKey: .activityID), materialID: v.decode(String.self, forKey: .materialID),
            entryID: v.decode(String.self, forKey: .entryID), choice: v.decode(PositionChoice.self, forKey: .choice),
            positioning: v.decode(PositioningPolicy.self, forKey: .positioning), requiredChoice: v.decodeIfPresent(PositionChoice.self, forKey: .requiredChoice),
            resolverVersion: v.decode(String.self, forKey: .resolverVersion), source: v.decode(ExerciseSourceMapping.self, forKey: .source),
            lessonTitles: v.decode([String: String].self, forKey: .lessonTitles), activityTitles: v.decode([String: String].self, forKey: .activityTitles),
            selfConfirmation: v.decodeIfPresent(PositionSelfConfirmation.self, forKey: .selfConfirmation))
    }
}
