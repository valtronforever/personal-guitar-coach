#if DEBUG
import SwiftUI
import Domain
import Learning

struct AssessmentFixtureView: View {
    @State private var selected = "valid"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("debug.assessmentTitle").font(.headline)
                Picker("debug.fixture", selection: $selected) {
                    ForEach(["valid", "uncalibrated", "insufficientSignal", "interrupted"], id: \.self) { value in
                        Text(LocalizedStringKey("assessment.validity." + value)).tag(value)
                    }
                }.accessibilityIdentifier("debug.assessmentCase")
                if let result = try? Self.result(selected) { AssessmentSummaryView(result: result) }
            }.padding(20)
        }.frame(minWidth: 500, minHeight: 500)
    }
    static func result(_ selected: String) throws -> AssessedPractice {
        let endpoint = try CalibrationEndpoint(uid: "synthetic-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512,
            deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "synthetic-fixture")
        let profile = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "synthetic-fixture", matchedPulses: 12, missedPulses: 0,
                extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let events = try (0..<8).map { try MusicalEvent(id: "fixture-\($0)", startTick: Int64($0) * 960,
            durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: $0)]) }
        let config = try PracticeConfiguration(exercise: Exercise(id: "synthetic-fixture", events: events), instrument: InstrumentProfile(),
            bpm: 60, route: route, calibration: selected == "uncalibrated" ? nil : profile)
        let attacks = try events.enumerated().map { index, event in
            try PracticeAttack(id: UInt64(index + 1), normalizedOnset: 104 + Double(index) + (index == 2 ? 0.05 : 0),
                frequency: config.instrument.tuning.pitch(at: event.positions[0]).frequency(referenceA4: 440),
                clarity: 0.99, reliable: selected != "insufficientSignal")
        }
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 20), phase: selected == "interrupted" ? .paused : .completed,
            reason: selected == "interrupted" ? .paused : nil, signalConfirmed: true, renderEpochSeconds: 100,
            maximumClockDriftSeconds: 0, attacks: attacks, clipping: [], analysisVersion: "synthetic-fixture")
        return try AssessmentEngine.evaluate(evidence)
    }
}
#endif
