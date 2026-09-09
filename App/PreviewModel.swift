import SwiftUI
import Domain
import Audio

@MainActor @Observable
final class PreviewModel {
    private var generation = 0
    var bpm = 60.0
    var countInBars = 1
    var loops = false
    var clickEnabled = true
    var accent = true
    var clickVolume = 0.5
    var toneVolume = 0.5
    var firstBar = 1
    var lastBar = 1
    private(set) var exercise: Exercise?
    private(set) var requestID: UUID?
    private(set) var cursorTick: Int64?
    private(set) var resumeTick: Int64?
    private(set) var countInBeat: Int?
    private(set) var isBusy = false
    private(set) var errorKey: String?
    var barCount: Int { max(1, Int(((exercise?.durationTicks ?? 1) - 1) / (exercise?.timeSignature.ticksPerBar ?? 3840)) + 1) }
    var range: Range<Int64> {
        let ticks = exercise?.timeSignature.ticksPerBar ?? 3840
        let lower = Int64(max(1, firstBar) - 1) * ticks
        let upper = min(exercise?.durationTicks ?? ticks, Int64(max(firstBar, lastBar)) * ticks)
        return lower..<max(lower, upper)
    }

    func configure(_ exercise: Exercise?, audio: AudioSessionStore) async {
        guard self.exercise != exercise else { return }
        self.exercise = exercise; bpm = exercise?.defaultBPM ?? 60; firstBar = 1; lastBar = barCount
        errorKey = nil
        await stop(audio: audio)
    }
    func start(tuning: TuningProfile, audio: AudioSessionStore) async {
        guard !isBusy, let exercise else { return }
        generation += 1; let ticket = generation
        isBusy = true; errorKey = nil
        defer { if generation == ticket { isBusy = false } }
        if let requestID { await audio.stopTransport(id: requestID) }
        guard generation == ticket else { return }
        do {
            let next = try TransportRequest(exercise: exercise, tuning: tuning, bpm: bpm, range: range,
                startTick: resumeTick.flatMap { range.contains($0) ? $0 : nil }, countInBars: countInBars, loops: loops,
                clickEnabled: clickEnabled, accent: accent, clickVolume: clickVolume, toneVolume: toneVolume)
            requestID = next.id; cursorTick = nil; countInBeat = nil
            await audio.startTransport(next)
            if generation == ticket { isBusy = false; update(audio.state) }
        } catch { if generation == ticket { requestID = nil; errorKey = "playback.invalid" } }
    }
    func update(_ state: AudioCoordinatorSnapshot?) {
        guard !isBusy, let requestID else { return }
        if let value = state?.transport, value.requestID == requestID {
            switch value.phase {
            case .playing where state?.transportRequestID == requestID:
                cursorTick = value.position.tick; countInBeat = value.position.countInBeat
                return
            case .completed: resumeTick = nil
            default: break
            }
        } else if state?.transportRequestID == requestID { return }
        self.requestID = nil; cursorTick = nil; countInBeat = nil
    }
    func stop(audio: AudioSessionStore, pause: Bool = false, seekTick: Int64? = nil) async {
        generation += 1; let ticket = generation
        isBusy = true
        let previous = requestID
        resumeTick = seekTick ?? (pause ? cursorTick : nil)
        requestID = nil; cursorTick = nil; countInBeat = nil
        if let previous { await audio.stopTransport(id: previous) }
        if generation == ticket { isBusy = false }
    }
    func seek(_ tick: Int64, audio: AudioSessionStore) async {
        await stop(audio: audio, seekTick: range.contains(tick) ? tick : range.lowerBound)
    }
    func activeEvent() -> MusicalEvent? {
        guard let cursorTick, countInBeat == nil else { return nil }
        return exercise?.events.first { $0.startTick <= cursorTick && cursorTick < $0.endTick }
    }
}
