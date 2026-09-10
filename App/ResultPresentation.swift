import Foundation
import Domain
import Learning
import Persistence

enum ResultAnnotation: String, CaseIterable {
    case uncertain, missing, pitch, early, late, matched, restExtra
    var key: String { "result.annotation." + rawValue }
    var symbol: String {
        switch self {
        case .uncertain: "questionmark.diamond"
        case .missing: "minus.circle"
        case .pitch: "waveform.path"
        case .early: "arrow.left.circle"
        case .late: "arrow.right.circle"
        case .matched: "link"
        case .restExtra: "plus.circle"
        }
    }
}

enum ResultPresentation {
    static func annotations(_ result: AssessedPractice) -> [String: ResultAnnotation] {
        let graded = result.validity == .valid || result.validity == .uncalibrated
        var annotations: [String: ResultAnnotation] = [:]
        for note in result.notes {
            if note.uncertain { annotations[note.id] = .uncertain }
            else if note.attackID == nil { if graded { annotations[note.id] = .missing } }
            else if graded && abs(note.centsError ?? 0) >= 15 { annotations[note.id] = .pitch }
            else if result.validity == .valid, let timing = note.timingErrorSeconds, abs(timing) > result.rhythmToleranceSeconds {
                annotations[note.id] = timing < 0 ? .early : .late
            } else { annotations[note.id] = .matched }
        }
        for extra in result.extras {
            if let rest = extra.restID {
                annotations[rest] = extra.uncertain || annotations[rest] == .uncertain ? .uncertain : .restExtra
            }
        }
        return annotations
    }
    static func title(record: PracticeRecord, lessons: [LoadedLesson], language: LessonLanguage) -> String? {
        guard let reference = record.assessment?.payload.evidence.configuration.lesson,
              let lesson = lessons.first(where: { $0.id == reference.id && $0.manifest.version == reference.version }) else { return nil }
        return lesson.text(for: language).title
    }
}
