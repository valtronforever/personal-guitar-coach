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
              (try MusicalTime.seconds(forTicks: exercise.durationTicks, bpm: bpm, pulseTicks: exercise.timeSignature.pulseTicks)) + Double(countInBars * exercise.timeSignature.beatsPerBar) * 60 / bpm <= 86390 else { throw MusicError.invalidTime }
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
    private struct HeldVoiceReference: Sendable {
        let span: ReferenceVoiceSpan
        let frequency: Double
    }
    private let heldVoices: [HeldVoiceReference]
    private let heldVoiceDivisor: Double
    private let strumOffsets: [[Int64]]
    private let vibratoReferences: [VibratoReference?]
    private let bendPoints: [[PitchBend.Point]]
    private let silentBeatTicks: Set<Int64>
    private let groupAccents: Set<Int>
    private var pulseTicks: Int64 { request.exercise.timeSignature.pulseTicks }
    private var firstTicks: Int64 { request.range.upperBound - request.startTick }
    private var cycleTicks: Int64 { request.range.upperBound - request.range.lowerBound }
    public var endFrame: Int64? { request.loops ? nil : frame(at: countInTicks + firstTicks) }
    public var practiceStartFrame: Int64 { frame(at: countInTicks) }

    public init(request: TransportRequest, sampleRate: Double) throws {
        guard sampleRate.isFinite, (8000...192000).contains(sampleRate) else { throw AudioBackendError.invalidFormat }
        self.request = request; self.sampleRate = sampleRate
        countInTicks = Int64(request.countInBars) * request.exercise.timeSignature.ticksPerBar
        silentBeatTicks = Set(request.exercise.metronome?.silentBeatTicks ?? [])
        groupAccents = request.exercise.accentedPulseIndices
        events = try request.exercise.resolvedEvents(instrument: request.tuning)
        let tuning = request.exercise.requiredTuning ?? request.tuning
        frequencies = try events.map { try $0.event.soundingFrequencies(in: tuning) }
        heldVoices = try request.exercise.referenceVoiceSpans.map { HeldVoiceReference(span: $0, frequency: try tuning.frequency(at: $0.position)) }
        heldVoiceDivisor = Double(max(1, request.exercise.events.map { $0.positions.count }.max() ?? 1))
        bendPoints = events.map { $0.event.bend?.points(durationTicks: $0.event.durationTicks) ?? [] }
        var waveforms: [Int: VibratoWaveform] = [:]
        vibratoReferences = try events.map { item in
            guard let vibrato = item.event.vibrato else { return nil }
            let waveform: VibratoWaveform
            if let existing = waveforms[vibrato.extentCents] { waveform = existing }
            else {
                waveform = try VibratoWaveform(extentCents: vibrato.extentCents)
                waveforms[vibrato.extentCents] = waveform
            }
            return try VibratoReference(vibrato: vibrato, waveform: waveform)
        }
        strumOffsets = events.map { item in
            guard let pattern = item.event.strum else { return [] }
            let strings = item.event.positions.map(\.string).sorted(by: pattern.direction == .down ? (>) : (<))
            return item.event.positions.map { position in
                Int64(strings.firstIndex(of: position.string)!) * pattern.spreadTicks / Int64(strings.count - 1)
            }
        }
        if request.mode == .preview && frequencies.joined().contains(where: { $0 >= sampleRate * 0.45 }) {
            throw AudioBackendError.invalidFormat
        }
    }

    // Internal callers only pass validated request-derived ticks within the 24-hour render bound.
    func frame(at tick: Int64) -> Int64 {
        Int64((Double(tick) * 60 * sampleRate / (request.bpm * Double(pulseTicks))).rounded())
    }
    private func ticks(at frame: Int64) -> Double {
        Double(frame) * request.bpm * Double(pulseTicks) / (60 * sampleRate)
    }

    public func position(at sample: Int64) -> TransportPosition {
        let sample = max(0, sample)
        if sample < practiceStartFrame {
            // Use the same half-sample boundary rule as scheduled clicks and musical position.
            let beat = Int((Double(sample) + 0.5) * request.bpm / (60 * sampleRate)) + 1
            return TransportPosition(tick: request.startTick, loopIndex: 0, countInBeat: beat, completed: false)
        }
        if let endFrame, sample >= endFrame {
            return TransportPosition(tick: request.range.upperBound, loopIndex: 0, countInBeat: nil, completed: true)
        }
        // Half a sample matches rounding of scheduled boundaries.
        let tick = Int64(floor((Double(sample) + 0.5) * request.bpm * Double(pulseTicks) / (60 * sampleRate))) - countInTicks
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
            let first = max(0, Int64(floor(ticks(at: startFrame) / Double(pulseTicks))) - 1)
            let last = min(countInTicks / pulseTicks, Int64(ceil(ticks(at: end) / Double(pulseTicks))) + 1)
            if first < last { for beat in first..<last {
                addClick(at: frame(at: beat * pulseTicks), accented: groupAccents.contains(Int(beat % Int64(request.exercise.timeSignature.beatsPerBar))),
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
                let sourceLow = sourceStart + max(0, Int64(floor(ticks(at: startFrame))) - epoch - pulseTicks)
                let sourceHigh = min(request.range.upperBound, sourceStart + Int64(ceil(ticks(at: end))) - epoch + pulseTicks)
                let firstBeat = max(sourceStart, sourceLow) / pulseTicks
                if sourceHigh > sourceStart { for beat in firstBeat...sourceHigh / pulseTicks {
                    let tick = beat * pulseTicks
                    if tick >= sourceStart && tick < request.range.upperBound && !silentBeatTicks.contains(tick) {
                        addClick(at: frame(at: epoch + tick - sourceStart), accented: groupAccents.contains(Int(beat % Int64(request.exercise.timeSignature.beatsPerBar))),
                                 stop: frame(at: segmentEnd), start: startFrame, output: &output)
                    }
                } }
            }
            guard request.mode == .preview, request.toneVolume > 0 else { continue }
            if !heldVoices.isEmpty {
                for voice in heldVoices {
                    let low = max(sourceStart, voice.span.startTick), high = min(request.range.upperBound, voice.span.endTick)
                    guard low < high else { continue }
                    let origin = frame(at: epoch + voice.span.startTick - sourceStart)
                    let offset = frame(at: epoch + high - sourceStart)
                    let a = max(startFrame, frame(at: epoch + low - sourceStart)), b = min(end, offset)
                    guard a < b else { continue }
                    let fade = max(1, min(sampleRate * 0.005, Double(offset - origin) / 2))
                    let gain = request.toneVolume * (voice.span.accented ? 0.3 : 0.2) / heldVoiceDivisor
                    for sample in a..<b {
                        let age = Double(sample - origin), remaining = Double(offset - sample - 1)
                        let envelope = min(1, min(age / fade, remaining / fade))
                        output[Int(sample - startFrame)] += Float(sin(2 * .pi * voice.frequency * age / sampleRate) * gain * envelope)
                    }
                }
                continue
            }
            for (index, item) in events.enumerated() where item.event.kind == .note {
                let low = max(sourceStart, item.event.startTick), high = min(request.range.upperBound, item.event.endTick)
                guard low < high else { continue }
                let onset = frame(at: epoch + low - sourceStart), offset = frame(at: epoch + high - sourceStart)
                let a = max(startFrame, onset), b = min(end, offset)
                guard a < b else { continue }
                let fade = max(1, min(sampleRate * 0.005, Double(offset - onset) / 2))
                let gain = request.toneVolume * (item.event.accented ? 0.3 : 0.2) / Double(max(1, frequencies[index].count))
                if item.event.mutedAttack != nil {
                    let attackOnset = frame(at: epoch + item.event.startTick - sourceStart)
                    for sample in a..<b {
                        output[Int(sample - startFrame)] += Float(Self.mutedSample(age: sample - attackOnset, sampleRate: sampleRate) * gain * min(1, Double(offset - sample - 1) / fade))
                    }
                    continue
                }
                if item.event.strum != nil {
                    for (voice, frequency) in frequencies[index].enumerated() {
                        let voiceOnset = frame(at: epoch + item.event.startTick + strumOffsets[index][voice] - sourceStart)
                        let voiceStart = max(a, voiceOnset)
                        guard voiceStart < b else { continue }
                        let voiceFade = max(1, min(sampleRate * 0.005, Double(offset - voiceOnset) / 2))
                        for sample in voiceStart..<b {
                            let age = Double(sample - voiceOnset), remaining = Double(offset - sample - 1)
                            let envelope = min(1, min(age / voiceFade, remaining / voiceFade))
                            output[Int(sample - startFrame)] += Float(sin(2 * .pi * frequency * age / sampleRate) * gain * envelope * (item.event.palmMuted ? exp(-age / (sampleRate * 0.09)) : 1))
                        }
                    }
                    continue
                }
                // Muted references keep their decay age when seeking into an existing note.
                let toneOnset = item.event.palmMuted || item.event.bend != nil || item.event.pitchTransition != nil || item.event.vibrato != nil || item.event.legatoChain != nil || item.event.harmonic != nil ? frame(at: epoch + item.event.startTick - sourceStart) : onset
                for sample in a..<b {
                    let age = Double(sample - toneOnset), remaining = Double(offset - sample - 1)
                    let envelope = min(1, min(age / fade, remaining / fade))
                    let phaseSeconds: Double
                    if item.event.bend != nil {
                        let secondsPerTick = 60 / (request.bpm * Double(pulseTicks))
                        phaseSeconds = PitchBend.integratedMultiplier(to: age / sampleRate / secondsPerTick, points: bendPoints[index]) * secondsPerTick
                    } else if let transition = item.event.pitchTransition {
                        let secondsPerTick = 60 / (request.bpm * Double(pulseTicks))
                        phaseSeconds = transition.integratedMultiplier(to: age / sampleRate / secondsPerTick, durationTicks: item.event.durationTicks) * secondsPerTick
                    } else if let chain = item.event.legatoChain {
                        let secondsPerTick = 60 / (request.bpm * Double(pulseTicks))
                        phaseSeconds = chain.integratedMultiplier(to: age / sampleRate / secondsPerTick, durationTicks: item.event.durationTicks) * secondsPerTick
                    } else if let reference = vibratoReferences[index] {
                        let secondsPerTick = 60 / (request.bpm * Double(pulseTicks))
                        phaseSeconds = reference.integratedMultiplier(to: age / sampleRate / secondsPerTick, durationTicks: item.event.durationTicks) * secondsPerTick
                    } else { phaseSeconds = age / sampleRate }
                    let tone = frequencies[index].reduce(0.0) { $0 + sin(2 * .pi * $1 * phaseSeconds) }
                    output[Int(sample - startFrame)] += Float(tone * gain * envelope * (item.event.palmMuted ? exp(-age / (sampleRate * 0.09)) : 1))
                }
            }
        }
        return output
    }

    /// Stateless short noise burst. Sample-age addressing preserves chunks/seeks/loops.
    private static func mutedSample(age: Int64, sampleRate: Double) -> Double {
        guard age >= 0 else { return 0 }
        let seconds = Double(age) / sampleRate
        guard seconds < 0.08 else { return 0 }
        var bits = UInt64(age) &+ 0x9E3779B97F4A7C15
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        bits ^= bits >> 31
        let noise = Double(bits & 0xFFFF) / 32767.5 - 1
        let envelope = min(1, seconds / 0.001) * exp(-seconds / 0.018) * min(1, (0.08 - seconds) / 0.005)
        return noise * envelope
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

extension TransportPlan {
    /// Display-only continuous score coordinate. Count-in occupies ticks before the selected start.
    /// Unlike `position`, this retains sub-tick precision and exposes movement during the count-in.
    public func audibleTimelineTick(renderedFrames: Int64, outputLatencySeconds: Double, visualAlignmentSeconds: Double = 0) -> Double {
        let delay = outputLatencySeconds.isFinite ? min(10, max(0, outputLatencySeconds)) : 0
        let alignment = visualAlignmentSeconds.isFinite ? min(1, max(-1, visualAlignmentSeconds)) : 0
        let frames = max(0, renderedFrames - Int64(((delay + alignment) * sampleRate).rounded()))
        let elapsed = Double(frames) * request.bpm * Double(pulseTicks) / (60 * sampleRate)
        let offset = elapsed - Double(countInTicks)
        if offset < Double(firstTicks) { return Double(request.startTick) + offset }
        if request.loops {
            return Double(request.range.lowerBound) + (offset - Double(firstTicks)).truncatingRemainder(dividingBy: Double(cycleTicks))
        }
        return Double(request.range.upperBound)
    }

    /// Display only. Only the separately measured tap alignment may be supplied; never the total guitar compensation.
    public func audiblePosition(renderedFrames: Int64, outputLatencySeconds: Double, visualAlignmentSeconds: Double = 0) -> TransportPosition {
        let delay = outputLatencySeconds.isFinite ? min(10, max(0, outputLatencySeconds)) : 0
        let alignment = visualAlignmentSeconds.isFinite ? min(1, max(-1, visualAlignmentSeconds)) : 0
        return position(at: max(0, renderedFrames - Int64(((delay + alignment) * sampleRate).rounded())))
    }
}
