import Foundation
import Testing
import Domain
import Learning
@testable import Audio

struct PluckingCueTests {
    @Test func fingerCueDoesNotChangeReferencePitchTimingOrInventGestureAssessment() throws {
        let position = try FretPosition(string: 2, fret: 5), endpoint = try CalibrationEndpoint(uid: "finger", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        var results: [AssessedPractice] = [], reference: [Float]? = nil
        for finger in [nil] + PluckingFinger.allCases.map(Optional.some) {
            let exercise = try Exercise(id: "finger", events: [MusicalEvent(id: "note", startTick: 0, durationTicks: 960, kind: .note,
                positions: [position], pluckFinger: finger)])
            let plan = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, clickEnabled: false), sampleRate: 48000)
            let pcm = try plan.render(startFrame: 0, count: 48000)
            if let reference { #expect(pcm == reference) } else { reference = pcm }
            let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route)
            let start = try config.expectedStart(renderEpochSeconds: 100)
            let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 10),
                phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
                attacks: [PracticeAttack(id: 1, normalizedOnset: start, frequency: 329.6275569128699, clarity: 0.99, reliable: true)], clipping: [], analysisVersion: "fixture")
            let result = try AssessmentEngine.evaluate(evidence)
            #expect(result.parameters == .current && result.validity == .uncalibrated && result.pitchScore == 100 && result.timingScore == nil)
            #expect(result.evidence.configuration.exercise.events.first?.pluckFinger == finger)
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
            results.append(result)
        }
        #expect(results.allSatisfy { $0.notes == results[0].notes && $0.pitchScore == results[0].pitchScore && $0.scoredExtras.isEmpty })
    }
}
