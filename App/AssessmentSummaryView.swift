import SwiftUI
import Domain

struct AssessmentSummaryView: View {
    let result: AssessedPractice
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey("assessment.validity." + result.validity.rawValue)).font(.headline)
                    .accessibilityIdentifier("assessment.validity")
                HStack(alignment: .top, spacing: 24) {
                    metric("assessment.overall", result.overallScore)
                    metric("assessment.pitch", result.pitchScore)
                    metric("assessment.rhythm", result.timingScore)
                    if result.sustain != nil { metric("assessment.sustain", result.sustainScore) }
                }
                if result.sustain != nil {
                    Text("assessment.sustainExplanation").font(.caption).foregroundStyle(.secondary)
                    if result.sustain?.score == nil { Text("assessment.sustainUnavailable").foregroundStyle(.secondary) }
                }
                if result.evidence.configuration.calibration?.method == .manualPersonal {
                    Text("calibration.method.manualPersonal").foregroundStyle(.secondary)
                }
                if result.rhythmCapability == .approximate {
                    Text("sync.approximateResult").foregroundStyle(.secondary)
                    Text("sync.tolerance \(Int((result.rhythmToleranceSeconds * 1000).rounded()))").font(.caption)
                }
                if result.validity == .uncalibrated {
                    Text(LocalizedStringKey("assessment.rhythmReason." + result.rhythmCapability.rawValue)).foregroundStyle(.secondary)
                }
                Text("assessment.expected \(result.expectedCount)")
                Text("assessment.matched \(result.matchedCount)")
                Text("assessment.missed \(result.missedCount)")
                Text("assessment.extra \(result.extras.count)")
                if result.uncertainCount + result.uncertainExtraCount > 0 {
                    Text("assessment.uncertain \(result.uncertainCount) \(result.uncertainExtraCount)")
                    Text("assessment.uncertainExplanation").font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("assessment.title").accessibilityAddTraits(.isHeader).accessibilityIdentifier("assessment.summary")
        }
    }
    private func metric(_ key: LocalizedStringKey, _ value: Double?) -> some View {
        VStack(alignment: .leading) {
            Text(key).font(.caption)
            if let value { Text(value, format: .number.precision(.fractionLength(0))).font(.title2.bold()).monospacedDigit() }
            else { Text("assessment.unavailable").foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
