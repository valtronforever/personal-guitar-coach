import Foundation

/// Three eighth-note slots in one quarter beat (3:2). A two-slot note permits a
/// written quarter + eighth shuffle pair; sounding time remains in event ticks.
public struct TripletGroup: Hashable, Codable, Identifiable, Sendable {
    public let id: String
    public let eventIDs: [String]
    public static let slotTicks: Int64 = 320
    public init(id: String, eventIDs: [String]) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (2...3).contains(eventIDs.count), Set(eventIDs).count == eventIDs.count,
              eventIDs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw MusicError.invalidEvent }
        self.id = id; self.eventIDs = eventIDs
    }
    private enum CodingKeys: String, CodingKey { case id, eventIDs }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(String.self, forKey: .id), eventIDs: values.decode([String].self, forKey: .eventIDs))
    }
    static func validate(_ groups: [TripletGroup], events: [MusicalEvent]) throws {
        guard !groups.isEmpty else { return }
        guard Set(groups.map(\.id)).count == groups.count else { throw MusicError.duplicateIdentifier }
        let indexed = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        var seen: Set<String> = []
        for group in groups {
            let members = try group.eventIDs.map { id -> MusicalEvent in
                guard let event = indexed[id], seen.insert(id).inserted else { throw MusicError.invalidEvent }
                return event
            }
            guard let first = members.first, let last = members.last,
                  first.startTick % MusicalTime.ppq == 0,
                  last.endTick - first.startTick == MusicalTime.ppq,
                  members.allSatisfy({ [slotTicks, slotTicks * 2].contains($0.durationTicks) }),
                  zip(members, members.dropFirst()).allSatisfy({ $0.endTick == $1.startTick }) else { throw MusicError.invalidTime }
        }
    }
}
