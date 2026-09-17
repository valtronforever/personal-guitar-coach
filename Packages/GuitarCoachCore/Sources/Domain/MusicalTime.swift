import Foundation

public enum TimeSignature: String, Codable, CaseIterable, Sendable {
    case threeFour = "3/4", fourFour = "4/4", sixEight = "6/8", twelveEight = "12/8", fiveFour = "5/4", sevenEight = "7/8"
    public var numerator: Int {
        switch self { case .threeFour: 3; case .fourFour: 4; case .sixEight: 6; case .twelveEight: 12; case .fiveFour: 5; case .sevenEight: 7 }
    }
    public var denominator: Int { [.sixEight, .twelveEight, .sevenEight].contains(self) ? 8 : 4 }
    /// BPM always counts this pulse. Old meters retain quarter-note BPM.
    public var pulseTicks: Int64 {
        switch self { case .sixEight, .twelveEight: 1440; case .sevenEight: 480; default: 960 }
    }
    public var ticksPerBar: Int64 { Int64(numerator) * MusicalTime.ppq * 4 / Int64(denominator) }
    public var beatsPerBar: Int { Int(ticksPerBar / pulseTicks) }
    public var tempoUnitKey: String { pulseTicks == 1440 ? "tempo.dottedQuarter" : pulseTicks == 480 ? "tempo.eighth" : "tempo.quarter" }
    public var defaultGrouping: [Int] {
        switch self { case .fiveFour: [3,2]; case .sevenEight: [2,2,3]; default: Array(repeating: 1, count: beatsPerBar) }
    }
    public func secondsPerTick(bpm: Double) -> Double { 60 / bpm / Double(pulseTicks) }
}

public enum MusicalTime {
    public static let ppq: Int64 = 960
    public static let tempoRange = 40.0...200.0

    public static func validateTempo(_ bpm: Double) throws {
        guard bpm.isFinite, tempoRange.contains(bpm) else { throw MusicError.invalidTempo }
    }

    public static func seconds(forTicks ticks: Int64, bpm: Double, pulseTicks: Int64 = ppq) throws -> Double {
        try validateTempo(bpm)
        guard ticks >= 0, [480,960,1440].contains(pulseTicks) else { throw MusicError.invalidTime }
        return Double(ticks) / Double(pulseTicks) * 60 / bpm
    }

    public static func ticks(forSeconds seconds: Double, bpm: Double, pulseTicks: Int64 = ppq) throws -> Int64 {
        try validateTempo(bpm)
        guard seconds.isFinite, seconds >= 0, [480,960,1440].contains(pulseTicks) else { throw MusicError.invalidTime }
        let ticks = (seconds * bpm / 60 * Double(pulseTicks)).rounded()
        guard ticks.isFinite, ticks >= 0, ticks < Double(Int64.max) else { throw MusicError.invalidTime }
        return Int64(ticks)
    }
}
