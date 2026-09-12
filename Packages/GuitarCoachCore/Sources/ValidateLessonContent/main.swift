import Foundation
import Domain
import Learning
import Darwin

let args = CommandLine.arguments
guard args.count == 2 || (args.count == 4 && args[2] == "--positions") else {
    print("Usage: ValidateLessonContent <catalog directory> [--positions <lesson-id>]")
    exit(2)
}
let report = LessonCatalogLoader().load(directory: URL(fileURLWithPath: args[1], isDirectory: true))
if args.count == 4, report.issues.isEmpty {
    guard let lesson = report.lessons.first(where: { $0.id == args[3] }) else { print("Unknown lesson"); exit(1) }
    struct ChoiceReport: Encodable { let choice: PositionChoice; let available: Bool; let reason: String? }
    struct Row: Encodable { let activityID: String; let tuningID: String; let fretCount: Int; let choices: [ChoiceReport] }
    struct Report: Encodable { let lessonID: String; let lessonVersion: Int; let resolverVersion: String; let rows: [Row] }
    var rows: [Row] = []
    // One validated lesson, at most 256 activities × 8 presets × 5 necks × 26 choices.
    for activity in lesson.manifest.activities {
        for tuning in TuningProfile.presets {
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                let choices: [PositionChoice] = [.original] + (0...24).map { .region(firstFret: $0) }
                let outcomes = choices.map { choice -> ChoiceReport in
                    do { _ = try lesson.resolveActivity(id: activity.id, instrument: instrument, choice: choice)
                        return ChoiceReport(choice: choice, available: true, reason: nil)
                    } catch { return ChoiceReport(choice: choice, available: false, reason: String(describing: error)) }
                }
                rows.append(Row(activityID: activity.id, tuningID: tuning.id, fretCount: frets.rawValue, choices: outcomes))
            }
        }
    }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(Report(lessonID: lesson.id, lessonVersion: lesson.manifest.version,
        resolverVersion: ResolvedLessonActivity.resolverVersion, rows: rows))
    FileHandle.standardOutput.write(data); print("")
} else {
    for issue in report.issues { print("[\(issue.lessonID ?? "catalog")] \(issue.code.rawValue): \(issue.detail)") }
    print("Validated \(report.lessons.count) bilingual lesson(s); \(report.issues.count) issue(s).")
}
exit(report.issues.isEmpty && !report.lessons.isEmpty ? 0 : 1)
