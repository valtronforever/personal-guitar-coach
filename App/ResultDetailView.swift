import SwiftUI
import Domain
import Learning

private struct PreparedResultAdvice: Identifiable, Sendable {
    var id: String { recommendation.id }
    let recommendation: PracticeRecommendation
    let request: PracticeRequest?
}

struct ResultDetailView: View {
    let result: AssessedPractice
    var history: [AssessedPractice] = []
    var onRetry: ((PracticeRequest) -> Void)? = nil
    var onAudioSetup: (() -> Void)? = nil
    var onTuner: ((TuningProfile) async -> Bool)? = nil
    @Environment(AppSettings.self) private var settings
    @State private var selectedID: String?
    @State private var preparingTuner = false
    @State private var tunerFailed = false
    @State private var preparedAdvice: [PreparedResultAdvice]?
    private var config: PracticeConfiguration { result.evidence.configuration }
    private var tuning: TuningProfile { config.exercise.requiredTuning ?? config.instrument.tuning }
    private var annotations: [String: ResultAnnotation] { ResultPresentation.annotations(result) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("result.title").font(.title2.bold()).accessibilityIdentifier("result.detail")
                Text(result.evidence.startedAt, format: .dateTime.year().month().day().hour().minute())
                AssessmentSummaryView(result: result)
                if let reason = result.evidence.reason { Text(LocalizedStringKey("practice.reason." + reason.rawValue)) }
                if tunerFailed { Text("result.tunerPreparationFailed").foregroundStyle(.red) }
                conditions
                comparison
                GroupBox("result.nextSteps") {
                    VStack(alignment: .leading, spacing: 16) {
                        if let preparedAdvice {
                            ForEach(preparedAdvice) { item in recommendation(item.recommendation, request: item.request) }
                        } else { ProgressView("common.loading") }
                        Text("result.adviceVersion \(PracticeRecommendation.ruleVersion)").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if let timeline = try? TimelineModel(exercise: config.exercise, instrument: tuning) {
                    TablatureView(model: timeline, selectedIDs: Set(selectedID.map { [$0] } ?? [result.notes[0].id]),
                        instructionsKey: "result.tabInstructions", annotations: annotations) { id, _ in selectedID = id }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading) {
                    ForEach(ResultAnnotation.allCases.filter { annotations.values.contains($0) }, id: \.rawValue) { annotation in
                        Label(LocalizedStringKey(annotation.key), systemImage: annotation.symbol).font(.caption)
                    }
                }
                eventDetail(selectedID ?? result.notes[0].id)
                if !result.extras.isEmpty {
                    DisclosureGroup("result.extraDetails") {
                        ForEach(result.extras) { extra in
                            if let attack = result.evidence.attacks.first(where: { $0.id == extra.id }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("result.attackID \(String(extra.id))").font(.headline)
                                    Text(LocalizedStringKey(extra.uncertain ? "result.annotation.uncertain" : "result.extraObserved"))
                                    if let rest = extra.restID, let event = config.selectedEvents.first(where: { $0.id == rest }) {
                                        Text("tab.bar \(event.startTick / config.exercise.timeSignature.ticksPerBar + 1)")
                                    }
                                    observed(attack)
                                }.padding(.vertical, 6)
                            }
                        }
                    }
                }
                Text("result.measurementLimits").font(.caption).foregroundStyle(.secondary)
            }.padding(CoachLayout.padding)
        }.frame(minWidth: 620, minHeight: 500)
        .task(id: result.id) {
            preparedAdvice = nil
            let snapshot = result
            let prepared = await Task.detached {
                FeedbackEngine.recommendations(for: snapshot).map {
                    PreparedResultAdvice(recommendation: $0, request: PracticeRequest(result: snapshot, recommendation: $0))
                }
            }.value
            if !Task.isCancelled { preparedAdvice = prepared }
        }
    }
    private var conditions: some View {
        GroupBox("result.conditions") {
            VStack(alignment: .leading, spacing: 8) {
                HStack { TuningName(profile: tuning); Text("practice.selectedTempo \(Int(config.bpm))") }
                Text("result.bars \(Int(config.range.lowerBound / config.exercise.timeSignature.ticksPerBar) + 1) \(Int((config.range.upperBound - 1) / config.exercise.timeSignature.ticksPerBar) + 1)")
                Text(verbatim: tuning.strings.reversed().map { $0.openPitch.name(spelling: tuning.preferredSpelling) }.joined(separator: " · "))
                Text("practice.stringOrder").font(.caption)
                Text("result.fretCount \(config.instrument.fretCount)")
                if let position = config.lesson?.position { Text("lesson.position.from \(position.firstFret)") }
                Text("result.reference \(number(tuning.referenceA4))")
                Text(LocalizedStringKey(config.instrument.source.titleKey))
                DisclosureGroup("result.versions") {
                    Text("result.exerciseVersion \(config.exercise.id) \(config.exercise.version)")
                    Text("result.tuningVersion \(tuning.id) \(tuning.revision)")
                    Text("result.analysisVersion \(result.evidence.analysisVersion)")
                    Text("result.scoringVersion \(result.parameters.version)")
                    Text("result.capabilityVersion \(config.capabilityVersion)")
                    Text(LocalizedStringKey("calibration.method." + (config.calibration?.method.rawValue ?? "none")))
                }.font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var comparison: some View {
        GroupBox("result.comparison") {
            VStack(alignment: .leading, spacing: 8) {
                Text("result.comparisonConditions").font(.caption).foregroundStyle(.secondary)
                if let previous = PracticeComparison.previous(to: result, in: history),
                   let before = PracticeComparison.score(previous), let current = PracticeComparison.score(result) {
                    Text(LocalizedStringKey(result.validity == .valid ? "result.comparingOverall" : "result.comparingPitch"))
                    Text("result.previousScore \(Int(before.rounded())) \(number(current - before))")
                    Text(previous.evidence.startedAt, format: .dateTime.year().month().day().hour().minute()).font(.caption)
                    if let best = PracticeComparison.best(for: result, in: history + [result]), let score = PracticeComparison.score(best) {
                        Text("result.bestScore \(Int(score.rounded()))")
                    }
                } else { Text("result.noComparison") }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private func recommendation(_ advice: PracticeRecommendation, request: PracticeRequest?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("feedback." + advice.kind.rawValue)).font(.headline)
            switch advice.kind {
            case .inputLevel: Text("feedback.clippingEvidence \(advice.evidenceCount)")
            case .signal: Text("feedback.signalEvidence \(advice.evidenceCount) \(advice.denominator)")
            case .early, .late, .missed, .pitch, .tuning:
                Text("feedback.noteEvidence \(advice.evidenceCount) \(advice.denominator)")
            case .rests: Text("feedback.restEvidence \(advice.evidenceCount) \(advice.denominator)")
            case .repeatFragment: Text("feedback.repeatEvidence \(advice.denominator)")
            case .calibration: Text(LocalizedStringKey("assessment.rhythmReason." + result.rhythmCapability.rawValue))
            case .interrupted, .restart:
                if let reason = result.evidence.reason { Text(LocalizedStringKey("practice.reason." + reason.rawValue)) }
            }
            if advice.action == .repeatFragment {
                Text("feedback.fragment \(advice.firstBar) \(advice.lastBar) \(Int(advice.bpm))")
                if let request, let onRetry {
                    Button("result.repeatFragment") { onRetry(request.freshSelection()) }.accessibilityIdentifier("result.retry." + advice.id)
                } else { Text("result.retryUnavailable").font(.caption).foregroundStyle(.secondary) }
            } else if advice.action == .tuner {
                if let onTuner {
                    Button("result.openSavedTuner") {
                        preparingTuner = true; tunerFailed = false
                        Task { tunerFailed = await !onTuner(tuning); preparingTuner = false }
                    }.disabled(preparingTuner)
                }
            } else if let onAudioSetup { Button("audio.title", action: onAudioSetup) }
            if !advice.eventIDs.isEmpty {
                if advice.action != .repeatFragment { Text("result.bars \(advice.firstBar) \(advice.lastBar)") }
                DisclosureGroup("result.showEvidence") {
                    ForEach(advice.eventIDs, id: \.self) { id in
                        if let event = config.selectedEvents.first(where: { $0.id == id }) {
                            let bar = event.startTick / config.exercise.timeSignature.ticksPerBar + 1
                            let beat = number(Double(event.startTick % config.exercise.timeSignature.ticksPerBar) / 960 + 1)
                            Button { selectedID = id } label: { Text("result.evidenceEvent \(bar) \(beat)") }
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .contain)
    }
    @ViewBuilder private func eventDetail(_ id: String) -> some View {
        if let event = config.exercise.events.first(where: { $0.id == id }) {
            GroupBox("result.eventDetails") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("tab.bar \(event.startTick / config.exercise.timeSignature.ticksPerBar + 1)")
                    if let annotation = annotations[id] { Label(LocalizedStringKey(annotation.key), systemImage: annotation.symbol) }
                    else { Text("result.unassessed") }
                    if let note = result.notes.first(where: { $0.id == id }) {
                        if let position = event.positions.first, let pitch = try? tuning.pitch(at: position) {
                            Text("result.expectedPosition \(pitch.name(spelling: tuning.preferredSpelling)) \(position.string) \(position.fret)")
                        }
                        Text("result.targetFrequency \(number(note.targetFrequency))")
                        if let cents = note.centsError { Text("result.pitchError \(number(cents))") }
                        if let timing = note.timingErrorSeconds { Text("result.timingError \(number(timing * 1000))") }
                        if let attackID = note.attackID, let attack = result.evidence.attacks.first(where: { $0.id == attackID }) { observed(attack) }
                    }
                    if event.kind == .rest && config.range.contains(event.startTick) {
                        Text("result.restAttacks \(result.extras.filter { $0.restID == id }.count)")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("result.eventDetails")
        }
    }
    @ViewBuilder private func observed(_ attack: PracticeAttack) -> some View {
        if let frequency = attack.frequency { Text("result.observedFrequency \(number(frequency))") }
        if let clarity = attack.clarity { Text("result.clarity \(number(clarity))") }
    }
    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2)).locale(settings.locale)) }
}
