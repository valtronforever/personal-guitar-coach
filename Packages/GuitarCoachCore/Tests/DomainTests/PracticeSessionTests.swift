import Foundation
import Testing
@testable import Domain

struct PracticeSessionTests {
    private func configuration() throws -> PracticeConfiguration {
        let events = try (0..<8).map { index in
            try MusicalEvent(id: "note-\(index)", startTick: Int64(index) * 960, durationTicks: 960,
                             kind: .note, positions: [FretPosition(string: 6, fret: index)])
        }
        let endpoint = try CalibrationEndpoint(uid: "test", channel: 1, sampleRate: 48000, bufferFrames: 512,
            deviceLatencyFrames: 240, streamLatencyFrames: 240)
        return try PracticeConfiguration(exercise: Exercise(id: "practice-test", events: events), instrument: InstrumentProfile(),
            bpm: 60, route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test"))
    }
    @Test func legalTransitionsFreezeConfigurationAndRetryUsesAnotherIdentity() throws {
        let configuration = try configuration()
        var state = PracticeStateMachine()
        #expect(throws: PracticeError.invalidTransition) { try state.complete() }
        try state.begin(configuration)
        let first = state.attemptID
        #expect(state.phase == .preflight && state.configuration == configuration)
        #expect(throws: PracticeError.invalidTransition) { try state.begin(configuration) }
        try state.preflightPassed(); try state.beginPlaying(); state.stop(.paused)
        #expect(state.phase == .paused && state.reason == .paused)
        #expect(throws: PracticeError.invalidTransition) { try state.complete() }
        try state.begin(configuration)
        #expect(state.attemptID != first && state.reason == nil)
        try state.preflightPassed(); try state.beginPlaying(); try state.beginFinalizing(); try state.complete()
        state.stop(.routeChanged)
        #expect(state.phase == .completed && state.reason == nil)
    }
    @Test func failedPreflightAndRunningInterruptionNeverBecomeCompleted() throws {
        let configuration = try configuration()
        var state = PracticeStateMachine()
        try state.begin(configuration); state.stop(.noTestSignal)
        #expect(state.phase == .preflightFailed)
        try state.begin(configuration); try state.preflightPassed(); try state.beginPlaying()
        state.stop(.dataLoss)
        #expect(state.phase == .interrupted)
        #expect(throws: PracticeError.invalidTransition) { try state.beginFinalizing() }
        try state.begin(configuration); state.stop(.userCancelled)
        #expect(state.phase == .cancelled)
    }
    @Test func rangesAndAudioClockMappingHaveExplicitBounds() throws {
        let original = try configuration()
        let selected = try PracticeConfiguration(exercise: original.exercise, instrument: original.instrument, bpm: 120,
            range: 3840..<7680, route: original.route)
        #expect(selected.selectedEvents.count == 4 && selected.durationSeconds == 2)
        #expect(abs(try selected.expectedStart(renderEpochSeconds: 100) - 102.01) < 0.000001)
        #expect(abs(selected.finalDrainSeconds - 1.41) < 0.000001)
        #expect(throws: PracticeError.invalidRange) {
            try PracticeConfiguration(exercise: original.exercise, instrument: original.instrument, bpm: 60,
                range: 960..<7680, route: original.route)
        }
        #expect(throws: MusicError.invalidTempo) {
            try PracticeConfiguration(exercise: original.exercise, instrument: original.instrument, bpm: .nan, route: original.route)
        }
    }
    @Test func archivedCapabilityIsPreservedButStartingAgainChecksCurrentSupport() throws {
        let original = try configuration()
        var document = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var route = try #require(document["route"] as? [String: Any])
        var input = try #require(route["input"] as? [String: Any])
        input["sampleRate"] = 32000
        route["input"] = input; document["route"] = route; document["capabilityVersion"] = "archived-capability"
        let restored = try JSONDecoder().decode(PracticeConfiguration.self, from: JSONSerialization.data(withJSONObject: document))
        #expect(restored.capabilityVersion == "archived-capability" && restored.route.input.sampleRate == 32000)
        var machine = PracticeStateMachine()
        #expect(throws: PracticeError.unsupportedFormat) { try machine.begin(restored) }
        #expect(machine.phase == .idle)
    }

}
