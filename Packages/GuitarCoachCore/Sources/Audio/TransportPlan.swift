import Foundation
import Domain

public enum TransportMode: String, Sendable { case preview, practice, calibration }

/// Immutable segment. A seek, pause/resume or tempo change creates another segment and epoch.
public struct TransportRequest: Sendable, Equatable {
    public let id: UUID
    public let exercise: Exercise
    public let tuning: TuningProfile
    public let bpm: Double
    public let range: Range<Int64>
    public let startTick: Int64
    public let countInBars: Int
    public let loops: Bool
    public let mode: TransportMode
    public let clickEnabled: Bool
    public let accent: Bool
    public let clickVolume: Double
    public let toneVolume: Double

    public init(exercise: Exercise, tuning: TuningProfile, bpm: Double, range: Range<Int64>? = nil,
                startTick: Int64? = nil, countInBars: Int = 1, loops: Bool = false, mode: TransportMode = .preview,
                clickEnabled: Bool = true, accent: Bool = true, clickVolume: Double = 0.5, toneVolume: Double = 0.5) throws {
        try MusicalTime.validateTempo(bpm)
        let range = range ?? 0..<exercise.durationTicks, start = startTick ?? range.lowerBound
        guard range.lowerBound >= 0, range.upperBound <= exercise.durationTicks,
              range.upperBound - range.lowerBound >= 240, range.contains(start),
              (0...4).contains(countInBars), clickVolume.isFinite, (0...1).contains(clickVolume),
              toneVolume.isFinite, (0...1).contains(toneVolume), exercise.events.count <= 4096,
              (try MusicalTime.seconds(forTicks: exercise.durationTicks, bpm: bpm)) + Double(countInBars * exercise.timeSignature.beatsPerBar) * 60 / bpm <= 86390 else { throw MusicError.invalidTime }
        id = UUID(); self.exercise = exercise; self.tuning = tuning; self.bpm = bpm; self.range = range
        self.startTick = start; self.countInBars = countInBars; self.loops = loops; self.mode = mode
        self.clickEnabled = clickEnabled; self.accent = accent; self.clickVolume = clickVolume; self.toneVolume = toneVolume
    }
}

public struct TransportPosition: Equatable, Sendable {
    public let tick: Int64
    public let loopIndex: Int64
    public let countInBeat: Int?
    public let completed: Bool
}

/// Pure sample schedule and renderer shared by offline tests and AVAudioPlayerNode output.
/// Every boundary is rounded from an absolute tick, never accumulated rounded beat/loop lengths.
public struct TransportPlan: Sendable {
    public let request: TransportRequest
    public let sampleRate: Double
    public let countInTicks: Int64
    private let events: [ResolvedEvent]
    private let frequencies: [[Double]]
    private var firstTicks: Int64 { request.range.upperBound - request.startTick }
    private var cycleTicks: Int64 { request.range.upperBound - request.range.lowerBound }
    public var endFrame: Int64? { request.loops ? nil : frame(at: countInTicks + firstTicks) }
    public var practiceStartFrame: Int64 { frame(at: countInTicks) }

    public init(request: TransportRequest, sampleRate: Double) throws {
        guard sampleRate.isFinite, (8000...192000).contains(sampleRate) else { throw AudioBackendError.invalidFormat }
        self.request = request; self.sampleRate = sampleRate
        countInTicks = Int64(request.countInBars) * request.exercise.timeSignature.ticksPerBar
        events = try request.exercise.resolvedEvents(instrument: request.tuning)
        let reference = (request.exercise.requiredTuning ?? request.tuning).referenceA4
        frequencies = try events.map { try $0.pitches.map { try $0.frequency(referenceA4: reference) } }
        if request.mode == .preview && frequencies.joined().contains(where: { $0 >= sampleRate * 0.45 }) {
            throw AudioBackendError.invalidFormat
        }
    }

    // Internal callers only pass validated request-derived ticks within the 24-hour render bound.
    func frame(at tick: Int64) -> Int64 {
        Int64((Double(tick) * 60 * sampleRate / (request.bpm * Double(MusicalTime.ppq))).rounded())
    }
    private func ticks(at frame: Int64) -> Double {
        Double(frame) * request.bpm * Double(MusicalTime.ppq) / (60 * sampleRate)
    }

    public func position(at sample: Int64) -> TransportPosition {
        let sample = max(0, sample)
        if sample < practiceStartFrame {
            let beat = Int(ticks(at: sample) / Double(MusicalTime.ppq)) + 1
            return TransportPosition(tick: request.startTick, loopIndex: 0, countInBeat: beat, completed: false)
        }
        if let endFrame, sample >= endFrame {
            return TransportPosition(tick: request.range.upperBound, loopIndex: 0, countInBeat: nil, completed: true)
        }
        // Half a sample matches rounding of scheduled boundaries.
        let tick = Int64(floor((Double(sample) + 0.5) * request.bpm * Double(MusicalTime.ppq) / (60 * sampleRate))) - countInTicks
        if tick < firstTicks {
            return TransportPosition(tick: min(request.range.upperBound - 1, request.startTick + max(0, tick)), loopIndex: 0, countInBeat: nil, completed: false)
        }
        let later = max(0, tick - firstTicks)
        return TransportPosition(tick: request.range.lowerBound + later % cycleTicks, loopIndex: 1 + later / cycleTicks, countInBeat: nil, completed: false)
    }

    /// Bounded worker call. Output samples have no dependence on chunk boundaries or UI scheduling.
    public func render(startFrame: Int64, count: Int) throws -> [Float] {
        guard startFrame >= 0, (1...48000).contains(count),
              startFrame <= Int64(sampleRate * 86400) - Int64(count) else { throw MusicError.invalidTime }
        var output = [Float](repeating: 0, count: count)
        let end = startFrame + Int64(count)
        if request.clickEnabled && request.mode != .calibration && startFrame < practiceStartFrame {
            let first = max(0, Int64(floor(ticks(at: startFrame) / 960)) - 1)
            let last = min(countInTicks / 960, Int64(ceil(ticks(at: end) / 960)) + 1)
            if first < last { for beat in first..<last {
                addClick(at: frame(at: beat * 960), accented: beat % Int64(request.exercise.timeSignature.beatsPerBar) == 0,
                         start: startFrame, output: &output)
            } }
        }
        let firstLoop = position(at: startFrame).loopIndex
        let lastLoop = position(at: end - 1).loopIndex
        for loop in firstLoop...lastLoop {
            if !request.loops && loop > 0 { break }
            let sourceStart = loop == 0 ? request.startTick : request.range.lowerBound
            let epoch = countInTicks + (loop == 0 ? 0 : firstTicks + (loop - 1) * cycleTicks)
            let segmentEnd = epoch + request.range.upperBound - sourceStart
            if frame(at: epoch) >= end || frame(at: segmentEnd) <= startFrame { continue }
            if request.mode == .calibration {
                if request.clickEnabled {
                    for item in events where item.event.kind == .note && item.event.startTick >= sourceStart && item.event.startTick < request.range.upperBound {
                        addClick(at: frame(at: epoch + item.event.startTick - sourceStart), accented: false, stop: frame(at: segmentEnd), start: startFrame, output: &output)
                    }
                }
                continue
            }
            if request.clickEnabled {
                let sourceLow = sourceStart + max(0, Int64(floor(ticks(at: startFrame))) - epoch - 960)
                let sourceHigh = min(request.range.upperBound, sourceStart + Int64(ceil(ticks(at: end))) - epoch + 960)
                let firstBeat = max(sourceStart, sourceLow) / 960
                if sourceHigh > sourceStart { for beat in firstBeat...sourceHigh / 960 {
                    let tick = beat * 960
                    if tick >= sourceStart && tick < request.range.upperBound {
                        addClick(at: frame(at: epoch + tick - sourceStart), accented: beat % Int64(request.exercise.timeSignature.beatsPerBar) == 0,
                                 stop: frame(at: segmentEnd), start: startFrame, output: &output)
                    }
                } }
            }
            guard request.mode == .preview, request.toneVolume > 0 else { continue }
            for (index, item) in events.enumerated() where item.event.kind == .note {
                let low = max(sourceStart, item.event.startTick), high = min(request.range.upperBound, item.event.endTick)
                guard low < high else { continue }
                let onset = frame(at: epoch + low - sourceStart), offset = frame(at: epoch + high - sourceStart)
                let a = max(startFrame, onset), b = min(end, offset)
                guard a < b else { continue }
                let fade = max(1, min(sampleRate * 0.005, Double(offset - onset) / 2))
                let gain = request.toneVolume * 0.2 / Double(max(1, frequencies[index].count))
                for sample in a..<b {
                    let age = Double(sample - onset), remaining = Double(offset - sample - 1)
                    let envelope = min(1, min(age / fade, remaining / fade))
                    let tone = frequencies[index].reduce(0.0) { $0 + sin(2 * .pi * $1 * age / sampleRate) }
                    output[Int(sample - startFrame)] += Float(tone * gain * envelope)
                }
            }
        }
        return output
    }

    private func addClick(at onset: Int64, accented: Bool, stop: Int64 = .max, start: Int64, output: inout [Float]) {
        let duration = Int64(sampleRate * 0.012), end = min(stop, onset + duration)
        let a = max(start, onset), b = min(start + Int64(output.count), end)
        guard a < b else { return }
        let frequency = request.accent && accented ? 1800.0 : 1200.0
        for sample in a..<b {
            let age = Double(sample - onset)
            output[Int(sample - start)] += Float(sin(2 * .pi * frequency * age / sampleRate) * (1 - age / Double(duration)) * request.clickVolume * 0.25)
        }
    }
}
