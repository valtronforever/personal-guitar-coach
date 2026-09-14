import Domain
import SwiftUI
import UniformTypeIdentifiers

struct CoachResultSection: View {
    let result: AssessedPractice
    @Environment(AppSettings.self) private var settings
    @State private var coach = AgentCoachStore.shared
    @State private var importing = false
    @State private var channel = 1
    var body: some View {
        GroupBox("coach.title") {
            VStack(alignment: .leading, spacing: 12) {
                Text("coach.explanation").font(.caption).foregroundStyle(.secondary)
                if coach.busyAttempt == result.id {
                    ProgressView("coach.analyzing")
                    Button("coach.cancel") { coach.cancel() }
                }
                if let error = coach.errors[result.id] {
                    Label(LocalizedStringKey(error), systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
                if coach.savedRequests[result.id] != nil {
                    Button("coach.retry") { coach.retry(result, language: settings.language.resolvedCode()) }.disabled(coach.busyAttempt != nil)
                }
                if let response = coach.responses[result.id] {
                    Text(verbatim: response.feedback.summary).textSelection(.enabled)
                    ForEach(Array(response.feedback.findings.enumerated()), id: \.offset) { _, finding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: finding.text).textSelection(.enabled)
                            DisclosureGroup("coach.evidence") {
                                ForEach(finding.evidenceIDs, id: \.self) { id in
                                    if let event = (response.request.audio.events + response.request.audio.pitchSamples).first(where: { $0.id == id }) {
                                        if let frequency = event.frequency { Text("coach.audioEvent \(event.seconds) \(frequency)") }
                                        else { Text("coach.audioEventUncertain \(event.seconds)") }
                                    } else { Text(verbatim: id) }
                                }
                            }.font(.caption)
                        }
                    }
                    Text(verbatim: response.provider.rawValue.capitalized + " · " + response.feedback.language.uppercased() + " · " + response.request.promptVersion)
                        .font(.caption).foregroundStyle(.secondary)
                    Text(response.createdAt, style: .date).font(.caption)
                }
                HStack {
                    Stepper("coach.channel \(channel)", value: $channel, in: 1...8)
                    Button("coach.import") { importing = true }.disabled(coach.busyAttempt != nil)
                }
                Text("coach.importLimits").font(.caption).foregroundStyle(.secondary)
                Button("coach.delete", role: .destructive) { coach.delete(result.id) }.disabled(coach.busyAttempt != nil)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: result.id) { await coach.load(result) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.wav, .mp3]) { selection in
            switch selection {
            case let .success(url):
                coach.analyze(practice: result, file: url, channel: channel, language: settings.language.resolvedCode())
            case let .failure(error): coach.fileSelectionFailed(error, practiceID: result.id)
            }
        }
    }
}

struct AgentCoachSettings: View {
    @AppStorage("coach.provider") private var provider = "codex"
    @State private var coach = AgentCoachStore.shared
    var body: some View {
        Form {
            Picker("coach.provider", selection: $provider) {
                Text(verbatim: "Codex").tag("codex")
                Text(verbatim: "Claude Code").tag("claude")
            }
            Text("coach.setup")
            Text("coach.explanation").foregroundStyle(.secondary)
            Text("coach.retention").foregroundStyle(.secondary)
            Button("coach.deleteAll", role: .destructive) { coach.deleteAll() }.disabled(coach.busyAttempt != nil)
            if coach.deletionFailed { Text("coach.error.delete").foregroundStyle(.red) }
        }.formStyle(.grouped)
    }
}
