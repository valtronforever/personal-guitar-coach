import Foundation

public enum TimeSignature: String, Codable, CaseIterable, Sendable {
    case threeFour = "3/4", fourFour = "4/4"
    public var beatsPerBar: Int { self == .threeFour ? 3 : 4 }
    public var ticksPerBar: Int64 { Int64(beatsPerBar) * MusicalTime.ppq }
}

public enum MusicalTime {
    public static let ppq: Int64 = 960
    public static let tempoRange = 40.0...200.0

    public static func validateTempo(_ bpm: Double) throws {
        guard bpm.isFinite, tempoRange.contains(bpm) else { throw MusicError.invalidTempo }
    }

    public static func seconds(forTicks ticks: Int64, bpm: Double) throws -> Double {
        try validateTempo(bpm)
        guard ticks >= 0 else { throw MusicError.invalidTime }
        return Double(ticks) / Double(ppq) * 60 / bpm
    }

    public static func ticks(forSeconds seconds: Double, bpm: Double) throws -> Int64 {
        try validateTempo(bpm)
        guard seconds.isFinite, seconds >= 0 else { throw MusicError.invalidTime }
        let ticks = (seconds * bpm / 60 * Double(ppq)).rounded()
        guard ticks.isFinite, ticks >= 0, ticks < Double(Int64.max) else { throw MusicError.invalidTime }
        return Int64(ticks)
    }
}
